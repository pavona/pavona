/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#if (KYBER_K == 2)
#define KYBER_POLYVECCOMPRESSED_LOOP 4
#elif (KYBER_K == 3)
#define KYBER_POLYVECCOMPRESSED_LOOP 6
#endif 

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
  LOOPI 4, 33
    /* Load inputs */
    bn.lid x4, 0(x10++)
    bn.lid x5, 0(x10++)
    bn.lid x6, 0(x10++)
    bn.lid x7, 0(x10++)

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

/*
 * Name:        poly_compress
 *
 * Description: Compression and subsequent serialization of a polynomial
 *
 * Arguments:   - uint8_t r: output byte array (of length KYBER_POLYCOMPRESSEDBYTES)
 *              - poly a: input polynomial, n=256, q=3329
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x11: dptr_input, dmem pointer to input polynomial
 * @param[out] x12: dptr_output, dmem pointer to output byte array
 * @param[in]  x13 (w3): const_80635
 * @param[in]  x14 (w6): modulus_bn
 * @param[in]  x15 (w2): dptr_modulus_over_2
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 */

poly_compress:
#if (KYBER_K == 2 || KYBER_K == 3)
  bn.rshi w3, w31, w3 >> 4 /* 80635 */
  LOOPI 4, 17
    LOOPI 4, 15
      bn.lid       x4, 0(x11++)  /* Load input */
      bn.shv.16H   w0, w0 << 4   /* <= 4 */ 
      bn.addv.16H  w0, w0, w2    /* += 1665 */
      LOOPI 2, 10
        LOOPI 8, 3
          bn.rshi    w1, w0, w1 >> 16  /* write one coeff to w1 */
          bn.rshi    w1, w31, w1 >> 16 /* make the coeff 32-bit */
          bn.rshi    w0, w31, w0 >> 16 /* shift out used coeff */
        bn.mulv.l.8S w1, w1, w3, 0     /* *= 80635 */
        bn.shv.8S    w1, w1 >> 28      /* >>= 28 */
        LOOPI 8, 2
          bn.rshi    w4, w1, w4 >> 4
          bn.rshi    w1, w31, w1 >> 32 
        NOP
      NOP 
    bn.sid x8, 0(x12++)
#elif (KYBER_K == 4)
  bn.shv.8S  w2, w2 << 16
  bn.shv.8S  w2, w2 >> 17 
  bn.shv.8S  w2, w2 << 1 /* 1664 */
  bn.rshi     w3, w31, w3 >> 4
  bn.addi     w3, w3, 1 /* 40318 */
  /* First WDR */
  LOOPI 3, 15
    bn.lid      x4, 0(x11++) 
    LOOPI 2, 12 
      LOOPI 8, 3
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w1, w31, w1 >> 16
        bn.rshi w0, w31, w0 >> 16
      bn.shv.8S    w1, w1 << 5
      bn.addv.8S   w1, w1, w2
      bn.mulv.l.8S w1, w1, w3, 0
      bn.shv.8S    w1, w1 >> 27 
      LOOPI 8, 2 
        bn.rshi w4, w1, w4 >> 5
        bn.rshi w1, w31, w1 >> 32
      NOP 
    NOP
  bn.lid      x4, 0(x11++)
  LOOPI 8, 3
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w1, w31, w1 >> 16
    bn.rshi w0, w31, w0 >> 16
  bn.shv.8S    w1, w1 << 5
  bn.addv.8S   w1, w1, w2
  bn.mulv.l.8S w1, w1, w3, 0
  bn.shv.8S    w1, w1 >> 27 
  LOOPI 3, 2 
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 32
  bn.rshi w4, w1, w4 >> 1
  bn.sid  x8, 0(x12++)
  
  /* Second WDR */
  bn.rshi w4, w1, w4 >> 5
  bn.rshi w1, w31, w1 >> 32 
  LOOPI 4, 2 
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 32
  LOOPI 8, 3
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w1, w31, w1 >> 16
    bn.rshi w0, w31, w0 >> 16
  bn.shv.8S    w1, w1 << 5
  bn.addv.8S   w1, w1, w2
  bn.mulv.l.8S w1, w1, w3, 0
  bn.shv.8S    w1, w1 >> 27
  LOOPI 8, 2 
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 32
  LOOPI 2, 15
    bn.lid      x4, 0(x11++)
    LOOPI 2, 12 
      LOOPI 8, 3
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w1, w31, w1 >> 16
        bn.rshi w0, w31, w0 >> 16
      bn.shv.8S    w1, w1 << 5
      bn.addv.8S   w1, w1, w2
      bn.mulv.l.8S w1, w1, w3, 0
      bn.shv.8S    w1, w1 >> 27 
      LOOPI 8, 2 
        bn.rshi w4, w1, w4 >> 5
        bn.rshi w1, w31, w1 >> 32
      NOP 
    NOP
  bn.lid      x4, 0(x11++)
  LOOPI 8, 3
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w1, w31, w1 >> 16
    bn.rshi w0, w31, w0 >> 16
  bn.shv.8S    w1, w1 << 5
  bn.addv.8S   w1, w1, w2
  bn.mulv.l.8S w1, w1, w3, 0
  bn.shv.8S    w1, w1 >> 27 
  LOOPI 6, 2 
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 32
  bn.rshi w4, w1, w4 >> 2 
  bn.sid  x8, 0(x12++)

  /* Third WDR */
  bn.rshi w4, w1, w4 >> 5
  bn.rshi w1, w31, w1 >> 32 
  bn.rshi w4, w1, w4 >> 5
  bn.rshi w1, w31, w1 >> 32
  LOOPI 8, 3
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w1, w31, w1 >> 16
    bn.rshi w0, w31, w0 >> 16
  bn.shv.8S    w1, w1 << 5
  bn.addv.8S   w1, w1, w2
  bn.mulv.l.8S w1, w1, w3, 0
  bn.shv.8S    w1, w1 >> 27
  LOOPI 8, 2 
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 32
  LOOPI 2, 15
    bn.lid      x4, 0(x11++)
    LOOPI 2, 12 
      LOOPI 8, 3
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w1, w31, w1 >> 16
        bn.rshi w0, w31, w0 >> 16
      bn.shv.8S    w1, w1 << 5
      bn.addv.8S   w1, w1, w2
      bn.mulv.l.8S w1, w1, w3, 0
      bn.shv.8S    w1, w1 >> 27 
      LOOPI 8, 2 
        bn.rshi w4, w1, w4 >> 5
        bn.rshi w1, w31, w1 >> 32
      NOP 
    NOP
  bn.lid      x4, 0(x11++)
  LOOPI 8, 3
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w1, w31, w1 >> 16
    bn.rshi w0, w31, w0 >> 16
  bn.shv.8S    w1, w1 << 5
  bn.addv.8S   w1, w1, w2
  bn.mulv.l.8S w1, w1, w3, 0
  bn.shv.8S    w1, w1 >> 27 
  LOOPI 8, 2 
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 32
  LOOPI 8, 3
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w1, w31, w1 >> 16
    bn.rshi w0, w31, w0 >> 16
  bn.shv.8S    w1, w1 << 5
  bn.addv.8S   w1, w1, w2
  bn.mulv.l.8S w1, w1, w3, 0
  bn.shv.8S    w1, w1 >> 27
  bn.rshi w4, w1, w4 >> 5
  bn.rshi w1, w31, w1 >> 32
  bn.rshi      w4, w1, w4 >> 3
  bn.sid       x8, 0(x12++)

  /* Fourth WDR */
  bn.rshi      w4, w1, w4 >> 5
  bn.rshi      w1, w31, w1 >> 32 
  LOOPI 6, 2 
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 32
  LOOPI 2, 15
    bn.lid      x4, 0(x11++)
    LOOPI 2, 12
      LOOPI 8, 3
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w1, w31, w1 >> 16
        bn.rshi w0, w31, w0 >> 16
      bn.shv.8S    w1, w1 << 5
      bn.addv.8S   w1, w1, w2
      bn.mulv.l.8S w1, w1, w3, 0
      bn.shv.8S    w1, w1 >> 27 
      LOOPI 8, 2 
        bn.rshi w4, w1, w4 >> 5
        bn.rshi w1, w31, w1 >> 32
      NOP 
    NOP
  bn.lid      x4, 0(x11++)
  LOOPI 8, 3
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w1, w31, w1 >> 16
    bn.rshi w0, w31, w0 >> 16
  bn.shv.8S    w1, w1 << 5
  bn.addv.8S   w1, w1, w2
  bn.mulv.l.8S w1, w1, w3, 0
  bn.shv.8S    w1, w1 >> 27 
  LOOPI 8, 2 
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 32
  LOOPI 8, 3
    bn.rshi w1, w0, w1 >> 16
    bn.rshi w1, w31, w1 >> 16
    bn.rshi w0, w31, w0 >> 16
  bn.shv.8S    w1, w1 << 5
  bn.addv.8S   w1, w1, w2
  bn.mulv.l.8S w1, w1, w3, 0
  bn.shv.8S    w1, w1 >> 27
  LOOPI 4, 2 
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 32
  bn.rshi      w4, w1, w4 >> 4
  bn.sid       x8, 0(x12++)

  /* Fifth WDR */
  bn.rshi      w4, w1, w4 >> 5
  bn.rshi      w1, w31, w1 >> 32
  LOOPI 3, 2 
    bn.rshi w4, w1, w4 >> 5
    bn.rshi w1, w31, w1 >> 32
  LOOPI 3, 15
    bn.lid      x4, 0(x11++)
    LOOPI 2, 12 
      LOOPI 8, 3
        bn.rshi w1, w0, w1 >> 16
        bn.rshi w1, w31, w1 >> 16
        bn.rshi w0, w31, w0 >> 16
      bn.shv.8S    w1, w1 << 5
      bn.addv.8S   w1, w1, w2
      bn.mulv.l.8S w1, w1, w3, 0
      bn.shv.8S    w1, w1 >> 27 
      LOOPI 8, 2 
        bn.rshi w4, w1, w4 >> 5
        bn.rshi w1, w31, w1 >> 32
      NOP 
    NOP
  bn.sid  x8, 0(x12++)
#endif
  ret

/*
 * Name:        polyvec_compress
 *
 * Description: Compress and serialize vector of polynomials
 *
 * Arguments:   - uint8_t r: output byte array (of length KYBER_POLYCOMPRESSEDBYTES)
 *              - poly a: input polynomial, n=256, q=3329
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input polynomial
 * @param[out] x12: dptr_output, dmem pointer to output byte array
 * @param[in]  x13: const_1290167
 * @param[in]  x14: modulus_bn
 * @param[in]  x15: dptr_modulus_over_2
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 */
polyvec_compress:
#if (KYBER_K == 2 || KYBER_K == 3)
  bn.rshi w7, w31, w2 >> 240 /* extract (Q+1)/2 */
  LOOPI KYBER_POLYVECCOMPRESSED_LOOP, 141
    /* First WDR: 25 coeffs (250 bits) + 6 bits of 10th coeff of next load */
    bn.lid       x4, 0(x10++)
    LOOPI 16, 7
      bn.rshi          w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi          w1, w31, w1 >> 230 /* << 10 */
      bn.add           w1, w1, w7 /* +1665 (w7) */
      bn.mulqacc.wo.z  w1, w1.0, w3.0, 0 /* *1290167 (w3) */
      bn.rshi          w1, w31, w1 >> 32 /* >> 32 */
      bn.rshi          w4, w1, w4 >> 10 /* store res to w4 */
      bn.rshi          w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 9, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 230 /* << 10 */
      bn.add          w1, w1, w7 /* +1665 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *1290167 (w3) */
      bn.rshi         w1, w31, w1 >> 32 /* >> 32 */
      bn.rshi         w4, w1, w4 >> 10 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
    bn.rshi         w1, w31, w1 >> 230 /* << 10 */
    bn.add          w1, w1, w7 /* +1665 (w7) */
    bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *1290167 (w3) */
    bn.rshi         w1, w31, w1 >> 32 /* >> 32 */
    bn.rshi         w4, w1, w4 >> 6 /* store 6 bits of w1 to w4 */
    bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.sid          x8, 0(x12++)

    /* Second WDR: 4 bits + 25 coeffs (250 bits) + 2 bits */
    bn.rshi w4, w1, w4 >> 10 /* store 4 bits of w1 to w4 */
    LOOPI 6, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 230 /* << 10 */
      bn.add          w1, w1, w7 /* +1665 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *1290167 (w3) */
      bn.rshi         w1, w31, w1 >> 32 /* >> 32 */
      bn.rshi         w4, w1, w4 >> 10 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 16, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 230 /* << 10 */
      bn.add          w1, w1, w7 /* +1665 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *1290167 (w3) */
      bn.rshi         w1, w31, w1 >> 32 /* >> 32 */
      bn.rshi         w4, w1, w4 >> 10 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 3, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 230 /* << 10 */
      bn.add          w1, w1, w7 /* +1665 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *1290167 (w3) */
      bn.rshi         w1, w31, w1 >> 32 /* >> 32 */
      bn.rshi         w4, w1, w4 >> 10 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
    bn.rshi         w1, w31, w1 >> 230 /* << 10 */
    bn.add          w1, w1, w7 /* +1665 (w7) */
    bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *1290167 (w3) */
    bn.rshi         w1, w31, w1 >> 32 /* >> 32 */
    bn.rshi         w4, w1, w4 >> 2 /* store 2 bits of w1 to w4 */
    bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.sid          x8, 0(x12++)

    /* Third WDR: 8 bits + 24 coeffs (240 bits) + 8 bits */
    bn.rshi w4, w1, w4 >> 10 /* store 8 bits of w1 to w4 */
    LOOPI 12, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 230 /* << 10 */
      bn.add          w1, w1, w7 /* +1665 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *1290167 (w3) */
      bn.rshi         w1, w31, w1 >> 32 /* >> 32 */
      bn.rshi         w4, w1, w4 >> 10 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 12, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 230 /* << 10 */
      bn.add          w1, w1, w7 /* +1665 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *1290167 (w3) */
      bn.rshi         w1, w31, w1 >> 32 /* >> 32 */
      bn.rshi         w4, w1, w4 >> 10 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
    bn.rshi         w1, w31, w1 >> 230 /* << 10 */
    bn.add          w1, w1, w7 /* +1665 (w7) */
    bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *1290167 (w3) */
    bn.rshi         w1, w31, w1 >> 32 /* >> 32 */
    bn.rshi         w4, w1, w4 >> 8 /* store 8 bits of w1 to w4 */
    bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.sid          x8, 0(x12++)

    /* Fourth WDR: 2 bits + 25 coeffs (250 bits) + 4 bits */
    bn.rshi w4, w1, w4 >> 10 /* store 2 bits of w1 to w4 */
    LOOPI 3, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 230 /* << 10 */
      bn.add          w1, w1, w7 /* +1665 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *1290167 (w3) */
      bn.rshi         w1, w31, w1 >> 32 /* >> 32 */
      bn.rshi         w4, w1, w4 >> 10 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 16, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 230 /* << 10 */
      bn.add          w1, w1, w7 /* +1665 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *1290167 (w3) */
      bn.rshi         w1, w31, w1 >> 32 /* >> 32 */
      bn.rshi         w4, w1, w4 >> 10 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 6, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 230 /* << 10 */
      bn.add          w1, w1, w7 /* +1665 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *1290167 (w3) */
      bn.rshi         w1, w31, w1 >> 32 /* >> 32 */
      bn.rshi         w4, w1, w4 >> 10 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
    bn.rshi         w1, w31, w1 >> 230 /* << 10 */
    bn.add          w1, w1, w7 /* +1665 (w7) */
    bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *1290167 (w3) */
    bn.rshi         w1, w31, w1 >> 32 /* >> 32 */
    bn.rshi         w4, w1, w4 >> 4 /* store 4 bits of w1 to w4 */
    bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.sid          x8, 0(x12++)

    /* Fifth WDR: 6 bits + 25 coeffs (250 bits) */
    bn.rshi w4, w1, w4 >> 10 /* store 6 bits of w1 to w4 */
    LOOPI 9, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 230 /* << 10 */
      bn.add          w1, w1, w7 /* +1665 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *1290167 (w3) */
      bn.rshi         w1, w31, w1 >> 32 /* >> 32 */
      bn.rshi         w4, w1, w4 >> 10 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 16, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 230 /* << 10 */
      bn.add          w1, w1, w7 /* +1665 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *1290167 (w3) */
      bn.rshi         w1, w31, w1 >> 32 /* >> 32 */
      bn.rshi         w4, w1, w4 >> 10 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.sid x8, 0(x12++)
#elif (KYBER_K == 4)
  bn.rshi w7, w31, w2 >> 240 /* extract (Q+1)/2 */
  bn.subi w7, w7, 1 /* 1664 */
  bn.rshi w3, w31, w3 >> 1 
  bn.addi w3, w3, 1 /* 645084 */
  LOOPI KYBER_K, 317
    /* 1st WDR */
    bn.lid       x4, 0(x10++)
    LOOPI 16, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 7, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
    bn.rshi         w1, w31, w1 >> 229 /* << 11 */
    bn.add          w1, w1, w7 /* +1664 (w7) */
    bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
    bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
    bn.rshi         w4, w1, w4 >> 3 /* store res to w4 */
    bn.sid          x8, 0(x12++)

    /* 2nd WDR */
    bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
    bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    LOOPI 8, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 14, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
    bn.rshi         w1, w31, w1 >> 229 /* << 11 */
    bn.add          w1, w1, w7 /* +1664 (w7) */
    bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
    bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
    bn.rshi         w4, w1, w4 >> 6 /* store res to w4 */
    bn.sid          x8, 0(x12++)

    /* 3rd WDR */
    bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
    bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
    bn.rshi         w1, w31, w1 >> 229 /* << 11 */
    bn.add          w1, w1, w7 /* +1664 (w7) */
    bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
    bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
    bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
    bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid          x4, 0(x10++)
    bn.shv.16H      w5, w0 >> 15
    bn.subv.16H     w5, w31, w5 /* Build mask from MSBs */
    bn.and          w5, w5, w6
    bn.addv.16H     w0, w0, w5
    LOOPI 16, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 5, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
    bn.rshi         w1, w31, w1 >> 229 /* << 11 */
    bn.add          w1, w1, w7 /* +1664 (w7) */
    bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
    bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
    bn.rshi         w4, w1, w4 >> 9 /* store res to w4 */
    bn.sid          x8, 0(x12++)

    /* 4th WDR */
    bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
    bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    LOOPI 10, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 13, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
    bn.rshi         w1, w31, w1 >> 229 /* << 11 */
    bn.add          w1, w1, w7 /* +1664 (w7) */
    bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
    bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
    bn.rshi         w4, w1, w4 >> 1 /* store res to w4 */
    bn.sid          x8, 0(x12++)

    /* 5th WDR */
    bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
    bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    LOOPI 2, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 16, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 4, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
    bn.rshi         w1, w31, w1 >> 229 /* << 11 */
    bn.add          w1, w1, w7 /* +1664 (w7) */
    bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
    bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
    bn.rshi         w4, w1, w4 >> 4 /* store res to w4 */
    bn.sid          x8, 0(x12++)

    /* 6th WDR */
    bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
    bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    LOOPI 11, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 11, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
    bn.rshi         w1, w31, w1 >> 229 /* << 11 */
    bn.add          w1, w1, w7 /* +1664 (w7) */
    bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
    bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
    bn.rshi         w4, w1, w4 >> 7 /* store res to w4 */
    bn.sid          x8, 0(x12++)

    /* 7th WDR */
    bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
    bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    LOOPI 4, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 16, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 2, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
    bn.rshi         w1, w31, w1 >> 229 /* << 11 */
    bn.add          w1, w1, w7 /* +1664 (w7) */
    bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
    bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
    bn.rshi         w4, w1, w4 >> 10 /* store res to w4 */
    bn.sid          x8, 0(x12++)

    /* 8th WDR */
    bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
    bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    LOOPI 13, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 10, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
    bn.rshi         w1, w31, w1 >> 229 /* << 11 */
    bn.add          w1, w1, w7 /* +1664 (w7) */
    bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
    bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
    bn.rshi         w4, w1, w4 >> 2 /* store res to w4 */
    bn.sid          x8, 0(x12++)

    /* 9th WDR */
    bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
    bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    LOOPI 5, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 16, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
    bn.rshi         w1, w31, w1 >> 229 /* << 11 */
    bn.add          w1, w1, w7 /* +1664 (w7) */
    bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
    bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
    bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
    bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
    bn.rshi         w1, w31, w1 >> 229 /* << 11 */
    bn.add          w1, w1, w7 /* +1664 (w7) */
    bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
    bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
    bn.rshi         w4, w1, w4 >> 5 /* store res to w4 */
    bn.sid          x8, 0(x12++)

    /* 10th WDR */
    bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
    bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    LOOPI 14, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 8, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
    bn.rshi         w1, w31, w1 >> 229 /* << 11 */
    bn.add          w1, w1, w7 /* +1664 (w7) */
    bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
    bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
    bn.rshi         w4, w1, w4 >> 8 /* store res to w4 */
    bn.sid          x8, 0(x12++)

    /* 11th WDR */
    bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
    bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    LOOPI 7, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.lid       x4, 0(x10++)
    LOOPI 16, 7
      bn.rshi         w1, w0, w1 >> 16 /* shift one coeff on w1 */
      bn.rshi         w1, w31, w1 >> 229 /* << 11 */
      bn.add          w1, w1, w7 /* +1664 (w7) */
      bn.mulqacc.wo.z w1, w1.0, w3.0, 0 /* *645084 (w3) */
      bn.rshi         w1, w31, w1 >> 31 /* >> 31 */
      bn.rshi         w4, w1, w4 >> 11 /* store res to w4 */
      bn.rshi         w0, w31, w0 >> 16 /* shift out used coeff */
    bn.sid          x8, 0(x12++)
#endif 
  ret


/*
 * Name:        pack_ciphertext 
 *
 * Description: Serialize the ciphertext as concatenation of the
 *              compressed and serialized vector of polynomials b
 *              and the compressed and serialized polynomial v
 *
 * Arguments:   - uint8_t *r: pointer to the output serialized ciphertext
 *              - polyvec *b: pointer to the input vector of polynomials b
 *              - poly *v: pointer to the input polynomial v
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_b, dmem pointer to first input polynomial
 * @param[in]  x11: dptr_v, dmem pointer to second input polynomial
 * @param[out] x12: dptr_output, dmem pointer to output byte array
 * @param[in]  x13: const_1290167
 * @param[in]  x14: modulus_bn
 * @param[in]  x15: dptr_modulus_over_2
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 */

.globl pack_ciphertext
pack_ciphertext:
  /* Set up registers for input and output */
  li x4, 0
  li x5, 1
  li x6, 2
  li x7, 3
  li x8, 4

  /* Load const */
  bn.lid  x6, 0(x15) /* modulus_over_2 (w2) */
  bn.lid  x7, 0(x13) /* const_1290167 (w3) */

  bn.xor  w31, w31, w31
  bn.xor  w1, w1, w1
  jal     x1, polyvec_compress
  jal     x1, poly_compress

  ret


/*
 * Name:        poly_decompress
 *
 * Description: De-serialization and subsequent decompression of a polynomial;
 *              approximate inverse of poly_compress
 *
 * Arguments:   - uint8_t r: input byte array (of length KYBER_POLYCOMPRESSEDBYTES)
 *              - poly a: output polynomial, n=256, q=3329
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input byte array
 * @param[in]  x12: dptr_output, dmem pointer to output polynomial
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 */

poly_decompress:
#if (KYBER_K == 2 || KYBER_K == 3)
  bn.shv.16H w2, w2 >> 8 /* 0xf */
  LOOPI 4, 11
    bn.lid x4, 0(x10++)
    LOOPI 4, 8
      LOOPI 16, 2
        bn.rshi   w1, w0, w1 >> 16
        bn.rshi   w0, w31, w0 >> 4
      bn.and        w1, w1, w2 
      bn.mulv.l.16H w1, w1, w6, 0
      bn.addv.16H   w1, w1, w3 
      bn.shv.16H    w1, w1 >> 4
      bn.sid        x5, 0(x12++)
    NOP 
#elif (KYBER_K == 4)
  bn.shv.8S  w2, w2 << 16
  bn.shv.8S  w2, w2 >> 23 /* 0x1f */
  bn.shv.8S  w3, w3 << 16
  bn.shv.8S  w3, w3 >> 15 /* 16 */
  /* 1st+2nd+3rd WDRs */
  bn.lid x4, 0(x10++)
  LOOPI 3, 13
    LOOPI 2, 11
      LOOPI 8, 2
        bn.rshi   w1, w0, w1 >> 32
        bn.rshi   w0, w31, w0 >> 5
      bn.and        w1, w1, w2 
      bn.mulv.l.8S  w1, w1, w6, 0
      bn.addv.8S    w1, w1, w3 
      bn.shv.8S     w1, w1 >> 5
      LOOPI 8, 2
        bn.rshi   w4, w1, w4 >> 16
        bn.rshi   w1, w31, w1 >> 32
      NOP
    bn.sid x8, 0(x12++)

  /* 4th WDR */
  LOOPI 3, 2
    bn.rshi   w1, w0, w1 >> 32
    bn.rshi   w0, w31, w0 >> 5
  bn.rshi w1, w0, w1 >> 1
  bn.lid  x4, 0(x10++)
  bn.rshi w1, w0, w1 >> 31
  bn.rshi w0, w31, w0 >> 4
  LOOPI 4, 2
    bn.rshi   w1, w0, w1 >> 32
    bn.rshi   w0, w31, w0 >> 5
  bn.and        w1, w1, w2 
  bn.mulv.l.8S  w1, w1, w6, 0
  bn.addv.8S    w1, w1, w3 
  bn.shv.8S     w1, w1 >> 5
  LOOPI 8, 2
    bn.rshi   w4, w1, w4 >> 16
    bn.rshi   w1, w31, w1 >> 32
  LOOPI 8, 2
    bn.rshi   w1, w0, w1 >> 32
    bn.rshi   w0, w31, w0 >> 5
  bn.and        w1, w1, w2 
  bn.mulv.l.8S  w1, w1, w6, 0
  bn.addv.8S    w1, w1, w3 
  bn.shv.8S     w1, w1 >> 5
  LOOPI 8, 2
    bn.rshi   w4, w1, w4 >> 16
    bn.rshi   w1, w31, w1 >> 32
  bn.sid        x8, 0(x12++)

  /* 5th+6th WDR */
  LOOPI 2, 13
    LOOPI 2, 11
      LOOPI 8, 2
        bn.rshi   w1, w0, w1 >> 32
        bn.rshi   w0, w31, w0 >> 5
      bn.and        w1, w1, w2 
      bn.mulv.l.8S  w1, w1, w6, 0
      bn.addv.8S    w1, w1, w3 
      bn.shv.8S     w1, w1 >> 5
      LOOPI 8, 2
        bn.rshi   w4, w1, w4 >> 16
        bn.rshi   w1, w31, w1 >> 32
      NOP
    bn.sid x8, 0(x12++)
  
  /* 7th WDR */
  LOOPI 6, 2
    bn.rshi   w1, w0, w1 >> 32
    bn.rshi   w0, w31, w0 >> 5
  bn.rshi w1, w0, w1 >> 2
  bn.lid  x4, 0(x10++)
  bn.rshi w1, w0, w1 >> 30
  bn.rshi w0, w31, w0 >> 3
  bn.rshi   w1, w0, w1 >> 32
  bn.rshi   w0, w31, w0 >> 5
  bn.and        w1, w1, w2 
  bn.mulv.l.8S  w1, w1, w6, 0
  bn.addv.8S    w1, w1, w3 
  bn.shv.8S     w1, w1 >> 5
  LOOPI 8, 2
    bn.rshi   w4, w1, w4 >> 16
    bn.rshi   w1, w31, w1 >> 32
  LOOPI 8, 2
    bn.rshi   w1, w0, w1 >> 32
    bn.rshi   w0, w31, w0 >> 5
  bn.and        w1, w1, w2 
  bn.mulv.l.8S  w1, w1, w6, 0
  bn.addv.8S    w1, w1, w3 
  bn.shv.8S     w1, w1 >> 5
  LOOPI 8, 2
    bn.rshi   w4, w1, w4 >> 16
    bn.rshi   w1, w31, w1 >> 32
  bn.sid        x8, 0(x12++)

  /* 8th+9th WDR */
  LOOPI 2, 13
    LOOPI 2, 11
      LOOPI 8, 2
        bn.rshi   w1, w0, w1 >> 32
        bn.rshi   w0, w31, w0 >> 5
      bn.and        w1, w1, w2 
      bn.mulv.l.8S  w1, w1, w6, 0
      bn.addv.8S    w1, w1, w3 
      bn.shv.8S     w1, w1 >> 5
      LOOPI 8, 2
        bn.rshi   w4, w1, w4 >> 16
        bn.rshi   w1, w31, w1 >> 32
      NOP
    bn.sid x8, 0(x12++)

  /* 10th WDR */
  LOOPI 8, 2
    bn.rshi   w1, w0, w1 >> 32
    bn.rshi   w0, w31, w0 >> 5
  bn.and        w1, w1, w2 
  bn.mulv.l.8S  w1, w1, w6, 0
  bn.addv.8S    w1, w1, w3 
  bn.shv.8S     w1, w1 >> 5
  LOOPI 8, 2
    bn.rshi   w4, w1, w4 >> 16
    bn.rshi   w1, w31, w1 >> 32
  bn.rshi   w1, w0, w1 >> 32
  bn.rshi   w0, w31, w0 >> 5
  bn.rshi w1, w0, w1 >> 3
  bn.lid  x4, 0(x10++)
  bn.rshi w1, w0, w1 >> 29
  bn.rshi w0, w31, w0 >> 2
  LOOPI 6, 2
    bn.rshi   w1, w0, w1 >> 32
    bn.rshi   w0, w31, w0 >> 5
  bn.and        w1, w1, w2 
  bn.mulv.l.8S  w1, w1, w6, 0
  bn.addv.8S    w1, w1, w3 
  bn.shv.8S     w1, w1 >> 5
  LOOPI 8, 2
    bn.rshi   w4, w1, w4 >> 16
    bn.rshi   w1, w31, w1 >> 32
  bn.sid        x8, 0(x12++)

  /* 11th+12th WDR */
  LOOPI 2, 13
    LOOPI 2, 11
      LOOPI 8, 2
        bn.rshi   w1, w0, w1 >> 32
        bn.rshi   w0, w31, w0 >> 5
      bn.and        w1, w1, w2 
      bn.mulv.l.8S  w1, w1, w6, 0
      bn.addv.8S    w1, w1, w3 
      bn.shv.8S     w1, w1 >> 5
      LOOPI 8, 2
        bn.rshi   w4, w1, w4 >> 16
        bn.rshi   w1, w31, w1 >> 32
      NOP
    bn.sid x8, 0(x12++)
  
  /* 13th WDR */
  LOOPI 8, 2
    bn.rshi   w1, w0, w1 >> 32
    bn.rshi   w0, w31, w0 >> 5
  bn.and        w1, w1, w2 
  bn.mulv.l.8S  w1, w1, w6, 0
  bn.addv.8S    w1, w1, w3 
  bn.shv.8S     w1, w1 >> 5
  LOOPI 8, 2
    bn.rshi   w4, w1, w4 >> 16
    bn.rshi   w1, w31, w1 >> 32
  LOOPI 4, 2
    bn.rshi   w1, w0, w1 >> 32
    bn.rshi   w0, w31, w0 >> 5
  bn.rshi w1, w0, w1 >> 4
  bn.lid  x4, 0(x10++)
  bn.rshi w1, w0, w1 >> 28
  bn.rshi w0, w31, w0 >> 1
  LOOPI 3, 2
    bn.rshi   w1, w0, w1 >> 32
    bn.rshi   w0, w31, w0 >> 5
  bn.and        w1, w1, w2 
  bn.mulv.l.8S  w1, w1, w6, 0
  bn.addv.8S    w1, w1, w3 
  bn.shv.8S     w1, w1 >> 5
  LOOPI 8, 2
    bn.rshi   w4, w1, w4 >> 16
    bn.rshi   w1, w31, w1 >> 32
  bn.sid        x8, 0(x12++)

  /* 14th+15th+16th WDR */
  LOOPI 3, 13
    LOOPI 2, 11
      LOOPI 8, 2
        bn.rshi   w1, w0, w1 >> 32
        bn.rshi   w0, w31, w0 >> 5
      bn.and        w1, w1, w2 
      bn.mulv.l.8S  w1, w1, w6, 0
      bn.addv.8S    w1, w1, w3 
      bn.shv.8S     w1, w1 >> 5
      LOOPI 8, 2
        bn.rshi   w4, w1, w4 >> 16
        bn.rshi   w1, w31, w1 >> 32
      NOP
    bn.sid x8, 0(x12++)
#endif 
  ret

/*
 * Name:        polyvec_decompress
 *
 * Description: De-serialize and decompress vector of polynomials;
 *              approximate inverse of polyvec_compress
 *
 * Arguments:   - polyvec *r:       pointer to output vector of polynomials
 *              - const uint8_t *a: pointer to input byte array
 *                                  (of length KYBER_POLYVECCOMPRESSEDBYTES)
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input polynomial
 * @param[out] x12: dptr_output, dmem pointer to output byte array
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 */

polyvec_decompress:
#if (KYBER_K == 2 || KYBER_K == 3)
  bn.shv.8S  w5, w2 << 16 
  bn.shv.8S  w5, w5 >> 18 /* 0x3ff */
  bn.shv.8S  w4, w3 << 16 
  bn.shv.8S  w4, w4 >> 10 /* 512 */ 
  LOOPI KYBER_POLYVECCOMPRESSED_LOOP, 163
    /* First WDR: 160 bits of w0 */
    bn.lid x4, 0(x10++) 
    LOOPI 2, 11
      LOOPI 8, 2
        bn.rshi w1, w0, w1 >> 32
        bn.rshi w0, w31, w0 >> 10
      bn.and       w1, w1, w5   /* & 0x000003ff */
      bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
      bn.addv.8S   w1, w1, w4   /* +512 */ 
      bn.shv.8S    w1, w1 >> 10 /* >>10 */
      LOOPI 8, 2
        bn.rshi w8, w1, w8 >> 16
        bn.rshi w1, w31, w1 >> 32
      NOP
    bn.sid x20, 0(x12++) 

    /* Second WDR: 90 bits + 6 bits + (Reload) 4 bits + 60 bits */
    LOOPI 8, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 10
    bn.and       w1, w1, w5   /* & 0x000003ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +512 */ 
    bn.shv.8S    w1, w1 >> 10 /* >>10 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    bn.rshi w1, w0, w1 >> 32
    bn.rshi w0, w31, w0 >> 10
    bn.rshi w1, w0, w1 >> 6
    bn.lid  x4, 0(x10++)
    bn.rshi w1, w0, w1 >> 26
    bn.rshi w0, w31, w0 >> 4
    LOOPI 6, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 10
    bn.and       w1, w1, w5   /* & 0x000003ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +512 */ 
    bn.shv.8S    w1, w1 >> 10 /* >>10 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    bn.sid x20, 0(x12++)

    /* Third WDR: 160 bits */
    LOOPI 2, 11
      LOOPI 8, 2
        bn.rshi w1, w0, w1 >> 32
        bn.rshi w0, w31, w0 >> 10
      bn.and       w1, w1, w5   /* & 0x000003ff */
      bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
      bn.addv.8S   w1, w1, w4   /* +512 */ 
      bn.shv.8S    w1, w1 >> 10 /* >>10 */
      LOOPI 8, 2
        bn.rshi w8, w1, w8 >> 16
        bn.rshi w1, w31, w1 >> 32
      NOP
    bn.sid x20, 0(x12++)

    /* Fourth WDR: 30 bits + 2 bits + (Reload) 8 bits + 120 bits */
    LOOPI 3, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 10
    bn.rshi w1, w0, w1 >> 2
    bn.lid  x4, 0(x10++)
    bn.rshi w1, w0, w1 >> 30
    bn.rshi w0, w31, w0 >> 8
    LOOPI 4, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 10
    bn.and       w1, w1, w5   /* & 0x000003ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +512 */ 
    bn.shv.8S    w1, w1 >> 10 /* >>10 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    LOOPI 8, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 10
    bn.and       w1, w1, w5   /* & 0x000003ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +512 */ 
    bn.shv.8S    w1, w1 >> 10 /* >>10 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    bn.sid x20, 0(x12++)

    /* Fifth WDR: 120 bits + 8 bits + (Reload) 2 bits + 30 bits */
    LOOPI 8, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 10
    bn.and       w1, w1, w5   /* & 0x000003ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +512 */ 
    bn.shv.8S    w1, w1 >> 10 /* >>10 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    LOOPI 4, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 10
    bn.rshi w1, w0, w1 >> 8
    bn.lid  x4, 0(x10++)
    bn.rshi w1, w0, w1 >> 24
    bn.rshi w0, w31, w0 >> 2
    LOOPI 3, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 10
    bn.and       w1, w1, w5   /* & 0x000003ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +512 */ 
    bn.shv.8S    w1, w1 >> 10 /* >>10 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    bn.sid x20, 0(x12++)

    /* Sixth WDR: 160 bits */
    LOOPI 2, 11
      LOOPI 8, 2
        bn.rshi w1, w0, w1 >> 32
        bn.rshi w0, w31, w0 >> 10
      bn.and       w1, w1, w5   /* & 0x000003ff */
      bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
      bn.addv.8S   w1, w1, w4   /* +512 */ 
      bn.shv.8S    w1, w1 >> 10 /* >>10 */
      LOOPI 8, 2
        bn.rshi w8, w1, w8 >> 16
        bn.rshi w1, w31, w1 >> 32
      NOP
    bn.sid x20, 0(x12++)

    /* Seventh WDR: 60 bits + 4 bits + (Reload) 6 bits + 90 bits */
    LOOPI 6, 2  
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 10
    bn.rshi      w1, w0, w1 >> 4
    bn.lid       x4, 0(x10++)
    bn.rshi      w1, w0, w1 >> 28
    bn.rshi      w0, w31, w0 >> 6
    bn.rshi      w1, w0, w1 >> 32
    bn.rshi      w0, w31, w0 >> 10
    bn.and       w1, w1, w5   /* & 0x000003ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +512 */ 
    bn.shv.8S    w1, w1 >> 10 /* >>10 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    LOOPI 8, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 10
    bn.and       w1, w1, w5   /* & 0x000003ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +512 */ 
    bn.shv.8S    w1, w1 >> 10 /* >>10 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    bn.sid x20, 0(x12++)

    /* Eigth WDR: 160 bits */
    LOOPI 2, 11
      LOOPI 8, 2
        bn.rshi w1, w0, w1 >> 32
        bn.rshi w0, w31, w0 >> 10
      bn.and       w1, w1, w5   /* & 0x000003ff */
      bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
      bn.addv.8S   w1, w1, w4   /* +512 */ 
      bn.shv.8S    w1, w1 >> 10 /* >>10 */
      LOOPI 8, 2
        bn.rshi w8, w1, w8 >> 16
        bn.rshi w1, w31, w1 >> 32
      NOP
    bn.sid x20, 0(x12++) 
#elif (KYBER_K == 4)
  bn.shv.8S  w5, w2 << 16 
  bn.shv.8S  w5, w5 >> 17 /* 0x7ff */
  bn.shv.8S  w4, w3 << 16 
  bn.shv.8S  w4, w4 >> 9 /* 1024 */ 
  LOOPI KYBER_K, 351
    /* First WDR */
    bn.lid x4, 0(x10++) 
    LOOPI 2, 11
      LOOPI 8, 2
        bn.rshi w1, w0, w1 >> 32
        bn.rshi w0, w31, w0 >> 11
      bn.and       w1, w1, w5   /* & 0x000007ff */
      bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
      bn.addv.8S   w1, w1, w4   /* +1024 */ 
      bn.shv.8S    w1, w1 >> 11 /* >>11 */
      LOOPI 8, 2
        bn.rshi w8, w1, w8 >> 16
        bn.rshi w1, w31, w1 >> 32
      NOP
    bn.sid x20, 0(x12++)

    /* 2nd WDR */
    LOOPI 7, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 3
    bn.lid  x4, 0(x10++)
    bn.rshi w1, w0, w1 >> 29
    bn.rshi w0, w31, w0 >> 8
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    LOOPI 8, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    bn.sid x20, 0(x12++)

    /* Third WDR: 160 bits */
    LOOPI 8, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    LOOPI 6, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 6
    bn.lid  x4, 0(x10++)
    bn.rshi w1, w0, w1 >> 26
    bn.rshi w0, w31, w0 >> 5
    bn.rshi w1, w0, w1 >> 32
    bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    bn.sid x20, 0(x12++)

    /* 4th WDR */
    LOOPI 2, 11
      LOOPI 8, 2
        bn.rshi w1, w0, w1 >> 32
        bn.rshi w0, w31, w0 >> 11
      bn.and       w1, w1, w5   /* & 0x000007ff */
      bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
      bn.addv.8S   w1, w1, w4   /* +1024 */ 
      bn.shv.8S    w1, w1 >> 11 /* >>11 */
      LOOPI 8, 2
        bn.rshi w8, w1, w8 >> 16
        bn.rshi w1, w31, w1 >> 32
      NOP
    bn.sid x20, 0(x12++)

    /* 5th WDR */
    LOOPI 5, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 9
    bn.lid  x4, 0(x10++)
    bn.rshi w1, w0, w1 >> 23
    bn.rshi w0, w31, w0 >> 2
    LOOPI 2, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    LOOPI 8, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    bn.sid x20, 0(x12++)

    /* 6th WDR */
    LOOPI 8, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    LOOPI 5, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 1
    bn.lid  x4, 0(x10++)
    bn.rshi w1, w0, w1 >> 31
    bn.rshi w0, w31, w0 >> 10
    LOOPI 2, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    bn.sid x20, 0(x12++)

    /* 7th WDR */
    LOOPI 2, 11
      LOOPI 8, 2
        bn.rshi w1, w0, w1 >> 32
        bn.rshi w0, w31, w0 >> 11
      bn.and       w1, w1, w5   /* & 0x000007ff */
      bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
      bn.addv.8S   w1, w1, w4   /* +1024 */ 
      bn.shv.8S    w1, w1 >> 11 /* >>11 */
      LOOPI 8, 2
        bn.rshi w8, w1, w8 >> 16
        bn.rshi w1, w31, w1 >> 32
      NOP
    bn.sid x20, 0(x12++)

    /* 8th WDR */
    LOOPI 4, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 4
    bn.lid  x4, 0(x10++)
    bn.rshi w1, w0, w1 >> 28
    bn.rshi w0, w31, w0 >> 7
    LOOPI 3, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    LOOPI 8, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    bn.sid x20, 0(x12++)

    /* 9th WDR */
    LOOPI 8, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    LOOPI 3, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 7
    bn.lid  x4, 0(x10++)
    bn.rshi w1, w0, w1 >> 25
    bn.rshi w0, w31, w0 >> 4
    LOOPI 4, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    bn.sid x20, 0(x12++)

    /* 10th WDR */
    LOOPI 2, 11
      LOOPI 8, 2
        bn.rshi w1, w0, w1 >> 32
        bn.rshi w0, w31, w0 >> 11
      bn.and       w1, w1, w5   /* & 0x000007ff */
      bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
      bn.addv.8S   w1, w1, w4   /* +1024 */ 
      bn.shv.8S    w1, w1 >> 11 /* >>11 */
      LOOPI 8, 2
        bn.rshi w8, w1, w8 >> 16
        bn.rshi w1, w31, w1 >> 32
      NOP
    bn.sid x20, 0(x12++)

    /* 11th WDR */
    LOOPI 2, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 10
    bn.lid  x4, 0(x10++)
    bn.rshi w1, w0, w1 >> 22
    bn.rshi w0, w31, w0 >> 1
    LOOPI 5, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    LOOPI 8, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    bn.sid x20, 0(x12++)

    /* 12th WDR */
    LOOPI 8, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    LOOPI 2, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 2
    bn.lid  x4, 0(x10++)
    bn.rshi w1, w0, w1 >> 30
    bn.rshi w0, w31, w0 >> 9
    LOOPI 5, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    bn.sid x20, 0(x12++)

    /* 13th WDR */
    LOOPI 2, 11
      LOOPI 8, 2
        bn.rshi w1, w0, w1 >> 32
        bn.rshi w0, w31, w0 >> 11
      bn.and       w1, w1, w5   /* & 0x000007ff */
      bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
      bn.addv.8S   w1, w1, w4   /* +1024 */ 
      bn.shv.8S    w1, w1 >> 11 /* >>11 */
      LOOPI 8, 2
        bn.rshi w8, w1, w8 >> 16
        bn.rshi w1, w31, w1 >> 32
      NOP
    bn.sid x20, 0(x12++)

    /* 14th WDR */
    bn.rshi w1, w0, w1 >> 32
    bn.rshi w0, w31, w0 >> 11
    bn.rshi w1, w0, w1 >> 5
    bn.lid  x4, 0(x10++)
    bn.rshi w1, w0, w1 >> 27
    bn.rshi w0, w31, w0 >> 6
    LOOPI 6, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    LOOPI 8, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    bn.sid x20, 0(x12++)

    /* 15th WDR */
    LOOPI 8, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    bn.rshi w1, w0, w1 >> 8
    bn.lid  x4, 0(x10++)
    bn.rshi w1, w0, w1 >> 24
    bn.rshi w0, w31, w0 >> 3
    LOOPI 7, 2
      bn.rshi w1, w0, w1 >> 32
      bn.rshi w0, w31, w0 >> 11
    bn.and       w1, w1, w5   /* & 0x000007ff */
    bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
    bn.addv.8S   w1, w1, w4   /* +1024 */ 
    bn.shv.8S    w1, w1 >> 11 /* >>11 */
    LOOPI 8, 2
      bn.rshi w8, w1, w8 >> 16
      bn.rshi w1, w31, w1 >> 32
    bn.sid x20, 0(x12++)

    /* 16th WDR */
    LOOPI 2, 11
      LOOPI 8, 2
        bn.rshi w1, w0, w1 >> 32
        bn.rshi w0, w31, w0 >> 11
      bn.and       w1, w1, w5   /* & 0x000007ff */
      bn.mulv.l.8S w1, w1, w6, 0   /* *KYBER_Q */
      bn.addv.8S   w1, w1, w4   /* +1024 */ 
      bn.shv.8S    w1, w1 >> 11 /* >>11 */
      LOOPI 8, 2
        bn.rshi w8, w1, w8 >> 16
        bn.rshi w1, w31, w1 >> 32
      NOP
    bn.sid x20, 0(x12++)
#endif 
  ret

/*
 * Name:        unpack_ciphertext 
 *
 * Description: Serialize the secret key
 *
 * Arguments:   - uint8_t *r: pointer to output serialized secret key
 *              - polyvec *sk: pointer to input vector of polynomials (secret key)
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to first input byte array 
 * @param[in]  x13: const_8
 * @param[in]  x14: modulus_bn
 * @param[in]  x15: const_0x0fff
 * @param[out] x12: dptr_output, dmem pointer to output ciphertext
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x30, w0-w31
 */

.globl unpack_ciphertext
unpack_ciphertext:
  /* Set up registers for input and output */
  li x4, 0
  li x5, 1
  li x6, 2
  li x7, 3
  li x8, 4
  li x9, 6
  li x20, 8

  /* Load const */
  bn.lid  x6, 0(x15) /* const_0x0fff (w2) */
  bn.lid  x7, 0(x13) /* const_8 (w3) */
  bn.lid  x9, 0(x14) /* modulus (w6) */

  bn.xor     w31, w31, w31
  bn.xor     w1, w1, w1
  jal        x1, polyvec_decompress
  jal        x1, poly_decompress

  ret