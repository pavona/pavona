// Copyright lowRISC contributors (OpenTitan project).
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class kmac_app_host_seq extends kmac_app_base_seq;
  `uvm_object_utils(kmac_app_host_seq)

  `uvm_object_new

  // Default to send one data byte, can be overridden at a higher layer.
  // Must be set before this sequence is started.
  //
  // This also implicitly controls when the `last` signal is asserted.
  int unsigned msg_size_bytes = 1;
  int unsigned init_msg_size_bytes = 1;

  // AppIntf mode for generating first message
  kmac_app_e mode;

  // SHA3 configuration constraints
  rand sha3_pkg::sha3_mode_e sha3_mode;
  rand sha3_pkg::keccak_strength_e keccak_drive;
  rand bit [3:0] max_digest_word;

  // Set supported SHA3/Keccak Strength configurations
  constraint kmac_app_config_c {
    sha3_mode inside {kmac_pkg::AppSHA3, kmac_pkg::AppKMAC};
    keccak_drive inside {sha3_pkg::L128, sha3_pkg::L256, sha3_pkg::L512};

    if (sha3_mode == kmac_pkg::AppSHA3) {
      keccak_drive inside {sha3_pkg::L256, sha3_pkg::L512}; // SHA3-256/512
      if (keccak_drive == sha3_pkg::L256) {
        max_digest_word == 4'h1; // SHA3-256
      } else if (keccak_drive == sha3_pkg::L512) {
        max_digest_word == 4'h2; // SHA3-512
      }
    } else if (sha3_mode == kmac_pkg::AppKMAC) {
      keccak_drive inside {sha3_pkg::L128, sha3_pkg::L256}; // SHAKE-128/256
      max_digest_word inside {[4'h1:4'hF]}; // Any size digest
    }
  }

  // Helper function to organize the CFG word
  function bit [KmacDataIfWidth-1:0] get_header_word();
    bit [KmacDataIfWidth-1:0] word = '0; // Initialize header
    word[1:0] = sha3_mode; // Assign hash mode
    word[4:2] = keccak_drive; // Assign keccak strength
    return word;
  endfunction


  // Send the OTBN-specific header word
  virtual task send_header();

    // Create the CFG msg req with only first byte valid
    bit [KmacDataIfWidth-1:0] header_data = get_header_word();
    bit [KmacDataIfWidth/8-1:0] header_strb = 8'h01;
    bit header_last = 0;

    // Send to driver for push to interface
    push_pull_host_seq#(`CONNECT_DATA_WIDTH) header_seq;
    `uvm_create_on(header_seq, p_sequencer.m_push_pull_sequencer)
    `DV_CHECK_RANDOMIZE_FATAL(header_seq)

    cfg.m_data_push_agent_cfg.add_h_user_data({header_data, header_strb, header_last});
    `uvm_send(header_seq)
  endtask

  virtual task body();

    `uvm_info(`gfn, $sformatf("msg_size_bytes: %0d", msg_size_bytes), UVM_HIGH)

    cfg.m_data_push_agent_cfg.zero_delays = cfg.zero_delays;
    cfg.m_data_push_agent_cfg.host_delay_min = 1;
    cfg.m_data_push_agent_cfg.host_delay_max = 100;

    req = kmac_app_item::type_id::create("req");
    `DV_CHECK_RANDOMIZE_WITH_FATAL(req, byte_data_q.size() == msg_size_bytes;)
    `uvm_info(`gfn, $sformatf("Randomized req: %0s", req.sprint()), UVM_HIGH)
    `uvm_info(`gfn, $sformatf("byte_data_q: %0p", req.byte_data_q), UVM_HIGH)

    init_msg_size_bytes = msg_size_bytes;

    // If mode is OTBN send CFG
    if (mode == AppOtbn) begin
      cfg.vif.otbn_start = 1'b1;
      cfg.vif.max_per = max_digest_word;
      send_header();
    end

    while (msg_size_bytes > 0) begin

      bit [KmacDataIfWidth-1:0] req_data = '0;
      bit [KmacDataIfWidth/8-1:0] req_strb = '1;
      bit req_last = 0;

      // create push_pull_host_seq
      push_pull_host_seq#(`CONNECT_DATA_WIDTH) host_seq;
      `uvm_create_on(host_seq, p_sequencer.m_push_pull_sequencer)
      `DV_CHECK_RANDOMIZE_FATAL(host_seq)

      // Assemble the message chunk and strb
      for (int i = 0; i < KmacDataIfWidth / 8; i ++) begin
        if (msg_size_bytes == 0) break;

        if (cfg.inject_zero_in_host_strb) begin
          `DV_CHECK_STD_RANDOMIZE_WITH_FATAL(req_strb,
              ($countones(req_strb ^ {req_strb[KmacDataIfWidth/8-2:0], 1'b0}) <= 2);)
        end
        if (req_strb[i] == 1) begin
          req_data[i*8 +: 8] = 8'(req.byte_data_q.pop_front());
          req_strb[i] = 1'b1;
          msg_size_bytes -= 1;
        end else begin
          req_data[i*8 +: 8] = $urandom_range(0, (1'b1<<9)-1);
          req_strb[i] = 1'b0;
        end
      end

      // Set the last bit
      req_last = (msg_size_bytes == 0);

      cfg.m_data_push_agent_cfg.add_h_user_data({req_data, req_strb, req_last});

      `uvm_send(host_seq)

    end
  endtask

endclass
