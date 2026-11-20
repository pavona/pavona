#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP AES-GCM prompts to JSON."""

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
        if "ct" in answer:
            vector["ciphertext"] = list(bytes.fromhex(answer["ct"]))
            vector["tag"] = list(bytes.fromhex(answer["tag"]))
            vector["result"] = True
        elif "pt" in answer:
            vector["plaintext"] = list(bytes.fromhex(answer["pt"]))
            vector["result"] = True
        elif answer.get("testPassed") is False:
            vector["result"] = False


def parse_aes_gcm(data):
    """Parse an AES-GCM prompt."""
    if data["revision"] != "1.0":
        raise SystemExit("parse_aes_gcm: only revision 1.0 is implemented")
    test_vectors = []
    for group in data["testGroups"]:
        direction = group["direction"]
        for test in group["tests"]:
            vector = {
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "mode": "gcm",
                "operation": direction,
                "key_len": group["keyLen"],
                "key": list(bytes.fromhex(test["key"])),
                "iv": list(bytes.fromhex(test["iv"])),
                "aad": list(bytes.fromhex(test["aad"])),
                "tag_len": group["tagLen"] // 8,
            }
            if direction == "encrypt":
                vector["plaintext"] = list(bytes.fromhex(test["pt"]))
            else:
                vector["ciphertext"] = list(bytes.fromhex(test["ct"]))
                vector["tag"] = list(bytes.fromhex(test["tag"]))
            test_vectors.append(vector)
    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for ACVP AES-GCM prompts.")
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
        choices=["gcm"],
        required=True,
        help="Type of test vectors to parse.",
    )
    args = parser.parse_args()

    test_vectors = parse_aes_gcm(load_vector_set(args.src))
    apply_expected(test_vectors, args.expected)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    with open(args.dst, "w") as dst:
        json.dump(test_vectors, dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
