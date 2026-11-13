#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP AES-ECB, AES-CBC, AES-CFB128, AES-OFB and
AES-CTR prompts to JSON."""

import argparse
import json
import sys

import jsonschema

from acvp_util import acvp_common, load_vector_set

MODES = {
    "ACVP-AES-ECB": "ecb",
    "ACVP-AES-CBC": "cbc",
    "ACVP-AES-CFB128": "cfb128",
    "ACVP-AES-OFB": "ofb",
    "ACVP-AES-CTR": "ctr",
}


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
            vector["result"] = True
        elif "pt" in answer:
            vector["plaintext"] = list(bytes.fromhex(answer["pt"]))
            vector["result"] = True
        elif "resultsArray" in answer:
            vector["mct_results"] = [{
                "key": list(bytes.fromhex(result["key"])),
                "iv": list(bytes.fromhex(result.get("iv", ""))),
                "plaintext": list(bytes.fromhex(result["pt"])),
                "ciphertext": list(bytes.fromhex(result["ct"])),
            } for result in answer["resultsArray"]]
            vector["result"] = True


def parse_aes(data):
    """Parse an AES-ECB, AES-CBC, AES-CFB128, AES-OFB or AES-CTR prompt."""
    if data["revision"] != "1.0":
        raise SystemExit("parse_aes: only revision 1.0 is implemented")
    mode = MODES[data["algorithm"]]
    test_vectors = []
    for group in data["testGroups"]:
        direction = group["direction"]
        for test in group["tests"]:
            message = test["pt" if direction == "encrypt" else "ct"]
            vector = {
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "test_type": group["testType"].lower(),
                "operation": direction,
                "mode": mode,
                "key": list(bytes.fromhex(test["key"])),
                "iv": list(bytes.fromhex(test.get("iv", "00" * 16))),
            }
            if direction == "encrypt":
                vector["plaintext"] = list(bytes.fromhex(message))
            else:
                vector["ciphertext"] = list(bytes.fromhex(message))
            test_vectors.append(vector)
    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for ACVP AES-ECB, AES-CBC, AES-CFB128, "
        "AES-OFB and AES-CTR prompts.")
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
        choices=list(MODES.values()),
        required=True,
        help="Type of test vectors to parse.",
    )
    args = parser.parse_args()

    raw_data = load_vector_set(args.src)
    if MODES.get(raw_data["algorithm"]) != args.test_type:
        raise SystemExit(f"parse_aes: {raw_data['algorithm']} is not "
                         f"{args.test_type}")
    test_vectors = parse_aes(raw_data)
    apply_expected(test_vectors, args.expected)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    with open(args.dst, "w") as dst:
        json.dump(test_vectors, dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
