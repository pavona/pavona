// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_CRYPTO_INCLUDE_ECC_P256_H_
#define OPENTITAN_SW_DEVICE_LIB_CRYPTO_INCLUDE_ECC_P256_H_

#include "datatypes.h"

/**
 * @file
 * @brief P-256 elliptic curve operations for OpenTitan cryptography library.
 *
 * Includes ECDSA and ECDH.
 */

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

/**
 * Constructs an ECDSA/ECDH P-256 public key from affine coordinates.
 *
 * The caller should allocate space for the public key and set the `key` and
 * `key_length` fields accordingly.
 *
 * @param size RSA size parameter.
 * @param x First affine coordinate of public key (x).
 * @param y Second affine coordinate of public key (y).
 * @param[out] public_key Destination public key struct.
 * @return Result of the P-256 key construction.
 */
otcrypto_status_t otcrypto_p256_public_key_construct(
    otcrypto_const_word32_buf_t x, otcrypto_const_word32_buf_t y,
    otcrypto_unblinded_key_t *public_key);

/**
 * Constructs an ECDSA/ECDH P-256 public key from affine coordinates, performing
 * an on-curve check on the constructed key.
 *
 * The caller should allocate space for the public key and set the `key` and
 * `key_length` fields accordingly.
 *
 * @param x First affine coordinate of public key (x).
 * @param y Second affine coordinate of public key (y).
 * @param[out] public_key Destination public key struct.
 * @param[out] key_valid Whether the constructed key is valid.
 * @return Result of the P-256 key construction.
 */
otcrypto_status_t otcrypto_p256_public_key_construct_and_check(
    otcrypto_const_word32_buf_t x, otcrypto_const_word32_buf_t y,
    otcrypto_unblinded_key_t *public_key, hardened_bool_t *key_valid);

/**
 * Starts an asynchronous public key check for ECDSA/P-256.
 *
 * See `otcrypto_p256_public_key_construct_and_check` for requirements on input
 * and output values.
 *
 * @param x First affine coordinate of public key (x).
 * @param y Second affine coordinate of public key (y).
 * @param[out] public_key Destination public key struct.
 * @param[out] key_valid Whether the constructed key is valid.
 * @param[out] session_token Session token for this operation.
 * @return Result of the P-256 key construction.
 */
otcrypto_status_t otcrypto_p256_public_key_construct_and_check_async_start(
    otcrypto_const_word32_buf_t x, otcrypto_const_word32_buf_t y,
    otcrypto_unblinded_key_t *public_key, hardened_bool_t *key_valid,
    otcrypto_session_token_t *session_token);

/**
 * Finalizes an asynchronous public key check for ECDSA/P-256.
 *
 * See `otcrypto_p256_public_key_construct_and_check` for requirements on input
 * and output values.
 *
 * @param session_token Session token for this operation.
 * @param[out] key_valid Whether the constructed key is valid.
 * @return Result of the P-256 key construction.
 */
otcrypto_status_t otcrypto_p256_public_key_construct_and_check_async_finalize(
    otcrypto_session_token_t session_token, hardened_bool_t *key_valid);

/**
 * Deconstructs an ECDSA/ECDH P-256 public key into affine coordinates.
 *
 * The caller should allocate space for both affine coordinates.
 *
 * @param public_key Destination public key struct.
 * @param[out] x First affine coordinate of public key (x).
 * @param[out] y Second affine coordinate of public key (y).
 * @return Result of the P-256 key deconstruction.
 */
otcrypto_status_t otcrypto_p256_public_key_deconstruct(
    const otcrypto_unblinded_key_t *public_key, otcrypto_word32_buf_t x,
    otcrypto_word32_buf_t y);

/*
 * Constructs an ECDSA/ECDH P-256 private key from scalar shares.
 *
 * The caller should allocate space for the private key and set the `keyblob`,
 * `keyblob_length`, and `config` fields accordingly.
 *
 * @param scalar_share0 First share of scalar (d).
 * @param scalar_share1 Second share of scalar (d).
 * @param[out] private_key Destination private key struct.
 * @return Result of the P-256 private key construction.
 */
otcrypto_status_t otcrypto_p256_private_key_construct(
    otcrypto_const_word32_buf_t scalar_share0,
    otcrypto_const_word32_buf_t scalar_share1,
    otcrypto_blinded_key_t *private_key);

/*
 * Deconstructs an ECDSA/ECDH P-256 private key into scalar shares.
 *
 * The caller should allocate space for both scalar shares.
 *
 * @param private_key Source private key struct.
 * @param[out] scalar_share0 First share of scalar (d).
 * @param[out] scalar_share1 Second share of scalar (d).
 * @return Result of the P-256 private key deconstruction.
 */
otcrypto_status_t otcrypto_p256_private_key_deconstruct(
    const otcrypto_blinded_key_t *private_key,
    otcrypto_word32_buf_t scalar_share0, otcrypto_word32_buf_t scalar_share1);

/**
 * Generates a key pair for ECDSA with curve P-256.
 *
 * The caller should allocate and partially populate the blinded key struct,
 * including populating the key configuration and allocating space for the
 * keyblob. For a hardware-backed key, use the private key handle returned by
 * `otcrypto_hw_backed_key`. Otherwise, the mode should indicate ECDSA with
 * P-256 and the keyblob should be 80 bytes. The value in the `checksum` field
 * of the blinded key struct will be populated by the key generation function.
 *
 * @param[out] private_key Pointer to the blinded private key (d) struct.
 * @param[out] public_key Pointer to the unblinded public key (Q) struct.
 * @return Result of the ECDSA key generation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdsa_p256_keygen(
    otcrypto_blinded_key_t *private_key, otcrypto_unblinded_key_t *public_key);

/**
 * Generates an ECDSA signature with curve P-256.
 *
 * The message digest must be exactly 256 bits (32 bytes) long, but may use any
 * hash mode. The caller is responsible for ensuring that the security
 * strength of the hash function is at least equal to the security strength of
 * the curve, but in some cases it may be truncated. See FIPS 186-5 for
 * details.
 *
 * @param private_key Pointer to the blinded private key (d) struct.
 * @param message_digest Message digest to be signed (pre-hashed).
 * @param[out] signature Pointer to the signature struct with (r,s) values.
 * @return Result of the ECDSA signature generation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdsa_p256_sign(
    const otcrypto_blinded_key_t *private_key,
    const otcrypto_hash_digest_t message_digest,
    otcrypto_word32_buf_t signature);

/**
 * Signs with the current ECDSA attestation private key.
 *
 * Curve is fixed to P-256. The message digest must be exactly 256 bits and
 * must use SHA-256 as the hash mode.
 *
 * In order to build a new link in the attestation chain, the caller must
 * ensure that the hash is the digest of a certificate that includes
 * hardware-backed public keys *from the same device as the attestation key*.
 *
 * @param message_digest Message digest to be signed (pre-hashed).
 * @param[out] signature Pointer to the signature struct with (r,s) values.
 * @return Result of the ECDSA signature generation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdsa_p256_attestation_endorse(
    const otcrypto_hash_digest_t message_digest,
    otcrypto_word32_buf_t signature);

/**
 * Generates an ECDSA signature with curve P-256 and verifies the signature
 * before releasing it to mitigate fault injection attacks.
 *
 * The message digest must be exactly 256 bits (32 bytes) long, but may use any
 * hash mode. The caller is responsible for ensuring that the security
 * strength of the hash function is at least equal to the security strength of
 * the curve, but in some cases it may be truncated. See FIPS 186-5 for
 * details.
 *
 * @param private_key Pointer to the blinded private key (d) struct.
 * @param public_key Pointer to the unblinded public key (Q) struct.
 * @param message_digest Message digest to be signed (pre-hashed).
 * @param[out] signature Pointer to the signature struct with (r,s) values.
 * @return Result of the ECDSA signature generation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdsa_p256_sign_verify(
    const otcrypto_blinded_key_t *private_key,
    const otcrypto_unblinded_key_t *public_key,
    const otcrypto_hash_digest_t message_digest,
    otcrypto_word32_buf_t signature);

/**
 * Verifies an ECDSA/P-256 signature.
 *
 * The message digest must be exactly 256 bits (32 bytes) long, but may use any
 * hash mode. The caller is responsible for ensuring that the security
 * strength of the hash function is at least equal to the security strength of
 * the curve, but in some cases it may be truncated. See FIPS 186-5 for
 * details.
 *
 * The caller must check the `verification_result` parameter, NOT only the
 * returned status code, to know if the signature passed verification. The
 * status code, as for other operations, only indicates whether errors were
 * encountered, and may return OK even when the signature is invalid.
 *
 * @param public_key Pointer to the unblinded public key (Q) struct.
 * @param message_digest Message digest to be verified (pre-hashed).
 * @param signature Pointer to the signature to be verified.
 * @param[out] verification_result Whether the signature passed verification.
 * @return Result of the ECDSA verification operation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdsa_p256_verify(
    const otcrypto_unblinded_key_t *public_key,
    const otcrypto_hash_digest_t message_digest,
    otcrypto_const_word32_buf_t signature,
    hardened_bool_t *verification_result);

/**
 * Generates a key pair for ECDH with curve P-256.
 *
 * The caller should allocate and partially populate the blinded key struct,
 * including populating the key configuration and allocating space for the
 * keyblob. For a hardware-backed key, use the private key handle returned by
 * `otcrypto_hw_backed_key`. Otherwise, the mode should indicate ECDH with
 * P-256 and the keyblob should be 80 bytes. The value in the `checksum` field
 * of the blinded key struct will be populated by the key generation function.
 *
 * @param[out] private_key Pointer to the blinded private key (d) struct.
 * @param[out] public_key Pointer to the unblinded public key (Q) struct.
 * @return Result of the ECDH key generation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdh_p256_keygen(
    otcrypto_blinded_key_t *private_key, otcrypto_unblinded_key_t *public_key);

/**
 * Elliptic Curve Diffie Hellman shared secret generation with curve P-256.
 *
 * @param private_key Pointer to the blinded private key (d) struct.
 * @param public_key Pointer to the unblinded public key (Q) struct.
 * @param[out] shared_secret Pointer to generated blinded shared key struct.
 * @return Result of ECDH shared secret generation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdh_p256(const otcrypto_blinded_key_t *private_key,
                                     const otcrypto_unblinded_key_t *public_key,
                                     otcrypto_blinded_key_t *shared_secret);

/**
 * Starts asynchronous key generation for ECDSA/P-256.
 *
 * See `otcrypto_ecdsa_p256_keygen` for requirements on input values.
 *
 * @param private_key Destination structure for private key, or key handle.
 * @param[out] session_token Session token for this operation.
 * @return Result of asynchronous ECDSA keygen start operation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdsa_p256_keygen_async_start(
    const otcrypto_blinded_key_t *private_key,
    otcrypto_session_token_t *session_token);

/**
 * Finalizes asynchronous key generation for ECDSA/P-256.
 *
 * See `otcrypto_ecdsa_p256_keygen` for requirements on input values.
 *
 * May block until the operation is complete.
 *
 * The caller should ensure that the private key configuration matches that
 * passed to the `_start` function.
 *
 * @param session_token Session token for this operation.
 * @param[out] private_key Pointer to the blinded private key (d) struct.
 * @param[out] public_key Pointer to the unblinded public key (Q) struct.
 * @return Result of asynchronous ECDSA keygen finalize operation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdsa_p256_keygen_async_finalize(
    otcrypto_session_token_t session_token, otcrypto_blinded_key_t *private_key,
    otcrypto_unblinded_key_t *public_key);

/**
 * Starts asynchronous signature generation for ECDSA/P-256.
 *
 * See `otcrypto_ecdsa_p256_sign` for requirements on input values.
 *
 * @param private_key Pointer to the blinded private key (d) struct.
 * @param message_digest Message digest to be signed (pre-hashed).
 * @param[out] session_token Session token for this operation.
 * @return Result of async ECDSA start operation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdsa_p256_sign_async_start(
    const otcrypto_blinded_key_t *private_key,
    const otcrypto_hash_digest_t message_digest,
    otcrypto_session_token_t *session_token);

/**
 * Finalizes asynchronous signature generation for ECDSA/P-256.
 *
 * See `otcrypto_ecdsa_p256_sign` for requirements on input values.
 *
 * May block until the operation is complete.
 *
 * @param session_token Session token for this operation.
 * @param[out] signature Pointer to the signature struct with (r,s) values.
 * @return Result of async ECDSA finalize operation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdsa_p256_sign_async_finalize(
    otcrypto_session_token_t session_token, otcrypto_word32_buf_t signature);

/**
 * Starts the asynchronous attestation signature generation.
 *
 * Curve is fixed to P-256. The message digest must be exactly 256 bits and
 * must use SHA-256 as the hash mode.
 *
 * In order to build a new link in the attestation chain, the caller must
 * ensure that the hash is the digest of a certificate that includes
 * hardware-backed public keys *from the same device as the attestation key*.
 *
 * @param message_digest Message digest to be signed (pre-hashed).
 * @param[out] session_token Session token for this operation.
 * @return Result of the ECDSA signature generation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdsa_p256_attestation_endorse_async_start(
    const otcrypto_hash_digest_t message_digest,
    otcrypto_session_token_t *session_token);

/**
 * Finalizes the asynchronous attestation signature generation.
 *
 * @param session_token Session token for this operation.
 * @param[out] signature Pointer to the signature struct with (r,s) values.
 * @return Result of the ECDSA signature generation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdsa_p256_attestation_endorse_async_finalize(
    otcrypto_session_token_t session_token, otcrypto_word32_buf_t signature);

/**
 * Starts asynchronous signature verification for ECDSA/P-256.
 *
 * See `otcrypto_ecdsa_p256_verify` for requirements on input values.
 *
 * @param public_key Pointer to the unblinded public key (Q) struct.
 * @param message_digest Message digest to be verified (pre-hashed).
 * @param signature Pointer to the signature to be verified.
 * @param[out] session_token Session token for this operation.
 * @return Result of async ECDSA verify start function.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdsa_p256_verify_async_start(
    const otcrypto_unblinded_key_t *public_key,
    const otcrypto_hash_digest_t message_digest,
    otcrypto_const_word32_buf_t signature,
    otcrypto_session_token_t *session_token);

/**
 * Finalizes asynchronous signature verification for ECDSA/P-256.
 *
 * See `otcrypto_ecdsa_p256_verify` for requirements on input values.
 *
 * May block until the operation is complete.
 *
 * The caller must check the `verification_result` parameter, NOT only the
 * returned status code, to know if the signature passed verification. The
 * status code, as for other operations, only indicates whether errors were
 * encountered, and may return OK even when the signature is invalid.
 *
 * @param signature Pointer to the signature which was verified.
 * @param session_token Session token for this operation.
 * @param[out] verification_result Whether the signature passed verification.
 * @return Result of async ECDSA verify finalize operation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdsa_p256_verify_async_finalize(
    otcrypto_const_word32_buf_t signature,
    otcrypto_session_token_t session_token,
    hardened_bool_t *verification_result);

/**
 * Starts asynchronous key generation for ECDH/P-256.
 *
 * See `otcrypto_ecdh_p256_keygen` for requirements on input values.
 *
 * @param private_key Destination structure for private key, or key handle.
 * @param[out] session_token Session token for this operation.
 * @return Result of asynchronous ECDH keygen start operation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdh_p256_keygen_async_start(
    const otcrypto_blinded_key_t *private_key,
    otcrypto_session_token_t *session_token);

/**
 * Finalizes asynchronous key generation for ECDH/P-256.
 *
 * See `otcrypto_ecdh_p256_keygen` for requirements on input values.
 *
 * May block until the operation is complete.
 *
 * The caller should ensure that the private key configuration matches that
 * passed to the `_start` function.
 *
 * @param session_token Session token for this operation.
 * @param[out] private_key Pointer to the blinded private key (d) struct.
 * @param[out] public_key Pointer to the unblinded public key (Q) struct.
 * @return Result of asynchronous ECDH keygen finalize operation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdh_p256_keygen_async_finalize(
    otcrypto_session_token_t session_token, otcrypto_blinded_key_t *private_key,
    otcrypto_unblinded_key_t *public_key);

/**
 * Starts asynchronous shared secret generation for ECDH/P-256.
 *
 * See `otcrypto_ecdh_p256` for requirements on input values.
 *
 * @param private_key Pointer to the blinded private key (d) struct.
 * @param public_key Pointer to the unblinded public key (Q) struct.
 * @param[out] session_token Session token for this operation.
 * @return Result of async ECDH start operation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdh_p256_async_start(
    const otcrypto_blinded_key_t *private_key,
    const otcrypto_unblinded_key_t *public_key,
    otcrypto_session_token_t *session_token);

/**
 * Finalizes asynchronous shared secret generation for ECDH/P-256.
 *
 * See `otcrypto_ecdh_p256` for requirements on input values.
 *
 * May block until the operation is complete.
 *
 * @param private_key Pointer to the blinded private key (d) struct.
 * @param session_token Session token for this operation.
 * @param[out] shared_secret Pointer to generated blinded shared key struct.
 * @return Result of async ECDH finalize operation.
 */
OT_WARN_UNUSED_RESULT
otcrypto_status_t otcrypto_ecdh_p256_async_finalize(
    const otcrypto_blinded_key_t *private_key,
    otcrypto_session_token_t session_token,
    otcrypto_blinded_key_t *shared_secret);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_LIB_CRYPTO_INCLUDE_ECC_P256_H_
