# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

SECP256K1_P = int(
    "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f", 16)
SECP256K1_N = int(
    "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141", 16)
SECP256K1_G = (
    int("79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
        16),
    int("483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8",
        16),
)

_ID_EC_PUBLIC_KEY_OID_DER = bytes.fromhex("06072a8648ce3d0201")
_SECP256K1_OID_DER = bytes.fromhex("06052b8104000a")


def _read_der_len(data, idx):
    if idx >= len(data):
        raise ValueError("Missing DER length")
    first = data[idx]
    idx += 1
    if first < 0x80:
        return first, idx
    count = first & 0x7f
    if count == 0 or idx + count > len(data):
        raise ValueError("Invalid DER length")
    return int.from_bytes(data[idx:idx + count], "big"), idx + count


def _read_der_tlv(data, idx):
    if idx >= len(data):
        raise ValueError("Missing DER tag")
    tag = data[idx]
    length, value_idx = _read_der_len(data, idx + 1)
    end = value_idx + length
    if end > len(data):
        raise ValueError("DER value extends past end of data")
    return tag, data[value_idx:end], end


def _mod_inv(x, modulus):
    return pow(x, -1, modulus)


def _point_add(point_a, point_b):
    if point_a is None:
        return point_b
    if point_b is None:
        return point_a
    x1, y1 = point_a
    x2, y2 = point_b
    if x1 == x2 and (y1 + y2) % SECP256K1_P == 0:
        return None
    if point_a == point_b:
        slope = (3 * x1 * x1 * _mod_inv(2 * y1, SECP256K1_P)) % SECP256K1_P
    else:
        slope = ((y2 - y1) * _mod_inv(x2 - x1, SECP256K1_P)) % SECP256K1_P
    x3 = (slope * slope - x1 - x2) % SECP256K1_P
    y3 = (slope * (x1 - x3) - y1) % SECP256K1_P
    return x3, y3


def _point_mul(scalar, point):
    result = None
    addend = point
    while scalar:
        if scalar & 1:
            result = _point_add(result, addend)
        addend = _point_add(addend, addend)
        scalar >>= 1
    return result


def _random_scalar(random):
    while True:
        scalar = int.from_bytes(random(32), "big")
        if 0 < scalar < SECP256K1_N:
            return scalar


def _decompress_point(prefix, x):
    rhs = (pow(x, 3, SECP256K1_P) + 7) % SECP256K1_P
    y = pow(rhs, (SECP256K1_P + 1) // 4, SECP256K1_P)
    if (y & 1) != (prefix & 1):
        y = SECP256K1_P - y
    return y


def _digest_to_z(digest):
    digest_bytes = digest.digest()
    return int.from_bytes(digest_bytes[:32], "big")


def parse_public_key(der):
    tag, spki, end = _read_der_tlv(der, 0)
    if tag != 0x30 or end != len(der):
        raise ValueError("Invalid SubjectPublicKeyInfo sequence")

    tag, alg, idx = _read_der_tlv(spki, 0)
    if tag != 0x30:
        raise ValueError("Invalid algorithm identifier")
    if (_ID_EC_PUBLIC_KEY_OID_DER not in alg or
            _SECP256K1_OID_DER not in alg):
        raise ValueError("Unexpected secp256k1 public-key OID")

    tag, bit_string, end = _read_der_tlv(spki, idx)
    if tag != 0x03 or end != len(spki):
        raise ValueError("Invalid public-key bit string")
    if len(bit_string) == 0 or bit_string[0] != 0:
        raise ValueError("Unsupported public-key bit string padding")

    encoded = bit_string[1:]
    if len(encoded) == 65 and encoded[0] == 4:
        return encoded[1:33], encoded[33:65]
    if len(encoded) == 33 and encoded[0] in (2, 3):
        x = int.from_bytes(encoded[1:], "big")
        y = _decompress_point(encoded[0], x)
        return encoded[1:], y.to_bytes(32, "big")
    raise ValueError("Unsupported secp256k1 point encoding")


def sign(private_key, digest, random):
    z = _digest_to_z(digest)
    while True:
        k = _random_scalar(random)
        point = _point_mul(k, SECP256K1_G)
        r = point[0] % SECP256K1_N
        if r == 0:
            continue
        s = (_mod_inv(k, SECP256K1_N) *
             (z + r * private_key)) % SECP256K1_N
        if s == 0:
            continue
        return r.to_bytes(32, "big") + s.to_bytes(32, "big")


def generate_key(random):
    private_key = _random_scalar(random)
    public_key = _point_mul(private_key, SECP256K1_G)
    return private_key, public_key
