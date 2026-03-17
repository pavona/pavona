#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting NIST AES-KWP testvectors to JSON.

"""

import argparse
import sys
import json
import jsonschema

from cryptotest_util import parse_rsp, str_to_byte_array


def parse_testcases(args) -> None:
    raw_testcases = parse_rsp(args.src)
    testcases = list()
    for test_case_id, test_vec in enumerate(raw_testcases):
        tmode = "null"
        if args.transformation_mode == "inverse":
            tmode = "forward" if args.operation == "decrypt" else "inverse"
        testcase = {
            "test_case_id": test_case_id,
            "vendor": "nist",
            "operation": args.operation.lower(),
            "transformation_mode": tmode,
            "padding": args.padding,
            "key_len": args.key_len,
            "key": str_to_byte_array(test_vec["K"]),
            "ciphertext": str_to_byte_array(test_vec["C"]),
            "plaintext": str_to_byte_array(test_vec["P"]) if "P" in test_vec else [],
            "result": True if "P" in test_vec else False,
        }

        # Filter based on AES-KWP API requirements (see aes_kwp.h):
        #   - aes_kwp_wrap: plaintext must be >= 16 bytes
        #   - aes_kwp_unwrap: ciphertext must be >= 24 bytes
        pt_len = len(testcase["plaintext"])
        ct_len = len(testcase["ciphertext"])
        if testcase["operation"] == "encrypt":
            if pt_len < 16:
                continue
        else:
            if ct_len < 24:
                continue
        testcases.append(testcase)

    # Validate generated JSON
    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(testcases, schema)

    json_filename = args.dst
    with open(json_filename, "w") as file:
        json.dump(testcases, file, indent=4)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for AES-KWP testvectors.")

    parser.add_argument(
        "--src",
        help="Source file to import."
    )
    parser.add_argument(
        "--dst",
        help="Destination of the output file."
    )
    parser.add_argument(
        "--operation",
        choices = ["encrypt", "decrypt"],
        type = str,
        help="Type of operation."
    )
    parser.add_argument(
        "--transformation_mode",
        choices = ["null", "inverse", "forward"],
        type = str,
        help="Cipher transformation mode used for encryption-decryption."
    )
    parser.add_argument(
        "--key_len",
        choices = [128, 192, 256],
        type = int,
        help = "Length of key in bits."
    )
    parser.add_argument(
        "--padding",
        type = bool,
        help = "Existence of padding."
    )
    parser.add_argument(
        "--schema",
        type = str,
        help = "Testvector schema file."
    )
    args = parser.parse_args()
    parse_testcases(args)

    return 0


if __name__ == "__main__":
    sys.exit(main())
