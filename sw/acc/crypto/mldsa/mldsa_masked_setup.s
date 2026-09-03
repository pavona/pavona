/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
 * Runtime population of the masked ML-DSA broadcast constant vectors from
 * mldsa_params.
 */

#define MLDSA_PARAM_K_OFFSET 0
#define MLDSA_PARAM_GAMMA1_MINUS_BETA_OFFSET 16
#define MLDSA_PARAM_GAMMA2_OFFSET 28
#define MLDSA_PARAM_GAMMA2_MINUS_BETA_OFFSET 32

#ifdef HARDENED
/**
 * Populate the single-symbol masked broadcast vectors from mldsa_params.
 * c_z/c_r need all 8 lanes written for DMEM integrity (secboundcheck reads
 * only lane 0).
 *
 * clobbered registers: x5 to x7, x10 to x11, x28
 * clobbered flag groups: none
 */
.globl _setup_masked_vectors
_setup_masked_vectors:
  la x10, mldsa_params

  /* gamma2_vec_const = broadcast(GAMMA2) */
  lw x5, MLDSA_PARAM_GAMMA2_OFFSET(x10)
  la x11, gamma2_vec_const
  loopi 8, 2
    sw   x5, 0(x11)
    addi x11, x11, 4
  endloop

  /* lambda0_z_vec = broadcast(GAMMA1_MINUS_BETA - 1) */
  lw   x5, MLDSA_PARAM_GAMMA1_MINUS_BETA_OFFSET(x10)
  addi x5, x5, -1
  la   x11, lambda0_z_vec
  loopi 8, 2
    sw   x5, 0(x11)
    addi x11, x11, 4
  endloop

  /* lambda0_r_vec = broadcast(GAMMA2_MINUS_BETA - 1) */
  lw   x5, MLDSA_PARAM_GAMMA2_MINUS_BETA_OFFSET(x10)
  addi x5, x5, -1
  la   x11, lambda0_r_vec
  loopi 8, 2
    sw   x5, 0(x11)
    addi x11, x11, 4
  endloop

  /* c_z_const = broadcast((1<<24) - 2*(GAMMA1_MINUS_BETA - 1) - 1) */
  lw   x5, MLDSA_PARAM_GAMMA1_MINUS_BETA_OFFSET(x10)
  addi x5, x5, -1
  slli x5, x5, 1
  li   x6, 0x1000000
  sub  x6, x6, x5
  addi x6, x6, -1
  la   x11, c_z_const
  loopi 8, 2
    sw   x6, 0(x11)
    addi x11, x11, 4
  endloop

  /* c_r_const = broadcast((1<<24) - 2*(GAMMA2_MINUS_BETA - 1) - 1) */
  lw   x5, MLDSA_PARAM_GAMMA2_MINUS_BETA_OFFSET(x10)
  addi x5, x5, -1
  slli x5, x5, 1
  li   x6, 0x1000000
  sub  x6, x6, x5
  addi x6, x6, -1
  la   x11, c_r_const
  loopi 8, 2
    sw   x6, 0(x11)
    addi x11, x11, 4
  endloop

  /* K selects the remaining vectors: gamma1 (2^17 for K==4 else 2^19),
   * polyz unpack mask, and eta (4 for K==6 else 2). */
  lw x7, MLDSA_PARAM_K_OFFSET(x10)

  li  x5, 524288
  li  x28, 4
  bne x7, x28, _smv_gamma_done
  li  x5, 131072
_smv_gamma_done:
  la x11, gamma1_vec_const
  loopi 8, 2
    sw   x5, 0(x11)
    addi x11, x11, 4
  endloop

  li  x5, 0xfffff
  li  x28, 4
  bne x7, x28, _smv_polyz
  li  x5, 0x3ffff
_smv_polyz:
  la x11, polyz_unpack_mask
  loopi 8, 2
    sw   x5, 0(x11)
    addi x11, x11, 4
  endloop

  li  x5, 2
  li  x28, 6
  bne x7, x28, _smv_eta
  li  x5, 4
_smv_eta:
  la x11, eta
  loopi 8, 2
    sw   x5, 0(x11)
    addi x11, x11, 4
  endloop

  ret
#endif
