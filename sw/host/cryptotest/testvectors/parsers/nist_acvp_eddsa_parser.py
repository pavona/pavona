#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP EdDSA testvectors to JSON.

Uses the internalProjection files from the NIST ACVP-Server repo.
Only Ed25519ph (preHash=true) is supported, since the cryptolib only
implements HashEdDSA mode.

For SigVer, the parser pre-hashes the message with SHA-512 so the
firmware receives the 64-byte digest directly.

For SigGen, the parser pre-hashes the message and emits the private
key, context, and expected signature.
"""

import argparse
import hashlib
import json
import sys

import jsonschema


def parse_sigver(data):
    """Parse EDDSA-SigVer internalProjection.

    Only Ed25519 with preHash=true (Ed25519ph / HashEdDSA) is selected.
    The message is pre-hashed with SHA-512 before output.
    """
    test_vectors = []
    for group in data["testGroups"]:
        if group["curve"] != "ED-25519":
            continue
        if not group.get("preHash", False):
            continue

        for test in group["tests"]:
            msg_bytes = bytes.fromhex(test["message"])
            prehash = hashlib.sha512(msg_bytes).digest()
            test_vectors.append({
                "vendor": "acvp",
                "test_case_id": test["tcId"],
                "algorithm": "ed25519",
                "operation": "verify",
                "message": list(prehash),
                "public_key": list(bytes.fromhex(test["q"])),
                "signature": list(bytes.fromhex(test["signature"])),
                "result": test["testPassed"],
            })
    return test_vectors


def parse_siggen(data):
    """Parse EDDSA-SigGen internalProjection.

    Only Ed25519 with preHash=true (Ed25519ph / HashEdDSA) is selected.
    The message is pre-hashed with SHA-512 before output.
    """
    test_vectors = []
    for group in data["testGroups"]:
        if group["curve"] != "ED-25519":
            continue
        if not group.get("preHash", False):
            continue

        d = list(bytes.fromhex(group["d"]))
        q = list(bytes.fromhex(group["q"]))
        for test in group["tests"]:
            msg_bytes = bytes.fromhex(test["message"])
            prehash = hashlib.sha512(msg_bytes).digest()
            context = list(bytes.fromhex(test.get("context", "")))
            test_vectors.append({
                "vendor": "acvp",
                "test_case_id": test["tcId"],
                "algorithm": "ed25519",
                "operation": "sign",
                "private_key": d,
                "public_key": q,
                "message": list(prehash),
                "context": context,
                "expected_signature": list(bytes.fromhex(test["signature"])),
                "result": True,
            })
    return test_vectors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--src",
        metavar="FILE",
        type=argparse.FileType("r"),
        help="Read test vectors from this JSON file.",
    )
    parser.add_argument(
        "--dst",
        metavar="FILE",
        type=argparse.FileType("w"),
        help="Write output to this file.",
    )
    parser.add_argument(
        "--schema",
        type=str,
        help="Testvector schema file",
    )
    parser.add_argument(
        "--test-type",
        type=str,
        choices=["sigver", "siggen"],
        required=True,
        help="Type of test vectors to parse",
    )
    args = parser.parse_args()

    data = json.load(args.src)
    args.src.close()

    if args.test_type == "sigver":
        testvecs = parse_sigver(data)
    elif args.test_type == "siggen":
        testvecs = parse_siggen(data)

    # Validate generated JSON
    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(testvecs, schema)

    print(f"Created {len(testvecs)} tests", file=sys.stderr)
    json.dump(testvecs, args.dst)
    args.dst.close()

    return 0


if __name__ == "__main__":
    sys.exit(main())
