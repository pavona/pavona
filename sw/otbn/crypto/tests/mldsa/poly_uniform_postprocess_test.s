/* Copyright zeroRISC Inc. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Test for the postprocessing part of the poly_uniform subroutine of ML-DSA.
 *
 * This part gets some individual attention because there are certain corner
 * cases that would have a very low probability of occurring naturally with
 * SHAKE output (for example, needing to refresh the digest more than once,
 * which would only happen if more than 32 coefficients were bad).
 */

.section .text.start

main:
  /* Prepare all-zero register. */
  bn.xor w31, w31, w31

  /* Note: if details of poly_uniform change, this setup might also need to change. */

  /* Load the mask. */
  li      x11, 11
  la      x2, mask23
  bn.lid  x11, 0(x2)

  /* Load the vectorized modulus. */
  li      x12, 12
  la      x2, modulus
  bn.lid  x12, 0(x2)

  /* Load the mask. */
  li      x13, 13
  la      x2, mask8
  bn.lid  x13, 0(x2)

  /* Load the temp reg pointer. */
  li      x31, 21

  /* Set up a SHAKE128 operation with an empty input (just so there's digest to read). */
  li      x2, 0x2
  csrrw   x0, kmac_cfg, x2

  /* Run the first test. */
  la      x11, result1
  addi    x11, x11, 1024
  addi    x28, x11, 0
  bn.addi w14, w31, 0
  jal     x1, _poly_uniform_postprocess_test_entrypoint

  /* Reset SHAKE128 operation. */
  li      x2, 0x2
  csrrw   x0, kmac_cfg, x2

  /* Run the second test. */
  la      x11, result2
  addi    x11, x11, 1024
  addi    x28, x11, 0
  bn.addi w14, w31, 31
  jal     x1, _poly_uniform_postprocess_test_entrypoint

  ecall

.data
/* Mask used internally by poly_uniform. */
.balign 32
mask8:
  .word 0xff000000
  .word 0xff000000
  .word 0xff000000
  .word 0xff000000
  .word 0xff000000
  .word 0xff000000
  .word 0xff000000
  .word 0xff000000

/* Mask used internally by poly_uniform. */
.balign 32
mask23:
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff

/* Polynomial with all good coefficients except for the very last (this means
   no shifting of the polynomial is required and could cause a loop error if
   not properly handled). */
.balign 32
result2:
  .zero 1020
  .word 0x7fffff

/* Polynomial with specially crafted 23-bit coefficient candidates to test
   corner cases in postprocessing. */
.balign 32
result1:
  /* vector 0: specific corner cases of bad coefficients */
  /* modulus */
  .word 0x007fe001
  /* modulus + 1 */
  .word 0x007fe002
  /* 2^23 - 1 */
  .word 0x007fffff
  /* 2^23 - 2^12 */
  .word 0x007ff000
  /* modulus + 2 */
  .word 0x007fe003
  /* modulus + 2^12 */
  .word 0x007ff001
  /* fill out the rest of the word with good coefficients */
  .word 0x007fffff
  .word 0x007fffff
  /* vector 1: specific corner cases of good coefficients */
  /* modulus - 1 */
  .word 0x007fe000
  /* 0 */
  .word 0x00000000
  /* 1 */
  .word 0x00000001
  /* golden value used in later tests */
  .word 0x000abcde
  /* 2*modulus & 0x7fffff */
  .word 0x007fc002
  /* fill out the rest of the vector with good coefficients */
  .word 0x000abcde
  .word 0x000abcde
  .word 0x000abcde
  /* vector 2: all bad coefficients */
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
  /* vector 3: bad coefficients at the start and end */
  .word 0x007fffff
  .word 0x000abcde
  .word 0x000abcde
  .word 0x000abcde
  .word 0x000abcde
  .word 0x000abcde
  .word 0x000abcde
  .word 0x007fffff
  /* vector 4: bad coefficients in the middle */
  .word 0x000abcde
  .word 0x000abcde
  .word 0x000abcde
  .word 0x007fffff
  .word 0x007fffff
  .word 0x000abcde
  .word 0x000abcde
  .word 0x000abcde
  /* vector 5: bad/good interleaved */
  .word 0x007fffff
  .word 0x000abcde
  .word 0x007fffff
  .word 0x000abcde
  .word 0x007fffff
  .word 0x000abcde
  .word 0x007fffff
  .word 0x000abcde
  /* vector 6: good/bad interleaved */
  .word 0x000abcde
  .word 0x007fffff
  .word 0x000abcde
  .word 0x007fffff
  .word 0x000abcde
  .word 0x007fffff
  .word 0x000abcde
  .word 0x007fffff
  /* vector 7-31: all bad coefficients */
.rept 25
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
  .word 0x007fffff
.endr

/* From here on, constants needed by the poly library. */

/* Modulus for reduction */
.global modulus
modulus:
  .word 0x007fe001
  .word 0x007fe001
  .word 0x007fe001
  .word 0x007fe001
  .word 0x007fe001
  .word 0x007fe001
  .word 0x007fe001
  .word 0x007fe001

.global reduce32_const
reduce32_const:
    .word 0x1
    .word 0x1
    .word 0x1
    .word 0x1
    .word 0x1
    .word 0x1
    .word 0x1
    .word 0x1

.global power2round_D
power2round_D:
    .word 0xd
    .word 0xd
    .word 0xd
    .word 0xd
    .word 0xd
    .word 0xd
    .word 0xd
    .word 0xd
.global power2round_D_preprocessed
power2round_D_preprocessed:
    .word 0xfff
    .word 0xfff
    .word 0xfff
    .word 0xfff
    .word 0xfff
    .word 0xfff
    .word 0xfff
    .word 0xfff
#if DILITHIUM_MODE == 2
    #define ETA 2
#elif DILITHIUM_MODE == 3
    #define ETA 4
#elif DILITHIUM_MODE == 5
    #define ETA 2
#endif
.global eta
eta:
    .word ETA
    .word ETA
    .word ETA
    .word ETA
    .word ETA
    .word ETA
    .word ETA
    .word ETA
.global polyt0_pack_const
polyt0_pack_const:
    .word 0x1000
    .word 0x1000
    .word 0x1000
    .word 0x1000
    .word 0x1000
    .word 0x1000
    .word 0x1000
    .word 0x1000
.global decompose_const
decompose_const:
    .word 0x00002c0b
    .word 0x00002c0b
    .word 0x00002c0b
    .word 0x00002c0b
    .word 0x00002c0b
    .word 0x00002c0b
    .word 0x00002c0b
    .word 0x00002c0b
.global gamma1_vec_const
gamma1_vec_const:
    .word 0x00020000
    .word 0x00020000
    .word 0x00020000
    .word 0x00020000
    .word 0x00020000
    .word 0x00020000
    .word 0x00020000
    .word 0x00020000
.global gamma2_vec_const
gamma2_vec_const:
    .word 0x00017400
    .word 0x00017400
    .word 0x00017400
    .word 0x00017400
    .word 0x00017400
    .word 0x00017400
    .word 0x00017400
    .word 0x00017400
.global qm1half_const
qm1half_const:
    .word 0x003ff000
    .word 0x003ff000
    .word 0x003ff000
    .word 0x003ff000
    .word 0x003ff000
    .word 0x003ff000
    .word 0x003ff000
    .word 0x003ff000
.global decompose_127_const
decompose_127_const:
    .word 0x0000007f
    .word 0x0000007f
    .word 0x0000007f
    .word 0x0000007f
    .word 0x0000007f
    .word 0x0000007f
    .word 0x0000007f
    .word 0x0000007f
.global decompose_43_const
decompose_43_const:
    .word 0x0000002b
    .word 0x0000002b
    .word 0x0000002b
    .word 0x0000002b
    .word 0x0000002b
    .word 0x0000002b
    .word 0x0000002b
    .word 0x0000002b
.global polyeta_unpack_mask
polyeta_unpack_mask:
    .word 0x07
    .word 0x07
    .word 0x07
    .word 0x07
    .word 0x07
    .word 0x07
    .word 0x07
    .word 0x07
.global polyt1_unpack_mask
polyt1_unpack_mask:
    .word 0x3ff
    .word 0x3ff
    .word 0x3ff
    .word 0x3ff
    .word 0x3ff
    .word 0x3ff
    .word 0x3ff
    .word 0x3ff
.global polyt0_unpack_mask
polyt0_unpack_mask:
    .word 0x1fff
    .word 0x1fff
    .word 0x1fff
    .word 0x1fff
    .word 0x1fff
    .word 0x1fff
    .word 0x1fff
    .word 0x1fff
.global polyz_unpack_mask
polyz_unpack_mask:
    .word 0x3ffff
    .word 0x3ffff
    .word 0x3ffff
    .word 0x3ffff
    .word 0x3ffff
    .word 0x3ffff
    .word 0x3ffff
    .word 0x3ffff
.global poly_uniform_eta_205
poly_uniform_eta_205:
    .word 205
    .word 205
    .word 205
    .word 205
    .word 205
    .word 205
    .word 205
    .word 205
.global poly_uniform_eta_5
poly_uniform_eta_5:
    .word 5
    .word 5
    .word 5
    .word 5
    .word 5
    .word 5
    .word 5
    .word 5
.global poly_wdr2gpr
poly_wdr2gpr:
    .zero 32
