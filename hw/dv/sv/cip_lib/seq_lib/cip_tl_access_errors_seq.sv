// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Choices for rejected TL accesses on one RAL interface. The standalone workload sends one
// batch without a trailing delay. A mixed workload can override the batch and delay constraints.
class cip_tl_access_errors_config_parameters extends dv_config_parameters;
  `uvm_object_utils_begin(cip_tl_access_errors_config_parameters)
    `uvm_field_int(instr_req_abort_en, UVM_DEFAULT)
    `uvm_field_int(instr_priority, UVM_DEFAULT)
    `uvm_field_int(check_instr_rsp, UVM_DEFAULT)
  `uvm_object_utils_end

  rand uint error_iterations;
  rand uint error_streams;
  rand uint error_transactions;
  rand uint error_gap_clks;
  rand tl_access_error_e error_kind;
  rand uint selection;
  rand uint instr_case;
  rand uint req_abort_pct;
  rand bit write;
  rand bit [BUS_AW-1:0] addr;
  rand bit [BUS_DW-1:0] data;
  rand bit [MuBi4Width-1:0] instr_type;

  // The standalone test preserves instruction requests until acceptance, sends them at normal
  // priority, and also checks d_error locally. The mixed workload permits withdrawal, uses low
  // priority, and omits this local check. Both rely on the existing scoreboard TL error checks,
  // which require cfg.en_scb_tl_err_chk independently of cfg.en_scb.
  bit instr_req_abort_en = 1'b0;
  int instr_priority = 100;
  bit check_instr_rsp = 1'b1;

  constraint error_iterations_c {
    error_iterations == 1;
  }

  constraint error_gap_clks_c {
    error_gap_clks == 0;
  }

  constraint error_workload_c {
    error_streams inside {[10:20]};
    error_transactions inside {[10:100]};
    req_abort_pct inside {[0:100]};
    instr_case inside {[0:2]};
  }

  // Select the instruction case before its address and encoding. The address space must not
  // bias the choice between malformed encodings, instruction writes, and forbidden fetches.
  constraint choice_order_c {
    solve instr_case before write, addr, instr_type;
    solve write before selection;
  }

  `uvm_object_new
endclass : cip_tl_access_errors_config_parameters

// Generate malformed or forbidden TL accesses.
// Response verification relies on the existing CIP scoreboard TL error checks, which require
// cfg.en_scb_tl_err_chk. This child also checks instruction responses locally when configured;
// its response counters do not verify other responses.
// RAL attributes select applicable error categories; memory cases are absent on CSR-only blocks.
// Concurrent streams exercise outstanding requests rather than only serial error responses.
// This child owns no reset, objection, assertion setting, or work outside body(). Its caller
// starts it below main_thread(), so destructive reset can terminate it and all request workers.
// Driver-aborted requests are not counted as DUT responses. This is not an integrity-fault test.
class cip_tl_access_errors_seq #(
  type CFG_T = cip_base_env_cfg,
  type VIRTUAL_SEQUENCER_T = cip_base_virtual_sequencer
) extends dv_base_seq #(.CFG_T(CFG_T), .SEQUENCER_T(VIRTUAL_SEQUENCER_T));
  `uvm_object_param_utils(cip_tl_access_errors_seq #(CFG_T, VIRTUAL_SEQUENCER_T))
  `uvm_object_new

  string ral_name;
  cip_tl_access_errors_config_parameters config_params;

  extern virtual task body();
  extern virtual function cip_tl_access_errors_config_parameters new_worker_config();
  extern virtual task run_error_stream(string ral_name, ref uint completed, ref uint errors);
  extern virtual task send_error_request(
      string ral_name, tl_host_single_seq #(cip_tl_seq_item) tl_seq,
      ref uint completed, ref uint errors, input bit instr_request = 1'b0);
endclass : cip_tl_access_errors_seq

function cip_tl_access_errors_config_parameters cip_tl_access_errors_seq::new_worker_config();
  cip_tl_access_errors_config_parameters worker_config_params;
  // Preserve factory constraints and non-random policy, but give each stream its own choices.
  // No stream can change a request that another stream is preparing.
  `downcast(worker_config_params, config_params.clone())
  return worker_config_params;
endfunction : new_worker_config

task cip_tl_access_errors_seq::body();
  cip_tl_access_errors_config_parameters worker_config_params = new_worker_config();
  uint completed = 0;
  uint errors = 0;

  `DV_CHECK_RANDOMIZE_FATAL(worker_config_params)
  `uvm_info(`gfn, $sformatf("TL access errors: %s iterations=%0d",
                           ral_name, worker_config_params.error_iterations), UVM_LOW)
  repeat (worker_config_params.error_iterations) begin
    `DV_CHECK_MEMBER_RANDOMIZE_FATAL(error_streams, worker_config_params)
    repeat (worker_config_params.error_streams) begin
      fork
        run_error_stream(ral_name, completed, errors);
      join_none
    end
    wait fork;
    if (worker_config_params.error_gap_clks != 0) begin
      delay_seq del_seq = delay_seq::type_id::create("del_seq");
      `DV_CHECK_MEMBER_RANDOMIZE_FATAL(error_gap_clks, worker_config_params)
      del_seq.delay_time_steps = worker_config_params.error_gap_clks;
      del_seq.start(p_sequencer.delay_sequencer_h, this);
    end
  end
  `uvm_info(`gfn, $sformatf("TL access errors complete: %s responses=%0d d_error=%0d",
                           ral_name, completed, errors), UVM_LOW)
endtask : body

task cip_tl_access_errors_seq::send_error_request(
    string ral_name, tl_host_single_seq #(cip_tl_seq_item) tl_seq,
    ref uint completed, ref uint errors, input bit instr_request);
  int seq_priority = instr_request ? config_params.instr_priority : 1;
  if (cfg.zero_delays) tl_seq.max_req_delay = 0;
  tl_seq.start(p_sequencer.tl_sequencer_hs[ral_name], this, seq_priority);
  // Count only requests with completed responses, not requests withdrawn by the driver.
  // The counters below are diagnostic. General response verification requires the existing
  // scoreboard TL error checks to be enabled through cfg.en_scb_tl_err_chk; cfg.en_scb does
  // not gate those checks. The optional local check covers instruction requests only.
  if (tl_seq.rsp.rsp_completed) begin
    if (instr_request && config_params.check_instr_rsp) begin
      `DV_CHECK_EQ(tl_seq.rsp.d_error, 1'b1,
                   $sformatf("Instruction error request was not rejected on %s", ral_name))
    end
    if (completed == 0) begin
      `uvm_info(`gfn, $sformatf("TL access errors: %s first DUT response d_error=%0b",
                               ral_name, tl_seq.rsp.d_error), UVM_LOW)
    end
    completed++;
    if (tl_seq.rsp.d_error) errors++;
  end
endtask : send_error_request

task cip_tl_access_errors_seq::run_error_stream(
    string ral_name, ref uint completed, ref uint errors);
  cip_tl_access_errors_config_parameters worker_config_params = new_worker_config();
  dv_base_reg_block block = cfg.ral_models[ral_name];
  tl_access_error_e kinds[$] = '{TlAccessProtocolError, TlAccessInstrTypeError};
  addr_range_t ranges[$];
  bit has_mem_mask, has_wo_mem, has_ro_mem;
  bit [BUS_AW-1:0] base_addr = block.default_map.get_base_addr();
  bit [BUS_AW-1:0] addr_mask = block.get_addr_mask();
  tl_access_error_e kind;
  uint num_requests;

  addr_mask[1:0] = 0;
  get_all_mem_attrs(block, has_mem_mask, has_wo_mem, has_ro_mem);
  if (block.csr_addrs.size() > 0) kinds.push_back(TlAccessCsrMaskError);
  if (block.has_unmapped_addrs) kinds.push_back(TlAccessUnmappedError);
  if (has_mem_mask) kinds.push_back(TlAccessMemMaskError);
  if (has_wo_mem) kinds.push_back(TlAccessWriteOnlyError);
  if (has_ro_mem) kinds.push_back(TlAccessReadOnlyError);
  `DV_CHECK_RANDOMIZE_WITH_FATAL(worker_config_params, error_kind inside {kinds};)
  kind = worker_config_params.error_kind;
  num_requests = worker_config_params.error_transactions;
  `uvm_info(`gfn, $sformatf("TL access error stream: %s kind=%s", ral_name, kind.name()),
            UVM_HIGH)

  if (kind == TlAccessCsrMaskError) begin
    dv_base_reg csrs[$];
    block.get_dv_base_regs(csrs);
    csrs.shuffle();
    foreach (csrs[i]) begin
      tl_host_custom_seq #(cip_tl_seq_item) tl_seq;
      bit [BUS_AW-1:0] csr_addr = csrs[i].get_address();
      bit [BUS_DBW-1:0] required_mask = (1 << (csrs[i].get_msb_pos() / 8 + 1)) - 1;
      // Some registers deliberately accept error writes. Do not change their contents outside
      // the CSR leaf's prediction path while its reads and writes are running concurrently.
      if (csrs[i].writes_ignore_errors) continue;
      tl_seq = tl_host_custom_seq#(cip_tl_seq_item)::type_id::create("tl_seq");
      `DV_CHECK_MEMBER_RANDOMIZE_FATAL(req_abort_pct, worker_config_params)
      tl_seq.req_abort_pct = worker_config_params.req_abort_pct;
      `DV_CHECK_RANDOMIZE_WITH_FATAL(tl_seq,
          opcode inside {PutFullData, PutPartialData};
          addr == csr_addr;
          (mask & required_mask) != required_mask;)
      send_error_request(ral_name, tl_seq, completed, errors);
    end
    return;
  end

  if (kind == TlAccessUnmappedError) begin
    foreach (block.unmapped_addr_ranges[i]) begin
      ranges.push_back(addr_range_t'{block.unmapped_addr_ranges[i].start_addr - base_addr,
                                    block.unmapped_addr_ranges[i].end_addr - base_addr});
    end
  end else if (kind inside {TlAccessMemMaskError, TlAccessWriteOnlyError,
                           TlAccessReadOnlyError}) begin
    foreach (block.mem_ranges[i]) begin
      dv_base_mem mem;
      `downcast(mem, get_mem_by_addr(block, block.mem_ranges[i].start_addr))
      if ((kind == TlAccessMemMaskError && !mem.get_mem_partial_write_support()) ||
          (kind == TlAccessWriteOnlyError && mem.get_access() == "WO") ||
          (kind == TlAccessReadOnlyError && mem.get_access() == "RO")) begin
        ranges.push_back(addr_range_t'{block.mem_ranges[i].start_addr - base_addr,
                                      block.mem_ranges[i].end_addr - base_addr});
      end
    end
  end

  repeat (num_requests) begin
    tl_host_single_seq #(cip_tl_seq_item) tl_seq;
    `DV_CHECK_MEMBER_RANDOMIZE_FATAL(req_abort_pct, worker_config_params)
    case (kind)
      TlAccessProtocolError: begin
        tl_seq = tl_host_protocol_err_seq#(cip_tl_seq_item)::type_id::create("tl_seq");
        tl_seq.req_abort_pct = worker_config_params.req_abort_pct;
        `DV_CHECK_RANDOMIZE_FATAL(tl_seq)
      end
      TlAccessInstrTypeError: begin
        cip_tl_host_single_seq instr_seq;
        bit has_nofetch_csrs = block.csr_addrs.size() > 0 && !block.get_allows_csr_fetch();
        `DV_CHECK_RANDOMIZE_WITH_FATAL(worker_config_params,
            if (!has_nofetch_csrs) instr_case != 2;
            if (instr_case == 0) !(instr_type inside {MuBi4True, MuBi4False});
            else instr_type == MuBi4True;
            if (instr_case == 1) write == 1;
            if (instr_case == 2) {
              write == 0;
              addr inside {block.csr_addrs};
            })
        instr_seq = cip_tl_host_single_seq::type_id::create("instr_seq");
        instr_seq.req_abort_pct = worker_config_params.instr_req_abort_en ?
                                 worker_config_params.req_abort_pct : 0;
        `DV_CHECK_RANDOMIZE_WITH_FATAL(instr_seq,
            addr == worker_config_params.addr;
            write == worker_config_params.write;
            data == worker_config_params.data;
            mask == '1;
            instr_type == worker_config_params.instr_type;)
        tl_seq = instr_seq;
      end
      default: begin
        uint index;
        `DV_CHECK_GT_FATAL(ranges.size(), 0)
        `DV_CHECK_MEMBER_RANDOMIZE_WITH_FATAL(selection,
            selection < ranges.size();, worker_config_params)
        index = worker_config_params.selection;
        tl_seq = tl_host_custom_seq#(cip_tl_seq_item)::type_id::create("tl_seq");
        tl_seq.req_abort_pct = worker_config_params.req_abort_pct;
        `DV_CHECK_RANDOMIZE_WITH_FATAL(tl_seq,
            (addr & addr_mask) inside {[ranges[index].start_addr:ranges[index].end_addr]};
            if (kind == TlAccessMemMaskError) {
              opcode inside {PutFullData, PutPartialData};
              addr[1:0] == 0;
              mask != '1 || size < 2;
            }
            if (kind == TlAccessWriteOnlyError) opcode == Get;
            if (kind == TlAccessReadOnlyError) opcode != Get;)
      end
    endcase
    send_error_request(ral_name, tl_seq, completed, errors, kind == TlAccessInstrTypeError);
  end
endtask : run_error_stream
