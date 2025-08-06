// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

package otbn_app_agent_pkg;
  // dep packages
  import uvm_pkg::*;
  import dv_utils_pkg::*;
  import dv_lib_pkg::*;
  import keymgr_pkg::*;
  import push_pull_agent_pkg::*;
  import kmac_pkg::*;
  import kmac_app_agent_pkg::*;

  // macro includes
  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  parameter int KMAC_REQ_DATA_WIDTH = keymgr_pkg::KmacDataIfWidth       // data width
                                      + keymgr_pkg::KmacDataIfWidth / 8 // data mask width
                                      + 1;                              // bit last

  parameter int KMAC_RSP_DATA_WIDTH = kmac_pkg::AppDigestW    // digest share 0
                                      + kmac_pkg::AppDigestW; // digest share 1

  // MSG FIFO size in bytes
  parameter int MSG_FIFO_SIZE_BYTES = kmac_pkg::MsgFifoDepth * 8;
  parameter int MSG_PACKER_SIZE_BYTES = 2 * 8;

  // If the packer in the Keccak MSG FIFO fills up completely, it must flush
  // before it can consume new data.
  parameter int MSG_FIFO_PACKER_FLUSH_LATENCY = 2;

  // Cycles for a Keccak round
  parameter int KECCAK_CYCLES_PER_ROUND = 4;
  parameter int KECCAK_NUM_ROUNDS = 24;

  // It takes 3 cycles until the finished digest is exposed to the application interface.
  parameter int KECCAK_LATENCY_DIGEST_EXPOSED = 3;

  // It takes 2 additional cycles when the Keccak permutation logic is done
  // for operations to continue (e.g. padding logic to resume)
  parameter int KECCAK_LATENCY_DONE = 2;

  // After setting the KMAC_CFG register, it takes two cycles until the KMAC_STATUS
  // register changes its value to ready.
  parameter int APP_INTF_READY_LATENCY = 2;

  // If a new chunk of the digest is requested for the DIGEST REG, there is a delay of
  // X cycles.
  parameter int SHIFT_DIGEST_LATENCY = 1;

  parameter int NEW_PERMUTATION_LATENCY = KECCAK_CYCLES_PER_ROUND * KECCAK_NUM_ROUNDS
                                          + KECCAK_LATENCY_DIGEST_EXPOSED + SHIFT_DIGEST_LATENCY;

  parameter int KECCAK_NOT_ABSORBED_LATENCY = KECCAK_CYCLES_PER_ROUND * KECCAK_NUM_ROUNDS + KECCAK_LATENCY_DONE;

  parameter int KECCAK_ABSORBED_LATENCY = KECCAK_CYCLES_PER_ROUND * KECCAK_NUM_ROUNDS + KECCAK_LATENCY_DIGEST_EXPOSED;

  `define CONNECT_DATA_WIDTH .HostDataWidth(otbn_app_agent_pkg::KMAC_RSP_DATA_WIDTH)

  // package sources
  `include "otbn_app_item.sv"
  `include "otbn_app_agent_cfg.sv"
  `include "otbn_app_sequencer.sv"
  `include "otbn_app_base_seq.sv"
  `include "otbn_app_agent_cov.sv"
  `include "otbn_app_driver.sv"
  `include "otbn_app_monitor.sv"
  `include "otbn_app_agent.sv"

endpackage: otbn_app_agent_pkg
