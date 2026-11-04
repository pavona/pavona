#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP SP 800-108 KDF prompts to JSON.

Two of the KDF modes map to the cryptolib:

- Counter mode with HMAC, a 32-bit counter before the fixed data, is
  otcrypto_kdf_ctr_hmac.
- Feedback mode with HMAC, an 8-bit counter after the fixed data and an empty
  IV, is otcrypto_hkdf_expand, which computes

      K(i) = HMAC(keyIn, K(i-1) || fixedData || [i]_8)

  with K(0) empty.

The tests are deferred: the module chooses the fixed data, and the response
returns it together with the derived key.
The internalProjection.json of a sample vector set carries the fixed data and
the derived key NIST chose, which the parser uses to test against.
A prompt from a certification session carries neither, and the parser chooses
random fixed data.
"""

import argparse
import json
import os
import sys

import jsonschema

from acvp_util import acvp_common, load_vector_set, report_skipped

# Longest inputs and output, in bytes, the cryptotest firmware accepts.
KDF_HMAC_CMD_MAX_KEY_IN_BYTES = 64
KDF_HMAC_CMD_MAX_FIXED_DATA_BYTES = 64
KDF_HMAC_CMD_MAX_KEY_OUT_BYTES = 128

# Length of the fixed data the parser chooses, as in the NIST samples.
FIXED_DATA_BYTES = 16

HASH_BYTES = {
    "HMAC-SHA2-256": 32,
    "HMAC-SHA2-384": 48,
    "HMAC-SHA2-512": 64,
}

# Counter location and length of each mode the cryptolib implements.
MODES = {
    "counter": ("before fixed data", 32),
    "feedback": ("after fixed data", 8),
}


def apply_expected(test_vectors, path):
    """Folds an expectedResults.json onto the test cases.
    The expected key only holds for the fixed data NIST chose, and the test
    case takes that fixed data too."""
    if path is None:
        return
    expected = load_vector_set(path)
    answers = {test["tcId"]: test
               for group in expected["testGroups"]
               for test in group["tests"]}
    for vector in test_vectors:
        answer = answers.get(vector["test_case_id"], {})
        if "keyOut" in answer:
            vector["fixed_data"] = list(bytes.fromhex(answer["fixedData"]))
            vector["key_out"] = list(bytes.fromhex(answer["keyOut"]))
            vector["result"] = True


def parse_kdf_hmac(data, skip_unsupported):
    """Parse a KDF prompt or internalProjection."""
    if data["revision"] != "1.0":
        raise SystemExit("parse_kdf_hmac: only revision 1.0 is implemented")
    test_vectors = []
    skipped_mode = 0
    skipped_mac = 0
    skipped_counter = 0
    skipped_iv = 0
    skipped_key_in = 0
    skipped_fixed_data = 0
    skipped_bits = 0
    skipped_key_out = 0
    for group in data["testGroups"]:
        mode = group["kdfMode"]
        if mode not in MODES:
            skipped_mode += len(group["tests"])
            continue
        if group["macMode"] not in HASH_BYTES:
            skipped_mac += len(group["tests"])
            continue
        counter = (group.get("counterLocation"), group.get("counterLength"))
        if counter != MODES[mode]:
            skipped_counter += len(group["tests"])
            continue
        key_out_bits = group["keyOutLength"]
        for test in group["tests"]:
            key_in = bytes.fromhex(test["keyIn"])
            if "fixedData" in test:
                fixed_data = bytes.fromhex(test["fixedData"])
            else:
                fixed_data = os.urandom(FIXED_DATA_BYTES)
            if mode == "feedback" and test.get("iv", ""):
                skipped_iv += 1
                continue
            if (mode == "feedback" and
                    len(key_in) != HASH_BYTES[group["macMode"]]):
                skipped_key_in += 1
                continue
            if len(key_in) > KDF_HMAC_CMD_MAX_KEY_IN_BYTES:
                skipped_key_in += 1
                continue
            if len(fixed_data) > KDF_HMAC_CMD_MAX_FIXED_DATA_BYTES:
                skipped_fixed_data += 1
                continue
            if key_out_bits % 8 != 0:
                skipped_bits += 1
                continue
            if key_out_bits > KDF_HMAC_CMD_MAX_KEY_OUT_BYTES * 8:
                skipped_key_out += 1
                continue
            vector = {
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "kdf_mode": mode,
                "mac_mode": group["macMode"],
                "key_in": list(key_in),
                "fixed_data": list(fixed_data),
                "key_out_len": key_out_bits // 8,
            }
            if "keyOut" in test:
                vector["key_out"] = list(bytes.fromhex(test["keyOut"]))
                vector["result"] = True
            test_vectors.append(vector)
    report_skipped("parse_kdf_hmac", {
        "KDF modes other than counter and feedback are not implemented":
            skipped_mode,
        "MACs other than HMAC-SHA2-256/384/512 are not implemented":
            skipped_mac,
        "counters other than 32 bits before the fixed data (counter mode) "
        "and 8 bits after the fixed data (feedback mode) are not implemented":
            skipped_counter,
        "feedback mode with an IV is not implemented": skipped_iv,
        "key derivation keys other than the hash length (feedback mode) or "
        f"longer than {KDF_HMAC_CMD_MAX_KEY_IN_BYTES} bytes are not "
        "implemented": skipped_key_in,
        "fixed data longer than "
        f"{KDF_HMAC_CMD_MAX_FIXED_DATA_BYTES} bytes is not implemented":
            skipped_fixed_data,
        "output lengths that are not a multiple of 8 bits are not "
        "implemented": skipped_bits,
        f"derived keys longer than {KDF_HMAC_CMD_MAX_KEY_OUT_BYTES} bytes are "
        "not implemented": skipped_key_out,
    }, skip_unsupported)
    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for ACVP SP 800-108 KDF prompts.")
    parser.add_argument(
        "--src",
        type=str,
        help="Source ACVP prompt or internalProjection file.",
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
        "Without it, the test vectors from a prompt carry no expected "
        "outputs and the harness only records what the device returns.",
    )
    parser.add_argument(
        "--schema",
        type=str,
        help="JSON schema file for validation.",
    )
    parser.add_argument(
        "--test-type",
        choices=["kdf_hmac"],
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
    test_vectors = parse_kdf_hmac(raw_data, args.skip_unsupported)
    apply_expected(test_vectors, args.expected)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    with open(args.dst, "w") as dst:
        json.dump(test_vectors, dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
