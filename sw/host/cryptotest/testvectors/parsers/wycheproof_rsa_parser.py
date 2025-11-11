#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import json
import jsonschema
import logging
import math
import random
import sys

from cryptotest_util import str_to_byte_array

# Fix random seed to make order of primes found by
# add_crt_values_to_test_vector below deterministic.
random.seed(3329)


def add_crt_values_to_test_vector(test_vec):
    # Unpack the non-CRT test vector key
    n = int.from_bytes(test_vec["n"], "big")
    d = int.from_bytes(test_vec["d"], "big")
    e = test_vec["e"]

    # Use private and public exponent to compute k, a multiple of phi(n)
    k = d * e - 1

    # Find a square root of unity mod n not equal to 1 or -1 mod n. By CRT,
    # such a value is congruent to 1 mod p or 1 mod q, so computing a simple
    # GCD suffices to extract a cofactor.
    while True:
        # Choose g nonzero at random mod n
        g = random.randrange(2, n - 1)

        # Check x = g^(k/2), g^(k/4), etc.
        found = False
        test_exp = k
        while test_exp % 2 == 0:
            test_exp //= 2
            x = pow(g, test_exp, n)
            if x == 1 or x == n - 1:
                continue

            # Try to factor n using this value
            p = math.gcd(x - 1, n)
            if p != 1:
                found = True
                break

        # If we found a cofactor, we're done
        if found:
            break

    # Compute the other cofactor and remaining CRT values
    assert n % p == 0
    q = n // p
    d_p = d % (p - 1)
    d_q = d % (q - 1)
    i_q = pow(q, -1, p)

    # Now, we just need to attach the remaining values to the test vector
    rsa_bytes = int(test_vec["security_level"]) // 8
    test_vec["p"] = list(p.to_bytes(rsa_bytes // 2, "big"))
    test_vec["q"] = list(q.to_bytes(rsa_bytes // 2, "big"))
    test_vec["d_p"] = list(d_p.to_bytes(rsa_bytes // 2, "big"))
    test_vec["d_q"] = list(d_q.to_bytes(rsa_bytes // 2, "big"))
    test_vec["i_q"] = list(i_q.to_bytes(rsa_bytes // 2, "big"))

    # Attach leading zero byte if the MSb of any value is set
    for key in ["p", "q", "d_p", "d_q", "i_q"]:
        if test_vec[key][0] & 0x80 != 0:
            test_vec[key] = [0] + test_vec[key]


def parse_test_vectors(raw_data, args):
    test_groups = raw_data["testGroups"]
    test_vectors = list()
    for group in test_groups:
        # Parse tests within the group
        for test in group["tests"]:
            logging.debug(f"Parsing tcId {test['tcId']}")
            test_vec = {
                "vendor": "wycheproof",
                "test_case_id": test["tcId"],
                "algorithm": "rsa",
                "operation": args.operation,
                "padding": args.padding,
                "security_level": int(args.security_level),
                "hash_alg": group["sha"].lower().replace("shake", "shake-"),
                "message": str_to_byte_array(test["msg"]),
            }

            # Operation-specific variables
            if args.operation == "decrypt":
                test_vec["ciphertext"] = str_to_byte_array(test["ct"])
                test_vec["n"] = str_to_byte_array(group["privateKey"]["modulus"])
                test_vec["d"] = str_to_byte_array(group["privateKey"]["privateExponent"])
                test_vec["e"] = int(group["privateKey"]["publicExponent"], 16)
                test_vec["label"] = str_to_byte_array(test["label"])
                add_crt_values_to_test_vector(test_vec)
            elif args.operation == "verify":
                test_vec["signature"] = str_to_byte_array(test["sig"])
                test_vec["n"] = str_to_byte_array(group["publicKey"]["modulus"])
                test_vec["e"] = int(group["publicKey"]["publicExponent"], 16)
            else:
                raise ValueError(f"Unsupported RSA operation: {args.operation}")

            if test["result"] == "valid":
                test_vec["result"] = True
            elif test["result"] == "invalid":
                test_vec["result"] = False
            elif test["result"] == "acceptable":
                # Err on the side of caution and reject "acceptable" signatures
                test_vec["result"] = False
            else:
                raise RuntimeError(f"Unexpected result type {test['result']}")
            # Wycheproof "decrypt" test vectors include both the
            # public and private keys, so they can be used to test
            # both encryption and decryption. We split these up into
            # separate test vectors so that manual tests need not
            # needlessly include the private and public key for
            # encryption and decryption, respectively.
            test_vectors.append(test_vec)
            if args.operation == "decrypt":
                # Only include tests that are marked as "valid" for
                # testing encryption, since we don't know if the
                # reason for a test being invalid is in the message or
                # in the ciphertext we will not use.
                if test_vec["result"] is True:
                    # Deep copy test_vec
                    encrypt_test_vec = test_vec.copy()
                    encrypt_test_vec["operation"] = "encrypt"
                    test_vectors.append(encrypt_test_vec)

        return test_vectors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--src',
        metavar='FILE',
        type=argparse.FileType('r'),
        help='Read test vectors from this JSON file.'
    )
    parser.add_argument(
        '--dst',
        metavar='FILE',
        type=argparse.FileType('w'),
        help='Write output to this file.'
    )
    parser.add_argument(
        "--schema",
        type = str,
        help = "Testvector schema file"
    )
    parser.add_argument(
        "--operation",
        type = str,
        help = "RSA operation under test",
        choices = ["verify", "decrypt"],
    )
    parser.add_argument(
        "--padding",
        type = str,
        help = "Padding mode to use for 'verify' operation",
        choices = ["pkcs1_1.5", "pss", "oaep"],
    )
    parser.add_argument(
        "--security_level",
        type = str,
        help = "RSA security level",
        choices = ["2048", "3072", "4096"],
    )
    args = parser.parse_args()

    testvecs = parse_test_vectors(json.load(args.src), args)
    args.src.close()

    # Validate generated JSON
    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(testvecs, schema)

    logging.info(f"Created {len(testvecs)} tests")
    json.dump(testvecs, args.dst)
    args.dst.close()

    return 0


if __name__ == '__main__':
    sys.exit(main())
