/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.text

#define KYBER_N 256
#define KYBER_Q 3329
#define KYBER_SYMBYTES 32   /* size in bytes of hashes, and seeds */
#define KYBER_SSBYTES  32   /* size in bytes of shared key */
#define KYBER_POLYBYTES		384
#define KYBER_ETA2 2
#if (KYBER_K == 2)
  #define KYBER_POLYVECBYTES	768
  #define KYBER_POLYCOMPRESSEDBYTES    128
  #define KYBER_POLYVECCOMPRESSEDBYTES 640
  #define KYBER_ETA1 3
  
  #define KYBER_INDCPA_MSGBYTES       32
  #define KYBER_INDCPA_PUBLICKEYBYTES 800
  #define KYBER_INDCPA_SECRETKEYBYTES 768
  #define KYBER_INDCPA_BYTES          768

  #define KYBER_PUBLICKEYBYTES  800
  /* 32 bytes of additional space to save H(pk) */
  #define KYBER_SECRETKEYBYTES  1632
  #define KYBER_CIPHERTEXTBYTES 768

  #define KYBER_INDCPA_PUBLICKEYBYTES_WRS 25
  #define KYBER_CIPHERTEXT_WRS 24
  #define KYBER_GEN_MATRIX_NONCE 254
  #define KYBER_GEN_MATRIX_AT_NONCE -511
  #define POLY -512
  #define K_POLYS -1024
  #define K_SQUARED_POLYS -2048

#elif (KYBER_K == 3)
  #define KYBER_POLYVECBYTES	1152
  #define KYBER_POLYCOMPRESSEDBYTES    128
  #define KYBER_POLYVECCOMPRESSEDBYTES 960
  #define KYBER_ETA1 2

  #define KYBER_INDCPA_MSGBYTES       32
  #define KYBER_INDCPA_PUBLICKEYBYTES 1184
  #define KYBER_INDCPA_SECRETKEYBYTES 1152
  #define KYBER_INDCPA_BYTES          1088

  #define KYBER_PUBLICKEYBYTES  1184
  /* 32 bytes of additional space to save H(pk) */
  #define KYBER_SECRETKEYBYTES  2400
  #define KYBER_CIPHERTEXTBYTES 1088

  #define KYBER_INDCPA_PUBLICKEYBYTES_WRS 37
  #define KYBER_CIPHERTEXT_WRS 34
  #define KYBER_GEN_MATRIX_NONCE 253
  #define KYBER_GEN_MATRIX_AT_NONCE -767
  #define POLY -512
  #define K_POLYS -1536
  #define K_SQUARED_POLYS -4608

#elif (KYBER_K == 4)
  #define KYBER_POLYVECBYTES	1536
  #define KYBER_POLYCOMPRESSEDBYTES    160
  #define KYBER_POLYVECCOMPRESSEDBYTES 1408
  #define KYBER_ETA1 2

  #define KYBER_INDCPA_MSGBYTES       32
  #define KYBER_INDCPA_PUBLICKEYBYTES 1568
  #define KYBER_INDCPA_SECRETKEYBYTES 1536
  #define KYBER_INDCPA_BYTES          1568

  #define KYBER_PUBLICKEYBYTES  1568
  /* 32 bytes of additional space to save H(pk) */
  #define KYBER_SECRETKEYBYTES  3168
  #define KYBER_CIPHERTEXTBYTES 1568

  #define KYBER_INDCPA_PUBLICKEYBYTES_WRS 49
  #define KYBER_CIPHERTEXT_WRS 49
  #define KYBER_GEN_MATRIX_NONCE 252
  #define KYBER_GEN_MATRIX_AT_NONCE -1023
  #define POLY -512
  #define K_POLYS -2048
  #define K_SQUARED_POLYS -8192
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
  srli t0, x11, 5

  /* Write all full 256-bit sections of the test message. */
  beq  t0, zero, _no_full_wdr

  loop t0, 2
      /* w0 <= dmem[x10..x10+32] = msg[32*i..32*i-1]
         x10 <= x10 + 32 */
      bn.lid  x0, 0(x10++)
      /* Write to the KECCAK_MSG wide special register (index 9).
         KECCAK_MSG <= w0 */
      bn.wsrw 0x9, w0

_no_full_wdr:
  /* Compute the remaining message length.
       t0 <= x11 & 31 = len mod 32 */
  andi t0, x11, 31

  /* If the remaining length is zero, return early. */
  beq t0, x0, _keccak_send_message_end

  bn.lid  x0, 0(x10)
  bn.wsrw 0x9, w0

  _keccak_send_message_end:
  ret

/*
 * Name:        indcpa_keypair_base
 *
 * Description: Generates public and private key for the CPA-secure
 *              public-key encryption scheme underlying Kyber
 *
 * Arguments:   - uint8_t *pk: pointer to output public key
 *                             (of length KYBER_INDCPA_PUBLICKEYBYTES bytes)
 *              - uint8_t *sk: pointer to output private key
 *                             (of length KYBER_INDCPA_SECRETKEYBYTES bytes)
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (a0): pointer to seed (KYBER_SYMBYTES = 32)
 * @param[out] x11 (a1): dmem pointer to public key pk_addr
 * @param[out] x12 (a2): dmem pointer to secret key sk_addr
 *
 * clobbered registers: a0-a4, t0-t5, w8, w16
 */

indcpa_keypair_base:
  /* Stack address mapping */
  #define STACK_PK_ADDR        -32
  #define STACK_SK_ADDR        -24
  #define STACK_COINS_ADDR     -16
  #define STACK_BUF           -128
    #define STACK_PUBLICSEED  -128
    #define STACK_NOISESEED    -96
    #define STACK_NONCE        -64
  #define STACK_TMP           -640
#if (KYBER_K == 2)
  #define STACK_A            -1664
  #define STACK_SKPV         -2688
#elif (KYBER_K == 3)
  #define STACK_A            -2176 
  #define STACK_SKPV         -3712 
#elif (KYBER_K == 4)
  #define STACK_A            -2688 
  #define STACK_SKPV         -4736 
#else 
#endif 

  /* Store parameters to stack */
  sw  a0, STACK_COINS_ADDR(fp)
  sw  a1, STACK_PK_ADDR(fp)
  sw  a2, STACK_SK_ADDR(fp)

  /*** hash_g ***/
  /* Initialize a SHA3-512 operation. */
  addi  a1, zero, 33
  slli  t0, a1, 5
  addi  t0, t0, SHA3_512_CFG
  csrrw zero, KECCAK_CFG_REG, t0
  addi  a1, zero, 32
  jal   x1, keccak_send_message
  addi  a0, fp, STACK_BUF
  addi  a1, zero, KYBER_K
  sw    a1, 0(a0)
  addi  a1, zero, 1
  jal   x1, keccak_send_message
  addi  a2, fp, STACK_BUF
  li    t0, 8
  LOOPI 2, 2
    bn.wsrr w8, 0xA /* KECCAK_DIGEST */
    bn.sid  t0, 0(a2++) /* Store into buffer */

  /*** CBD skpv ***/
  li   a5, STACK_A
  li   a1, STACK_SKPV
  add  a1, fp, a1
  li   a3, STACK_NONCE
  li   a2, 0
  LOOPI KYBER_K, 5
    add  t1, fp, a5
    addi a0, fp, STACK_NOISESEED
    sw   a2, STACK_NONCE(fp)
    jal  x1, poly_getnoise_eta_1
    addi a2, a2, 1 

  /*** NTT skpv ***/
  /* ntt(skpv) */
  li   a0, STACK_SKPV
  add  a0, fp, a0
  add  a2, zero, a0
  .rept KYBER_K
    la  a1, twiddles_ntt_base
    jal x1, ntt_base_kyber
  .endr
  
  /*** Packing sk ***/
  li   a0, STACK_SKPV
  add  a0, fp, a0
  lw   a3, STACK_SK_ADDR(fp)
  jal  x1, pack_sk

  /*** Matrix generation ***/
  li   a1, STACK_A
  add  a1, fp, a1
  li   a2, 0
  .rept KYBER_K
    /* Gen 1st mat poly */
    addi a0, fp, STACK_PUBLICSEED
    jal  x1, poly_gen_matrix
    addi a2, a2, 1

    /* Mutliply this generated poly with sk */
    addi a1, a1, POLY /* point back to A[0][0] */
    li   x29, STACK_SKPV
    add  x29, fp, x29 /* point to sk[0] */
    add  a3, a1, x0   /* output at A[0][0] */
    la   x28, twiddles_ntt_base
    jal  x1, basemul_base_kyber

    /* After basemul:
       a1 points to A[0][1]: for storing next generated vector
       a0: reloaded for seed
       a2: untouched by basemul
       x29: accumulated to always point to next poly
       a3: output of basemul, must always points to A[0][0] */
    .rept KYBER_K-1
      /* Gen next mat poly */
      addi a0, fp, STACK_PUBLICSEED
      jal  x1, poly_gen_matrix
      addi a2, a2, 1

      /* Mutliply this generated poly with sk */
      addi a1, a1, POLY /* points back to A[0][1] */
      addi a3, a1, POLY /* points back to A[0][0] for accumulation */
      la   x28, twiddles_ntt_base
      jal  x1, basemul_acc_base_kyber
      addi a1, a1, POLY /* points back to A[0][1] */
    .endr 
    addi a2, a2, KYBER_GEN_MATRIX_NONCE 
  .endr 
  
  /* toplant */
  li  a0, STACK_A
  add a0, fp, a0
  la  a2, const_toplant
  .rept KYBER_K
    jal x1, poly_reduce
  .endr 

  /*** CBD e ***/
  li   a5, STACK_TMP
  li   a1, STACK_SKPV
  add  a1, fp, a1
  li   a3, STACK_NONCE
  li   a2, KYBER_K
  LOOPI KYBER_K, 5
    add  t1, fp, a5
    addi a0, fp, STACK_NOISESEED
    sw   a2, STACK_NONCE(fp)
    jal  x1, poly_getnoise_eta_1
    addi a2, a2, 1 

  /*** NTT e ***/
  /* ntt(skpv) */
  li   a0, STACK_SKPV
  add  a0, fp, a0
  add  a2, zero, a0
  .rept KYBER_K
    la  a1, twiddles_ntt_base
    jal x1, ntt_base_kyber
  .endr

  /* Polyvec add */
  li   a0, STACK_A
  add  a0, fp, a0
  li   a1, STACK_SKPV 
  add  a1, fp, a1 
  add  a2, zero, a0 
  .rept KYBER_K
    jal x1, poly_add_base
  .endr
  
  /*** Packing pk ***/

  lw   a3, STACK_PK_ADDR(fp)
  li   a0, STACK_A
  add  a0, fp, a0 
  addi a1, fp, STACK_PUBLICSEED
  jal  x1, pack_pk

  ret 

/*
 * Name:        crypto_kem_keypair
 *
 * Description: Generates public and private key
 *              for CCA-secure Kyber key encapsulation mechanism
 *
 * Arguments:   - uint8_t *pk: pointer to output public key
 *                (an already allocated array of KYBER_PUBLICKEYBYTES bytes)
 *              - uint8_t *sk: pointer to output private key
 *                (an already allocated array of KYBER_SECRETKEYBYTES bytes)
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (a0): pointer to seed (2*KYBER_SYMBYTES = 64)
 * @param[out] x11 (a1): dmem pointer to kem_pk
 * @param[out] x12 (a2): dmem pointer to kem_sk 
 *
 * clobbered registers: a0-a4, t0-t5, w8, w16
 */

.globl crypto_kem_keypair
crypto_kem_keypair: 
  /* Set frame pointer */
  addi fp, sp, 0 
#if KYBER_K == 2
    li  t0, -2688
#elif KYBER_K == 3
    li  t0, -3712
#elif KYBER_K == 4
    li  t0, -4736
#endif
  add  sp, sp, t0 

  /*** indcpa_keypair ***/
  jal  x1, indcpa_keypair_base
  li   x4, 0
  lw   a0, STACK_PK_ADDR(fp)
  lw   a1, STACK_SK_ADDR(fp)
  addi a1, a1, KYBER_INDCPA_SECRETKEYBYTES
  LOOPI KYBER_INDCPA_PUBLICKEYBYTES_WRS, 2
    bn.lid x4, 0(a0++)
    bn.sid x4, 0(a1++)

  /*** hash_h ***/
  lw      a0, STACK_PK_ADDR(fp) 
  addi    a1, zero, KYBER_PUBLICKEYBYTES
  slli    t0, a1, 5
  addi    t0, t0, SHA3_256_CFG
  csrrw   zero, KECCAK_CFG_REG, t0
  jal     x1, keccak_send_message
  lw      a2, STACK_SK_ADDR(fp)
  addi    a2, a2, KYBER_INDCPA_PUBLICKEYBYTES
  addi    a2, a2, KYBER_INDCPA_SECRETKEYBYTES
  li      t0, 8
  bn.wsrr w8, 0xA /* KECCAK_DIGEST */
  bn.sid  t0, 0(a2++) /* Store into buffer */

  /*** Random bytes ***/
  lw      a0, STACK_COINS_ADDR(fp)
  addi    a0, a0, 32 
  li      t0, 8
  bn.lid  t0, 0(a0)
  bn.sid  t0, 0(a2++) 

  /* Free space on stack */
  addi sp, fp, 0
  ret

/*
 * Name:        indcpa_enc_base
 *
 * Description: Encryption function of the CPA-secure
 *              public-key encryption scheme underlying Kyber.
 *
 * Arguments:   - uint8_t *c: pointer to output ciphertext
 *                            (of length KYBER_INDCPA_BYTES bytes)
 *              - const uint8_t *m: pointer to input message
 *                                  (of length KYBER_INDCPA_MSGBYTES bytes)
 *              - const uint8_t *pk: pointer to input public key
 *                                   (of length KYBER_INDCPA_PUBLICKEYBYTES)
 *              - const uint8_t *coins: pointer to input random coins used as seed
 *                                      (of length KYBER_SYMBYTES) to deterministically
 *                                      generate all randomness 
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (a0): dmem pointer to input message 
 * @param[in]  x11 (a1): dmem pointer to input packed pk
 * @param[in]  x12 (a2): dmem pointer to input coins 
 * @param[out] x13 (a3): dmem pointer to output ciphertext
 *
 * clobbered registers: a0-a4, t0-t5, w8, w16
 */

indcpa_enc_base:
  /* Stack address mapping */
  #define STACK_ENC_PK_ADDR      -24
  #define STACK_ENC_COINS_ADDR   -28
  #define STACK_ENC_C_ADDR       -32
  #define STACK_ENC_NONCE        -64
  #define STACK_ENC_SEED         -96
  #define STACK_ENC_V           -608
  #define STACK_ENC_TMP        -1120
#if (KYBER_K == 2)
  #define STACK_ENC_AT         -2144
    #define STACK_ENC_K        -2144
    #define STACK_ENC_B        -2144
    #define STACK_ENC_PKPV     -1632
    #define STACK_ENC_EPP      -1632
  #define STACK_ENC_SP         -3168
    #define STACK_ENC_EP       -3168 
#elif (KYBER_K == 3)
  #define STACK_ENC_AT         -2656
    #define STACK_ENC_K        -2656
    #define STACK_ENC_B        -2656
    #define STACK_ENC_PKPV     -2144
    #define STACK_ENC_EPP      -2144
  #define STACK_ENC_SP         -4192
    #define STACK_ENC_EP       -4192 
#elif (KYBER_K == 4)
  #define STACK_ENC_AT         -3168
    #define STACK_ENC_K        -3168
    #define STACK_ENC_B        -3168
    #define STACK_ENC_PKPV     -2656
    #define STACK_ENC_EPP      -2656
  #define STACK_ENC_SP         -5216
    #define STACK_ENC_EP       -5216 
#else 
#endif 

  /* Store parameters to stack */
  sw a2, STACK_ENC_COINS_ADDR(fp)

  /*** poly_frommsg ***/
  la  a1, modulus_over_2
  li  a2, STACK_ENC_K
  add a2, fp, a2 
  jal x1, poly_frommsg_base

  /*** unpack_pk ***/
  lw  a0, STACK_ENC_PK_ADDR(fp)
  la  a3, const_0x0fff
  jal x1, unpack_pk

  /*** save seed to dmem ***/
  li     x4, 0
  bn.lid x4, 0(a0)
  bn.sid x4, STACK_ENC_SEED(fp)

  /*** CBD sp ***/
  lw  a0, STACK_ENC_COINS_ADDR(fp)
  add a4, zero, a0
  li  a1, STACK_ENC_SP
  add a1, fp, a1
  li  a5, STACK_ENC_V  
  li  a3, STACK_ENC_NONCE
  li  a2, 0
  LOOPI KYBER_K, 5
    add  t1, fp, a5
    sw   a2, STACK_ENC_NONCE(fp)
    jal  x1, poly_getnoise_eta_1
    add  a0, zero, a4
    addi a2, a2, 1  

  /*** NTT ***/
  li  a0, STACK_ENC_SP 
  add a0, fp, a0
  add a2, zero, a0 
  .rept KYBER_K
    la  a1, twiddles_ntt_base
    jal x1, ntt_base_kyber
  .endr 

  /** v = sp * pkpv **/ 
  li   x29, STACK_ENC_PKPV 
  add  x29, fp, x29
  li   a1, STACK_ENC_SP 
  add  a1, fp, a1 
  li   a3, STACK_ENC_V
  add  a3, fp, a3
  la   x28, twiddles_ntt_base
  jal  x1, basemul_base_kyber
  .rept KYBER_K-1
    addi a3, a3, POLY
    la   x28, twiddles_ntt_base
    jal  x1, basemul_acc_base_kyber 
  .endr

  /*** reduce v ***/
  li  a0, STACK_ENC_V
  add a0, fp, a0
  la  a2, const_1290167
  jal x1, poly_reduce

  /*** INTT v ***/
  li  a0, STACK_ENC_V
  add a0, fp, a0 
  add a2, zero, a0 
  la  a1, twiddles_intt_base
  jal x1, intt_base_kyber

  /*** CBD epp ***/
  lw   a0, STACK_ENC_COINS_ADDR(fp)
  li   a1, STACK_ENC_EPP
  add  a1, fp, a1
  addi a2, zero, 2*KYBER_K
  sw   a2, STACK_ENC_NONCE(fp)
  li   a3, STACK_ENC_NONCE
  li   t1, STACK_ENC_TMP
  add  t1, fp, t1
  jal  x1, poly_getnoise_eta_2

  /** v = v + k + epp **/
  li   a0, STACK_ENC_K
  add  a0, fp, a0
  li   a1, STACK_ENC_V
  add  a1, fp, a1
  add  a2, zero, a1 
  jal  x1, poly_add_base
  addi a1, a1, POLY
  addi a2, a2, POLY
  jal  x1, poly_add_base

  /*** Matrix vector multiplication ***/
  li   a1, STACK_ENC_AT
  add  a1, fp, a1
  li   a2, 0
  .rept KYBER_K
    /* Gen 1st mat poly */
    addi a0, fp, STACK_ENC_SEED
    jal  x1, poly_gen_matrix
    addi a2, a2, 0x0100

    /* Mutliply this generated poly with sk */
    addi a1, a1, POLY /* point back to A[0][0] */
    li   x29, STACK_ENC_SP
    add  x29, fp, x29 /* point to sk[0] */
    add  a3, a1, x0   /* output at A[0][0] */
    la   x28, twiddles_ntt_base
    jal  x1, basemul_base_kyber
    .rept KYBER_K-1
      /* Gen next mat poly */
      addi a0, fp, STACK_ENC_SEED
      jal  x1, poly_gen_matrix
      addi a2, a2, 0x0100

      /* Mutliply this generated poly with sk */
      addi a1, a1, POLY /* points back to A[0][1] */
      addi a3, a1, POLY /* points back to A[0][0] for accumulation */
      la   x28, twiddles_ntt_base
      jal  x1, basemul_acc_base_kyber
      addi a1, a1, POLY /* points back to A[0][1] */
    .endr 
    addi a2, a2, KYBER_GEN_MATRIX_AT_NONCE 
  .endr

  /* reduce */
  li  a0, STACK_ENC_AT
  add a0, fp, a0
  la  a2, const_1290167
  .rept KYBER_K
    jal x1, poly_reduce
  .endr

  /*** INTT ***/
  li  a0, STACK_ENC_AT
  add a0, fp, a0 
  add a2, zero, a0 
  .rept KYBER_K
    la  a1, twiddles_intt_base
    jal x1, intt_base_kyber
  .endr 

  /*** CBD ep ***/
  lw  a0, STACK_ENC_COINS_ADDR(fp)
  li  a1, STACK_ENC_EP
  add a1, fp, a1
  add a4, zero, a0
  li  a5, STACK_ENC_TMP
  li  a3, STACK_ENC_NONCE
  li  a2, KYBER_K
  LOOPI KYBER_K, 5
    add  t1, fp, a5
    sw   a2, STACK_ENC_NONCE(fp)
    jal  x1, poly_getnoise_eta_2
    add  a0, zero, a4
    addi a2, a2, 1

  /*** ADD ***/
  /** b = b + ep **/
  li  a0, STACK_ENC_B
  add a0, fp, a0
  li  a1, STACK_ENC_EP
  add a1, fp, a1 
  add a2, zero, a0 
  .rept KYBER_K
    jal x1, poly_add_base 
  .endr 

  /*** pack_ciphertext ***/
  li   a0, STACK_ENC_B
  add  a0, fp, a0
  li   a1, STACK_ENC_V
  add  a1, fp, a1
  lw   a2, STACK_ENC_C_ADDR(fp)
  la   a3, const_1290167
  la   a5, modulus_over_2
  jal  x1, pack_ciphertext
  ret 

/*
 * Name:        crypto_kem_enc
 *
 * Description: Generates cipher text and shared
 *              secret for given public key
 *
 * Arguments:   - uint8_t *ct: pointer to output cipher text
 *                (an already allocated array of KYBER_CIPHERTEXTBYTES bytes)
 *              - uint8_t *ss: pointer to output shared secret
 *                (an already allocated array of KYBER_SSBYTES bytes)
 *              - const uint8_t *pk: pointer to input public key
 *                (an already allocated array of KYBER_PUBLICKEYBYTES bytes)
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (a0): dmem pointer to input randombytes (KYBER_SYMBYTES = 32)
 * @param[out] x11 (a1): dmem pointer to output ct
 * @param[out] x12 (a2): dmem pointer to output key_b 
 * @param[in]  x13 (a3): dmem pointer to input pk 
 *
 * clobbered registers: a0-a4, t0-t5, w8, w16
 */

.globl crypto_kem_enc
crypto_kem_enc: 
  #define STACK_KEM_ENC_KEYB_ADDR -20
  #define STACK_KEM_ENC_PK_ADDR   -24
  #define STACK_KEM_ENC_CT_ADDR   -32
  #define STACK_KEM_ENC_BUF     -1120
  #define STACK_KEM_ENC_KR      -1056

  /* Set frame pointer */
  addi fp, sp, 0 
#if KYBER_K == 2
    li  t0, -3168
#elif KYBER_K == 3
    li  t0, -4192
#elif KYBER_K == 4
    li  t0, -5216
#endif
  add  sp, sp, t0

  /* Save parameters to stack */
  sw a1, STACK_KEM_ENC_CT_ADDR(fp)
  sw a2, STACK_KEM_ENC_KEYB_ADDR(fp) 
  sw a3, STACK_KEM_ENC_PK_ADDR(fp)

  /*** Copy randombytes to buf ***/
  li     x4, 0
  bn.lid x4, 0(a0)
  li     t0, STACK_KEM_ENC_BUF
  add    t0, fp, t0 
  bn.sid x4, 0(t0++)
  add    a2, zero, t0 

  /*** hash_h(pk) ***/
  lw      a0, STACK_KEM_ENC_PK_ADDR(fp)
  addi    a1, zero, KYBER_PUBLICKEYBYTES
  slli    t0, a1, 5
  addi    t0, t0, SHA3_256_CFG
  csrrw   zero, KECCAK_CFG_REG, t0
  jal     x1, keccak_send_message
  li      t0, 8
  bn.wsrr w8, 0xA /* KECCAK_DIGEST */
  bn.sid  t0, 0(a2++) /* Store into buffer */

  /*** hash_g(randombytes||hash_h(pk)) ***/
  addi  a0, a2, -64 
  lw    a2, STACK_KEM_ENC_KEYB_ADDR(fp)
  addi  a1, zero, 64
  slli  t0, a1, 5
  addi  t0, t0, SHA3_512_CFG
  csrrw zero, KECCAK_CFG_REG, t0
  jal   x1, keccak_send_message
  li    t0, 8
  LOOPI 2, 2
    bn.wsrr w8, 0xA /* KECCAK_DIGEST */
    bn.sid  t0, 0(a2++) /* Store into buffer */

  /*** indcpa_enc ***/
  add a0, a0, -64 /* randombytes = m */
  add a2, a2, -32 /* r */
  jal x1, indcpa_enc_base

  /* Free space on stack */
  addi sp, fp, 0

  ret

/*
 * Name:        indcpa_dec_base
 *
 * Description: Decryption function of the CPA-secure
 *              public-key encryption scheme underlying Kyber.
 *
 * Arguments:   - uint8_t *m: pointer to output decrypted message
 *                            (of length KYBER_INDCPA_MSGBYTES)
 *              - const uint8_t *c: pointer to input ciphertext
 *                                  (of length KYBER_INDCPA_BYTES)
 *              - const uint8_t *sk: pointer to input secret key
 *                                   (of length KYBER_INDCPA_SECRETKEYBYTES) 
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (a0): dmem pointer to input ciphertext 
 * @param[in]  x11 (a1): dmem pointer to input packed sk
 * @param[out] x13 (a3): dmem pointer to output message
 *
 * clobbered registers: a0-a4, t0-t5, w8, w16
 */

indcpa_dec_base:
  /* Stack address mapping */
  #define STACK_DEC_M_ADDR     -32
#if (KYBER_K == 2)
  #define STACK_DEC_SKPV     -1056
  #define STACK_DEC_V        -1568
  #define STACK_DEC_B        -2592
#elif (KYBER_K == 3)
  #define STACK_DEC_SKPV     -1568
  #define STACK_DEC_V        -2080
  #define STACK_DEC_B        -3616
#elif (KYBER_K == 4)
  #define STACK_DEC_SKPV     -2080
  #define STACK_DEC_V        -2592
  #define STACK_DEC_B        -4640
#else 
#endif 

  /* Store parameters to stack */
  sw a3, STACK_DEC_M_ADDR(fp)
  
  /*** unpack_ciphertext ***/
  li  a2, STACK_DEC_B
  add a2, fp, a2 
  la  a3, const_8
  la  a4, modulus
  la  a5, const_0x0fff
  jal x1, unpack_ciphertext

  /*** unpack_sk ***/
  jal x1, unpack_sk

  /*** NTT ***/
  li  a0, STACK_DEC_B
  add a0, fp, a0 
  add a2, zero, a0 
  .rept KYBER_K 
    la  a1, twiddles_ntt_base
    jal x1, ntt_base_kyber
  .endr 

  /*** Vector vector multiplication ***/
  addi x29, a0, K_POLYS
  addi a1, a2, 512
  add  a3, zero, x29
  la   x28, twiddles_ntt_base
  jal  x1, basemul_base_kyber
  .rept KYBER_K-1
    addi a3, a3, POLY
    la   x28, twiddles_ntt_base
    jal  x1, basemul_acc_base_kyber 
  .endr 

  /* reduce */
  li  a0, STACK_DEC_B
  add a0, fp, a0
  la  a2, const_1290167
  jal x1, poly_reduce

  /*** INTT ***/
  add a0, a0, POLY 
  la  a1, twiddles_intt_base
  add a2, zero, a0 
  jal x1, intt_base_kyber

  /*** SUB ***/
  li   a0, STACK_DEC_V
  add  a0, fp, a0 
  addi a1, a2, POLY
  addi a2, a2, POLY 
  jal  x1, poly_sub_base 

  /*** poly_tomsg ***/
  addi a0, a1, POLY 
  la   a1, modulus_over_2
  lw   a2, STACK_DEC_M_ADDR(fp)
  la   a3, const_1290167
  jal  x1, poly_tomsg_base

  ret

/*
 * Name:        crypto_kem_dec
 *
 * Description: Generates shared secret for given
 *              cipher text and private key
 *
 * Arguments:   - uint8_t *ss: pointer to output shared secret
 *                (an already allocated array of KYBER_SSBYTES bytes)
 *              - const uint8_t *ct: pointer to input cipher text
 *                (an already allocated array of KYBER_CIPHERTEXTBYTES bytes)
 *              - const uint8_t *sk: pointer to input private key
 *                (an already allocated array of KYBER_SECRETKEYBYTES bytes)
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10 (a0): dmem pointer to input ct
 * @param[in]  x11 (a1): dmem pointer to input sk 
 * @param[out] x12 (a2): dmem pointer to output key_a
 *
 * clobbered registers: a0-a4, t0-t5, w8, w16
 */
.globl crypto_kem_dec
crypto_kem_dec:
  #define STACK_KEM_DEC_KEYA_ADDR -8
  #define STACK_KEM_DEC_H_ADDR   -12
  #define STACK_KEM_DEC_SK_ADDR  -16
  #define STACK_KEM_DEC_CT_ADDR  -20
  #define STACK_KEM_DEC_PK_ADDR  -24
  #define STACK_KEM_DEC_CMP_ADDR -32
#if (KYBER_K == 2)
  #define STACK_KEM_DEC_KR     -3232
  #define STACK_KEM_DEC_BUF    -3296
  #define STACK_KEM_DEC_CMP    -2144
#elif (KYBER_K == 3)
  #define STACK_KEM_DEC_KR     -4256
  #define STACK_KEM_DEC_BUF    -4320
  #define STACK_KEM_DEC_CMP    -2656
#elif (KYBER_K == 4)
  #define STACK_KEM_DEC_KR     -5280
  #define STACK_KEM_DEC_BUF    -5344
  #define STACK_KEM_DEC_CMP    -3168
#else 
#endif 
  /* Set frame pointer */
  addi fp, sp, 0 
#if KYBER_K == 2
    li  t0, -3296
#elif KYBER_K == 3
    li  t0, -4320
#elif KYBER_K == 4
    li  t0, -5344
#endif
  add  sp, sp, t0

  /* Save parameters to stack */ 
  sw   a0, STACK_KEM_DEC_CT_ADDR(fp)
  sw   a1, STACK_KEM_DEC_SK_ADDR(fp) 
  addi t0, a1, KYBER_INDCPA_SECRETKEYBYTES 
  sw   t0, STACK_KEM_DEC_PK_ADDR(fp)
  addi t0, t0, KYBER_INDCPA_PUBLICKEYBYTES
  sw   t0, STACK_KEM_DEC_H_ADDR(fp)
  sw   a2, STACK_KEM_DEC_KEYA_ADDR(fp)

  /*** indcpa_dec ***/ 
  li  a3, STACK_KEM_DEC_BUF
  add a3, fp, a3 
  jal x1, indcpa_dec_base

  /*** Copy hash_h(pk) to buf+32 ***/
  li     x4, 0
  lw     a0, STACK_KEM_DEC_H_ADDR(fp)
  li     a3, STACK_KEM_DEC_BUF
  add    a3, fp, a3 
  addi   a3, a3, 32
  bn.lid x4, 0(a0)
  bn.sid x4, 0(a3++)

  /*** hash_g(buf) ***/
  addi  a0, a3, -64  
  add   a2, zero, a3  
  addi  a1, zero, 64
  slli  t0, a1, 5
  addi  t0, t0, SHA3_512_CFG
  csrrw zero, KECCAK_CFG_REG, t0
  jal   x1, keccak_send_message
  li    t0, 8
  LOOPI 2, 2
    bn.wsrr w8, 0xA /* KECCAK_DIGEST */
    bn.sid  t0, 0(a2++) /* Store into buffer */

  /*** indcpa_enc ***/
  addi a0, a0, -64
  addi a2, a2, -32 
  li   a3, STACK_KEM_DEC_CMP
  add  a3, fp, a3 
  sw   a3, STACK_KEM_DEC_CMP_ADDR(fp)
  jal  x1, indcpa_enc_base

  /*** shake256(z||c,32) ***/
  addi    a1, zero, 32
  addi    a1, a1, KYBER_CIPHERTEXTBYTES
  slli    t0, a1, 5
  addi    t0, t0, SHAKE256_CFG
  csrrw   zero, KECCAK_CFG_REG, t0
  /* z */
  lw      a0, STACK_KEM_DEC_H_ADDR(fp)
  addi    a0, a0, 32
  addi    a1, zero, 32
  jal     x1, keccak_send_message
  /* cmp */
  lw      a0, STACK_KEM_DEC_CT_ADDR(fp)
  addi    a1, zero, KYBER_CIPHERTEXTBYTES
  jal     x1, keccak_send_message
  /* output buffer */
  li      a2, STACK_KEM_DEC_KR
  add     a2, fp, a2 
  addi    a2, a2, 32
  li      t0, 8
  bn.wsrr w8, 0xA /* KECCAK_DIGEST */
  bn.sid  t0, 0(a2++) /* Store into buffer */

  /*** verify: ct == cmp ? ***/
  li      t0, 0
  li      t1, 1
  lw      a0, STACK_KEM_DEC_CT_ADDR(fp)
  lw      a1, STACK_KEM_DEC_CMP_ADDR(fp)
  li      t2, 1
  bn.subi w2, w31, 1
  LOOPI KYBER_CIPHERTEXT_WRS, 8
    beq    t2, zero, _skip_verify
    bn.lid t0, 0(a0++)
    bn.lid t1, 0(a1++)
    bn.cmp w0, w1
    bn.sel w4, w31, w2, FG0.Z
    csrrw  t2, 0x7C0, zero 
    srl t2, t2, 3
_skip_verify:
    nop

  /*** cmov ***/
  li      a0, STACK_KEM_DEC_KR
  add     a0, fp, a0 
  bn.lid  t0, 0(a0++) /* load true key */
  bn.lid  t1, 0(a0)   /* load false key */
  bn.xor  w3, w0, w1 
  bn.and  w3, w3, w4 
  bn.xor  w0, w0, w3 
  lw      a0, STACK_KEM_DEC_KEYA_ADDR(fp) 
  bn.sid  t0, 0(a0) /* return key */

  ret
