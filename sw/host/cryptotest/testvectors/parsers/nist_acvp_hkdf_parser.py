#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP KDA HKDF prompts to JSON.

KDA HKDF derives the key with HKDF, using the shared secret `z` as the input
keying material and FixedInfo as the info.
With the pattern uPartyInfo||vPartyInfo||l and concatenation encoding,
FixedInfo is

    partyIdU || ephemeralDataU || partyIdV || ephemeralDataV || L

where the ephemeral data is optional and L is the output length in bits, as
a 32-bit big-endian integer.
ACVP gives these fields per test case, and the parser concatenates them.
"""

import argparse
import json
import sys

import jsonschema

from acvp_util import acvp_common, load_vector_set, report_skipped

# Longest inputs and output, in bytes, the cryptotest firmware accepts.
HKDF_CMD_MAX_IKM_BYTES = 8192
HKDF_CMD_MAX_SALT_BYTES = 512
HKDF_CMD_MAX_INFO_BYTES = 16420
HKDF_CMD_MAX_OKM_BYTES = 128

HASH_ALGS = ["SHA2-256", "SHA2-384", "SHA2-512"]
FIXED_INFO_PATTERN = "uPartyInfo||vPartyInfo||l"


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
        if "dkm" in answer:
            vector["okm"] = list(bytes.fromhex(answer["dkm"]))
            vector["result"] = True
        elif "testPassed" in answer:
            vector["result"] = answer["testPassed"]


def fixed_info(test, l_bits):
    """FixedInfo for the pattern uPartyInfo||vPartyInfo||l, concatenated."""
    info = b""
    for party in ("fixedInfoPartyU", "fixedInfoPartyV"):
        info += bytes.fromhex(test[party]["partyId"])
        info += bytes.fromhex(test[party].get("ephemeralData", ""))
    return info + l_bits.to_bytes(4, "big")


def parse_hkdf(data, skip_unsupported):
    """Parse a KDA HKDF prompt."""
    if data["revision"] not in ("Sp800-56Cr1", "Sp800-56Cr2"):
        raise SystemExit("parse_hkdf: only revisions Sp800-56Cr1 and "
                         "Sp800-56Cr2 are implemented")
    test_vectors = []
    skipped_multi = 0
    skipped_hybrid = 0
    skipped_hash = 0
    skipped_pattern = 0
    skipped_ikm = 0
    skipped_salt = 0
    skipped_info = 0
    skipped_okm = 0
    for group in data["testGroups"]:
        if group.get("multiExpansion", False):
            skipped_multi += len(group["tests"])
            continue
        if group.get("usesHybridSharedSecret", False):
            skipped_hybrid += len(group["tests"])
            continue
        config = group["kdfConfiguration"]
        if config["hmacAlg"] not in HASH_ALGS:
            skipped_hash += len(group["tests"])
            continue
        if (config["fixedInfoPattern"] != FIXED_INFO_PATTERN or
                config["fixedInfoEncoding"] != "concatenation"):
            skipped_pattern += len(group["tests"])
            continue
        for test in group["tests"]:
            params = test["kdfParameter"]
            l_bits = params.get("l", config["l"])
            ikm = bytes.fromhex(params["z"])
            salt = bytes.fromhex(params.get("salt", ""))
            info = fixed_info(test, l_bits)
            if len(ikm) > HKDF_CMD_MAX_IKM_BYTES:
                skipped_ikm += 1
                continue
            if len(salt) > HKDF_CMD_MAX_SALT_BYTES:
                skipped_salt += 1
                continue
            if len(info) > HKDF_CMD_MAX_INFO_BYTES:
                skipped_info += 1
                continue
            if l_bits > HKDF_CMD_MAX_OKM_BYTES * 8:
                skipped_okm += 1
                continue
            vector = {
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "operation": ("validate" if group["testType"] == "VAL"
                              else "derive"),
                "hash_alg": config["hmacAlg"],
                "ikm": list(ikm),
                "salt": list(salt),
                "info": list(info),
                "okm_len": l_bits // 8,
            }
            if group["testType"] == "VAL":
                vector["okm"] = list(bytes.fromhex(test["dkm"]))
            test_vectors.append(vector)
    report_skipped("parse_hkdf", {
        "multi-expansion tests are not implemented": skipped_multi,
        "hybrid shared secrets are not implemented": skipped_hybrid,
        "hash functions other than SHA2-256/384/512 are not implemented":
            skipped_hash,
        f"FixedInfo patterns other than {FIXED_INFO_PATTERN} are not "
        "implemented": skipped_pattern,
        f"shared secrets longer than {HKDF_CMD_MAX_IKM_BYTES} bytes are not "
        "implemented": skipped_ikm,
        f"salts longer than {HKDF_CMD_MAX_SALT_BYTES} bytes are not "
        "implemented": skipped_salt,
        f"FixedInfo longer than {HKDF_CMD_MAX_INFO_BYTES} bytes is not "
        "implemented": skipped_info,
        f"keys longer than {HKDF_CMD_MAX_OKM_BYTES} bytes are not "
        "implemented": skipped_okm,
    }, skip_unsupported)
    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for ACVP KDA HKDF prompts.")
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
        choices=["hkdf"],
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
    test_vectors = parse_hkdf(raw_data, args.skip_unsupported)
    apply_expected(test_vectors, args.expected)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    with open(args.dst, "w") as dst:
        json.dump(test_vectors, dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
