#!/usr/bin/env python3

import subprocess
import argparse
import re
import sys
from pathlib import Path

_REG_RE = re.compile(r'\s*([a-zA-Z0-9_]+)\s*=\s*((:?0x[0-9a-f]+)|([0-9]+))$')

def run_command(cmd):
    result = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    if result.returncode:
      print(result.stderr)
      raise RuntimeError(f'command failed: {cmd}')
    return result.stdout.strip()

def extract_elf_path(aquery_output):
    match = re.search(r'(bazel-out[^\s]*\.elf)', aquery_output)
    if not match:
        raise ValueError("No .elf path found in aquery output.")
    return match.group(1)

def parse_nm_output(nm_output):
    symbols = {}
    for line in nm_output.splitlines():
        parts = line.strip().split()
        if len(parts) == 3:
            addr, sym_type, name = parts
            symbols[name] = {'address': int(addr, 16), 'type': sym_type}
    return symbols

def bazel_target_to_exp(target: str, extension: str = ".exp") -> str:
    if not target.startswith("//") or ":" not in target:
        raise ValueError("Invalid Bazel target format")
    pkg, name = target[2:].split(":")
    return f"./{pkg}/{name}{extension}"


def parse_address_range(range_str):
    if '-' in range_str:
        start, end = map(int, range_str.split('-'))
        if end < start:
            raise ValueError(f"Invalid address range: {range_str}")
        return list(range(start, end + 1))
    else:
        return [int(range_str)]

def hex_to_bytes(hex_str, byte_len):
    hex_str = hex_str[2:]  # Strip '0x'
    if len(hex_str) > byte_len * 2:
        raise ValueError(f"Hex value 0x{hex_str} doesn't fit in {byte_len} bytes")
    padded = hex_str.rjust(byte_len * 2, '0')
    b = bytes.fromhex(padded)
    return b

def main():
    parser = argparse.ArgumentParser(description="Run Bazel test and extract ELF symbols.")
    parser.add_argument("--test_target", help="Bazel test target (e.g. //path/to:test)")
    parser.add_argument("--nm_path", nargs="?", default="riscv-none-elf-nm", help="Path to RISC-V nm command")
    parser.add_argument("--copt", nargs="?", help="--copt argument to pass to bazel")
    args = parser.parse_args()
    target = args.test_target

    # touch the .dexp file in case it doesn't yet exist.
    dexp = bazel_target_to_exp(args.test_target, '.dexp')
    run_command(f'touch {dexp}')

    copt = ""
    if args.copt is not None:
      copt = f"--copt={args.copt}"
    run_command(f'./bazelisk.sh test {copt} {target}')

    aquery_cmd = f"./bazelisk.sh aquery 'outputs(\".*\\.elf\", {target})' | grep Outputs"
    aquery_output = run_command(aquery_cmd)

    try:
        elf_path = extract_elf_path(aquery_output)
    except ValueError as e:
        print(e)
        sys.exit(1)

    nm_output = run_command(f"{args.nm_path} {elf_path}")
    symbol_dict = parse_nm_output(nm_output)

    # print(symbol_dict)

    memory_map = {}
    current_tag = None
    expected_addr = None
    buffer = bytearray()
    start_addr = None
    regs = ''

    with open(bazel_target_to_exp(args.test_target, '.exp2'), 'r') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line or line.startswith('//'):
                continue

            m = _REG_RE.match(line)
            if m:
                regs += line + '\n'
                buffer.clear()
                current_tag = None
                continue

            if line.startswith('#'):
                if current_tag and buffer:
                    memory_map[(current_tag, start_addr)] = buffer.hex()
                    buffer.clear()
                match = re.match(r"#\s*(\w+):", line)
                if not match:
                    raise ValueError(f"Malformed tag on line {line_num}: {line}")
                current_tag = match.group(1)
                expected_addr = None
                start_addr = None
                continue

            match = re.match(r"(\d+(?:-\d+)?)\s*=\s*(0x[0-9a-fA-F]+)", line)
            if not match:
                raise ValueError(f"Invalid data format on line {line_num}: {line}")
            addr_range_str, hex_value = match.groups()
            addresses = parse_address_range(addr_range_str)
            byte_len = len(addresses)

            byte_seq = hex_to_bytes(hex_value, byte_len)

            if expected_addr is not None and addresses[0] != expected_addr:
                raise ValueError(f"Non-contiguous addresses at line {line_num}: expected {expected_addr}, got {addresses[0]}")
            if start_addr is None:
                start_addr = addresses[0]

            buffer.extend(byte_seq)
            expected_addr = addresses[-1] + 1

    if current_tag and buffer:
        memory_map[(current_tag, start_addr)] = buffer.hex()

    # for k, v in memory_map.items():
    #     print(f"{k}: {v}")

    if len(memory_map) > 0:
        with open(bazel_target_to_exp(args.test_target, '.dexp'), 'w') as f:
            # The actual tag specified in the .exp file is almost always bogus, so search by address offset
            for region, value in memory_map.items():
                found = False
                for symbol, attrs in symbol_dict.items():
                    if attrs['address'] == region[1] and attrs['type'] in ['d', 'D']:
                        f.write(f'{symbol}: {value}\n')
                        print(f"Binding address {region[1]}(0x{region[1]:x}) to label '{symbol}'")
                        found = True
                        break
                if not found:
                    print(f"Error: could not automatically resolve dmem expected value at {region[1]}(0x{region[1]:x}) to any label")
                    print("Label candidates:")
                    print(nm_output)
    if len(regs) > 0:
        with open(bazel_target_to_exp(args.test_target, '.exp'), 'w') as f:
            f.write(regs)

if __name__ == "__main__":
    main()
