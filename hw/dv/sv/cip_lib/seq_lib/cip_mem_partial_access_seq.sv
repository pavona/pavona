// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Shared partial-memory stimulus controls. Each request worker clones these controls before
// randomization, so outstanding accesses cannot change each other's address, data, or byte mask.
class cip_mem_partial_access_config_parameters extends dv_config_parameters;
  `uvm_object_utils_begin(cip_mem_partial_access_config_parameters)
    `uvm_field_int(max_mem_accesses, UVM_DEFAULT)
  `uvm_object_utils_end

  uint max_mem_accesses = 100_000;
  rand uint selection;
  rand uint req_abort_pct;
  rand bit write;
  rand bit [BUS_AW-1:0] addr;
  rand bit [BUS_DW-1:0] data;
  rand bit [BUS_DBW-1:0] mask;

  constraint memory_workload_c {
    req_abort_pct inside {[0:100]};
  }

  // Choose read or write before selecting from the different address sets.
  constraint choice_order_c {
    solve write before selection;
  }

  `uvm_object_new
endclass : cip_mem_partial_access_config_parameters

// Exercise memory byte enables and outstanding requests on one RAL interface. Write-response
// history selects the addresses and bytes for later reads; it is not an expected-data model.
// The common scoreboard uses monitored traffic to predict writes and check read data when
// cfg.en_scb_mem_chk is set, and to check response errors when cfg.en_scb_tl_err_chk is set.
// Those checks run independently of cfg.en_scb, which these common tests set to zero.
// Read-only windows are not written, and write-only windows are not read. Unsupported partial
// writes use a full mask. Request withdrawal remains part of the stimulus, not a DUT response.
//
// Both the standalone memory test and the mixed CSR/memory test use this finite workload.
// The child owns no reset, objection, or assertion setting. All workers run below body(), which
// the caller starts below main_thread(). Reset can terminate that complete subtree immediately.
// Written-address history and the outstanding-request limit belong to this invocation only.
class cip_mem_partial_access_seq #(
  type CFG_T = cip_base_env_cfg,
  type VIRTUAL_SEQUENCER_T = cip_base_virtual_sequencer
) extends dv_base_seq #(.CFG_T(CFG_T), .SEQUENCER_T(VIRTUAL_SEQUENCER_T));
  `uvm_object_param_utils(cip_mem_partial_access_seq #(CFG_T, VIRTUAL_SEQUENCER_T))
  `uvm_object_new

  typedef struct packed {
    bit [BUS_AW-1:0] addr;
    bit [BUS_DBW-1:0] mask;
  } addr_mask_t;

  string ral_name;
  dv_test_seq_parameters test_params;
  cip_mem_partial_access_config_parameters config_params;

  extern virtual task body();
  extern virtual function cip_mem_partial_access_config_parameters new_worker_config();
  extern virtual task run_memory_access(
      ref addr_mask_t written[$], ref uint reads, ref uint writes);
endclass : cip_mem_partial_access_seq

function cip_mem_partial_access_config_parameters
    cip_mem_partial_access_seq::new_worker_config();
  cip_mem_partial_access_config_parameters worker_config_params;
  // Preserve the caller's factory specialization and access limit without sharing random choices.
  `downcast(worker_config_params, config_params.clone())
  return worker_config_params;
endfunction : new_worker_config

task cip_mem_partial_access_seq::body();
  dv_base_reg_block block = cfg.ral_models[ral_name];
  addr_mask_t written[$];
  longint unsigned num_accesses = 0;
  uint reads = 0;
  uint writes = 0;
  semaphore slots = new(1 << BUS_AIW);

  if (block.mem_ranges.size() == 0) begin
    `uvm_info(`gfn, $sformatf("Partial memory: %s has no memory windows", ral_name), UVM_LOW)
    return;
  end
  foreach (block.mem_ranges[i]) begin
    if (get_mem_access_by_addr(block, block.mem_ranges[i].start_addr) != "RO") begin
      num_accesses += (block.mem_ranges[i].end_addr - block.mem_ranges[i].start_addr) >> 2;
    end
  end
  if (num_accesses > config_params.max_mem_accesses) begin
    num_accesses = config_params.max_mem_accesses;
  end
  if (num_accesses < 100) num_accesses = 100;

  `uvm_info(`gfn, $sformatf("Partial memory: %s windows=%0d attempts=%0d",
                           ral_name, block.mem_ranges.size(),
                           num_accesses * test_params.num_trans), UVM_LOW)
  // Bound request workers without a package-wide counter or a delta delay. Reset discards
  // this semaphore with its workers; no cancelled worker owes a key to the next epoch.
  repeat (num_accesses * test_params.num_trans) begin
    slots.get(1);
    fork
      begin
        run_memory_access(written, reads, writes);
        slots.put(1);
      end
    join_none
  end
  wait fork;
  `uvm_info(`gfn, $sformatf("Partial memory complete: %s reads=%0d writes=%0d",
                           ral_name, reads, writes), UVM_LOW)
endtask : body

task cip_mem_partial_access_seq::run_memory_access(
    ref addr_mask_t written[$], ref uint reads, ref uint writes);
  cip_mem_partial_access_config_parameters worker_config_params = new_worker_config();
  dv_base_reg_block block = cfg.ral_models[ral_name];
  addr_range_t ranges[$] = block.mem_ranges;
  cip_tl_host_single_seq tl_seq;
  bit [BUS_DBW-1:0] valid_mask = '1;
  bit [BUS_AW-1:0] access_addr;
  bit do_write;
  dv_base_mem mem;

  `DV_CHECK_RANDOMIZE_WITH_FATAL(worker_config_params,
      if (written.size() == 0) write == 1;
      if (write) selection < ranges.size();
      else       selection < written.size();)
  do_write = worker_config_params.write;
  if (do_write) begin
    uint index = worker_config_params.selection;
    `DV_CHECK_MEMBER_RANDOMIZE_WITH_FATAL(addr,
        addr inside {[ranges[index].start_addr:ranges[index].end_addr]};,
        worker_config_params)
    access_addr = worker_config_params.addr;
    if (get_mem_access_by_addr(block, access_addr) == "RO") return;
  end else begin
    access_addr = written[worker_config_params.selection].addr;
    valid_mask = written[worker_config_params.selection].mask;
    if (get_mem_access_by_addr(block, access_addr) == "WO") return;
  end
  `downcast(mem, get_mem_by_addr(block, access_addr))
  if (do_write && !mem.get_mem_partial_write_support()) begin
    worker_config_params.mask = '1;
  end else begin
    `DV_CHECK_MEMBER_RANDOMIZE_WITH_FATAL(mask,
        $countones(mask ^ {mask[BUS_DBW-2:0], 1'b0}) <= 2;
        (mask & ~valid_mask) == 0;,
        worker_config_params)
  end

  tl_seq = cip_tl_host_single_seq::type_id::create("tl_seq");
  tl_seq.req_abort_pct = worker_config_params.req_abort_pct;
  if (cfg.zero_delays) tl_seq.max_req_delay = 0;
  `DV_CHECK_RANDOMIZE_WITH_FATAL(tl_seq,
      addr == access_addr;
      write == do_write;
      mask == worker_config_params.mask;
      data == worker_config_params.data;)
  tl_seq.start(p_sequencer.tl_sequencer_hs[ral_name], this);

  // Keep address and byte-mask history so later reads select bytes written by this workload.
  // Add a write only after a completed response with no error; aborted or failed accesses
  // must not make new bytes eligible for reads. This history selects stimulus only.
  // It does not store expected data or prove that the DUT performed the write correctly.
  if (tl_seq.rsp.rsp_completed && !tl_seq.rsp.d_error) begin
    if (do_write) begin
      access_addr[1:0] = 0;
      written.push_back(addr_mask_t'{access_addr, worker_config_params.mask});
      writes++;
    end else begin
      reads++;
    end
  end
endtask : run_memory_access
