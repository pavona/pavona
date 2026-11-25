#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP RSA prompts to JSON."""

import argparse
import json
import sys

import jsonschema

from acvp_util import acvp_common, apply_expected, load_vector_set

HASH_ALGS = {
    "SHA2-256": "sha-256",
    "SHA2-384": "sha-384",
    "SHA2-512": "sha-512",
    "SHA3-224": "sha3-224",
    "SHA3-256": "sha3-256",
    "SHA3-384": "sha3-384",
    "SHA3-512": "sha3-512",
}

DIGEST_BYTES = {
    "SHA2-256": 32,
    "SHA2-384": 48,
    "SHA2-512": 64,
    "SHA3-224": 28,
    "SHA3-256": 32,
    "SHA3-384": 48,
    "SHA3-512": 64,
}

PADDINGS = {
    "pkcs1v1.5": "pkcs1_1.5",
    "pss": "pss",
}


def signature_scheme(where, group):
    """Returns the padding and hash of a signature test group."""
    hash_alg = group["hashAlg"]
    if hash_alg not in HASH_ALGS:
        raise SystemExit(f"{where}: {hash_alg} is not implemented")
    sig_type = group["sigType"]
    if sig_type not in PADDINGS:
        raise SystemExit(f"{where}: {sig_type} is not implemented")
    if sig_type == "pss":
        if group["maskFunction"] != "mgf1":
            raise SystemExit(f"{where}: mask functions other than MGF1 are not implemented")
        if group["saltLen"] != DIGEST_BYTES[hash_alg]:
            raise SystemExit(f"{where}: salts other than the digest length are not "
                             "implemented")
    if "conformance" in group:
        raise SystemExit(f"{where}: {group['conformance']} is not implemented")
    return PADDINGS[sig_type], HASH_ALGS[hash_alg]


def parse_keygen(data):
    """Parse an RSA keyGen prompt. Response: n, e, p, q, dmp1, dmq1, iqmp."""
    if data["revision"] != "FIPS186-5":
        raise SystemExit("parse_keygen: only revision FIPS186-5 is implemented")
    test_vectors = []
    for group in data["testGroups"]:
        if group["randPQ"] != "probable":
            raise SystemExit("parse_keygen: primes other than probable primes are not "
                             "implemented")
        if group["keyFormat"] != "crt":
            raise SystemExit("parse_keygen: key formats other than CRT are not implemented")
        if group["pubExp"] != "fixed" or group["fixedPubExp"] != "010001":
            raise SystemExit("parse_keygen: public exponents other than 65537 are not "
                             "implemented")
        if group["primeTest"] != "2powSecStr":
            raise SystemExit("parse_keygen: prime tests other than 2powSecStr are not "
                             "implemented")
        if group["pMod8"] != 0 or group["qMod8"] != 0:
            raise SystemExit("parse_keygen: primes with a fixed residue mod 8 are not "
                             "implemented")
        for test in group["tests"]:
            test_vectors.append({
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "operation": "keygen",
                "padding": "pkcs1_1.5",
                "security_level": group["modulo"],
            })
    return test_vectors


def parse_siggen(data):
    """Parse an RSA sigGen prompt. Response: n and e per group, signature."""
    if data["revision"] != "FIPS186-5":
        raise SystemExit("parse_siggen: only revision FIPS186-5 is implemented")
    test_vectors = []
    for group in data["testGroups"]:
        padding, hash_alg = signature_scheme("parse_siggen", group)
        for test in group["tests"]:
            test_vectors.append({
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "operation": "keygen_sign",
                "padding": padding,
                "security_level": group["modulo"],
                "hash_alg": hash_alg,
                "message": list(bytes.fromhex(test["message"])),
                # The signature must verify with the device's public key.
                "result": True,
            })
    return test_vectors


def parse_sigver(data):
    """Parse an RSA sigVer prompt. Response: testPassed."""
    if data["revision"] != "FIPS186-5":
        raise SystemExit("parse_sigver: only revision FIPS186-5 is implemented")
    test_vectors = []
    for group in data["testGroups"]:
        padding, hash_alg = signature_scheme("parse_sigver", group)
        n = bytes.fromhex(group["n"])
        e = int(group["e"], 16)
        for test in group["tests"]:
            test_vectors.append({
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "operation": "verify",
                "padding": padding,
                "security_level": group["modulo"],
                "hash_alg": hash_alg,
                "message": list(bytes.fromhex(test["message"])),
                "n": list(n),
                "e": e,
                "signature": list(bytes.fromhex(test["signature"])),
            })
    return test_vectors


def associated_data(group):
    """Assembles the associated data of a KTS-IFC test group."""
    config = group["ktsConfiguration"]
    if config["encoding"] == "none" and config["associatedDataPattern"] == "":
        return b""
    if config["encoding"] != "concatenation":
        raise SystemExit("parse_kts: encodings other than concatenation are not implemented")
    # The initiator is party U and the responder is party V.
    if group["kasRole"] == "initiator":
        parts = {"uPartyInfo": group["iutId"], "vPartyInfo": group["serverId"]}
    else:
        parts = {"uPartyInfo": group["serverId"], "vPartyInfo": group["iutId"]}
    data = b""
    for field in config["associatedDataPattern"].split("||"):
        if field not in parts:
            raise SystemExit(f"parse_kts: associated data field {field} is not implemented")
        data += bytes.fromhex(parts[field])
    return data


def parse_kts(data, expected_path):
    """Parse a KTS-IFC prompt or internalProjection.
    Response: iutC and dkm for the initiator, dkm for the responder."""
    if data["revision"] != "Sp800-56Br2":
        raise SystemExit("parse_kts: only revision Sp800-56Br2 is implemented")
    answers = {}
    if expected_path is not None:
        answers = {test["tcId"]: test
                   for group in load_vector_set(expected_path)["testGroups"]
                   for test in group["tests"]}
    test_vectors = []
    for group in data["testGroups"]:
        if group["scheme"] != "KTS-OAEP-basic":
            raise SystemExit("parse_kts: schemes other than KTS-OAEP-basic are not implemented")
        if group["keyGenerationMethod"] != "rsakpg1-crt":
            raise SystemExit("parse_kts: key formats other than CRT are not implemented")
        config = group["ktsConfiguration"]
        if config["hashAlg"] not in HASH_ALGS:
            raise SystemExit(f"parse_kts: {config['hashAlg']} is not implemented")
        label = associated_data(group)
        for test in group["tests"]:
            vector = {
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "padding": "oaep",
                "security_level": group["modulo"],
                "hash_alg": HASH_ALGS[config["hashAlg"]],
                "label": list(label),
            }
            if group["kasRole"] == "initiator":
                vector.update({
                    "operation": "encrypt_random",
                    "n": list(bytes.fromhex(test["serverN"])),
                    "e": int(test["serverE"], 16),
                    "message_len": group["l"] // 8,
                })
                # The server's private key, to decrypt the device's ciphertext.
                if "serverP" in test:
                    vector.update({
                        "p": list(bytes.fromhex(test["serverP"])),
                        "q": list(bytes.fromhex(test["serverQ"])),
                        "result": True,
                    })
            else:
                vector.update({
                    "operation": "decrypt",
                    "n": list(bytes.fromhex(test["iutN"])),
                    "e": int(test["iutE"], 16),
                    "p": list(bytes.fromhex(test["iutP"])),
                    "q": list(bytes.fromhex(test["iutQ"])),
                    "d_p": list(bytes.fromhex(test["iutDmp1"])),
                    "d_q": list(bytes.fromhex(test["iutDmq1"])),
                    "i_q": list(bytes.fromhex(test["iutIqmp"])),
                    "ciphertext": list(bytes.fromhex(test["serverC"])),
                })
                dkm = answers.get(test["tcId"], test).get("dkm")
                if dkm is not None:
                    vector["message"] = list(bytes.fromhex(dkm))
                    vector["result"] = True
            test_vectors.append(vector)
    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for ACVP RSA prompts.")
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
        choices=["keygen", "kts", "siggen", "sigver"],
        required=True,
        help="Type of test vectors to parse.",
    )
    args = parser.parse_args()

    raw_data = load_vector_set(args.src)
    if args.test_type == "keygen":
        test_vectors = parse_keygen(raw_data)
    elif args.test_type == "siggen":
        test_vectors = parse_siggen(raw_data)
    elif args.test_type == "sigver":
        test_vectors = parse_sigver(raw_data)
    elif args.test_type == "kts":
        test_vectors = parse_kts(raw_data, args.expected)
    if args.test_type != "kts":
        apply_expected(test_vectors, args.expected)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    with open(args.dst, "w") as dst:
        json.dump(test_vectors, dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
