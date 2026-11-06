#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP ctrDRBG prompts to JSON.

Each test instantiates the DRBG with the entropy input and the
personalization string, optionally reseeds it, generates twice with the
additional inputs, and answers with the output of the second generate call.
"""

import argparse
import json
import sys

import jsonschema

from acvp_util import acvp_common, load_vector_set


def apply_expected(test_vectors, path):
    """Folds an expectedResults.json onto the test cases."""
    if path is None:
        return
    expected = load_vector_set(path)
    answers = {test["tcId"]: test
               for group in expected["testGroups"]
               for test in group["tests"]}
    for vector in test_vectors:
        answer = answers.get(vector["test_case_id"], {})
        if "returnedBits" in answer:
            vector["output"] = list(bytes.fromhex(answer["returnedBits"]))
            vector["result"] = True


def other_inputs(test, use):
    """The additional inputs and entropy of one intended use, in order."""
    return [other for other in test["otherInput"]
            if other["intendedUse"] == use]


def parse_ctr_drbg(data):
    """Parse a ctrDRBG prompt."""
    if data["revision"] != "SP800-90Ar1":
        raise SystemExit("parse_ctr_drbg: only revision SP800-90Ar1 is "
                         "implemented")
    test_vectors = []
    for group in data["testGroups"]:
        output_bits = group["returnedBitsLen"]
        for test in group["tests"]:
            generates = other_inputs(test, "generate")
            vector = {
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "entropy": list(bytes.fromhex(test["entropyInput"])),
                "personalization_string":
                    list(bytes.fromhex(test["persoString"])),
                "reseed": group["reSeed"],
                "additional_input_1":
                    list(bytes.fromhex(generates[0]["additionalInput"])),
                "additional_input_2":
                    list(bytes.fromhex(generates[1]["additionalInput"])),
                "output_len": output_bits // 8,
            }
            if group["reSeed"]:
                reseed = other_inputs(test, "reSeed")[0]
                vector["reseed_entropy"] = list(
                    bytes.fromhex(reseed["entropyInput"]))
                vector["reseed_additional_input"] = list(
                    bytes.fromhex(reseed["additionalInput"]))
            test_vectors.append(vector)
    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for ACVP ctrDRBG prompts.")
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
        choices=["ctr_drbg"],
        required=True,
        help="Type of test vectors to parse.",
    )
    args = parser.parse_args()

    raw_data = load_vector_set(args.src)
    test_vectors = parse_ctr_drbg(raw_data)
    apply_expected(test_vectors, args.expected)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    with open(args.dst, "w") as dst:
        json.dump(test_vectors, dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
