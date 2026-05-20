/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Entrypoint for ML-DSA keygen / sign / verify operations.
 *
 * This binary has 9 modes: {keygen, sign, verify} x {ML-DSA-44, ML-DSA-65,
 * ML-DSA-87}. The mode is read from `dmem[mode]`. Mode-specific parameters
 * are written into mldsa_params at dispatch time by copying the right entry
 * from one of the mldsa_params_{44,65,87} tables below.
 */

/* Register aliases */
.equ x1, ra
.equ x2, sp
.equ x5, t0
.equ x6, t1
.equ x10, a0
.equ x11, a1
.equ x12, a2
.equ w31, bn0

/* Offsets into mldsa_params (see mldsa_consts.s). */
#define MLDSA_PARAM_K_OFFSET 0
#define MLDSA_PARAM_L_OFFSET 4
#define MLDSA_PARAM_TAU_OFFSET 8
#define MLDSA_PARAM_OMEGA_OFFSET 12
#define MLDSA_PARAM_GAMMA1_MINUS_BETA_OFFSET 16
#define MLDSA_PARAM_POLYW1_PACKEDBYTES_OFFSET 20
#define MLDSA_PARAM_CRYPTO_PUBLICKEYBYTES_OFFSET 24
#define MLDSA_PARAM_GAMMA2_OFFSET 28
#define MLDSA_PARAM_GAMMA2_MINUS_BETA_OFFSET 32
#define MLDSA_PARAM_SK_S2_OFFSET_OFFSET 36
#define MLDSA_PARAM_SK_T0_OFFSET_OFFSET 40
#define MLDSA_PARAM_CRYPTO_BYTES_OFFSET 44

/**
 * Mode magic values, generated with
 * $ ./util/design/sparse-fsm-encode.py -d 6 -m 9 -n 11 \
 *     --avoid-zero -s 271828182
 *
 * Call the same utility with the same arguments and a higher -m to generate
 * additional value(s) without changing the others or sacrificing mutual HD.
 *
 */
.equ MODE_KEYGEN_44, 0x1ec
.equ MODE_KEYGEN_65, 0x4d5
.equ MODE_KEYGEN_87, 0x6a6
.equ MODE_SIGN_44,   0x58b
.equ MODE_SIGN_65,   0x2da
.equ MODE_SIGN_87,   0x572
.equ MODE_VERIFY_44, 0x347
.equ MODE_VERIFY_65, 0x71c
.equ MODE_VERIFY_87, 0x3b1

.globl MODE_KEYGEN_44
.globl MODE_KEYGEN_65
.globl MODE_KEYGEN_87
.globl MODE_SIGN_44
.globl MODE_SIGN_65
.globl MODE_SIGN_87
.globl MODE_VERIFY_44
.globl MODE_VERIFY_65
.globl MODE_VERIFY_87

.section .text.start
.globl start
start:
    /* All-zero register. */
    bn.xor w31, w31, w31

    /* MOD = R | Q. */
    li      x5, 2
    la      x6, modulus
    bn.lid  x5, 0(x6)
    li      x5, 3
    la      x6, montg_R
    bn.lid  x5, 0(x6)
    bn.rshi w2, w3, w2 >> 224
    bn.wsrw 0x0, w2

    /* Read mode and dispatch. */
    la x5, mode
    lw x5, 0(x5)

    addi x3, x0, MODE_KEYGEN_44
    beq  x5, x3, _mldsa_keygen_44
    addi x3, x0, MODE_KEYGEN_65
    beq  x5, x3, _mldsa_keygen_65
    addi x3, x0, MODE_KEYGEN_87
    beq  x5, x3, _mldsa_keygen_87

    addi x3, x0, MODE_SIGN_44
    beq  x5, x3, _mldsa_sign_44
    addi x3, x0, MODE_SIGN_65
    beq  x5, x3, _mldsa_sign_65
    addi x3, x0, MODE_SIGN_87
    beq  x5, x3, _mldsa_sign_87

    addi x3, x0, MODE_VERIFY_44
    beq  x5, x3, _mldsa_verify_44
    addi x3, x0, MODE_VERIFY_65
    beq  x5, x3, _mldsa_verify_65
    addi x3, x0, MODE_VERIFY_87
    beq  x5, x3, _mldsa_verify_87

    /* Invalid mode. */
    unimp
    unimp
    unimp

_mldsa_keygen_44:
    la   a0, mldsa_params_44
    jal  x1, _setup_params
    jal  x0, _mldsa_keygen_common
_mldsa_keygen_65:
    la   a0, mldsa_params_65
    jal  x1, _setup_params
    jal  x0, _mldsa_keygen_common
_mldsa_keygen_87:
    la   a0, mldsa_params_87
    jal  x1, _setup_params
_mldsa_keygen_common:
    jal  x1, crypto_sign_keypair
    ecall

_mldsa_sign_44:
    la   a0, mldsa_params_44
    jal  x1, _setup_params
    jal  x0, _mldsa_sign_common
_mldsa_sign_65:
    la   a0, mldsa_params_65
    jal  x1, _setup_params
    jal  x0, _mldsa_sign_common
_mldsa_sign_87:
    la   a0, mldsa_params_87
    jal  x1, _setup_params
_mldsa_sign_common:
    la   a0, sig
    jal  x1, crypto_sign_signature_internal
    ecall

_mldsa_verify_44:
    la   a0, mldsa_params_44
    jal  x1, _setup_params
    jal  x0, _mldsa_verify_common
_mldsa_verify_65:
    la   a0, mldsa_params_65
    jal  x1, _setup_params
    jal  x0, _mldsa_verify_common
_mldsa_verify_87:
    la   a0, mldsa_params_87
    jal  x1, _setup_params
_mldsa_verify_common:
    la   a0, sig
    jal  x1, crypto_sign_verify_internal
    ecall

/**
 * Copy 64 bytes from a0 to mldsa_params.
 *
 * @param[in] a0: pointer to source mldsa_params_* table
 *
 * clobbered registers: a1, t0, w0
 */
_setup_params:
    la     a1, mldsa_params
    li     t0, 0
    bn.lid t0, 0(a0)
    bn.sid t0, 0(a1)
    bn.lid t0, 32(a0)
    bn.sid t0, 32(a1)
    ret

.section .data

/* ML-DSA-44 parameters (K=4, L=4, ETA=2, GAMMA1=2^17, GAMMA2=(Q-1)/88). */
.balign 32
.globl mldsa_params_44
mldsa_params_44:
    .word 4         /* K */
    .word 4         /* L */
    .word 39        /* TAU */
    .word 80        /* OMEGA */
    .word 130994    /* GAMMA1 - BETA */
    .word 192       /* POLYW1_PACKEDBYTES */
    .word 1312      /* CRYPTO_PUBLICKEYBYTES */
    .word 95232     /* GAMMA2 */
    .word 95154     /* GAMMA2 - BETA */
    .word 512       /* SK_S2_OFFSET */
    .word 896       /* SK_T0_OFFSET */
    .word 2420      /* CRYPTO_BYTES */
    .zero 16

/* ML-DSA-65 parameters (K=6, L=5, ETA=4, GAMMA1=2^19, GAMMA2=(Q-1)/32). */
.balign 32
.globl mldsa_params_65
mldsa_params_65:
    .word 6
    .word 5
    .word 49
    .word 55
    .word 524092
    .word 128
    .word 1952
    .word 261888
    .word 261692
    .word 768
    .word 1536
    .word 3309
    .zero 16

/* ML-DSA-87 parameters (K=8, L=7, ETA=2, GAMMA1=2^19, GAMMA2=(Q-1)/32). */
.balign 32
.globl mldsa_params_87
mldsa_params_87:
    .word 8
    .word 7
    .word 60
    .word 75
    .word 524168
    .word 128
    .word 2592
    .word 261888
    .word 261768
    .word 800
    .word 1568
    .word 4627
    .zero 16

.bss

/* Operation mode (one of MODE_*). */
.globl mode
.balign 4
mode:
    .zero 4

/* Keygen seed (32 bytes). */
.globl zeta
.balign 32
zeta:
    .zero 32

/* Public key (worst-case ML-DSA-87 = 2592 bytes). */
.globl pk
.balign 32
pk:
    .zero 2592

/* Secret key (sk) for keypair/sign and the packed z polyvec (z_polyvec)
 * for verify share storage: sk is unused during verify and z_polyvec is
 * unused during keypair/sign. Sized for the larger consumer (z_polyvec =
 * L*1024 = 7168 bytes for ML-DSA-87); sk uses only the first 4896 bytes. */
.globl sk
.globl z_polyvec
.balign 32
sk:
z_polyvec:
    .zero 7168

/* Signature (worst-case ML-DSA-87 = 4627 bytes). */
.globl sig
.balign 32
sig:
    .zero 4627

/* External mu (64 bytes), computed by the caller for sign and verify. */
.globl mu
.balign 32
mu:
    .zero 64

/* Hedge randomness for signing (32 bytes). */
.globl rnd
.balign 32
rnd:
    .zero 32

/* Verify result (HARDENED_BOOL_TRUE if valid, HARDENED_BOOL_FALSE otherwise). */
.globl result
.balign 4
result:
    .zero 4

/* Shared kernel scratch. Buffers that are only live within a single
 * operation are overlaid by aliasing label names to the same storage. */

.balign 32
.globl tmp_poly
tmp_poly:
    .zero 1024

.balign 32
.globl c_poly
.globl y_poly
.globl s1_poly
c_poly:
y_poly:
s1_poly:
    .zero 1024

.balign 32
.globl rhoprime
.globl ctilde
rhoprime:
ctilde:
    .zero 64

.balign 4
.globl dptr_sig
dptr_sig:
    .zero 4

.balign 32
.globl w1_repvec
w1_repvec:
    .zero 256

/* keypair: t_polyvec; sign: w0_polyvec; verify: w1_polyvec. */
.balign 32
.globl t_polyvec
.globl w0_polyvec
.globl w1_polyvec
t_polyvec:
w0_polyvec:
w1_polyvec:
    .zero 8192
