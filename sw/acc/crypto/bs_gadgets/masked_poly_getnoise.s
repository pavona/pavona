/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#ifndef NSHARES
    #define NSHARES 2
#endif

#define NB_POLY 512 /* Number of bytes occupied by a polynomial */
#define N_COEFFS 16 /* Number of coeffs fitting in a WDR */

/* Register aliases */
.equ x2, sp
.equ x3, fp
.equ x5, t0
#define t1 x6
.equ x7, t2
.equ x8, s0
.equ x9, s1
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ x13, a3
.equ x14, a4
.equ x15, a5
.equ x16, a6
.equ x17, a7
.equ x18, s2
.equ x19, s3
.equ x20, s4
.equ x21, s5
.equ x22, s6
.equ x23, s7
.equ x24, s8
.equ x25, s9
.equ x26, s10
.equ x27, s11
.equ x28, t3
.equ x29, t4
.equ x30, t5
.equ x31, t6

.equ w31, bn0

/* Config to start a SHAKE-256 operation. */
#define SHAKE256_CFG 0xA
#define wone w30

/*
 * Name:        poly_getnoise_eta_init
 *
 * Description: Prepares for polynomial CBD sampling via either of
 *              `poly_getnoise_eta_1` or `poly_getnoise_eta_2` given a seed and
 *              a nonce by initializing a SHAKE256 operation.
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: dptr_input, dmem pointer to input seed
 * @param[in]  x11: *nonce
 *
 * clobbered registers: x5, w0
 * clobbered flag groups: None
 */
.globl poly_getnoise_eta_init
poly_getnoise_eta_init:
    /* Initialize a SHAKE256 operation. */
    addi  t0, x0, 33
    slli  t0, t0, 5
    addi  t0, t0, SHAKE256_CFG
#if NSHARES == 2
    addi  t1, x0, 1
    slli  t1, t1, 20
    add   t0, t0, t1
#endif
    csrrw x0, kmac_cfg, t0

    /* Send the message to the Keccak core. */
#if NSHARES == 2
    bn.xor  w0, w0, w0 /* Whitening. */
    bn.lid  x0, 0(a0++)
    bn.wsrw kmac_msg, w0
    bn.xor  w0, w0, w0 /* Whitening. */
    bn.lid  x0, 0(a0++)
    bn.wsrw kmac_msg1, w0
    li      t0, 1
    csrrw   x0, kmac_partial_write, t0
    bn.lid  x0, 0(a1)
    bn.wsrw kmac_msg, w0
    bn.xor  w0, w0, w0
    bn.wsrw kmac_msg1, w0
#else
    bn.lid  x0, 0(a0)
    bn.wsrw kmac_msg, w0
    li      t0, 1
    csrrw   x0, kmac_partial_write, t0
    bn.lid  x0, 0(a1)
    bn.wsrw kmac_msg, w0
#endif

    ret

/*
 * Name: masked_poly_getnoise_eta_1
 *
 * Sample a polynomial deterministically from a seed and a nonce, with output
 * polynomial close to centered binomial distribution with parameter KYBER_ETA1;
 * this function assumes `poly_getnoise_eta_init` has been called first with the
 * appropriate seed and nonce.
 *
 * @param[in]  x10: eta
 * @param[out] x11: ptr_ra, dmem_ptr to arithmetic shares of r
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */
.globl masked_poly_getnoise_eta_1
masked_poly_getnoise_eta_1:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw   s0, 4(fp)
    sw   s1, 8(fp)
    sw   s2, 12(fp)
    sw   s3, 16(fp)
    addi s0, a0, 0
    addi s1, x0, NSHARES
    addi s2, a1, 0

    /* Adjust stack for intermediate variables. */
    slli t0, a0, 5 /* eta * 32 */
    loop s1, 1
        sub sp, sp, t0
    addi s3, sp, 0 /* ptr_x */
    loop s1, 1
        sub sp, sp, t0 /* ptr_y */

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    /* Create mask 0x1. */
    bn.subi    wone, bn0, 1
    bn.shv.16h wone, wone >> 15

    addi x4, x0, 3
    bne  a0, x4, _handle_eta_2
#if NSHARES == 2
    #define w0_share0 w15
    #define w0_share1 w16
    #define w1_share0 w17
    #define w1_share1 w18
    #define w2_share0 w19
    #define w2_share1 w20
    #define w3_share0 w21
    #define w3_share1 w22
    /* The first three digests are for used immediately later. */
    bn.wsrr w0_share0, kmac_digest
    bn.wsrr w0_share1, kmac_digest1
    bn.wsrr w1_share0, kmac_digest
    bn.wsrr w1_share1, kmac_digest1
    bn.wsrr w2_share0, kmac_digest
    bn.wsrr w2_share1, kmac_digest1
    /* This digest is squeezed out in advance so that KMAC is refreshed.
        * While waiting for this, we generate x and y. */
    bn.wsrr w3_share0, kmac_digest
    bn.wsrr w3_share1, kmac_digest1
    jal     x1, _gen_input_k2
    bn.mov  w0_share0, w3_share0
    bn.mov  w0_share1, w3_share1
    bn.wsrr w1_share0, kmac_digest
    bn.wsrr w1_share1, kmac_digest1
    bn.wsrr w2_share0, kmac_digest
    bn.wsrr w2_share1, kmac_digest1
    jal     x1, _gen_input_k2
    /* Done and save results to assigned buffers. */
    addi   t0, s3, 0 /* ptr_x */
    addi   t1, sp, 0 /* ptr_y */
    addi   x4, x0, 3
    bn.sid x4++, 0(t0)
    bn.sid x4++, 32(t0)
    bn.sid x4++, 64(t0)
    bn.sid x4++, 96(t0)
    bn.sid x4++, 128(t0)
    bn.sid x4++, 160(t0)
    bn.sid x4++, 0(t1)
    bn.sid x4++, 32(t1)
    bn.sid x4++, 64(t1)
    bn.sid x4++, 96(t1)
    bn.sid x4++, 128(t1)
    bn.sid x4++, 160(t1)
#else
    #define xwb0 w4
    #define xwb1 w5
    #define xwb2 w6
    #define ywb0 w7
    #define ywb1 w8
    #define ywb2 w9
    /* The first three digests are for used immediately later. */
    bn.wsrr w0, kmac_digest
    bn.wsrr w1, kmac_digest
    bn.wsrr w2, kmac_digest
    /* This digest is squeezed out in advance so that KMAC is refreshed.
    * While waiting for this, we generate x and y. */
    bn.wsrr w3, kmac_digest
    jal     x1, _gen_input_k2
    bn.mov  w0, w3
    bn.wsrr w1, kmac_digest
    bn.wsrr w2, kmac_digest
    jal     x1, _gen_input_k2
    /* Done and save results to assigned buffers. */
    addi t0, s1, -1 /* nshares - 1 */
    addi x4, x0, 1
    addi t1, s3, 0 /* ptr_x */
    addi t2, sp, 0 /* ptr_y */
    loop t0, 18
        bn.wsrr w1, urnd
        bn.sid  x4, 0(t1++)
        bn.xor  xwb0, xwb0, w1
        bn.wsrr w1, urnd
        bn.sid  x4, 0(t1++)
        bn.xor  xwb1, xwb1, w1
        bn.wsrr w1, urnd
        bn.sid  x4, 0(t1++)
        bn.xor  xwb2, xwb2, w1
        bn.wsrr w1, urnd
        bn.sid  x4, 0(t2++)
        bn.xor  ywb0, ywb0, w1
        bn.wsrr w1, urnd
        bn.sid  x4, 0(t2++)
        bn.xor  ywb1, ywb1, w1
        bn.wsrr w1, urnd
        bn.sid  x4, 0(t2++)
        bn.xor  ywb2, ywb2, w1
    addi   x4, x0, 4
    bn.sid x4++, 0(t1)
    bn.sid x4++, 32(t1)
    bn.sid x4++, 64(t1)
    bn.sid x4++, 0(t2)
    bn.sid x4++, 32(t2)
    bn.sid x4++, 64(t2)
#endif /* NSHARES == 2*/
    beq x0, x0, _handle_common

_handle_eta_2:
#if NSHARES == 2
    #define xwb0_share0_2 w3
    #define xwb1_share0_2 w4
    #define xwb0_share1_2 w5
    #define xwb1_share1_2 w6
    #define ywb0_share0_2 w7
    #define ywb1_share0_2 w8
    #define ywb0_share1_2 w9
    #define ywb1_share1_2 w10
    #define wtmp w1

    loopi 4, 41
        /* Handle first share. */
        bn.wsrr w0, kmac_digest
        loopi 4, 18
            loopi N_COEFFS, 2
                bn.rshi w2, w0, w2 >> 16
                bn.rshi w0, bn0, w0 >> 4
            bn.and     wtmp, w2, wone
            bn.shv.16h xwb0_share0_2, xwb0_share0_2 << 1
            bn.xor     xwb0_share0_2, xwb0_share0_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h xwb1_share0_2, xwb1_share0_2 << 1
            bn.xor     xwb1_share0_2, xwb1_share0_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h ywb0_share0_2, ywb0_share0_2 << 1
            bn.xor     ywb0_share0_2, ywb0_share0_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h ywb1_share0_2, ywb1_share0_2 << 1
            bn.xor     ywb1_share0_2, ywb1_share0_2, wtmp
        /* Handle second share. */
        bn.wsrr w0, kmac_digest1
        loopi 4, 18
            loopi N_COEFFS, 2
                bn.rshi w2, w0, w2 >> 16
                bn.rshi w0, bn0, w0 >> 4
            bn.and     wtmp, w2, wone
            bn.shv.16h xwb0_share1_2, xwb0_share1_2 << 1
            bn.xor     xwb0_share1_2, xwb0_share1_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h xwb1_share1_2, xwb1_share1_2 << 1
            bn.xor     xwb1_share1_2, xwb1_share1_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h ywb0_share1_2, ywb0_share1_2 << 1
            bn.xor     ywb0_share1_2, ywb0_share1_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h ywb1_share1_2, ywb1_share1_2 << 1
            bn.xor     ywb1_share1_2, ywb1_share1_2, wtmp
        nop

    addi   t0, s3, 0
    addi   t1, sp, 0
    addi   x4, x0, 3
    bn.sid x4++, 0(t0)
    bn.sid x4++, 32(t0)
    bn.sid x4++, 64(t0)
    bn.sid x4++, 96(t0)
    bn.sid x4++, 0(t1)
    bn.sid x4++, 32(t1)
    bn.sid x4++, 64(t1)
    bn.sid x4++, 96(t1)

#else
    #define xwb0_2 w3
    #define xwb1_2 w4
    #define ywb0_2 w5
    #define ywb1_2 w6
    #define wtmp w1

    loopi 4, 21
        bn.wsrr w0, kmac_digest
        loopi 4, 18
            loopi N_COEFFS, 2
                bn.rshi w2, w0, w2 >> 16
                bn.rshi w0, bn0, w0 >> 4
            bn.and     wtmp, w2, wone
            bn.shv.16h xwb0_2, xwb0_2 << 1
            bn.xor     xwb0_2, xwb0_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h xwb1_2, xwb1_2 << 1
            bn.xor     xwb1_2, xwb1_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h ywb0_2, ywb0_2 << 1
            bn.xor     ywb0_2, ywb0_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h ywb1_2, ywb1_2 << 1
            bn.xor     ywb1_2, ywb1_2, wtmp
        nop

    addi t0, s1, -1 /* nshares - 1 */
    addi x4, x0, 1
    addi t1, s3, 0 /* ptr_x */
    addi t2, sp, 0 /* ptr_y */
    loop t0, 12
        bn.wsrr w1, urnd
        bn.sid  x4, 0(t1++)
        bn.xor  xwb0_2, xwb0_2, w1
        bn.wsrr w1, urnd
        bn.sid  x4, 0(t1++)
        bn.xor  xwb1_2, xwb1_2, w1
        bn.wsrr w1, urnd
        bn.sid  x4, 0(t2++)
        bn.xor  ywb0_2, ywb0_2, w1
        bn.wsrr w1, urnd
        bn.sid  x4, 0(t2++)
        bn.xor  ywb1_2, ywb1_2, w1
    addi   x4, x0, 3
    bn.sid x4++, 0(t1)
    bn.sid x4++, 32(t1)
    bn.sid x4++, 0(t2)
    bn.sid x4++, 32(t2)

#endif /* NSHARES == 2 */

_handle_common:
    /* Compute r = masked_cbd_bc22(x, y, eta, nshares). */
    addi a0, s3, 0 /* ptr_x */
    addi a1, sp, 0 /* ptr_y */
    addi a2, s0, 0 /* eta */
    addi a3, s1, 0 /* nshares */
    addi a4, s2, 0 /* ptr_r */
    jal  x1, masked_cbd_bc22

    /* Restore inputs. */
    addi a0, s0, 0
    addi a1, s1, 0
    /* We want to point r to the next polynomial for next cbd. */
    addi a2, s2, NB_POLY

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)
    lw s3, 16(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret

/*
 * Name: _gen_input_k2
 *
 * Helper function for masked_poly_getnoise_eta_1 when KYBER_K == 2.
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */
_gen_input_k2:
    #define wtmp0 w23
    #define wtmp1 w24
#if NSHARES == 2
    #define xwb0_share0 w3
    #define xwb1_share0 w4
    #define xwb2_share0 w5
    #define xwb0_share1 w6
    #define xwb1_share1 w7
    #define xwb2_share1 w8
    #define ywb0_share0 w9
    #define ywb1_share0 w10
    #define ywb2_share0 w11
    #define ywb0_share1 w12
    #define ywb1_share1 w13
    #define ywb2_share1 w14
    /* Handle first share. */
    loopi 2, 26
        loopi N_COEFFS, 2
            bn.rshi wtmp0, w0_share0, wtmp0 >> 16
            bn.rshi w0_share0, bn0, w0_share0 >> 6
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb0_share0, xwb0_share0 << 1
        bn.xor     xwb0_share0, xwb0_share0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb1_share0, xwb1_share0 << 1
        bn.xor     xwb1_share0, xwb1_share0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb2_share0, xwb2_share0 << 1
        bn.xor     xwb2_share0, xwb2_share0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb0_share0, ywb0_share0 << 1
        bn.xor     ywb0_share0, ywb0_share0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb1_share0, ywb1_share0 << 1
        bn.xor     ywb1_share0, ywb1_share0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb2_share0, ywb2_share0 << 1
        bn.xor     ywb2_share0, ywb2_share0, wtmp1

    loopi 10, 2
        bn.rshi wtmp0, w0_share0, wtmp0 >> 16
        bn.rshi w0_share0, bn0, w0_share0 >> 6
    bn.rshi wtmp0, w0_share0, wtmp0 >> 4
    bn.rshi wtmp0, w1_share0, wtmp0 >> 12
    bn.rshi w1_share0, bn0, w1_share0 >> 2
    loopi 5, 2
        bn.rshi wtmp0, w1_share0, wtmp0 >> 16
        bn.rshi w1_share0, bn0, w1_share0 >> 6
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb0_share0, xwb0_share0 << 1
    bn.xor     xwb0_share0, xwb0_share0, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb1_share0, xwb1_share0 << 1
    bn.xor     xwb1_share0, xwb1_share0, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb2_share0, xwb2_share0 << 1
    bn.xor     xwb2_share0, xwb2_share0, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb0_share0, ywb0_share0 << 1
    bn.xor     ywb0_share0, ywb0_share0, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb1_share0, ywb1_share0 << 1
    bn.xor     ywb1_share0, ywb1_share0, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb2_share0, ywb2_share0 << 1
    bn.xor     ywb2_share0, ywb2_share0, wtmp1

    loopi 2, 26
        loopi N_COEFFS, 2
            bn.rshi wtmp0, w1_share0, wtmp0 >> 16
            bn.rshi w1_share0, bn0, w1_share0 >> 6
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb0_share0, xwb0_share0 << 1
        bn.xor     xwb0_share0, xwb0_share0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb1_share0, xwb1_share0 << 1
        bn.xor     xwb1_share0, xwb1_share0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb2_share0, xwb2_share0 << 1
        bn.xor     xwb2_share0, xwb2_share0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb0_share0, ywb0_share0 << 1
        bn.xor     ywb0_share0, ywb0_share0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb1_share0, ywb1_share0 << 1
        bn.xor     ywb1_share0, ywb1_share0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb2_share0, ywb2_share0 << 1
        bn.xor     ywb2_share0, ywb2_share0, wtmp1
    loopi 5, 2
        bn.rshi wtmp0, w1_share0, wtmp0 >> 16
        bn.rshi w1_share0, bn0, w1_share0 >> 6
    bn.rshi wtmp0, w1_share0, wtmp0 >> 2
    bn.rshi wtmp0, w2_share0, wtmp0 >> 14
    bn.rshi w2_share0, bn0, w2_share0 >> 4
    loopi 10, 2
        bn.rshi wtmp0, w2_share0, wtmp0 >> 16
        bn.rshi w2_share0, bn0, w2_share0 >> 6
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb0_share0, xwb0_share0 << 1
    bn.xor     xwb0_share0, xwb0_share0, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb1_share0, xwb1_share0 << 1
    bn.xor     xwb1_share0, xwb1_share0, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb2_share0, xwb2_share0 << 1
    bn.xor     xwb2_share0, xwb2_share0, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb0_share0, ywb0_share0 << 1
    bn.xor     ywb0_share0, ywb0_share0, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb1_share0, ywb1_share0 << 1
    bn.xor     ywb1_share0, ywb1_share0, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb2_share0, ywb2_share0 << 1
    bn.xor     ywb2_share0, ywb2_share0, wtmp1

    loopi 2, 26
        loopi N_COEFFS, 2
            bn.rshi wtmp0, w2_share0, wtmp0 >> 16
            bn.rshi w2_share0, bn0, w2_share0 >> 6
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb0_share0, xwb0_share0 << 1
        bn.xor     xwb0_share0, xwb0_share0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb1_share0, xwb1_share0 << 1
        bn.xor     xwb1_share0, xwb1_share0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb2_share0, xwb2_share0 << 1
        bn.xor     xwb2_share0, xwb2_share0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb0_share0, ywb0_share0 << 1
        bn.xor     ywb0_share0, ywb0_share0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb1_share0, ywb1_share0 << 1
        bn.xor     ywb1_share0, ywb1_share0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb2_share0, ywb2_share0 << 1
        bn.xor     ywb2_share0, ywb2_share0, wtmp1

    /* Handle second share. */
    loopi 2, 26
        loopi N_COEFFS, 2
            bn.rshi wtmp0, w0_share1, wtmp0 >> 16
            bn.rshi w0_share1, bn0, w0_share1 >> 6
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb0_share1, xwb0_share1 << 1
        bn.xor     xwb0_share1, xwb0_share1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb1_share1, xwb1_share1 << 1
        bn.xor     xwb1_share1, xwb1_share1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb2_share1, xwb2_share1 << 1
        bn.xor     xwb2_share1, xwb2_share1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb0_share1, ywb0_share1 << 1
        bn.xor     ywb0_share1, ywb0_share1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb1_share1, ywb1_share1 << 1
        bn.xor     ywb1_share1, ywb1_share1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb2_share1, ywb2_share1 << 1
        bn.xor     ywb2_share1, ywb2_share1, wtmp1
    loopi 10, 2
        bn.rshi wtmp0, w0_share1, wtmp0 >> 16
        bn.rshi w0_share1, bn0, w0_share1 >> 6
    bn.rshi wtmp0, w0_share1, wtmp0 >> 4
    bn.rshi wtmp0, w1_share1, wtmp0 >> 12
    bn.rshi w1_share1, bn0, w1_share1 >> 2
    loopi 5, 2
        bn.rshi wtmp0, w1_share1, wtmp0 >> 16
        bn.rshi w1_share1, bn0, w1_share1 >> 6
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb0_share1, xwb0_share1 << 1
    bn.xor     xwb0_share1, xwb0_share1, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb1_share1, xwb1_share1 << 1
    bn.xor     xwb1_share1, xwb1_share1, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb2_share1, xwb2_share1 << 1
    bn.xor     xwb2_share1, xwb2_share1, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb0_share1, ywb0_share1 << 1
    bn.xor     ywb0_share1, ywb0_share1, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb1_share1, ywb1_share1 << 1
    bn.xor     ywb1_share1, ywb1_share1, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb2_share1, ywb2_share1 << 1
    bn.xor     ywb2_share1, ywb2_share1, wtmp1

    loopi 2, 26
        loopi N_COEFFS, 2
            bn.rshi wtmp0, w1_share1, wtmp0 >> 16
            bn.rshi w1_share1, bn0, w1_share1 >> 6
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb0_share1, xwb0_share1 << 1
        bn.xor     xwb0_share1, xwb0_share1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb1_share1, xwb1_share1 << 1
        bn.xor     xwb1_share1, xwb1_share1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb2_share1, xwb2_share1 << 1
        bn.xor     xwb2_share1, xwb2_share1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb0_share1, ywb0_share1 << 1
        bn.xor     ywb0_share1, ywb0_share1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb1_share1, ywb1_share1 << 1
        bn.xor     ywb1_share1, ywb1_share1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb2_share1, ywb2_share1 << 1
        bn.xor     ywb2_share1, ywb2_share1, wtmp1
    loopi 5, 2
        bn.rshi wtmp0, w1_share1, wtmp0 >> 16
        bn.rshi w1_share1, bn0, w1_share1 >> 6
    bn.rshi wtmp0, w1_share1, wtmp0 >> 2
    bn.rshi wtmp0, w2_share1, wtmp0 >> 14
    bn.rshi w2_share1, bn0, w2_share1 >> 4
    loopi 10, 2
        bn.rshi wtmp0, w2_share1, wtmp0 >> 16
        bn.rshi w2_share1, bn0, w2_share1 >> 6
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb0_share1, xwb0_share1 << 1
    bn.xor     xwb0_share1, xwb0_share1, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb1_share1, xwb1_share1 << 1
    bn.xor     xwb1_share1, xwb1_share1, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb2_share1, xwb2_share1 << 1
    bn.xor     xwb2_share1, xwb2_share1, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb0_share1, ywb0_share1 << 1
    bn.xor     ywb0_share1, ywb0_share1, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb1_share1, ywb1_share1 << 1
    bn.xor     ywb1_share1, ywb1_share1, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb2_share1, ywb2_share1 << 1
    bn.xor     ywb2_share1, ywb2_share1, wtmp1

    loopi 2, 26
        loopi N_COEFFS, 2
            bn.rshi wtmp0, w2_share1, wtmp0 >> 16
            bn.rshi w2_share1, bn0, w2_share1 >> 6
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb0_share1, xwb0_share1 << 1
        bn.xor     xwb0_share1, xwb0_share1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb1_share1, xwb1_share1 << 1
        bn.xor     xwb1_share1, xwb1_share1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb2_share1, xwb2_share1 << 1
        bn.xor     xwb2_share1, xwb2_share1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb0_share1, ywb0_share1 << 1
        bn.xor     ywb0_share1, ywb0_share1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb1_share1, ywb1_share1 << 1
        bn.xor     ywb1_share1, ywb1_share1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb2_share1, ywb2_share1 << 1
        bn.xor     ywb2_share1, ywb2_share1, wtmp1
#else
    loopi 2, 26
        loopi N_COEFFS, 2
            bn.rshi wtmp0, w0, wtmp0 >> 16
            bn.rshi w0, bn0, w0 >> 6
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb0, xwb0 << 1
        bn.xor     xwb0, xwb0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb1, xwb1 << 1
        bn.xor     xwb1, xwb1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb2, xwb2 << 1
        bn.xor     xwb2, xwb2, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb0, ywb0 << 1
        bn.xor     ywb0, ywb0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb1, ywb1 << 1
        bn.xor     ywb1, ywb1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb2, ywb2 << 1
        bn.xor     ywb2, ywb2, wtmp1
    loopi 10, 2
        bn.rshi wtmp0, w0, wtmp0 >> 16
        bn.rshi w0, bn0, w0 >> 6
    bn.rshi wtmp0, w0, wtmp0 >> 4
    bn.rshi wtmp0, w1, wtmp0 >> 12
    bn.rshi w1, bn0, w1 >> 2
    loopi 5, 2
        bn.rshi wtmp0, w1, wtmp0 >> 16
        bn.rshi w1, bn0, w1 >> 6
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb0, xwb0 << 1
    bn.xor     xwb0, xwb0, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb1, xwb1 << 1
    bn.xor     xwb1, xwb1, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb2, xwb2 << 1
    bn.xor     xwb2, xwb2, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb0, ywb0 << 1
    bn.xor     ywb0, ywb0, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb1, ywb1 << 1
    bn.xor     ywb1, ywb1, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb2, ywb2 << 1
    bn.xor     ywb2, ywb2, wtmp1

    loopi 2, 26
        loopi N_COEFFS, 2
            bn.rshi wtmp0, w1, wtmp0 >> 16
            bn.rshi w1, bn0, w1 >> 6
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb0, xwb0 << 1
        bn.xor     xwb0, xwb0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb1, xwb1 << 1
        bn.xor     xwb1, xwb1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb2, xwb2 << 1
        bn.xor     xwb2, xwb2, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb0, ywb0 << 1
        bn.xor     ywb0, ywb0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb1, ywb1 << 1
        bn.xor     ywb1, ywb1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb2, ywb2 << 1
        bn.xor     ywb2, ywb2, wtmp1
    loopi 5, 2
        bn.rshi wtmp0, w1, wtmp0 >> 16
        bn.rshi w1, bn0, w1 >> 6
    bn.rshi wtmp0, w1, wtmp0 >> 2
    bn.rshi wtmp0, w2, wtmp0 >> 14
    bn.rshi w2, bn0, w2 >> 4
    loopi 10, 2
        bn.rshi wtmp0, w2, wtmp0 >> 16
        bn.rshi w2, bn0, w2 >> 6
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb0, xwb0 << 1
    bn.xor     xwb0, xwb0, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb1, xwb1 << 1
    bn.xor     xwb1, xwb1, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h xwb2, xwb2 << 1
    bn.xor     xwb2, xwb2, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb0, ywb0 << 1
    bn.xor     ywb0, ywb0, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb1, ywb1 << 1
    bn.xor     ywb1, ywb1, wtmp1
    bn.shv.16h wtmp0, wtmp0 >> 1
    bn.and     wtmp1, wtmp0, wone
    bn.shv.16h ywb2, ywb2 << 1
    bn.xor     ywb2, ywb2, wtmp1

    loopi 2, 26
        loopi N_COEFFS, 2
            bn.rshi wtmp0, w2, wtmp0 >> 16
            bn.rshi w2, bn0, w2 >> 6
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb0, xwb0 << 1
        bn.xor     xwb0, xwb0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb1, xwb1 << 1
        bn.xor     xwb1, xwb1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h xwb2, xwb2 << 1
        bn.xor     xwb2, xwb2, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb0, ywb0 << 1
        bn.xor     ywb0, ywb0, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb1, ywb1 << 1
        bn.xor     ywb1, ywb1, wtmp1
        bn.shv.16h wtmp0, wtmp0 >> 1
        bn.and     wtmp1, wtmp0, wone
        bn.shv.16h ywb2, ywb2 << 1
        bn.xor     ywb2, ywb2, wtmp1
#endif /* NSHARES == 2*/
    ret

/*
 * Name: masked_poly_getnoise_eta_2
 *
 * Sample a polynomial deterministically from a seed and a nonce, with output
 * polynomial close to centered binomial distribution with parameter KYBER_ETA2;
 * this function assumes `poly_getnoise_eta_init` has been called first with the
 * appropriate seed and nonce.
 *
 * @param[in]  x10: eta
 * @param[out] x11: ptr_ra, dmem_ptr to arithmetic shares of r
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */
.globl masked_poly_getnoise_eta_2
masked_poly_getnoise_eta_2:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw   s0, 4(fp)
    sw   s1, 8(fp)
    sw   s2, 12(fp)
    sw   s3, 16(fp)
    addi s0, a0, 0
    addi s1, x0, NSHARES
    addi s2, a1, 0

    /* Adjust stack for intermediate variables. */
    loop s1, 1
        addi sp, sp, -64
    addi s3, sp, 0 /* ptr_x */
    loop s1, 1
        addi sp, sp, -64 /* ptr_y */

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    /* Create mask of 0x1. */
    bn.subi    wone, bn0, 1
    bn.shv.16h wone, wone >> 15

#if NSHARES == 2
    loopi 4, 41
        /* Handle first share. */
        bn.wsrr w0, kmac_digest
        loopi 4, 18
            loopi N_COEFFS, 2
                bn.rshi w2, w0, w2 >> 16
                bn.rshi w0, bn0, w0 >> 4
            bn.and     wtmp, w2, wone
            bn.shv.16h xwb0_share0_2, xwb0_share0_2 << 1
            bn.xor     xwb0_share0_2, xwb0_share0_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h xwb1_share0_2, xwb1_share0_2 << 1
            bn.xor     xwb1_share0_2, xwb1_share0_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h ywb0_share0_2, ywb0_share0_2 << 1
            bn.xor     ywb0_share0_2, ywb0_share0_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h ywb1_share0_2, ywb1_share0_2 << 1
            bn.xor     ywb1_share0_2, ywb1_share0_2, wtmp
        /* Handle second share. */
        bn.wsrr w0, kmac_digest1
        loopi 4, 18
            loopi N_COEFFS, 2
                bn.rshi w2, w0, w2 >> 16
                bn.rshi w0, bn0, w0 >> 4
            bn.and     wtmp, w2, wone
            bn.shv.16h xwb0_share1_2, xwb0_share1_2 << 1
            bn.xor     xwb0_share1_2, xwb0_share1_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h xwb1_share1_2, xwb1_share1_2 << 1
            bn.xor     xwb1_share1_2, xwb1_share1_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h ywb0_share1_2, ywb0_share1_2 << 1
            bn.xor     ywb0_share1_2, ywb0_share1_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h ywb1_share1_2, ywb1_share1_2 << 1
            bn.xor     ywb1_share1_2, ywb1_share1_2, wtmp
        nop

    addi   t0, s3, 0
    addi   t1, sp, 0
    addi   x4, x0, 3
    bn.sid x4++, 0(t0)
    bn.sid x4++, 32(t0)
    bn.sid x4++, 64(t0)
    bn.sid x4++, 96(t0)
    bn.sid x4++, 0(t1)
    bn.sid x4++, 32(t1)
    bn.sid x4++, 64(t1)
    bn.sid x4++, 96(t1)

#else
    loopi 4, 21
        bn.wsrr w0, kmac_digest
        loopi 4, 18
            loopi N_COEFFS, 2
                bn.rshi w2, w0, w2 >> 16
                bn.rshi w0, bn0, w0 >> 4
            bn.and     wtmp, w2, wone
            bn.shv.16h xwb0_2, xwb0_2 << 1
            bn.xor     xwb0_2, xwb0_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h xwb1_2, xwb1_2 << 1
            bn.xor     xwb1_2, xwb1_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h ywb0_2, ywb0_2 << 1
            bn.xor     ywb0_2, ywb0_2, wtmp
            bn.shv.16h w2, w2 >> 1
            bn.and     wtmp, w2, wone
            bn.shv.16h ywb1_2, ywb1_2 << 1
            bn.xor     ywb1_2, ywb1_2, wtmp
        nop

    addi t0, s1, -1 /* nshares - 1 */
    addi x4, x0, 1
    addi t1, s3, 0 /* ptr_x */
    addi t2, sp, 0 /* ptr_y */
    loop t0, 12
        bn.wsrr w1, urnd
        bn.sid  x4, 0(t1++)
        bn.xor  xwb0_2, xwb0_2, w1
        bn.wsrr w1, urnd
        bn.sid  x4, 0(t1++)
        bn.xor  xwb1_2, xwb1_2, w1
        bn.wsrr w1, urnd
        bn.sid  x4, 0(t2++)
        bn.xor  ywb0_2, ywb0_2, w1
        bn.wsrr w1, urnd
        bn.sid  x4, 0(t2++)
        bn.xor  ywb1_2, ywb1_2, w1
    addi   x4, x0, 3
    bn.sid x4++, 0(t1)
    bn.sid x4++, 32(t1)
    bn.sid x4++, 0(t2)
    bn.sid x4++, 32(t2)

#endif /* NSHARES == 2 */

    /* Compute r = masked_cbd_bc22(x, y, eta, nshares). */
    addi a0, s3, 0 /* ptr_x */
    addi a1, sp, 0 /* ptr_y */
    addi a2, s0, 0 /* eta */
    addi a3, s1, 0 /* nshares */
    addi a4, s2, 0 /* ptr_r */
    jal  x1, masked_cbd_bc22

    /* Restore inputs. */
    addi a0, s0, 0
    addi a1, s1, 0
    /* We want to point r to the next polynomial for next cbd. */
    addi a2, s2, NB_POLY

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)
    lw s3, 16(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
