#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP SHA2, SHA3 and SHAKE prompts to JSON."""

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
        if "md" in answer:
            vector["digest"] = list(bytes.fromhex(answer["md"]))
            vector["result"] = True
        elif "resultsArray" in answer:
            vector["mct_digests"] = [list(bytes.fromhex(result["md"]))
                                     for result in answer["resultsArray"]]
            vector["result"] = True


def message(test):
    """The first len / 8 bytes of msg; the spec writes an empty message as "00"."""
    return list(bytes.fromhex(test["msg"])[:test["len"] // 8])


def parse_hash(data):
    """Parse a SHA2 or SHA3 prompt."""
    test_vectors = []
    for group in data["testGroups"]:
        test_type = group["testType"]
        if test_type == "LDT":
            raise SystemExit("parse_hash: the large data test is not implemented")
        for test in group["tests"]:
            if test["len"] % 8 != 0:
                raise SystemExit("parse_hash: bit-length messages are not implemented")
            vector = {
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "operation": "mct" if test_type == "MCT" else "hash",
                "message": message(test),
            }
            if test_type == "MCT":
                vector["mct_version"] = group["mctVersion"]
            test_vectors.append(vector)
    return test_vectors


def parse_shake(data):
    """Parse a SHAKE prompt."""
    if data["revision"] != "FIPS202":
        raise SystemExit("parse_shake: only the FIPS202 revision is implemented")
    test_vectors = []
    for group in data["testGroups"]:
        for test in group["tests"]:
            if test["len"] % 8 != 0:
                raise SystemExit("parse_shake: bit-length messages are not implemented")
            if test["outLen"] % 32 != 0:
                raise SystemExit("parse_shake: outputs that are not whole words are not "
                                 "implemented")
            test_vectors.append({
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "operation": "hash",
                "message": message(test),
                "output_len": test["outLen"] // 8,
            })
    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for ACVP hash prompts.")
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
        choices=["sha2", "sha3", "shake"],
        required=True,
        help="Type of test vectors to parse.",
    )
    args = parser.parse_args()

    raw_data = load_vector_set(args.src)
    if args.test_type in ("sha2", "sha3"):
        test_vectors = parse_hash(raw_data)
    else:
        test_vectors = parse_shake(raw_data)
    apply_expected(test_vectors, args.expected)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    with open(args.dst, "w") as dst:
        json.dump(test_vectors, dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
