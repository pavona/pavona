#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP SHA3 and SHAKE prompts to JSON."""

import argparse
import json
import sys

import jsonschema

from acvp_util import acvp_common, load_vector_set, report_skipped


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


def parse_sha3(data, skip_unsupported):
    """Parse a SHA3 prompt."""
    test_vectors = []
    skipped_bits = 0
    skipped_large = 0
    for group in data["testGroups"]:
        test_type = group["testType"]
        if test_type == "LDT":
            skipped_large += len(group["tests"])
            continue
        for test in group["tests"]:
            if test["len"] % 8 != 0:
                skipped_bits += 1
                continue
            test_vectors.append({
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "operation": "mct" if test_type == "MCT" else "hash",
                "message": message(test),
            })
    report_skipped("parse_sha3", {
        "bit-length messages are not implemented": skipped_bits,
        "the large data test is not implemented": skipped_large,
    }, skip_unsupported)
    return test_vectors


def parse_shake(data, skip_unsupported):
    """Parse a SHAKE prompt."""
    if data["revision"] != "FIPS202":
        raise SystemExit("parse_shake: only the FIPS202 revision is implemented")
    test_vectors = []
    skipped_bits = 0
    skipped_output = 0
    for group in data["testGroups"]:
        for test in group["tests"]:
            if test["len"] % 8 != 0:
                skipped_bits += 1
                continue
            if test["outLen"] % 32 != 0:
                skipped_output += 1
                continue
            test_vectors.append({
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "operation": "hash",
                "message": message(test),
                "output_len": test["outLen"] // 8,
            })
    report_skipped("parse_shake", {
        "bit-length messages are not implemented": skipped_bits,
        "outputs that are not whole words are not implemented":
            skipped_output,
    }, skip_unsupported)
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
        choices=["sha3", "shake"],
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
    if args.test_type == "sha3":
        test_vectors = parse_sha3(raw_data, args.skip_unsupported)
    else:
        test_vectors = parse_shake(raw_data, args.skip_unsupported)
    apply_expected(test_vectors, args.expected)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    with open(args.dst, "w") as dst:
        json.dump(test_vectors, dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
