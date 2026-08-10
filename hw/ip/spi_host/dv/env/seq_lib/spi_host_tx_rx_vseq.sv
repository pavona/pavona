// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// this sequence has the tasks that combine basic tasks
// from base_vseq into more elaborate actions
// such as build a full spi transaction (which is consist of cmd/addr/dummy/data segments
// or transmit a transaction which is setting up the dut, program fifo and enable transmit
// for each individual segment.
//
// these task can be easily leveraged to build more complex sequences
//

class spi_host_tx_rx_vseq extends spi_host_base_vseq;
  `uvm_object_utils(spi_host_tx_rx_vseq)
  `uvm_object_new

  // This lock can be used to control access to the DUT TL-interface between testbench tasks.
  semaphore spi_host_atomic = new(1);

  int unsigned num_wr, num_rd; // Keeps score of the reads/writes sent
  bit          spi_host_txn_sent;
  // Set when read_rx_fifo() returns, so a sequence can drain what lands afterwards without
  // racing it for the same byte.
  bit          rd_rx_fifo_finished;

  virtual task start_spi_host_trans(int num_transactions, bit wait_ready = 1'b1);
    spi_host_status_t status;
    `uvm_info(`gfn, $sformatf("%m: start_spi_host_trans (num_transactions=%0d, bit wait_ready=%0d)",
                              num_transactions, wait_ready), UVM_DEBUG)
    program_spi_host_regs();
    if (wait_ready) begin
      wait_ready_for_command();
    end
    csr_rd(.ptr(ral.status), .value(status));

    num_wr = 0;
    num_rd = 0;
    spi_host_txn_sent = 0;
    for (int n = 0; n < num_transactions; n++) begin
      generate_transaction();
      send_trans(transaction, wait_ready);
      if (wait_ready)
        wait_ready_for_command();
    end
    // Releases the waiter when every segment was a write and num_rd stayed 0. Set only after all
    // transactions, since a later one could still add reads.
    spi_host_txn_sent = 1;
  endtask

  // Read CSR.RXFIFO until spi_host is inactive and the fifo is empty.
  // Wait until the TL-bus is inactive, then read status/intr_state for scb checking.
  // Set 'producer_running' when another thread is still sending. The DUT looks idle with an
  // empty RXFIFO both between segments and at the end of the traffic, and returning on the
  // former leaves the next segment's reads uncollected.
  virtual task read_rx_fifo(bit producer_running = 1'b0);
    bit [7:0] read_q[$];
    spi_host_status_t status;

    rd_rx_fifo_finished = 0;
    // Wait until not-empty before entering the forever loop. Paced because csr_spinwait polls a
    // backdoor read every 1ns, which burns wall clock. 1us is finer than any SCK period.
    csr_spinwait(.ptr(ral.status.rxempty), .exp_data(1'b0), .backdoor(1),
                 .spinwait_delay_ns(1000));
    forever begin : read_rxfifo_until_empty_and_inactive
      // Re-read the depth before every access: a count sampled once goes stale when a SW_RST
      // empties the FIFO, and reading it then underflows. Deliberately unlocked, since send_trans
      // holds spi_host_atomic waiting for TXFIFO space that this drain may have to free.
      csr_rd(.ptr(ral.status), .value(status));
      forever begin
        csr_rd(.ptr(ral.status), .value(status), .backdoor(1));
        if (status.rx_qd == 0) break;
        `uvm_info(`gfn, $sformatf("Calling 'access_data_fifo' since status.rx_qd = 0x%0x > 0",
                                  status.rx_qd), UVM_DEBUG)
        access_data_fifo(read_q, RxFifo);
      end
      if (!status.active && status.rxempty && (status.rx_qd == 0)) begin
        if (!producer_running || spi_host_txn_sent) break;
        // Idle only because the producer is between segments. Block until it either queues more
        // data or reports that every transaction has been sent.
        fork begin : wait_for_rx_or_producer_done
          fork
            csr_spinwait(.ptr(ral.status.rxempty), .exp_data(1'b0), .backdoor(1),
                         .spinwait_delay_ns(1000));
            wait (spi_host_txn_sent);
          join_any
          disable fork;
        end join
        continue;
      end
      // Nothing queued and the DUT still running: wait for RX data or for the DUT to go idle.
      fork begin : wait_for_rx_or_idle
        fork
          csr_spinwait(.ptr(ral.status.rxempty), .exp_data(1'b0), .backdoor(1),
                       .spinwait_delay_ns(1000));
          csr_spinwait(.ptr(ral.status.active),  .exp_data(1'b0), .backdoor(1),
                       .spinwait_delay_ns(1000));
        join_any
        disable fork;
      end join
    end : read_rxfifo_until_empty_and_inactive

    // Wait for all accesses to complete
    wait_no_outstanding_access();

    // Read out status/intr_state CSRs (ignore the data)
    // This lets the scoreboard check the values.
    check_status_and_clear_intrs();
    rd_rx_fifo_finished = 1;

  endtask

  // Generate the TL-writes needed for the DUT to send all segments of a "spi_transaction_item" transaction.
  virtual task send_trans(spi_transaction_item trans, bit wait_ready = 1'b1);
    spi_segment_item segment;
    while (trans.segments.size() > 0) begin
      if (wait_ready)
        wait_ready_for_command();

      // lock fifo to this seq
      spi_host_atomic.get(1);
      segment = trans.segments.pop_back();
      `uvm_info(`gfn, $sformatf("Last segment: %s",segment.convert2string()), UVM_DEBUG)
      // Populate TXIFIO with write-data (if required)
      if (segment.command_reg.direction inside {TxOnly, Bidir}) begin
        access_data_fifo(segment.spi_data, TxFifo);
      end

      case(segment.command_reg.direction)
        TxOnly: num_wr++;
        RxOnly: num_rd++;
        Bidir: begin
          num_rd++;
          num_wr++;
        end
        default: ;
      endcase // case (segment.command_reg.direction)

      // As soon as the COMMAND reg is populated, the DUT will begin the transaction.
      program_command_reg(segment.command_reg);
      spi_host_atomic.put(1);
    end
  endtask : send_trans

  // Write dummy-data into TxFifo.
  virtual task txfifo_fill();
    spi_segment_item segment = spi_segment_item::type_id::create("segment");
    spi_host_atomic.get(1);
    access_data_fifo(segment.spi_data, TxFifo);
    spi_host_atomic.put(1);
  endtask : txfifo_fill

  virtual task generate_transaction();
    transaction_init();
    `DV_CHECK_RANDOMIZE_FATAL(transaction)
    `uvm_info(`gfn, $sformatf("transaction = %s",transaction.convert2string()), UVM_DEBUG)
  endtask

  task check_event(uvm_reg_field fld, bit intr_value, bit state_value);
    spi_host_intr_state_t intr_state;
    uvm_reg_field enable_fld;
    if (fld == ral.status.active) begin
      enable_fld = ral.event_enable.get_field_by_name("idle");
    end
    else begin
      enable_fld = ral.event_enable.get_field_by_name(fld.get_name);
    end
    csr_rd_check(.ptr(fld), .compare_value(state_value));
    if ((enable_fld != null) && enable_fld.get()) begin
      bit enable = `gmv(enable_fld);
      check_interrupts(1 << intr_state.spi_event, intr_value & enable);
    end else begin
      check_interrupts(1 << intr_state.spi_event, 0);
    end
  endtask

  task check_error(uvm_reg_field fld, bit value);
    spi_host_intr_state_t intr_state;
    uvm_reg_field enable_fld = ral.error_enable.get_field_by_name(fld.get_name);
    csr_rd_check(.ptr(fld), .compare_value(value));
      if ((enable_fld != null) && enable_fld.get()) begin
        bit enable = `gmv(enable_fld);
        `DV_CHECK(ral.intr_enable.predict(.value(intr_enable.error), .kind(UVM_PREDICT_DIRECT)))
        check_interrupts(1 << intr_state.error, value & enable);
      end else begin
        check_interrupts(1 << intr_state.error, 0);
      end
  endtask
endclass : spi_host_tx_rx_vseq
