#!/usr/bin/env python3

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile


ROOT_DIR = Path(__file__).resolve().parents[2]
DEFAULT_CONFIG = ROOT_DIR / "hw/top_egret/dv/resiliator/config.json"


def load_config(path):
    with path.open(encoding="utf-8") as config_file:
        return json.load(config_file)


def run(command, **kwargs):
    print(f"+ {shlex.join(str(arg) for arg in command)}", flush=True)
    subprocess.run([str(arg) for arg in command], check=True, **kwargs)


def bazel_output(bazel, extra_flags, target):
    command = [bazel, "cquery", *extra_flags, "--output=files", target]
    result = subprocess.run(
        command, check=True, cwd=ROOT_DIR, stdout=subprocess.PIPE, text=True
    )
    output = result.stdout.strip()
    if not output:
        raise RuntimeError(f"Bazel returned no files for {target}")
    path = Path(output)
    if not path.is_absolute():
        path = ROOT_DIR / path
    return path.resolve(strict=True)


def write_github_output(name, value):
    output_file = os.environ.get("GITHUB_OUTPUT")
    if output_file:
        with open(output_file, "a", encoding="utf-8") as output:
            output.write(f"{name}={value}\n")


def main():
    parser = argparse.ArgumentParser(description="Run a Resiliator fault-injection campaign")
    parser.add_argument("top", nargs="?", help="top-level design (defaults to the config value)")
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    args = parser.parse_args()

    config = load_config(args.config)
    top = args.top or config["top"]
    if top != config["top"]:
        raise RuntimeError(f"Config supports top '{config['top']}', not '{top}'")

    bazel = ROOT_DIR / "bazelisk.sh"
    extra_flags = shlex.split(os.environ.get("BAZEL_EXTRA_FLAGS", ""))
    build = config["build"]
    simulation = config["simulation"]

    print("::group::Build Resiliator model and firmware")
    try:
        run(
            [
                bazel,
                "build",
                f"--//hw/top={top}",
                f"--//hw:make_options=-j,{build['jobs']}",
                *extra_flags,
                *build["targets"],
            ],
            cwd=ROOT_DIR,
        )
    finally:
        print("::endgroup::")

    simulator = bazel_output(bazel, extra_flags, simulation["simulator_target"])
    firmware = bazel_output(bazel, extra_flags, simulation["firmware_target"])

    work_dir = Path(tempfile.mkdtemp())
    output_dir = work_dir / simulation["output_directory"]
    print(f"Campaign results: {output_dir}")
    write_github_output("results", output_dir)

    command = [
        simulator,
        f"+firmware={firmware}",
        f"+timeout={simulation['timeout']}",
    ]
    window = os.environ.get("RESILIATOR_WINDOW")
    if window:
        command.extend(["-w", window])

    print("::group::Resiliator Fault injection campaign")
    try:
        run(command, cwd=work_dir, stdin=subprocess.DEVNULL)
    finally:
        print("::endgroup::")

    results_file = output_dir / simulation["results_file"]
    if not results_file.is_file():
        raise RuntimeError("Campaign produced no sim_results file")

    results = results_file.read_text(encoding="utf-8")
    if re.search(r"^Total Flip-Flops\s*:\s*0\s*$", results, re.MULTILINE):
        raise RuntimeError(
            "No flip-flops were targeted. Check the --resiliator prefix "
            "in ibex_resiliator.core"
        )

    print("::group::Resiliator fault-injection results")
    print(results, end="" if results.endswith("\n") else "\n")
    print("::endgroup::")

    successes = sum(line.startswith("Successful injection") for line in results.splitlines())
    print(
        f"RESILIATOR CAMPAIGN DONE: {successes} injection site(s) "
        "changed the outcome with no alert"
    )


if __name__ == "__main__":
    try:
        main()
    except (
        OSError,
        KeyError,
        TypeError,
        ValueError,
        subprocess.CalledProcessError,
        RuntimeError,
    ) as error:
        print(f"RESILIATOR CAMPAIGN FAILURE: {error}", file=sys.stderr)
        sys.exit(1)
