/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text
/* #define SWSHAKE */

#define SEEDBYTES 32
#define CRHBYTES 64
#define TRBYTES 64
#define RNDBYTES 32
#define N 256
#define Q 8380417
#define D 13
#define ROOT_OF_UNITY 1753

#if DILITHIUM_MODE == 2
#define K 4
#define L 4
#define ETA 2
#define TAU 39
#define BETA 78
#define GAMMA1 131072
#define GAMMA2 95232
#define OMEGA 80
#define CTILDEBYTES 32

#define POLYVECK_BYTES 4096
#define POLYVECL_BYTES 4096

#define CRYPTO_PUBLICKEYBYTES 1312
#define CRYPTO_SECRETKEYBYTES 2560
#define CRYPTO_BYTES 2420

#elif DILITHIUM_MODE == 3
#define K 6
#define L 5
#define ETA 4
#define TAU 49
#define BETA 196
#define GAMMA1 524288
#define GAMMA2 261888
#define OMEGA 55
#define CTILDEBYTES 48

#define POLYVECK_BYTES 6144
#define POLYVECL_BYTES 5120

#define CRYPTO_PUBLICKEYBYTES 1952
#define CRYPTO_SECRETKEYBYTES 4032
#define CRYPTO_BYTES 3309

#elif DILITHIUM_MODE == 5
#define K 8
#define L 7
#define ETA 2
#define TAU 60
#define BETA 120
#define GAMMA1 524288
#define GAMMA2 261888
#define OMEGA 75
#define CTILDEBYTES 64

#define POLYVECK_BYTES 8192
#define POLYVECL_BYTES 7168

#define CRYPTO_PUBLICKEYBYTES 2592
#define CRYPTO_SECRETKEYBYTES 4896
#define CRYPTO_BYTES 4627

#endif

#define POLYT1_PACKEDBYTES  320
#define POLYT0_PACKEDBYTES  416
#define POLYVECH_PACKEDBYTES (OMEGA + K)

#if GAMMA1 == (1 << 17)
#define POLYZ_PACKEDBYTES   576
#elif GAMMA1 == (1 << 19)
#define POLYZ_PACKEDBYTES   640
#endif

#if GAMMA2 == (Q-1)/88
#define POLYW1_PACKEDBYTES  192
#elif GAMMA2 == (Q-1)/32
#define POLYW1_PACKEDBYTES  128
#endif

#if ETA == 2
#define POLYETA_PACKEDBYTES  96
#elif ETA == 4
#define POLYETA_PACKEDBYTES 128
#endif

/* Register aliases */
.equ x0, zero
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
    addi sp, sp, -4      /* Decrement stack pointer by 4 bytes */
    sw \reg, 0(sp)      /* Store register value at the top of the stack */
.endm

.macro pop reg
    lw \reg, 0(sp)      /* Load value from the top of the stack into register */
    addi sp, sp, 4     /* Increment stack pointer by 4 bytes */
.endm

/*
 * Send a variable-length message to the Keccak core.
 *
 * Expects the Keccak core to have already received a `start` command matching
 * the desired hash function. After calling this routine, reading from the
 * KECCAK_DIGEST special register will return the hash digest.
 *
 * @param[in]   a1: len, byte-length of the message
 * @param[in]   a0: dptr_msg, pointer to message in DMEM
 * @param[in]   w31: all-zero
 * @param[in] dmem[dptr_msg..dptr_msg+len]: msg, hash function input
 *
 * clobbered registers: t0, a1, w0
 * clobbered flag groups: None
 */
keccak_send_message:
  /* Compute the number of full 256-bit message chunks.
       t0 <= x11 >> 5 = floor(len / 32) */
  srli     t0, x11, 5

  /* Write all full 256-bit sections of the test message. */
  beq t0, zero, _no_full_wdr
  loop     t0, 2
    /* w0 <= dmem[x10..x10+32] = msg[32*i..32*i-1]
       x10 <= x10 + 32 */
    bn.lid   x0, 0(x10++)
    /* Write to the KECCAK_MSG wide special register (index 8).
         KECCAK_MSG <= w0 */
    bn.wsrw  0x9, w0
_no_full_wdr:
  /* Compute the remaining message length.
       t0 <= x10 & 31 = len mod 32 */
  andi     t0, x11, 31

  /* If the remaining length is zero, return early. */
  beq      t0, x0, _keccak_send_message_end

  bn.lid   x0, 0(x10)
  bn.wsrw  0x9, w0

  _keccak_send_message_end:
  ret

/**
 * polyt1_unpack_dilithium
 *
 * Unpack polynomial t1 with coefficients fitting in 10 bits.
 * Output coefficients are standard representatives.
 * 
 * Returns: -
 *
 * @param[in]  a1: pointer to input byte array with POLYT1_PACKEDBYTES bytes
 * @param[out] a0: pointer to output polynomial
 *
 * clobbered registers: a0-a1, t0-t2
 */

.global polyt1_unpack_dilithium
polyt1_unpack_dilithium:

    /* Setup WDR */ 
    li t1, 1
    li t2, 2
    li t3, 3
    li t4, 4
    li t5, 5

    /* Load mask for zeroing the upper bits of the unpacked coefficients. */
    la t6, polyt1_unpack_dilithium_mask
    bn.lid t5, 0(t6)
    li t6, 6

    LOOPI 2, 23
        /* Start unpacking */
        bn.lid t1, 0(a1++)
        jal    x1, _inner_polyt1_unpack_dilithium

        /* Current state: w1 = 0|w1[160:256] */
        bn.lid t6, 0(a1++)      /* Load new WLEN word to w6 */
        bn.or  w1, w1, w6 << 96 /* w1 = w6[0:160]|w1[160:256] */
        jal    x1, _inner_polyt1_unpack_dilithium 

        /* Current state: w1 = 0|w6[64:160] */
        bn.rshi w6, bn0, w6 >> 160
        bn.or   w1, w1, w6 << 96 /* w1 = 0[64]|w6[160:256]|w6[64:160] */
        jal     x1, _inner_polyt1_unpack_dilithium

        /* Current state: w1 = 0|w6[224:256] */
        bn.lid t6, 0(a1++)       /* Load new WLEN word to w6 */
        bn.or  w1, w1, w6 << 32  /* w1 = w6[0:224]|w6_prev[224:256] */
        jal    x1, _inner_polyt1_unpack_dilithium

        /* Current state: w1 = 0|w6[128:224] */
        bn.or  w1, bn0, w6 >> 128
        bn.lid t6, 0(a1++)       /* Load new WLEN word to w6 */
        bn.or  w1, w1, w6 << 128 /* w1 = w6[0:128]|w6_prev[128:256] */
        jal    x1, _inner_polyt1_unpack_dilithium

        /* Current state: w1 = 0|w6[32:128] */
        bn.or w1, bn0, w6 >> 32 /* w1 = 0[32]|w6[128:256]|w6[32:128] */
        jal   x1, _inner_polyt1_unpack_dilithium

        /* Current state: w1 = 0|w6[192:256] */
        bn.lid t6, 0(a1++)       /* Load new WLEN word to w6 */
        bn.or  w1, w1, w6 << 64 /* w1 = w6[0:192]|w6_prev[192:256] */
        jal    x1, _inner_polyt1_unpack_dilithium

        bn.or w1, bn0, w6 >> 96 /* w1 = w6[96:256] */
        jal   x1, _inner_polyt1_unpack_dilithium
        nop
    
    ret

/**
 * _inner_polyt1_unpack_dilithium
 *
 * Inner part of unpacking function to reduce the code size.
 * Do not call from anywhere but polyeta_unpack_dilithium.
 * Does not adhere to calling convention.
 */
_inner_polyt1_unpack_dilithium:
    /* Unpack 16 coefficients in one go */
    LOOPI 2, 18
        /* This could also be done by a loop but it causes 64 cycles per
           function call, which is a lot to save 14 instructions */
        .rept 8
            /* Shift one coefficient into the output register, ignoring the
                upper 22 bits of other coefficient data */
            bn.rshi w2, w1, w2 >> 32
            /* Advance the input register such that the next coefficient is
                in the lower 10 bits */
            bn.rshi w1, bn0, w1 >> 10
        .endr
        
        bn.and     w2, w2, w5 /* Mask unpacked coeffs to 10 bit */

        bn.sid t2, 0(a0++)
    ret

/**
 * polyz_unpack_base_dilithium
 *
 * Unpack polynomial z with coefficients in [-(GAMMA1 - 1), GAMMA1] fitting into
 * 18 bits. 
 * 
 * Returns: -
 *
 * @param[in]  a1: pointer to input byte array with POLYZ_PACKEDBYTES bytes
 * @param[out] a0: pointer to output polynomial
 *
 * clobbered registers: a0-a1, t0-t6
 */
.global polyz_unpack_base_dilithium
polyz_unpack_base_dilithium:
#if GAMMA1 == (1 << 17)
    /* Load gamma1 as a vector into w4 */
    li t2, 4
    la t3, gamma1_vec_base_const
    bn.lid t2, 0(t3)

    /* Load mask for zeroing the upper bits of the unpacked coefficients. */
    li t2, 5
    la t3, polyz_unpack_base_dilithium_mask
    bn.lid t5, 0(t3)

    /* Setup WDR */ 
    li t2, 2
    li t3, 3
    li t6, 6

    LOOPI 2, 42
        bn.lid  t6, 0(a1++)
        bn.mov  w1, w6
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.lid  t3, 0(a1++)
        bn.rshi w1, w3, w6 >> 144
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.rshi w1, bn0, w3 >> 32
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.lid  t6, 0(a1++)
        bn.rshi w1, w6, w3 >> 176
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.rshi w1, bn0, w6 >> 64
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.lid  t3, 0(a1++)
        bn.rshi w1, w3, w6 >> 208
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.rshi w1, bn0, w3 >> 96
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.lid  t6, 0(a1++)
        bn.rshi w1, w6, w3 >> 240
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.lid  t3, 0(a1++)
        bn.rshi w1, w3, w6 >> 128
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.rshi w1, bn0, w3 >> 16
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.lid  t6, 0(a1++)
        bn.rshi w1, w6, w3 >> 160
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.rshi w1, bn0, w6 >> 48
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.lid  t3, 0(a1++)
        bn.rshi w1, w3, w6 >> 192
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.rshi w1, bn0, w3 >> 80
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.lid  t6, 0(a1++)
        bn.rshi w1, w6, w3 >> 224
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.rshi w1, bn0, w6 >> 112
        jal     x1, _inner_polyz_unpack_base_dilithium
        nop /* Must not end on branch */

    ret

/**
 * _inner_polyz_unpack_base_dilithium
 *
 * Inner part of unpacking function to reduce the code size.
 * Do not call from anywhere but polyz_unpack_dilithium.
 * Does not adhere to calling convention.
 */
_inner_polyz_unpack_base_dilithium:
    /* Unpack 8 coefficients in one go */
    .rept 8
        /* Mask */
        bn.and w7, w1, w5
        /* Subtract coefficient from gamma1 */
        bn.sub w7, w4, w7
        /* Move coefficient into the output register */
        bn.rshi w2, w7, w2 >> 32
        /* Advance the input register such that the next coefficient is
            in the lower 18 bits */
        bn.rshi w1, bn0, w1 >> 18
    .endr
    
    bn.sid     t2, 0(a0++)
    ret
#elif GAMMA1 == (1 << 19)
    /* Load gamma1 as a vector into w4 */
    li t2, 4
    la t3, gamma1_vec_base_const
    bn.lid t2, 0(t3)

    /* Load mask for zeroing the upper bits of the unpacked coefficients. */
    li t2, 5
    la t3, polyz_unpack_base_dilithium_mask
    bn.lid t5, 0(t3)

    /* Setup WDR */ 
    li t2, 2
    li t3, 3
    li t6, 6

    LOOPI 4, 22
        bn.lid  t6, 0(a1++)
        bn.mov  w1, w6
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.lid  t3, 0(a1++)
        bn.rshi w1, w3, w6 >> 160
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.rshi w1, bn0, w3 >> 64
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.lid  t6, 0(a1++)
        bn.rshi w1, w6, w3 >> 224
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.lid  t3, 0(a1++)
        bn.rshi w1, w3, w6 >> 128
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.rshi w1, bn0, w3 >> 32
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.lid  t6, 0(a1++)
        bn.rshi w1, w6, w3 >> 192
        jal     x1, _inner_polyz_unpack_base_dilithium

        bn.rshi w1, bn0, w6 >> 96
        jal     x1, _inner_polyz_unpack_base_dilithium
        nop /* Must not end on branch */

    ret

/**
 * _inner_polyz_unpack_base_dilithium
 *
 * Inner part of unpacking function to reduce the code size.
 * Do not call from anywhere but polyz_unpack_dilithium.
 * Does not adhere to calling convention.
 */
_inner_polyz_unpack_base_dilithium:
    /* Unpack 8 coefficients in one go */
    .rept 8
        /* Mask */
        bn.and w7, w1, w5
        /* Subtract coefficient from gamma1 */
        bn.sub w7, w4, w7
        /* Move coefficient into the output register */
        bn.rshi w2, w7, w2 >> 32
        /* Advance the input register such that the next coefficient is
            in the lower 18 bits */
        bn.rshi w1, bn0, w1 >> 20
    .endr
    
    bn.sid     t2, 0(a0++)
    ret
#endif
/**
 * poly_chknorm_base_dilithium
 *
 * Check infinity norm of polynomial against given bound.
 * Assumes input coefficients were reduced by reduce32().
 * 
 * Returns: 0 if norm is strictly smaller than B <= (Q-1)/8 and 1 otherwise.
 *
 * Flags: -
 *
 * @param[in]     a1: norm bound
 * @param[in]     a0: pointer to polynomial
 *
 * clobbered registers: a0-a1, t0-t5, w1-w2
 */
 .global poly_chknorm_base_dilithium
poly_chknorm_base_dilithium:
    /* save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)

    addi fp, sp, 0
    
    /* Adjust sp to accomodate local variables */
    addi sp, sp, -32

    /* Reserve space for tmp buffer to hold a WDR */
    #define STACK_WDR2GPR -32

    /* Load modulus Q */
    la   t0, modulus
    lw   t1, 0(t0)
    /* Compute (Q-1)/8 */
    addi t1, t1, -1
    srli t1, t1, 3 /* /8 */

    /* (Q-1)/8 <? B  */
    sub t2, t1, a1
    srli t2, t2, 31
    bne zero, t2, _ret1_poly_chknorm_base_dilithium

    /* Set end address */
    addi t0, a0, 1024
    /* Setup WDRs */
    li t1, 1
    li t2, 2
_loop_poly_chknorm_base_dilithium:
    /* bn.lid      t1, 0(a0) */
    lw t1, 0(a0)

    /* constant time absolute value 
       t = a->coeffs[i] >> 31;
       t = a->coeffs[i] - (t & 2*a->coeffs[i]);
    */
    srai t2, t1, 31 /* Get the mask */
    slli t3, t1, 1 /* t3 <= (2 * t1) */
    and  t2, t2, t3 /* t2 <= t2 & (2 * t1) */
    sub  t2, t1, t2
    
    /* t5 <= 1, if t2 <? a1, else 0 with a1 the bound */
    sub  t5, t2, a1
    srli t5, t5, 31
    beq  t5, zero, _ret1_poly_chknorm_base_dilithium

    addi a0, a0, 4
    bne a0, t0, _loop_poly_chknorm_base_dilithium

_ret0_poly_chknorm_base_dilithium:
    /* sp <- fp */
    addi sp, fp, 0
    /* Pop ebp */
    lw fp, 0(sp)
    addi sp, sp, 32
    /* return success */
    li a0, 0
    ret
_ret1_poly_chknorm_base_dilithium:
    /* sp <- fp */
    addi sp, fp, 0
    /* Pop ebp */
    lw fp, 0(sp)
    addi sp, sp, 32
    /* return fail */
    li a0, 1
    ret

/**
 * poly_challenge
 *
 * Implementation of H. Samples polynomial with TAU nonzero coefficients in
 * {-1,1} using the output stream of SHAKE256(seed).
 * 
 * Returns: -
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  a1: mu byte array containing seed of length SEEDBYTES
 * @param[out] a0: pointer to output polynomial
 *
 * clobbered registers: a0-a5, t0-t3, w0-w3
 */
.global poly_challenge
poly_challenge:
    /* save fp to stack */
    addi sp, sp, -32
    sw   fp, 0(sp)

    addi fp, sp, 0
    
    /* Adjust sp to accomodate local variables */
    addi sp, sp, -32

    /* Reserve space for tmp buffer to hold a WDR */
    #define STACK_WDR2GPR -32

    /* save output pointer */
    addi a4, a0, 0

    /* Initialize a SHAKE256 operation. */
    addi a0, a1, 0 /* a0 <= *mu */

    li    a1, CTILDEBYTES /* a1 <= CTILDEBYTES */
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw zero, KECCAK_CFG_REG, t0

    /* Send the message to the Keccak core. */
    /* a0 contains *mu already */
    /* a1 contains CTILDEBYTES already */
    jal  x1, keccak_send_message

    /* Restore output pointer */
    addi a1, a0, 0
    addi a0, a4, 0

    /* Read first SHAKE output */
    bn.wsrr w0, 0xA /* KECCAK_DIGEST */

    /* Initialize output poly to 0 */
    add t1, zero, a0

    /* w31 contains all zeros by convention */ 
    li t0, 31
    LOOPI 32, 1
        bn.sid t0, 0(t1++)

    /* Setup WDR */
    li t0, 0
    li a6, 3

    /* fill signs */

    /* Load mask (2**64)-1 to w2 */
    bn.addi w1, bn0, 1
    bn.or   w2, bn0, w1 << 64
    bn.sub  w2, w2, w1

    /* w1 <= signs */
    /* Mask out the sign bits from the WDR containing the SHAKE output */
    bn.or   w1, bn0, w0
    bn.and  w1, w1, w2
    /* w2 <= 1-bit mask */
    bn.addi w2, bn0, 1
    /* shift out sign bits from the register containing the SHAKE output */
    bn.rshi w0, bn0, w0 >> 64

    /* a2 <= number of remaining bits in buf */
    li a2, 192
    
    li t1, TAU
    li a4, N
    /* a3 <= i = N-TAU */
    sub a3, a4, t1
    li t3, 1

    LOOPI TAU, 25
    /* get address of c->coeffs[i], the current coefficient */
    slli a5, a3, 2 /* i * 4 for byte position */
    add  a5, a5, a0 /* Add the array start address: c->coeffs + i * 4 */
    /* start do-while loop */
_loop_inner_poly_challenge:
        /* If the SHAKE output "buffer" register w0 is empty, squeeze again.
        Since all reads from w0 are equally large (8 bits) and 8 | 256, 
        we can just check for "zero" */
        bne     zero, a2, _loop_inner_skip_load_poly_challenge
        bn.wsrr w0, 0xA /* KECCAK_DIGEST */
        li      a2, 256 /* reset the remaining bits counter */
_loop_inner_skip_load_poly_challenge:
        /* Store w0 to the stack in order to read one word into a GPR */
        bn.sid  t0, STACK_WDR2GPR(fp)
        bn.rshi w0, bn0, w0 >> 8 /* shift out used bits */
        addi    a2, a2, -8 /* decrease number of remaining bits */
        /* NOTE: optimize this to use all bytes from this load */
        lw      t1, STACK_WDR2GPR(fp) /* get one word of SHAKE output into GPR */
        /* t1 = b from the reference implementation */
        andi    t1, t1, 0xFF /* mask out one byte, because we only need one */
        sub     t2, a3, t1 /* i <? b */
        srli    t2, t2, 31
        /* while(b > i); */
        beq     t3, t2, _loop_inner_poly_challenge

        /* Implements:
        c->coeffs[i] = c->coeffs[b];
        c->coeffs[b] = 1 - 2*(signs & 1);
        signs >>= 1; */
        /* get address of c->coeffs[b] */
        slli t1, t1, 2  /* b * 4 for byte position */
        add  t1, t1, a0 /* Add the array start address: c->coeffs + b * 4 */

        /* "swap" */
        lw t2, 0(t1) /* Load c->coeffs[b] */
        sw t2, 0(a5) /* c->coeffs[i] = c->coeffs[b]; */

        /* NOTE: accumulate result values in WDR and store once 32 bytes; avoid 
        moving between WDR and GPR? */
        bn.and  w3, w1, w2            /* signs & 1 */
        bn.add  w3, w3, w3            /* 2 * (signs & 1) */
        bn.subm  w3, w2, w3            /* 1 - 2 * (signs & 1) */
        bn.sid  a6, STACK_WDR2GPR(fp) /* Store w3 to memory to move value to GPR */
        lw      t2, STACK_WDR2GPR(fp)
        sw      t2, 0(t1)             /* c->coeffs[b] = 1 - 2*(signs & 1); */

        bn.rshi w1, bn0, w1 >> 1 /* Discard the used bit: signs >>= 1 */

        addi a3, a3, 1 /* i++ */

    /* Finish the SHAKE-256 operation. */


    /* sp <- fp */
    addi sp, fp, 0

    /* Pop ebp */
    lw   fp, 0(sp)
    addi sp, sp, 32

    ret

/**
 * poly_uniform_base_dilithium
 *
 * Returns: -
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  a0: pointer to rho
 * @param[in]  a2: nonce
 * @param[out] a1: dmem pointer to polynomial
 *
 * clobbered registers: a0-a5, t0-t5, w8, s0-s3
 */
.global poly_uniform_base_dilithium
poly_uniform_base_dilithium:
    /* 32 byte align the sp */
    andi a5, sp, 31
    beq  a5, zero, _aligned
    sub  sp, sp, a5
_aligned:
    /* save fp to stack, use 32 bytes to keep it 32-byte aligned */
    addi sp, sp, -32
    sw   fp, 0(sp)

    addi fp, sp, 0
    
    /* Adjust sp to accomodate local variables */
    addi sp, sp, -64

    /* Space for tmp buffer to hold a WDR */
    #define STACK_WDR2GPR -32
    /* Space for the nonce */
    #define STACK_NONCE -64

    /* Store nonce to memory */
    sw a2, STACK_NONCE(fp)

    /* Initialize a SHAKE128 operation. */
    addi  a4, a1, 0               /* save output pointer */
    addi  a1, zero, 34
    slli  t0, a1, 5
    addi  t0, t0, SHAKE128_CFG
    csrrw zero, KECCAK_CFG_REG, t0

    /* Send the message to the Keccak core. */
    li   a1, 32                  /* set message length */
    jal  x1, keccak_send_message /* a0 already contains the input buffer */
    addi a1, zero, 2             /* set message length */
    addi a0, fp, STACK_NONCE     /* Set a0 to point to the nonce in memory */
    jal  x1, keccak_send_message

    addi a1, a4, 0 /* move output pointer back to a1 */

    /* Load Q to GPR */
    la t0, modulus
    lw a2, 0(t0)
    
    /* t0 = 1020, a1 + 1020 is the last valid address */
    addi t0, a1, 1024

    /* Load mask for coefficient */
    li t2, 0x7FFFFF

    /* WDR index */
    li a6, 3 /* Compare for flag bits */

    #define cmp_mask w9
    bn.addi cmp_mask, bn0, 3

    /* Get mask 0x7FFFFF */
    #define coeff_mask w10
    bn.addi coeff_mask, bn0, 1
    bn.rshi coeff_mask, coeff_mask, bn0 >> 233
    bn.subi coeff_mask, coeff_mask, 1

    #define cand w11

    #define mod w12
    li t3, 12
    la t1, modulus
    bn.lid t3, 0(t1)
    bn.rshi mod, bn0, mod >> 224 /* Only keep mod in lowest word */

    #define accumulator w13
    li t5, 13
    li t3, 8
    #define accumulator_count t6
    li t6, 0

    /* Loop until 256 coefficients have been written to the output */
_rej_sample_loop:
    /* First squeeze */
    .equ w8, shake_reg
    bn.wsrr  shake_reg, 0xA /* KECCAK_DIGEST */

    /* With one SHAKE squeeze, we get 32 bytes of data. From this, we can try to
       build 10 coefficients with 3 bytes each and are left with 2 bytes
       remainder. We then take the two remaining bytes and one byte from the
       next squeeze operation and try to get another coefficient, leaving us
       with 31 bytes from which we can, again, try to read 10 coefficients and
       are left with 1 byte remainder. From the next 32 bytes, we take 2 bytes
       and try to build one coefficient with the remaining 1 byte. Finally, we
       are left with 30 bytes which we can try to turn into 10 coefficients
       without any remainder. lcm(3, 32) = 96, meaning we use 96 bytes of SHAKE
       output each (full) iteration of the main loop. In case we reach the
       target amount of coefficients, we jump to _end_rej_sample_loop and exit.
       */

    /* Process floor(32 bytes / 3 bytes) * 3 bytes = 30 bytes */
    jal x1, _poly_uniform_base_inner_loop

    /* Check if we have finished in the previous loop */
    beq a1, t0, _end_rej_sample_loop

    /* Process remaining 2 bytes */

    /* Get last two bytes of shake output in shake_reg into cand */
    bn.rshi cand, shake_reg, bn0 >> 16 /* move remaining 2 bytes to the top of cand */
    /* Squeeze */
    bn.wsrr  shake_reg, 0xA /* KECCAK_DIGEST */

    /* Get one more byte from new shake data*/
    bn.rshi cand, shake_reg, cand >> 240
    /* We use only 1 byte of the 4, so shift by 8 */
    bn.or   shake_reg, bn0, shake_reg >> 8

    /* mask candidate */
    bn.and cand, coeff_mask, cand

    bn.cmp cand, mod
    csrrs  a4, 0x7C0, zero      /* Read flags */
    andi a4, a4, 3 /* Mask flags */
    bne    a4, a6, _skip_store2 /* Reject if M, C are NOT set to 1, meaning
                                    NOT (q > cand) = (q <= cand) */
    
    bn.rshi accumulator, cand, accumulator >> 32
    addi accumulator_count, accumulator_count, 1

    bne accumulator_count, t3, _skip_store2
    
    bn.or accumulator, bn0, accumulator
    bn.sid    t5, 0(a1++) /* Store to memory */
    li        accumulator_count, 0

    /* if we have written the last coefficient, exit */
    beq  a1, t0, _end_rej_sample_loop
_skip_store2:

    /* Process floor(31/3)*3 = 30 bytes */
    jal x1, _poly_uniform_base_inner_loop

    /* Check if we have finished in the previous loop */
    beq a1, t0, _end_rej_sample_loop

    /* Process remaining 1 byte */
    /* Get last two bytes of shake output in shake_reg into cand */
    bn.rshi cand, shake_reg, bn0 >> 8 /* move remaining 1 byte to the top of cand */
    /* Squeeze */
    bn.wsrr  shake_reg, 0xA /* KECCAK_DIGEST */

    /* Get one more byte from new shake data*/
    bn.rshi cand, shake_reg, cand >> 248
    /* We use only 1 byte of the 4, so shift by 8 */
    bn.or  shake_reg, bn0, shake_reg >> 16

    /* mask candidate */
    bn.and cand, coeff_mask, cand

    bn.cmp cand, mod
    csrrs a4, 0x7C0, zero /* Read flags */
    andi a4, a4, 3 /* Mask flags */
    bne  a4, a6, _skip_store4 /* Reject if M, C are NOT set to 1, meaning
                                    NOT (q > cand) = (q <= cand) */
    
    bn.rshi accumulator, cand, accumulator >> 32
    addi accumulator_count, accumulator_count, 1

    bne accumulator_count, t3, _skip_store4
    
    bn.or accumulator, bn0, accumulator
    bn.sid t5, 0(a1++) /* Store to memory */
    li accumulator_count, 0
    /* if we have written the last coefficient, exit */
    beq  a1, t0, _end_rej_sample_loop
_skip_store4:

    /* Process floor(30/3)*3 = 30 bytes */
    jal x1, _poly_uniform_base_inner_loop

    /* Check if we have finished in the previous loop */
    beq a1, t0, _end_rej_sample_loop

    /* No remainder! Start all over again. */
    beq zero, zero, _rej_sample_loop

_end_rej_sample_loop:
    /* Finish the SHAKE-128 operation. */

    /* sp <- fp */
    addi sp, fp, 0
    /* Pop ebp */
    lw fp, 0(sp)
    addi sp, sp, 32
    /* Correct alignment offset (unalign) */
    add sp, sp, a5

    ret

_poly_uniform_base_inner_loop:
    LOOPI 10, 12
        beq a1, t0, _skip_store1
        /* Mask shake output */
        /* Get the candidate coefficient */
        bn.and cand, coeff_mask, shake_reg
        
        bn.cmp cand, mod
        csrrs  a4, 0x7C0, zero /* Read flags */

        /* Z L M C */
        andi a4, a4, 3 /* Mask flags */
        bne  a4, a6, _skip_store1 /* Reject if M, C are NOT set to 1, meaning
                                     NOT (q > cand) = (q <= cand) */
        
        bn.rshi accumulator, cand, accumulator >> 32
        addi    accumulator_count, accumulator_count, 1

        bne accumulator_count, t3, _skip_store1 /* Accumulator not full yet */
        
        bn.sid    t5, 0(a1++) /* Store to memory */
        li        accumulator_count, 0
_skip_store1:
        /* Shift out the 3 bytes we have read for the next potential coefficient */
        bn.or shake_reg, bn0, shake_reg >> 24
    ret

/**
 * poly_uniform_eta_base_dilithium
 *
 * Returns: -
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]     a0: pointer to rho
 * @param[in]     a1: dmem pointer to polynomial
 * @param[in]     a2: nonce
 * @param[in]     a3: SHAKE context buffer
 *
 * clobbered registers: a1, a3-a5, w8-w15, w20, t0-t6
 */
.global poly_uniform_eta_base_dilithium
poly_uniform_eta_base_dilithium:
/* 32 byte align the sp */
    andi a5, sp, 31
    beq  a5, zero, _aligned_poly_uniform_eta_base
    sub  sp, sp, a5
_aligned_poly_uniform_eta_base:
    /* save fp to stack, use 32 bytes to keep it 32-byte aligned */
    addi sp, sp, -32
    sw   fp, 0(sp)

    addi fp, sp, 0
    
    /* Adjust sp to accomodate local variables */
    addi sp, sp, -64
    /* Space for tmp buffer to hold a WDR */
    #define STACK_WDR2GPR -32

    /* Space for the nonce */
    #define STACK_NONCE -64

    /* Store nonce to memory */
    sw a2, STACK_NONCE(fp)

    /* Initialize a SHAKE256 operation. */
    addi a4, a1, 0               /* save output pointer */

    addi  a1, zero, 66 /* len(rho) + len(nonce) */
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw zero, KECCAK_CFG_REG, t0

    /* Send the messages to the Keccak core. */
    addi a1, zero, 64            /* set rho length */
    addi a0, a0, 0
    jal  x1, keccak_send_message /* a0 already contains the input buffer */
    addi a1, zero, 2             /* set nonce length */
    addi a0, fp, STACK_NONCE     /* After rho, absorb nonce */
    jal  x1, keccak_send_message
    addi a1, a4, 0 /* move output pointer back to a1 */

    /* t0 = 1024, stop address*/
    addi t0, a1, 1024

    /* Initialize constants for WDR index */
    li t5, 9
    li t6, 10
    li t3, 20

    jal x1, _poly_uniform_eta_base_init_wdr_consts

    li a6, 2
        
    /* First squeeze */
    .equ w8, shake_reg
    
    li t6, 8
    li s4, 0
_rej_eta_base_sample_loop:    

    bn.wsrr  shake_reg, 0xA /* KECCAK_DIGEST */

LOOPI 64, 13
    beq a1, t0, _rej_eta_base_sample_loop_continue
    /* Process 4 bits */
    bn.and  w9, shake_reg, w14            /* Mask out all other bits */
    
    /* Check "t0" < {15,9} */
    bn.cmp w9, w16
    csrrs a4, 0x7C0, zero
    /* If the MSB of t0 - {15,9} is not set, we know that t0 >= {15,9}
           and thus, we have to reject. */
    and a4, a4, a6
    beq a4, zero, _rej_eta_base_sample_loop_continue

    addi t6, t6, -1

    jal x1, _poly_uniform_eta_base_arithmetic

    /* Store coefficient value from WDR into target polynomial */
    bn.rshi w20, w9, w20 >> 32

    bne t6, zero, _rej_eta_base_sample_loop_continue
    bn.sid t3, 0(a1++)
    li t6, 8
        
_rej_eta_base_sample_loop_continue:
    bn.rshi shake_reg, bn0, shake_reg >> 4 /* shift out the used nibble */
    
bne a1, t0, _rej_eta_base_sample_loop /* Continue sampling */

    /* Finish the SHAKE-256 operation. */

    /* sp <- fp */
    addi sp, fp, 0
    /* Pop ebp */
    lw   fp, 0(sp)
    addi sp, sp, 32
    /* Correct alignment offset (unalign) */
    add  sp, sp, a5

    ret

_poly_uniform_eta_base_arithmetic:
#if ETA == 2
    /* "t{0,1}" indicate the variable names from the reference code */ 
    /* Compute "t0" = "t0" - (205 * "t0" >> 10) * 5 from reference code */

    bn.mulqacc.wo.z w13, w12.0, w9.0, 0 /* 205 * "t0" */
    bn.rshi         w13, bn0, w13 >> 10 /* (205 * "t0" >> 10) */
    bn.mulqacc.wo.z w13, w0.0, w13.0, 0 /* (205 * "t0" >> 10) * 5 */
    bn.sub          w9, w9, w13         /* "t0" - (205 * "t0" >> 10) * 5 */
#endif
    bn.subm          w9, w1, w9          /* ETA - ... */
    ret

_poly_uniform_eta_base_init_wdr_consts:
    /* Initialize constants */
    bn.addi w14, bn0, 0x0F
#if ETA == 2
    bn.addi w16, bn0, 15
#elif ETA == 4
    bn.addi w16, bn0, 9
#endif
    bn.addi w12, bn0, 205
    bn.addi w0, bn0, 5
    bn.addi w1, bn0, ETA
    
    ret
/**
 * decompose_base_dilithium
 *
 * For finite field element a, compute high and low bits a0, a1 such that a
 * mod^+ Q = a1*ALPHA + a0 with -ALPHA/2 < a0 <= ALPHA/2 except if a1 =
 * (Q-1)/ALPHA where we set a1 = 0 and -ALPHA/2 <= a0 = a mod^+ Q - Q < 0.
 * Assumes a to be standard representative.
 * 
 * Returns: output element vector "a0" in w1, output element vector "a1" in w2
 *
 * @param[in] w0: input element vector
 * @param[in] w5-w11: constants in the following order: 1<<23,
 * decompose_const_base, qm1half_base_const, 43 or 15, gamma2x2_vec_base_const,
 * modulus_base, 0xFFFFFFFF
 *
 * clobbered registers: w1-w4, t0, t3-t4
 */
.global decompose_base_dilithium
decompose_base_dilithium:
    /* "a", "a{0,1}" refer to the variable names from the reference code */ 
#if GAMMA2 == (Q-1)/88
    LOOPI 8, 19
#elif GAMMA2 == (Q-1)/32
    LOOPI 8, 16
#endif
        bn.and w12, w0, w11 /* Mask 32-bit coefficient */
        bn.rshi w0, bn0, w0 >> 32 /* Discard used coefficient */

        /* Compute "a1" */
        bn.addi w3, w12, 127 /* a1  = (a + 127) */
        bn.rshi w3, bn0, w3 >> 7 /* a1  = (a + 127) >> 7 */
#if GAMMA2 == (Q-1)/88
        bn.mulqacc.wo.z w3, w3.0, w6.0, 0 /* a1*11275 */
        bn.add          w3, w3, w5        /* a1*11275 + (1 << 23) */
        bn.rshi         w3, bn0, w3 >> 24 /* (a1*11275 + (1 << 23)) >> 24 */

        bn.sub w4, w8, w3 /* (43 - a1) */
        bn.rshi w4, bn0, w4 >> 255 /* (43 - a1) >> 31) get sign bit */
        bn.mulqacc.wo.z w4, w4.0, w3.0, 0 /* ((43 - a1) >> 31) & a1 */
        bn.xor w3, w3, w4 /* a1 ^= ((43 - a1) >> 31) & a1 */
#elif GAMMA2 == (Q-1)/32
        bn.mulqacc.wo.z w3, w3.0, w6.0, 0 /* a1*1025 */
        bn.add          w3, w3, w5        /* a1*1025 + (1 << 21) */
        bn.rshi         w3, bn0, w3 >> 22 /* (a1*1025 + (1 << 21)) >> 22 */
        bn.and          w3, w3, w8        /* & 15 */
#endif
        bn.rshi w2, w3, w2 >> 32 /* Accumulate output */

        /* Compute "a0" */
        bn.mulqacc.wo.z w4, w3.0, w9.0, 0 /* a1*2*GAMMA2 */
        bn.sub w4, w12, w4 /* a - a1*2*GAMMA2 */

        bn.sub          w12, w7, w4 /* ((Q-1)/2 - *a0) */
        bn.rshi         w12, bn0, w12 >> 255 /* Get the sign bit */
        bn.mulqacc.wo.z w12, w12.0, w10.0, 0 /* Subtract Q if sign is 1 */
        bn.sub          w4, w4, w12 /* *a0 -= (((Q-1)/2 - *a0) >> 31) & Q; */

        bn.rshi w1, w4, w1 >> 32 /* Accumulate output */
    
    ret

/**
 * decompose_base_dilithium
 *
 * For finite field element a, compute high and low bits a0, a1 such that a
 * mod^+ Q = a1*ALPHA + a0 with -ALPHA/2 < a0 <= ALPHA/2 except if a1 =
 * (Q-1)/ALPHA where we set a1 = 0 and -ALPHA/2 <= a0 = a mod^+ Q - Q < 0.
 * Assumes a to be standard representative.
 * 
 * Returns: output element vector "a0" in w1, output element vector "a1" in w2
 *
 * @param[in] w0: input element vector
 * @param[in] w5-w11: constants in the following order: 1<<23,
 * decompose_const_base, qm1half_base_const, 43 or 15, gamma2x2_vec_base_const,
 * modulus_base, 0xFFFFFFFF
 *
 * clobbered registers: w1-w4, t0, t3-t4
 */
.global decompose_unsigned_base_dilithium
decompose_unsigned_base_dilithium:
    /* "a", "a{0,1}" refer to the variable names from the reference code */ 
#if GAMMA2 == (Q-1)/88
    LOOPI 8, 19
#elif GAMMA2 == (Q-1)/32
    LOOPI 8, 16
#endif
        bn.and w12, w0, w11 /* Mask 32-bit coefficient */
        bn.rshi w0, bn0, w0 >> 32 /* Discard used coefficient */

        /* Compute "a1" */
        bn.addi w3, w12, 127 /* a1  = (a + 127) */
        bn.rshi w3, bn0, w3 >> 7 /* a1  = (a + 127) >> 7 */
#if GAMMA2 == (Q-1)/88
        bn.mulqacc.wo.z w3, w3.0, w6.0, 0 /* a1*11275 */
        bn.add          w3, w3, w5        /* a1*11275 + (1 << 23) */
        bn.rshi         w3, bn0, w3 >> 24 /* (a1*11275 + (1 << 23)) >> 24 */

        bn.sub w4, w8, w3 /* (43 - a1) */
        bn.rshi w4, bn0, w4 >> 255 /* (43 - a1) >> 31) get sign bit */
        bn.mulqacc.wo.z w4, w4.0, w3.0, 0 /* ((43 - a1) >> 31) & a1 */
        bn.xor w3, w3, w4 /* a1 ^= ((43 - a1) >> 31) & a1 */
#elif GAMMA2 == (Q-1)/32
        bn.mulqacc.wo.z w3, w3.0, w6.0, 0 /* a1*1025 */
        bn.add          w3, w3, w5        /* a1*1025 + (1 << 21) */
        bn.rshi         w3, bn0, w3 >> 22 /* (a1*1025 + (1 << 21)) >> 22 */
        bn.and          w3, w3, w8        /* & 15 */
#endif
        bn.rshi w2, w3, w2 >> 32 /* Accumulate output */

        /* Compute "a0" */
        bn.mulqacc.wo.z w4, w3.0, w9.0, 0 /* a1*2*GAMMA2 */
        bn.subm w4, w12, w4 /* a - a1*2*GAMMA2 */

        bn.subm          w12, w7, w4 /* ((Q-1)/2 - *a0) */
        bn.rshi         w12, bn0, w12 >> 255 /* Get the sign bit */
        bn.mulqacc.wo.z w12, w12.0, w10.0, 0 /* Subtract Q if sign is 1 */
        bn.sub          w4, w4, w12 /* *a0 -= (((Q-1)/2 - *a0) >> 31) & Q; */

        bn.rshi w1, w4, w1 >> 32 /* Accumulate output */
    
    ret

/**
 * poly_use_hint_dilithium
 *
 * Use hint polynomial to correct the high bits of a polynomial.
 * 
 * Returns: 
 *
 * Flags: -
 *
 * @param[in]     a0: output poly pointer
 * @param[out]    a1: input poly pointer
 * @param[out]    a2: input hint poly pointer
 *
 * clobbered registers: a0-a5, t0-t6, w0-w11
 */
.global poly_use_hint_dilithium
poly_use_hint_dilithium:
    /* save fp to stack */
    addi sp, sp, -32
    sw fp, 0(sp)

    addi fp, sp, 0
    
    /* Adjust sp to accomodate local variables */
    addi sp, sp, -64

    /* Reserve space for tmp buffer to hold a WDR */
    #define STACK_WDR2GPR1 -32
    #define STACK_WDR2GPR2 -64
    addi a3, a0, 1024 /* overall stop address */

    /* Constants */
    li a4, 43
    li a5, 1
    li a6, 2

    /* WDR constants for decompose */
    /* w5 <= 1<<23 or 1<<21 */
    bn.addi w5, bn0, 1
#if GAMMA2 == (Q-1)/88
    bn.rshi w5, w5, bn0 >> 233
#elif GAMMA2 == (Q-1)/32
    bn.rshi w5, w5, bn0 >> 235
#endif

    la t0, decompose_const_base
    li t1, 6
    /* w6 <= decompose_const_base */
    bn.lid t1, 0(t0)

    la t0, qm1half_base_const
    li t1, 7
    /* w7 <= qm1half_base_const */
    bn.lid t1, 0(t0)

    /* w8 <= decompose_43_const or decompose_15_const */
#if GAMMA2 == (Q-1)/88
    bn.addi w8, bn0, 43
#elif GAMMA2 == (Q-1)/32
    bn.addi w8, bn0, 15
#endif

    la t0, gamma2x2_vec_base_const
    li t1, 9
    /* w9 <= gamma2x2_vec_base_const */
    bn.lid t1, 0(t0)

    la t0, modulus_base
    li t1, 10
    /* w10 <= modulus_base */
    bn.lid t1, 0(t0)

    /* w11 <= 0xFFFFFFFF */
    bn.addi w11, bn0, 1
    bn.rshi w11, w11, bn0 >> 224
    bn.subi w11, w11, 1 

    li t0, 0
    
    addi t4, a0, 32 /* stop address */
#if GAMMA2 == (Q-1)/88
LOOPI 32, 32
#elif GAMMA2 == (Q-1)/32
LOOPI 32, 28
#endif
    /* decompose */
    bn.lid t0, 0(a1++)
    jal x1, decompose_base_dilithium


    /* Store result form decomposition do dmem */
    bn.sid a5, STACK_WDR2GPR1(fp)
    bn.sid a6, STACK_WDR2GPR2(fp)

    /* "a{0,1}" refers to the variables from the reference code */

    addi t2, fp, STACK_WDR2GPR1 /* "a0" */
    addi t3, fp, STACK_WDR2GPR2 /* "a1" */

    /* scalar part starts here */
#if GAMMA2 == (Q-1)/88
    LOOPI 8, 24
        lw  t1, 0(t3) /* Load "a1" */
        /* Check if hint is 0 */
        lw  t5, 0(a2)
        bne t5, zero, _inner_loop_skip_store1_poly_use_hint_dilithium
        sw  t1, 0(a0)
        beq zero, zero, _inner_loop_end_poly_use_hint_dilithium
_inner_loop_skip_store1_poly_use_hint_dilithium:
        /* if(0 < "a0") */
        lw t5, 0(t2)
        sub t5, zero, t5
        srli t5, t5, 31
        bne t5, a5, _inner_loop_else_poly_use_hint_dilithium /* go to else-branch */
        /* if("a1" == 43) */
        bne t1, a4, _inner_loop_aplus1_poly_use_hint_dilithium /* go to else-branch */
        sw zero, 0(a0) /* return 0 */
        beq zero, zero, _inner_loop_end_poly_use_hint_dilithium /* go to iteration end */
_inner_loop_aplus1_poly_use_hint_dilithium:
        /* if("a1" == 43) else-branch */
        /* Store "a1" + 1 */
        addi t1, t1, 1
        sw t1, 0(a0)
        beq zero, zero, _inner_loop_end_poly_use_hint_dilithium /* unconditional */
_inner_loop_else_poly_use_hint_dilithium:
        /* if(0 < "a0") else-branch */
        /* if("a1" == 0) */
        bne t1, zero, _inner_loop_aminus1_poly_use_hint_dilithium /* go to else-branch */
        /* Store 43 */
        sw a4, 0(a0)
        beq zero, zero, _inner_loop_end_poly_use_hint_dilithium
_inner_loop_aminus1_poly_use_hint_dilithium:
        /* if("a1" == 0) else-branch */
        /* Store "a1" - 1 */
        addi t1, t1, -1
        sw t1, 0(a0)
_inner_loop_end_poly_use_hint_dilithium:
        addi t3, t3, 4 /* increment "a1" pointer */
        addi a0, a0, 4 /* increment output */
        addi t2, t2, 4 /* increment "a0" pointer */
        addi a2, a2, 4 /* increment *hint */
        
    addi t4, a0, 32             /* stop address */
    /* LOOP END */
#elif GAMMA2 == (Q-1)/32
    LOOPI 8, 20
        lw  t1, 0(t3) /* Load "a1" */
        /* Check if hint is 0 */
        lw  t5, 0(a2)
        bne t5, zero, _inner_loop_skip_store1_poly_use_hint_dilithium
        sw  t1, 0(a0)
        beq zero, zero, _inner_loop_end_poly_use_hint_dilithium
_inner_loop_skip_store1_poly_use_hint_dilithium:
        /* if(0 < "a0") */
        lw t5, 0(t2)
        sub t5, zero, t5
        srli t5, t5, 31
        bne t5, a5, _inner_loop_else_poly_use_hint_dilithium /* go to else-branch */

        /* if-branch */
        addi t1, t1, 1
        andi t1, t1, 15
        sw t1, 0(a0)
        beq zero, zero, _inner_loop_end_poly_use_hint_dilithium

_inner_loop_else_poly_use_hint_dilithium:
        /* else-branch */
        addi t1, t1, -1
        andi t1, t1, 15
        sw t1, 0(a0)
_inner_loop_end_poly_use_hint_dilithium:
        addi t3, t3, 4 /* increment "a1" pointer */
        addi a0, a0, 4 /* increment output */
        addi t2, t2, 4 /* increment "a0" pointer */
        addi a2, a2, 4 /* increment *hint */
        /* LOOP END */
#endif

    /* sp <- fp */
    addi sp, fp, 0
    /* Pop ebp */
    lw fp, 0(sp)
    addi sp, sp, 32
    ret

/**
 * polyt1_pack_dilithium
 *
 * Bit-pack polynomial t1 with coefficients fitting in 10 bits. Input
 * coefficients are assumed to be standard representatives.
 *
 * Flags: -
 *
 * @param[out] a0: pointer to output byte array with at least
                   POLYT1_PACKEDBYTES bytes
 * @param[in]  a1: pointer to input polynomial
 *
 * clobbered registers: a0-a1, t0-t2
 */
.global polyt1_pack_dilithium
polyt1_pack_dilithium:
    li t1, 1
    li t4, 4
    
    jal     x1, _inner_polyt1_pack_dilithium
    bn.rshi w4, w2, w4 >> 160


    jal     x1, _inner_polyt1_pack_dilithium
    bn.rshi w4, w2, w4 >> 96
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 160


    jal     x1, _inner_polyt1_pack_dilithium
    bn.rshi w4, w2, w4 >> 160


    jal     x1, _inner_polyt1_pack_dilithium
    bn.rshi w4, w2, w4 >> 32
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 160


    jal     x1, _inner_polyt1_pack_dilithium
    bn.rshi w4, w2, w4 >> 128
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 160


    jal     x1, _inner_polyt1_pack_dilithium
    bn.rshi w4, w2, w4 >> 160


    jal     x1, _inner_polyt1_pack_dilithium
    bn.rshi w4, w2, w4 >> 64
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 160


    jal     x1, _inner_polyt1_pack_dilithium
    bn.rshi w4, w2, w4 >> 160
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 0


    jal     x1, _inner_polyt1_pack_dilithium
    bn.rshi w4, w2, w4 >> 160


    jal     x1, _inner_polyt1_pack_dilithium
    bn.rshi w4, w2, w4 >> 96
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 160


    jal     x1, _inner_polyt1_pack_dilithium
    bn.rshi w4, w2, w4 >> 160


    jal     x1, _inner_polyt1_pack_dilithium
    bn.rshi w4, w2, w4 >> 32
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 160


    jal     x1, _inner_polyt1_pack_dilithium
    bn.rshi w4, w2, w4 >> 128
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 160


    jal     x1, _inner_polyt1_pack_dilithium
    bn.rshi w4, w2, w4 >> 160


    jal     x1, _inner_polyt1_pack_dilithium
    bn.rshi w4, w2, w4 >> 64
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 160


    jal     x1, _inner_polyt1_pack_dilithium
    bn.rshi w4, w2, w4 >> 160
    bn.sid  t4, 0(a0++)

    ret

_inner_polyt1_pack_dilithium:
    LOOPI 2, 17
        bn.lid t1, 0(a1++)
        .rept 8
            bn.rshi w2, w1, w2 >> 10 /* Write one coefficient into the output WDR */
            bn.rshi w1, bn0, w1 >> 32 /* Shift out used coefficient */
        .endr
    bn.rshi w2, bn0, w2 >> 96 /* Shift the 160 bits of data to the bottom of the 
                                 WDR */
    ret


/**
 * polyeta_pack_dilithium
 *
 * Bit-pack polynomial with coefficients in [-ETA,ETA].
 * 
 * Returns: -
 *
 * Flags: -
 *
 * @param[out] a0: pointer to output byte array with at least
                   POLYETA_PACKEDBYTES bytes
 * @param[in]  a1: pointer to input polynomial
 *
 * clobbered registers: a0-a1, t0-t3, w1, w2
 */
.global polyeta_pack_dilithium
polyeta_pack_dilithium:
#if ETA == 2
    /* Load mask */
    bn.addi w20, bn0, 1
    bn.or   w20, bn0, w20 << 32
    bn.subi w20, w20, 1

    /* Compute ETA - coeff */
    /* Setup WDRs */
    li t1, 1
    li t2, 2
    li t3, 3
    li t4, 4

    /* Load precomputed, vectorized eta */
    la t0, eta_vec_base_const
    bn.lid t3, 0(t0)

    /* Load coefficient mask */
    bn.addi w5, bn0, 7

    jal     x1, _inner_polyeta_pack_dilithium
    bn.rshi w4, w2, w4 >> 192


    jal     x1, _inner_polyeta_pack_dilithium
    bn.rshi w4, w2, w4 >> 64
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 192


    jal     x1, _inner_polyeta_pack_dilithium
    bn.rshi w4, w2, w4 >> 128
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 192


    jal     x1, _inner_polyeta_pack_dilithium
    bn.rshi w4, w2, w4 >> 192
    bn.sid  t4, 0(a0++)

    ret


/**
 * _inner_polyeta_pack_dilithium
 *
 * Inner part of packing function to reduce the code size. Could be inlined.
 * Do not call from anywhere but polyeta_pack_dilithium.
 * Does not adhere to calling convention.
 */
_inner_polyeta_pack_dilithium:
    LOOPI 8, 33
        bn.lid t1, 0(a1++)
        .rept 8
            /* Mask */
            bn.and w7, w1, w20
            /* Subtract coefficient from eta */
            bn.subm w7, w3, w7
            /* Move coefficient into the output register */
            bn.rshi w2, w7, w2 >> 3
            /* Shift out used coefficient */
            bn.rshi w1, bn0, w1 >> 32 
        .endr
    bn.rshi w2, bn0, w2 >> 64 /* Shift the 208 bits of data to the bottom of the 
                                 WDR */
    ret
#else
/* Load mask */
    bn.addi w20, bn0, 1
    bn.or   w20, bn0, w20 << 32
    bn.subi w20, w20, 1

    /* Compute ETA - coeff */
    /* Setup WDRs */
    li t1, 1
    li t2, 2
    li t3, 3

    /* Load precomputed, vectorized eta */
    la t0, eta_vec_base_const
    bn.lid t3, 0(t0)

    /* Load coefficient mask */
    bn.addi w5, bn0, 7

    jal     x1, _inner_polyeta_pack_dilithium
    bn.sid  t2, 0(a0++)
    jal     x1, _inner_polyeta_pack_dilithium
    bn.sid  t2, 0(a0++)
    jal     x1, _inner_polyeta_pack_dilithium
    bn.sid  t2, 0(a0++)
    jal     x1, _inner_polyeta_pack_dilithium
    bn.sid  t2, 0(a0++)

    ret


/**
 * _inner_polyeta_pack_dilithium
 *
 * Inner part of packing function to reduce the code size. Could be inlined.
 * Do not call from anywhere but polyeta_pack_dilithium.
 * Does not adhere to calling convention.
 */
_inner_polyeta_pack_dilithium:
    LOOPI 8, 33
        bn.lid t1, 0(a1++)
        .rept 8
            /* Mask */
            bn.and w7, w1, w20
            /* Subtract coefficient from eta */
            bn.subm w7, w3, w7
            /* Move coefficient into the output register */
            bn.rshi w2, w7, w2 >> 4
            /* Shift out used coefficient */
            bn.rshi w1, bn0, w1 >> 32 
        .endr
    ret
#endif
/**
 * polyt0_pack_base_dilithium
 *
 * Bit-pack polynomial t0 with coefficients in ]-2^{D-1}, 2^{D-1}].
 * 
 * Flags: -
 *
 * @param[out] a0: pointer to output byte array with at least
                   POLYETA_PACKEDBYTES bytes
 * @param[in]  a1: pointer to input polynomial
 *
 * clobbered registers: a0-a1, t0-t3, w1, w2
 */
.global polyt0_pack_base_dilithium
polyt0_pack_base_dilithium:
    /* Setup WDRs */
    li t1, 1
    li t2, 2
    li t3, 3
    li t4, 4

    /* Load precomputed (1 << (D-1)) */
    la     t0, polyt0_pack_base_const
    bn.lid t3, 0(t0)

    /* Load coefficient mask */
    bn.addi w5, bn0, 1
    bn.rshi w5, w5, bn0 >> 243
    bn.subi w5, w5, 1
    
    /* Start packing */
    jal     x1, _inner_polyt0_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 208

    jal     x1, _inner_polyt0_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 48 /* Fill up accumulator register to be 256 bits */
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 208 /* Initialize the accumulator register again,
                                  shifting 48 bits more than the rest in the
                                  register actually is to discard the bits used
                                  to fill the accumulator before the store */

    jal     x1, _inner_polyt0_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 96
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 208

    jal     x1, _inner_polyt0_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 208

    jal     x1, _inner_polyt0_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 192
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 208

    jal     x1, _inner_polyt0_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 208

    jal     x1, _inner_polyt0_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 32
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 208

    jal     x1, _inner_polyt0_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 80
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 208

    jal     x1, _inner_polyt0_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 128
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 208

    jal     x1, _inner_polyt0_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 176
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 208

    jal     x1, _inner_polyt0_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 208

    jal     x1, _inner_polyt0_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 16
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 208

    jal     x1, _inner_polyt0_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 64
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 208

    jal     x1, _inner_polyt0_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 112
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 208

    jal     x1, _inner_polyt0_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 160
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 208

    jal     x1, _inner_polyt0_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 208
    bn.sid  t4, 0(a0++)
    
    ret

_inner_polyt0_pack_base_dilithium:
    LOOPI 2, 33
        bn.lid t1, 0(a1++)
        .rept 8
            /* Mask coefficient */
            bn.and w7, w1, w5
            /* Subtract from constant */ 
            bn.sub w7, w3, w7
            /* Move coefficient into the output register */
            bn.rshi w2, w7, w2 >> 13
            /* Shift out used coefficient */
            bn.rshi w1, bn0, w1 >> 32 
        .endr
    bn.rshi w2, bn0, w2 >> 48 /* Shift the 208 bits of data to the bottom of the 
                                 WDR */
    ret

/**
 * polyw1_pack_dilithium
 *
 * Bit-pack polynomial w1 with coefficients fitting in 6 bits. Input
 * coefficients are assumed to be standard representatives.
 * 
 * Flags: -
 *
 * @param[out] a0: pointer to output byte array with at least
                   POLYW1_PACKEDBYTES bytes
 * @param[in]  a1: pointer to input polynomial
 *
 * clobbered registers: a0-a1, t0-t2
 */
.global polyw1_pack_dilithium
polyw1_pack_dilithium:

    /* Setup WDRs */
    li t1, 1
    li t2, 2
    li t4, 4
#if GAMMA2 == (Q-1)/88
    LOOPI 2, 13
        jal     x1, _inner_polyw1_pack_dilithium
        bn.rshi w4, w2, w4 >> 192


        jal     x1, _inner_polyw1_pack_dilithium
        bn.rshi w4, w2, w4 >> 64
        bn.sid  t4, 0(a0++)
        bn.rshi w4, w2, bn0 >> 192


        jal     x1, _inner_polyw1_pack_dilithium
        bn.rshi w4, w2, w4 >> 128
        bn.sid  t4, 0(a0++)
        bn.rshi w4, w2, bn0 >> 192


        jal     x1, _inner_polyw1_pack_dilithium
        bn.rshi w4, w2, w4 >> 192
        bn.sid  t4, 0(a0++)

    ret

_inner_polyw1_pack_dilithium:
    LOOPI 4, 17
        bn.lid t1, 0(a1++)
        .rept 8
            bn.rshi w2, w1, w2 >> 6 /* Write one coefficient into the output WDR */
            bn.rshi w1, bn0, w1 >> 32 /* Shift out used coefficient */
        .endr
    bn.rshi w2, bn0, w2 >> 64 /* Shift the 192 bits of data to the bottom of the 
                                 WDR */
    ret
#elif GAMMA2 == (Q-1)/32
    LOOPI 4, 2
        jal     x1, _inner_polyw1_pack_dilithium
        bn.sid t2, 0(a0++)

    ret

_inner_polyw1_pack_dilithium:
    LOOPI 8, 17
        bn.lid t1, 0(a1++)
        .rept 8
            bn.rshi w2, w1, w2 >> 4 /* Write one coefficient into the output WDR */
            bn.rshi w1, bn0, w1 >> 32 /* Shift out used coefficient */
        .endr
    ret
#endif
/**
 * polyeta_unpack_base_dilithium
 *
 * Unpack polynomial with coefficients fitting in [-ETA, ETA]. 
 *
 * Flags: -
 *
 * @param[in]  a1: byte array with bit-packed polynomial
 * @param[out] a0: pointer to output polynomial
 *
 * clobbered registers: a0-a1, t0-t2, w1-w2
 */

.global polyeta_unpack_base_dilithium
polyeta_unpack_base_dilithium:
#if ETA == 2
    /* Setup WDR */ 
    li t1, 1
    li t2, 2
    li t3, 3
    li t4, 4
    li t5, 5

    /* Load precomputed, vectorized eta */
    la t0, eta_vec_base_const
    bn.lid t4, 0(t0)
    /* Load mask for zeroing the upper bits of the unpacked coefficients. */
    bn.addi w5, bn0, 7
    li t6, 6
    
    /* Start unpacking */
    bn.lid t1, 0(a1++)
    jal    x1, _inner_polyeta_unpack_base_dilithium

    /* Current state: w1 = |0|0|0|w1.3 */
    bn.lid t6, 0(a1++)      /* Load new WLEN word to w2 */
    bn.or  w1, w1, w6 << 64 /* w1 = |w6.2|w6.1|w6.0|w1.3| */
    jal    x1, _inner_polyeta_unpack_base_dilithium /* 64-bit rest in w0.0 */

    /* Current state: w1 = |0|0|0|w6.2 */
    bn.lid  t3, 0(a1++)       /* Load new WLEN word to w3 */
    bn.rshi w1, w3, w6 >> 128 /* w1 = |w3.1|w3.0|w6.3|w6.2 */
    jal     x1, _inner_polyeta_unpack_base_dilithium

    /* w1 = |0|w3.3|w3.2|w3.1 */
    bn.rshi w1, bn0, w3 >> 64
    jal     x1, _inner_polyeta_unpack_base_dilithium

    ret

/**
 * inner_polyeta_unpack_base_dilithium
 *
 * Inner part of unpacking function to reduce the code size.
 * Do not call from anywhere but polyeta_unpack_base_dilithium.
 * Does not adhere to calling convention.
 */
_inner_polyeta_unpack_base_dilithium:
    /* Unpack 64 coefficients in one go */
    LOOPI 8, 33
        /* This could also be done by a loop */
        .rept 8
            /* Mask */
            bn.and w7, w1, w5
            /* Subtract coefficient from eta */
            bn.subm w7, w4, w7
            /* Move coefficient into the output register */
            bn.rshi w2, w7, w2 >> 32
            /* Advance the input register such that the next coefficient is
                in the lower 3 bits */
            bn.rshi w1, bn0, w1 >> 3
        .endr

        bn.sid t2, 0(a0++)
    ret
#elif ETA == 4
    /* Setup WDR */ 
    li t1, 1
    li t2, 2
    li t3, 3
    li t4, 4
    li t5, 5

    /* Load precomputed, vectorized eta */
    la t0, eta_vec_base_const
    bn.lid t4, 0(t0)
    /* Load mask for zeroing the upper bits of the unpacked coefficients. */
    bn.addi w5, bn0, 0x0f
    li t6, 6
    
    /* Start unpacking */
    bn.lid t1, 0(a1++)
    jal    x1, _inner_polyeta_unpack_base_dilithium

    bn.lid t1, 0(a1++)
    jal    x1, _inner_polyeta_unpack_base_dilithium

    bn.lid  t1, 0(a1++)
    jal     x1, _inner_polyeta_unpack_base_dilithium

    bn.lid  t1, 0(a1++)
    jal     x1, _inner_polyeta_unpack_base_dilithium

    ret
/**
 * inner_polyeta_unpack_base_dilithium
 *
 * Inner part of unpacking function to reduce the code size.
 * Do not call from anywhere but polyeta_unpack_base_dilithium.
 * Does not adhere to calling convention.
 */
_inner_polyeta_unpack_base_dilithium:
    /* Unpack 64 coefficients in one go */
    LOOPI 8, 33
        /* This could also be done by a loop */
        .rept 8
            /* Mask */
            bn.and w7, w1, w5
            /* Subtract coefficient from eta */
            bn.subm w7, w4, w7
            /* Move coefficient into the output register */
            bn.rshi w2, w7, w2 >> 32
            /* Advance the input register such that the next coefficient is
                in the lower 3 bits */
            bn.rshi w1, bn0, w1 >> 4
        .endr

        bn.sid t2, 0(a0++)
    ret
#endif


/**
 * polyvec_decode_h_dilithium
 *
 * Decode h from signature into polyvec h. Check extra indices. 
 *
 * Flags: -
 *
 * @param[in]  a1: pointer to input byte array signature
 * @param[out] a0: pointer to output polynomial h
 *
 * clobbered registers: a0-a7, t0-t6
 */
.global polyvec_decode_h_dilithium
polyvec_decode_h_dilithium:
    /* Initialize h to zero */
    add t1, zero, a0
    li t0, 31
    LOOPI 32, 1
        bn.sid t0, 0(t1++)
    
    li t0, 0 /* "k" = 0 */
    li t1, 0 /* "i" = 0 */
    /* Initialize constants */ 
    li t4, OMEGA
    li a2, 0xFFFFFFFC
    li a7, 1

    /* The notation inside the comments goes in line with the reference code */
_loop_decode_h_dilithium:
    /* Load sig[OMEGA + i] to t2 */
    addi t2, t1, OMEGA /* i + OMEGA */
    add  t6, t2, a1    /* (sig + OMEGA + i) */
    andi  a4, t6, 0x3   /* get lower two bits */
    and  t6, t6, a2    /* set lowest two bits to 0 */
    lw   t6, 0(t6)     /* aligned load */
    slli a4, a4, 3
    srl  t6, t6, a4    /* extract the respective byte */
    andi t2, t6, 0xFF

    /* Note: sig, k, OMEGA are all unsigned. Can also compare by subtracting and
       checking the MSB */
    /* sig[OMEGA + i] <? k  */
    sub t3, t2, t0
    srli t3, t3, 31
    bne t3, zero, _ret1_decode_h_dilithium
    /* || sig[OMEGA + i] >? OMEGA */
    sub t3, t4, t2
    srli t3, t3, 31
    bne t3, zero, _ret1_decode_h_dilithium

    addi t5, t0, 0 /* j = k */
    /* in case j=k == sig[OMEGA+i], we're done */
    beq t2, t0, _loop_inner_skip_decode_h_dilithium
    
    /* Do first iteration separately */
    /* Load sig[j] */
    add  t6, t5, a1   /* (sig + j) */
    andi a4, t6, 0x3  /* get lower two bits */
    and  t6, t6, a2   /* set lowest two bits to 0 */
    lw   t6, 0(t6)    /* aligned load */
    slli a4, a4, 3
    srl  t6, t6, a4   /* extract the respective byte */
    andi a6, t6, 0xFF /* a6 = sig[j] */

    /* Store a 1 to h */ 
    slli a4, a6, 2  /* sig[j] * 4 */
    add  t6, a0, a4 /* (h[sig[j]]) */
    sw   a7, 0(t6)  /* h->vec[i].coeffs[sig[j]] = a7 = 1 */

    /* Skip the loop if we are already done here */
    addi t5, t5, 1
    beq t5, t2, _loop_inner_skip_decode_h_dilithium
_loop_inner_decode_h_dilithium:
        /* NOTE: Can be done more efficiently, probably dont need to compute
                 this every iteration */
        /* Load sig[j] */
        add  a5, t5, a1  /* (sig + j) */
        andi a4, a5, 0x3 /* get lower two bits */
        and  t6, a5, a2  /* set lowest two bits to 0 */
        lw   a3, 0(t6)   /* aligned load */
        slli a4, a4, 3
        srl  a3, a3, a4  /* extract the respective byte */
        andi a3, a3, 0xFF

        /* sig[j - 1] is in a6 at this point */

        /* sig[j] ==? sig[j-1] */
        beq  a3, a6, _ret1_decode_h_dilithium
        sub t6, a3, a6
        srli t6, t6, 31

        /* sig[j] <? sig[j-1] */
        li  a4, 1
        beq t6, a4, _ret1_decode_h_dilithium


        slli a4, a3, 2  /* sig[j] * 4 */
        add  t6, a0, a4 /* (h[sig[j]]) */
        sw   a7, 0(t6)  /* h->vec[i].coeffs[sig[j]] = 1 */

        
        addi a6, a3, 0 /* set sig[j - 1] from sig[j] */
        addi t5, t5, 1 /* j++ */

        /* j != sig[OMEGA + i] */
        bne t5, t2, _loop_inner_decode_h_dilithium
_loop_inner_skip_decode_h_dilithium:

    addi t0, t2, 0    /* k = sig[OMEGA + i]; */
    addi t1, t1, 1    /* i++ */
    addi a0, a0, 1024 /* Go to next poly in h */
    li   t5, K

    /* i <? 4 (K = 4): Check if all polynomials are done */
    bne t1, t5, _loop_decode_h_dilithium

    /* Extra indices zero  */
    addi t5, t0, 0 /* j = k */
    beq  t5, t4, _ret0_decode_h_dilithium
_loop_extra_decode_h_dilithium:
    /* Load sig[j] */
    add  t6, t5, a1   /* (sig + j) */
    andi  a4, t6, 0x3  /* get lower two bits */
    and  t6, t6, a2   /* set lowest two bits to 0 */
    lw   t6, 0(t6)    /* aligned load */
    slli a4, a4, 3
    srl  t6, t6, a4   /* extract the respective byte */
    andi a6, t6, 0xFF /* a6 = sig[j] */

    /* if(sig[j]) return 1; */
    bne a6, zero, _ret1_decode_h_dilithium

    addi t5, t5, 1 /* j++ */
    bne  t5, t4, _loop_extra_decode_h_dilithium

_ret0_decode_h_dilithium:
    li a0, 0
    ret

_ret1_decode_h_dilithium:
    li a0, 1
    ret

/**
 * polyt0_unpack_dilithium
 *
 * Bit-unpack polynomial t0 with coefficients in ]-2^{D-1}, 2^{D-1}].
 *
 * Flags: -
 *
 * @param[out] a0: pointer to output byte array with at least
                   POLYETA_PACKEDBYTES bytes
 * @param[in]  a1: pointer to input polynomial
 *
 * clobbered registers: a0-a1, t2, t3, t5, t6, w1-w2
 */
.global polyt0_unpack_base_dilithium
polyt0_unpack_base_dilithium:

    li t4, 4
    /* Load precomputed (1 << (D-1)) */
    la     t0, polyt0_pack_base_const
    bn.lid t4, 0(t0)

    /* Load coefficient mask for 13-bit coefficients 0x1fff */
    bn.addi w5, bn0, 1
    bn.rshi w5, w5, bn0 >> 243
    bn.subi w5, w5, 1

    /* Setup WDR */ 
    li t2, 2
    li t3, 3
    li t6, 6

    bn.lid  t6, 0(a1++)
    bn.mov  w1, w6
    jal     x1, _inner_polyt0_unpack_base_dilithium

    bn.lid  t3, 0(a1++)
    bn.rshi w1, w3, w6 >> 208
    jal     x1, _inner_polyt0_unpack_base_dilithium

    bn.lid  t6, 0(a1++)
    bn.rshi w1, w6, w3 >> 160
    jal     x1, _inner_polyt0_unpack_base_dilithium

    bn.lid  t3, 0(a1++)
    bn.rshi w1, w3, w6 >> 112
    jal     x1, _inner_polyt0_unpack_base_dilithium

    bn.lid  t6, 0(a1++)
    bn.rshi w1, w6, w3 >> 64
    jal     x1, _inner_polyt0_unpack_base_dilithium

    bn.rshi w1, bn0, w6 >> 16
    jal     x1, _inner_polyt0_unpack_base_dilithium

    bn.lid  t3, 0(a1++)
    bn.rshi w1, w3, w6 >> 224
    jal     x1, _inner_polyt0_unpack_base_dilithium

    bn.lid  t6, 0(a1++)
    bn.rshi w1, w6, w3 >> 176
    jal     x1, _inner_polyt0_unpack_base_dilithium

    bn.lid  t3, 0(a1++)
    bn.rshi w1, w3, w6 >> 128
    jal     x1, _inner_polyt0_unpack_base_dilithium

    bn.lid  t6, 0(a1++)
    bn.rshi w1, w6, w3 >> 80
    jal     x1, _inner_polyt0_unpack_base_dilithium

    bn.rshi w1, bn0, w6 >> 32
    jal     x1, _inner_polyt0_unpack_base_dilithium

    bn.lid  t3, 0(a1++)
    bn.rshi w1, w3, w6 >> 240
    jal     x1, _inner_polyt0_unpack_base_dilithium

    bn.lid  t6, 0(a1++)
    bn.rshi w1, w6, w3 >> 192
    jal     x1, _inner_polyt0_unpack_base_dilithium

    bn.lid  t3, 0(a1++)
    bn.rshi w1, w3, w6 >> 144
    jal     x1, _inner_polyt0_unpack_base_dilithium

    bn.lid  t6, 0(a1++)
    bn.rshi w1, w6, w3 >> 96
    jal     x1, _inner_polyt0_unpack_base_dilithium

    bn.rshi w1, bn0, w6 >> 48
    jal     x1, _inner_polyt0_unpack_base_dilithium

    ret

/**
 * _inner_polyt0_unpack_base_dilithium
 *
 * Inner part of unpacking function to reduce the code size.
 * Do not call from anywhere but polyt0_unpack_dilithium.
 * Does not adhere to calling convention.
 */
_inner_polyt0_unpack_base_dilithium:
    /* Unpack 16 coefficients in one go */
    LOOPI 2, 33
        /* This could also be done by a loop */
        .rept 8
            /* Mask */
            bn.and w7, w1, w5
            /* Subtract coefficient from eta */
            bn.subm w7, w4, w7
            /* Move coefficient into the output register */
            bn.rshi w2, w7, w2 >> 32
            /* Advance the input register such that the next coefficient is
                in the lower 13 bits */
            bn.rshi w1, bn0, w1 >> 13
        .endr
        
        bn.sid     t2, 0(a0++)
    ret

/**
 * poly_uniform_gamma1_base_dilithium
 *
 *  Sample polynomial with uniformly random coefficients in [-(GAMMA1 - 1),
 *  GAMMA1] by unpacking output stream of SHAKE256(seed|nonce).
 *
 * Flags: -
 *
 * @param[out] a0: pointer to output polynomial
 * @param[in]  a1: byte array with seed of length CRHBYTES
 * @param[in]  a2: nonce
 * @param[in]  a3: pointer to gamma1_vec_const
 *
 * clobbered registers: a0, a4, t0-t6, w1-w2, w3, w6, w8
 */
.global poly_uniform_gamma1_base_dilithium
poly_uniform_gamma1_base_dilithium:
#if GAMMA1 == (1 << 17)
    /* save fp to stack */
    addi sp, sp, -32
    sw fp, 0(sp)

    addi fp, sp, 0
    
    /* Adjust sp to accomodate local variables */
    addi sp, sp, -32

    /* Reserve space for tmp buffer to hold a WDR */
    #define STACK_WDR2GPR -32

    push a0
    push a1

    /* Initialize a SHAKE256 operation. */
    addi a0, a1, 0    /* save a0 <= seed address */

    addi  a1, zero, CRHBYTES
    addi  a1, a1, 2
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw zero, KECCAK_CFG_REG, t0

    /* Send the seed to the Keccak core. */
    /* a0 already set above */
    li   a1, CRHBYTES /* a1 <= CRHBYTES */
    jal  x1, keccak_send_message

    /* Send the nonce to the Keccak core. */
    sw   a2, STACK_WDR2GPR(fp)
    addi a0, fp, STACK_WDR2GPR /* a0 <= *STACK_WDR2GPR = *nonce*/
    li   a1, 2 /* a1 <= 2 */
    jal  x1, keccak_send_message

    pop a1
    pop a0

    /* Load gamma1 as a vector into w4 */
    li t2, 4
    la t3, gamma1_vec_base_const
    bn.lid t2, 0(t3)

    /* Load mask for zeroing the upper bits of the unpacked coefficients to w5 */
    li t2, 5
    la t3, polyz_unpack_base_dilithium_mask
    bn.lid t2, 0(t3)

    /* Setup WDR */ 
    li t2, 2
    LOOPI 2, 51
        jal x1, _read_shake_poly_uniform_gamma1_base_dilithium
        bn.mov  w1, w8
        bn.mov  w6, w8
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        jal x1, _read_shake_poly_uniform_gamma1_base_dilithium
        bn.mov  w3, w8
        bn.rshi w1, w3, w6 >> 144
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        bn.rshi w1, bn0, w3 >> 32
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        jal x1, _read_shake_poly_uniform_gamma1_base_dilithium
        bn.mov  w6, w8
        bn.rshi w1, w6, w3 >> 176
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        bn.rshi w1, bn0, w6 >> 64
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        jal x1, _read_shake_poly_uniform_gamma1_base_dilithium
        bn.mov  w3, w8
        bn.rshi w1, w3, w6 >> 208
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        bn.rshi w1, bn0, w3 >> 96
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        jal x1, _read_shake_poly_uniform_gamma1_base_dilithium
        bn.mov  w6, w8
        bn.rshi w1, w6, w3 >> 240
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        jal x1, _read_shake_poly_uniform_gamma1_base_dilithium
        bn.mov  w3, w8
        bn.rshi w1, w3, w6 >> 128
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        bn.rshi w1, bn0, w3 >> 16
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        jal x1, _read_shake_poly_uniform_gamma1_base_dilithium
        bn.mov  w6, w8
        bn.rshi w1, w6, w3 >> 160
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        bn.rshi w1, bn0, w6 >> 48
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        jal x1, _read_shake_poly_uniform_gamma1_base_dilithium
        bn.mov  w3, w8
        bn.rshi w1, w3, w6 >> 192
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        bn.rshi w1, bn0, w3 >> 80
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        jal x1, _read_shake_poly_uniform_gamma1_base_dilithium
        bn.mov  w6, w8
        bn.rshi w1, w6, w3 >> 224
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        bn.rshi w1, bn0, w6 >> 112
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium
        nop /* Loop must not end on jump */

    /* Finish the SHAKE-256 operation. */

    /* sp <- fp */
    addi sp, fp, 0
    /* Pop ebp */
    lw fp, 0(sp)
    addi sp, sp, 32

    ret

_inner_poly_uniform_gamma1_base_dilithium:
    /* Unpack 8 coefficients in one go */
    .rept 8
        /* Mask */
        bn.and w7, w1, w5
        /* Subtract coefficient from eta */
        bn.subm w7, w4, w7
        /* Move coefficient into the output register */
        bn.rshi w2, w7, w2 >> 32
        /* Advance the input register such that the next coefficient is
            in the lower 18 bits */
        bn.rshi w1, bn0, w1 >> 18
    .endr
    
    bn.sid     t2, 0(a0++)
    ret
#elif GAMMA1 == (1 << 19)
/* save fp to stack */
    addi sp, sp, -32
    sw fp, 0(sp)

    addi fp, sp, 0
    
    /* Adjust sp to accomodate local variables */
    addi sp, sp, -32

    /* Reserve space for tmp buffer to hold a WDR */
    #define STACK_WDR2GPR -32

    push a0
    push a1
    
    /* Initialize a SHAKE256 operation. */
    addi a0, a1, 0    /* a0 <= seed address */

    addi  a1, zero, CRHBYTES
    addi  a1, a1, 2
    slli  t0, a1, 5
    addi  t0, t0, SHAKE256_CFG
    csrrw zero, KECCAK_CFG_REG, t0

    /* Send the seed to the Keccak core. */
    /* a0 already set above */
    li   a1, CRHBYTES /* a1 <= CRHBYTES */
    jal  x1, keccak_send_message

    /* Send the nonce to the Keccak core. */
    sw   a2, STACK_WDR2GPR(fp)
    addi a0, fp, STACK_WDR2GPR /* a0 <= *STACK_WDR2GPR = *nonce*/
    li   a1, 2 /* a1 <= 2 */
    jal  x1, keccak_send_message

    pop a1
    pop a0

    /* Load gamma1 as a vector into w4 */
    li t2, 4
    la t3, gamma1_vec_base_const
    bn.lid t2, 0(t3)

    /* Load mask for zeroing the upper bits of the unpacked coefficients to w5 */
    li t2, 5
    la t3, polyz_unpack_base_dilithium_mask
    bn.lid t2, 0(t3)

    /* Setup WDR */ 
    li t2, 2
    LOOPI 4, 27
        jal x1, _read_shake_poly_uniform_gamma1_base_dilithium
        bn.mov  w6, w8
        bn.mov  w1, w6
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        jal x1, _read_shake_poly_uniform_gamma1_base_dilithium
        bn.mov w3, w8
        bn.rshi w1, w3, w6 >> 160
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        bn.rshi w1, bn0, w3 >> 64
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        jal x1, _read_shake_poly_uniform_gamma1_base_dilithium
        bn.mov w6, w8
        bn.rshi w1, w6, w3 >> 224
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        jal x1, _read_shake_poly_uniform_gamma1_base_dilithium
        bn.mov w3, w8
        bn.rshi w1, w3, w6 >> 128
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        bn.rshi w1, bn0, w3 >> 32
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        jal x1, _read_shake_poly_uniform_gamma1_base_dilithium
        bn.mov w6, w8
        bn.rshi w1, w6, w3 >> 192
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium

        bn.rshi w1, bn0, w6 >> 96
        jal     x1, _inner_poly_uniform_gamma1_base_dilithium
        nop /* Must not end on branch */

    /* Finish the SHAKE-256 operation. */

    /* sp <- fp */
    addi sp, fp, 0
    /* Pop ebp */
    lw fp, 0(sp)
    addi sp, sp, 32

    ret

_inner_poly_uniform_gamma1_base_dilithium:
    /* Unpack 8 coefficients in one go */
    .rept 8
        /* Mask */
        bn.and w7, w1, w5
        /* Subtract coefficient from eta */
        bn.subm w7, w4, w7
        /* Move coefficient into the output register */
        bn.rshi w2, w7, w2 >> 32
        /* Advance the input register such that the next coefficient is
            in the lower 18 bits */
        bn.rshi w1, bn0, w1 >> 20
    .endr
    
    bn.sid     t2, 0(a0++)
    ret
#endif

_read_shake_poly_uniform_gamma1_base_dilithium:
    bn.wsrr w8, 0xA /* KECCAK_DIGEST */
    ret

/**
 * poly_decompose_dilithium
 *
 *  For all coefficients c of the input polynomial, compute high and low bits
 *  c0, c1 such c mod Q = c1*ALPHA + c0 with -ALPHA/2 < c0 <= ALPHA/2 except c1
 *  = (Q-1)/ALPHA where we set c1 = 0 and -ALPHA/2 <= c0 = c mod Q - Q < 0.
 *  Assumes coefficients to be standard representatives.
 *
 * Flags: -
 *
 * @param[out] a0: a0 pointer to output polynomial with coefficients c0
 * @param[out] a1: a1: pointer to output polynomial with coefficients c1
 * @param[in]  a2: *a: pointer to input polynomial
 *
 * clobbered registers: w0-w11, a0-a2, t0-t4
 */
.global poly_decompose_dilithium
poly_decompose_dilithium:
    /* WDR constants for decompose */
    /* w5 <= 1<<23 or 1<<21 */
    bn.addi w5, bn0, 1
#if GAMMA2 == (Q-1)/88
    bn.rshi w5, w5, bn0 >> 233
#elif GAMMA2 == (Q-1)/32
    bn.rshi w5, w5, bn0 >> 235
#endif

    la t0, decompose_const_base
    li t1, 6
    /* w6 <= decompose_const_base */
    bn.lid t1, 0(t0)

    la t0, qm1half_base_const
    li t1, 7
    /* w7 <= qm1half_base_const */
    bn.lid t1, 0(t0)

    /* w8 <= decompose_43_const or decompose_15_const */
#if GAMMA2 == (Q-1)/88
    bn.addi w8, bn0, 43
#elif GAMMA2 == (Q-1)/32
    bn.addi w8, bn0, 15
#endif

    la t0, gamma2x2_vec_base_const
    li t1, 9
    /* w9 <= gamma2x2_vec_base_const */
    bn.lid t1, 0(t0)

    la t0, modulus_base
    li t1, 10
    /* w10 <= modulus_base */
    bn.lid t1, 0(t0)

    /* w11 <= 0xFFFFFFFF */
    bn.addi w11, bn0, 1
    bn.rshi w11, w11, bn0 >> 224
    bn.subi w11, w11, 1 

    /* Setup constants for WDRs */
    li t0, 0
    li t1, 1
    li t2, 2

    LOOPI 32, 4
        bn.lid t0, 0(a2++)
        jal x1, decompose_unsigned_base_dilithium
        bn.sid t1, 0(a0++)
        bn.sid t2, 0(a1++)

    ret

/**
 * poly_make_hint_dilithium
 *
 *  Compute hint polynomial. The coefficients of which indicate whether the low
 *  bits of the corresponding coefficient of the input polynomial overflow into
 *  the high bits.
 *  The function accepts inputs mod^+ q.
 * 
 * Returns: Number of one bits
 *
 * @param[out] a0: pointer to output hint polynomial
 * @param[in]  a1: a0 pointer to low part of input polynomial
 * @param[in]  a2: a1: pointer to high part of input polynomial
 *
 * clobbered registers: t0-t2, t4-t6, a0-a2, a4-a7
 */
.global poly_make_hint_dilithium
poly_make_hint_dilithium:
    li   t2, 0
    li   t4, 1

    /* Constants for condition checking */ 
    li t6, GAMMA2

    la t0, modulus
    lw a6, 0(t0)
    sub a7, a6, t6 /* q - gamma2 */

    /* Loop over every coefficient pair of the input */
    LOOPI 256, 21
        lw t0, 0(a1)
        lw t1, 0(a2)

        sub t5, t6, t0 /* Check t0 < (gamma2 + 1) <=> 0 < (gamma2 + 1) - t0 */
        srli t3, t5, 31
        beq t3, zero, _loop_end_poly_make_hint_dilithium

        sub t5, a7, t0 /* Check t0 > (q - gamma) <=> t0 - (q - gamma) > 0 */
        srli t3, t5, 31
        beq t3, t4, _return0

        bne t0, a7, _return1
        li t3, 0
        beq t1, zero, _loop_end_poly_make_hint_dilithium
        beq t1, a6, _loop_end_poly_make_hint_dilithium
        beq zero, zero, _return1
_return0:
        li t3, 0
        beq zero, zero, _loop_end_poly_make_hint_dilithium
_return1:
        li t3, 1
        /* Fall through to loop end */
_loop_end_poly_make_hint_dilithium:
        sw   t3, 0(a0) /* Write to output polynomial */
        add  t2, t2, t3
        addi a1, a1, 4
        addi a2, a2, 4
        addi a0, a0, 4

    addi a0, t2, 0 /* move result to return value */
    ret

/**
 * polyz_pack_base_dilithium
 *
 * Pack polynomial z with coefficients fitting in 18 bits. 
 *
 * Flags: -
 *
 * @param[in]  w0: gamma1_vec_const
 * @param[in]  a1: pointer to input polynomial
 * @param[out] a0: pointer to output byte array with at least
 *                 POLYZ_PACKEDBYTES bytes
 *
 * clobbered registers: a0-a1, t0-t2, w0-w1
 */
.global polyz_pack_base_dilithium
polyz_pack_base_dilithium:
#if GAMMA1 == (1 << 17)
    la t1, gamma1_vec_base_const
    li t3, 3
    bn.lid t3, 0(t1)

    la t1, polyz_unpack_base_dilithium_mask
    li t3, 5
    bn.lid t3, 0(t1)

    /* Setup WDRs */
    li t1, 1
    li t4, 4

    /* Start packing */
    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 112
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 80
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 48
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 16
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 128
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 96
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 64
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 32
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 112
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 80
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 48
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 16
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 128
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 96
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 64
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 32
    bn.sid  t4, 0(a0++)
    bn.rshi w4, w2, bn0 >> 144


    jal     x1, _inner_polyz_pack_base_dilithium
    bn.rshi w4, w2, w4 >> 144
    bn.sid  t4, 0(a0++)

    ret

_inner_polyz_pack_base_dilithium:
    bn.lid t1, 0(a1++)
    .rept 8
        /* Mask coefficient */
            bn.and w7, w1, w5
            /* Subtract from constant */ 
            bn.sub w7, w3, w7
            /* Move coefficient into the output register */
            bn.rshi w2, w7, w2 >> 18
            /* Shift out used coefficient */
            bn.rshi w1, bn0, w1 >> 32 
    .endr
    bn.rshi w2, bn0, w2 >> 112 /* Shift the 144 bits of data to the bottom of the 
                                 WDR */
    ret
#elif GAMMA1 == (1 << 19)
    la t1, gamma1_vec_base_const
    li t3, 3
    bn.lid t3, 0(t1)

    la t1, polyz_unpack_base_dilithium_mask
    li t3, 5
    bn.lid t3, 0(t1)

    /* Setup WDRs */
    li t1, 1
    li t4, 4
    LOOPI 4, 25
        jal     x1, _inner_polyz_pack_base_dilithium
        bn.rshi w4, w2, w4 >> 160


        jal     x1, _inner_polyz_pack_base_dilithium
        bn.rshi w4, w2, w4 >> 96
        bn.sid  t4, 0(a0++)
        bn.rshi w4, w2, bn0 >> 160


        jal     x1, _inner_polyz_pack_base_dilithium
        bn.rshi w4, w2, w4 >> 160


        jal     x1, _inner_polyz_pack_base_dilithium
        bn.rshi w4, w2, w4 >> 32
        bn.sid  t4, 0(a0++)
        bn.rshi w4, w2, bn0 >> 160


        jal     x1, _inner_polyz_pack_base_dilithium
        bn.rshi w4, w2, w4 >> 128
        bn.sid  t4, 0(a0++)
        bn.rshi w4, w2, bn0 >> 160


        jal     x1, _inner_polyz_pack_base_dilithium
        bn.rshi w4, w2, w4 >> 160


        jal     x1, _inner_polyz_pack_base_dilithium
        bn.rshi w4, w2, w4 >> 64
        bn.sid  t4, 0(a0++)
        bn.rshi w4, w2, bn0 >> 160


        jal     x1, _inner_polyz_pack_base_dilithium
        bn.rshi w4, w2, w4 >> 160
        bn.sid  t4, 0(a0++)

    ret
_inner_polyz_pack_base_dilithium:
    bn.lid t1, 0(a1++)
    .rept 8
        /* Mask coefficient */
        bn.and w7, w1, w5
        /* Subtract from constant */ 
        bn.sub w7, w3, w7
        /* Move coefficient into the output register */
        bn.rshi w2, w7, w2 >> 20
        /* Shift out used coefficient */
        bn.rshi w1, bn0, w1 >> 32 
    .endr
    bn.rshi w2, bn0, w2 >> 96 /* Shift the 96 bits of data to the bottom of the 
                                 WDR */
    ret
#endif
/**
 * polyvec_encode_h_dilithium
 *
 * Encode h to signature from polyvec h.
 *
 * Flags: -
 *
 * @param[in]  a1: pointer to input polynomial h
 * @param[out] a0: pointer to output byte array signature
 *
 * clobbered registers: a1-a2, t0-t6
 */
.global polyvec_encode_h_dilithium
polyvec_encode_h_dilithium:
    li t0, 0 /* k = 0 */
    li t1, 0 /* i = 0 */

    /* Masking constant for alignment */
    li a2, 0xFFFFFFFC
    LOOPI K, 25
        li t2, 0 /* j = 0 */
        LOOPI N, 13
            lw   t3, 0(a1)
            addi a1, a1, 4   /* Increment input pointer */
            beq  zero, t3, _skip_store_polyvec_encode_h_dilithium
            add  t4, a0, t0  /* *sig + k */
            andi t5, t4, 0x3 /* preserve lower 2 bits */
            and  t4, t4, a2  /* align */
            lw   t6, 0(t4)   /* load form aligned(sig+k) */
            slli t5, t5, 3   /* #bytes -> #bits */
            sll  t5, t2, t5  /* j << #bits */
            or   t6, t6, t5
            sw   t6, 0(t4)

            addi t0, t0, 1 /* k++ */
_skip_store_polyvec_encode_h_dilithium:
            addi t2, t2, 1
        addi t2, t1, OMEGA /* OMEGA + i */
        add  t2, a0, t2    /* *sig + OMEGA + i */
        andi t3, t2, 0x3   /* preserve lower 2 bits */
        and  t2, t2, a2    /* align */
        lw   t4, 0(t2)     /* load from aligned(*sig + OMEGA + i) */
        slli t3, t3, 3     /* #bytes -> #bits */
        sll  t3, t0, t3    /* k << #bits */
        or   t4, t4, t3
        sw   t4, 0(t2)

        addi t1, t1, 1

    ret

/**
 * Constant Time Dilithium polynomial power2round
 *
 * Returns: power2round(output2, output1, input) reduced mod q
 *
 * This implements the polynomial addition for Dilithium, where n=256,q=8380417.
 *
 * Flags: -
 *
 * @param[in]  a0:  a, dmem pointer to first word of input polynomial
 * @param[in]  a1: a0, dmem pointer to output polynomial with coefficients c0
 * @param[in]  a2: a1, dmem pointer to output polynomial with coefficients c1
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x7, w2-w4
 */
.global poly_power2round_base_dilithium
poly_power2round_base_dilithium:
    #define D 13
    #define Dinv 243

    /* Load (1 << (D-1)) - 1 to w10 */
    li t0, 10
    la t1, power2round_D_preprocessed_base
    bn.lid t0, 0(t1)

    /* Set up constants for input/state */
    li t0, 0
    li t1, 1
    li t2, 2

    /* w11 <= 0xFFFFFFFF for masking */
    bn.addi w11, bn0, 1
    bn.rshi w11, w11, bn0 >> 224
    bn.subi w11, w11, 1 

    LOOPI 32, 12
        /* Load input */
        bn.lid t0, 0(a0++)

        LOOPI 8, 8
            bn.and w3, w0, w11 /* Mask out one coefficient */

            bn.addm w3, w3, bn0 /* Reduce q to 0 */

            bn.add w4, w3, w10
            bn.rshi w4, bn0, w4 >> D

            bn.rshi w0, w4, w0 >> 32 /* Accumulate to output register */

            bn.rshi w4, w4, bn0 >> Dinv /* << by D */
            bn.sub w4, w3, w4

            bn.rshi w1, w4, w1 >> 32 /* Accumulate to output register */

        /* Store */
        bn.sid t0, 0(a2++)
        bn.sid t1, 0(a1++)

    ret

/**
 * Constant Time Dilithium reduce32
 *
 * Returns: reduce32(input1)
 *
 * This implements reduce32 for Dilithium, where n=256,q=8380417.
 *
 * Note: This is a modified version that only takes small inputs. Used for 
 *       obtaining centralized representative
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  a0: dptr_input1, dmem pointer to first word of input1 polynomial
 * @param[in]  w31: all-zero
 * @param[out] a1: dmem pointer to result
 *
 * clobbered registers: x4-x7, x10-x11, w2-w6
 */
.globl poly_reduce32_short_dilithium
poly_reduce32_short_dilithium:
    /* Load 4194304 to w10 */
    la t0, reduce32_cmp_const
    li t1, 10
    bn.lid t1, 0(t0)

    /* Set up constants for input/state */
    li t0, 0
    li t1, 1
    li t2, 2

    /* w11 <= 0xFFFFFFFF for masking */
    bn.addi w11, bn0, 1
    bn.rshi w11, w11, bn0 >> 224
    bn.subi w11, w11, 1 

    /* Load q */
    li     t4, 12
    la     t3, modulus
    bn.lid t4, 0(t3)
    bn.and w12, w12, w11 /* Only keep one word */

    LOOPI 32, 8
        bn.lid t0, 0(a0++)

        LOOPI 8, 5
            bn.and w3, w0, w11 /* Mask out one coefficient */

            bn.cmp w3, w10
            bn.sel w4, bn0, w12, C
            bn.sub w2, w3, w4

            bn.rshi w0, w2, w0 >> 32

        bn.sid t0, 0(a1++)

    ret


/**
 * Constant Time Dilithium reduce32
 *
 * Returns: reduce32(input1)
 *
 * This implements reduce32 for Dilithium, where n=256,q=8380417.
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  a0: dptr_input1, dmem pointer to first word of input1 polynomial
 * @param[in]  w31: all-zero
 * @param[out] a1: dmem pointer to result
 *
 * clobbered registers: x4-x7, x10-x11, w2-w6
 */
.globl poly_reduce32_dilithium
poly_reduce32_dilithium:
    /* Load 4194304 to w10 */
    la t0, reduce32_cmp_const
    li t1, 10
    bn.lid t1, 0(t0)

    /* Set up constants for input/state */
    li t0, 0
    li t1, 1
    li t2, 2

    /* w11 <= 0xFFFFFFFF for masking */
    bn.addi w11, bn0, 1
    bn.rshi w11, w11, bn0 >> 224
    bn.subi w11, w11, 1

    /* w13 <= mask for sign ext */
    bn.addi w13, w11, 0
    bn.rshi w13, bn0, w13 >> 9

    /* Load q */
    li     t4, 12
    la     t3, modulus
    bn.lid t4, 0(t3)
    bn.and w12, w12, w11 /* Only keep one word */

    LOOPI 32, 11
        bn.lid t0, 0(a0++)

        LOOPI 8, 8
            bn.and w3, w0, w11
            
            bn.add w4, w3, w10 /* Add (1<<22) */
            bn.and w4, w4, w11
            bn.rshi w4, bn0, w4 >> 23
            bn.and w4, w4, w11

            bn.mulqacc.wo.z w4, w4.0, w12.0, 0
            bn.sub w3, w3, w4

            bn.rshi w0, w3, w0 >> 32 /* Capture result and advance input */

        bn.sid t0, 0(a1++)

    ret

/**
 * Constant Time Dilithium reduce32
 *
 * Returns: reduce32(input1)
 *
 * This implements reduce32 for Dilithium, where n=256,q=8380417.
 *
 * Note: This is a modified version giving a result in [0,6283007]
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  a0: dptr_input1, dmem pointer to first word of input1 polynomial
 * @param[in]  w31: all-zero
 * @param[out] a1: dmem pointer to result
 *
 * clobbered registers: x4-x7, x10-x11, w2-w6
 */
.globl poly_reduce32_pos_dilithium
poly_reduce32_pos_dilithium:
    /* Load 4194304 to w10 */
    la t0, reduce32_cmp_const
    li t1, 10
    bn.lid t1, 0(t0)

    /* Set up constants for input/state */
    li t0, 0
    li t1, 1
    li t2, 2

    /* w11 <= 0xFFFFFFFF for masking */
    bn.addi w11, bn0, 1
    bn.rshi w11, w11, bn0 >> 224
    bn.subi w11, w11, 1

    /* w13 <= mask for sign ext */
    bn.addi w13, w11, 0
    bn.rshi w13, bn0, w13 >> 9

    /* Load q */
    li     t4, 12
    la     t3, modulus
    bn.lid t4, 0(t3)
    bn.and w12, w12, w11 /* Only keep one word */

    LOOPI 32, 11
        bn.lid t0, 0(a0++)

        LOOPI 8, 8
            bn.and w3, w0, w11
            
            bn.add w4, w3, w10 /* Add (1<<22) */
            bn.and w4, w4, w11
            bn.rshi w4, bn0, w4 >> 23
            bn.and w4, w4, w11

            bn.mulqacc.wo.z w4, w4.0, w12.0, 0
            bn.subm w3, w3, w4

            bn.rshi w0, w3, w0 >> 32 /* Capture result and advance input */

        bn.sid t0, 0(a1++)

    ret

/**
 * Constant Time Dilithium base multiplication (pointwise)
 *
 * Returns: poly_pointwise(input1, input2)
 *
 * This implements the base multiplication for Dilithium, where n=256,q=8380417.
 *
 * Flags: -
 *
 * @param[in]  x10: dptr_input1, dmem pointer to first word of input1 polynomial
 * @param[in]  x11: dptr_input2, dmem pointer to first word of input2 polynomial
 * @param[in]  w31: all-zero
 * @param[out] x12: dmem pointer to result
 *
 * clobbered registers: x4-x6, w2-w4
 */
.globl poly_pointwise_base_dilithium
poly_pointwise_base_dilithium:
    #define mask w7
    #define qprime w8.2
    #define q w8.3
    
    /* Init constants */

    /* Load mask */
    bn.addi mask, bn0, 1
    bn.or   mask, bn0, mask << 32
    bn.subi mask, mask, 1

    /* Load q' to w8.0 */
    li t0, 8
    la t1, qprime_single
    bn.lid t0, 0(t1)
    bn.or w8, bn0, w8 << 128

    /* Load q to w8.2 */
    li t0, 9
    la t1, modulus
    bn.lid t0, 0(t1)
    bn.and w9, mask, w9
    bn.or w8, w8, w9 << 192

    /* Load alpha = 1 */
    bn.addi w10, bn0, 1
    bn.or w8, w8, w10 << 64
    /* Constants for WDRs */
    li t0, 0
    li t1, 1
    li t2, 6

    LOOPI 32, 13
        bn.lid t0, 0(a0++)
        bn.lid t1, 0(a1++)

        LOOPI 8, 9
            /* Mask one coefficient to working registers */
            bn.and w4, w0, w7
            bn.and w5, w1, w7
            /* Shift out used coefficient */
            bn.rshi w0, bn0, w0 >> 32

            /* Do operation */
            /* c = a * b */
            bn.mulqacc.wo.z w5, qprime, w5.0, 0
            /* Multiply q' */
            bn.mulqacc.wo.z w4, w4.0, w5.0, 192
            /* Extract upper 32-bits of bottom result half */
            /* + 1 */
            bn.add w4, w8, w4 >> 160
            bn.mulqacc.wo.z w4, w4.1, q, 0
            bn.rshi w4, w8, w4 >> 32

            /* Append result to output */
            bn.rshi w1, w4, w1 >> 32
        /* Store 8 coefficients */
        bn.sid t1, 0(a2++)
    ret

/**
 * Constant Time Dilithium base multiplication (pointwise) with accumulation
 *
 * Returns: poly_pointwise_acc(input1, input2)
 *
 * This implements the base multiplication for Dilithium, where n=256,q=8380417.
 * Accumulates onto the output polynomial.
 *
 * Flags: -
 * 
 * @param[in]  x10: dptr_input1, dmem pointer to first word of input1 polynomial
 * @param[in]  x11: dptr_input2, dmem pointer to first word of input2 polynomial
 * @param[in]  w31: all-zero
 * @param[in/out] x12: dmem pointer to result
 *
 * clobbered registers: x4-x6, w2-w4
 */
.globl poly_pointwise_acc_base_dilithium
poly_pointwise_acc_base_dilithium:
    #define mask w7
    #define qprime w8.2
    #define q w8.3
    
    /* Init constants */

    /* Load mask */
    bn.addi mask, bn0, 1
    bn.or   mask, bn0, mask << 32
    bn.subi mask, mask, 1

    /* Load q' to w8.0 */
    li t0, 8
    la t1, qprime_single
    bn.lid t0, 0(t1)
    bn.or w8, bn0, w8 << 128

    /* Load q to w8.2 */
    li t0, 9
    la t1, modulus
    bn.lid t0, 0(t1)
    bn.and w9, mask, w9
    bn.or w8, w8, w9 << 192

    /* Load alpha = 1 */
    bn.addi w10, bn0, 1
    bn.or w8, w8, w10 << 64

    /* Constants for WDRs */
    li t0, 0
    li t1, 1
    li t2, 2
    li t3, 6

    LOOPI 32, 15
        bn.lid t0, 0(a0++)
        bn.lid t1, 0(a1++)
        bn.lid t2, 0(a2)

        LOOPI 8, 9
            /* Mask one coefficient to working registers */
            bn.and w4, w0, mask
            bn.and w5, w1, mask
            /* Shift out used coefficient */
            bn.rshi w0, bn0, w0 >> 32

            /* Do operation */
            /* c = a * b */
            bn.mulqacc.wo.z w5, qprime, w5.0, 0
            /* Multiply q' */
            bn.mulqacc.wo.z w4, w5.0, w4.0, 192
            /* + 1 */
            bn.add w4, w8, w4 >> 160
            bn.mulqacc.wo.z w4, w4.1, q, 0
            bn.rshi w4, w8, w4 >> 32

            /* Append result to output */
            bn.rshi w1, w4, w1 >> 32

        bn.add w1, w1, w2 /* Accumulate */

        /* Store 8 coefficients */
        bn.sid t1, 0(a2++)
    ret

/**
 * Constant Time Dilithium conditional add q
 *
 * Returns: input1 reduced mod^{+} q (taken from MOD WDR)
 *
 * This implements the polynomial addition for e.g. Dilithium, where n=256.
 *
 * Flags: -
 *
 * @param[in/out]  x10: dptr_input1, dmem pointer to first word of input1 polynomial
 * @param[in]  w31: all-zero
 *
 * clobbered registers: x4-x6, w2-w4
 */
.global poly_caddq_base_dilithium
poly_caddq_base_dilithium:
    

    /* Init mask */
    bn.addi w7, w31, 1
    bn.or w7, w31, w7 << 32
    bn.subi w7, w7, 1

    /* Load modulus */
    la x4, modulus
    li x5, 8
    bn.lid x5, 0(x4)
    bn.and w8, w8, w7

    /* Load mask for masking the sign bit */
    bn.addi w9, bn0, 1
    bn.rshi w9, w9, bn0 >> 225 /* Set 31st bit to 1 */

    /* Set up constants for input/state */
    li x6, 2
    li x5, 3
    li x4, 6

    LOOPI 32, 8
        bn.lid x6, 0(x10)

        LOOPI 8, 5
            /* Mask one coefficient to working registers */
            bn.and w4, w2, w7

            /* Test sign */
            bn.and w5, w4, w9
            /* If sign bit was set, select q. Else 0. */
            bn.sel w5, bn0, w8, z
            bn.add w4, w4, w5

            bn.rshi w2, w4, w2 >> 32
        
        bn.sid x6, 0(x10++)

    ret

.data 
.balign 32
qprime_single:
    /* qprime */
    .word 0x03802001, 0x180a4060
    .word 0x0, 0x0
    .word 0x0, 0x0
    .word 0x0, 0x0
reduce32_cmp_const:
    .word 4194304
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0