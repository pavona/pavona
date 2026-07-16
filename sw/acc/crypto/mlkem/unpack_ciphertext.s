/* Copyright zeroRISC Inc. */
/* Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192). */
/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors. */
/* Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of */
/* "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN" */
/* (https://eprint.iacr.org/2025/2028). */
/* Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

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


/*
 * Name:        poly_decompress
 *
 * Description: De-serialization and subsequent decompression of a polynomial;
 *              approximate inverse of poly_compress
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  a0: dptr_input, dmem pointer to input byte array
 * @param[out] a1: dptr_output, dmem pointer to output polynomial
 * @param[in]  a2: k, the security level
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x0-x30, w0-w31
 */
.globl poly_decompress
.type poly_decompress, @function
poly_decompress:
	/* Load constants. */
	addi   x4, x0, 2
	la     t0, const_8
	bn.lid x4, 0(t0)

	addi x4, x0, 4
	beq  a2, x4, _handle_k4_poly_decompress

_handle_kn4_poly_decompress:
	la         t0, const_0x0fff
	addi       x4, x0, 3
	bn.lid     x4, 0(t0)
	bn.shv.16h w3, w3 >> 8 /* 0xf */
	addi       x4, x0, 1

	loopi 4, 11
		bn.lid x0, 0(a0++)
		loopi 4, 8
			loopi 16, 2
				bn.rshi w1, w0, w1 >> 16
				bn.rshi w0, w31, w0 >> 4
			endloop
			bn.and           w1, w1, w3
			bn.mulv.l.16h.lo w1, w1, sw0.0
			bn.addv.16h      w1, w1, w2
			bn.shv.16h       w1, w1 >> 4
			bn.sid           x4, 0(a1++)
		endloop
		nop
	endloop
	ret

_handle_k4_poly_decompress:
	/* Before, we used bn.mulv.l.8s.{even,odd}.lo to compute 16 16x16-bit
	 * multiplications, because we need the full 32-bit results to shift them by
	 * a certain number of bits. The computation is:
	 * (((a & mask_num_bits) * KYBER_Q) + const) >> num_bits
	 * To use compute 16 16x16-bit multiplications and adding with const at once,
	 * we do the following trick:
	 * ((((a*mask_num_bits)<<(16-num_bits))* KYBER_Q)+(const<<(16-num_bits)))>>16
	 * The addition is the accumulation to ACC(H), so we need to write
	 * (const<<(16-num_bits)) to ACC(H) before the multiplication. The final shift
	 * to the right 16 bits is taking the high parts of the multiplication
	 * results. All of this can be done in bn.mulv.l.16h.acc.hi. */
	addi x4, x0, 1
	/* 1st+2nd+3rd WDRs: 3*80 bits */
	bn.lid x0, 0(a0++)
	loopi 3, 5
		loopi 16, 2
			bn.rshi w1, w0, w1 >> 16
			bn.rshi w0, w31, w0 >> 5
		endloop
		jal    x1, poly_decompress_k4
		bn.sid x4, 0(a1++)
	endloop

	/* 4th WDR: 15 bits + 1 bit + (Reload) 4 bits + 60 bits*/
	loopi 3, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 5
	endloop
	bn.rshi w1, w0, w1 >> 1
	bn.lid  x0, 0(a0++)
	bn.rshi w1, w0, w1 >> 15
	bn.rshi w0, w31, w0 >> 4
	loopi 12, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 5
	endloop
	jal    x1, poly_decompress_k4
	bn.sid x4, 0(a1++)

	/* 5th+6th WDR: 2*80 bits */
	loopi 2, 5
		loopi 16, 2
			bn.rshi w1, w0, w1 >> 16
			bn.rshi w0, w31, w0 >> 5
		endloop
		jal    x1, poly_decompress_k4
		bn.sid x4, 0(a1++)
	endloop

	/* 7th WDR: 30 bits + 2 bits + (Reload) 3 bits + 45 bits */
	loopi 6, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 5
	endloop
	bn.rshi w1, w0, w1 >> 2
	bn.lid  x0, 0(a0++)
	bn.rshi w1, w0, w1 >> 14
	bn.rshi w0, w31, w0 >> 3
	loopi 9, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 5
	endloop
	jal    x1, poly_decompress_k4
	bn.sid x4, 0(a1++)

	/* 8th+9th WDR: 2*80 bits */
	loopi 2, 5
		loopi 16, 2
			bn.rshi w1, w0, w1 >> 16
			bn.rshi w0, w31, w0 >> 5
		endloop
		jal    x1, poly_decompress_k4
		bn.sid x4, 0(a1++)
	endloop

	/* 10th WDR: 45 bits + 3 bits + (Reload) 2 bits + 30 bits */
	loopi 9, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 5
	endloop
	bn.rshi w1, w0, w1 >> 3
	bn.lid  x0, 0(a0++)
	bn.rshi w1, w0, w1 >> 13
	bn.rshi w0, w31, w0 >> 2
	loopi 6, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 5
	endloop
	jal    x1, poly_decompress_k4
	bn.sid x4, 0(a1++)

	/* 11th+12th WDR: 2*80 bits */
	loopi 2, 5
		loopi 16, 2
			bn.rshi w1, w0, w1 >> 16
			bn.rshi w0, w31, w0 >> 5
		endloop
		jal    x1, poly_decompress_k4
		bn.sid x4, 0(a1++)
	endloop

	/* 13th WDR: 60 bits + 4 bits + (Reload) 1 bit + 15 bits */
	loopi 12, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 5
	endloop
	bn.rshi w1, w0, w1 >> 4
	bn.lid  x0, 0(a0++)
	bn.rshi w1, w0, w1 >> 12
	bn.rshi w0, w31, w0 >> 1
	loopi 3, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 5
	endloop
	jal    x1, poly_decompress_k4
	bn.sid x4, 0(a1++)

  	/* 14th+15th+16th WDRs: 3*80 bits */
	loopi 3, 5
		loopi 16, 2
			bn.rshi w1, w0, w1 >> 16
			bn.rshi w0, w31, w0 >> 5
		endloop
		jal    x1, poly_decompress_k4
		bn.sid x4, 0(a1++)
	endloop
  ret

/*
 * Name:        poly_decompress_k4
 *
 * Description: Subroutine of poly_decompress for decompressing 16 coefficients when KYBER_K == 4
 *
 * @param[in/out] w1: input/output vector with 16 16-bit coefficients
 * @param[in]     w2: const_8
 * @param[in]     w16 (sw0): R | Q
 * @param[in]     w31: all-zero
 *
 * clobbered registers: w1, acch, acc
 */
.type poly_decompress_k4, @function
poly_decompress_k4:
  bn.shv.16h           w1, w1 << 11 /* << 11 */
  bn.wsrw              acc, w2 /* Write w2 to ACC */
  bn.wsrw              acch, w2 /* Write w2 to ACCH */
  bn.mulv.l.16h.acc.hi w1, w1, sw0.0 /* *KYBER_Q + ACC */
  ret

/*
 * Name:        poly_polyvec_decompress
 *
 * Description: De-serialize and decompress a single polynomial of a vector of
 *              polynomials; approximate inverse of poly_polyvec_compress
 *
 * @param[in]  a0: dptr_input, dmem pointer to input byte array
 * @param[out] a1: dptr_output, dmem pointer to output polynomial
 * @param[in]  a2: k, the security level
 * @param[in]  w16 (sw0): R | Q
 * @param[in]  w31: all-zero register
 *
 * clobbered registers: x0-x30, w0-w31
 */
.globl poly_polyvec_decompress
.type poly_polyvec_decompress, @function
poly_polyvec_decompress:
	/* Load constants. */
	la        t0, const_8
	addi      x4, x0, 2
	bn.lid    x4++, 0(t0)
	bn.shv.8s w2, w2 << 16 /* Shift out the odd 16-bit slots. */
	bn.shv.8s w2, w2 >> 4 /* w2 = (0x00008000)^8 */
	la        t0, const_0x0fff
	bn.lid    x4++, 0(t0)

	/* Before, we used bn.mulv.l.8s.{even,odd}.lo to compute 16 16x16-bit
	 * multiplications, because we need the full 32-bit results to shift them by
	 * a certain number of bits. The computation is:
	 * (((a & mask_num_bits) * KYBER_Q) + const) >> num_bits
	 * To use compute 16 16x16-bit multiplications and adding with const at once,
	 * we do the following trick:
	 * ((((a*mask_num_bits)<<(16-num_bits))* KYBER_Q)+(const<<(16-num_bits)))>>16
	 * The addition is the accumulation to ACC(H), so we need to write
	 * (const<<(16-num_bits)) to ACC(H) before the multiplication. The final shift
	 * to the right 16 bits is taking the high parts of the multiplication
	 * results. All of this can be done in bn.mulv.l.16h.acc.hi. */
	beq  a2, x4, _handle_k4_polyvec_decompress

_handle_kn4_polyvec_decompress:
	addi x4, x0, 1

	loopi 2, 69
		/* First WDR: 160 bits of w0 */
		bn.lid x0, 0(a0++)
		loopi 16, 2
			bn.rshi w1, w0, w1 >> 16  /* Extract 10 bit from input to a 16-bit vector slot */
			bn.rshi w0, w31, w0 >> 10 /* Shift out used bits */
		endloop
		jal    x1, polyvec_decompress_kn4
		bn.sid x4, 0(a1++)

		/* Second WDR: 90 bits + 6 bits + (Reload) 4 bits + 60 bits */
		loopi 9, 2
			bn.rshi w1, w0, w1 >> 16
			bn.rshi w0, w31, w0 >> 10
		endloop
		bn.rshi w1, w0, w1 >> 6 /* Move the final 6 bits of w0 to w1 */
		bn.lid  x0, 0(a0++) /* Load the second batch of input to w0 */
		bn.rshi w1, w0, w1 >> 10 /* Move the first 4 bits of w0 to w1 to form 10 bits */
		bn.rshi w0, w31, w0 >> 4 /* Shift out the used 4 bits */
		loopi 6, 2
			bn.rshi w1, w0, w1 >> 16
			bn.rshi w0, w31, w0 >> 10
		endloop
		jal x1, polyvec_decompress_kn4
		bn.sid x4, 0(a1++)

		/* Third WDR: 160 bits */
		loopi 16, 2
			bn.rshi w1, w0, w1 >> 16
			bn.rshi w0, w31, w0 >> 10
		endloop
		jal    x1, polyvec_decompress_kn4
		bn.sid x4, 0(a1++)

		/* Fourth WDR: 30 bits + 2 bits + (Reload) 8 bits + 120 bits */
		loopi 3, 2
			bn.rshi w1, w0, w1 >> 16
			bn.rshi w0, w31, w0 >> 10
		endloop
		bn.rshi w1, w0, w1 >> 2 /* Move the final 2 bits of w0 to w1 */
		bn.lid  x0, 0(a0++) /* Load the third batch of input */
		bn.rshi w1, w0, w1 >> 14 /* Move the first 8 bits of w0 to w1 to form 10 bits */
		bn.rshi w0, w31, w0 >> 8 /* Shift out used bits */
		loopi 12, 2
			bn.rshi w1, w0, w1 >> 16
			bn.rshi w0, w31, w0 >> 10
		endloop
		jal    x1, polyvec_decompress_kn4
		bn.sid x4, 0(a1++)

		/* Fifth WDR: 120 bits + 8 bits + (Reload) 2 bits + 30 bits */
		loopi 12, 2
			bn.rshi w1, w0, w1 >> 16
			bn.rshi w0, w31, w0 >> 10
		endloop
		bn.rshi w1, w0, w1 >> 8 /* Move the final 8 bits of w0 to w1 */
		bn.lid  x0, 0(a0++) /* Load the fourth batch of input to w0 */
		bn.rshi w1, w0, w1 >> 8 /* Move the first 2 bits of w0 to w1 to form 10 bits */
		bn.rshi w0, w31, w0 >> 2 /* Shift out used bits */
		loopi 3, 2
			bn.rshi w1, w0, w1 >> 16
			bn.rshi w0, w31, w0 >> 10
		endloop
		jal    x1, polyvec_decompress_kn4
		bn.sid x4, 0(a1++)

		/* Sixth WDR: 160 bits */
		loopi 16, 2
			bn.rshi w1, w0, w1 >> 16
			bn.rshi w0, w31, w0 >> 10
		endloop
		jal    x1, polyvec_decompress_kn4
		bn.sid x4, 0(a1++)

		/* Seventh WDR: 60 bits + 4 bits + (Reload) 6 bits + 90 bits */
		loopi 6, 2
			bn.rshi w1, w0, w1 >> 16
			bn.rshi w0, w31, w0 >> 10
		endloop
		bn.rshi      w1, w0, w1 >> 4 /* Move the final 4 bits of w0 to w1 */
		bn.lid       x0, 0(a0++) /* Load the fifth batch of input to w0 */
		bn.rshi      w1, w0, w1 >> 12 /* Move the first 6 bits of w0 to w1 to form 10 bits */
		bn.rshi      w0, w31, w0 >> 6 /* Shift out used bits */
		loopi 9, 2
			bn.rshi w1, w0, w1 >> 16
			bn.rshi w0, w31, w0 >> 10
		endloop
		jal    x1, polyvec_decompress_kn4
		bn.sid x4, 0(a1++)

		/* Eigth WDR: 160 bits */
		loopi 16, 2
			bn.rshi w1, w0, w1 >> 16
			bn.rshi w0, w31, w0 >> 10
		endloop
		jal    x1, polyvec_decompress_kn4
		bn.sid x4, 0(a1++)
	endloop
	ret

_handle_k4_polyvec_decompress:
	addi x4, x0, 1

	/* First WDR: 176 bits */
	bn.lid x0, 0(a0++)
	loopi 16, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	jal    x1, polyvec_decompress_k4
	bn.sid x4, 0(a1++)

	/* 2nd WDR: 77 bits + 3 bits + (Reload) 8 bits + 88 bits */
	loopi 7, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	bn.rshi w1, w0, w1 >> 3
	bn.lid  x0, 0(a0++)
	bn.rshi w1, w0, w1 >> 13
	bn.rshi w0, w31, w0 >> 8
	loopi 8, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	jal    x1, polyvec_decompress_k4
	bn.sid x4, 0(a1++)

	/* Third WDR: 154 bits + 6 bits + (Reload) 5 bits + 11 bits */
	loopi 14, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	bn.rshi              w1, w0, w1 >> 6
	bn.lid               x0, 0(a0++)
	bn.rshi              w1, w0, w1 >> 10
	bn.rshi              w0, w31, w0 >> 5
	bn.rshi              w1, w0, w1 >> 16
	bn.rshi              w0, w31, w0 >> 11
	jal    x1, polyvec_decompress_k4
	bn.sid x4, 0(a1++)

	/* 4th WDR: 176 bits */
	loopi 16, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	jal    x1, polyvec_decompress_k4
	bn.sid x4, 0(a1++)

	/* 5th WDR: 55 bits + 9 bits + (Reload) 2 bits + 110 bits*/
	loopi 5, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	bn.rshi w1, w0, w1 >> 9
	bn.lid  x0, 0(a0++)
	bn.rshi w1, w0, w1 >> 7
	bn.rshi w0, w31, w0 >> 2
	loopi 10, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	jal    x1, polyvec_decompress_k4
	bn.sid x4, 0(a1++)

	/* 6th WDR:  143 bits + 1 bits + (Reload) 10 bits + 22 bits */
	loopi 13, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	bn.rshi w1, w0, w1 >> 1
	bn.lid  x0, 0(a0++)
	bn.rshi w1, w0, w1 >> 15
	bn.rshi w0, w31, w0 >> 10
	loopi 2, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	jal    x1, polyvec_decompress_k4
	bn.sid x4, 0(a1++)

	/* 7th WDR: 176 bits */
	loopi 16, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	jal    x1, polyvec_decompress_k4
	bn.sid x4, 0(a1++)

	/* 8th WDR: 44 bits + 4 bits + (Reload) 7 bits + 121 bits */
	loopi 4, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	bn.rshi w1, w0, w1 >> 4
	bn.lid  x0, 0(a0++)
	bn.rshi w1, w0, w1 >> 12
	bn.rshi w0, w31, w0 >> 7
	loopi 11, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	jal    x1, polyvec_decompress_k4
	bn.sid x4, 0(a1++)

	/* 9th WDR: 121 bits + 7 bits + (Reload) 4 bits + 44 bits */
	loopi 11, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	bn.rshi w1, w0, w1 >> 7
	bn.lid  x0, 0(a0++)
	bn.rshi w1, w0, w1 >> 9
	bn.rshi w0, w31, w0 >> 4
	loopi 4, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	jal    x1, polyvec_decompress_k4
	bn.sid x4, 0(a1++)

	/* 10th WDR: 176 bits */
	loopi 16, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	jal    x1, polyvec_decompress_k4
	bn.sid x4, 0(a1++)

	/* 11th WDR: 22 bits + 10 bits + (Reload) 1 bits + 143 bits */
	loopi 2, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	bn.rshi w1, w0, w1 >> 10
	bn.lid  x0, 0(a0++)
	bn.rshi w1, w0, w1 >> 6
	bn.rshi w0, w31, w0 >> 1
	loopi 13, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	jal    x1, polyvec_decompress_k4
	bn.sid x4, 0(a1++)

	/* 12th WDR: 110 bits + 2 bits + (Reload) 9 bits + 55 bits */
	loopi 10, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	bn.rshi w1, w0, w1 >> 2
	bn.lid  x0, 0(a0++)
	bn.rshi w1, w0, w1 >> 14
	bn.rshi w0, w31, w0 >> 9
	loopi 5, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	jal    x1, polyvec_decompress_k4
	bn.sid x4, 0(a1++)

	/* 13th WDR: 176 bits*/
	loopi 16, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	jal    x1, polyvec_decompress_k4
	bn.sid x4, 0(a1++)

	/* 14th WDR: 11 bits + 5 bits + (Reload) 6 bits + 154 bits */
	bn.rshi w1, w0, w1 >> 16
	bn.rshi w0, w31, w0 >> 11
	bn.rshi w1, w0, w1 >> 5
	bn.lid  x0, 0(a0++)
	bn.rshi w1, w0, w1 >> 11
	bn.rshi w0, w31, w0 >> 6
	loopi 14, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	jal    x1, polyvec_decompress_k4
	bn.sid x4, 0(a1++)

	/* 15th WDR: 88 bits + 8 bits + (Reload) 3 bits + 77 bits */
	loopi 8, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	bn.rshi w1, w0, w1 >> 8
	bn.lid  x0, 0(a0++)
	bn.rshi w1, w0, w1 >> 8
	bn.rshi w0, w31, w0 >> 3
	loopi 7, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	jal    x1, polyvec_decompress_k4
	bn.sid x4, 0(a1++)

	/* 16th WDR: 176 bits */
	loopi 16, 2
		bn.rshi w1, w0, w1 >> 16
		bn.rshi w0, w31, w0 >> 11
	endloop
	jal    x1, polyvec_decompress_k4
	bn.sid x4, 0(a1++)
  ret

/*
 * Name:        polyvec_decompress_kn4
 *
 * Description: Subroutine of poly_polyvec_decompress for decompressing 16 coefficients when KYBER_K != 4
 *
 * @param[in/out] w1: input/output vector with 16 16-bit coefficients
 * @param[in]     w16 (sw0): R | Q
 * @param[in]     w2: (0x00008000)^8
 *
 * clobbered registers: w1, acch, acc
 */
.type polyvec_decompress_kn4, @function
polyvec_decompress_kn4:
  bn.shv.16h           w1, w1 << 6 /* *(2**6) */
  bn.wsrw              acc, w2 /* Write w2 to ACC */
  bn.wsrw              acch, w2 /* Write w2 to ACCH */
  bn.mulv.l.16h.acc.hi w1, w1, sw0.0 /* *KYBER_Q + ACC */
  ret

/*
 * Name:        polyvec_decompress_k4
 *
 * Description: Subroutine of poly_polyvec_decompress for decompressing 16 coefficients when KYBER_K == 4
 *
 * @param[in/out] w1: input/output vector with 16 16-bit coefficients
 * @param[in]     w16 (sw0): R | Q
 * @param[in]     w2: (0x00008000)^8
 *
 * clobbered registers: w1, acch, acc
 */
.type polyvec_decompress_k4, @function
polyvec_decompress_k4:
  bn.shv.16h           w1, w1 << 5 /* *(2**5) */
  bn.wsrw              acc, w2 /* Write w2 to ACC */
  bn.wsrw              acch, w2 /* Write w2 to ACCH */
  bn.mulv.l.16h.acc.hi w1, w1, sw0.0 /* *KYBER_Q + ACC */
  ret
