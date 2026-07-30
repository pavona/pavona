// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Device responder that deliberately holds responses until the requested
// number of A-channel requests has been accepted.
class ${module_instance_name}_gated_tl_device_seq extends cip_tl_device_seq;
  `uvm_object_utils(${module_instance_name}_gated_tl_device_seq)

  int unsigned gate_count = 1;
  uvm_event collected_ev;
  uvm_event release_ev;

  function new(string name = "");
    super.new(name);
    collected_ev = new("collected_ev");
    release_ev = new("release_ev");
  endfunction : new

  protected virtual task send_response_thread();
    wait (req_q.size() >= gate_count);
    collected_ev.trigger();
    release_ev.wait_on();
    super.send_response_thread();
  endtask : send_response_thread
endclass : ${module_instance_name}_gated_tl_device_seq

class ${module_instance_name}_fixed_addr_tl_host_seq
    extends tl_host_seq #(cip_tl_seq_item);
  `uvm_object_utils(${module_instance_name}_fixed_addr_tl_host_seq)

  bit [AddrWidth-1:0] fixed_addr;

  function new(string name = "");
    super.new(name);
  endfunction : new

  virtual function void randomize_req(cip_tl_seq_item req, int idx);
    if (!(req.randomize() with {
          a_addr == local::fixed_addr;
          a_opcode == tlul_pkg::Get;
          a_size == 2;
          a_mask == '1;
          a_valid_delay == 0;
        })) begin
      `uvm_fatal(`gfn, "Cannot randomize fixed-address request")
    end
    req.set_instr_type(MuBi4False, 0);
  endfunction : randomize_req
endclass : ${module_instance_name}_fixed_addr_tl_host_seq

class ${module_instance_name}_tl_cov_test_seq_parameters
    extends ${module_instance_name}_base_test_seq_parameters;
  `uvm_object_utils(${module_instance_name}_tl_cov_test_seq_parameters)

  constraint reset_enable_c {
    reset_testing == ENABLE;
  }

  constraint reset_loops_c {
    num_reset_loops == 2;
  }

  function new(string name = "");
    super.new(name);
    do_dut_init = 1'b0;
    do_${module_instance_name}_init = 1'b0;
  endfunction : new
endclass : ${module_instance_name}_tl_cov_test_seq_parameters

// Closes legal outstanding, same-address, pending-on-reset, and downstream
// response-error coverage for the AC datapath TileLink agents.
class ${module_instance_name}_rst_safe_tl_cov_vseq
    extends ${module_instance_name}_rst_safe_cov_base_vseq;
  `uvm_object_utils(${module_instance_name}_rst_safe_tl_cov_vseq)

  uvm_event reset_ready_ev;
  int unsigned epoch;

  extern function new(string name = "");
  extern virtual task body();
  extern virtual task reset_trigger_thread();
  extern virtual task main_thread();
  extern virtual task start_gated_responder(
      ${module_instance_name}_gated_tl_device_seq device_seq);
endclass : ${module_instance_name}_rst_safe_tl_cov_vseq

function ${module_instance_name}_rst_safe_tl_cov_vseq::new(string name = "");
  super.new(name);
  reset_ready_ev = new("reset_ready_ev");
endfunction : new

task ${module_instance_name}_rst_safe_tl_cov_vseq::body();
  if (test_params == null) begin
    test_params = ${module_instance_name}_tl_cov_test_seq_parameters::type_id::create(
        "test_params");
  end
  if (config_params == null) begin
    config_params = ${module_instance_name}_base_config_parameters::type_id::create(
        "config_params");
  end
  super.body();
endtask : body

task ${module_instance_name}_rst_safe_tl_cov_vseq::reset_trigger_thread();
  reset_seq rst_seq;

  reset_ready_ev.wait_on();
  reset_ready_ev.reset();
  rst_seq = reset_seq::type_id::create("rst_seq");
  rst_seq.start(p_sequencer.clk_rst_sequencer_h);
endtask : reset_trigger_thread

task ${module_instance_name}_rst_safe_tl_cov_vseq::start_gated_responder(
    ${module_instance_name}_gated_tl_device_seq device_seq);
  `DV_CHECK_RANDOMIZE_FATAL(device_seq)
  fork
    device_seq.start(p_sequencer.tl_filt_sqr);
  join_none
endtask : start_gated_responder

task ${module_instance_name}_rst_safe_tl_cov_vseq::main_thread();
  initialize_directed_inputs();
  configure_fixed_range(0);
  configure_fixed_range(1);

  if (epoch == 0) begin
    ${module_instance_name}_gated_tl_device_seq burst_device_seq;
    ${module_instance_name}_fixed_addr_tl_host_seq burst_host_seq;
    ${module_instance_name}_gated_tl_device_seq pending_device_seq;
    ${module_instance_name}_fixed_addr_tl_host_seq pending_host_seq;

    burst_device_seq = ${module_instance_name}_gated_tl_device_seq::type_id::create(
        "burst_device_seq");
    burst_device_seq.gate_count = 16;
    burst_device_seq.min_rsp_delay = 0;
    burst_device_seq.max_rsp_delay = 0;
    burst_device_seq.rsp_abort_pct = 0;
    start_gated_responder(burst_device_seq);

    burst_host_seq = ${module_instance_name}_fixed_addr_tl_host_seq::type_id::create(
        "burst_host_seq");
    burst_host_seq.req_cnt = 16;
    burst_host_seq.fixed_addr = range_base_addr(0);
    burst_host_seq.min_req_delay = 0;
    burst_host_seq.max_req_delay = 0;
    fork
      burst_host_seq.start(p_sequencer.tl_unfilt_sqr);
      begin
        burst_device_seq.collected_ev.wait_on();
        burst_device_seq.release_ev.trigger();
      end
    join

    // The pending queue is now empty, so a different address samples the
    // falling same-address transition before this responder is stopped.
    send_access(1, Read);
    burst_device_seq.seq_stop();

    pending_device_seq = ${module_instance_name}_gated_tl_device_seq::type_id::create(
        "pending_device_seq");
    pending_device_seq.gate_count = 1;
    start_gated_responder(pending_device_seq);
    pending_host_seq = ${module_instance_name}_fixed_addr_tl_host_seq::type_id::create(
        "pending_host_seq");
    pending_host_seq.req_cnt = 1;
    pending_host_seq.fixed_addr = range_base_addr(0);
    fork
      pending_host_seq.start(p_sequencer.tl_unfilt_sqr);
    join_none
    pending_device_seq.collected_ev.wait_on();

    epoch++;
    reset_ready_ev.trigger();
    // The reset-safe base must kill this thread. Returning as reset asserts
    // is diagnosed as the main thread finishing before reset control.
    wait (1'b0);
  end else begin
    // A granted request propagates a downstream d_error unchanged.
    start_filtered_responder(.d_error_pct(100));
    send_access(0, Read);
    epoch++;
  end
endtask : main_thread
