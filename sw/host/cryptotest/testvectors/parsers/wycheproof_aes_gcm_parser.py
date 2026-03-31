#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting Wycheproof AES-GCM testvectors to JSON."""

import argparse
import json
import logging
import sys

import jsonschema

SUPPORTED_TAG_LENS = {32, 64, 96, 128}
SUPPORTED_IV_LENS = {96, 128}
MAX_MSG_BYTES = 64


def parse_test_vectors(raw_data):
    test_vectors = list()
    for group in raw_data["testGroups"]:
        key_len = group["keySize"]

        if group["tagSize"] not in SUPPORTED_TAG_LENS:
            logging.info("Skipped group: unsupported tag size %d bits",
                         group["tagSize"])
            continue
        if group["ivSize"] not in SUPPORTED_IV_LENS:
            logging.info("Skipped group: unsupported IV size %d bits",
                         group["ivSize"])
            continue

        for test in group["tests"]:
            aad = list(bytes.fromhex(test["aad"]))
            plaintext = list(bytes.fromhex(test["msg"]))
            ciphertext = list(bytes.fromhex(test["ct"]))

            if len(aad) >= MAX_MSG_BYTES:
                logging.info("Skipped tcId %d: AAD too long (%d bytes)",
                             test["tcId"], len(aad))
                continue
            if len(plaintext) >= MAX_MSG_BYTES:
                logging.info("Skipped tcId %d: plaintext too long (%d bytes)",
                             test["tcId"], len(plaintext))
                continue
            if len(ciphertext) >= MAX_MSG_BYTES:
                logging.info("Skipped tcId %d: ciphertext too long (%d bytes)",
                             test["tcId"], len(ciphertext))
                continue

            # "invalid" vectors have tampered ciphertext or tag,
            # only test decryption in that case.
            result = test["result"] == "valid"
            if result:
                operations = ("encrypt", "decrypt")
            else:
                operations = ("decrypt",)

            for operation in operations:
                test_vec = {
                    "vendor": "wycheproof",
                    "test_case_id": test["tcId"],
                    "mode": "gcm",
                    "operation": operation,
                    "key_len": key_len,
                    "key": list(bytes.fromhex(test["key"])),
                    "iv": list(bytes.fromhex(test["iv"])),
                    "aad": aad,
                    "tag": list(bytes.fromhex(test["tag"])),
                    "plaintext": plaintext,
                    "ciphertext": ciphertext,
                    "result": result,
                }
                test_vectors.append(test_vec)

    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for Wycheproof AES-GCM testvectors.")
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
