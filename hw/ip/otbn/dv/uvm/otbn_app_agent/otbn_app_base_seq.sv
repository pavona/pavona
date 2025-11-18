// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class otbn_app_base_seq extends dv_base_seq #(
    .REQ         (otbn_app_item),
    .RSP         (otbn_app_item),
    .CFG_T       (otbn_app_agent_cfg),
    .SEQUENCER_T (otbn_app_sequencer)
  );

  `uvm_object_utils(otbn_app_base_seq)
  `uvm_object_new

  virtual task body();
    otbn_app_item item;

    // Status bits to determine response digest behavior
    bit finish_seq = 0;
    bit saw_first_rsp = 0;
    bit should_send_rsp = 0;

    // Response digest shares
    bit [255:0] digest_lsb_share0 = 0;
    bit [255:0] digest_lsb_share1 = 0;

    // KMAC config from first req word
    sha3_pkg::keccak_strength_e strength;
    sha3_pkg::sha3_mode_e hash_mode;
    byte cfg_word;

    // Cast to an array so we can pass this into the DPI functions
    bit [7:0] msg_arr[];
    int msg_size = 0;

    // Array to hold the digest calculated by DPI model
    bit [7:0] dpi_digest[];

    // Set this to the calculated output length for XOFs
    int output_len_bytes = 0;
    int output_wrd_cnt = 0;
    int start_idx = 0;

    // Used to determine when a new keccak round is run
    // Need to model the KMAC delay to run lockstep with python simulation
    int keccak_rate       = 0;
    int keccak_state_size = 0;
    int keccak_rate_bytes = 0;
    int keccak_delay      = 0;
    int rsp_ready_delay   = 0;
    int kmac_msg_fifo_cnt = 0;
    int keccak_byte_cnt   = 0;
    int flush_ctr         = 0;
    bit flush_in_absorb   = 0;

    // Used to determine if ready will be 1 or 0
    int ready_chance      = 0;
    bit initial_ready_rsp = 0;

    while (!finish_seq) begin
      // Wait for transaction from monitor
      p_sequencer.req_analysis_fifo.get(item);

      should_send_rsp = 0;

      // Set the Keccak Strength and SHA algorithm from first byte
      // Compute length of message in bytes for computing digest
      cfg_word  = item.byte_data_q[0];
      strength  = cfg_word[4:2];
      hash_mode = cfg_word[1:0];
      keccak_rate = sha3_pkg::KeccakRate[strength];
      keccak_rate_bytes = keccak_rate * 8;

      // Cast msg req into array with first byte removed
      if (item.byte_data_q.size() > 0) begin
        msg_arr = new[item.byte_data_q.size() - 1];
        foreach (item.byte_data_q[i]) begin
          if (i == 0) continue; // Skip cfg byte
          msg_arr[i - 1] = item.byte_data_q[i];
        end
      end

      // Set ready to 1 at the start of a transaction
      if (!item.rsp_ready && item.drive_rsp_ready && !initial_ready_rsp) begin
        otbn_app_item rsp = otbn_app_item::type_id::create("rsp_item");

        rsp.rsp_ready         = 1;
        rsp.drive_rsp_ready   = 1;
        rsp.rsp_ready_delay   = APP_INTF_READY_LATENCY-1;
        initial_ready_rsp     = 1;

        start_item(rsp);
        finish_item(rsp);
      end

      // Decrease from the ready delay each clock cycle the keccak state is full
      if (keccak_byte_cnt == keccak_rate_bytes) begin
        rsp_ready_delay = rsp_ready_delay - 1;
      end

      // Absorb from MSG FIFO -> STATE with a 1 cycle delay from MSG FIFO
      if (keccak_byte_cnt < keccak_rate_bytes) begin
        if ((kmac_msg_fifo_cnt >= 8) && item.rsp_ready) begin
          keccak_byte_cnt   += 8;
          kmac_msg_fifo_cnt -= 8;
          `uvm_info(`gfn, $sformatf("ABSORBING 8 BYTES FROM MSG FIFO -> KECCAK STATE: %0d",
                    keccak_byte_cnt), UVM_MEDIUM)
          if (keccak_byte_cnt == keccak_rate_bytes) begin
            rsp_ready_delay = KECCAK_NOT_ABSORBED_LATENCY+1; // 1 Additional for pending process
            `uvm_info(`gfn, $sformatf("KECCAK STATE IS NOW FULL"), UVM_MEDIUM)
          end
        end
      end

      // Absorb from APP FIFO -> MSG FIFO
      if (kmac_msg_fifo_cnt <= ((MSG_FIFO_SIZE_BYTES + MSG_PACKER_SIZE_BYTES)-8)) begin
        if ((msg_arr.size() > 0) && (item.req_valid && item.rsp_ready)) begin
          kmac_msg_fifo_cnt += $countones(item.req_strb);
          if (kmac_msg_fifo_cnt == (MSG_FIFO_SIZE_BYTES + MSG_PACKER_SIZE_BYTES)) begin
            // Drop ready here now that msg_fifo is full
            otbn_app_item rsp = otbn_app_item::type_id::create("rsp_item");
            rsp.rsp_ready_delay = 0;
            rsp.rsp_ready = 0;
            rsp.drive_rsp_ready = 1;
            `uvm_info(`gfn, $sformatf("MSG FIFO FULL"), UVM_MEDIUM)
            start_item(rsp);
            finish_item(rsp);
          end
        end
      end else if (kmac_msg_fifo_cnt == (MSG_FIFO_SIZE_BYTES + MSG_PACKER_SIZE_BYTES)) begin
        // Assert ready to 1 after the appropriate delay
        otbn_app_item rsp = otbn_app_item::type_id::create("rsp_item");
        rsp.rsp_ready_delay = rsp_ready_delay;
        rsp.rsp_ready = 1;
        msg_size = msg_size + 1;
        rsp.drive_rsp_ready = 1;
        start_item(rsp);
        finish_item(rsp);
        rsp_ready_delay   = 0;
        // We start by absorbing the first 2 bytes from MSG FIFO -> STATE
        keccak_byte_cnt   = 16;
        kmac_msg_fifo_cnt -= 16;
      end

      // Entire req msg has been captured in monitor
      // Ready for setting cfg and generating digest
      if (!saw_first_rsp && item.req_last) begin
        saw_first_rsp = 1;
        should_send_rsp = 1;

        output_len_bytes = 32; // First word
        output_wrd_cnt = 1;    // First word

        // Set initial delay to a remaining ready delay process (0 if no previous run in progress)
        keccak_delay = rsp_ready_delay;
        `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER ADDING REMAINING FULL STATE DELAY: %0d", keccak_delay), UVM_MEDIUM)
        `uvm_info(`gfn, $sformatf("REMAINING MSG FIFO CNT: %0d | CURRENT KECCAK BYTE CNT: %0d", kmac_msg_fifo_cnt, keccak_byte_cnt), UVM_MEDIUM)

        // If there is an in progress keccak run from a full keccak state then we will need
        // to begin emptying the MSG FIFO and acummulate FIFO flush counts before the run
        // has finished, leading to a separate logic block compared to no run
        if (rsp_ready_delay > 0) begin
          // keccak_byte_cnt will always be equal to the rate, if the following evaluates to false
          // then the msg fifo is already empty and there will be no flushing / absorbing delays
          if ((kmac_msg_fifo_cnt + keccak_byte_cnt) > keccak_rate_bytes) begin
            flush_ctr = 1; // There is no latency when coming off a previous run (acommodate by setting to 1)
            // If the MSG FIFO is greater than or equal to 16 we can absorb the first
            // two bytes and begin processing the remainder
            if (kmac_msg_fifo_cnt >= 16) begin
              // Set the initial fifo and keccak state sizes after absorbing during
              // the last two clock cycles
              kmac_msg_fifo_cnt -= 16;
              keccak_byte_cnt   =  16;
              flush_ctr         += 2;

              // Determine if after absorbing 2B and resetting keccak_byte_cnt
              // if we will once again fill the keccak rate
              if (kmac_msg_fifo_cnt + keccak_byte_cnt >= keccak_rate_bytes) begin
                while (keccak_byte_cnt < keccak_rate_bytes) begin
                  kmac_msg_fifo_cnt -= 8;
                  keccak_byte_cnt   += 8;
                  keccak_delay      += 1; // 1 clock cycle per absorb
                  flush_ctr         += 1;
                end
                `uvm_info(`gfn, $sformatf("REMAINING MSG FIFO CNT: %0d", kmac_msg_fifo_cnt), UVM_MEDIUM)
                `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER SHIFT DELAY: %0d", keccak_delay), UVM_MEDIUM)

                keccak_delay += 1; // 1 cycle for starting processes in not absorbed state
                `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER ADDING PROCESSING DELAYS: %0d", keccak_delay), UVM_MEDIUM)
                keccak_delay += KECCAK_NOT_ABSORBED_LATENCY; // Delay for a new run
                `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER ADDING NEW NOT ABSORBED DELAY: %0d", keccak_delay), UVM_MEDIUM)

                // If after an additional run there is still more than 2B of data
                // absorb and dtermine the addditional absorb delay
                if (kmac_msg_fifo_cnt > 16) begin
                  kmac_msg_fifo_cnt -= 16;
                  keccak_byte_cnt   =  16;
                  flush_ctr         += 2;
                  keccak_delay += (kmac_msg_fifo_cnt/8); // Delay for whole words
                  flush_ctr    += (kmac_msg_fifo_cnt/8);
                  keccak_delay += ((kmac_msg_fifo_cnt % 8) > 0) ? 1 : 0; // Delay for partial word
                  flush_ctr    += ((kmac_msg_fifo_cnt % 8) > 0) ? 1 : 0;
                  `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER MSG FIFO ABSORBED: %0d", keccak_delay), UVM_MEDIUM)

                // There will not be an aditional absorb cycle required
                end else if (kmac_msg_fifo_cnt > 8) begin
                  `uvm_info(`gfn, $sformatf("REMAINING MSG FIFO CNT: %0d", kmac_msg_fifo_cnt), UVM_MEDIUM)
                  flush_ctr    += (kmac_msg_fifo_cnt/8);
                  flush_ctr    += ((kmac_msg_fifo_cnt % 8) > 0) ? 1 : 0;

                // If last absorb is with 2 cycles remaining the packer flush cycle
                // will ocurr during the last cycle of the previous run
                end else begin
                  flush_ctr += ((kmac_msg_fifo_cnt % 8) > 0) ? 1 : 0;
                  flush_in_absorb = 1;
                end

              // Keccak rate will not be filled with remainder
              // simply absorb the remaining bytes
              end else begin
                keccak_delay += (kmac_msg_fifo_cnt/8); // Delay for whole words
                flush_ctr    += (kmac_msg_fifo_cnt/8);
                keccak_delay += ((kmac_msg_fifo_cnt % 8) > 0) ? 1 : 0; // Delay for partial word
                flush_ctr    += ((kmac_msg_fifo_cnt % 8) > 0) ? 1 : 0;
                `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER MSG FIFO ABSORBED: %0d", keccak_delay), UVM_MEDIUM)
              end

            // There is less than 2B to absorb so only need to determine how
            // many clock cycles to flush the FIFO and packer
            end else begin
              if (kmac_msg_fifo_cnt > 8) begin
                flush_ctr += (kmac_msg_fifo_cnt/8);
                flush_ctr += ((kmac_msg_fifo_cnt % 8) > 0) ? 1 : 0;

              // With 1B or less the packer absorb will ocurr during ongoing run if required
              end else begin
                flush_ctr += ((kmac_msg_fifo_cnt % 8) > 0) ? 1 : 0;
                flush_in_absorb = 1;
              end

              kmac_msg_fifo_cnt = 0;
            end
          end
        end else begin
          // There is not a previous run in progress which means we do not need to begin emptying
          // the MSG FIFO and accumulating FIFO flush ctr cycles until after absorbing from
          // MSG FIFO -> KECCAK STATE

          // Check for possibility of needing extra run after flushing MSG FIFO if the
          // FIFO + STATE is > RATE
          if (kmac_msg_fifo_cnt + keccak_byte_cnt >= keccak_rate_bytes) begin
            // When Keccak State is full we need a Not Absorbed run
            keccak_delay += 1; // 1 cycle for starting processes in not absorbed state
            `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER ADDING PROCESSING DELAYS: %0d", keccak_delay), UVM_MEDIUM)
            keccak_delay +=  KECCAK_NOT_ABSORBED_LATENCY;
            `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER ADDING NEW NOT ABSORBED DELAY: %0d", keccak_delay), UVM_MEDIUM)

            // Slightly different behavior when the msg is exact state size
            // There is no FIFO flushing required after absorbing
            if (kmac_msg_fifo_cnt + keccak_byte_cnt == keccak_rate_bytes) begin
              keccak_delay += (kmac_msg_fifo_cnt/8); // Delay for whole words absorbed
              `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER MSG FIFO ABSORBED: %0d", keccak_delay), UVM_MEDIUM)
            end else begin
              while (keccak_byte_cnt < keccak_rate_bytes) begin
                kmac_msg_fifo_cnt -= 8;
                keccak_byte_cnt   += 8;
                keccak_delay      += 1; // 1 clock cycle per absorb
                flush_ctr         += 1;
              end
              `uvm_info(`gfn, $sformatf("REMAINING MSG FIFO CNT: %0d", kmac_msg_fifo_cnt), UVM_MEDIUM)
              `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER SHIFT DELAY: %0d", keccak_delay), UVM_MEDIUM)

              // Check for appropriate FIFO delays depending on remaining msg fifo count and flush count
              if (kmac_msg_fifo_cnt > 16) begin
                kmac_msg_fifo_cnt -= 16;
                flush_ctr         += 2;
                keccak_delay += (kmac_msg_fifo_cnt/8); // Delay for whole words
                flush_ctr    += (kmac_msg_fifo_cnt/8);
                keccak_delay += ((kmac_msg_fifo_cnt % 8) > 0) ? 1 : 0; // Delay for partial word
                flush_ctr    += ((kmac_msg_fifo_cnt % 8) > 0) ? 1 : 0;
                `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER MSG FIFO ABSORBED: %0d", keccak_delay), UVM_MEDIUM)

              end else if (kmac_msg_fifo_cnt > 8) begin
                flush_ctr    += (kmac_msg_fifo_cnt/8);
                flush_ctr    += ((kmac_msg_fifo_cnt % 8) > 0) ? 1 : 0;

              // With 1B or less the packer absorb will ocurr during ongoing run if required
              end else begin
                flush_ctr += (kmac_msg_fifo_cnt > 0) ? 1 : 0;
                flush_in_absorb = 1;
              end
            end
          end else begin
            // The msg fifo + current keccak state is less than the maximum rate
            // First check if the msg fifo is not empty
            if (kmac_msg_fifo_cnt > 0) begin
              keccak_delay += (kmac_msg_fifo_cnt/8); // Delay for whole words
              flush_ctr    += (kmac_msg_fifo_cnt/8);
              keccak_delay += ((kmac_msg_fifo_cnt % 8) > 0) ? 1 : 0; // Delay for partial word
              flush_ctr    += ((kmac_msg_fifo_cnt % 8) > 0) ? 1 : 0;
              `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER MSG FIFO ABSORBED: %0d", keccak_delay), UVM_MEDIUM)

              if (kmac_msg_fifo_cnt < 8) begin
                keccak_delay += 1; // FIFO flush state transition
                `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER FLUSH STATE TRANSITION: %0d", keccak_delay), UVM_MEDIUM)
              end
            end
          end
        end

        // Add the MSG FIFO and PACKER flush latency
        // If the flush_in_absorb bit is high then the packer flush cycle is ignored when
        // the counter is less or equal to 2. When greater than 2 there is no delay
        // If the counter is still 0 there is need to flush as the Keccak STATE == Keccak RATE
        if (flush_ctr > 0) begin
          if (flush_ctr <= 2) begin
            if (flush_in_absorb) begin
              keccak_delay += MSG_FIFO_PACKER_FLUSH_LATENCY-1;
            end else begin
              keccak_delay += MSG_FIFO_PACKER_FLUSH_LATENCY;
            end
          end else begin
            if (~flush_in_absorb) begin
              keccak_delay += MSG_FIFO_PACKER_FLUSH_LATENCY-1;
            end
          end
        end
        `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER MSG FIFO FLUSH: %0d", keccak_delay), UVM_MEDIUM)

        // Add the Padding Delay
        keccak_delay += keccak_pad_cycles(msg_arr.size(), keccak_rate);
        `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER ADDING PADDING DELAY: %0d", keccak_delay), UVM_MEDIUM)

        // Add transition delay to Processing State
        keccak_delay += 1;
        `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER ADDING PROCESSING DELAYS: %0d", keccak_delay), UVM_MEDIUM)

        // Add Processing In Absorbed State Delay
        keccak_delay += KECCAK_ABSORBED_LATENCY;
        `uvm_info(`gfn, $sformatf("KECCAK DELAY AFTER ADDING NEW IN ABSORBED DELAY: %0d", keccak_delay), UVM_MEDIUM)

        // Compute first word for digest
        compute_dpi_digest(strength, hash_mode, msg_arr, output_len_bytes, output_wrd_cnt, dpi_digest);

        keccak_state_size = keccak_rate;

      // Already sent first digest response
      // Generate new response if next is observed in monitor
      end else if (saw_first_rsp && item.req_next && item.req_hold) begin

        // Determine how many total bytes should be in digest
        should_send_rsp   = 1;
        output_wrd_cnt    = output_wrd_cnt + 1;
        output_len_bytes  = 32 * output_wrd_cnt;

        // Determine if keccak state has been exhausted for delay modeling
        if ((output_wrd_cnt * 4) <= keccak_state_size) begin
          // Shift new word
          keccak_delay = SHIFT_DIGEST_LATENCY-1;
        end else begin
          // Keccak manual run
          keccak_delay = NEW_PERMUTATION_LATENCY-1;
          keccak_state_size += keccak_rate;
        end

        // Compute next word for digest
        compute_dpi_digest(strength, hash_mode, msg_arr, output_len_bytes, output_wrd_cnt, dpi_digest);

      end else if (saw_first_rsp && !item.req_hold) begin
        // Hold being released indicates end of transaction
        should_send_rsp = 0;
        saw_first_rsp = 0;
        finish_seq = 1;
      end

      // Send the actual digest response
      if (should_send_rsp) begin
        otbn_app_item rsp = otbn_app_item::type_id::create("rsp_item");

        // Add the rsp_delay;
        rsp.rsp_delay = keccak_delay;

        // Copy byte_data_q for scoreboard/reference purposes
        rsp.byte_data_q = item.byte_data_q;

        // Determine the start index and interate through digest to get the 256-bit msb
        // 256-bit msb always contains the most recent portion of rsp digest
        start_idx = dpi_digest.size() - 1;
        digest_lsb_share0 = '0;

        for (int i = 0; i < 32; i++) begin
          digest_lsb_share0 = (digest_lsb_share0 << 8) | dpi_digest[start_idx - i];
        end

        // Computed digest is unmasked therefore set share1 to all 0.
        // Inject error if appropriate from sequence config
        rsp.rsp_digest_share0 = {128'h0, digest_lsb_share0};
        rsp.rsp_digest_share1 = {128'h0, 256'h0};
        rsp.rsp_error         = 0;
        rsp.rsp_done          = 1;
        rsp.rsp_ready         = 0;
        rsp.drive_rsp_ready   = 0;
        rsp.rsp_ready_delay   = 0;

        // Pass through for reference/debug
        rsp.req_next = item.req_next;
        rsp.req_hold = item.req_hold;

        `uvm_info(`gfn, $sformatf("Sending digest response:\n%0s", rsp.sprint()), UVM_MEDIUM)

        start_item(rsp);
        finish_item(rsp);
      end
    end
  endtask

  // Use DPI-C models to compute the response digest
  task automatic compute_dpi_digest (
    input sha3_pkg::keccak_strength_e strength,
    input sha3_pkg::sha3_mode_e       hash_mode,
    input bit [7:0]                   msg_arr[],
    input int                         output_len_bytes,
    input int                         output_wrd_cnt,
    output bit [7:0]                  digest_result[]
  );

    // Based on the rsp word count initialize array for rsp digest
    digest_result = new[output_len_bytes];

    case (hash_mode)
      ///////////
      // SHA-3 //
      ///////////
      sha3_pkg::Sha3: begin
        case (strength)
          sha3_pkg::L224: begin
            `uvm_fatal(`gfn, $sformatf("strength[%0s] is not allowed for OTBN sha3", strength.name()))
          end
          sha3_pkg::L256: begin
            if (output_wrd_cnt > 1) begin
              `uvm_fatal(`gfn, $sformatf("strength[%0s] should only have output length of 32B", strength.name()))
            end
            digestpp_dpi_pkg::c_dpi_sha3_256(msg_arr, msg_arr.size(), digest_result);
          end
          sha3_pkg::L384: begin
            `uvm_fatal(`gfn, $sformatf("strength[%0s] is not allowed for OTBN sha3", strength.name()))
          end
          sha3_pkg::L512: begin
            if (output_wrd_cnt > 2) begin
              `uvm_fatal(`gfn, $sformatf("strength[%0s] should only have output length of 64B", strength.name()))
            end
            digestpp_dpi_pkg::c_dpi_sha3_512(msg_arr, msg_arr.size(), digest_result);
          end
          default: begin
            `uvm_fatal(`gfn, $sformatf("strength[%0s] is not allowed for sha3", strength.name()))
          end
        endcase
      end
      ///////////
      // SHAKE //
      ///////////
      sha3_pkg::Shake: begin
        case (strength)
          sha3_pkg::L128: begin
            digestpp_dpi_pkg::c_dpi_shake128(msg_arr, msg_arr.size(), output_len_bytes, digest_result);
          end
          sha3_pkg::L256: begin
            digestpp_dpi_pkg::c_dpi_shake256(msg_arr, msg_arr.size(), output_len_bytes, digest_result);
          end
          default: begin
            `uvm_fatal(`gfn, $sformatf("strength[%0s] is not allowed for shake", strength.name()))
          end
        endcase
      end
      ////////////
      // CSHAKE //
      ////////////
      sha3_pkg::CShake: begin
        `uvm_fatal(`gfn, $sformatf("mode[%0s] is not allowed for OTBN", hash_mode.name()))
      end
    endcase
  endtask

  // Function to compute cycle delay needed for padding inside KMAC
  function automatic int keccak_pad_cycles (
    input int msg_bytes,
    input int keccak_rate
  );

    int whole_words;
    int leftover_bytes;
    int padding_remainder;
    int padding_cycles;

    begin
      whole_words = msg_bytes / 8; // Number of complete 64-bit words
      // Translate word counts and keccak rate into clock cycles
      padding_remainder = (whole_words % keccak_rate);
      // Add 1 for partial word
      padding_cycles = keccak_rate - padding_remainder;
      return padding_cycles;
    end
  endfunction

endclass
