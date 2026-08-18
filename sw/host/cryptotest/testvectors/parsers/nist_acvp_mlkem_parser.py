#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP ML-KEM prompts to JSON.

Reads a `prompt.json` vector set. The harness assembles the response.
Supports:
  - ML-KEM-keyGen-FIPS203 (keygen)
  - ML-KEM-encapDecap-FIPS203 (encaps, decaps)

Each test carries the `tg_id` and `vs_id` it came from, so the harness can
rebuild the test group structure the response requires.

ACVP encapsulationKeyCheck and decapsulationKeyCheck tests verify that
the implementation rejects invalid keys. The cryptolib does not expose
dedicated key validation functions as of now, but encapsulate_derand
and decapsulate perform internal checks (FIPS 203 modulus check,
hash consistency) that reject invalid keys. We map these tests to
regular encaps/decaps operations with dummy randomness/ciphertext:
valid keys succeed, invalid keys cause the operation to fail. These
groups run as regression tests only; the two key check functions are
not supported as a standalone API.
"""

import argparse
import json
import sys

import jsonschema

import acvp_util
from acvp_util import apply_expected, load_vector_set

PARAMETER_SETS = {
    "ML-KEM-512": 512,
    "ML-KEM-768": 768,
    "ML-KEM-1024": 1024,
}


def acvp_common(data, group):
    """The identifiers the harness needs to rebuild the response;
    `function` selects the response shape within encapDecap."""
    common = acvp_util.acvp_common(data, group)
    if "function" in group:
        common["function"] = group["function"]
    return common


def parse_keygen(data):
    """Parse an ML-KEM-keyGen prompt. Response: ek and dk."""
    test_vectors = []
    for group in data["testGroups"]:
        param_set = PARAMETER_SETS[group["parameterSet"]]
        for test in group["tests"]:
            seed = bytes.fromhex(test["d"]) + bytes.fromhex(test["z"])
            test_vectors.append({
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "operation": "keygen",
                "parameter_set": param_set,
                "seed": list(seed),
                "result": True,
            })
    return test_vectors


def parse_encap_decap(data):
    """Parse an ML-KEM-encapDecap prompt."""
    test_vectors = []
    for group in data["testGroups"]:
        param_set = PARAMETER_SETS[group["parameterSet"]]
        function = group["function"]
        common = {
            **acvp_common(data, group),
            "parameter_set": param_set,
        }

        if function == "encapsulation":
            # Response: c and K.
            for test in group["tests"]:
                test_vectors.append({
                    **common,
                    "test_case_id": test["tcId"],
                    "operation": "encaps",
                    "seed": list(bytes.fromhex(test["m"])),
                    "ek": list(bytes.fromhex(test["ek"])),
                    "result": True,
                })
        elif function == "decapsulation":
            # Response: K.
            for test in group["tests"]:
                test_vectors.append({
                    **common,
                    "test_case_id": test["tcId"],
                    "operation": "decaps",
                    "dk": list(bytes.fromhex(test["dk"])),
                    "c": list(bytes.fromhex(test["c"])),
                    "result": True,
                })
        elif function == "encapsulationKeyCheck":
            # Response: testPassed, taken from whether encapsulation succeeds.
            for test in group["tests"]:
                test_vectors.append({
                    **common,
                    "test_case_id": test["tcId"],
                    "operation": "encaps",
                    "seed": [0] * 32,
                    "ek": list(bytes.fromhex(test["ek"])),
                })
        elif function == "decapsulationKeyCheck":
            # Response: testPassed, taken from whether decapsulation succeeds.
            ct_sizes = {512: 768, 768: 1088, 1024: 1568}
            dummy_ct = [0] * ct_sizes[param_set]
            for test in group["tests"]:
                test_vectors.append({
                    **common,
                    "test_case_id": test["tcId"],
                    "operation": "decaps",
                    "dk": list(bytes.fromhex(test["dk"])),
                    "c": dummy_ct,
                })
        else:
            raise ValueError(f"Unknown function: {function}")

    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for ACVP ML-KEM prompts.")
    parser.add_argument(
        "--src",
        type=str,
        help="Source ACVP prompt file.",
    )
    parser.add_argument(
        "--dst",
        type=str,
        help="Destination output JSON file.",
    )
    parser.add_argument(
        "--expected",
        type=str,
        help="ACVP expectedResults.json holding the answers to the prompt. "
        "Without it the test vectors carry no expected outputs and the "
        "harness only records what the device returns.",
    )
    parser.add_argument(
        "--schema",
        type=str,
        help="JSON schema file for validation.",
    )
    parser.add_argument(
        "--test-type",
        choices=["keygen", "encap_decap"],
        required=True,
        help="Type of test vectors to parse.",
    )
    args = parser.parse_args()

    raw_data = load_vector_set(args.src)

    if args.test_type == "keygen":
        test_vectors = parse_keygen(raw_data)
    elif args.test_type == "encap_decap":
        test_vectors = parse_encap_decap(raw_data)

    apply_expected(test_vectors, args.expected)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    with open(args.dst, "w") as dst:
        json.dump(test_vectors, dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
