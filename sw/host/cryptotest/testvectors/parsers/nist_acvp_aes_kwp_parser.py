#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP AES-KWP prompts to JSON.

Reads a `prompt.json` vector set. The harness assembles the response.
Supports:
  - ACVP-AES-KWP-1.0 (encrypt, decrypt)

Each test carries the `tg_id` and `vs_id` it came from, so the harness can
rebuild the test group structure the response requires.

Only the forward cipher (kwCipher "cipher") is answered, and only payloads
of at least two semiblocks: the cryptolib wraps with the AES encryption
direction and does not implement the single-block case for payloads of at
most 64 bits.
"""

import argparse
import json
import sys

import jsonschema

from acvp_util import acvp_common, load_vector_set, report_skipped

# Shortest payload, in bits, the cryptolib wraps.
MIN_PAYLOAD_LEN = 72


def apply_expected(test_vectors, path):
    """Folds an expectedResults.json onto the test cases. Unlike the shared
    helper, the answers go into the plaintext and ciphertext fields the
    harness also reads its inputs from. A prompt with no answers is answered
    without checking, which is the production case."""
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
        elif "testPassed" in answer:
            vector["result"] = answer["testPassed"]


def parse_kwp(data, skip_unsupported):
    """Parse an ACVP-AES-KWP prompt.
    Response: ct when wrapping; pt, or testPassed false, when unwrapping."""
    test_vectors = []
    skipped_inverse = 0
    skipped_short = 0
    for group in data["testGroups"]:
        if group["kwCipher"] != "cipher":
            skipped_inverse += len(group["tests"])
            continue
        if group["payloadLen"] < MIN_PAYLOAD_LEN:
            skipped_short += len(group["tests"])
            continue

        for test in group["tests"]:
            vector = {
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "operation": group["direction"],
                "padding": True,
                "key_len": group["keyLen"],
                "key": list(bytes.fromhex(test["key"])),
            }
            if group["direction"] == "encrypt":
                vector["plaintext"] = list(bytes.fromhex(test["pt"]))
            else:
                vector["ciphertext"] = list(bytes.fromhex(test["ct"]))
            test_vectors.append(vector)
    report_skipped("parse_kwp", {
        "the inverse cipher is not implemented": skipped_inverse,
        "payloads of at most 64 bits are not implemented": skipped_short,
    }, skip_unsupported)
    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for ACVP AES-KWP prompts.")
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
        choices=["kwp"],
        required=True,
        help="Type of test vectors to parse.",
    )
    parser.add_argument(
        "--skip-unsupported",
        action="store_true",
        help="Skip test cases this cryptolib cannot answer instead of "
        "failing on the first one.",
    )
    args = parser.parse_args()

    raw_data = load_vector_set(args.src)
    test_vectors = parse_kwp(raw_data, args.skip_unsupported)
    apply_expected(test_vectors, args.expected)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    with open(args.dst, "w") as dst:
        json.dump(test_vectors, dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
