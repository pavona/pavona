#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

r"""Answers ACVP vector sets on the device.

Converts each prompt into cryptotest test vectors and runs the matching
cryptotest target. The algorithm and mode come from the prompt itself.

    ./bazelisk.sh run //util:acvp_client -- \
        session/*/testvector-request.json --out responses/

Responses land in the test's undeclared outputs, and are copied to --out.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

REPO = Path(os.environ.get("BUILD_WORKSPACE_DIRECTORY",
                           Path(__file__).resolve().parent.parent))
SCHEMAS = "sw/host/cryptotest/testvectors/data/schemas"
CRYPTOTEST = "sw/device/tests/crypto/cryptotest"
PARSERS = "//sw/host/cryptotest/testvectors/parsers"

VECTOR_SETS = {
    ("ACVP-AES-KWP", ""): ("aes_kwp", "kwp"),
    ("ML-DSA", "keyGen"): ("mldsa", "keygen"),
    ("ML-DSA", "sigGen"): ("mldsa", "siggen"),
    ("ML-DSA", "sigVer"): ("mldsa", "sigver"),
    ("ML-KEM", "keyGen"): ("mlkem", "keygen"),
    ("ML-KEM", "encapDecap"): ("mlkem", "encap_decap"),
}


# Conversion outcomes other than a successful (harness, path).
SKIPPED, FAILED = "skipped", "failed"


def bazel(*args, check=True):
    result = subprocess.run([str(REPO / "bazelisk.sh"), *args], cwd=REPO)
    if check and result.returncode:
        raise subprocess.CalledProcessError(result.returncode, args)
    return result.returncode == 0


def collect(events, dest):
    """Copies out the outputs Bazel recorded for the test run."""
    for line in events.read_text().splitlines():
        result = json.loads(line).get("testResult", {})
        for out in result.get("testActionOutput", []):
            if not out["name"].startswith("test.outputs/"):
                continue
            path = Path(unquote(urlparse(out["uri"]).path))
            response = dest / path.name
            response.unlink(missing_ok=True)
            shutil.copyfile(path, response)
            print(f"response: {response}", file=sys.stderr)


def load_vector_set(path):
    """Reads a vector set.
    Sample vectors are bare objects, while production vectors are a
    two-element array. We support both here."""
    data = json.loads(Path(path).read_text())
    return data[1] if isinstance(data, list) else data


def convert(prompt, answers, out_dir, skip_unsupported):
    """Runs the parser for one vector set, returning (harness, vectors path)."""
    vector_set = load_vector_set(prompt)
    # Algorithms such as the AES modes have no mode.
    key = (vector_set["algorithm"], vector_set.get("mode", ""))
    if key not in VECTOR_SETS:
        name = " ".join(part for part in key if part)
        print(f"vsId {vector_set['vsId']}: skipping {name}, no cryptotest "
              "harness answers this algorithm and mode", file=sys.stderr)
        return SKIPPED, None
    harness, test_type = VECTOR_SETS[key]
    out = out_dir / f"acvp_{harness}_{test_type}_{vector_set['vsId']}.json"

    args = [
        "run", f"{PARSERS}:nist_acvp_{harness}_parser", "--",
        "--src", str(prompt),
        "--dst", str(out),
        "--test-type", test_type,
        "--schema", str(REPO / SCHEMAS / f"{harness}_schema.json"),
    ]
    # The answers, when the session supplied them, go onto the test cases.
    expected = answers.get(vector_set["vsId"])
    if expected:
        args += ["--expected", str(expected)]
    # Only the AES-KWP and ML-DSA parsers take --skip-unsupported.
    if skip_unsupported and harness in ("aes_kwp", "mldsa"):
        args += ["--skip-unsupported"]
    if not bazel(*args, check=False):
        return FAILED, None
    return harness, out


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("prompts", nargs="+", type=Path,
                        help="Prompt files, one per vector set.")
    parser.add_argument("--expected", nargs="+", type=Path, default=[],
                        help="Answers to those prompts, paired by vsId.")
    parser.add_argument("--out", type=Path,
                        help="Where to write the responses, besides "
                        "bazel-testlogs.")
    parser.add_argument("--exec-env", default="fpga_cw340_pqc_test_rom",
                        help="Execution environment of the cryptotest target.")
    parser.add_argument("--test-arg", "--test_arg", action="append",
                        default=[], help="Extra argument for the test, such "
                        "as --usb-serial=<serial>.")
    parser.add_argument("--hardened", action="store_true",
                        help="Run the hardened ACC backend instead.")
    parser.add_argument("--acc-pqc", action=argparse.BooleanOptionalAction,
                        default=True,
                        help="Build the ACC PQC backends into the firmware.")
    parser.add_argument("--skip-unsupported", action="store_true",
                        help="Skip test cases this cryptolib cannot answer.")
    parser.add_argument("--timeout", type=int, default=7200,
                        help="Test timeout in seconds.")
    args = parser.parse_args()

    vectors_dir = Path.home() / ".cache/pavona-acvp-client"
    vectors_dir.mkdir(parents=True, exist_ok=True)
    responses = args.out.resolve() if args.out else None
    if responses:
        responses.mkdir(parents=True, exist_ok=True)
    answers = {load_vector_set(p)["vsId"]: p for p in args.expected}
    vectors, failed, skipped = {}, [], 0
    for prompt in args.prompts:
        harness, out = convert(prompt, answers, vectors_dir,
                               args.skip_unsupported)
        if harness == SKIPPED:
            skipped += 1
        elif harness == FAILED:
            failed.append(prompt)
        else:
            vectors.setdefault(harness, []).append(out)

    answered = sum(len(paths) for paths in vectors.values())
    print(f"\n{answered} converted, {skipped} skipped as another algorithm, "
          f"{len(failed)} failed", file=sys.stderr)
    # A session is answered whole or not at all.
    for prompt in failed:
        print(f"  failed: {prompt}", file=sys.stderr)
    if failed or not vectors:
        return 1

    for harness, paths in sorted(vectors.items()):
        suffix = "_hardened" if args.hardened else ""
        name = f"{harness}_kat{suffix}_{args.exec_env}"
        config = ["--define=acc_has_pqc=true"] if args.acc_pqc else []
        events = vectors_dir / f"{name}-events.json"
        command = ["test", "--nocache_test_results", "--test_output=streamed",
                   f"--test_timeout={args.timeout}", *config,
                   f"--build_event_json_file={events}",
                   f"//{CRYPTOTEST}:{name}"]
        command += [f"--test_arg=--acvp-json={path}" for path in paths]
        command += [f"--test_arg={arg}" for arg in args.test_arg]
        print(" ".join(["./bazelisk.sh", *command]), file=sys.stderr)
        bazel(*command)
        if responses:
            collect(events, responses)
    return 0


if __name__ == "__main__":
    sys.exit(main())
