/* Copyright zeroRISC Inc.
 * Copyright lowRISC Contributors.
 * Copyright 2016 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE.dcrypto file.
 *
 * Derived from code in
 * https://chromium.googlesource.com/chromiumos/platform/ec/+/refs/heads/cr50_stab/chip/g/dcrypto/dcrypto_bn.c
 */


.text
.globl modexp_65537
.globl modexp
.globl modexp_crt

/**
 * Conditionally overwrite bigint in dmem
 *
 * Depending on state of FG0.C overwrites a bigint in dmem with one from
 * a buffer in the wide reg file.
 *
 * Flags: Does not set any flags, does not use flags except FG0.C
 *
 * @param[in]  x21: dptr, pointer to first limb of bigint in dmem
 * @param[in]  x8: rptr, pointer to first limb of bigint in regfile buffer
 * @param[in]  FG.C: selection condition, overwrite dmem when FG0.C==1
 * @param[in]  x30: number of limbs
 * @param[in]  x9: pointer to temp reg, must be set to 3
 * @param[in]  x11: pointer to temp reg, must be set to 2
 *
 * clobbered registers: x8, x21, w0, w2
 * clobbered Flag Groups: FG1
 */
sel_sqr_or_sqrmul:
  /* iterate over all limbs */
  loop      x30, 8
    /* load limb from dmem */
    bn.lid    x9, 0(x21)

    /* load limb from regfile buffer */
    bn.movr   x11, x8++

    /* randomize dmem with value from URND (one extra dummy call to clear) */
    bn.addi   w31, w31, 0, FG1 /* dummy */
    bn.wsrr   w0, URND
    bn.sid    x0, 0(x21)

    /* select a limb and store to dmem */
    bn.sel    w0, w2, w3, FG0.C
    bn.sid    x0, 0(x21++)

    /* dummy call to clear */
    bn.addi   w31, w31, 0, FG1

  ret


/**
 * Constant-time bigint modular exponentiation
 *
 * Returns: C = modexp(A,E) = A^E mod M
 *
 * This implements the square and multiply algorithm, i.e. for each bit of the
 * exponent both the squared only and the squared with multiply results are
 * computed but one result is discarded.
 * Computation is carried out in the Montgomery domain, by using the montmul
 * primitive.
 * The squared Montgomery modulus RR and the Montgomery constant m0' have to
 * be precomputed and provided at the appropriate locations in dmem.
 *
 * Flags: The states of both FG0 and FG1 depend on intermediate values and are
 *        not usable after return.
 *
 * The base bignum A is expected in the input buffer, the exponent E in the
 * exp buffer, the result C is written to the output buffer.
 * Note, that the content of both, the input buffer and the exp buffer is
 * modified during execution.
 *
 * @param[in]   x2: dptr_c, dmem pointer to buffer for output C
 * @param[in]  x14: dptr_a, dmem pointer to first limb of input A
 * @param[in]  x15: dptr_e, dmem pointer to first limb of exponent E
 * @param[in]  x16: dptr_M, dmem pointer to first limb of modulus M
 * @param[in]  x17: dptr_m0d, dmem pointer to first limb of m0'
 * @param[in]  x18: dptr_RR, dmem pointer to first limb of RR
 * @param[in]  x30: N, number of limbs per bignum
 * @param[in]  w31: all-zero
 * @param[out] dmem[dptr_c:dptr_c+N*32] C, A^E mod M
 *
 * clobbered registers: x3 to x13, x16 to x29, x31
 *                      w0 to w3, w24 to w30
 *                      w4 to w[4+N-1]
 * clobbered Flag Groups: FG0, FG1
 */
modexp:
  /* prepare pointers to temp regs */
  li         x8, 4
  li         x9, 3
  li        x10, 4
  li        x11, 2

  /* Compute (N-1).
       x31 <= x30 - 1 = N - 1 */
  addi      x31, x30, -1

  /* Convert input to montgomery domain.
       dmem[dptr_a] <= montmul(A,RR) = A*R mod M */
  addi      x19, x14, 0
  addi      x20, x18, 0
  addi      x21, x14, 0
  jal       x1, montmul
  loop      x30, 2
    bn.sid    x8, 0(x21++)
    addi      x8, x8, 1

  /* zeroize w2 and reset flags */
  bn.sub    w2, w2, w2

  /* initialize the output buffer with -M */
  addi      x3, x16, 0
  addi      x21, x2, 0
  loop      x30, 3
    /* load limb from modulus */
    bn.lid    x11, 0(x3++)

    /* subtract limb from 0 */
    bn.subb   w2, w31, w2

    /* store limb in dmem */
    bn.sid    x11, 0(x21++)

  /* compute bit length of current bigint size */
  slli      x24, x30, 8

  /* iterate over all bits of bigint */
  loop      x24, 20
    /* square: out = montmul(out,out)  */
    addi      x19, x2, 0
    addi      x20, x2, 0
    addi      x21, x2, 0
    jal       x1, montmul
    /* Store result in dmem starting at dmem[dptr_c] */
    loop      x30, 2
      bn.sid    x8, 0(x21++)
      addi      x8, x8, 1

    /* multiply: out = montmul(in,out) */
    addi      x19, x14, 0
    addi      x20, x2, 0
    addi      x21, x2, 0
    jal       x1, montmul

    /* w2 <= w2 << 1 */
    bn.add    w2, w2, w2

    /* the loop performs a 1-bit left shift of the exponent. Last MSB moves
       to FG0.C, such that it can be used for selection */
    addi      x20, x15, 0
    loop      x30, 3
      bn.lid    x11, 0(x20)
      /* w2 <= w2 << 1 */
      bn.addc   w2, w2, w2
      bn.sid    x11, 0(x20++)

    /* select squared or squared+multiplied result */
    addi      x21, x2, 0
    jal       x1, sel_sqr_or_sqrmul

    nop

  /* convert back from montgomery domain */
  /* out = montmul(out,1) = out/R mod M  */
  addi      x19, x2, 0
  addi      x21, x2, 0
  jal       x1, montmul_mul1

  ret

/**
 * Constant-time bigint CRT modular exponentiation.
 *
 * Returns: C = modexp(A,E) = A^E mod M
 *     where
 *         E mod (p - 1) = E_p
 *         E mod (q - 1) = E_q
 *         M = p * q coprime.
 *
 * This implements the standard RSA CRT modexp algorithm, internally using the
 * square and multiply via calls to `modexp`. Base modular exponentiations are
 * performed in the Montgomery domain.
 *
 * The squared Montgomery modulus RR and the Montgomery constant m0' have to
 * be precomputed and provided at the appropriate locations in dmem.
 *
 * The base bignum A is expected in the input buffer, the primes in the p and q
 * buffers, the CRT components of the exponent E in the exp_p and exp_q buffers,
 * and the CRT reconstruction coefficient in the q_p buffer. The result C is
 * written to the output buffer.
 *
 * Note that the content of the exp_p and exp_q buffers will be modified during
 * computation.
 *
 * Flags: The states of both FG0 and FG1 depend on intermediate values and are
 *        not usable after return.
 *
 * @param[in]   x2: dptr_c, dmem pointer to buffer for output C
 * @param[in]   x3: dptr_exp, work buffer for `modexp` calls
 * @param[in]   x4: dptr_reduce, work buffer for modular reductions
 * @param[in]  x17: dptr_m0d, dmem pointer to first limb of m0'
 * @param[in]  x18: dptr_RR, dmem pointer to first limb of RR
 * @param[in]  x23: dptr_a, dmem pointer to first limb of input A
 * @param[in]  x25: dptr_e_p, dmem pointer to first limb of exponent CRT
       component E_p
 * @param[in]  x26: dptr_e_q, dmem pointer to first limb of exponent CRT
       component E_q
 * @param[in]  x27: dptr_p, dmem pointer to first limb of cofactor p
 * @param[in]  x28: dptr_q, dmem pointer to first limb of cofactor q
 * @param[in]  x29: dptr_q_p, dmem pointer to first limb of CRT reconstruction
       coefficient q_p
 * @param[in]  x30: N, number of limbs per bignum (must be even)
 * @param[in]  w31: all-zero
 * @param[out] dmem[dptr_c:dptr_c+N*32] C, A^E mod M
 *
 * clobbered registers: x2 to x29, x31
 *                      w0 to w3, w20 to w30
 *                      w4 to w[4+N-1]
 * clobbered Flag Groups: FG0, FG1
 */
modexp_crt:
  /* temporarially halve the limb count to copy a cofactor
       x30 <= N >> 1 = N / 2 */
  srli      x30, x30, 1

  /* copy the second cofactor, q, into the exp buffer to zero-extend
       dmem[dptr_exp:dptr_exp+(N/2)*32] <= q */
  addi      x11, x28, 0
  addi      x12, x3, 0
  li        x20, 20
  loop      x30, 2
    bn.lid    x20, 0(x11++)
    bn.sid    x20, 0(x12++)

  /* zero out the remainder of the exp region to perform the zero-extend
       dmem[dptr_exp+(N/2)*32:dptr_exp+N*32] <= 0 */
  li        x31, 31
  loop      x30, 1
    bn.sid    x31, 0(x12++)

  /* restore the limb count provided
       x30 <= 2*(N/2) = N */
  add       x30, x30, x30

  /* copy the message to the reduce buffer for in-place reduction
       dmem[dptr_reduce:dptr_reduce+N*32] <= A */
  addi      x11, x23, 0
  addi      x12, x4, 0
  loop      x30, 2
    bn.lid    x20, 0(x11++)
    bn.sid    x20, 0(x12++)

  /* save important dmem pointers for upcoming `div` call
       x6 <= dptr_a
       x7 <= dptr_e_p
       x9 <= dptr_e_q */
  addi      x6, x23, 0
  addi      x7, x25, 0
  addi      x9, x26, 0

  /* compute input A modulo second cofactor, q; here, we take advantage of the
     fact that div overwrites its input A with the remainder A mod q as a side
     effect, and we discard the quotient
       dmem[dptr_reduce:dptr_reduce+N*32] <= A mod q */
  addi      x10, x4, 0
  addi      x11, x3, 0
  addi      x12, x2, 0
  jal       x1, div

  /* restore clobbered dmem pointers
       x23 <= dptr_a
       x25 <= dptr_e_p
       x26 <= dptr_e_q
       x4 <= dptr_reduce
       x3 <= dptr_exp
       x2 <= dptr_c */
  addi      x23, x6, 0
  addi      x25, x7, 0
  addi      x26, x9, 0
  addi      x4, x10, 0
  addi      x3, x11, 0
  addi      x2, x12, 0

  /* temporarially halve the limb count to compute a base modexp
       x30 <= N >> 1 = N / 2 */
  srli      x30, x30, 1

  /* compute Montgomery constants for q */
  addi     x16, x28, 0
  addi     x14, x2, 0
  addi     x15, x3, 0
  jal      x1, modload

  /* restore clobbered dmem pointers
       x2 <= dptr_c
       x3 <= dptr_exp */
  addi     x2, x14, 0
  addi     x3, x15, 0

  /* compute q-component of modexp result, saving dptr_exp as well
       dmem[dptr_c:dptr_c+(N/2)*32] <= C_q = A_q^(E_q) mod q
       x4 <= dptr_exp
       x14 <= dptr_reduce
       x15 <= dptr_e_q
       x16 <= dptr_q */
  addi      x14, x4, 0
  addi      x4, x3, 0
  addi      x15, x26, 0
  addi      x16, x28, 0
  jal       x1, modexp

  /* restore clobbered dmem pointers
       x3 <= dptr_exp
       x4 <= dptr_reduce */
  addi      x3, x4, 0
  addi      x4, x14, 0

  /* copy the the q-component of the modexp result over E_q
       dmem[dptr_e_q:dptr_e_q+(N/2)*32] <= C_q */
  addi      x11, x2, 0
  addi      x12, x26, 0
  li        x20, 20
  loop      x30, 2
    bn.lid    x20, 0(x11++)
    bn.sid    x20, 0(x12++)

  /* copy the first cofactor, p, into the exp buffer to zero-extend
       dmem[dptr_exp:dptr_exp+(N/2)*32] <= p */
  addi      x11, x27, 0
  addi      x12, x3, 0
  loop      x30, 2
    bn.lid    x20, 0(x11++)
    bn.sid    x20, 0(x12++)

  /* zero out the remainder of the exp region to perform the zero-extend
       dmem[dptr_exp+(N/2)*32:dptr_exp+N*32] <= 0 */
  li        x31, 31
  loop      x30, 1
    bn.sid    x31, 0(x12++)

  /* restore the limb count provided
       x30 <= 2*(N/2) = N */
  add       x30, x30, x30

  /* copy the message to the reduce buffer for in-place reduction
       dmem[dptr_reduce:dptr_reduce+N*32] <= A */
  addi      x11, x23, 0
  addi      x12, x4, 0
  loop      x30, 2
    bn.lid    x20, 0(x11++)
    bn.sid    x20, 0(x12++)

  /* save important dmem pointers for upcoming `div` call
       x6 <= dptr_a
       x7 <= dptr_e_p
       x9 <= dptr_e_q */
  addi      x6, x23, 0
  addi      x7, x25, 0
  addi      x9, x26, 0

  /* compute input A modulo first cofactor, p
       dmem[dptr_exp:dptr_exp+N*32] <= A mod p */
  addi      x10, x4, 0
  addi      x11, x3, 0
  addi      x12, x2, 0
  jal       x1, div

  /* restore clobbered dmem pointers
       x23 <= dptr_a
       x25 <= dptr_e_p
       x26 <= dptr_e_q
       x4 <= dptr_reduce
       x3 <= dptr_exp
       x2 <= dptr_c */
  addi      x23, x6, 0
  addi      x25, x7, 0
  addi      x26, x9, 0
  addi      x4, x10, 0
  addi      x3, x11, 0
  addi      x2, x12, 0

  /* temporarially halve the limb count to compute a base modexp
       x30 <= N >> 1 = N / 2 */
  srli      x30, x30, 1

  /* compute Montgomery constants for p */
  addi     x16, x27, 0
  addi     x14, x2, 0
  addi     x15, x3, 0
  jal      x1, modload

  /* restore clobbered dmem pointers
       x2 <= dptr_c
       x3 <= dptr_exp */
  addi     x2, x14, 0
  addi     x3, x15, 0

  /* compute p-component of modexp result, saving dptr_exp as well
       dmem[dptr_c:dptr_c+(N/2)*32] <= C_p = A_p^(E_p) mod p
       x4 <= dptr_exp
       x14 <= dptr_reduce
       x15 <= dptr_e_q
       x16 <= dptr_q */
  addi      x14, x4, 0
  addi      x4, x3, 0
  addi      x15, x25, 0
  addi      x16, x27, 0
  jal       x1, modexp

  /* restore clobbered dmem pointers
       x3 <= dptr_exp
       x4 <= dptr_reduce */
  addi      x3, x4, 0
  addi      x4, x14, 0

  /* copy the the p-component of the modexp result over E_p
       dmem[dptr_e_p:dptr_e_p+(N/2)*32] <= C_p */
  addi      x11, x2, 0
  addi      x12, x25, 0
  li        x20, 20
  loop      x30, 2
    bn.lid    x20, 0(x11++)
    bn.sid    x20, 0(x12++)

  /* clear any flags in FG0 */
  bn.sub    w31, w31, w31, FG0

  /* compare C_p and C_q
       FG0.C <= C_p > C_q */
  addi       x11, x25, 0
  addi       x12, x26, 0
  li         x21, 21
  loop       x30, 3
    /* w20 <= C_p[i] */
    bn.lid   x20, 0(x11++)
    /* w21 <= C_q[i] */
    bn.lid   x21, 0(x12++)
    /* FG0.C <= C_p[i] <? C_q[i] + FG0.C */
    bn.cmpb  w20, w21, FG0

  /* capture FG0.C in a mask
       w23 <= FG0.C ? 2^256 - 1 : 0 */
  bn.subb  w23, w31, w31

  /* clear any flags in both flag groups */
  bn.sub    w31, w31, w31, FG0
  bn.sub    w31, w31, w31, FG1

  /* subtract C_p from C_q, conditionally adding the modulus if C_p > C_q
       dmem[dptr_e_q..dptr_e_q+(N/2)*32] <= C_q - C_p mod p */
  addi       x11, x25, 0
  addi       x12, x26, 0
  addi       x13, x27, 0
  loop       x30, 7
    /* w20 <= C_p[i] */
    bn.lid   x20, 0(x11)
    /* w21 <= C_q[i] */
    bn.lid   x21, 0(x12++)
    /* w20, FG0.C <= C_p[i] - C_q[i] - FG0.C */
    bn.subb  w20, w20, w21, FG0
    /* w21 <= p[i] */
    bn.lid   x21, 0(x13++)
    /* w21 <= p[i] & w23 */
    bn.and   w21, w21, w23
    /* w20, FG1.C <= w20 + w21 + FG1.C  */
    bn.addc  w20, w20, w21, FG1
    /* dmem[dptr_e_p..dptr_e_q+(plen*32)] <= w20 */
    bn.sid   x20, 0(x11++)

  /* preserve dptr_a across the next few calls
       x9 <= dptr_a */
  addi      x9, x23, 0

  /* save important dmem pointers for upcoming `bignum_mul` call
       x13 <= dptr_exp
       x14 <= dptr_reduce */
  addi      x13, x3, 0
  addi      x14, x4, 0

  /* multiply difference by q_p, inverse of q mod p
      dmem[dptr_c..dptr_c+(N/2)*32] <= q_p * (C_q - C_p) */
  addi      x10, x25, 0
  addi      x11, x29, 0
  addi      x12, x2, 0
  jal       x1, bignum_mul

  /* restore clobbered dmem pointers
       x2 <= dptr_c
       x3 <= dptr_exp
       x4 <= dptr_reduce */
  addi      x2, x12, 0
  addi      x3, x13, 0
  addi      x4, x14, 0

  /* restore the limb count provided
       x30 <= 2*(N/2) = N */
  add       x30, x30, x30

  /* save important dmem pointer for upcoming `div` call
       x13 <= dptr_e_q */
  addi      x13, x26, 0

  /* reduce mod p
      dmem[dptr_c..dptr_c+(N/2)*32] <= h = q_p * (C_q - C_p) mod p */
  addi      x10, x2, 0
  addi      x11, x3, 0
  addi      x12, x4, 0
  jal       x1, div

  /* restore clobbered dmem pointers
       x2 <= dptr_c
       x3 <= dptr_exp
       x4 <= dptr_reduce
       x26 <= dptr_e_q */
  addi      x2, x10, 0
  addi      x3, x11, 0
  addi      x4, x12, 0
  addi      x26, x13, 0

  /* temporarially halve the limb count to copy a cofactor
       x30 <= N >> 1 = N / 2 */
  srli      x30, x30, 1

  /* multiply result by q
       dmem[dptr_a..dptr_a+N*32] = h * q */
  addi      x10, x2, 0
  addi      x11, x28, 0
  addi      x12, x9, 0
  jal       x1, bignum_mul

  /* restore clobbered dmem pointers
       x2 <= dmem_c
       x3 <= dptr_exp */
  addi      x2, x10, 0
  addi      x3, x12, 0

  /* finally, add C_q to the result and write it back
       dmem[dptr_c..dptr_c+N*32] = h * q + C_q = modexp(A,E) */
  addi     x11, x9, 0
  addi     x12, x26, 0
  addi     x13, x2, 0
  loop     x30, 4
    /* w20 <= (h * q)[i] */
    bn.lid   x20, 0(x11++)
    /* w20 <= C_q[i] */
    bn.lid   x21, 0(x12++)
    /* w20, FG0.C <= (h * q)[i] + C_q[i] + FG0.C */
    bn.addc  w20, w20, w21
    /* dmem[dptr_c + i] <= w20 */
    bn.sid   x20, 0(x13++)

  loop     x30, 3
    /* w20 <= (h * q)[N/2 + i] */
    bn.lid   x20, 0(x11++)
    /* w20, FG0.C <= w[4 + N/2 + i] + FG0.C */
    bn.addc  w20, w20, w31
    /* dmem[dptr_c + N/2 + i] <= w20 */
    bn.sid   x20, 0(x13++)

  /* restore the limb count provided
       x30 <= 2*(N/2) = N */
  add       x30, x30, x30

  ret


/**
 * Bigint modular exponentiation with fixed exponent of 65537
 *
 * Returns: C = modexp(A,65537) = A^65537 mod M
 *
 * This implements the square and multiply algorithm for the fixed exponent
 * of E=65537. Note that this implementation (in contrast to modexp) runs the
 * multiplication step only for bits being actually set in the exponent.
 * Since the exponent is fixed, this is inherently constant-time.
 *
 * The squared Montgomery modulus RR and the Montgomery constant m0' have to
 * be precomputed and provided at the appropriate locations in dmem.
 *
 * Flags: The states of both FG0 and FG1 depend on intermediate values and are
 *        not usable after return.
 *
 * The base bignum A is expected in the input buffer, the result C is written
 * to the output buffer. Note, that the content of the input buffer is
 * modified during execution.
 *
 * @param[in]   x2: dptr_c, dmem pointer to buffer for output C
 * @param[in]  x14: dptr_a, dmem pointer to first linb of input A
 * @param[in]  x16: dptr_M, dmem pointer to first limb of modulus M
 * @param[in]  x17: dptr_m0d, dmem pointer to Mongtgomery constant m0'
 * @param[in]  x18: dptr_RR, dmem pointer to Montgmery constant RR
 * @param[in]  x30: N, number of limbs per bignum
 * @param[in]  w31: all-zero
 * @param[out] dmem[dptr_c:dptr_c+N*32] C, A^65537 mod M
 *
 * clobbered registers: x3 to x13, x16 to x31
 *                      w0 to w3, w24 to w30
 *                      w4 to w[4+N-1]
 * clobbered Flag Groups: FG0, FG1
 */
modexp_65537:
  /* prepare pointers to temp regs */
  li         x8, 4
  li         x9, 3
  li        x10, 4
  li        x11, 2

  /* Compute (N-1).
       x31 <= x30 - 1 = N - 1 */
  addi      x31, x30, -1

  /* convert to montgomery domain montmul(A,RR)
  in = montmul(A,RR) montmul(A,RR) = C*R mod M */
  addi      x19, x14, 0
  addi      x20, x18, 0
  addi      x21, x14, 0
  jal       x1, montmul
  /* Store result in dmem starting at dmem[dptr_a] */
  loop      x30, 2
    bn.sid    x8, 0(x21++)
    addi      x8, x8, 1

  /* pointer to out buffer */
  addi      x21, x2, 0

  /* zeroize w2 and reset flags */
  bn.sub    w2, w2, w2

  /* pointer to modulus */
  addi      x3, x16, 0

  /* this loop initializes the output buffer with -M */
  loop      x30, 3
    /* load limb from modulus */
    bn.lid    x11, 0(x3++)

    /* subtract limb from 0 */
    bn.subb   w2, w31, w2

    /* store limb in dmem */
    bn.sid    x11, 0(x21++)

  /* TODO: Is this squaring necessary? */
  /* 65537 = 0b10000000000000001
               ^ sqr + mult
    out = montmul(out,out)       */
  addi      x19, x2, 0
  addi      x20, x2, 0
  jal       x1, montmul
  /* Store result in dmem starting at dmem[dptr_c] */
  addi      x21, x2, 0
  loop      x30, 2
    bn.sid    x8, 0(x21++)
    addi      x8, x8, 1

  /* out = montmul(in,out)       */
  addi      x19, x14, 0
  addi      x20, x2, 0
  jal       x1, montmul

  /* store multiplication result in output buffer */
  addi      x21, x2, 0
  li        x8, 4
  loop      x30, 2
    bn.sid    x8, 0(x21++)
    addi      x8, x8, 1

  /* 65537 = 0b10000000000000001
                ^<< 16 x sqr >>^   */
  loopi      16, 8
    /* square: out = montmul(out, out) */
    addi      x19, x2, 0
    addi      x20, x2, 0
    jal       x1, montmul
    /* Store result in dmem starting at dmem[dptr_c] */
    addi      x21, x2, 0
    loop      x30, 2
      bn.sid    x8, 0(x21++)
      addi      x8, x8, 1
    nop

  /* 65537 = 0b10000000000000001
                          mult ^
     out = montmul(in,out)       */
  addi      x19, x14, 0
  addi      x20, x2, 0
  jal       x1, montmul

  /* store multiplication result in output buffer */
  addi      x21, x2, 0
  li        x8, 4
  loop      x30, 2
    bn.sid    x8, 0(x21++)
    addi      x8, x8, 1

  /* convert back from montgomery domain */
  /* out = montmul(out,1) = out/R mod M  */
  addi      x19, x2, 0
  addi      x21, x2, 0
  jal       x1, montmul_mul1

  ret

/**
 * Constant time conditional bigint subtraction
 *
 * Returns C = A-x*B
 *         with A being a bigint of length 256..4096 bit
 *              B being a bigint of length 256..4096 bit
 *              C being a bigint of length 256..4096 bit
 *              x being a boolean value [0,1]
 *
 * Depending on state of FG1.C subtracts a bigint B located in dmem from
 * another bigint A, located in the wide reg file and stores result C in dmem.
 *
 * Flags: When leaving this subroutine, flags of FG0 depend on a
 *        potentially discarded value and therefore are not usable after
 *        return. FG1 is not modified in this subroutine.
 *
 * @param[in]  x16: dmem pointer to first limb of subtrahend (B)
 * @param[in]  x8: regfile pointer to first limb of minuend (input A)
 * @param[in]  x21: dmem pointer to first limb of result (C)
 * @param[in]  x30: N, number of limbs
 * @param[in]  FG1.C: subtraction condition, subtract if 1 (x)
 * @param[in]  x9: pointer to temp reg, must be set to 3
 * @param[in]  x11: pointer to temp reg, must be set to 2
 * @param[in]  FG0.C: needs to be set to 0
 *
 * clobbered registers: x8, x16, x21, w2, w3
 * clobbered Flag Groups: FG0
 */
cond_sub_to_dmem:
  /* iterate over all limbs for conditional limb-wise subtraction */
  loop      x30, 5
    /* load limb of subtrahend (input B): w3 = dmem[x16+i] */
    bn.lid    x9, 0(x16++)

    /* move limb from bignum bufer to w2 */
    bn.movr   x11, x8++

    /* perform subtraction for a limb w3 = w2-1 */
    bn.subb   w3, w2, w3

    /* conditionally select subtraction result or unmodified limb */
    bn.sel    w2, w3, w2, FG1.C

    /* store selection result in dmem */
    bn.sid    x11, 0(x21++)

  ret

/**
 * Constant-time Montgomery modular multiply by one
 *
 * Returns: C = montmul(1,A) = A*R^(-1) mod M
 *
 * Routine for back-conversion from Montgomery domain.
 * This implements the limb-by-limb interleaved Montgomery Modular
 * Multiplication Algorithm, with one operand fixed to 1. This is only a
 * wrapper around the main loop body. For algorithmic implementation details
 * see the mont_loop subroutine.
 *
 * Flags: The states of both FG0 and FG1 depend on intermediate values and are
 *        not usable after return.
 *
 * @param[in]  x16: dmem pointer to first limb of modulus M
 * @param[in]  x17: dptr_m0d, dmem pointer to Montgomery Constant m0'
 * @param[in]  x19: dmem pointer to first limb of operand A
 * @param[in]  x21: dmem pointer to first limb of result C
 * @param[in]  x30: N, number of limbs
 * @param[in]  x31: N-1, number of limbs minus one
 * @param[in]  x8: pointer to temp reg, must be set to 4
 * @param[in]  x9: pointer to temp reg, must be set to 3
 * @param[in]  x10: pointer to temp reg, must be set to 4
 * @param[in]  x11: pointer to temp reg, must be set to 2
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x6, x7, x8, x12, x13, x21, x22,
 *                      w2, w3, w4 to w[4+N-1], w24 to w30
 * clobbered Flag Groups: FG0, FG1
 */
montmul_mul1:
  /* load Montgomery constant: w3 = dmem[x17] = dmem[dptr_m0d] = m0' */
  bn.lid    x9, 0(x17)

  /* init regfile bigint buffer with zeros */
  bn.mov    w2, w31
  loop      x30, 1
    bn.movr   x10++, x11

  /* w2=1 this is operand B */
  bn.xor    w2, w2, w2
  bn.addi   w2, w2, 1

  /* save dmem pointers for operand A and modulus */
  addi      x6, x16, 0
  addi      x7, x19, 0

  /* iterate over limbs of operand B */
  loop      x30, 4

    /* restore  dmem pointers for operand A and modulus */
    addi      x16, x6, 0
    addi      x19, x7, 0

    /* Main loop body of Montgomery Multiplication algorithm */
    /* 1[i]*A */
    jal       x1, mont_loop

    /* all subsequent limbs of operand B are zero since B=1 */
    bn.mov    w2, w31

  /* restore dmem pointers for operand A and modulus */
  addi      x16, x6, 0
  addi      x19, x7, 0

  /* zeroize w2 and clear flags */
  bn.sub    w2, w2, w2, FG1

  /* iterate over all limbs of bigint buffer for limbwise comparison of
     buffer with the Modulus. After last loop cycle, FG1.C is set if bigint
     in buffer is larger than Modulus */
  loop      x30, 3

    /* load limb of limb of Modulus to w3 */
    bn.lid    x9, 0(x16++)

    /* load limb from bigint buffer to w2 */
    bn.movr   x11, x8++

    /* compare limb of flag with limb of Modulus */
    bn.cmpb   w3, w2, FG1

  /* restore pointers to bigint buffer in regfile */
  li         x8, 4
  li        x10, 4

  /* restore  dmem pointers for operand A and modulus */
  addi      x16, x6, 0
  addi      x19, x7, 0

  /* conditionally subtract Modulus from buffer and store result in
     dmem[x21] to dmem[x21+N] */
  jal       x1, cond_sub_to_dmem

  /* restore  dmem pointers for operand A and modulus */
  addi      x16, x6, 0
  addi      x19, x7, 0

  ret
