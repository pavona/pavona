/* Copyright zeroRISC Inc. */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192). */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#define CRHBYTES 64
#define N 256
#define Q 8380417
#define D 13

/* Index of the Keccak command special register. */
#define KECCAK_CFG_REG 0x7d9
/* Config to start a SHAKE-128 operation. */
#define SHAKE128_CFG 0x2
/* Config to start a SHAKE-256 operation. */
#define SHAKE256_CFG 0xA
/* Config to start a SHA3_256 operation. */
#define SHA3_256_CFG 0x8
/* Config to start a SHA3_512 operation. */
#define SHA3_512_CFG 0x10

/* Macros */
.macro push reg
  addi x2, x2, -4      /* Decrement stack pointer by 4 bytes */
  sw \reg, 0(x2)      /* Store register value at the top of the stack */
.endm

.macro pop reg
  lw \reg, 0(x2)      /* Load value from the top of the stack into register */
  addi x2, x2, 4     /* Increment stack pointer by 4 bytes */
.endm

/**
 * polyt1_unpack
 *
 * Unpack polynomial t1 with coefficients fitting in 10 bits.
 * Output coefficients are standard representatives.
 *
 * @param[in]  x11: pointer to input byte array with POLYT1_PACKEDBYTES bytes
 * @param[out] x10: pointer to output polynomial
 *
 * clobbered registers: x6 to x7, x10 to x11, x28 to x31, w1 to w2, w5 to w6
 * clobbered flag groups: FG0
 */

.globl polyt1_unpack
.type polyt1_unpack, @function
polyt1_unpack:

  /* Setup WDR */
  li x6, 1
  li x7, 2
  li x28, 3
  li x29, 4
  li x30, 5

  /* Load mask for zeroing the upper bits of the unpacked coefficients. */
  la x31, polyt1_unpack_mask
  bn.lid x30, 0(x31)
  li x31, 6

  loopi 2, 23
    /* Start unpacking */
    bn.lid x6, 0(x11++)
    jal    x1, _inner_polyt1_unpack

    /* Current state: w1 = 0|w1[160:256] */
    bn.lid x31, 0(x11++)      /* Load new WLEN word to w6 */
    bn.or  w1, w1, w6 << 96 /* w1 = w6[0:160]|w1[160:256] */
    jal    x1, _inner_polyt1_unpack

    /* Current state: w1 = 0|w6[64:160] */
    bn.rshi w6, w31, w6 >> 160
    bn.or   w1, w1, w6 << 96 /* w1 = 0[64]|w6[160:256]|w6[64:160] */
    jal     x1, _inner_polyt1_unpack

    /* Current state: w1 = 0|w6[224:256] */
    bn.lid x31, 0(x11++)       /* Load new WLEN word to w6 */
    bn.or  w1, w1, w6 << 32  /* w1 = w6[0:224]|w6_prev[224:256] */
    jal    x1, _inner_polyt1_unpack

    /* Current state: w1 = 0|w6[128:224] */
    bn.or  w1, w31, w6 >> 128
    bn.lid x31, 0(x11++)       /* Load new WLEN word to w6 */
    bn.or  w1, w1, w6 << 128 /* w1 = w6[0:128]|w6_prev[128:256] */
    jal    x1, _inner_polyt1_unpack

    /* Current state: w1 = 0|w6[32:128] */
    bn.or w1, w31, w6 >> 32 /* w1 = 0[32]|w6[128:256]|w6[32:128] */
    jal   x1, _inner_polyt1_unpack

    /* Current state: w1 = 0|w6[192:256] */
    bn.lid x31, 0(x11++)       /* Load new WLEN word to w6 */
    bn.or  w1, w1, w6 << 64 /* w1 = w6[0:192]|w6_prev[192:256] */
    jal    x1, _inner_polyt1_unpack

    bn.or w1, w31, w6 >> 96 /* w1 = w6[96:256] */
    jal   x1, _inner_polyt1_unpack

    nop
  endloop

  ret

/**
 * _inner_polyt1_unpack
 *
 * Inner part of unpacking function to reduce the code size.
 * Do not call from anywhere but polyeta_unpack.
 * Does not adhere to calling convention.
 *
 * clobbered registers: x10, w1 to w2
 * clobbered flag groups: FG0
 */
_inner_polyt1_unpack:
  /* Unpack 16 coefficients in one go */
  loopi 2, 18
    /* This could also be done by a loop but it causes 64 cycles per
       function call, which is a lot to save 14 instructions */
    .rept 8
      /* Shift one coefficient into the output register, ignoring the
          upper 22 bits of other coefficient data */
      bn.rshi w2, w1, w2 >> 32
      /* Advance the input register such that the next coefficient is
          in the lower 10 bits */
      bn.rshi w1, w31, w1 >> 10
    .endr

    bn.and     w2, w2, w5 /* Mask unpacked coeffs to 10 bit */

    bn.sid x7, 0(x10++)
  endloop
  ret

/**
 * polyz_unpack_17 / polyz_unpack_19
 *
 * Unpack polynomial z with coefficients in [-(GAMMA1 - 1), GAMMA1] fitting into
 * 18 bits.
 *
 * @param[in]  x11: pointer to input byte array with POLYZ_PACKEDBYTES bytes
 * @param[in]  x14: K (used by polyz_unpack dispatcher only)
 * @param[out] x10: pointer to output polynomial
 *
 * clobbered registers: x5, x7, x10 to x11, x28, x30 to x31, w1 to w6
 * clobbered flag groups: FG0
 */
.globl polyz_unpack
.type polyz_unpack, @function
polyz_unpack:
  /* Dispatch on x14 (K): K==4 means GAMMA1=2^17, otherwise 2^19. */
  li  x5, 4
  beq x14, x5, polyz_unpack_17
  jal x0, polyz_unpack_19

.globl polyz_unpack_17
.type polyz_unpack_17, @function
polyz_unpack_17:
  /* Load gamma1 as a vector into w4 */
  li x7, 4
  la x28, gamma1_vec_const_17
  bn.lid x7, 0(x28)

  /* Load mask for zeroing the upper bits of the unpacked coefficients. */
  li x30, 5
  la x28, polyz_unpack_mask_17
  bn.lid x30, 0(x28)

  /* Setup WDR */
  li x7, 2
  li x28, 3
  li x31, 6

  loopi 2, 42
    bn.lid  x31, 0(x11++)
    bn.mov  w1, w6
    jal     x1, _inner_polyz_unpack_17

    bn.lid  x28, 0(x11++)
    bn.rshi w1, w3, w6 >> 144
    jal     x1, _inner_polyz_unpack_17

    bn.rshi w1, w31, w3 >> 32
    jal     x1, _inner_polyz_unpack_17

    bn.lid  x31, 0(x11++)
    bn.rshi w1, w6, w3 >> 176
    jal     x1, _inner_polyz_unpack_17

    bn.rshi w1, w31, w6 >> 64
    jal     x1, _inner_polyz_unpack_17

    bn.lid  x28, 0(x11++)
    bn.rshi w1, w3, w6 >> 208
    jal     x1, _inner_polyz_unpack_17

    bn.rshi w1, w31, w3 >> 96
    jal     x1, _inner_polyz_unpack_17

    bn.lid  x31, 0(x11++)
    bn.rshi w1, w6, w3 >> 240
    jal     x1, _inner_polyz_unpack_17

    bn.lid  x28, 0(x11++)
    bn.rshi w1, w3, w6 >> 128
    jal     x1, _inner_polyz_unpack_17

    bn.rshi w1, w31, w3 >> 16
    jal     x1, _inner_polyz_unpack_17

    bn.lid  x31, 0(x11++)
    bn.rshi w1, w6, w3 >> 160
    jal     x1, _inner_polyz_unpack_17

    bn.rshi w1, w31, w6 >> 48
    jal     x1, _inner_polyz_unpack_17

    bn.lid  x28, 0(x11++)
    bn.rshi w1, w3, w6 >> 192
    jal     x1, _inner_polyz_unpack_17

    bn.rshi w1, w31, w3 >> 80
    jal     x1, _inner_polyz_unpack_17

    bn.lid  x31, 0(x11++)
    bn.rshi w1, w6, w3 >> 224
    jal     x1, _inner_polyz_unpack_17

    bn.rshi w1, w31, w6 >> 112
    jal     x1, _inner_polyz_unpack_17
    nop /* Must not end on branch */
  endloop

  ret

_inner_polyz_unpack_17:
  /* Unpack 8 coefficients in one go */
  loopi 8, 2
    /* Shift one coefficient into the output register, ignoring the
        upper 14 bits of other coefficient data */
    bn.rshi w2, w1, w2 >> 32
    /* Advance the input register such that the next coefficient is
        in the lower 18 bits */
    bn.rshi w1, w31, w1 >> 18
  endloop

  bn.and     w2, w2, w5 /* Mask unpacked coeffs to 18 bit */
  bn.subvm.8s w2, w4, w2 /* w2 <= gamma1_vec_const - w2 */
  bn.sid     x7, 0(x10++)
  ret

.globl polyz_unpack_19
.type polyz_unpack_19, @function
polyz_unpack_19:
  /* Load gamma1 as a vector into w4 */
  li x7, 4
  la x28, gamma1_vec_const_19
  bn.lid x7, 0(x28)

  /* Load mask for zeroing the upper bits of the unpacked coefficients. */
  li x30, 5
  la x28, polyz_unpack_mask_19
  bn.lid x30, 0(x28)

  /* Setup WDR */
  li x7, 2
  li x28, 3
  li x31, 6

  loopi 4, 22
    bn.lid  x31, 0(x11++)
    bn.mov  w1, w6
    jal     x1, _inner_polyz_unpack_19

    bn.lid  x28, 0(x11++)
    bn.rshi w1, w3, w6 >> 160
    jal     x1, _inner_polyz_unpack_19

    bn.rshi w1, w31, w3 >> 64
    jal     x1, _inner_polyz_unpack_19

    bn.lid  x31, 0(x11++)
    bn.rshi w1, w6, w3 >> 224
    jal     x1, _inner_polyz_unpack_19

    bn.lid  x28, 0(x11++)
    bn.rshi w1, w3, w6 >> 128
    jal     x1, _inner_polyz_unpack_19

    bn.rshi w1, w31, w3 >> 32
    jal     x1, _inner_polyz_unpack_19

    bn.lid  x31, 0(x11++)
    bn.rshi w1, w6, w3 >> 192
    jal     x1, _inner_polyz_unpack_19

    bn.rshi w1, w31, w6 >> 96
    jal     x1, _inner_polyz_unpack_19
    nop /* Must not end on branch */
  endloop

  ret

_inner_polyz_unpack_19:
  /* Unpack 8 coefficients in one go */
  loopi 8, 2
    /* Shift one coefficient into the output register, ignoring the
        upper 14 bits of other coefficient data */
    bn.rshi w2, w1, w2 >> 32
    /* Advance the input register such that the next coefficient is
        in the lower 18 bits */
    bn.rshi w1, w31, w1 >> 20
  endloop

  bn.and     w2, w2, w5 /* Mask unpacked coeffs to 18 bit */
  bn.subvm.8s w2, w4, w2 /* w2 <= gamma1_vec_const - w2 */
  bn.sid     x7, 0(x10++)
  ret

/**
 * poly_chknorm
 *
 * Check infinity norm of polynomial against given bound.
 * Assumes input coefficients were reduced by reduce32().
 *
 * The bound should be <= (Q - 1) / 8; we do not check that here, since in
 * practice the bound is always a compile-time constant.
 *
 * Increments the input pointer in place.
 *
 * Returns: 0 if norm is strictly smaller than B <= (Q-1)/8 and 1 otherwise.
 *
 * @param[in]    x11: norm bound
 * @param[inout] x10: pointer to polynomial
 * @param[out]   x12: 0 on success, 1 on failure
 *
 * clobbered registers: x5 to x7, x10, x12, w0 to w4
 * clobbered flag groups: FG0
 */
.globl poly_chknorm
.type poly_chknorm, @function
poly_chknorm:
  /* Load the bound into a wide register. */
  la      x7, poly_wdr2gpr
  sw      x11, 0(x7)
  bn.lid  x0, 0(x7)
  bn.rshi w0, w0, w0 >> 32
  bn.rshi w0, w31, w0 >> 224

  /* Vectorize the bound. */
  bn.or w0, w0, w0 << 128
  bn.or w0, w0, w0 << 64
  bn.or w0, w0, w0 << 32

  /* Load a vectorized 1 for comparison. */
  bn.addi w4, w31, 1
  bn.or   w4, w4, w4 << 128
  bn.or   w4, w4, w4 << 64
  bn.or   w4, w4, w4 << 32

  /* Initialize success flag (0 = failure, 8 = success). */
  li x5, 8

  /* Setup WDRs */
  li x6, 1
  loopi  32, 11
    bn.lid      x6, 0(x10++)
    /* constant time absolute value
       t = a->coeffs[i] >> 31;
       t = a->coeffs[i] - (t & 2*a->coeffs[i]);
    */
    /* Get the mask */
    /* w2 <= 0, if w1 >=? 0, else 0xFFFFFFFF */
    bn.shv.8s  w2, w1 >> 31
    bn.subv.8s w2, w31, w2 /* Build mask from MSBs */
    /* w2 <= w2 & (2 * w1) */
    bn.shv.8s  w3, w1 << 1
    bn.and     w2, w2, w3
    /* w2 <= w1 - w2 */
    bn.subv.8s w2, w1, w2

    /* Compare to the bound. */
    /* w2 <= w2 <? w0  */
    bn.subv.8s w2, w2, w0
    bn.shv.8s  w2, w2 >> 31

    /* Check that all underflow bits are 1 (w2 == w4, Z = 1). */
    bn.cmp w2, w4
    csrrs  x7, FG0, x0
    and    x5, x5, x7
  endloop

  /* Return 0 on success, 1 on failure. */
  srli x12, x5, 3
  xori x12, x12, 1
  ret

/**
 * poly_challenge
 *
 * Implementation of H. Samples polynomial with TAU nonzero coefficients in
 * {-1,1} using the output stream of SHAKE128(seed|nonce).
 *
 * @param[in]  x11: mu byte array containing seed of length CTILDEBYTES
 * @param[out] x10: pointer to output polynomial
 * @param[in]  x12: CTILDEBYTES
 * @param[in]  x13: TAU
 *
 * clobbered registers: x5 to x7, x10 to x16, x28 to x29, w0 to w3
 * clobbered flag groups: FG0
 */
.globl poly_challenge
.type poly_challenge, @function
poly_challenge:
  /* save output pointer */
  addi x14, x10, 0

  /* Initialize a SHAKE256 operation. */
  addi x10, x11, 0 /* x10 <= *mu */

  addi  x11, x12, 0 /* x11 <= CTILDEBYTES */
  slli  x5, x11, 5
  addi  x5, x5, SHAKE256_CFG
  csrrw x0, KECCAK_CFG_REG, x5

  /* Send the message to the Keccak core. */
  /* x10 contains *mu already */
  /* x11 contains CTILDEBYTES already */
  jal  x1, keccak_send_message

  /* Restore output pointer */
  addi x11, x10, 0
  addi x10, x14, 0

  /* Read first SHAKE output */
  bn.wsrr w0, 0xA /* KECCAK_DIGEST */

  /* Initialize output poly to 0 */
  add x6, x0, x10

  /* w31 contains all zeros by convention */
  li x5, 31
  loopi 32, 1
    bn.sid x5, 0(x6++)
  endloop

  /* Setup WDR */
  li x5, 0
  li x16, 3

  /* Set up pointer to tmp buffer. */
  la x29, poly_wdr2gpr

  /* fill signs */

  /* Load mask (2**64)-1 to w2 */
  bn.addi w1, w31, 1
  bn.or   w2, w31, w1 << 64
  bn.sub  w2, w2, w1

  /* w1 <= signs */
  /* Mask out the sign bits from the WDR containing the SHAKE output */
  bn.or   w1, w31, w0
  bn.and  w1, w1, w2
  /* w2 <= 1-bit mask */
  bn.addi w2, w31, 1
  /* shift out sign bits from the register containing the SHAKE output */
  bn.rshi w0, w31, w0 >> 64

  /* x12 <= number of remaining bits in buf */
  li x12, 192

  addi x6, x13, 0
  li x14, N
  /* x13 <= i = N-TAU */
  sub x13, x14, x6
  li x28, 1

  /* Loop TAU times. */
  loop x6, 25
    /* get address of c->coeffs[i], the current coefficient */
    slli x15, x13, 2 /* i * 4 for byte position */
    add  x15, x15, x10 /* Add the array start address: c->coeffs + i * 4 */
    /* start do-while loop */
_loop_inner_poly_challenge:
    /* If the SHAKE output "buffer" register w0 is empty, squeeze again.
       Since all reads from w0 are equally large (8 bits) and 8 | 256,
       we can just check for "zero" */
    bne     x0, x12, _loop_inner_skip_load_poly_challenge
    bn.wsrr w0, 0xA /* KECCAK_DIGEST */
    li      x12, 256 /* reset the remaining bits counter */
_loop_inner_skip_load_poly_challenge:
    /* Store w0 to memory in order to read one word into a GPR */
    bn.sid  x5, 0(x29)
    bn.rshi w0, w31, w0 >> 8 /* shift out used bits */
    addi    x12, x12, -8 /* decrease number of remaining bits */
    /* NOTE: optimize this to use all bytes from this load */
    lw      x6, 0(x29) /* get one word of SHAKE output into GPR */
    /* x6 = b from the reference implementation */
    andi    x6, x6, 0xFF /* mask out one byte, because we only need one */
    sub     x7, x13, x6 /* i <? b */
    srli    x7, x7, 31
    /* while(b > i); */
    beq     x28, x7, _loop_inner_poly_challenge

    /* Implements:
    c->coeffs[i] = c->coeffs[b];
    c->coeffs[b] = 1 - 2*(signs & 1);
    signs >>= 1; */
    /* get address of c->coeffs[b] */
    slli x6, x6, 2  /* b * 4 for byte position */
    add  x6, x6, x10 /* Add the array start address: c->coeffs + b * 4 */

    /* "swap" */
    lw x7, 0(x6) /* Load c->coeffs[b] */
    sw x7, 0(x15) /* c->coeffs[i] = c->coeffs[b]; */

    /* NOTE: accumulate result values in WDR and store once 32 bytes; avoid
    moving between WDR and GPR? */
    bn.and  w3, w1, w2            /* signs & 1 */
    bn.add  w3, w3, w3            /* 2 * (signs & 1) */
    bn.subm  w3, w2, w3            /* 1 - 2 * (signs & 1) */
    bn.sid  x16, 0(x29) /* Store w3 to memory to move value to GPR */
    lw      x7, 0(x29)
    sw      x7, 0(x6)             /* c->coeffs[b] = 1 - 2*(signs & 1); */

    bn.rshi w1, w31, w1 >> 1 /* Discard the used bit: signs >>= 1 */

    addi x13, x13, 1 /* i++ */
  endloop

  /* Finish the SHAKE-256 operation. */

  ret

/**
 * poly_uniform
 *
 * Rejection-samples SHAKE output for a full polynomial of coefficients < Q.
 *
 * Expects the SHAKE operation to have already been initialized before this
 * function is called.
 *
 * @param[in]  x11: dmem pointer to polynomial
 * @param[out] dmem[x11]: freshly sampled polynomial
 *
 * clobbered registers: x5 to x7, x11, x13, x28 to x29, x31, w0, w8, w10 to w15, w21
 * clobbered flag groups: FG0
 */
.globl poly_uniform
.type poly_uniform, @function
poly_uniform:
  /* Define temporary registers. */
  #define shake_reg w8
  #define shake_reg_ptr 8

  /* Set up a mask to select the lower 23 bits of each 32 bits. */
  bn.not  w11, w31
  bn.rshi w11, w31, w11 >> 233
  bn.or   w11, w11, w11 << 128
  bn.or   w11, w11, w11 << 64
  bn.or   w11, w11, w11 << 32

  /* Load the vectorized modulus for later. */
  li      x5, 12
  la      x6, modulus
  bn.lid  x5, 0(x6)

  /* Set up a mask to select the most significant byte of each 32 bits. */
  bn.shv.8s w13, w11 << 24

  /* Copy the pointer to the start of the output polynomial. */
  addi    x28, x11, 0

  /* Initialize a register that will eventually hold the vector index of the
     first vector with bad coefficients as a hint to the postprocessing. */
  bn.xor  w14, w14, w14

  /* Initialize a register to increment the vector index. When we reach the
     first bad vector, we set this to zero to stop incrementing. */
  bn.addi w15, w31, 1

  /* Initialize a temp register pointer. */
  li      x31, 21

  /* Speculatively store 256 candidate coefficients.

     In the following logic, we translate 768 bytes of SHAKE data into 256
     23-bit candidate coefficients by sampling 3 bytes per coefficient and
     masking out the uppermost bit. This logic is performance-critical.

     We read the digest in 32-byte chunks from the digest register. SHAKE128
     produces output 168 bytes at a time, so once every ~5 reads we will need
     to wait about 100 cycles for the KMAC hardware block to process.
     Carefully scheduled during this time, we store information about whether
     the coefficients we stored so far are < Q or not. For performance
     reasons, we do not discard them immediately, since it would complicate
     the vectorization of the sampling routine. The vast majority of 23-bit
     numbers are within bounds (Q / 2^23 = 0.99902), so it's faster to store
     speculatively and run a more expensive correction routine later for the
     few bad values.

     Reads from SHAKE and stores of candidate vectors follow a repeating
     pattern every 3 reads/4 stores:
       - read 32B of digest
       - create 8 candidates (uses 24B, 8B of digest remaining)
       - store 8 candidates
       - create 2 candidates (uses 6B, 2B of digest remaining)
       - read 32B of digest
       - create 6 candidates (uses 18B, 16B of digest remaining)
       - store 8 candidates
       - create 5 candidates (uses 15B, 1B of digest remaining)
       - read 32B of digest
       - create 3 candidates (uses 9B, 24B of digest remaining)
       - store 8 candidates
       - create 8 candidates (uses 24B, now aligned again)
       - store 8 candidates
  */

  /* Process bytes 0..95 of digest (no state refresh needed). */

  /* Read 32 bytes from the digest. */
  bn.wsrr shake_reg, kmac_digest
  /* Load 8 23-bit coefficient candidates into vector register. */
  .rept 8
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  /* Store 8 coefficient candidates. */
  bn.sid  x0, 0(x11++)
  /* Load 2 23-bit coefficient candidates into vector register. */
  .rept 2
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  /* Save the leftover bytes (2) in the upper part of w0. */
  bn.rshi w0, shake_reg, w0 >> 16
  /* Read 32 bytes from the digest. */
  bn.wsrr shake_reg, kmac_digest
  /* Complete the partial coefficient with 1 more byte from the digest. */
  bn.rshi w0, shake_reg, w0 >> 16
  bn.rshi shake_reg, shake_reg, shake_reg >> 8
  /* Load 5 23-bit coefficient candidates into vector register. */
  .rept 5
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  /* Store 8 coefficient candidates. */
  bn.sid  x0, 0(x11++)
  /* Load 5 23-bit coefficient candidates into vector register. */
  .rept 5
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  /* Save the leftover bytes (1) in the upper part of w0. */
  bn.rshi w0, shake_reg, w0 >> 8
  /* Read 32 bytes from the digest. */
  bn.wsrr shake_reg, kmac_digest
  /* Complete the partial coefficient with 2 more bytes from the digest. */
  bn.rshi w0, shake_reg, w0 >> 24
  bn.rshi shake_reg, shake_reg, shake_reg >> 16
  /* Load 2 23-bit coefficient candidates into vector register. */
  .rept 2
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  /* Store 8 coefficient candidates. */
  bn.sid  x0, 0(x11++)
  /* Load 8 23-bit coefficient candidates into vector register. */
  .rept 8
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  /* Store 8 coefficient candidates. */
  bn.sid  x0, 0(x11++)

  /* Process bytes 96..191 of digest (state refresh before third read). */

  bn.wsrr shake_reg, kmac_digest
  .rept 8
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 2
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.rshi w0, shake_reg, w0 >> 16
  bn.wsrr shake_reg, kmac_digest
  bn.rshi w0, shake_reg, w0 >> 16
  bn.rshi shake_reg, shake_reg, shake_reg >> 8
  .rept 5
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 5
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.rshi w0, shake_reg, w0 >> 8
  /* While waiting for more digest, mask and check vectors 0..5. */
  li      x6, 6
  jal     x1, poly_uniform_mask_and_check_vectors
  /* STATE REFRESH. */
  bn.wsrr shake_reg, kmac_digest
  bn.rshi w0, shake_reg, w0 >> 24
  bn.rshi shake_reg, shake_reg, shake_reg >> 16
  .rept 2
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 8
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)

  /* Process bytes 192-287 of digest (no state refresh needed). */

  bn.wsrr shake_reg, kmac_digest
  .rept 8
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 2
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.rshi w0, shake_reg, w0 >> 16
  bn.wsrr shake_reg, kmac_digest
  bn.rshi w0, shake_reg, w0 >> 16
  bn.rshi shake_reg, shake_reg, shake_reg >> 8
  .rept 5
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 5
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.rshi w0, shake_reg, w0 >> 8
  bn.wsrr shake_reg, kmac_digest
  bn.rshi w0, shake_reg, w0 >> 24
  bn.rshi shake_reg, shake_reg, shake_reg >> 16
  .rept 2
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 8
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)

  /* Process bytes 288-383 of digest (state refresh before second read). */

  bn.wsrr shake_reg, kmac_digest
  .rept 8
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 2
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.rshi w0, shake_reg, w0 >> 16
  /* While waiting for more digest, mask and check vectors 6..12. */
  li      x6, 7
  jal     x1, poly_uniform_mask_and_check_vectors
  /* STATE REFRESH. */
  bn.wsrr shake_reg, kmac_digest
  bn.rshi w0, shake_reg, w0 >> 16
  bn.rshi shake_reg, shake_reg, shake_reg >> 8
  .rept 5
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 5
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.rshi w0, shake_reg, w0 >> 8
  bn.wsrr shake_reg, kmac_digest
  bn.rshi w0, shake_reg, w0 >> 24
  bn.rshi shake_reg, shake_reg, shake_reg >> 16
  .rept 2
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 8
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)

  /* Process bytes 384-479 of digest (no state refresh needed). */

  bn.wsrr shake_reg, kmac_digest
  .rept 8
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 2
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.rshi w0, shake_reg, w0 >> 16
  bn.wsrr shake_reg, kmac_digest
  bn.rshi w0, shake_reg, w0 >> 16
  bn.rshi shake_reg, shake_reg, shake_reg >> 8
  .rept 5
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 5
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.rshi w0, shake_reg, w0 >> 8
  bn.wsrr shake_reg, kmac_digest
  bn.rshi w0, shake_reg, w0 >> 24
  bn.rshi shake_reg, shake_reg, shake_reg >> 16
  .rept 2
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 8
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)

  /* Process bytes 480-575 of digest (state refresh before first read). */

  /* Note: this loop is an inlined version of
     poly_uniform_mask_and_check_vectors, because when there is a refresh on
     the first read of a 96-byte cycle the checking latency slightly exceeds
     the SHAKE latency and saving a few instructions on loading the loop size
     and jumping actually counts. */
  loopi  7, 8
    bn.lid     x31, 0(x28)
    bn.and     w21, w21, w11
    bn.sid     x31, 0(x28++)
    bn.subv.8s w10, w21, w12
    bn.and     w10, w10, w13
    bn.cmp     w10, w13
    bn.sel     w15, w15, w31, Z
    bn.add     w14, w14, w15
  endloop
  /* STATE REFRESH. */
  bn.wsrr shake_reg, kmac_digest
  .rept 8
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 2
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.rshi w0, shake_reg, w0 >> 16
  bn.wsrr shake_reg, kmac_digest
  bn.rshi w0, shake_reg, w0 >> 16
  bn.rshi shake_reg, shake_reg, shake_reg >> 8
  .rept 5
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 5
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.rshi w0, shake_reg, w0 >> 8
  bn.wsrr shake_reg, kmac_digest
  bn.rshi w0, shake_reg, w0 >> 24
  bn.rshi shake_reg, shake_reg, shake_reg >> 16
  .rept 2
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 8
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)

  /* Process bytes 576-671 of digest (no state refresh needed). */

  bn.wsrr shake_reg, kmac_digest
  .rept 8
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 2
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.rshi w0, shake_reg, w0 >> 16
  bn.wsrr shake_reg, kmac_digest
  bn.rshi w0, shake_reg, w0 >> 16
  bn.rshi shake_reg, shake_reg, shake_reg >> 8
  .rept 5
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 5
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.rshi w0, shake_reg, w0 >> 8
  bn.wsrr shake_reg, kmac_digest
  bn.rshi w0, shake_reg, w0 >> 24
  bn.rshi shake_reg, shake_reg, shake_reg >> 16
  .rept 2
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 8
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)

  /* Process bytes 672-767 of digest (state refresh before first read). */

  /* While waiting for more digest, mask and check vectors 20..27. */
  /* Note: this loop is an inlined version of
     poly_uniform_mask_and_check_vectors, because when there is a refresh on
     the first read of a 96-byte cycle the checking latency slightly exceeds
     the SHAKE latency and saving a few instructions on loading the loop size
     and jumping actually counts. */
  loopi  8, 8
    bn.lid     x31, 0(x28)
    bn.and     w21, w21, w11
    bn.sid     x31, 0(x28++)
    bn.subv.8s w10, w21, w12
    bn.and     w10, w10, w13
    bn.cmp     w10, w13
    bn.sel     w15, w15, w31, Z
    bn.add     w14, w14, w15
  endloop
  /* STATE REFRESH. */
  bn.wsrr shake_reg, kmac_digest
  .rept 8
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 2
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.rshi w0, shake_reg, w0 >> 16
  bn.wsrr shake_reg, kmac_digest
  bn.rshi w0, shake_reg, w0 >> 16
  bn.rshi shake_reg, shake_reg, shake_reg >> 8
  .rept 5
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 5
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.rshi w0, shake_reg, w0 >> 8
  bn.wsrr shake_reg, kmac_digest
  bn.rshi w0, shake_reg, w0 >> 24
  bn.rshi shake_reg, shake_reg, shake_reg >> 16
  .rept 2
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)
  .rept 8
    bn.rshi w0, shake_reg, w0 >> 32
    bn.rshi shake_reg, shake_reg, shake_reg >> 24
  .endr
  bn.sid  x0, 0(x11++)

  /* Done sampling; mask and check the last few vectors 28..31. */
  li      x6, 4
  jal     x1, poly_uniform_mask_and_check_vectors

/* This label is for testing, so we can intentionally give the postprocessing
 * part difficult inputs. */
.globl _poly_uniform_postprocess_test_entrypoint
_poly_uniform_postprocess_test_entrypoint:

  /* Keep track of the number of bytes available in the digest. Starts at 0
     since at present all bytes have been consumed. */
  li    x7, 0

  /* Reset the output pointer. */
  addi    x11, x11, -1024

_poly_uniform_discard_coeff_done:
  /* If we jump here, we assume:
       - a1 points to the start of the output polynomial
       - w11 holds a mask that selects the lower 23 bits of each 32b word
       - w12 holds the vectorized modulus
       - w13 holds a mask that selects the upper 8 bits of each 32b word
       - w14 holds the first vector index with a bad coefficient (32 if none)
   */

  /* Copy the index of the first bad coefficient into a GPR. */
  la      x5, poly_wdr2gpr
  li      x6, 14
  bn.sid  x6, 0(x5)
  lw      x13, 0(x5)

  /* If the index is 32, there are no bad coefficients and we can return. */
  li      x6, 32
  bne     x13, x6, .+8
  ret

  /* Load the bad vector. */
  slli    x5, x13, 5
  add     x5, x5, x11
  bn.lid  x0, 0(x5)

  /* Subtract the modulus from each coefficient. */
  bn.subv.8s w10, w0, w12

  /* Select the most significant byte of each difference. */
  bn.and  w10, w10, w13

  /* Cycle through probing the L flag to find the bad coefficient. */
  /* Note: this cannot be a hardware loop because after discarding the bad
     coefficient we will branch directly back to the postprocessing loop. */
  bn.or   w10, w31, w10 >> 24
  .rept 8
    /* Probe the L flag. If it is unset, discard the coefficient. */
    csrrs   x6, FG0, x0
    andi    x6, x6, 4
    beq     x6, x0, _poly_uniform_discard_coeff
    /* Increment the output pointer. */
    addi    x5, x5, 4
    /* Shift the indicators (sets the L flag for the next iteration). */
    bn.or   w10, w31, w10 >> 32
  .endr

    /* We should never get here; it would mean there was no bad coefficient. */
    unimp

_poly_uniform_discard_coeff:
  /* If we jump here:
       - x5 points to a bad 32-bit coefficient
       - x7 has the number of digest bytes available in shake_reg
       - x28 points to the end of the output polynomial
       - x13 holds the vector index of x5
       - w11 holds a vectorized 23-bit mask
     Now we need to shift the entire polynomial to eliminate the bad
     coefficient, and backfill the next candidate from the digest. */
  /* Get the number of coefficients to shift. */
  sub  x6, x28, x5
  srli x6, x6, 2
  addi x6, x6, -1
  /* Loop iteration count cannot be zero. */
  beq  x6, x0, _poly_uniform_discard_coeff_skip_shift
  /* For every coefficient from *x11...poly[254], shift in the value of the
     next coefficient. This overwrites the bad coefficient. */
  loop x6, 3
    lw   x6, 4(x5)
    sw   x6, 0(x5)
    addi x5, x5, 4
  endloop
_poly_uniform_discard_coeff_skip_shift:
  /* Now we need to draw a new coefficient from SHAKE output. */
  /* Load the last vector of coefficients. */
  srli    x5, x5, 5
  slli    x5, x5, 5
  bn.lid  x0, 0(x5)
  /* Rotate so the last coefficient is in the least significant position. */
  bn.rshi w0, w0, w0 >> 224
  /* Speculatively copy 3 bytes of digest (some bytes may be invalid). */
  bn.rshi w0, shake_reg, w0 >> 32
  bn.rshi shake_reg, shake_reg, shake_reg >> 24
  /* Speculatively store. */
  bn.sid  x0, 0(x5)
  /* Update number of bytes available and check for underflow. If the bytes
     were all valid, we're done. */
  addi    x7, x7, -3
  srli    x6, x7, 31
  beq     x6, x0, _poly_uniform_recompute_first_bad_index
  /* Some upper bytes are not valid. Refresh the digest. */
  bn.wsrr shake_reg, kmac_digest
  /* Shift the uppermost 0 byte out of the vector. */
  bn.rshi w0, w0, w31 >> 248
  /* Calculate how many bytes were invalid. */
  sub     x29, x0, x7
  /* Shift invalid upper bytes out of the coefficient. */
  loop    x29, 1
    bn.rshi w0, w0, w31 >> 248
  endloop
  /* Rotate valid bytes into the coefficient. */
  loop    x29, 2
    bn.rshi w0, shake_reg, w0 >> 8
    bn.rshi shake_reg, shake_reg, shake_reg >> 8
  endloop
  /* Reinsert the uppermost 0 byte. */
  bn.rshi w0, w31, w0 >> 8
  /* Update the number of bytes available in the digest. */
  addi    x7, x7, 32
  /* Store again. */
  bn.sid  x0, 0(x5)
_poly_uniform_recompute_first_bad_index:
  /* Calculate the number of vectors remaining (includes the just-corrected
     one; we may have shifted in a bad coefficient). */
  li   x6, 32
  sub  x6, x6, x13
  /* Get a pointer to the just-corrected vector. */
  slli x28, x13, 5
  add  x28, x28, x11
  /* Reset the incrementer value. The index register will still correctly
     indicate the current vector. */
  bn.addi w15, w31, 1
  jal     x1, poly_uniform_mask_and_check_vectors

  /* Jump back to discard next bad coefficient, if any. */
  jal     x0, _poly_uniform_discard_coeff_done

/**
 * Internal helper routine for poly_uniform.
 *
 * Given a series of vectors in memory, loads them, masks them, and returns the
 * index of the first one that contains at least one bad coefficient.
 *
 * The index and incrementer arguments are used to ensure we stop after the
 * first bad coefficient. If we find a bad coefficient, we set the incrementer
 * register to zero, and then future loops or calls to this function will not
 * change the index.
 *
 * This routine is performance-critical within the sampling loop, where it
 * typically runs between KMAC refreshes that take ~100 cycles and typically
 * checks about 5 vectors at a time. Therefore, keeping the total cycle count
 * under about 80 cycles per 5 vectors is important but hyperoptimizing the
 * performance beyond that is not.
 *
 * @param[in]    w11: mask that selects lower 23 bits of each 32b word
 * @param[in]    w12: vectorized modulus
 * @param[in]    w13: mask that selects upper 8 bits of each 32b word
 * @param[in]    x6: number of vectors to check
 * @param[in]    x31: constant 21 (wide register pointer)
 * @param[inout] x28: pointer to first input vector (updated in-place)
 * @param[inout] w14: index, either current index or first bad index if found
 * @param[inout] w15: incrementer, 1 if bad index not found yet otherwise 0
 *
 * clobbered registers: x28, w10, w14 to w15, w21, wref-x31
 * clobbered flag groups: FG0
 */
.type poly_uniform_mask_and_check_vectors, @function
poly_uniform_mask_and_check_vectors:
  loop  x6, 8
    /* Load the next vector. */
    bn.lid     x31, 0(x28)
    /* Mask and store the data. */
    bn.and     w21, w21, w11
    bn.sid     x31, 0(x28++)
    /* Check for underflow in all coefficients. */
    bn.subv.8s w10, w21, w12
    bn.and     w10, w10, w13
    bn.cmp     w10, w13
    /* If the Z flag is unset, stop incrementing the index. */
    bn.sel     w15, w15, w31, Z
    bn.add     w14, w14, w15
  endloop
  ret

/**
 * poly_uniform_eta_eta_2 / poly_uniform_eta_eta_4
 *
 * @param[in]  x10: pointer to rho
 * @param[in]  x12: nonce
 * @param[in]  x11: dmem pointer to polynomial
 * @param[in]  x14: K (used by poly_uniform_eta dispatcher only)
 *
 * clobbered registers: x5, x10 to x11, x14 to x16, x28 to x31, w0 to w1, w8 to w9, w12 to w14, w20 to w21
 * clobbered flag groups: FG0
 */
#ifndef HARDENED
.globl poly_uniform_eta
.type poly_uniform_eta, @function
poly_uniform_eta:
  /* Dispatch on x14 (K): K==6 means ETA=4, otherwise ETA=2. */
  li  x5, 6
  beq x14, x5, poly_uniform_eta_eta_4
  jal x0, poly_uniform_eta_eta_2

.globl poly_uniform_eta_eta_2
.type poly_uniform_eta_eta_2, @function
poly_uniform_eta_eta_2:
  /* Save nonce to memory (use poly tmp buffer). */
  la x5, poly_wdr2gpr
  sw x12, 0(x5)

  /* Initialize a SHAKE256 operation. */
  addi x14, x11, 0               /* save output pointer */

  addi  x11, x0, 66 /* len(rho) + len(nonce) */
  slli  x5, x11, 5
  addi  x5, x5, SHAKE256_CFG
  csrrw x0, KECCAK_CFG_REG, x5

  /* Send the messages to the Keccak core. */
  addi x11, x0, 64            /* set rho length */
  addi x10, x10, 0
  jal  x1, keccak_send_message /* x10 already contains the input buffer */
  addi x11, x0, 2             /* set nonce length */
  la   x10, poly_wdr2gpr        /* After rho, absorb nonce */
  jal  x1, keccak_send_message
  addi x11, x14, 0 /* move output pointer back to x11 */

  /* x5 = 1024, stop address */
  addi x5, x11, 1024

  /* Initialize constants for WDR index */
  li x30, 9
  li x31, 10
  li x28, 15

  /* Initialize constants */
  bn.addi w14, w31, 0x0F
  bn.addi w21, w31, 15
  li x15, 8
  li x16, 2

  la x31, poly_uniform_eta_205
  li x29, 12
  bn.lid x29, 0(x31)

  la x31, poly_uniform_eta_5/* Merge into one const for lane use */
  li x29, 0
  bn.lid x29, 0(x31)

  la x31, eta_2
  li x29, 1
  bn.lid x29, 0(x31)

  li x31, 8 /* coeffs to be collected in register */

  /* First squeeze */
  #define shake_reg w8

_rej_eta_sample_loop_eta_2:
  bn.wsrr  shake_reg, 0xA /* KECCAK_DIGEST */
  loopi 64, 13
    beq x11, x5, _rej_eta_sample_loop_continue_eta_2
    /* Process 4 bits */
    bn.and  w9, shake_reg, w14            /* Mask out all other bits */

    /* Check "t0" < 15 */
    bn.cmp w9, w21
    csrrs x14, 0x7C0, x0
    /* If the MSB of t0 - 15 is not set, we know that t0 >= 15
       and thus, we have to reject. */
    and x14, x14, x16
    beq x14, x0, _rej_eta_sample_loop_continue_eta_2

    addi x31, x31, -1 /* Found one more valid 4-bit value */

    /* Put each 4-bit value into one of 32-bit words in the WDR */
    bn.rshi w20, w9, w20 >> 32

    bne x0, x31, _rej_eta_sample_loop_continue_eta_2

    /* Vectorized part for arithmetic */

    /* "t{0,1}" indicate the variable names from the reference code */
    /* Compute "t0" = "t0" - (205 * "t0" >> 10) * 5 from reference code */
    jal x1, _poly_uniform_eta_arithmetic_eta_2

    /* Store coefficient value from WDR into target polynomial */
    bn.sid x30, 0(x11++)
    li x31, 8
_rej_eta_sample_loop_continue_eta_2:
    bn.rshi shake_reg, w31, shake_reg >> 4 /* shift out the used nibble */
  endloop

/* Loop logic */
  bne  x11, x5, _rej_eta_sample_loop_eta_2 /* Continue sampling */

  /* Finish the SHAKE-256 operation. */

  ret

.globl poly_uniform_eta_eta_4
.type poly_uniform_eta_eta_4, @function
poly_uniform_eta_eta_4:
  /* Save nonce to memory (use poly tmp buffer). */
  la x5, poly_wdr2gpr
  sw x12, 0(x5)

  /* Initialize a SHAKE256 operation. */
  addi x14, x11, 0               /* save output pointer */

  addi  x11, x0, 66 /* len(rho) + len(nonce) */
  slli  x5, x11, 5
  addi  x5, x5, SHAKE256_CFG
  csrrw x0, KECCAK_CFG_REG, x5

  /* Send the messages to the Keccak core. */
  addi x11, x0, 64            /* set rho length */
  addi x10, x10, 0
  jal  x1, keccak_send_message /* x10 already contains the input buffer */
  addi x11, x0, 2             /* set nonce length */
  la   x10, poly_wdr2gpr        /* After rho, absorb nonce */
  jal  x1, keccak_send_message
  addi x11, x14, 0 /* move output pointer back to x11 */

  /* x5 = 1024, stop address */
  addi x5, x11, 1024

  /* Initialize constants for WDR index */
  li x30, 9
  li x31, 10
  li x28, 15

  /* Initialize constants */
  bn.addi w14, w31, 0x0F
  bn.addi w21, w31, 9
  li x15, 8
  li x16, 2

  la x31, poly_uniform_eta_205
  li x29, 12
  bn.lid x29, 0(x31)

  la x31, poly_uniform_eta_5/* Merge into one const for lane use */
  li x29, 0
  bn.lid x29, 0(x31)

  la x31, eta_4
  li x29, 1
  bn.lid x29, 0(x31)

  li x31, 8 /* coeffs to be collected in register */

_rej_eta_sample_loop_eta_4:
  bn.wsrr  shake_reg, 0xA /* KECCAK_DIGEST */
  loopi 64, 13
    beq x11, x5, _rej_eta_sample_loop_continue_eta_4
    /* Process 4 bits */
    bn.and  w9, shake_reg, w14            /* Mask out all other bits */

    /* Check "t0" < 9 */
    bn.cmp w9, w21
    csrrs x14, 0x7C0, x0
    /* If the MSB of t0 - 9 is not set, we know that t0 >= 9
       and thus, we have to reject. */
    and x14, x14, x16
    beq x14, x0, _rej_eta_sample_loop_continue_eta_4

    addi x31, x31, -1 /* Found one more valid 4-bit value */

    /* Put each 4-bit value into one of 32-bit words in the WDR */
    bn.rshi w20, w9, w20 >> 32

    bne x0, x31, _rej_eta_sample_loop_continue_eta_4

    /* Vectorized part for arithmetic */

    /* "t{0,1}" indicate the variable names from the reference code */
    /* Compute "t0" = "t0" - (205 * "t0" >> 10) * 5 from reference code */
    jal x1, _poly_uniform_eta_arithmetic_eta_4

    /* Store coefficient value from WDR into target polynomial */
    bn.sid x30, 0(x11++)
    li x31, 8
_rej_eta_sample_loop_continue_eta_4:
    bn.rshi shake_reg, w31, shake_reg >> 4 /* shift out the used nibble */
  endloop

/* Loop logic */
  bne  x11, x5, _rej_eta_sample_loop_eta_4 /* Continue sampling */

  /* Finish the SHAKE-256 operation. */

  ret

_poly_uniform_eta_arithmetic_eta_2:
  bn.mulv.8s.even.lo w13, w20, w12
  bn.mulv.8s.odd.lo  w13, w13, w12
  bn.shv.8s  w13, w13 >> 10
  bn.mulv.8s.even.lo w13, w13, w0
  bn.mulv.8s.odd.lo  w13, w13, w0
  bn.subv.8s w20, w20, w13
  bn.subvm.8s w9, w1, w20
  ret

_poly_uniform_eta_arithmetic_eta_4:
  bn.subvm.8s w9, w1, w20
  ret

/**
 * poly_use_hint_88 / poly_use_hint_32
 *
 * Use hint polynomial to correct the high bits of a polynomial.
 *
 * The _88 and _32 variants implement the same loop and differ only in the
 * GAMMA2-dependent constants they load. In pseudocode, for input polynomial r:
 *   for i = 0..255:
 *     r0, r1 = decompose(r[i])
 *     if hint == 0:
 *       return r1
 *     if r0 > 0:
 *       return (r1 + 1) % ((q - 1) / (2 * gamma2))
 *     else:
 *       return (r1 - 1) % ((q - 1) / (2 * gamma2))
 * The if/else cases are implemented with bitwise operations so that the loop
 * can be vectorized; the code does not need to be constant-time. Hint values
 * are assumed to be 0 or 1, and decompose output is assumed to be
 * <= (q - 1) / (2 * gamma2) (16 or 44 depending on gamma2). The reference code
 * calls r0, r1 "a0" and "a1", but we use r here to avoid confusion with
 * register names.
 *
 * @param[in]  x10: output poly pointer
 * @param[out] x11: input poly pointer
 * @param[out] x12: input hint poly pointer
 * @param[in]  x14: K (used by poly_use_hint dispatcher only)
 *
 * clobbered registers: x5 to x6, x10 to x12, w0 to w13, w15, w30, mod
 * clobbered flag groups: FG0
 */
#endif
.globl poly_use_hint
.type poly_use_hint, @function
poly_use_hint:
  /* Dispatch on x14 (K): K==4 means GAMMA2=(Q-1)/88, otherwise (Q-1)/32. */
  li  x5, 4
  beq x14, x5, poly_use_hint_88
  jal x0, poly_use_hint_32

.globl poly_use_hint_88
.type poly_use_hint_88, @function
poly_use_hint_88:
  la x5, decompose_127_const
  li x6, 5
  bn.lid x6++, 0(x5)

  la x5, decompose_const_88
  bn.lid x6++, 0(x5)

  la x5, reduce32_const
  bn.lid x6++, 0(x5)

  la x5, decompose_43_const_88
  bn.lid x6++, 0(x5)

  la x5, gamma2_vec_const_88
  bn.lid x6++, 0(x5)

  la x5, qm1half_const
  bn.lid x6++, 0(x5)

  la x5, modulus
  bn.lid x6++, 0(x5)

  bn.wsrr w15, MOD

  bn.shv.8s w12, w5 >> 6
  bn.addv.8s w12, w12, w8
  bn.wsrw MOD, w12

  loopi 32, 11
    bn.lid x0, 0(x11++)
    jal    x1, decompose_88

    bn.lid x0, 0(x12++)

    bn.subv.8s w1, w1, w0
    bn.shv.8s w12, w1 >> 31

    bn.and w13, w12, w0

    bn.xor w12, w12, w0
    bn.and w12, w12, w0

    bn.addvm.8s w0, w2, w12
    bn.subvm.8s w0, w0, w13
    bn.sid x0, 0(x10++)
  endloop

  bn.wsrw MOD, w15

  ret

.globl poly_use_hint_32
.type poly_use_hint_32, @function
poly_use_hint_32:
  la x5, decompose_127_const
  li x6, 5
  bn.lid x6++, 0(x5)

  la x5, decompose_const_32
  bn.lid x6++, 0(x5)

  la x5, reduce32_const
  bn.lid x6++, 0(x5)

  la x5, decompose_43_const_32
  bn.lid x6++, 0(x5)

  la x5, gamma2_vec_const_32
  bn.lid x6++, 0(x5)

  la x5, qm1half_const
  bn.lid x6++, 0(x5)

  la x5, modulus
  bn.lid x6++, 0(x5)

  bn.wsrr w15, MOD

  bn.shv.8s w12, w5 >> 6
  bn.addv.8s w12, w12, w8
  bn.wsrw MOD, w12

  loopi 32, 11
    bn.lid x0, 0(x11++)
    jal    x1, decompose_32

    bn.lid x0, 0(x12++)

    bn.subv.8s w1, w1, w0
    bn.shv.8s w12, w1 >> 31

    bn.and w13, w12, w0

    bn.xor w12, w12, w0
    bn.and w12, w12, w0

    bn.addvm.8s w0, w2, w12
    bn.subvm.8s w0, w0, w13
    bn.sid x0, 0(x10++)
  endloop

  bn.wsrw MOD, w15

  ret

/**
 * polyt1_pack
 *
 * Bit-pack polynomial t1 with coefficients fitting in 10 bits. Input
 * coefficients are assumed to be standard representatives.
 *
 * @param[out] x10: pointer to output byte array with at least
                   POLYT1_PACKEDBYTES bytes
 * @param[in]  x11: pointer to input polynomial
 *
 * clobbered registers: x6, x10 to x11, x29, w1 to w2, w4
 * clobbered flag groups: none
 */
.globl polyt1_pack
.type polyt1_pack, @function
polyt1_pack:
  li x6, 1
  li x29, 4

  jal     x1, _inner_polyt1_pack
  bn.rshi w4, w2, w4 >> 160

  jal     x1, _inner_polyt1_pack
  bn.rshi w4, w2, w4 >> 96
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 160

  jal     x1, _inner_polyt1_pack
  bn.rshi w4, w2, w4 >> 160

  jal     x1, _inner_polyt1_pack
  bn.rshi w4, w2, w4 >> 32
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 160

  jal     x1, _inner_polyt1_pack
  bn.rshi w4, w2, w4 >> 128
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 160

  jal     x1, _inner_polyt1_pack
  bn.rshi w4, w2, w4 >> 160

  jal     x1, _inner_polyt1_pack
  bn.rshi w4, w2, w4 >> 64
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 160

  jal     x1, _inner_polyt1_pack
  bn.rshi w4, w2, w4 >> 160
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 0

  jal     x1, _inner_polyt1_pack
  bn.rshi w4, w2, w4 >> 160

  jal     x1, _inner_polyt1_pack
  bn.rshi w4, w2, w4 >> 96
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 160

  jal     x1, _inner_polyt1_pack
  bn.rshi w4, w2, w4 >> 160

  jal     x1, _inner_polyt1_pack
  bn.rshi w4, w2, w4 >> 32
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 160

  jal     x1, _inner_polyt1_pack
  bn.rshi w4, w2, w4 >> 128
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 160

  jal     x1, _inner_polyt1_pack
  bn.rshi w4, w2, w4 >> 160

  jal     x1, _inner_polyt1_pack
  bn.rshi w4, w2, w4 >> 64
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 160

  jal     x1, _inner_polyt1_pack
  bn.rshi w4, w2, w4 >> 160
  bn.sid  x29, 0(x10++)

  ret

_inner_polyt1_pack:
  loopi 2, 5
    bn.lid x6, 0(x11++)
    loopi 8, 2
      bn.rshi w2, w1, w2 >> 10 /* Write one coefficient into the output WDR */
      bn.rshi w1, w31, w1 >> 32 /* Shift out used coefficient */
    endloop
    nop
  endloop
  bn.rshi w2, w31, w2 >> 96 /* Shift the 160 bits of data to the bottom of the
                               WDR */
  ret

/**
 * polyeta_pack_eta_2 / polyeta_pack_eta_4
 *
 * Bit-pack polynomial with coefficients in [-ETA,ETA].
 *
 * @param[out] x10: pointer to output byte array with at least
                   POLYETA_PACKEDBYTES bytes
 * @param[in]  x11: pointer to input polynomial
 * @param[in]  x14: K (used by polyeta_pack dispatcher only)
 *
 * clobbered registers: x5 to x7, x10 to x11, x28, w1 to w3
 * clobbered flag groups: none
 */
#ifndef HARDENED
.globl polyeta_pack
.type polyeta_pack, @function
polyeta_pack:
  /* Dispatch on x14 (K): K==6 means ETA=4, otherwise ETA=2. */
  li  x5, 6
  beq x14, x5, polyeta_pack_eta_4
  jal x0, polyeta_pack_eta_2

.globl polyeta_pack_eta_2
.type polyeta_pack_eta_2, @function
polyeta_pack_eta_2:
  /* Compute ETA - coeff */
  /* Setup WDRs */
  li x6, 1
  li x7, 2
  li x28, 3

  /* Load precomputed, vectorized eta */
  la x5, eta_2
  bn.lid x28, 0(x5)

  /* 1 */
  jal x1, _inner_polyeta_pack_eta_2

  bn.lid x6, 0(x11++)
  /* w1 <= eta - w1 */
  bn.subvm.8s w1, w3, w1
  loopi 5, 2
    bn.rshi w2, w1, w2 >> 3 /* Write one coefficient into the output WDR */
    bn.rshi w1, w31, w1 >> 32 /* Shift out used coefficient */
  endloop
  /* Handle split coefficient */
  bn.rshi w2, w1, w2 >> 1 /* Get one more bit to fill w2 */
  bn.sid x7, 0(x10++)
  bn.rshi w2, w1, w2 >> 3 /* Use up two remaining bits */
  bn.rshi w1, w31, w1 >> 32 /* Coeff done, goto next */
  /* Do the rest of the register */
  loopi 2, 2
    bn.rshi w2, w1, w2 >> 3 /* Write one coefficient into the output WDR */
    bn.rshi w1, w31, w1 >> 32 /* Shift out used coefficient */
  endloop

  /* 2 */
  jal x1, _inner_polyeta_pack_eta_2

  bn.lid x6, 0(x11++)
  /* w1 <= eta - w1 */
  bn.subvm.8s w1, w3, w1
  loopi 2, 2
    bn.rshi w2, w1, w2 >> 3 /* Write one coefficient into the output WDR */
    bn.rshi w1, w31, w1 >> 32 /* Shift out used coefficient */
  endloop
  /* Handle split coefficient */
  bn.rshi w2, w1, w2 >> 2 /* Get two more bits to fill w2 */
  bn.sid x7, 0(x10++)
  bn.rshi w2, w1, w2 >> 3 /* Use up one remaining bits */
  bn.rshi w1, w31, w1 >> 32 /* Coeff done, goto next */
  /* Do the rest of the register */
  loopi 5, 2
    bn.rshi w2, w1, w2 >> 3 /* Write one coefficient into the output WDR */
    bn.rshi w1, w31, w1 >> 32 /* Shift out used coefficient */
  endloop

  /* 3 */
  jal x1, _inner_polyeta_pack_eta_2
  bn.sid x7, 0(x10++)
  ret

/**
 * _inner_polyeta_pack_eta_2
 *
 * Inner part of packing function to reduce the code size. Could be inlined.
 * Do not call from anywhere but polyeta_pack_eta_2.
 * Does not adhere to calling convention.
 *
 * clobbered registers: x11, w1 to w2, wref-x6
 * clobbered flag groups: none
 */
_inner_polyeta_pack_eta_2:
  loopi 10, 18
    bn.lid x6, 0(x11++)
    /* w1 <= eta - w1 */
    bn.subvm.8s w1, w3, w1
    .rept 8
      bn.rshi w2, w1, w2 >> 3 /* Write one coefficient into the output WDR */
      bn.rshi w1, w31, w1 >> 32 /* Shift out used coefficient */
    .endr
  endloop
  ret

.globl polyeta_pack_eta_4
.type polyeta_pack_eta_4, @function
polyeta_pack_eta_4:
  /* Compute ETA - coeff */
  /* Setup WDRs */
  li x6, 1
  li x7, 2
  li x28, 3

  /* Load precomputed, vectorized eta */
  la x5, eta_4
  bn.lid x28, 0(x5)

  /* Each WDR can hold 256/4 coefficients. So do this 4x */
  jal x1, _inner_polyeta_pack_eta_4
  bn.sid x7, 0(x10++)
  jal x1, _inner_polyeta_pack_eta_4
  bn.sid x7, 0(x10++)
  jal x1, _inner_polyeta_pack_eta_4
  bn.sid x7, 0(x10++)
  jal x1, _inner_polyeta_pack_eta_4
  bn.sid x7, 0(x10++)
  ret

/**
 * _inner_polyeta_pack_eta_4
 *
 * Inner part of packing function to reduce the code size. Could be inlined.
 * Do not call from anywhere but polyeta_pack_eta_4.
 * Does not adhere to calling convention.
 *
 * clobbered registers: x11, w1 to w2, wref-x6
 * clobbered flag groups: none
 */
_inner_polyeta_pack_eta_4:
  loopi 8, 18
    bn.lid x6, 0(x11++)
    /* w1 <= eta - w1 */
    bn.subvm.8s w1, w3, w1
    .rept 8
      bn.rshi w2, w1, w2 >> 4 /* Write one coefficient into the output WDR */
      bn.rshi w1, w31, w1 >> 32 /* Shift out used coefficient */
    .endr
  endloop
  ret
/**
 * polyt0_pack
 *
 * Bit-pack polynomial t0 with coefficients in ]-2^{D-1}, 2^{D-1}].
 *
 * @param[out] x10: pointer to output byte array with at least
                   POLYETA_PACKEDBYTES bytes
 * @param[in]  x11: pointer to input polynomial
 *
 * clobbered registers: x5 to x7, x10 to x11, x28 to x29, w1 to w4
 * clobbered flag groups: none
 */
#endif
.globl polyt0_pack
.type polyt0_pack, @function
polyt0_pack:
  /* Compute (1 << (D-1)) - coeff */
  /* Setup WDRs */
  li x6, 1
  li x7, 2
  li x28, 3
  li x29, 4

  /* Load precomputed (1 << (D-1)) */
  la     x5, polyt0_pack_const
  bn.lid x28, 0(x5)

  /* Start packing */
  jal     x1, _inner_polyt0_pack
  bn.rshi w4, w2, w4 >> 208

  jal     x1, _inner_polyt0_pack
  bn.rshi w4, w2, w4 >> 48 /* Fill up accumulator register to be 256 bits */
  /*bn.rshi w2, bn0, w2 >> 48*/ /* Remove used up bits */
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 208 /* Initialize the accumulator register again,
                                shifting 48 bits more than the rest in the
                                register actually is to discard the bits used
                                to fill the accumulator before the store */

  jal     x1, _inner_polyt0_pack
  bn.rshi w4, w2, w4 >> 96
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 208

  jal     x1, _inner_polyt0_pack
  bn.rshi w4, w2, w4 >> 144
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 208

  jal     x1, _inner_polyt0_pack
  bn.rshi w4, w2, w4 >> 192
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 208

  jal     x1, _inner_polyt0_pack
  bn.rshi w4, w2, w4 >> 208

  jal     x1, _inner_polyt0_pack
  bn.rshi w4, w2, w4 >> 32
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 208

  jal     x1, _inner_polyt0_pack
  bn.rshi w4, w2, w4 >> 80
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 208

  jal     x1, _inner_polyt0_pack
  bn.rshi w4, w2, w4 >> 128
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 208

  jal     x1, _inner_polyt0_pack
  bn.rshi w4, w2, w4 >> 176
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 208

  jal     x1, _inner_polyt0_pack
  bn.rshi w4, w2, w4 >> 208

  jal     x1, _inner_polyt0_pack
  bn.rshi w4, w2, w4 >> 16
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 208

  jal     x1, _inner_polyt0_pack
  bn.rshi w4, w2, w4 >> 64
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 208

  jal     x1, _inner_polyt0_pack
  bn.rshi w4, w2, w4 >> 112
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 208

  jal     x1, _inner_polyt0_pack
  bn.rshi w4, w2, w4 >> 160
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 208

  jal     x1, _inner_polyt0_pack
  bn.rshi w4, w2, w4 >> 208
  bn.sid  x29, 0(x10++)

  ret

_inner_polyt0_pack:
  loopi 2, 6
    bn.lid x6, 0(x11++)
    /* w1 <= eta - w1 */
    bn.subv.8s w1, w3, w1
    loopi 8, 2
      bn.rshi w2, w1, w2 >> 13 /* Write one coefficient into the output WDR */
      bn.rshi w1, w31, w1 >> 32 /* Shift out used coefficient */
    endloop
    nop
  endloop
  bn.rshi w2, w31, w2 >> 48 /* Shift the 208 bits of data to the bottom of the
                               WDR */
  ret

/**
 * poly_nonzero_encode
 *
 * Compactly encode the coefficients of the polynomial which are nonzero mod q.
 *
 * The bit at index (255-i) in the output 256-bit value is 1 if and only if the
 * coefficient i of the input is nonzero mod q. The bits are in "reverse order"
 * for more convenient iteration later; when iterating from MSb->LSb a single
 * bn.add can simultaneously capture the next bit in the carry flag and also
 * shift all the other bits.
 *
 * Expects input in the range [0, q).
 *
 * @param[in]  x10: pointer to input polynomial
 * @param[out] w0: Representative of nonzero coefficients.
 *
 * clobbered registers: x5, x10, w0 to w4
 * clobbered flag groups: FG0
 */
.globl poly_nonzero_encode
.type poly_nonzero_encode, @function
poly_nonzero_encode:
  /* Initialize accumulator to zero. */
  bn.mov w0, w31

  /* Create a 32-bit mask. */
  bn.not w2, w31
  bn.rshi w2, w31, w2 >> 224

  /* Set up WDR pointer. */
  li  x5, 1

  /* Loop through the coefficients. */
  loopi 32, 8
    bn.lid x5, 0(x10++)
    loopi 8, 5
      bn.add   w0, w0, w0
      bn.addi  w3, w0, 1
      bn.and   w4, w1, w2
      bn.sel   w0, w0, w3, FG0.Z
      bn.rshi  w1, w31, w1 >> 32
    endloop
    nop
  endloop

  ret

/**
 * polyw1_pack_88 / polyw1_pack_32
 *
 * Bit-pack polynomial w1 with coefficients fitting in 6 bits. Input
 * coefficients are assumed to be standard representatives.
 *
 * Output and input buffers may not arbitrarily overlap, but they may be the
 * same.
 *
 * @param[out] x10: pointer to output byte array with at least
                   POLYW1_PACKEDBYTES bytes
 * @param[in]  x11: pointer to input polynomial
 * @param[in]  x14: K (used by polyw1_pack dispatcher only)
 *
 * clobbered registers: x5 to x7, x10 to x11, x29, w1 to w2, w4
 * clobbered flag groups: none
 */
.globl polyw1_pack
.type polyw1_pack, @function
polyw1_pack:
  /* Dispatch on x14 (K): K==4 means GAMMA2=(Q-1)/88, otherwise (Q-1)/32. */
  li  x5, 4
  beq x14, x5, polyw1_pack_88
  jal x0, polyw1_pack_32

.globl polyw1_pack_88
.type polyw1_pack_88, @function
polyw1_pack_88:

  /* Setup WDRs */
  li x6, 1
  li x7, 2
  li x29, 4

  loopi 2, 13
    jal     x1, _inner_polyw1_pack_88
    bn.rshi w4, w2, w4 >> 192

    jal     x1, _inner_polyw1_pack_88
    bn.rshi w4, w2, w4 >> 64
    bn.sid  x29, 0(x10++)
    bn.rshi w4, w2, w31 >> 192

    jal     x1, _inner_polyw1_pack_88
    bn.rshi w4, w2, w4 >> 128
    bn.sid  x29, 0(x10++)
    bn.rshi w4, w2, w31 >> 192

    jal     x1, _inner_polyw1_pack_88
    bn.rshi w4, w2, w4 >> 192
    bn.sid  x29, 0(x10++)
  endloop

  ret

_inner_polyw1_pack_88:
  loopi 4, 5
    bn.lid x6, 0(x11++)
    loopi 8, 2
      bn.rshi w2, w1, w2 >> 6 /* Write one coefficient into the output WDR */
      bn.rshi w1, w31, w1 >> 32 /* Shift out used coefficient */
    endloop
    nop
  endloop
  bn.rshi w2, w31, w2 >> 64 /* Shift the 192 bits of data to the bottom of the
                               WDR */
  ret

.globl polyw1_pack_32
.type polyw1_pack_32, @function
polyw1_pack_32:

  /* Setup WDRs */
  li x6, 1
  li x7, 2
  li x29, 4

  loopi 4, 2
    jal     x1, _inner_polyw1_pack_32
    bn.sid x7, 0(x10++)
  endloop
  ret

_inner_polyw1_pack_32:
  loopi 8, 5
    bn.lid x6, 0(x11++)
    loopi 8, 2
      bn.rshi w2, w1, w2 >> 4 /* Write one coefficient into the output WDR */
      bn.rshi w1, w31, w1 >> 32 /* Shift out used coefficient */
    endloop
    nop
  endloop
  ret
/**
 * polyeta_unpack_eta_2 / polyeta_unpack_eta_4
 *
 * Unpack polynomial with coefficients fitting in [-ETA, ETA].
 *
 * @param[in]  x11: byte array with bit-packed polynomial
 * @param[in]  x14: K (used by polyeta_unpack dispatcher only)
 * @param[out] x10: pointer to output polynomial
 *
 * clobbered registers: x5 to x7, x10 to x11, x28 to x31, w1 to w6
 * clobbered flag groups: FG0
 */
#ifndef HARDENED
.globl polyeta_unpack
.type polyeta_unpack, @function
polyeta_unpack:
  /* Dispatch on x14 (K): K==6 means ETA=4, otherwise ETA=2. */
  li  x5, 6
  beq x14, x5, polyeta_unpack_eta_4
  jal x0, polyeta_unpack_eta_2

.globl polyeta_unpack_eta_2
.type polyeta_unpack_eta_2, @function
polyeta_unpack_eta_2:
  /* Setup WDR */
  li x6, 1
  li x7, 2
  li x28, 3
  li x29, 4
  li x30, 5

  /* Load precomputed, vectorized eta */
  la x5, eta_2
  bn.lid x29, 0(x5)
  /* Load mask for zeroing the upper bits of the unpacked coefficients. */
  la x31, polyeta_unpack_mask_eta_2
  bn.lid x30, 0(x31)
  li x31, 6

  /* Start unpacking */
  bn.lid x6, 0(x11++)
  jal    x1, _inner_polyeta_unpack_eta_2

  /* Current state: w1 = |0|0|0|w1.3 */
  bn.lid x31, 0(x11++)      /* Load new WLEN word to w2 */
  bn.or  w1, w1, w6 << 64 /* w1 = |w6.2|w6.1|w6.0|w1.3| */
  jal    x1, _inner_polyeta_unpack_eta_2 /* 64-bit rest in w0.0 */

  /* Current state: w1 = |0|0|0|w6.2 */
  bn.lid  x28, 0(x11++)       /* Load new WLEN word to w3 */
  bn.rshi w1, w3, w6 >> 128 /* w1 = |w3.1|w3.0|w6.3|w6.2 */
  jal     x1, _inner_polyeta_unpack_eta_2

  /* w1 = |0|w3.3|w3.2|w3.1 */
  bn.rshi w1, w31, w3 >> 64
  jal     x1, _inner_polyeta_unpack_eta_2

  ret

/**
 * _inner_polyeta_unpack_eta_2
 *
 * Inner part of unpacking function to reduce the code size.
 * Do not call from anywhere but polyeta_unpack_eta_2.
 * Does not adhere to calling convention.
 *
 * clobbered registers: x10, w1 to w2
 * clobbered flag groups: FG0
 */
_inner_polyeta_unpack_eta_2:
  /* Unpack 64 coefficients in one go */
  loopi 8, 19
    /* This could also be done by a loop but it causes 64 cycles per
       function call, which is a lot to save 14 instructions */
    .rept 8
      /* Shift one coefficient into the output register, ignoring the
          upper 29 bits of other coefficient data */
      bn.rshi w2, w1, w2 >> 32
      /* Advance the input register such that the next coefficient is
          in the lower 3 bits */
      bn.rshi w1, w31, w1 >> 3
    .endr

    bn.and     w2, w2, w5 /* Mask unpacked coeffs to 3 bit */
    bn.subvm.8s w2, w4, w2 /* Subtract coeffs from eta: w2 <= eta - w2 */

    bn.sid x7, 0(x10++)
  endloop
  ret

.globl polyeta_unpack_eta_4
.type polyeta_unpack_eta_4, @function
polyeta_unpack_eta_4:
  /* Setup WDR */
  li x6, 1
  li x7, 2
  li x28, 3
  li x29, 4
  li x30, 5

  /* Load precomputed, vectorized eta */
  la x5, eta_4
  bn.lid x29, 0(x5)
  /* Load mask for zeroing the upper bits of the unpacked coefficients. */
  la x31, polyeta_unpack_mask_eta_4
  bn.lid x30, 0(x31)
  li x31, 6

  /* Start unpacking */
  bn.lid x6, 0(x11++)
  jal    x1, _inner_polyeta_unpack_eta_4

  bn.lid x6, 0(x11++)
  jal    x1, _inner_polyeta_unpack_eta_4

  bn.lid  x6, 0(x11++)
  jal     x1, _inner_polyeta_unpack_eta_4

  bn.lid  x6, 0(x11++)
  jal     x1, _inner_polyeta_unpack_eta_4

  ret

/**
 * _inner_polyeta_unpack_eta_4
 *
 * Inner part of unpacking function to reduce the code size.
 * Do not call from anywhere but polyeta_unpack_eta_4.
 * Does not adhere to calling convention.
 *
 * clobbered registers: x10, w1 to w2
 * clobbered flag groups: FG0
 */
_inner_polyeta_unpack_eta_4:
  /* Unpack 64 coefficients in one go */
  loopi 8, 19
    /* This could also be done by a loop but it causes 64 cycles per
       function call, which is a lot to save 14 instructions */
    .rept 8
      /* Shift one coefficient into the output register, ignoring the
          upper 29 bits of other coefficient data */
      bn.rshi w2, w1, w2 >> 32
      /* Advance the input register such that the next coefficient is
          in the lower 3 bits */
      bn.rshi w1, w31, w1 >> 4
    .endr

    bn.and     w2, w2, w5 /* Mask unpacked coeffs to 4 bit */
    bn.subvm.8s w2, w4, w2 /* Subtract coeffs from eta: w2 <= eta - w2 */

    bn.sid x7, 0(x10++)
  endloop
  ret

/**
 * poly_decode_h
 *
 * Decode a single polynomial of the hint from the signature. Returns 1 on a
 * decode failure, or 0 on success. Increments input pointer and indices for
 * the next call to the same function (but not output pointer). If the index
 * indicates that this is the last hint polynomial, then checks that extra bits
 * are zero.
 *
 * @param[in]  x10: pointer to output polynomial h
 * @param[in]  x11: pointer to bytes of encoded hint
 * @param[in]  x12: k, number of nonzero h coefficients so far
 * @param[in]  x13: i, index of this polynomial in h
 * @param[out] x14: return code (1 or 0)
 * @param[in]  x15: K, number of polynomials in h
 * @param[in]  x29: OMEGA
 *
 * clobbered registers: x5 to x7, x12 to x17, x28, x30 to x31
 * clobbered flag groups: none
 */
#endif
.globl poly_decode_h
.type poly_decode_h, @function
poly_decode_h:
  /* Initialize h[i] to zero */
  add x6, x0, x10
  li x5, 31
  loopi 32, 1
    bn.sid x5, 0(x6++)
  endloop

  /* Initialize constants */
  li x17, 1

  /* The notation inside the comments goes in line with the reference code */
  /* Load sig[OMEGA + i] to x7 */
  add  x7, x13, x29    /* i + OMEGA */
  add  x31, x7, x11    /* (sig + OMEGA + i) */
  andi x14, x31, 0x3   /* get lower two bits */
  sub  x31, x31, x14    /* set lowest two bits to 0 */
  lw   x31, 0(x31)     /* aligned load */
  slli x14, x14, 3
  srl  x31, x31, x14    /* extract the respective byte */
  andi x7, x31, 0xFF

  /* Note: sig, k, OMEGA are all unsigned. Can also compare by subtracting and
     checking the MSB */
  /* sig[OMEGA + i] <? k  */
  sub x28, x7, x12
  srli x28, x28, 31
  bne x28, x0, _ret1_decode_h
  /* || sig[OMEGA + i] >? OMEGA */
  sub x28, x29, x7
  srli x28, x28, 31
  bne x28, x0, _ret1_decode_h

  addi x28, x15, 0

  addi x30, x12, 0 /* j = k */

  /* Check if there is nothing to do if k = sig[OMEGA + i] */
  beq x7, x30, _loop_inner_skip_decode_h

  /* Do first iteration separately */
  /* Load sig[j] */
  add  x31, x30, x11   /* (sig + j) */
  andi x14, x31, 0x3  /* get lower two bits */
  sub  x31, x31, x14   /* set lowest two bits to 0 */
  lw   x31, 0(x31)    /* aligned load */
  slli x14, x14, 3
  srl  x31, x31, x14   /* extract the respective byte */
  andi x16, x31, 0xFF /* x16 = sig[j] */

  /* Store a 1 to h */
  slli x14, x16, 2  /* sig[j] * 4 */
  add  x31, x10, x14 /* (h[sig[j]]) */
  sw   x17, 0(x31)  /* h->vec[i].coeffs[sig[j]] = x17 = 1 */

  /* Skip the loop if we are already done here */
  addi x30, x30, 1
  beq x30, x7, _loop_inner_skip_decode_h
_loop_inner_decode_h:
    /* NOTE: Can be done more efficiently, probably dont need to compute
             this every iteration */
    /* Load sig[j] */
    add  x15, x30, x11  /* (sig + j) */
    andi x14, x15, 0x3 /* get lower two bits */
    sub  x31, x15, x14  /* set lowest two bits to 0 */
    lw   x6, 0(x31)   /* aligned load */
    slli x14, x14, 3
    srl  x6, x6, x14  /* extract the respective byte */
    andi x6, x6, 0xFF

    /* sig[j - 1] is in x16 at this point */

    /* sig[j] ==? sig[j-1] */
    beq  x6, x16, _ret1_decode_h
    sub x31, x6, x16
    srli x31, x31, 31

    /* sig[j] <? sig[j-1] */
    li  x14, 1
    beq x31, x14, _ret1_decode_h

    slli x14, x6, 2  /* sig[j] * 4 */
    add  x31, x10, x14 /* (h[sig[j]]) */
    sw   x17, 0(x31)  /* h->vec[i].coeffs[sig[j]] = 1 */

    addi x16, x6, 0 /* set sig[j - 1] from sig[j] */
    addi x30, x30, 1 /* j++ */

    /* j != sig[OMEGA + i] */
    bne x30, x7, _loop_inner_decode_h
_loop_inner_skip_decode_h:

  addi x12, x7, 0    /* k = sig[OMEGA + i]; */
  addi x13, x13, 1    /* i++ */

  /* Check if this is the last polynomial. */
  bne  x13, x28, _ret0_decode_h

  /* Ensure the extra indices are 0. */

  addi x30, x12, 0 /* j = k */
  beq  x30, x29, _ret0_decode_h
_loop_extra_decode_h:
  /* Load sig[j] */
  add  x31, x30, x11   /* (sig + j) */
  andi x14, x31, 0x3  /* get lower two bits */
  sub  x31, x31, x14   /* set lowest two bits to 0 */
  lw   x31, 0(x31)    /* aligned load */
  slli x14, x14, 3
  srl  x31, x31, x14   /* extract the respective byte */
  andi x16, x31, 0xFF /* x16 = sig[j] */

  /* if(sig[j]) return 1; */
  bne x16, x0, _ret1_decode_h

  addi x30, x30, 1 /* j++ */
  bne  x30, x29, _loop_extra_decode_h

_ret0_decode_h:
  li x14, 0
  ret

_ret1_decode_h:
  li x14, 1
  ret

/**
 * polyt0_unpack
 *
 * Bit-unpack polynomial t0 with coefficients in ]-2^{D-1}, 2^{D-1}].
 *
 * @param[out] x10: pointer to output byte array with at least
                   POLYETA_PACKEDBYTES bytes
 * @param[in]  x11: pointer to input polynomial
 *
 * clobbered registers: x7, x10 to x11, x28, x31, w1 to w6
 * clobbered flag groups: FG0
 */
.globl polyt0_unpack
.type polyt0_unpack, @function
polyt0_unpack:
  /* Load (1 << (D-1)) as a vector into w4 */
  li x7, 4
  la x28, polyt0_pack_const
  bn.lid x7, 0(x28)

  /* Load mask for zeroing the upper bits of the unpacked coefficients. */
  li x7, 5
  la x28, polyt0_unpack_mask
  bn.lid x7, 0(x28)

  /* Setup WDR */
  li x7, 2
  li x28, 3
  li x31, 6

  bn.lid  x31, 0(x11++)
  bn.mov  w1, w6
  jal     x1, _inner_polyt0_unpack

  bn.lid  x28, 0(x11++)
  bn.rshi w1, w3, w6 >> 208
  jal     x1, _inner_polyt0_unpack

  bn.lid  x31, 0(x11++)
  bn.rshi w1, w6, w3 >> 160
  jal     x1, _inner_polyt0_unpack

  bn.lid  x28, 0(x11++)
  bn.rshi w1, w3, w6 >> 112
  jal     x1, _inner_polyt0_unpack

  bn.lid  x31, 0(x11++)
  bn.rshi w1, w6, w3 >> 64
  jal     x1, _inner_polyt0_unpack

  bn.rshi w1, w31, w6 >> 16
  jal     x1, _inner_polyt0_unpack

  bn.lid  x28, 0(x11++)
  bn.rshi w1, w3, w6 >> 224
  jal     x1, _inner_polyt0_unpack

  bn.lid  x31, 0(x11++)
  bn.rshi w1, w6, w3 >> 176
  jal     x1, _inner_polyt0_unpack

  bn.lid  x28, 0(x11++)
  bn.rshi w1, w3, w6 >> 128
  jal     x1, _inner_polyt0_unpack

  bn.lid  x31, 0(x11++)
  bn.rshi w1, w6, w3 >> 80
  jal     x1, _inner_polyt0_unpack

  bn.rshi w1, w31, w6 >> 32
  jal     x1, _inner_polyt0_unpack

  bn.lid  x28, 0(x11++)
  bn.rshi w1, w3, w6 >> 240
  jal     x1, _inner_polyt0_unpack

  bn.lid  x31, 0(x11++)
  bn.rshi w1, w6, w3 >> 192
  jal     x1, _inner_polyt0_unpack

  bn.lid  x28, 0(x11++)
  bn.rshi w1, w3, w6 >> 144
  jal     x1, _inner_polyt0_unpack

  bn.lid  x31, 0(x11++)
  bn.rshi w1, w6, w3 >> 96
  jal     x1, _inner_polyt0_unpack

  bn.rshi w1, w31, w6 >> 48
  jal     x1, _inner_polyt0_unpack

  ret

/**
 * _inner_polyt0_unpack
 *
 * Inner part of unpacking function to reduce the code size.
 * Do not call from anywhere but polyt0_unpack.
 * Does not adhere to calling convention.
 *
 * clobbered registers: x10, w1 to w2
 * clobbered flag groups: FG0
 */
_inner_polyt0_unpack:
  /* Unpack 16 coefficients in one go */
  loopi 2, 19
    /* This could also be done by a loop but it causes 64 cycles per
       function call, which is a lot to save 14 instructions */
    .rept 8
      /* Shift one coefficient into the output register, ignoring the
          upper 19 bits of other coefficient data */
      bn.rshi w2, w1, w2 >> 32
      /* Advance the input register such that the next coefficient is
          in the lower 13 bits */
      bn.rshi w1, w31, w1 >> 13
    .endr

    bn.and     w2, w2, w5 /* Mask unpacked coeffs to 13 bit */
    bn.subvm.8s w2, w4, w2 /* w2 <= (1 << (D-1)) - coeffs */
    bn.sid     x7, 0(x10++)
  endloop
  ret

/**
 * poly_uniform_gamma_1_17 / poly_uniform_gamma_1_19
 *
 *  Sample polynomial with uniformly random coefficients in [-(GAMMA1 - 1),
 *  GAMMA1] by unpacking output stream of SHAKE256(seed|nonce).
 *
 * Accumulates the result onto the existing value in the output polynomial
 * register; the caller should zero this value if only the sampling output is
 * desired.
 *
 * @param[out] x10: pointer to accumulator on which to add output
 * @param[in]  x11: byte array with seed of length CRHBYTES
 * @param[in]  x12: nonce
 * @param[in]  x13: pointer to gamma1_vec_const
 * @param[in]  x14: K (used by poly_uniform_gamma_1 dispatcher only)
 *
 * clobbered registers: x5 to x7, x10 to x11, x28, w0 to w6
 * clobbered flag groups: FG0
 */
#ifndef HARDENED
.globl poly_uniform_gamma_1
.type poly_uniform_gamma_1, @function
poly_uniform_gamma_1:
  /* Dispatch on x14 (K): K==4 means GAMMA1=2^17, otherwise 2^19. */
  li  x5, 4
  beq x14, x5, poly_uniform_gamma_1_17
  jal x0, poly_uniform_gamma_1_19

.globl poly_uniform_gamma_1_17
.type poly_uniform_gamma_1_17, @function
poly_uniform_gamma_1_17:
  /* copy output pointer */
  addi x6, x10, 0

  /* Initialize a SHAKE256 operation. */
  addi x10, x11, 0    /* save x10 <= seed address */

  addi  x11, x0, CRHBYTES
  addi  x11, x11, 2
  slli  x5, x11, 5
  addi  x5, x5, SHAKE256_CFG
  csrrw x0, KECCAK_CFG_REG, x5

  /* Send the seed to the Keccak core. */
  /* x10 already set above */
  li   x11, CRHBYTES /* x11 <= CRHBYTES */
  jal  x1, keccak_send_message

  /* Send the nonce to the Keccak core. */
  la   x10, poly_wdr2gpr
  sw   x12, 0(x10)
  li   x11, 2 /* x11 <= 2 */
  jal  x1, keccak_send_message

  /* restore original value of output pointer */
  addi x10, x6, 0

  /* Load gamma1 as a vector into w4 */
  li x7, 4
  la x28, gamma1_vec_const_17
  bn.lid x7, 0(x28)

  /* Load mask for zeroing the upper bits of the unpacked coefficients to w5 */
  li x7, 5
  la x28, polyz_unpack_mask_17
  bn.lid x7, 0(x28)

  /* Setup WDR */
  li x7, 2
  loopi 2, 42
    bn.wsrr w6, 0xA /* KECCAK_DIGEST */
    bn.mov  w1, w6
    jal     x1, _inner_poly_uniform_gamma_1_17

    bn.wsrr w3, 0xA /* KECCAK_DIGEST */
    bn.rshi w1, w3, w6 >> 144
    jal     x1, _inner_poly_uniform_gamma_1_17

    bn.rshi w1, w31, w3 >> 32
    jal     x1, _inner_poly_uniform_gamma_1_17

    bn.wsrr w6, 0xA /* KECCAK_DIGEST */
    bn.rshi w1, w6, w3 >> 176
    jal     x1, _inner_poly_uniform_gamma_1_17

    bn.rshi w1, w31, w6 >> 64
    jal     x1, _inner_poly_uniform_gamma_1_17

    bn.wsrr w3, 0xA /* KECCAK_DIGEST */
    bn.rshi w1, w3, w6 >> 208
    jal     x1, _inner_poly_uniform_gamma_1_17

    bn.rshi w1, w31, w3 >> 96
    jal     x1, _inner_poly_uniform_gamma_1_17

    bn.wsrr w6, 0xA /* KECCAK_DIGEST */
    bn.rshi w1, w6, w3 >> 240
    jal     x1, _inner_poly_uniform_gamma_1_17

    bn.wsrr w3, 0xA /* KECCAK_DIGEST */
    bn.rshi w1, w3, w6 >> 128
    jal     x1, _inner_poly_uniform_gamma_1_17

    bn.rshi w1, w31, w3 >> 16
    jal     x1, _inner_poly_uniform_gamma_1_17

    bn.wsrr w6, 0xA /* KECCAK_DIGEST */
    bn.rshi w1, w6, w3 >> 160
    jal     x1, _inner_poly_uniform_gamma_1_17

    bn.rshi w1, w31, w6 >> 48
    jal     x1, _inner_poly_uniform_gamma_1_17

    bn.wsrr w3, 0xA /* KECCAK_DIGEST */
    bn.rshi w1, w3, w6 >> 192
    jal     x1, _inner_poly_uniform_gamma_1_17

    bn.rshi w1, w31, w3 >> 80
    jal     x1, _inner_poly_uniform_gamma_1_17

    bn.wsrr w6, 0xA /* KECCAK_DIGEST */
    bn.rshi w1, w6, w3 >> 224
    jal     x1, _inner_poly_uniform_gamma_1_17

    bn.rshi w1, w31, w6 >> 112
    jal     x1, _inner_poly_uniform_gamma_1_17
    nop /* Loop must not end on jump */
  endloop

  /* Finish the SHAKE-256 operation. */

  ret

_inner_poly_uniform_gamma_1_17:
  /* Unpack 8 coefficients in one go */
  loopi 8, 2
    /* Shift one coefficient into the output register, ignoring the
        upper 14 bits of other coefficient data */
    bn.rshi w2, w1, w2 >> 32
    /* Advance the input register such that the next coefficient is
        in the lower 18 bits */
    bn.rshi w1, w31, w1 >> 18
  endloop

  bn.and     w2, w2, w5 /* Mask unpacked coeffs to 18 bit */
  bn.subvm.8s w2, w4, w2 /* w2 <= gamma1_eta_const - w2 */
  bn.lid     x0, 0(x6)
  bn.addvm.8s w2, w0, w2
  bn.sid     x7, 0(x6++)
  ret

.globl poly_uniform_gamma_1_19
.type poly_uniform_gamma_1_19, @function
poly_uniform_gamma_1_19:
  /* copy output pointer */
  addi x6, x10, 0

  /* Initialize a SHAKE256 operation. */
  addi x10, x11, 0    /* x10 <= seed address */

  addi  x11, x0, CRHBYTES
  addi  x11, x11, 2
  slli  x5, x11, 5
  addi  x5, x5, SHAKE256_CFG
  csrrw x0, KECCAK_CFG_REG, x5

  /* Send the seed to the Keccak core. */
  /* x10 already set above */
  li   x11, CRHBYTES /* x11 <= CRHBYTES */
  jal  x1, keccak_send_message

  /* Send the nonce to the Keccak core. */
  la   x10, poly_wdr2gpr
  sw   x12, 0(x10)
  li   x11, 2 /* x11 <= 2 */
  jal  x1, keccak_send_message

  /* restore original value of output pointer */
  addi x10, x6, 0

  /* Load gamma1 as a vector into w4 */
  li x7, 4
  la x28, gamma1_vec_const_19
  bn.lid x7, 0(x28)

  /* Load mask for zeroing the upper bits of the unpacked coefficients to w5 */
  li x7, 5
  la x28, polyz_unpack_mask_19
  bn.lid x7, 0(x28)

  /* Setup WDR */
  li x7, 2

  loopi 4, 22
    bn.wsrr w6, 0xA /* KECCAK_DIGEST */
    bn.mov  w1, w6
    jal     x1, _inner_poly_uniform_gamma_1_19

    bn.wsrr w3, 0xA /* KECCAK_DIGEST */
    bn.rshi w1, w3, w6 >> 160
    jal     x1, _inner_poly_uniform_gamma_1_19

    bn.rshi w1, w31, w3 >> 64
    jal     x1, _inner_poly_uniform_gamma_1_19

    bn.wsrr w6, 0xA /* KECCAK_DIGEST */
    bn.rshi w1, w6, w3 >> 224
    jal     x1, _inner_poly_uniform_gamma_1_19

    bn.wsrr w3, 0xA /* KECCAK_DIGEST */
    bn.rshi w1, w3, w6 >> 128
    jal     x1, _inner_poly_uniform_gamma_1_19

    bn.rshi w1, w31, w3 >> 32
    jal     x1, _inner_poly_uniform_gamma_1_19

    bn.wsrr w6, 0xA /* KECCAK_DIGEST */
    bn.rshi w1, w6, w3 >> 192
    jal     x1, _inner_poly_uniform_gamma_1_19

    bn.rshi w1, w31, w6 >> 96
    jal     x1, _inner_poly_uniform_gamma_1_19
    nop /* Must not end on branch */
  endloop

  /* Finish the SHAKE-256 operation. */

  ret

_inner_poly_uniform_gamma_1_19:
  /* Unpack 8 coefficients in one go */
  loopi 8, 2
    /* Shift one coefficient into the output register, ignoring the
        upper 14 bits of other coefficient data */
    bn.rshi w2, w1, w2 >> 32
    /* Advance the input register such that the next coefficient is
        in the lower 18 bits */
    bn.rshi w1, w31, w1 >> 20
  endloop

  bn.and     w2, w2, w5 /* Mask unpacked coeffs to 20 bit */
  bn.subvm.8s w2, w4, w2 /* w2 <= gamma1_eta_const - w2 */
  bn.lid     x0, 0(x6)
  bn.addvm.8s w2, w0, w2
  bn.sid     x7, 0(x6++)
  ret
/**
 * poly_decompose_88 / poly_decompose_32
 *
 *  For all coefficients c of the input polynomial, compute high and low bits
 *  c0, c1 such c mod Q = c1*ALPHA + c0 with -ALPHA/2 < c0 <= ALPHA/2 except c1
 *  = (Q-1)/ALPHA where we set c1 = 0 and -ALPHA/2 <= c0 = c mod Q - Q < 0.
 *  Assumes coefficients to be standard representatives.
 *
 * @param[out] x10: a0 pointer to output polynomial with coefficients c0
 * @param[out] x11: a1 pointer to output polynomial with coefficients c1
 * @param[in]  x12: *a, pointer to input polynomial
 * @param[in]  x14: K (used by poly_decompose dispatcher only)
 *
 * clobbered registers: x5 to x7, x10 to x12, w0 to w11, w30
 * clobbered flag groups: FG0
 */
.globl poly_decompose
.type poly_decompose, @function
poly_decompose:
  /* Dispatch on x14 (K): K==4 means GAMMA2=(Q-1)/88, otherwise (Q-1)/32. */
  li  x5, 4
  beq x14, x5, poly_decompose_88
  jal x0, poly_decompose_32

.globl poly_decompose_88
.type poly_decompose_88, @function
poly_decompose_88:
  la x5, decompose_127_const
  li x6, 5
  bn.lid x6, 0(x5)

  la x5, decompose_const_88
  li x6, 6
  bn.lid x6, 0(x5)

  la x5, reduce32_const
  li x6, 7
  bn.lid x6, 0(x5)

  la x5, decompose_43_const_88
  li x6, 8
  bn.lid x6, 0(x5)

  la x5, gamma2_vec_const_88
  li x6, 9
  bn.lid x6, 0(x5)

  la x5, qm1half_const
  li x6, 10
  bn.lid x6, 0(x5)

  la x5, modulus
  li x6, 11
  bn.lid x6, 0(x5)

  li x5, 0
  li x6, 1
  li x7, 2

  loopi 32, 4
    bn.lid x5, 0(x12++)
    jal x1, decompose_88
    bn.sid x6, 0(x10++)
    bn.sid x7, 0(x11++)
  endloop

  ret

.globl poly_decompose_32
.type poly_decompose_32, @function
poly_decompose_32:
  la x5, decompose_127_const
  li x6, 5
  bn.lid x6, 0(x5)

  la x5, decompose_const_32
  li x6, 6
  bn.lid x6, 0(x5)

  la x5, reduce32_const
  li x6, 7
  bn.lid x6, 0(x5)

  la x5, decompose_43_const_32
  li x6, 8
  bn.lid x6, 0(x5)

  la x5, gamma2_vec_const_32
  li x6, 9
  bn.lid x6, 0(x5)

  la x5, qm1half_const
  li x6, 10
  bn.lid x6, 0(x5)

  la x5, modulus
  li x6, 11
  bn.lid x6, 0(x5)

  li x5, 0
  li x6, 1
  li x7, 2

  loopi 32, 4
    bn.lid x5, 0(x12++)
    jal x1, decompose_32
    bn.sid x6, 0(x10++)
    bn.sid x7, 0(x11++)
  endloop

  ret

/**
 * poly_make_hint
 *
 *  Compute hint polynomial. The coefficients of which indicate whether the low
 *  bits of the corresponding coefficient of the input polynomial overflow into
 *  the high bits.
 *  The function accepts inputs mod^+ q.
 *
 * Expects the high part of the polynomial to be represented with 256 bits, in
 * the format produced by poly_nonzero_encode_dilithium.
 *
 * Returns: Number of one bits
 *
 * @param[out] x10: pointer to output hint polynomial
 * @param[in]  x11: pointer to low part of input polynomial
 * @param[in]  x12: GAMMA2
 * @param[in]  w0: 256b representative of nonzero values in high part of polynomial
 *
 * clobbered registers: x5, x7, x10 to x11, x16 to x17, x28 to x31, w0
 * clobbered flag groups: FG0
 */
#endif
.globl poly_make_hint
.type poly_make_hint, @function
poly_make_hint:
  li   x7, 0
  li   x29, 1

  /* Constants for condition checking */
  addi x31, x12, 0

  la x5, modulus
  lw x16, 0(x5)
  sub x17, x16, x31 /* q - gamma2 */

  /* Loop over every coefficient pair of the input */
  loopi 256, 19
    lw x5, 0(x11)

    /* Collect the bit corresponding to whether the high part is nonzero in
       FG0.C, and shift the wide register one place. */
    bn.add  w0, w0, w0

    /* Return 0 if t0 <= gamma2 <=> 0 <= gamma2 - t0 */
    sub  x30, x31, x5
    srli x28, x30, 31
    beq  x28, x0, _loop_end_poly_make_hint

    /* Return 0 if q - gamma2 < t0 <=> (q - gamma2) - t0 < 0 */
    sub  x30, x17, x5
    srli x28, x30, 31
    beq  x28, x29, _return0

    /* Return 1 if t0 != q - gamma2 */
    bne  x5, x17, _return1

    /* Return 1 if the high part of the coefficient is nonzero. */
    csrrs   x28, FG0, x0
    andi    x28, x28, 1
    jal     x0, _loop_end_poly_make_hint
_return0:
    li  x28, 0
    jal x0, _loop_end_poly_make_hint
_return1:
    li  x28, 1
    /* Fall through to loop end */
_loop_end_poly_make_hint:
    sw   x28, 0(x10) /* Write to output polynomial */
    add  x7, x7, x28
    addi x11, x11, 4
    addi x10, x10, 4
  endloop

  addi x10, x7, 0 /* move result to return value */
  ret

/**
 * polyz_pack_17 / polyz_pack_19
 *
 * Pack polynomial z with coefficients fitting in 18 bits.
 *
 * @param[in]  w0: gamma1_vec_const
 * @param[in]  x11: pointer to input polynomial
 * @param[in]  x14: K (used by polyz_pack dispatcher only)
 * @param[out] x10: pointer to output byte array with at least
 *                  POLYZ_PACKEDBYTES bytes
 *
 * clobbered registers: x5 to x6, x10 to x11, x28 to x29, w1 to w4
 * clobbered flag groups: none
 */
.globl polyz_pack
.type polyz_pack, @function
polyz_pack:
  /* Dispatch on x14 (K): K==4 means GAMMA1=2^17, otherwise 2^19. */
  li  x5, 4
  beq x14, x5, polyz_pack_17
  jal x0, polyz_pack_19

.globl polyz_pack_17
.type polyz_pack_17, @function
polyz_pack_17:
  la x6, gamma1_vec_const_17
  li x28, 3
  bn.lid x28, 0(x6)

  /* Setup WDRs */
  li x6, 1
  li x29, 4

  /* Start packing */
  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 112
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 80
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 48
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 16
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 128
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 96
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 64
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 32
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 144
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 112
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 80
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 48
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 16
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 128
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 96
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 64
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 32
  bn.sid  x29, 0(x10++)
  bn.rshi w4, w2, w31 >> 144

  jal     x1, _inner_polyz_pack_17
  bn.rshi w4, w2, w4 >> 144
  bn.sid  x29, 0(x10++)

  ret

_inner_polyz_pack_17:
  bn.lid x6, 0(x11++)
  /* w1 <= eta - w1 */
  bn.subv.8s w1, w3, w1
  loopi 8, 2
    bn.rshi w2, w1, w2 >> 18 /* Write one coefficient into the output WDR */
    bn.rshi w1, w31, w1 >> 32 /* Shift out used coefficient */
  endloop
  bn.rshi w2, w31, w2 >> 112 /* Shift the 144 bits of data to the bottom of the
                               WDR */
  ret

.globl polyz_pack_19
.type polyz_pack_19, @function
polyz_pack_19:
  la x6, gamma1_vec_const_19
  li x28, 3
  bn.lid x28, 0(x6)

  /* Setup WDRs */
  li x6, 1
  li x29, 4
  loopi 4, 25
    jal     x1, _inner_polyz_pack_19
    bn.rshi w4, w2, w4 >> 160

    jal     x1, _inner_polyz_pack_19
    bn.rshi w4, w2, w4 >> 96
    bn.sid  x29, 0(x10++)
    bn.rshi w4, w2, w31 >> 160

    jal     x1, _inner_polyz_pack_19
    bn.rshi w4, w2, w4 >> 160

    jal     x1, _inner_polyz_pack_19
    bn.rshi w4, w2, w4 >> 32
    bn.sid  x29, 0(x10++)
    bn.rshi w4, w2, w31 >> 160

    jal     x1, _inner_polyz_pack_19
    bn.rshi w4, w2, w4 >> 128
    bn.sid  x29, 0(x10++)
    bn.rshi w4, w2, w31 >> 160

    jal     x1, _inner_polyz_pack_19
    bn.rshi w4, w2, w4 >> 160

    jal     x1, _inner_polyz_pack_19
    bn.rshi w4, w2, w4 >> 64
    bn.sid  x29, 0(x10++)
    bn.rshi w4, w2, w31 >> 160

    jal     x1, _inner_polyz_pack_19
    bn.rshi w4, w2, w4 >> 160
    bn.sid  x29, 0(x10++)
  endloop

  ret
_inner_polyz_pack_19:
  bn.lid x6, 0(x11++)
  /* w1 <= eta - w1 */
  bn.subv.8s w1, w3, w1
  loopi 8, 2
    bn.rshi w2, w1, w2 >> 20 /* Write one coefficient into the output WDR */
    bn.rshi w1, w31, w1 >> 32 /* Shift out used coefficient */
  endloop
  bn.rshi w2, w31, w2 >> 96 /* Shift the 96 bits of data to the bottom of the
                               WDR */
  ret

/**
 * poly_encode_h
 *
 * Encode hint to signature from single polynomial h[i].
 *
 * @param[in]  x11: pointer to input polynomial h[i]
 * @param[in]  x12: k, number of nonzero h coefficients so far
 * @param[in]  x13: i, index of this polynomial in h
 * @param[in]  x14: OMEGA
 * @param[out] x10: pointer to the start of all signature hint bytes
 *
 * clobbered registers: x5, x7, x11 to x12, x28 to x31
 * clobbered flag groups: none
 */
.globl poly_encode_h
.type poly_encode_h, @function
poly_encode_h:
  /* Masking constant for alignment */
  li x5, 0xFFFFFFFC

  /* j = 0 (index within h[i]) */
  li x7, 0

  /* Loop through each coefficient and store indices of nonzero ones. */
  loopi N, 13
    lw   x28, 0(x11)
    addi x11, x11, 4   /* Increment input pointer */
    beq  x0, x28, _skip_store_poly_encode_h
    add  x29, x10, x12  /* *sig + k */
    andi x30, x29, 0x3 /* preserve lower 2 bits */
    and  x29, x29, x5  /* align */
    lw   x31, 0(x29)   /* load form aligned(sig+k) */
    slli x30, x30, 3   /* #bytes -> #bits */
    sll  x30, x7, x30  /* j << #bits */
    or   x31, x31, x30
    sw   x31, 0(x29)

    addi x12, x12, 1 /* k++ */
_skip_store_poly_encode_h:
    addi x7, x7, 1
  endloop

  /* Store the number of nonzero coefficients after h[i] at the end. */
  add  x7, x13, x14   /* OMEGA + i */
  add  x7, x10, x7    /* *sig + OMEGA + i */
  andi x28, x7, 0x3   /* preserve lower 2 bits */
  and  x7, x7, x5    /* align */
  lw   x29, 0(x7)     /* load from aligned(*sig + OMEGA + i) */
  slli x28, x28, 3     /* #bytes -> #bits */
  sll  x28, x12, x28    /* k << #bits */
  or   x29, x29, x28
  sw   x29, 0(x7)

  ret

/**
 * Constant Time Dilithium reduce32
 *
 * Returns: reduce32(input1)
 *
 * This implements reduce32 for Dilithium, where n=256,q=8380417.
 *
 * @param[in]  x10: dptr_input1, dmem pointer to first word of input1 polynomial
 * @param[in]  w31: all-zero
 * @param[out] x11: dmem pointer to result
 *
 * clobbered registers: x5 to x7, x10 to x11, x28, w2, w4 to w6
 * clobbered flag groups: none
 */
.globl poly_reduce32
.type poly_reduce32, @function
poly_reduce32:
  /* Set up constants for input/state */
  li x6, 3
  li x5, 4
  li x7, 6

  /* Setup constant 1 << 22 */
  la        x6, reduce32_const
  bn.lid    x5, 0(x6)
  bn.shv.8s w4, w4 << 22

  /* Load q */
  la     x28, modulus
  bn.lid x7, 0(x28)

  /* Set up constants for input/state */
  li x28, 2

  loopi 32, 7
    bn.lid x28, 0(x10++)

    /* t = a + (1 << 22) */
    bn.addv.8s w5, w2, w4
    /* t = (a + (1 << 22)) >> 23 */
    /* Shift can be logical because inputs are positive anyways */
    bn.shv.8s  w5, w5 >> 23
    /* t = t * q */
    bn.mulv.8s.even.lo  w5, w5, w6
    bn.mulv.8s.odd.lo   w5, w5, w6
    /* a - t */
    bn.subv.8s w2, w2, w5

    bn.sid x28, 0(x11++)
  endloop

  ret

/**
 * Constant Time Dilithium polynomial power2round
 *
 * Returns: power2round(output2, output1, input) reduced mod q
 *
 * This implements the polynomial addition for Dilithium, where n=256,q=8380417.
 *
 * @param[in]  x10:  a, dmem pointer to first word of input polynomial
 * @param[in]  x11: a0, dmem pointer to output polynomial with coefficients c0
 * @param[in]  x12: a1, dmem pointer to output polynomial with coefficients c1
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x5 to x7, x10 to x12, x28, w4 to w7
 * clobbered flag groups: none
 */
.globl poly_power2round
.type poly_power2round, @function
poly_power2round:
  #define D 13
  /* Set up constants for input/state */
  li x5, 4
  li x7, 6
  li x28, 7

  /* Load (1 << (D-1)) - 1 as vector */
  la x6, power2round_D_preprocessed
  bn.lid x5, 0(x6)

  li x6, 5

  loopi 32, 7
    /* Load input */
    bn.lid x6, 0(x10++)

    /* Compute */
    /* (a + (1 << (D-1)) - 1) */
    bn.addv.8s w6, w4, w5
    /* a1 = (a + (1 << (D-1)) - 1) >> D */
    bn.shv.8s w6, w6 >> D
    /* a0 = (a1 << D) */
    bn.shv.8s w7, w6 << D
    /* a0 = a - (a1 << D) */
    bn.subv.8s w7, w5, w7

    /* Store */
    bn.sid x7, 0(x12++)
    bn.sid x28, 0(x11++)
  endloop

  ret

.data

/* Aligned buffer to store a WDR value. */
.balign 32
.weak poly_wdr2gpr
poly_wdr2gpr:
.word 0
.word 0
.word 0
.word 0
.word 0
.word 0
.word 0
.word 0
