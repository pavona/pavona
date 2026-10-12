// Resiliator fault-injection wrapper around the Egret Ibex core.
//
// The driver supplies clk and active-high rst. Firmware reports 
// whether fault injection succeeded or failed through gpio.
// Uses Egret's secure Ibex configuration with flat SRAM and a matching PMP map.
// Keep these memory-map constants in sync:
//   MemSizeByte  <-> LENGTH in fw/resiliator_fw.ld
//   GpioAddr     <-> RESILIATOR_GPIO_ADDR in
//                    hw/vendor/kjnsen_resiliator/firmware/injection.h

module ibex_resiliator_top import ibex_pkg::*; (
  input  wire        clk,
  input  wire        rst,   // Active high
  output wire        fail,
  output wire [31:0] gpio
);

  //////////////////////////////////////////////////////////////////////////////
  // Parameters                                                                //
  //////////////////////////////////////////////////////////////////////////////

  localparam logic [31:0] MemSizeByte = 32'h20000;
  localparam logic [31:0] GpioAddr    = 32'hff000000;

  localparam int unsigned Depth = int'(MemSizeByte) / 4;
  localparam int unsigned Aw    = $clog2(int'(MemSizeByte));

  // Ibex fetches its reset vector from {boot_addr_i[31:8], 8'h80}, and asserts
  // that boot_addr_i[7:0] == 0 (`ibex_if_stage.sv`). With a zero boot address
  // execution starts at 0x80, which is where the linker script places `_start`.
  localparam logic [31:0] BootAddr = 32'h0000_0000;

  // Fixed ICache scrambling key/nonce. The value is irrelevant to the campaign
  // (it only has to be stable across the golden and faulty runs); the same
  // trick is used by `hw/ip/acc/dv/verilator/acc_top_sim.sv`.
  localparam logic [SCRAMBLE_KEY_W-1:0]   TestScrambleKey   =
      128'h48ecf6c738f0f108a5b08620695ffd4d;
  localparam logic [SCRAMBLE_NONCE_W-1:0] TestScrambleNonce =
      64'hf88c2578fa4cd123;

  // PMP reset state for this testbench's memory map. Region 0 covers the whole
  // SRAM; regions 10/11 form a TOR pair over the GPIO window. Everything else
  // is OFF and, because mmwp is set, therefore denied.
  localparam pmp_cfg_t PmpCfgRstTb[16] = '{
    '{lock: 1'b1, mode: PMP_MODE_NAPOT, exec: 1'b1, write: 1'b1, read: 1'b1}, // 0  [SRAM: LRWX]
    '{lock: 1'b0, mode: PMP_MODE_OFF,   exec: 1'b0, write: 1'b0, read: 1'b0}, // 1
    '{lock: 1'b0, mode: PMP_MODE_OFF,   exec: 1'b0, write: 1'b0, read: 1'b0}, // 2
    '{lock: 1'b0, mode: PMP_MODE_OFF,   exec: 1'b0, write: 1'b0, read: 1'b0}, // 3
    '{lock: 1'b0, mode: PMP_MODE_OFF,   exec: 1'b0, write: 1'b0, read: 1'b0}, // 4
    '{lock: 1'b0, mode: PMP_MODE_OFF,   exec: 1'b0, write: 1'b0, read: 1'b0}, // 5
    '{lock: 1'b0, mode: PMP_MODE_OFF,   exec: 1'b0, write: 1'b0, read: 1'b0}, // 6
    '{lock: 1'b0, mode: PMP_MODE_OFF,   exec: 1'b0, write: 1'b0, read: 1'b0}, // 7
    '{lock: 1'b0, mode: PMP_MODE_OFF,   exec: 1'b0, write: 1'b0, read: 1'b0}, // 8
    '{lock: 1'b0, mode: PMP_MODE_OFF,   exec: 1'b0, write: 1'b0, read: 1'b0}, // 9
    '{lock: 1'b0, mode: PMP_MODE_OFF,   exec: 1'b0, write: 1'b0, read: 1'b0}, // 10 [GPIO: lo]
    '{lock: 1'b1, mode: PMP_MODE_TOR,   exec: 1'b0, write: 1'b1, read: 1'b1}, // 11 [GPIO: hi, LRW]
    '{lock: 1'b0, mode: PMP_MODE_OFF,   exec: 1'b0, write: 1'b0, read: 1'b0}, // 12
    '{lock: 1'b0, mode: PMP_MODE_OFF,   exec: 1'b0, write: 1'b0, read: 1'b0}, // 13
    '{lock: 1'b0, mode: PMP_MODE_OFF,   exec: 1'b0, write: 1'b0, read: 1'b0}, // 14
    '{lock: 1'b0, mode: PMP_MODE_OFF,   exec: 1'b0, write: 1'b0, read: 1'b0}  // 15
  };

  // Byte-granular addresses, as in `ibex_pmp_reset_pkg`. For NAPOT the value is
  // `base | (size/2 - 1)`; for TOR it is the bound itself. The bottom two bits
  // are stripped by the core (PMPGranularity == 0).
  localparam logic [33:0] PmpAddrRstTb[16] = '{
    (34'(MemSizeByte) >> 1) - 34'd1, // rgn 0  [SRAM: base=0x0 size=MEMSIZE]
    34'h00000000,                    // rgn 1
    34'h00000000,                    // rgn 2
    34'h00000000,                    // rgn 3
    34'h00000000,                    // rgn 4
    34'h00000000,                    // rgn 5
    34'h00000000,                    // rgn 6
    34'h00000000,                    // rgn 7
    34'h00000000,                    // rgn 8
    34'h00000000,                    // rgn 9
    34'(GpioAddr),                   // rgn 10 [GPIO: lo]
    34'(GpioAddr + 32'h10),          // rgn 11 [GPIO: hi]
    34'h00000000,                    // rgn 12
    34'h00000000,                    // rgn 13
    34'h00000000,                    // rgn 14
    34'h00000000                     // rgn 15
  };

  // Keep Egret's whitelist policy: an access with no matching region is denied
  // even in machine mode.
  localparam pmp_mseccfg_t PmpMseccfgRstTb = '{rlb: 1'b1, mmwp: 1'b1, mml: 1'b0};

  //////////////////////////////////////////////////////////////////////////////
  // Signals                                                                   //
  //////////////////////////////////////////////////////////////////////////////

  wire rst_n = ~rst;

  // Instruction memory interface
  logic        instr_req;
  logic        instr_gnt;
  logic        instr_rvalid;
  logic [31:0] instr_addr;
  logic [31:0] instr_rdata;
  logic [38:0] instr_rdata_ecc;
  logic        instr_err;

  // Data memory interface
  logic        data_req;
  logic        data_gnt;
  logic        data_rvalid;
  logic        data_we;
  logic [3:0]  data_be;
  logic [31:0] data_addr;
  logic [31:0] data_wdata;
  logic [6:0]  data_wdata_intg;
  logic [31:0] data_rdata;
  logic [38:0] data_rdata_ecc;
  logic        data_err;

  logic [31:0] mem [Depth];

  logic [31:0] gpio_q;
  logic        mem_fail_q;

  logic        alert_minor;
  logic        alert_major_internal;
  logic        alert_major_bus;
  logic        double_fault_seen;
  logic        core_sleep;
  logic        scramble_req;
  crash_dump_t crash_dump;

  //////////////////////////////////////////////////////////////////////////////
  // Firmware loading                                                          //
  //////////////////////////////////////////////////////////////////////////////

  // Resiliator's required firmware hook: the driver passes `+firmware=<file>`
  // (see `run_sim.sh`), and the same image is loaded identically for the golden
  // and every faulty simulation.
  // 512 characters. Resiliator's own examples use 1024 bits (128 characters),
  // which is not enough here: $value$plusargs right-justifies the string, so a
  // longer path silently loses its leading characters and $readmemh then fails
  // with "file not found" on a path that looks almost right. Bazel hands us
  // absolute paths through the output base, e.g.
  //   /home/<user>/.cache/bazel/_bazel_<user>/<32-hex-digits>/execroot/_main/
  //   bazel-out/k8-fastbuild/bin/hw/top_egret/dv/resiliator/fw/auth_check.hex
  // which is over 160 characters before the workspace is even deep.
  reg [4095:0] firmware_file;
  initial begin
    if ($value$plusargs("firmware=%s", firmware_file)) begin
      $readmemh(firmware_file, mem);
    end else begin
      $fatal(1, "ibex_resiliator_top: no +firmware=<file> supplied");
    end
  end

  //////////////////////////////////////////////////////////////////////////////
  // Memory model                                                              //
  //////////////////////////////////////////////////////////////////////////////

  // Ideal dual-ported SRAM: the instruction port reads, the data port reads and
  // writes. Both are always granted with single-cycle latency, so no arbitration
  // stalls perturb the cycle numbering the campaign indexes on.
  assign instr_gnt = instr_req;
  assign data_gnt  = data_req;

  wire instr_in_range = instr_addr < MemSizeByte;
  wire data_in_range  = data_addr < MemSizeByte;

  // Address comparisons against MMIO use Hamming distance rather than equality,
  // so that a single flipped address bit cannot silently redirect a GPIO access
  // elsewhere. Taken from Resiliator's own `rtl/sim_rv.v`.
  wire data_is_gpio = $countones(data_addr ^ GpioAddr) <= 1;

  // Instruction port
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      instr_rvalid <= 1'b0;
      instr_err    <= 1'b0;
    end else begin
      instr_rvalid <= instr_req;
      instr_err    <= instr_req & ~instr_in_range;
    end

    if (instr_req && instr_in_range) begin
      instr_rdata <= mem[instr_addr[Aw-1:2]];
    end
  end

  // Data port
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      data_rvalid <= 1'b0;
      data_err    <= 1'b0;
      gpio_q      <= 32'h0;
      mem_fail_q  <= 1'b0;
    end else begin
      data_rvalid <= data_req;
      data_err    <= data_req & ~data_in_range & ~data_is_gpio;

      if (data_req && data_we) begin
        if (data_is_gpio) begin
          gpio_q <= data_wdata;
        end else if (data_in_range) begin
          if (data_be[0]) mem[data_addr[Aw-1:2]][7:0]   <= data_wdata[7:0];
          if (data_be[1]) mem[data_addr[Aw-1:2]][15:8]  <= data_wdata[15:8];
          if (data_be[2]) mem[data_addr[Aw-1:2]][23:16] <= data_wdata[23:16];
          if (data_be[3]) mem[data_addr[Aw-1:2]][31:24] <= data_wdata[31:24];
        end else begin
          mem_fail_q <= 1'b1;
        end
      end

      if (data_req && !data_we) begin
        if (data_is_gpio) begin
          data_rdata <= gpio_q;
        end else if (data_in_range) begin
          data_rdata <= mem[data_addr[Aw-1:2]];
        end else begin
          mem_fail_q <= 1'b1;
        end
      end
    end
  end

  // Observe the verdict immediately; there is no grace period for later alerts.
  assign gpio = gpio_q;

  // Ibex checks the 7 integrity bits with `prim_secded_inv_39_32_dec`, so the
  // memory has to produce them with the matching encoder.
  prim_secded_inv_39_32_enc u_instr_intg_enc (
    .data_i (instr_rdata),
    .data_o (instr_rdata_ecc)
  );

  prim_secded_inv_39_32_enc u_data_intg_enc (
    .data_i (data_rdata),
    .data_o (data_rdata_ecc)
  );

  //////////////////////////////////////////////////////////////////////////////
  // Attack detection                                                          //
  //////////////////////////////////////////////////////////////////////////////

  // A successful injection changes the auth verdict without an alert by the
  // verdict cycle. Accept alerts from lockstep, ECC, or the bus, and double faults.
  //
  // Resiliator checks fail before the verdict, but skips the check immediately
  // after injecting a fault. Latch alerts through the next rising edge so a
  // pulse ending at that edge is still visible to the driver.
  //
  // The register file and icache RAMs use ECC rather than lockstep duplication.
  logic core_alert;
  assign core_alert = alert_major_internal | alert_major_bus | double_fault_seen;

  logic alert_seen_q;
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      alert_seen_q <= 1'b0;
    end else if (core_alert) begin
      alert_seen_q <= 1'b1;
    end
  end

  assign fail = core_alert | alert_seen_q | mem_fail_q;

  //////////////////////////////////////////////////////////////////////////////
  // DUT                                                                       //
  //////////////////////////////////////////////////////////////////////////////

  ibex_top #(
    .PMPEnable        (1'b1),
    .PMPGranularity   (0),
    .PMPNumRegions    (16),
    .MHPMCounterNum   (2),
    .MHPMCounterWidth (32),
    .PMPRstCfg        (PmpCfgRstTb),
    .PMPRstAddr       (PmpAddrRstTb),
    .PMPRstMsecCfg    (PmpMseccfgRstTb),
    .RV32E            (1'b0),
    .RV32M            (RV32MSingleCycle),
    .RV32B            (RV32BOTEarlGrey),
    .RV32ZC           (RV32ZcaZcbZcmp),
    .RegFile          (RegFileFF),
    .BranchTargetALU  (1'b1),
    .WritebackStage   (1'b1),
    .ICache           (1'b1),
    .ICacheECC        (1'b1),
    .ICacheScramble   (1'b1),
    // Egret reduces the instruction cache to 2 PRINCE half rounds to ease
    // timing (see `rv_core_ibex.sv`).
    .ICacheScrNumPrinceRoundsHalf (2),
    .BranchPredictor  (1'b0),
    .DbgTriggerEn     (1'b1),
    .DbgHwBreakNum    (4),
    // Turns on the lockstep shadow core.
    .SecureIbex       (1'b1),
    .LockstepOffset   (1),
    .RndCnstIbexKey   (TestScrambleKey),
    .RndCnstIbexNonce (TestScrambleNonce),
    .CsrMvendorId     (32'b0),
    .CsrMimpId        (32'b0)
  ) u_core (
    .clk_i  (clk),
    .rst_ni (rst_n),

    .test_en_i  (1'b0),
    .scan_rst_ni(1'b1),

    .ram_cfg_icache_tag_i     (prim_ram_1p_pkg::RAM_1P_CFG_DEFAULT),
    .ram_cfg_rsp_icache_tag_o (),
    .ram_cfg_icache_data_i    (prim_ram_1p_pkg::RAM_1P_CFG_DEFAULT),
    .ram_cfg_rsp_icache_data_o(),

    .hart_id_i   (32'b0),
    .boot_addr_i (BootAddr),

    .instr_req_o        (instr_req),
    .instr_gnt_i        (instr_gnt),
    .instr_rvalid_i     (instr_rvalid),
    .instr_addr_o       (instr_addr),
    .instr_rdata_i      (instr_rdata),
    .instr_rdata_intg_i (instr_rdata_ecc[38:32]),
    .instr_err_i        (instr_err),

    .data_req_o         (data_req),
    .data_gnt_i         (data_gnt),
    .data_rvalid_i      (data_rvalid),
    .data_we_o          (data_we),
    .data_be_o          (data_be),
    .data_addr_o        (data_addr),
    .data_wdata_o       (data_wdata),
    .data_wdata_intg_o  (data_wdata_intg),
    .data_rdata_i       (data_rdata),
    .data_rdata_intg_i  (data_rdata_ecc[38:32]),
    .data_err_i         (data_err),

    .irq_software_i (1'b0),
    .irq_timer_i    (1'b0),
    .irq_external_i (1'b0),
    .irq_fast_i     (15'b0),
    .irq_nm_i       (1'b0),

    .scramble_key_valid_i (1'b1),
    .scramble_key_i       (TestScrambleKey),
    .scramble_nonce_i     (TestScrambleNonce),
    .scramble_req_o       (scramble_req),

    .debug_req_i          (1'b0),
    .crash_dump_o         (crash_dump),
    .double_fault_seen_o  (double_fault_seen),

    .fetch_enable_i         (IbexMuBiOn),
    .alert_minor_o          (alert_minor),
    .alert_major_internal_o (alert_major_internal),
    .alert_major_bus_o      (alert_major_bus),
    .core_sleep_o           (core_sleep),

    // Shadow-core observation outputs, used by rv_core_ibex to build its TL-UL
    // comparators. Nothing consumes them here.
    .lockstep_cmp_en_o        (),
    .data_req_shadow_o        (),
    .data_we_shadow_o         (),
    .data_be_shadow_o         (),
    .data_addr_shadow_o       (),
    .data_wdata_shadow_o      (),
    .data_wdata_intg_shadow_o (),
    .instr_req_shadow_o       (),
    .instr_addr_shadow_o      ()
  );

  logic unused;
  assign unused = ^{alert_minor,
                    core_sleep,
                    scramble_req,
                    crash_dump,
                    data_wdata_intg,
                    instr_rdata_ecc[31:0],
                    data_rdata_ecc[31:0]};

endmodule
