#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting Wycheproof AES-KWP testvectors to JSON."""

import argparse
import json
import logging
import sys

import jsonschema


def parse_test_vectors(raw_data):
    test_vectors = list()
    for group in raw_data["testGroups"]:
        key_len = group["keySize"]

        for test in group["tests"]:
            plaintext = list(bytes.fromhex(test["msg"]))
            ciphertext = list(bytes.fromhex(test["ct"]))

            # Filter based on AES-KWP API requirements (see aes_kwp.h):
            #   - aes_kwp_wrap: plaintext must be >= 16 bytes
            #   - aes_kwp_unwrap: ciphertext must be >= 24 bytes
            if len(plaintext) < 16:
                logging.info("Skipped tcId %d: plaintext too short (%d bytes)",
                             test["tcId"], len(plaintext))
                continue
            if len(ciphertext) < 24:
                logging.info("Skipped tcId %d: ciphertext too short (%d bytes)",
                             test["tcId"], len(ciphertext))
                continue

            # "invalid" vectors have tampered ciphertext,
            # only test unwrap in that case.
            result = test["result"] == "valid"
            if result:
                operations = ("encrypt", "decrypt")
            else:
                operations = ("decrypt",)

            for operation in operations:
                test_vectors.append({
                    "vendor": "wycheproof",
                    "test_case_id": test["tcId"],
                    "operation": operation,
                    "key_len": key_len,
                    "key": list(bytes.fromhex(test["key"])),
                    "plaintext": plaintext,
                    "ciphertext": ciphertext,
                    "result": result,
                })

    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for Wycheproof AES-KWP testvectors.")
    parser.add_argument(
        "--src",
        type=argparse.FileType("r"),
        help="Source Wycheproof JSON file.",
    )
    parser.add_argument(
        "--dst",
        type=argparse.FileType("w"),
        help="Destination output JSON file.",
    )
    parser.add_argument(
        "--schema",
        type=str,
        help="JSON schema file for validation.",
    )
    args = parser.parse_args()

    raw_data = json.load(args.src)
    test_vectors = parse_test_vectors(raw_data)

    # Validate generated JSON
    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    json.dump(test_vectors, args.dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
