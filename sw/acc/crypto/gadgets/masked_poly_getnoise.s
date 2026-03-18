/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#define N 256 /* Number of coefficients in a polynomial. */

#ifndef NSHARES
    #define NSHARES 2
#endif

#define NB_POLY 512 /* Number of bytes occupied by a polynomial */
#define N_WDR 16 /* Number of WDRs to store N coeffs */
#define BITSIZE 16 /* Register bit size */
#define BITSIZEm1 15 /* BITSIZE - 1 */
#define N_COEFFS 16 /* Number of coeffs fitting in a WDR */
#define W 4 /* ceil(log2(k - 1)), k = 16 */
#define Wm1 3 /* W - 1 */


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
 * Flags: -
 *
 * @param[in]  x10: eta
 * @param[out] x11: ptr_ra, dmem_ptr to the output arithmetic shares
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

    sw a1, 4(fp)
    sw s0, 8(fp)
    sw s1, 12(fp)
    sw s2, 16(fp)
    sw s3, 20(fp)

    /* Adjust stack for inputs to secsampler{1,2}_spog19. */
    loopi NSHARES, 1
        addi sp, sp, -NB_POLY
    addi t0, sp, 0 /* ptr_xb */
    loopi NSHARES, 1
        addi sp, sp, -NB_POLY
    addi t1, sp, 0 /* ptr_yb */

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    /* Since we don't have the result of KMAC in masked form for now, we will
     * generate the second share here to test secsampler{1,2}_spog19. */
    li   t2, NSHARES
    addi t2, t2, -1 /* t2 = nshares - 1 */
    #define wmask w10
    #define w0_shares0 w0
    #define w0_shares1 w1
    #define w1_shares0 w2
    #define w1_shares1 w3
    #define w2_shares0 w4
    #define w2_shares1 w5
    #define w3_shares0 w6
    #define w3_shares1 w7
    #define wtmp0_idx t3
    #define wtmp1_idx t4
    #define wtmp3_idx t3
    #define wtmp4_idx t4

    addi x4, x0, 3
    bne  a0, x4, _handle_kn2_eta_1
_handle_k2_eta_1:
    /* Create mask 0x7. */
    bn.subi    wmask, bn0, 1
    bn.shv.16h wmask, wmask >> 13

    #if NSHARES == 2
    /* The first three digests are for used immediately later. */
    bn.wsrr w0_shares0, kmac_digest
    bn.wsrr w0_shares1, kmac_digest1
    bn.wsrr w1_shares0, kmac_digest
    bn.wsrr w1_shares1, kmac_digest1
    bn.wsrr w2_shares0, kmac_digest
    bn.wsrr w2_shares1, kmac_digest1
    /* This digest is squeezed out in advance so that KMAC is refreshed.
     * While waiting for this, we generate xb and yb for the secsampler{1,2}_spog19. */
    bn.wsrr w3_shares0, kmac_digest
    bn.wsrr w3_shares1, kmac_digest1
    addi    wtmp0_idx, x0, 8
    addi    wtmp1_idx, x0, 9
    addi    s0, t0, 0
    addi    s1, t1, 0
    jal     x1, _gen_input_k2
    addi    t0, s0, 256
    addi    t1, s1, 256
    bn.mov  w0_shares0, w3_shares0
    bn.mov  w0_shares1, w3_shares1
    bn.wsrr w1_shares0, kmac_digest
    bn.wsrr w1_shares1, kmac_digest1
    bn.wsrr w2_shares0, kmac_digest
    bn.wsrr w2_shares1, kmac_digest1
    jal     x1, _gen_input_k2
    #else
    /* The first three digests are for used immediately later. */
    bn.wsrr w0, kmac_digest
    bn.wsrr w1, kmac_digest
    bn.wsrr w2, kmac_digest
    /* This digest is squeezed out in advance so that KMAC is refreshed.
     * While waiting for this, we generate xb and yb for the secsampler{1,2}_spog19. */
    bn.wsrr w3, kmac_digest
    addi    wtmp3_idx, x0, 8
    addi    wtmp4_idx, x0, 9
    addi    s0, t0, 0
    addi    s1, t1, 0
    jal     x1, _gen_input_k2
    addi    t0, s0, 256
    addi    t1, s1, 256
    bn.mov  w0, w3
    bn.wsrr w1, kmac_digest
    bn.wsrr w2, kmac_digest
    jal     x1, _gen_input_k2
    #endif /* NSHARES == 2*/

    /* Call secsampler{1,2}_spog19. */
    addi a0, s0, 0 /* ptr_xb */
    addi a1, s1, 0 /* ptr_yb */
    addi a2, x0, 3
    addi a3, x0, NSHARES
    lw   a4, 4(fp)
    jal  x1, secsampler1_spog19

    beq x0, x0, _handle_common_eta_1

_handle_kn2_eta_1:
    /* Create mask of 0x3. */
    bn.subi    wmask, bn0, 1
    bn.shv.16h wmask, wmask >> 14

    addi t3, x0, 2
    addi t4, x0, 3
    addi s2, t0, 0
    addi s3, t1, 0

    #if NSHARES == 2
    loopi 4, 26
        addi    s0, t0, 0
        addi    s1, t1, 0
        bn.wsrr w0, kmac_digest
        /*----- Start creating xb and yb for secsampler{1,2}_spog19 -----*/
        loopi 4, 8
            loopi N_COEFFS, 2
                bn.rshi w2, w0, w2 >> 16
                bn.rshi w0, bn0, w0 >> 4
            bn.shv.16h w3, w2 >> 2
            bn.and     w2, w2, wmask
            bn.sid     t3, 0(t0++)
            bn.and     w3, w3, wmask
            bn.sid     t4, 0(t1++)
        addi t0, t0, 384 /* Point to next share: -32 * 4 + NB_POLY. */
        addi t1, t1, 384 /* Point to next share: -32 * 4 + NB_POLY. */
        /*------ End: Creating xb and yb for secsampler{1,2}_spog19 ------*/
        bn.wsrr w0, kmac_digest1
        /*----- Start creating xb and yb for secsampler{1,2}_spog19 -----*/
        loopi 4, 8
            loopi N_COEFFS, 2
                bn.rshi w2, w0, w2 >> 16
                bn.rshi w0, bn0, w0 >> 4
            bn.shv.16h w3, w2 >> 2
            bn.and     w2, w2, wmask
            bn.sid     t3, 0(t0++)
            bn.and     w3, w3, wmask
            bn.sid     t4, 0(t1++)
        addi t0, s0, 128 /* Point to next batch of coeffs: 32 * 4. */
        addi t1, s1, 128 /* Point to next batch of coeffs: 32 * 4. */
        /*------ End: Creating xb and yb for secsampler{1,2}_spog19 ------*/
    #else
    loopi 4, 28
        addi    s0, t0, 0
        addi    s1, t1, 0
        bn.wsrr w0, kmac_digest
        /* Loop over i = 1,...,nshares - 1. */
        loop t2, 13
            bn.wsrr w1, urnd
            bn.xor  w0, w0, w1 /* Xoring to create the last share. */
            /*----- Start creating xb and yb for secsampler{1,2}_spog19 -----*/
            loopi 4, 8
                loopi N_COEFFS, 2
                    bn.rshi w2, w1, w2 >> 16
                    bn.rshi w1, bn0, w1 >> 4
                bn.shv.16h w3, w2 >> 2
                bn.and     w2, w2, wmask
                bn.sid     t3, 0(t0++)
                bn.and     w3, w3, wmask
                bn.sid     t4, 0(t1++)
            addi t0, t0, 384 /* Point to next share: -32 * 4 + NB_POLY. */
            addi t1, t1, 384 /* Point to next share: -32 * 4 + NB_POLY. */
            /*------ End: Creating xb and yb for secsampler{1,2}_spog19 ------*/
        /*----- Start creating xb and yb for secsampler{1,2}_spog19 -----*/
        loopi 4, 8
            loopi N_COEFFS, 2
                bn.rshi w2, w0, w2 >> 16
                bn.rshi w0, bn0, w0 >> 4
            bn.shv.16h w3, w2 >> 2
            bn.and     w2, w2, wmask
            bn.sid     t3, 0(t0++)
            bn.and     w3, w3, wmask
            bn.sid     t4, 0(t1++)
        addi t0, s0, 128 /* Point to next batch of coeffs: 32 * 4. */
        addi t1, s1, 128 /* Point to next batch of coeffs: 32 * 4. */
        /*------ End: Creating xb and yb for secsampler{1,2}_spog19 ------*/
    #endif /* NSHARES == 2*/

    /* Call secsampler{1,2}_spog19. */
    addi a0, s2, 0 /* ptr_xb */
    addi a1, s3, 0 /* ptr_yb */
    addi a2, x0, 2
    addi a3, x0, NSHARES
    lw   a4, 4(fp)
    jal  x1, secsampler1_spog19

_handle_common_eta_1:

    /* Restore registers. */
    lw s0, 8(fp)
    lw s1, 12(fp)
    lw s2, 16(fp)
    lw s3, 20(fp)

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
 * Flags: -
 *
 * @param[in]  x13: nshares, number of shares
 * @param[out] x14: ptr_ra, dmem_ptr to the output arithmetic shares
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */
_gen_input_k2:
#if NSHARES == 2
    #define wtmp0 w8
    #define wtmp1 w9
    /*----- Start creating xb and yb for secsampler{1,2}_spog19 -----*/
    loopi 2, 8
        loopi N_COEFFS, 2
            bn.rshi wtmp0, w0_shares0, wtmp0 >> 16
            bn.rshi w0_shares0, bn0, w0_shares0 >> 6
        bn.shv.16h wtmp1, wtmp0 >> 3
        bn.and     wtmp0, wtmp0, wmask
        bn.sid     wtmp0_idx, 0(t0++)
        bn.and     wtmp1, wtmp1, wmask
        bn.sid     wtmp1_idx, 0(t1++)
    loopi 10, 2
        bn.rshi wtmp0, w0_shares0, wtmp0 >> 16
        bn.rshi w0_shares0, bn0, w0_shares0 >> 6
    bn.rshi wtmp0, w0_shares0, wtmp0 >> 4
    bn.rshi wtmp0, w1_shares0, wtmp0 >> 12
    bn.rshi w1_shares0, bn0, w1_shares0 >> 2
    loopi 5, 2
        bn.rshi wtmp0, w1_shares0, wtmp0 >> 16
        bn.rshi w1_shares0, bn0, w1_shares0 >> 6
    bn.shv.16h wtmp1, wtmp0 >> 3
    bn.and     wtmp0, wtmp0, wmask
    bn.sid     wtmp0_idx, 0(t0++)
    bn.and     wtmp1, wtmp1, wmask
    bn.sid     wtmp1_idx, 0(t1++)

    loopi 2, 8
        loopi N_COEFFS, 2
            bn.rshi wtmp0, w1_shares0, wtmp0 >> 16
            bn.rshi w1_shares0, bn0, w1_shares0 >> 6
        bn.shv.16h wtmp1, wtmp0 >> 3
        bn.and     wtmp0, wtmp0, wmask
        bn.sid     wtmp0_idx, 0(t0++)
        bn.and     wtmp1, wtmp1, wmask
        bn.sid     wtmp1_idx, 0(t1++)
    loopi 5, 2
        bn.rshi wtmp0, w1_shares0, wtmp0 >> 16
        bn.rshi w1_shares0, bn0, w1_shares0 >> 6
    bn.rshi wtmp0, w1_shares0, wtmp0 >> 2
    bn.rshi wtmp0, w2_shares0, wtmp0 >> 14
    bn.rshi w2_shares0, bn0, w2_shares0 >> 4
    loopi 10, 2
        bn.rshi wtmp0, w2_shares0, wtmp0 >> 16
        bn.rshi w2_shares0, bn0, w2_shares0 >> 6
    bn.shv.16h wtmp1, wtmp0 >> 3
    bn.and     wtmp0, wtmp0, wmask
    bn.sid     wtmp0_idx, 0(t0++)
    bn.and     wtmp1, wtmp1, wmask
    bn.sid     wtmp1_idx, 0(t1++)

    loopi 2, 8
        loopi N_COEFFS, 2
            bn.rshi wtmp0, w2_shares0, wtmp0 >> 16
            bn.rshi w2_shares0, bn0, w2_shares0 >> 6
        bn.shv.16h wtmp1, wtmp0 >> 3
        bn.and     wtmp0, wtmp0, wmask
        bn.sid     wtmp0_idx, 0(t0++)
        bn.and     wtmp1, wtmp1, wmask
        bn.sid     wtmp1_idx, 0(t1++)

    addi t0, t0, 256 /* Point to next share: -32 * 8 + NB_POLY. */
    addi t1, t1, 256 /* Point to next share: -32 * 8 + NB_POLY. */
    /*------ End: Creating xb and yb for secsampler{1,2}_spog19 ------*/
    /*----- Start creating xb and yb for secsampler{1,2}_spog19 -----*/
    loopi 2, 8
        loopi N_COEFFS, 2
            bn.rshi wtmp0, w0_shares1, wtmp0 >> 16
            bn.rshi w0_shares1, bn0, w0_shares1 >> 6
        bn.shv.16h wtmp1, wtmp0 >> 3
        bn.and     wtmp0, wtmp0, wmask
        bn.sid     wtmp0_idx, 0(t0++)
        bn.and     wtmp1, wtmp1, wmask
        bn.sid     wtmp1_idx, 0(t1++)
    loopi 10, 2
        bn.rshi wtmp0, w0_shares1, wtmp0 >> 16
        bn.rshi w0_shares1, bn0, w0_shares1 >> 6
    bn.rshi wtmp0, w0_shares1, wtmp0 >> 4
    bn.rshi wtmp0, w1_shares1, wtmp0 >> 12
    bn.rshi w1_shares1, bn0, w1_shares1 >> 2
    loopi 5, 2
        bn.rshi wtmp0, w1_shares1, wtmp0 >> 16
        bn.rshi w1_shares1, bn0, w1_shares1 >> 6
    bn.shv.16h wtmp1, wtmp0 >> 3
    bn.and     wtmp0, wtmp0, wmask
    bn.sid     wtmp0_idx, 0(t0++)
    bn.and     wtmp1, wtmp1, wmask
    bn.sid     wtmp1_idx, 0(t1++)

    loopi 2, 8
        loopi N_COEFFS, 2
            bn.rshi wtmp0, w1_shares1, wtmp0 >> 16
            bn.rshi w1_shares1, bn0, w1_shares1 >> 6
        bn.shv.16h wtmp1, wtmp0 >> 3
        bn.and     wtmp0, wtmp0, wmask
        bn.sid     wtmp0_idx, 0(t0++)
        bn.and     wtmp1, wtmp1, wmask
        bn.sid     wtmp1_idx, 0(t1++)
    loopi 5, 2
        bn.rshi wtmp0, w1_shares1, wtmp0 >> 16
        bn.rshi w1_shares1, bn0, w1_shares1 >> 6
    bn.rshi wtmp0, w1_shares1, wtmp0 >> 2
    bn.rshi wtmp0, w2_shares1, wtmp0 >> 14
    bn.rshi w2_shares1, bn0, w2_shares1 >> 4
    loopi 10, 2
        bn.rshi wtmp0, w2_shares1, wtmp0 >> 16
        bn.rshi w2_shares1, bn0, w2_shares1 >> 6
    bn.shv.16h wtmp1, wtmp0 >> 3
    bn.and     wtmp0, wtmp0, wmask
    bn.sid     wtmp0_idx, 0(t0++)
    bn.and     wtmp1, wtmp1, wmask
    bn.sid     wtmp1_idx, 0(t1++)

    loopi 2, 8
        loopi N_COEFFS, 2
            bn.rshi wtmp0, w2_shares1, wtmp0 >> 16
            bn.rshi w2_shares1, bn0, w2_shares1 >> 6
        bn.shv.16h wtmp1, wtmp0 >> 3
        bn.and     wtmp0, wtmp0, wmask
        bn.sid     wtmp0_idx, 0(t0++)
        bn.and     wtmp1, wtmp1, wmask
        bn.sid     wtmp1_idx, 0(t1++)
    /*------ End: Creating xb and yb for secsampler{1,2}_spog19 ------*/
#else
    #define wtmp0 w5
    #define wtmp1 w6
    #define wtmp2 w7
    #define wtmp3 w8
    #define wtmp4 w9
    /* Loop over i = 1,...,nshares - 1. */
    loop t2, 63
        /*----- Start creating xb and yb for secsampler{1,2}_spog19 -----*/
        bn.wsrr wtmp0, urnd
        bn.xor  w0, w0, wtmp0
        bn.wsrr wtmp1, urnd
        bn.xor  w1, w1, wtmp1
        bn.wsrr wtmp2, urnd
        bn.xor  w2, w2, wtmp2

        loopi 2, 8
            loopi N_COEFFS, 2
                bn.rshi wtmp3, wtmp0, wtmp3 >> 16
                bn.rshi wtmp0, bn0, wtmp0 >> 6
            bn.shv.16h wtmp4, wtmp3 >> 3
            bn.and     wtmp3, wtmp3, wmask
            bn.sid     wtmp3_idx, 0(t0++)
            bn.and     wtmp4, wtmp4, wmask
            bn.sid     wtmp4_idx, 0(t1++)
        loopi 10, 2
            bn.rshi wtmp3, wtmp0, wtmp3 >> 16
            bn.rshi wtmp0, bn0, wtmp0 >> 6
        bn.rshi wtmp3, wtmp0, wtmp3 >> 4
        bn.rshi wtmp3, wtmp1, wtmp3 >> 12
        bn.rshi wtmp1, bn0, wtmp1 >> 2
        loopi 5, 2
            bn.rshi wtmp3, wtmp1, wtmp3 >> 16
            bn.rshi wtmp1, bn0, wtmp1 >> 6
        bn.shv.16h wtmp4, wtmp3 >> 3
        bn.and     wtmp3, wtmp3, wmask
        bn.sid     wtmp3_idx, 0(t0++)
        bn.and     wtmp4, wtmp4, wmask
        bn.sid     wtmp4_idx, 0(t1++)

        loopi 2, 8
            loopi N_COEFFS, 2
                bn.rshi wtmp3, wtmp1, wtmp3 >> 16
                bn.rshi wtmp1, bn0, wtmp1 >> 6
            bn.shv.16h wtmp4, wtmp3 >> 3
            bn.and     wtmp3, wtmp3, wmask
            bn.sid     wtmp3_idx, 0(t0++)
            bn.and     wtmp4, wtmp4, wmask
            bn.sid     wtmp4_idx, 0(t1++)
        loopi 5, 2
            bn.rshi wtmp3, wtmp1, wtmp3 >> 16
            bn.rshi wtmp1, bn0, wtmp1 >> 6
        bn.rshi wtmp3, wtmp1, wtmp3 >> 2
        bn.rshi wtmp3, wtmp2, wtmp3 >> 14
        bn.rshi wtmp2, bn0, wtmp2 >> 4
        loopi 10, 2
            bn.rshi wtmp3, wtmp2, wtmp3 >> 16
            bn.rshi wtmp2, bn0, wtmp2 >> 6
        bn.shv.16h wtmp4, wtmp3 >> 3
        bn.and     wtmp3, wtmp3, wmask
        bn.sid     wtmp3_idx, 0(t0++)
        bn.and     wtmp4, wtmp4, wmask
        bn.sid     wtmp4_idx, 0(t1++)

        loopi 2, 8
            loopi N_COEFFS, 2
                bn.rshi wtmp3, wtmp2, wtmp3 >> 16
                bn.rshi wtmp2, bn0, wtmp2 >> 6
            bn.shv.16h wtmp4, wtmp3 >> 3
            bn.and     wtmp3, wtmp3, wmask
            bn.sid     wtmp3_idx, 0(t0++)
            bn.and     wtmp4, wtmp4, wmask
            bn.sid     wtmp4_idx, 0(t1++)

        addi t0, t0, 256 /* Point to next share: -32 * 8 + NB_POLY. */
        addi t1, t1, 256 /* Point to next share: -32 * 8 + NB_POLY. */
        /*------ End: Creating xb and yb for secsampler{1,2}_spog19 ------*/
    /*----- Start creating xb and yb for secsampler{1,2}_spog19 -----*/
    loopi 2, 8
        loopi N_COEFFS, 2
            bn.rshi wtmp3, w0, wtmp3 >> 16
            bn.rshi w0, bn0, w0 >> 6
        bn.shv.16h wtmp4, wtmp3 >> 3
        bn.and     wtmp3, wtmp3, wmask
        bn.sid     wtmp3_idx, 0(t0++)
        bn.and     wtmp4, wtmp4, wmask
        bn.sid     wtmp4_idx, 0(t1++)
    loopi 10, 2
        bn.rshi wtmp3, w0, wtmp3 >> 16
        bn.rshi w0, bn0, w0 >> 6
    bn.rshi wtmp3, w0, wtmp3 >> 4
    bn.rshi wtmp3, w1, wtmp3 >> 12
    bn.rshi w1, bn0, w1 >> 2
    loopi 5, 2
        bn.rshi wtmp3, w1, wtmp3 >> 16
        bn.rshi w1, bn0, w1 >> 6
    bn.shv.16h wtmp4, wtmp3 >> 3
    bn.and     wtmp3, wtmp3, wmask
    bn.sid     wtmp3_idx, 0(t0++)
    bn.and     wtmp4, wtmp4, wmask
    bn.sid     wtmp4_idx, 0(t1++)

    loopi 2, 8
        loopi N_COEFFS, 2
            bn.rshi wtmp3, w1, wtmp3 >> 16
            bn.rshi w1, bn0, w1 >> 6
        bn.shv.16h wtmp4, wtmp3 >> 3
        bn.and     wtmp3, wtmp3, wmask
        bn.sid     wtmp3_idx, 0(t0++)
        bn.and     wtmp4, wtmp4, wmask
        bn.sid     wtmp4_idx, 0(t1++)
    loopi 5, 2
        bn.rshi wtmp3, w1, wtmp3 >> 16
        bn.rshi w1, bn0, w1 >> 6
    bn.rshi wtmp3, w1, wtmp3 >> 2
    bn.rshi wtmp3, w2, wtmp3 >> 14
    bn.rshi w2, bn0, w2 >> 4
    loopi 10, 2
        bn.rshi wtmp3, w2, wtmp3 >> 16
        bn.rshi w2, bn0, w2 >> 6
    bn.shv.16h wtmp4, wtmp3 >> 3
    bn.and     wtmp3, wtmp3, wmask
    bn.sid     wtmp3_idx, 0(t0++)
    bn.and     wtmp4, wtmp4, wmask
    bn.sid     wtmp4_idx, 0(t1++)

    loopi 2, 8
        loopi N_COEFFS, 2
            bn.rshi wtmp3, w2, wtmp3 >> 16
            bn.rshi w2, bn0, w2 >> 6
        bn.shv.16h wtmp4, wtmp3 >> 3
        bn.and     wtmp3, wtmp3, wmask
        bn.sid     wtmp3_idx, 0(t0++)
        bn.and     wtmp4, wtmp4, wmask
        bn.sid     wtmp4_idx, 0(t1++)
    /*------ End: Creating xb and yb for secsampler{1,2}_spog19 ------*/
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
 * Flags: -
 *
 * @param[out] x11: ptr_ra, dmem_ptr to the output arithmetic shares
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

    sw a1, 4(fp)
    sw s0, 8(fp)
    sw s1, 12(fp)
    sw s2, 16(fp)
    sw s3, 20(fp)

    /* Adjust stack for inputs to secsampler{1,2}_spog19. */
    loopi NSHARES, 1
        addi sp, sp, -NB_POLY
    addi t0, sp, 0 /* ptr_xb */
    loopi NSHARES, 1
        addi sp, sp, -NB_POLY
    addi t1, sp, 0 /* ptr_yb */

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    /* Since we don't have the result of KMAC in masked form for now, we will
     * generate the second share here to test secsampler{1,2}_spog19. */
    li   t2, NSHARES
    addi t2, t2, -1 /* t2 = nshares - 1 */

    #define wmask w10
    /* Create mask of 0x3. */
    bn.subi    wmask, bn0, 1
    bn.shv.16h wmask, wmask >> 14

    addi t3, x0, 2
    addi t4, x0, 3
    addi s2, t0, 0
    addi s3, t1, 0

    #if NSHARES == 2
    loopi 4, 26
        addi    s0, t0, 0
        addi    s1, t1, 0
        bn.wsrr w0, kmac_digest
        /*----- Start creating xb and yb for secsampler{1,2}_spog19 -----*/
        loopi 4, 8
            loopi N_COEFFS, 2
                bn.rshi w2, w0, w2 >> 16
                bn.rshi w0, bn0, w0 >> 4
            bn.shv.16h w3, w2 >> 2
            bn.and     w2, w2, wmask
            bn.sid     t3, 0(t0++)
            bn.and     w3, w3, wmask
            bn.sid     t4, 0(t1++)
        addi t0, t0, 384 /* Point to next share: -32 * 4 + NB_POLY. */
        addi t1, t1, 384 /* Point to next share: -32 * 4 + NB_POLY. */
        /*------ End: Creating xb and yb for secsampler{1,2}_spog19 ------*/
        bn.wsrr w0, kmac_digest1
        /*----- Start creating xb and yb for secsampler{1,2}_spog19 -----*/
        loopi 4, 8
            loopi N_COEFFS, 2
                bn.rshi w2, w0, w2 >> 16
                bn.rshi w0, bn0, w0 >> 4
            bn.shv.16h w3, w2 >> 2
            bn.and     w2, w2, wmask
            bn.sid     t3, 0(t0++)
            bn.and     w3, w3, wmask
            bn.sid     t4, 0(t1++)
        addi t0, s0, 128 /* Point to next batch of coeffs: 32 * 4. */
        addi t1, s1, 128 /* Point to next batch of coeffs: 32 * 4. */
        /*------ End: Creating xb and yb for secsampler{1,2}_spog19 ------*/
    #else
    loopi 4, 28
        bn.wsrr w0, kmac_digest
        addi    s0, t0, 0
        addi    s1, t1, 0
        /* Loop over i = 1,...,nshares - 1. */
        loop t2, 13
            bn.wsrr w1, urnd
            bn.xor  w0, w0, w1 /* Xoring to create the last share. */
            /*----- Start creating xb and yb for secsampler{1,2}_spog19 -----*/
            loopi 4, 8
                loopi N_COEFFS, 2
                    bn.rshi w2, w1, w2 >> 16
                    bn.rshi w1, bn0, w1 >> 4
                bn.shv.16h w3, w2 >> 2
                bn.and     w2, w2, wmask
                bn.sid     t3, 0(t0++)
                bn.and     w3, w3, wmask
                bn.sid     t4, 0(t1++)
            addi t0, t0, 384 /* Point to next share: -32 * 4 + NB_POLY. */
            addi t1, t1, 384 /* Point to next share: -32 * 4 + NB_POLY. */
            /*------ End: Creating xb and yb for secsampler{1,2}_spog19 ------*/
        /*----- Start creating xb and yb for secsampler{1,2}_spog19 -----*/
        loopi 4, 8
            loopi N_COEFFS, 2
                bn.rshi w2, w0, w2 >> 16
                bn.rshi w0, bn0, w0 >> 4
            bn.shv.16h w3, w2 >> 2
            bn.and     w2, w2, wmask
            bn.sid     t3, 0(t0++)
            bn.and     w3, w3, wmask
            bn.sid     t4, 0(t1++)
        addi t0, s0, 128 /* Point to next batch of coeffs: 32 * 4. */
        addi t1, s1, 128 /* Point to next batch of coeffs: 32 * 4. */
        /*------ End: Creating xb and yb for secsampler{1,2}_spog19 ------*/
    #endif /* NSHARES == 2*/

    /* Call secsampler{1,2}_spog19. */
    addi a0, s2, 0 /* ptr_xb */
    addi a1, s3, 0 /* ptr_yb */
    addi a2, x0, 2
    addi a3, x0, NSHARES
    lw   a4, 4(fp)
    jal  x1, secsampler1_spog19

    /* Restore registers. */
    lw s0, 8(fp)
    lw s1, 12(fp)
    lw s2, 16(fp)
    lw s3, 20(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
