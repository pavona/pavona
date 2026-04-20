/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

.equ x1,  ra
.equ x2,  sp
.equ x5,  t0
.equ x6,  t1
.equ x7,  t2
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x14, a4
.equ x15, a5
.equ x16, a6
.equ x17, a7
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6

.equ w31, bn0

#define MLDSA_KBITS         23
#define MLDSA_KBITS_PLUS_1  24
#define SHARE_STR_BYTES     768    /* (k+1) * 32 */

/*
 * Name: secb2amodq_bc22 (PINI, d = 2)
 *
 * Convert a 2-share Boolean sharing x^{B,k} of x in [0, q) into a 2-share
 * arithmetic sharing z^{A_p} with z = x.  Implements [BC22] Alg.11
 * (SecB2AModp).
 *
 * Alg.11 (d = 2; the line 1 loop runs once for i = 0):
 *   1: for i = 0 to d - 2 do
 *   2:    z_i^{A_p}     <- Z_p                                    . poly_rej_samp_bitsliced
 *   3:    z'_i^{A_p}    <- p - z_i^{A_p}                          . bitsliced borrow chain
 *   4: z'_{d-1}^{A_p}   <- 0
 *   5: a^{B,k}          <- SecA2BModp^d_k(z'^{A_p})               . seca2bmodq_bc22
 *   6: b^{B,k}          <- SecAddModp^d_k(a^{B,k}, x^{B,k})       . secaddmodq_bc22
 *   7: c^{B,k}          <- RefreshIOS^d_k(b^{B,k})                . fused with step 8
 *   8: z_{d-1}^{A_p}    <- UnMask^d_k(c^{B,k})                    . XOR-collapse
 *
 * @param[in]   x10: dptr_z, output ((k+1) * 2 * 32 bytes, bit k = 0).
 * @param[in]   x11: dptr_x, input  ((k+1) * 2 * 32 bytes, bit k = 0).
 * @param[in]   x13: dptr_scratch, 1536 B for seca2bmodq_bc22 (forwarded).
 * @param[in]   w31: all-zero.
 *
 * clobbered registers: x2, x5 to x7, x10 to x17, x28 to x31, w0 to w23
 * clobbered flag groups: FG0
 */
.globl secb2amodq_bc22
secb2amodq_bc22:
    /* z_0 staging in the shared scratchpad; standard 32 B prologue. */
    la   a4, scratch
    addi sp, sp, -32
    sw   a0, 0(sp)                 /* save z_out */
    sw   a1, 4(sp)                 /* save x_in */
    sw   a3, 8(sp)                 /* save scratch_ptr for seca2b */
    sw   a4, 12(sp)                /* save z_0 scratch ptr */

    /* Step 2: z_0 staged in caller-provided a4. */
    addi a0, a4, 0
    jal  ra, poly_rej_samp_bitsliced

    /* Step 3. */
    lw   t6, 0(sp)
    lw   t5, 12(sp)
    li   t0, 0
    li   t1, 1
    li   t2, 2
    li   t3, 31

    bn.lid t0, 0(t5++)
    bn.not w2, w0
    bn.sid t2, 0(t6++)
    bn.xor w1, w31, w31

    loopi 12, 4
        bn.lid t0, 0(t5++)
        bn.xor w2, w0, w1
        bn.sid t2, 0(t6++)
        bn.or  w1, w0, w1

    loopi 10, 5
        bn.lid t0, 0(t5++)
        bn.not w3, w0
        bn.xor w2, w3, w1
        bn.sid t2, 0(t6++)
        bn.and w1, w0, w1

    bn.sid t3, 0(t6++)

    /* Step 4: z'_{d-1}^{A_p} <- 0. */
    loopi MLDSA_KBITS_PLUS_1, 1
        bn.sid t3, 0(t6++)

    /* Step 5: a^{B,k} <- SecA2BModp^d_k(z'^{A_p}). */
    lw   a0, 0(sp)
    lw   a1, 0(sp)
    lw   a3, 8(sp)
    jal  ra, seca2bmodq_bc22

    /* Step 6: b^{B,k} <- SecAddModp^d_k(a^{B,k}, x^{B,k}). */
    lw   a0, 0(sp)
    lw   a1, 4(sp)
    lw   a2, 0(sp)
    li   a4, 2
    jal  ra, secaddmodq_bc22

    /* Steps 7+8: z_{d-1}^{A_p} <- UnMask^d_k(RefreshIOS^d_k(b^{B,k})). */
    lw   t6, 0(sp)
    addi a3, t6, 0                 /* b[share 0] read */
    addi a4, t6, SHARE_STR_BYTES   /* b[share 1] read */
    li   t1, 1
    li   t2, 2
    addi t5, t6, SHARE_STR_BYTES   /* z[share 1] write */
    li   t4, MLDSA_KBITS
    loop t4, 7
        bn.lid  t1, 0(a3++)
        bn.lid  t2, 0(a4++)
        bn.wsrr w3, URND
        bn.xor  w1, w1, w3
        bn.xor  w2, w2, w3
        bn.xor  w1, w1, w2
        bn.sid  t1, 0(t5++)
    li   t3, 31
    bn.sid t3, 0(t5)               /* z[share 1] bit k = 0 */

    /* z[share 0] <- z_0. */
    addi t5, t6, 0                 /* z[share 0] write */
    lw   a1, 12(sp)                /* z_0 source */
    li   t0, 0
    li   t4, MLDSA_KBITS
    loop t4, 2
        bn.lid t0, 0(a1++)
        bn.sid t0, 0(t5++)
    bn.sid t3, 0(t5)               /* z[share 0] bit k = 0 */

    addi sp, sp, 32
    ret
