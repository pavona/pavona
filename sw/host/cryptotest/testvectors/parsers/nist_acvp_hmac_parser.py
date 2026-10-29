#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP HMAC prompts to JSON."""

import argparse
import json
import sys

import jsonschema

from acvp_util import acvp_common, load_vector_set, report_skipped

# Longest key and message, in bytes, the cryptotest firmware accepts.
HMAC_CMD_MAX_KEY_BYTES = 512
HMAC_CMD_MAX_MESSAGE_BYTES = 512


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
        if "mac" in answer:
            vector["tag"] = list(bytes.fromhex(answer["mac"]))
            vector["result"] = True


def parse_hmac(data, skip_unsupported):
    """Parse an HMAC prompt."""
    if data["revision"] != "2.0":
        raise SystemExit("parse_hmac: only revision 2.0 is implemented")
    test_vectors = []
    skipped_key = 0
    skipped_msg = 0
    for group in data["testGroups"]:
        for test in group["tests"]:
            if test["keyLen"] > HMAC_CMD_MAX_KEY_BYTES * 8:
                skipped_key += 1
                continue
            if test["msgLen"] > HMAC_CMD_MAX_MESSAGE_BYTES * 8:
                skipped_msg += 1
                continue
            test_vectors.append({
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "key": list(bytes.fromhex(test["key"])),
                "message": list(bytes.fromhex(test["msg"])[:test["msgLen"] // 8]),
                "mac_len": test["macLen"] // 8,
            })
    report_skipped("parse_hmac", {
        f"keys longer than {HMAC_CMD_MAX_KEY_BYTES} bytes are not implemented":
            skipped_key,
        f"messages longer than {HMAC_CMD_MAX_MESSAGE_BYTES} bytes are not "
        "implemented": skipped_msg,
    }, skip_unsupported)
    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for ACVP HMAC prompts.")
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
        choices=["hmac"],
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
    test_vectors = parse_hmac(raw_data, args.skip_unsupported)
    apply_expected(test_vectors, args.expected)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    with open(args.dst, "w") as dst:
        json.dump(test_vectors, dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
