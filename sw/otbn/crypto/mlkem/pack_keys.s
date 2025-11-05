/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028) */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */

.text

/*
 * Name:        poly_tobytes
 *
 * Description: Serialization of a polynomial
 *
 * Arguments:   - uint8_t r: output byte array (KYBER_POLYBYTES=384 bytes)
 *              - const poly a: input polynomial, n=256, q=3329
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input polynomial
 * @param[out]  x13: dptr_output, dmem pointer to output
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x9, w0-w5, w31
 */

poly_tobytes:
  LOOPI 4, 37
    /* Load inputs */
    bn.lid x4, 0(x10++)
    bn.lid x5, 0(x10++)
    bn.lid x6, 0(x10++)
    bn.lid x7, 0(x10++)

    /* Reduce inputs to [0,q). This is because outputs of NTT without final conditional subtraction
     * in Montgomery multiplication are in [0,2q). */
    bn.addvm.16H w0, w0, w31
    bn.addvm.16H w1, w1, w31
    bn.addvm.16H w2, w2, w31
    bn.addvm.16H w3, w3, w31

    /* First 32 bytes */
    LOOPI 16, 2                    /* 16 coeffs in w0 = 24 bytes: 8 bytes left */
      bn.rshi w5, w0, w5 >> 12   /* write one coeff (12 bits) */
      bn.rshi w0, w31, w0 >> 16  /* shift out used coeff */
    LOOPI 5, 2                   /* 5 coeffs in w1 = 6 bytes + 12 bits: 4 bits left */
      bn.rshi w5, w1, w5 >> 12
      bn.rshi w1, w31, w1 >> 16
    bn.rshi w5, w1, w5 >> 4      /* write first 4 bits of 6th coeff of w1 to w5 */
    bn.rshi w1, w31, w1 >> 4     /* shift out 4 used bits */
    bn.sid  x9, 0(x13++)        /* store the first 32 bytes to dmem */

    /* Second 32 bytes */
    bn.rshi w5, w1, w5 >> 8      /* write the next 8 bits of 6th coeff of w1 to w5 */
    bn.rshi w1, w31, w1  >> 12   /* shift out used byte */
    LOOPI 10, 2                     /* there are 10 coeffs left in w1 = 15 bytes */
      bn.rshi w5, w1, w5 >> 12
      bn.rshi w1, w31, w1 >> 16
    LOOPI 10, 2                     /* 16 bytes of w5 are used. 10 coeffs of w2 = 15 bytes */
      bn.rshi w5, w2, w5 >> 12
      bn.rshi w2, w31, w2 >> 16
    bn.rshi w5, w2, w5 >> 8      /* write the first 8 bits of 11th coeff of w2 to w5 */
    bn.rshi w2, w31, w2 >> 8     /* shift out used byte */
    bn.sid  x9, 0(x13++)        /* store the second 32 bytes to dmem */

    /* The last 32 bytes */
    bn.rshi w5, w2, w5 >> 4      /* write the next 4 bits of 11th coeff of w2 to w5 */
    bn.rshi w2, w31, w2 >> 8     /* shift out used byte */
    LOOPI 5, 2                      /* there are 5 coeffs left in w2 = 7 bytes + 4 bits */
      bn.rshi w5, w2, w5 >> 12
      bn.rshi w2, w31, w2 >> 16
    LOOPI 16, 2                     /* there are 24 bytes left in w5 = 16 coeffs of w3 */
      bn.rshi w5, w3, w5 >> 12
      bn.rshi w3, w31, w3 >> 16
    bn.sid x9, 0(x13++)
  ret

/*
 * Name:        pack_pk
 *
 * Description: Serialize the public key as concatenation of the
 *              serialized vector of polynomials pk
 *              and the public seed used to generate the matrix A.
 *
 * Arguments:   - uint8_t *r: pointer to the output serialized public key
 *              - polyvec *pk: pointer to the input public-key polyvec
 *              - const uint8_t *seed: pointer to the input public seed
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input pk
 * @param[in]  x11: dptr_seed, dmem pointer to input public seed
 * @param[in]  x12: modulus_bn
 * @param[out] x13; dptr_output, dmem pointer to output serialized pk
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x9, w0-w5, w31
 */

.globl pack_pk
pack_pk:
  /* Set up wide registers for input and output */
  li x4, 0
  li x5, 1
  li x6, 2
  li x7, 3
  li x9, 5

  /* Zeroize w31 */
  bn.xor w31, w31, w31

  /* Pack polyvec pk */
  .rept KYBER_K
    jal x1, poly_tobytes
  .endr

  /* Pack seed */
  bn.lid x9, 0(x11)
  bn.sid x9, 0(x13)

  ret

/*
 * Name:        pack_sk
 *
 * Description: Serialize the secret key
 *
 * Arguments:   - uint8_t *r: pointer to output serialized secret key
 *              - polyvec *sk: pointer to input vector of polynomials (secret key)
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input sk
 * @param[in]  x12: modulus_bn
 * @param[out] x13: dptr_output, dmem pointer to output serialized sk
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x9, w0-w5, w31
 */

.globl pack_sk
pack_sk:
  /* Set up wide registers for input and output */
  li x4, 0
  li x5, 1
  li x6, 2
  li x7, 3
  li x9, 5

  /* Zeroize w31 */
  bn.xor w31, w31, w31

  /* Pack polyvec sk */
  .rept KYBER_K
    jal x1, poly_tobytes
  .endr

  ret

/*
 * Name:        poly_frombytes
 *
 * Description: De-serialization of a polynomial; inverse of poly_tobytes
 *
 * Arguments:   - uint8_t r: input byte array (KYBER_POLYBYTES=384 bytes)
 *              - poly a: output polynomial, n=256, q=3329
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input byte array
 * @param[out] x12: dptr_output, dmem pointer to output
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x8, w0-w4, w31
 */

poly_frombytes:
  LOOPI 4, 35
    /* Load inputs */
    bn.lid x4, 0(x10++)
    bn.lid x5, 0(x10++)
    bn.lid x6, 0(x10++)

    /* First 16 coeffs = 24 bytes */
    LOOPI 16, 2
      bn.rshi w4, w0, w4 >> 16
      bn.rshi w0, w31, w0 >> 12
    bn.and w4, w4, w3
    bn.sid x8, 0(x12++)

    /* Second 16 coeffs = 24 bytes (8 bytes w0 + 16 bytes w1)*/
    LOOPI 5, 2
      bn.rshi w4, w0, w4 >> 16
      bn.rshi w0, w31, w0 >> 12
    bn.rshi w4, w0, w4 >> 4
    bn.rshi w4, w1, w4 >> 12
    bn.rshi w1, w31, w1 >> 8
    LOOPI 10, 2
      bn.rshi w4, w1, w4 >> 16
      bn.rshi w1, w31, w1 >> 12
    bn.and w4, w4, w3
    bn.sid x8, 0(x12++)

    /* Third 16 coeffs = 24 bytes (16 bytes w1 + 8 bytes w2) */
    LOOPI 10, 2
      bn.rshi w4, w1, w4 >> 16
      bn.rshi w1, w31, w1 >> 12
    bn.rshi w4, w1, w4 >> 8
    bn.rshi w4, w2, w4 >> 8
    bn.rshi w2, w31, w2 >> 4
    LOOPI 5, 2
      bn.rshi w4, w2, w4 >> 16
      bn.rshi w2, w31, w2 >> 12
    bn.and w4, w4, w3
    bn.sid x8, 0(x12++)

    /* Fourth 16 coeffs = 24 bytes (24 bytes w2) */
    LOOPI 16, 2
      bn.rshi w4, w2, w4 >> 16
      bn.rshi w2, w31, w2 >> 12
    bn.and w4, w4, w3
    bn.sid x8, 0(x12++)
  ret

/*
 * Name:        unpack_pk
 *
 * Description: De-serialize public key from a byte array;
 *              approximate inverse of pack_pk
 *
 * Arguments:   - polyvec *pk: pointer to output public-key polynomial vector
 *              - uint8_t *seed: pointer to output seed to generate matrix A
 *              - const uint8_t *packedpk: pointer to input serialized public key
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input serialized pk
 * @param[out] x12: dptr_output, dmem pointer to output polyvec pk
 * @param[in]  x13: dptr_const_0x0fff
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x8, w0-w5, w31
 */

.globl unpack_pk
unpack_pk:
  /* Set up wide registers for input and output */
  li x4, 0
  li x5, 1
  li x6, 2
  li x7, 3
  li x8, 4

  /* Load constant */
  bn.lid x7, 0(x13)

  /* Unpack pk */
  .rept KYBER_K
    jal x1, poly_frombytes
  .endr

  /* Unpack seed */
  /* There's no need to unpack seed. Once pk is sent, client
     only needs to unpack pk to polynomials and use the attached
     seed directly for matrix generation. */

  ret

/*
 * Name:        unpack_sk
 *
 * Description: Deserialize the secret key
 *
 * Arguments:   - polyvec *sk: pointer to output vector of polynomials (secret key)
 *              - const uint8_t *packedsk: pointer to input serialized secret key
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input serialized sk
 * @param[in]  x15: dptr_modulus, dmem pointer to const_0x0fff
 * @param[out]  x12: dptr_output, dmem pointer to output polyvec sk
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x8, w0-w5, w31
 */

.globl unpack_sk
unpack_sk:
  /* Set up wide registers for input and output */
  li x4, 0
  li x5, 1
  li x6, 2
  li x7, 3
  li x8, 4

  /* Load constant */
  bn.lid x7, 0(x15)

  /* Unpack sk */
  .rept KYBER_K
    jal x1, poly_frombytes
  .endr

  ret
