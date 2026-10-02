// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

package dma_pkg;
  // Create a type to be exposed for the inter_signal_list in the HJSON definition
  // This type is needed since regtool cannot evaluate parameters defined in the HJSON
  typedef logic [dma_reg_pkg::NumIntClearSources-1:0] lsio_trigger_t;

  // Possible error bits the DMA can raise
  typedef enum logic [3:0] {
    DmaSrcAddrErr,
    DmaDstAddrErr,
    DmaOpcodeErr,
    DmaSizeErr,
    DmaBusErr,
    DmaBaseLimitErr,
    DmaRangeValidErr,
    DmaAsidErr,
    DmaAesTagErr,
    DmaErrLast
  } dma_error_e;

  // DMAC Transfer width as encoded in `transfer_width` register
  typedef enum logic [1:0] {
    DmaXfer1BperTxn = 2'h0,
    DmaXfer2BperTxn = 2'h1,
    DmaXfer4BperTxn = 2'h2
  } dma_transfer_width_e;

  // Translated extended Hamming [8,4,4] code: 16 IDs, minimum distance four.
  // Zero and all-ones are invalid. An ID is usable only when present in PortDesc;
  // unused codewords are reserved for future ports. IDs never depend on port order.
  parameter int unsigned ASID_WIDTH = 8;
  parameter int unsigned MaxPorts = 16;

  typedef enum logic [ASID_WIDTH-1:0] {
    Asid0 = 8'h03, Asid1 = 8'h0c, Asid2 = 8'h30, Asid3 = 8'h3f,
    Asid4 = 8'h56, Asid5 = 8'h59, Asid6 = 8'h65, Asid7 = 8'h6a,
    Asid8 = 8'h95, Asid9 = 8'h9a, Asid10 = 8'ha6, Asid11 = 8'ha9,
    Asid12 = 8'hc0, Asid13 = 8'hcf, Asid14 = 8'hf3, Asid15 = 8'hfc
  } asid_encoding_e;

  // Names for the default integration, not special cases in the routing logic.
  parameter asid_encoding_e OtInternalAddr = Asid0;
  parameter asid_encoding_e SocControlAddr = Asid1;
  parameter asid_encoding_e SocSystemAddr = Asid2;

  function automatic bit dma_asid_code_valid(logic [ASID_WIDTH-1:0] asid);
    return asid inside {Asid0, Asid1, Asid2, Asid3, Asid4, Asid5, Asid6, Asid7,
                        Asid8, Asid9, Asid10, Asid11, Asid12, Asid13, Asid14, Asid15};
  endfunction

  ////////////////////////////////
  // Generic host port descriptor //
  ////////////////////////////////

  typedef enum logic [0:0] {
    PortTlul32,
    PortTlul64
  } dma_port_class_e;

  typedef struct packed {
    asid_encoding_e                 asid;
    dma_port_class_e                cls;
    logic                           range_check;
    logic [tlul_pkg::RsvdWidth-1:0] user_rsvd;
  } dma_port_desc_t;

  parameter dma_port_desc_t DmaPortOtInternal =
      '{asid: OtInternalAddr, cls: PortTlul32, range_check: 1'b1, user_rsvd: '0};
  parameter dma_port_desc_t DmaPortSocControl =
      '{asid: SocControlAddr, cls: PortTlul32, range_check: 1'b0, user_rsvd: '0};
  parameter dma_port_desc_t DmaPortSocSystem  =
      '{asid: SocSystemAddr, cls: PortTlul64, range_check: 1'b0, user_rsvd: '0};

  parameter int unsigned NumPortsDefault = 3;
  parameter dma_port_desc_t DmaPortDesc [NumPortsDefault] = '{
    DmaPortOtInternal,
    DmaPortSocControl,
    DmaPortSocSystem
  };

  // Default integration's membership mask, also usable directly by DV constraints.
  function automatic bit [(1 << ASID_WIDTH)-1:0] dma_configured_asids();
    dma_configured_asids = '0;
    foreach (DmaPortDesc[p]) dma_configured_asids[DmaPortDesc[p].asid] = 1'b1;
  endfunction
  parameter bit [(1 << ASID_WIDTH)-1:0] ConfiguredAsids = dma_configured_asids();

  function automatic bit dma_asid_configured(asid_encoding_e asid);
    return ConfiguredAsids[asid];
  endfunction

  function automatic int unsigned dma_count_class(dma_port_class_e c);
    dma_count_class = 0;
    for (int unsigned i = 0; i < NumPortsDefault; i++) begin
      if (DmaPortDesc[i].cls == c) dma_count_class = dma_count_class + 1;
    end
  endfunction

  function automatic int unsigned dma_class_subidx(int unsigned p);
    dma_class_subidx = 0;
    for (int unsigned i = 0; i < p; i++) begin
      if (DmaPortDesc[i].cls == DmaPortDesc[p].cls) dma_class_subidx = dma_class_subidx + 1;
    end
  endfunction

  parameter int unsigned NumTlul32Default = dma_count_class(PortTlul32);
  parameter int unsigned NumTlul64Default = dma_count_class(PortTlul64);

  function automatic int unsigned dma_max1(int unsigned n);
    dma_max1 = (n > 0) ? n : 1;
  endfunction

  parameter int unsigned DmaPortIdxW = prim_util_pkg::vbits(NumPortsDefault);

  // Inline-hashing digest selector carried in the captured control state.
  typedef enum logic [1:0] {
    DigestNone   = 2'd0,
    DigestSha256 = 2'd1,
    DigestSha384 = 2'd2,
    DigestSha512 = 2'd3
  } dma_digest_e;

  // Inline-AES operation selector (CONTROL.aes_op, plain encoding; reserved value -> opcode error).
  typedef enum logic [1:0] {
    DmaAesOpOff = 2'd0,
    DmaAesOpEnc = 2'd1,
    DmaAesOpDec = 2'd2
  } dma_aes_op_e;

  // Named bit definitions for the SRC_ and DST_CTRL register for convenience
  parameter bit AddrIncrement   = 1'b1;
  parameter bit AddrNoIncrement = 1'b0;
  parameter bit AddrWrapChunk   = 1'b1;
  parameter bit AddrNoWrapChunk = 1'b0;

  // Control state captured during the operation
  typedef struct packed {
    // Control register
    logic        read_en;
    logic        write_en;
    dma_digest_e digest_sel;
    logic       cfg_handshake_en;
    logic       cfg_digest_swap;
    logic       range_valid;
    // Inline AES: cipher active (CONTROL.aes_op != Off), decrypt (Dec), and GCM mode.
    logic       aes_en;
    logic       aes_decrypt;
    logic       aes_gcm;
    // Enabled memory base register
    logic [31:0] enabled_memory_range_base;
    // Enabled memory limit register
    logic [31:0] enabled_memory_range_limit;
  } control_state_t;


  // Encoding generated with:
  // $ ./util/design/sparse-fsm-encode.py -d 3 -m 20 -n 9 \
  //     -s 8273645 --language=sv
  // Existing encodings are zero-extended; the ninth bit provides code space for the inline-AES
  // states while preserving a minimum Hamming distance of three.
  //
  // Hamming distance histogram:
  //
  //  0: --
  //  1: --
  //  2: --
  //  3: ||||||||||||| (25.26%)
  //  4: ||||||||||||||||||| (34.74%)
  //  5: |||||||||| (18.95%)
  //  6: |||||| (11.58%)
  //  7: |||| (7.89%)
  //  8: | (1.58%)
  //  9: --
  //
  // Minimum Hamming distance: 3
  // Maximum Hamming distance: 8
  // Minimum Hamming weight: 2
  // Maximum Hamming weight: 7

  typedef enum logic [8:0] {
    DmaIdle                 = 9'b011110111,
    DmaClearIntrSrc         = 9'b010101100,
    DmaWaitIntrSrcResponse  = 9'b000101011,
    DmaAddrSetup            = 9'b011110000,
    DmaSendRead             = 9'b001000011,
    DmaWaitReadResponse     = 9'b000011111,
    DmaSendWrite            = 9'b010010100,
    DmaWaitWriteResponse    = 9'b011011001,
    DmaError                = 9'b001010110,
    DmaShaFinalize          = 9'b000110001,
    DmaShaWait              = 9'b001111010,
    DmaCfgValidate          = 9'b001001101,
    DmaReadBurst            = 9'b010000001,
    DmaWriteBurst           = 9'b010001010,
    DmaRunPipe              = 9'b000011000,
    // Inline AES block-serial sub-FSM.
    DmaAesGather            = 9'b100000101,
    DmaAesProcess           = 9'b100001110,
    DmaAesScatter           = 9'b100010010,
    DmaAesGhashAad          = 9'b100101000,
    DmaAesTag               = 9'b100110100
  } dma_ctrl_state_e;

  // Maximum number of outstanding TL-UL requests per host port. >1 enables the read-ahead
  // burst datapath (DmaReadBurst/DmaWriteBurst) to keep multiple read requests in flight and
  // hide memory/bus read latency.
  //
  // Response ordering requirement: the burst path matches read data to metadata in arrival
  // order and does not inspect d_source. With NUM_MAX_OUTSTANDING_REQS > 1, each connected
  // fabric must therefore return all read responses in the order their requests were accepted,
  // across all source IDs. The OpenTitan-internal fabric provides this ordering; external
  // integrations must guarantee it. Otherwise, set NUM_MAX_OUTSTANDING_REQS to 1 or add a
  // d_source-indexed reorder buffer. See the read-ahead ordering section in
  // doc/theory_of_operation.md.
  parameter int unsigned NUM_MAX_OUTSTANDING_REQS = 8;

  // Depth of the read-ahead data/metadata FIFOs (also the maximum read burst length).
  parameter int unsigned DMA_BURST_FIFO_DEPTH = 8;

  // Internal address-arithmetic width. The DMA holds and increments src/dst
  // addresses at this width; 32-bit ports truncate to top_pkg::TL_AW, 64-bit
  // (off-bus) ports use the full width.
  parameter int unsigned DMA_ADDR_WIDTH = 64;

endpackage
