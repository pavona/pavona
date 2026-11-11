#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP SP 800-108r1 KMAC KDF prompts to JSON.

The KMAC KDF derives the key as KMAC(keyDerivationKey, context, L, label), with
the context as the message and the label as the customization string, which
is otcrypto_kmac_kdf.
"""

import argparse
import json
import sys

import jsonschema

from acvp_util import acvp_common, load_vector_set, report_skipped

# Longest inputs and output, in bytes, the cryptotest firmware accepts.
KDF_KMAC_CMD_MAX_LABEL_BYTES = 32
KDF_KMAC_CMD_MAX_CONTEXT_BYTES = 512
KDF_KMAC_CMD_MAX_KEY_OUT_BYTES = 512

# Key derivation key lengths, in bytes, the KMAC hardware accepts.
KEY_IN_BYTES = (16, 24, 32, 48, 64)

# Shortest key derivation key, in bytes, the cryptolib accepts for each MAC.
MIN_KEY_IN_BYTES = {
    "KMAC-128": 16,
    "KMAC-256": 32,
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
        if "derivedKey" in answer:
            vector["key_out"] = list(bytes.fromhex(answer["derivedKey"]))
            vector["result"] = True


def parse_kdf_kmac(data, skip_unsupported):
    """Parse a KMAC KDF prompt or internalProjection."""
    if data["revision"] != "Sp800-108r1":
        raise SystemExit("parse_kdf_kmac: only revision Sp800-108r1 is "
                         "implemented")
    test_vectors = []
    skipped_mac = 0
    skipped_key_in = 0
    skipped_label = 0
    skipped_context = 0
    skipped_words = 0
    skipped_key_out = 0
    for group in data["testGroups"]:
        mac_mode = group["macMode"]
        if mac_mode not in MIN_KEY_IN_BYTES:
            skipped_mac += len(group["tests"])
            continue
        for test in group["tests"]:
            key_in = bytes.fromhex(test["keyDerivationKey"])
            label = bytes.fromhex(test["label"])
            context = bytes.fromhex(test["context"])
            key_out_bits = test["derivedKeyLength"]
            if (len(key_in) not in KEY_IN_BYTES or
                    len(key_in) < MIN_KEY_IN_BYTES[mac_mode]):
                skipped_key_in += 1
                continue
            if len(label) > KDF_KMAC_CMD_MAX_LABEL_BYTES:
                skipped_label += 1
                continue
            if len(context) > KDF_KMAC_CMD_MAX_CONTEXT_BYTES:
                skipped_context += 1
                continue
            if key_out_bits % 32 != 0:
                skipped_words += 1
                continue
            if key_out_bits > KDF_KMAC_CMD_MAX_KEY_OUT_BYTES * 8:
                skipped_key_out += 1
                continue
            vector = {
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "mac_mode": mac_mode,
                "key_in": list(key_in),
                "label": list(label),
                "context": list(context),
                "key_out_len": key_out_bits // 8,
            }
            if "derivedKey" in test:
                vector["key_out"] = list(bytes.fromhex(test["derivedKey"]))
                vector["result"] = True
            test_vectors.append(vector)
    report_skipped("parse_kdf_kmac", {
        "MACs other than KMAC-128 and KMAC-256 are not implemented":
            skipped_mac,
        "key derivation keys other than 128, 192, 256, 384 and 512 bits, "
        "or shorter than 256 bits for KMAC-256, are not implemented":
            skipped_key_in,
        f"labels longer than {KDF_KMAC_CMD_MAX_LABEL_BYTES} bytes are not "
        "implemented": skipped_label,
        f"contexts longer than {KDF_KMAC_CMD_MAX_CONTEXT_BYTES} bytes are not "
        "implemented": skipped_context,
        "derived key lengths that are not a multiple of 32 bits are not "
        "implemented": skipped_words,
        f"derived keys longer than {KDF_KMAC_CMD_MAX_KEY_OUT_BYTES} bytes are "
        "not implemented": skipped_key_out,
    }, skip_unsupported)
    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for ACVP SP 800-108r1 KMAC KDF prompts.")
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
        choices=["kdf_kmac"],
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
    test_vectors = parse_kdf_kmac(raw_data, args.skip_unsupported)
    apply_expected(test_vectors, args.expected)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    with open(args.dst, "w") as dst:
        json.dump(test_vectors, dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
