// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
#ifndef OPENTITAN_HW_IP_ACC_DV_MODEL_ACC_MODEL_DPI_H_
#define OPENTITAN_HW_IP_ACC_DV_MODEL_ACC_MODEL_DPI_H_

// The DPI exports for AccModel. See also acc_model_dpi.svh, where
// they are declared for the SystemVerilog side.
//
// These are defined in a separate file from acc_model.h because otherwise
// something like acc_top_sim.cc will see both these defines and the
// auto-generated ones that Verilator produces in e.g. Vacc_top_sim__Dpi.h. The
// latter use void* for all the chandle arguments and some versions of GCC treat
// the resulting signatures as incompatible.

extern "C" {

// Create an AccModel object. Will always succeed.
AccModel *acc_model_init(const char *mem_scope, const char *design_scope);

// Delete an AccModel
void acc_model_destroy(AccModel *model);

// Take loop warps from an AccMemUtil
void acc_take_loop_warps(AccModel *model, AccMemUtil *memutil);

// Returns non-zero if an AccMemUtil contains loop warps
int acc_has_loop_warps(AccMemUtil *memutil);

// Flush URND and RND EDN data from model because of edn_rst_n signal. Returns
// 0 on success; -1 on error.
int acc_model_edn_flush(AccModel *model);

// Call edn_rnd_step function of AccModel. Returns 0 on success; -1 on error.
int acc_model_edn_rnd_step(AccModel *model,
                            svLogicVecVal *edn_rnd_data /* logic [31:0] */,
                            unsigned char fips_err);

// Call edn_urnd_step function of AccModel. Returns 0 on success; -1 on error.
int acc_model_edn_urnd_step(AccModel *model,
                             svLogicVecVal *edn_urnd_data /* logic [31:0] */);

// Signal RTL is finished processing RND data to Model. Returns 0 on success;
// -1 on error.
int acc_model_rnd_cdc_done(AccModel *model);

// Signal RTL is finished processing EDN data for URND to Model. Returns 0 on
// success; -1 on error.
int acc_model_urnd_cdc_done(AccModel *model);

// Signal RTL is finished processing OTP key to the Model. Returns 0 on
// success; -1 on error.
int acc_model_otp_key_cdc_done(AccModel *model);

// Pass keymgr data to model. Returns 0 on success; -1 on error.
int acc_model_set_keymgr_value(AccModel *model, svLogicVecVal *key0,
                                svLogicVecVal *key1, unsigned char valid);

// The main entry point to the ACC model, exported from here and used in
// acc_core_model.sv.
//
// This communicates state with acc_core_model.sv through the model_state
// parameter, which has the following bits:
//
//    Bit 0:      running       True if the model is currently running
//    Bit 1:      check_due     True if the model finished running last cycle
//    Bit 2:      failed_step   Something failed when trying to start/step ISS
//
// The acc_model_step function should only be called when either the model is
// running (bit 0 of model_state), has a check due (bit 1 of model_state), or
// when start is asserted. At other times, it will return immediately (but
// wastes a DPI call).
//
// If the model is running and start is false, acc_model_step steps the ISS by
// a single cycle. If something goes wrong, it will set failed_step to true and
// running to false. Otherwise, it writes the new value of acc.INSN_CNT to
// *insn_cnt.
//
// If nothing goes wrong and the ISS finishes its run, we set running to false,
// write out err_bits and stop_pc and set check_due to ensure acc_model_check
// runs on the next negedge of the clock.
//
unsigned acc_model_step(AccModel *model, unsigned model_state,
                         svBitVecVal *cmd /* bit [7:0] */,
                         svBitVecVal *status /* bit [7:0] */,
                         svBitVecVal *insn_cnt /* bit [31:0] */,
                         svBitVecVal *rnd_req /* bit [0:0] */,
                         svBitVecVal *err_bits /* bit [31:0] */,
                         svBitVecVal *stop_pc /* bit [31:0] */);

// This gets run if the acc_model_step function sets the check_due bit in its
// model_state bitfield (see above). If the model's design_scope is non-empty,
// it should be the scope of an RTL implementation. In that case, we compare
// register and memory contents with that implementation, printing to stderr
// and setting the failed_cmp bit if there are any mismatches. If the model's
// design_scope is the empty string, we grab the contents of DMEM from the ISS
// and inject them into the simulation memory.
//
// Returns 1 on success; 0 on failure.
int acc_model_check(AccModel *model, svBitVecVal *mismatch /* bit [0:0] */);

// Tell the model to mark all of IMEM as invalid so that any fetch causes an
// integrity error. Returns 0 on success or -1 on failure.
int acc_model_invalidate_imem(AccModel *model);

// Tell the model to mark all of DMEM as invalid so that any load causes an
// integrity error. Returns 0 on success or -1 on failure.
int acc_model_invalidate_dmem(AccModel *model);

// Tell the model to set software_errs_fatal bit in ctrl register. Once this bit
// is set, any software error will be elevated to fatal error from recoverable
// error.
int acc_model_set_software_errs_fatal(AccModel *model, unsigned char new_val);

// Tell the model to not execute checks to see if secure wiping has written
// random data to all registers before wiping them with zeroes.
int acc_set_no_sec_wipe_chk(AccModel *model);

// Disable stack integrity checks
int acc_disable_stack_check(AccModel *model);

// Step the CRC calculation for item
//
// state is an inout parameter and should be updated in-place. This is
// a "pure" function: there isn't actually any model state that gets
// updated by calling it. Returns 0 on success or -1 on failure.
int acc_model_step_crc(AccModel *model, svBitVecVal *item /* bit [47:0] */,
                        svBitVecVal *state /* inout bit [31:0] */);

// Flush any information in the model. Returns 0 on success; -1 on error.
int acc_model_reset(AccModel *model, svBitVecVal *status /* bit [7:0] */,
                     svBitVecVal *insn_cnt /* bit [31:0] */,
                     svBitVecVal *rnd_req /* bit [0:0] */,
                     svBitVecVal *err_bits /* bit [31:0] */,
                     svBitVecVal *stop_pc /* bit [31:0] */);

// React to an error escalation. Returns 0 on success or -1 on failure.
int acc_model_send_err_escalation(AccModel *model,
                                   svBitVecVal *err_val /* bit [31:0] */,
                                   svBit lock_immediately);

// Send an RMA request value to the model
int acc_model_set_rma_req(AccModel *model,
                           svBitVecVal *rma_req /* bit [3:0] */);

// Trigger initial secure wipe.
int acc_model_initial_secure_wipe(AccModel *model);
}

#endif  // OPENTITAN_HW_IP_ACC_DV_MODEL_ACC_MODEL_DPI_H_
