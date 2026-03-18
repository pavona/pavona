/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#define N_COEFFS 16

/* Register aliases */
.equ x2, sp
.equ x3, fp
.equ x5, t0
.equ x6, t1
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

/*
 * Name: poly_masked_compare_bc22
 *
 * Return 1 if (Compressq(cprime, dv)) == c. Else, return 0.
 * Bitsliced.
 *
 * Source: Described in Section 6.2 [BC22]
 *         [BC22]: "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and Profit: with Application to Lattice-Based KEMs"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/9831
 *
 * @param[in]  x10: dptr_x, dmem pointer to arithmetic shares of cprime
 * @param[in]  x11: dptr_y, dmem pointer to the reference compressed polynomial c
 * @param[in]  x12: share stride, distance between shares
 * @param[in]  x13: nshares, the number of shares
 * @param[out] x14: dptr_r, dmem pointer to the output Boolean shares of r
 * @param[out] x15: k, the security level
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */
.globl poly_masked_compare_bc22
poly_masked_compare_bc22:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw s0, 4(fp)
    sw s1, 8(fp)
    sw s2, 12(fp)
    sw s3, 16(fp)
    sw s4, 20(fp)
    sw a5, 24(fp)

    /* Save input/output addresses. */
    addi s0, a0, 0
    addi s1, a1, 0
    addi s2, a2, 0
    addi s3, a3, 0
    addi s4, a4, 0

    /* Adjust stack for temporary variable t. */
    loop a3, 1
        sub sp, sp, a2

    #define wone w1
    #define wc w2
    #define wb1 w3
    #define wb2 w4
    #define wb3 w5
    #define wb4 w6
    #define wb5 w7
    #define wtmp w14
    #define wmask w15

    /* Compute t = poly_hocompress_cgmz21b(cprime, nshares). */
    addi a0, s0, 0 /* ptr_cprime */
    addi a1, s3, 0 /* nshares */
    addi a2, sp, 0 /* ptr_t */
    addi a3, a5, 0 /* k */
    jal  x1, poly_hocompress_cgmz21b

    /* Decode + bitslice c. */
    addi a1, s1, 0 /* ptr_c */
    /* Create mask (0x0001)^16. */
    bn.xor     bn0, bn0, bn0
    bn.subi    wone, bn0, 1
    bn.shv.16h wone, wone >> 15

    addi x4, x0, 4
    lw   a5, 24(fp)
    bne  a5, x4, _handle_kn4_dv

_handle_k4_dv:
    /* 1st+2nd+3rd WDRs: 3*80 bits */
	bn.lid x0, 0(a1++)
	loopi 3, 23
		loopi 16, 2
			bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 5
		/* Bitslicing. */
        bn.shv.16h wb1, wb1 << 1
        bn.shv.16h wb2, wb2 << 1
        bn.shv.16h wb3, wb3 << 1
        bn.shv.16h wb4, wb4 << 1
        bn.shv.16h wb5, wb5 << 1
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb1, wb1, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb2, wb2, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb3, wb3, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb4, wb4, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb5, wb5, wtmp

	/* 4th WDR: 15 bits + 1 bit + (Reload) 4 bits + 60 bits*/
	loopi 3, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 5
	bn.rshi wc, w0, wc >> 1
	bn.lid  x0, 0(a1++)
	bn.rshi wc, w0, wc >> 15
	bn.rshi w0, bn0, w0 >> 4
	loopi 12, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 5
	/* Bitslicing. */
    bn.shv.16h wb1, wb1 << 1
    bn.shv.16h wb2, wb2 << 1
    bn.shv.16h wb3, wb3 << 1
    bn.shv.16h wb4, wb4 << 1
    bn.shv.16h wb5, wb5 << 1
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb1, wb1, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb2, wb2, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb3, wb3, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb4, wb4, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb5, wb5, wtmp

	/* 5th+6th WDR: 2*80 bits */
	loopi 2, 23
		loopi 16, 2
			bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 5
		/* Bitslicing. */
        bn.shv.16h wb1, wb1 << 1
        bn.shv.16h wb2, wb2 << 1
        bn.shv.16h wb3, wb3 << 1
        bn.shv.16h wb4, wb4 << 1
        bn.shv.16h wb5, wb5 << 1
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb1, wb1, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb2, wb2, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb3, wb3, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb4, wb4, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb5, wb5, wtmp

	/* 7th WDR: 30 bits + 2 bits + (Reload) 3 bits + 45 bits */
	loopi 6, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 5
	bn.rshi wc, w0, wc >> 2
	bn.lid  x0, 0(a1++)
	bn.rshi wc, w0, wc >> 14
	bn.rshi w0, bn0, w0 >> 3
	loopi 9, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 5
	/* Bitslicing. */
    bn.shv.16h wb1, wb1 << 1
    bn.shv.16h wb2, wb2 << 1
    bn.shv.16h wb3, wb3 << 1
    bn.shv.16h wb4, wb4 << 1
    bn.shv.16h wb5, wb5 << 1
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb1, wb1, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb2, wb2, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb3, wb3, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb4, wb4, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb5, wb5, wtmp

	/* 8th+9th WDR: 2*80 bits */
	loopi 2, 23
		loopi 16, 2
			bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 5
		/* Bitslicing. */
        bn.shv.16h wb1, wb1 << 1
        bn.shv.16h wb2, wb2 << 1
        bn.shv.16h wb3, wb3 << 1
        bn.shv.16h wb4, wb4 << 1
        bn.shv.16h wb5, wb5 << 1
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb1, wb1, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb2, wb2, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb3, wb3, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb4, wb4, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb5, wb5, wtmp

	/* 10th WDR: 45 bits + 3 bits + (Reload) 2 bits + 30 bits */
	loopi 9, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 5
	bn.rshi wc, w0, wc >> 3
	bn.lid  x0, 0(a1++)
	bn.rshi wc, w0, wc >> 13
	bn.rshi w0, bn0, w0 >> 2
	loopi 6, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 5
	/* Bitslicing. */
    bn.shv.16h wb1, wb1 << 1
    bn.shv.16h wb2, wb2 << 1
    bn.shv.16h wb3, wb3 << 1
    bn.shv.16h wb4, wb4 << 1
    bn.shv.16h wb5, wb5 << 1
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb1, wb1, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb2, wb2, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb3, wb3, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb4, wb4, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb5, wb5, wtmp

	/* 11th+12th WDR: 2*80 bits */
	loopi 2, 23
		loopi 16, 2
            bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 5
		/* Bitslicing. */
        bn.shv.16h wb1, wb1 << 1
        bn.shv.16h wb2, wb2 << 1
        bn.shv.16h wb3, wb3 << 1
        bn.shv.16h wb4, wb4 << 1
        bn.shv.16h wb5, wb5 << 1
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb1, wb1, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb2, wb2, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb3, wb3, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb4, wb4, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb5, wb5, wtmp

	/* 13th WDR: 60 bits + 4 bits + (Reload) 1 bit + 15 bits */
	loopi 12, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 5
	bn.rshi wc, w0, wc >> 4
	bn.lid  x0, 0(a1++)
	bn.rshi wc, w0, wc >> 12
	bn.rshi w0, bn0, w0 >> 1
	loopi 3, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 5
	/* Bitslicing. */
    bn.shv.16h wb1, wb1 << 1
    bn.shv.16h wb2, wb2 << 1
    bn.shv.16h wb3, wb3 << 1
    bn.shv.16h wb4, wb4 << 1
    bn.shv.16h wb5, wb5 << 1
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb1, wb1, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb2, wb2, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb3, wb3, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb4, wb4, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb5, wb5, wtmp

  	/* 14th+15th+16th WDRs: 3*80 bits */
	loopi 3, 23
		loopi 16, 2
			bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 5
		/* Bitslicing. */
        bn.shv.16h wb1, wb1 << 1
        bn.shv.16h wb2, wb2 << 1
        bn.shv.16h wb3, wb3 << 1
        bn.shv.16h wb4, wb4 << 1
        bn.shv.16h wb5, wb5 << 1
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb1, wb1, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb2, wb2, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb3, wb3, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb4, wb4, wtmp
        bn.and     wtmp, wc, wone
        bn.shv.16h wc, wc >> 1
        bn.xor     wb5, wb5, wtmp

    /* Load mask ((1 << N) - 1). */
    bn.subi wmask, bn0, 1

    /* Compute t[0] ^= c ^ ((1 << N) - 1). */
    bn.xor wb1, wb1, wmask
    bn.xor wb2, wb2, wmask
    bn.xor wb3, wb3, wmask
    bn.xor wb4, wb4, wmask
    bn.xor wb5, wb5, wmask

    addi   x4, x0, 14
    addi   t0, sp, 0 /* ptr_t */
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb1
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb2
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb3
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb4
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb5
    bn.sid x4, 0(t0++)

    addi s1, x0, 5
    beq  x0, x0, _handle_common_dv

_handle_kn4_dv:
    loopi 4, 22
        bn.lid x0, 0(a1++)
        loopi 4, 19
            loopi N_COEFFS, 2
                bn.rshi wc, w0, wc >> 16
                bn.rshi w0, bn0, w0 >> 4
            /* Bitslicing. */
            bn.shv.16h wb1, wb1 << 1
            bn.shv.16h wb2, wb2 << 1
            bn.shv.16h wb3, wb3 << 1
            bn.shv.16h wb4, wb4 << 1
            bn.and     wtmp, wc, wone
            bn.shv.16h wc, wc >> 1
            bn.xor     wb1, wb1, wtmp
            bn.and     wtmp, wc, wone
            bn.shv.16h wc, wc >> 1
            bn.xor     wb2, wb2, wtmp
            bn.and     wtmp, wc, wone
            bn.shv.16h wc, wc >> 1
            bn.xor     wb3, wb3, wtmp
            bn.and     wtmp, wc, wone
            bn.shv.16h wc, wc >> 1
            bn.xor     wb4, wb4, wtmp
        nop

    /* Load mask ((1 << N) - 1). */
    bn.subi wmask, bn0, 1

    /* Compute t[0] ^= c ^ ((1 << N) - 1). */
    bn.xor wb1, wb1, wmask
    bn.xor wb2, wb2, wmask
    bn.xor wb3, wb3, wmask
    bn.xor wb4, wb4, wmask

    addi   x4, x0, 14
    addi   t0, sp, 0 /* ptr_t */
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb1
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb2
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb3
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb4
    bn.sid x4, 0(t0++)

    addi s1, x0, 4

_handle_common_dv:

    /* Compute r = secand_cs20(r, t). */
    addi a1, x0, 32
    addi a2, sp, 0 /* ptr_t */
    addi a3, s2, 0 /* share_str */
    addi a4, s3, 0 /* nshares */
    addi a6, x0, 32 /* output share_str */
    /* After the secand_cs20, the input and output pointers will point to
     * next bit so we don't have to pass all the arguments above to secand again. */
    loop s1, 4
        addi a0, s4, 0 /* ptr_r */
        addi a5, s4, 0 /* ptr_r */
        jal  x1, secand_cs20
        nop

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)
    lw s3, 16(fp)
    lw s4, 20(fp)
    lw a5, 24(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret


/*
 * Name: poly_polyvec_masked_compare_bc22
 *
 * Return 1 if (Compressq(cprime, du)) == c. Else, return 0.
 * Bitsliced.
 *
 * Source: Described in Section 6.2 [BC22]
 *         [BC22]: "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and Profit: with Application to Lattice-Based KEMs"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/9831
 *
 * @param[in]  x10: dptr_x, dmem pointer to arithmetic shares of cprime
 * @param[in]  x11: dptr_y, dmem pointer to the reference compressed polynomial c
 * @param[in]  x12: share stride, distance between shares
 * @param[in]  x13: nshares, the number of shares
 * @param[out] x14: dptr_r, dmem pointer to the output Boolean shares of r
 * @param[out] x15: k, the security level
 *
 * clobbered registers: TODO
 * clobbered flag groups: TODO
 */
.globl poly_polyvec_masked_compare_bc22
poly_polyvec_masked_compare_bc22:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw s0, 4(fp)
    sw s1, 8(fp)
    sw s2, 12(fp)
    sw s3, 16(fp)
    sw s4, 20(fp)
    sw a5, 24(fp)

    /* Save input/output addresses. */
    addi s0, a0, 0
    addi s1, a1, 0
    addi s2, a2, 0
    addi s3, a3, 0
    addi s4, a4, 0

    /* Adjust stack for temporary variable t. */
    loop a3, 1
        sub sp, sp, a2

    /* Compute t = poly_hocompress_cgmz21b(cprime, nshares). */
    addi a0, s0, 0 /* ptr_cprime */
    addi a1, s3, 0 /* nshares */
    addi a2, sp, 0 /* ptr_t */
    addi a3, a5, 0 /* k */
    jal  x1, poly_polyvec_hocompress_cgmz21b

    #define wone w1
    #define wc w2
    #define wb1 w3
    #define wb2 w4
    #define wb3 w5
    #define wb4 w6
    #define wb5 w7
    #define wb6 w8
    #define wb7 w9
    #define wb8 w10
    #define wb9 w11
    #define wb11 w13
    #define wb10 w12
    #define wtmp w14
    #define wmask w15

    /* Decode + bitslice c. */
    addi a1, s1, 0 /* ptr_c */
    /* Create mask (0x0001)^16. */
    bn.xor     bn0, bn0, bn0
    bn.subi    wone, bn0, 1
    bn.shv.16h wone, wone >> 15

    addi x4, x0, 4
    lw   a5, 24(fp)
    bne  a5, x4, _handle_kn4_du

_handle_k4_du:
    /* First WDR: 176 bits */
	bn.lid x0, 0(a1++)
	loopi 16, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	jal x1, _to_bs_k4

	/* 2nd WDR: 77 bits + 3 bits + (Reload) 8 bits + 88 bits */
	loopi 7, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	bn.rshi wc, w0, wc >> 3
	bn.lid  x0, 0(a1++)
	bn.rshi wc, w0, wc >> 13
	bn.rshi w0, bn0, w0 >> 8
	loopi 8, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	jal x1, _to_bs_k4

	/* Third WDR: 154 bits + 6 bits + (Reload) 5 bits + 11 bits */
	loopi 14, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	bn.rshi wc, w0, wc >> 6
	bn.lid  x0, 0(a1++)
	bn.rshi wc, w0, wc >> 10
	bn.rshi w0, bn0, w0 >> 5
	bn.rshi wc, w0, wc >> 16
	bn.rshi w0, bn0, w0 >> 11
	jal x1, _to_bs_k4

	/* 4th WDR: 176 bits */
	loopi 16, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	jal x1, _to_bs_k4

	/* 5th WDR: 55 bits + 9 bits + (Reload) 2 bits + 110 bits*/
	loopi 5, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	bn.rshi wc, w0, wc >> 9
	bn.lid  x0, 0(a1++)
	bn.rshi wc, w0, wc >> 7
	bn.rshi w0, bn0, w0 >> 2
	loopi 10, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	jal x1, _to_bs_k4

	/* 6th WDR:  143 bits + 1 bits + (Reload) 10 bits + 22 bits */
	loopi 13, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	bn.rshi wc, w0, wc >> 1
	bn.lid  x0, 0(a1++)
	bn.rshi wc, w0, wc >> 15
	bn.rshi w0, bn0, w0 >> 10
	loopi 2, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	jal x1, _to_bs_k4

	/* 7th WDR: 176 bits */
	loopi 16, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	jal x1, _to_bs_k4

	/* 8th WDR: 44 bits + 4 bits + (Reload) 7 bits + 121 bits */
	loopi 4, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	bn.rshi wc, w0, wc >> 4
	bn.lid  x0, 0(a1++)
	bn.rshi wc, w0, wc >> 12
	bn.rshi w0, bn0, w0 >> 7
	loopi 11, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	jal x1, _to_bs_k4

	/* 9th WDR: 121 bits + 7 bits + (Reload) 4 bits + 44 bits */
	loopi 11, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	bn.rshi wc, w0, wc >> 7
	bn.lid  x0, 0(a1++)
	bn.rshi wc, w0, wc >> 9
	bn.rshi w0, bn0, w0 >> 4
	loopi 4, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	jal x1, _to_bs_k4

	/* 10th WDR: 176 bits */
	loopi 16, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	jal x1, _to_bs_k4

	/* 11th WDR: 22 bits + 10 bits + (Reload) 1 bits + 143 bits */
	loopi 2, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	bn.rshi wc, w0, wc >> 10
	bn.lid  x0, 0(a1++)
	bn.rshi wc, w0, wc >> 6
	bn.rshi w0, bn0, w0 >> 1
	loopi 13, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	jal x1, _to_bs_k4

	/* 12th WDR: 110 bits + 2 bits + (Reload) 9 bits + 55 bits */
	loopi 10, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	bn.rshi wc, w0, wc >> 2
	bn.lid  x0, 0(a1++)
	bn.rshi wc, w0, wc >> 14
	bn.rshi w0, bn0, w0 >> 9
	loopi 5, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	jal x1, _to_bs_k4

	/* 13th WDR: 176 bits*/
	loopi 16, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	jal x1, _to_bs_k4

	/* 14th WDR: 11 bits + 5 bits + (Reload) 6 bits + 154 bits */
	bn.rshi wc, w0, wc >> 16
	bn.rshi w0, bn0, w0 >> 11
	bn.rshi wc, w0, wc >> 5
	bn.lid  x0, 0(a1++)
	bn.rshi wc, w0, wc >> 11
	bn.rshi w0, bn0, w0 >> 6
	loopi 14, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	jal x1, _to_bs_k4

	/* 15th WDR: 88 bits + 8 bits + (Reload) 3 bits + 77 bits */
	loopi 8, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	bn.rshi wc, w0, wc >> 8
	bn.lid  x0, 0(a1++)
	bn.rshi wc, w0, wc >> 8
	bn.rshi w0, bn0, w0 >> 3
	loopi 7, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	jal x1, _to_bs_k4

	/* 16th WDR: 176 bits */
	loopi 16, 2
		bn.rshi wc, w0, wc >> 16
		bn.rshi w0, bn0, w0 >> 11
	jal x1, _to_bs_k4

    /* Load mask ((1 << N) - 1). */
    bn.subi wmask, bn0, 1

    /* Compute t[0] ^= c ^ ((1 << N) - 1). */
    bn.xor wb1, wb1, wmask
    bn.xor wb2, wb2, wmask
    bn.xor wb3, wb3, wmask
    bn.xor wb4, wb4, wmask
    bn.xor wb5, wb5, wmask
    bn.xor wb6, wb6, wmask
    bn.xor wb7, wb7, wmask
    bn.xor wb8, wb8, wmask
    bn.xor wb9, wb9, wmask
    bn.xor wb10, wb10, wmask
    bn.xor wb11, wb11, wmask

    addi   x4, x0, 14
    addi   t0, sp, 0 /* ptr_t */
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb1
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb2
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb3
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb4
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb5
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb6
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb7
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb8
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb9
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb10
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb11
    bn.sid x4, 0(t0++)

    addi s1, x0, 11 /* du */
    beq  x0, x0, _handle_common_du

_handle_kn4_du:
    loopi 2, 62
		/* First WDR: 160 bits of w0 */
		bn.lid x0, 0(a1++)
		loopi 16, 2
			bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 10
		jal x1, _to_bs_kn4

		/* Second WDR: 90 bits + 6 bits + (Reload) 4 bits + 60 bits */
		loopi 9, 2
			bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 10
		bn.rshi wc, w0, wc >> 6
		bn.lid  x0, 0(a1++)
		bn.rshi wc, w0, wc >> 10
		bn.rshi w0, bn0, w0 >> 4
		loopi 6, 2
			bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 10
		jal x1, _to_bs_kn4

		/* Third WDR: 160 bits */
		loopi 16, 2
			bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 10
		jal x1, _to_bs_kn4

		/* Fourth WDR: 30 bits + 2 bits + (Reload) 8 bits + 120 bits */
		loopi 3, 2
			bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 10
		bn.rshi wc, w0, wc >> 2
		bn.lid  x0, 0(a1++)
		bn.rshi wc, w0, wc >> 14
		bn.rshi w0, bn0, w0 >> 8
		loopi 12, 2
			bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 10
		jal x1, _to_bs_kn4

		/* Fifth WDR: 120 bits + 8 bits + (Reload) 2 bits + 30 bits */
		loopi 12, 2
			bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 10
		bn.rshi wc, w0, wc >> 8
		bn.lid  x0, 0(a1++)
		bn.rshi wc, w0, wc >> 8
		bn.rshi w0, bn0, w0 >> 2
		loopi 3, 2
			bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 10
		jal x1, _to_bs_kn4

		/* Sixth WDR: 160 bits */
		loopi 16, 2
			bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 10
		jal x1, _to_bs_kn4

		/* Seventh WDR: 60 bits + 4 bits + (Reload) 6 bits + 90 bits */
		loopi 6, 2
			bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 10
		bn.rshi wc, w0, wc >> 4
		bn.lid  x0, 0(a1++)
		bn.rshi wc, w0, wc >> 12
		bn.rshi w0, bn0, w0 >> 6
		loopi 9, 2
			bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 10
		jal x1, _to_bs_kn4

		/* Eigth WDR: 160 bits */
		loopi 16, 2
			bn.rshi wc, w0, wc >> 16
			bn.rshi w0, bn0, w0 >> 10
		jal x1, _to_bs_kn4
        nop

    /* Load mask ((1 << N) - 1). */
    bn.subi wmask, bn0, 1

    /* Compute t[0] ^= c ^ ((1 << N) - 1). */
    bn.xor wb1, wb1, wmask
    bn.xor wb2, wb2, wmask
    bn.xor wb3, wb3, wmask
    bn.xor wb4, wb4, wmask
    bn.xor wb5, wb5, wmask
    bn.xor wb6, wb6, wmask
    bn.xor wb7, wb7, wmask
    bn.xor wb8, wb8, wmask
    bn.xor wb9, wb9, wmask
    bn.xor wb10, wb10, wmask

    addi   x4, x0, 14
    addi   t0, sp, 0 /* ptr_t */
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb1
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb2
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb3
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb4
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb5
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb6
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb7
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb8
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb9
    bn.sid x4, 0(t0++)
    bn.lid x4, 0(t0)
    bn.xor wtmp, wtmp, wb10
    bn.sid x4, 0(t0++)

    addi s1, x0, 10 /* du */
_handle_common_du:
    /* Compute r = secand_cs20(r, t). */
    addi a1, x0, 32
    addi a2, sp, 0 /* ptr_t */
    addi a3, s2, 0 /* share_str */
    addi a4, s3, 0 /* nshares */
    addi a6, x0, 32 /* output share_str */
    /* After the secand_cs20, the input and output pointers will point to
     * next bit so we don't have to pass all the arguments above to secand again. */
    loop s1, 4
        addi a0, s4, 0 /* ptr_r */
        addi a5, s4, 0 /* ptr_r */
        jal  x1, secand_cs20
        nop

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)
    lw s2, 12(fp)
    lw s3, 16(fp)
    lw s4, 20(fp)
    lw a5, 24(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret

_to_bs_k4:
    bn.shv.16h wb1, wb1 << 1
    bn.shv.16h wb2, wb2 << 1
    bn.shv.16h wb3, wb3 << 1
    bn.shv.16h wb4, wb4 << 1
    bn.shv.16h wb5, wb5 << 1
    bn.shv.16h wb6, wb6 << 1
    bn.shv.16h wb7, wb7 << 1
    bn.shv.16h wb8, wb8 << 1
    bn.shv.16h wb9, wb9 << 1
    bn.shv.16h wb10, wb10 << 1
    bn.shv.16h wb11, wb11 << 1
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb1, wb1, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb2, wb2, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb3, wb3, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb4, wb4, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb5, wb5, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb6, wb6, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb7, wb7, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb8, wb8, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb9, wb9, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb10, wb10, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb11, wb11, wtmp
    ret

_to_bs_kn4:
    bn.shv.16h wb1, wb1 << 1
    bn.shv.16h wb2, wb2 << 1
    bn.shv.16h wb3, wb3 << 1
    bn.shv.16h wb4, wb4 << 1
    bn.shv.16h wb5, wb5 << 1
    bn.shv.16h wb6, wb6 << 1
    bn.shv.16h wb7, wb7 << 1
    bn.shv.16h wb8, wb8 << 1
    bn.shv.16h wb9, wb9 << 1
    bn.shv.16h wb10, wb10 << 1
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb1, wb1, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb2, wb2, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb3, wb3, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb4, wb4, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb5, wb5, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb6, wb6, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb7, wb7, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb8, wb8, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb9, wb9, wtmp
    bn.and     wtmp, wc, wone
    bn.shv.16h wc, wc >> 1
    bn.xor     wb10, wb10, wtmp
    ret

/*
 * Name: finalize_cmp_bc22 (inplace)
 *
 * Return Boolean shares of the comparison bit given output of masked_compare_bc22.
 * Bitsliced.
 *
 * Source: Described in Section 6.2 [BC22]
 *         [BC22]: "Bitslicing Arithmetic/Boolean Masking Conversions for Fun and Profit: with Application to Lattice-Based KEMs"
 *         Link: https://tches.iacr.org/index.php/TCHES/article/view/9831
 *
 * @param[in/out] x10: dptr_x, dmem pointer to Boolean shares of output of masked_compare_bc22
 * @param[in]     x11: nshares, the number of shares
 *
 * clobbered registers: x2 to x16, x18, x28 to x31, w0 to w8, w31
 * clobbered flag groups: FG0
 */
.globl finalize_cmp_bc22
finalize_cmp_bc22:
    /* Save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)
    addi fp, sp, 0

    /* Save registers. */
    sw s0, 4(fp)
    sw s1, 8(fp)

    /* Save input and output address. */
    addi s0, a0, 0
    addi s1, a1, 0

    /* Adjust stack space for temporary variable. */
    loop a1, 1
        addi sp, sp, -32

    /* All-zero register. */
    bn.xor bn0, bn0, bn0

    /* Compute x &= (x >> 128). */
    /* Compute t = x >> 128. */
    addi x4, x0, 1
    addi t0, sp, 0 /* ptr_t */
    loop s1, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, bn0, w0 >> 128
        bn.sid  x4, 0(t0++)
    /* Compute x &= t. */
    addi a0, s0, 0
    addi a1, x0, 32
    addi a2, sp, 0
    addi a3, x0, 32
    addi a4, s1, 0
    addi a5, s0, 0
    addi a6, x0, 32
    jal  x1, secand_cs20

    /* Compute x &= (x >> 64). */
    /* Compute t = x >> 64. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loop s1, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, bn0, w0 >> 64
        bn.sid  x4, 0(t0++)
    /* Compute x &= t. */
    addi a0, s0, 0
    /* a1 is still 32. */
    addi a2, sp, 0
    /* a3 is still 32. */
    addi a4, s1, 0
    addi a5, s0, 0
    /* a6 is still 32. */
    jal  x1, secand_cs20

    /* Compute x &= (x >> 32). */
    /* Compute t = x >> 32. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loop s1, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, bn0, w0 >> 32
        bn.sid  x4, 0(t0++)
    /* Compute x &= t. */
    addi a0, s0, 0
    /* a1 is still 32. */
    addi a2, sp, 0
    /* a3 is still 32. */
    addi a4, s1, 0
    addi a5, s0, 0
    /* a6 is still 32. */
    jal  x1, secand_cs20

    /* Compute x &= (x >> 16). */
    /* Compute t = x >> 16. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loop s1, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, bn0, w0 >> 16
        bn.sid  x4, 0(t0++)
    /* Compute x &= t. */
    addi a0, s0, 0
    /* a1 is still 32. */
    addi a2, sp, 0
    /* a3 is still 32. */
    addi a4, s1, 0
    addi a5, s0, 0
    /* a6 is still 32. */
    jal  x1, secand_cs20

    /* Compute x &= (x >> 8). */
    /* Compute t = x >> 8. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loop s1, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, bn0, w0 >> 8
        bn.sid  x4, 0(t0++)
    /* Compute x &= t. */
    addi a0, s0, 0
    /* a1 is still 32. */
    addi a2, sp, 0
    /* a3 is still 32. */
    addi a4, s1, 0
    addi a5, s0, 0
    /* a6 is still 32. */
    jal  x1, secand_cs20

    /* Compute x &= (x >> 4). */
    /* Compute t = x >> 4. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loop s1, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, bn0, w0 >> 4
        bn.sid  x4, 0(t0++)
    /* Compute x &= t. */
    addi a0, s0, 0
    /* a1 is still 32. */
    addi a2, sp, 0
    /* a3 is still 32. */
    addi a4, s1, 0
    addi a5, s0, 0
    /* a6 is still 32. */
    jal  x1, secand_cs20

    /* Compute x &= (x >> 2). */
    /* Compute t = x >> 2. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loop s1, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, bn0, w0 >> 2
        bn.sid  x4, 0(t0++)
    /* Compute x &= t. */
    addi a0, s0, 0
    /* a1 is still 32. */
    addi a2, sp, 0
    /* a3 is still 32. */
    addi a4, s1, 0
    addi a5, s0, 0
    /* a6 is still 32. */
    jal  x1, secand_cs20

    /* Compute x &= (x >> 1). */
    /* Compute t = x >> 1. */
    addi x4, x0, 1
    addi a0, s0, 0
    addi t0, sp, 0 /* ptr_t */
    loop s1, 5
        /* Whitening. */
        bn.xor  w0, w0, w0
        bn.xor  w1, w1, w1
        bn.lid  x0, 0(a0++)
        bn.rshi w1, bn0, w0 >> 1
        bn.sid  x4, 0(t0++)
    /* Compute x &= t. */
    addi a0, s0, 0
    /* a1 is still 32. */
    addi a2, sp, 0
    /* a3 is still 32. */
    addi a4, s1, 0
    addi a5, s0, 0
    /* a6 is still 32. */
    jal  x1, secand_cs20

    /* Restore registers. */
    lw s0, 4(fp)
    lw s1, 8(fp)

    /* Restore sp and fp. */
    addi sp, fp, 0
    lw   fp, 0(sp)
    addi sp, sp, 32
    ret
