// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Wide TLUL flavor for the DMA host port: like tlul_pkg h2d types but with a
// 64-bit address (dma_pkg::DMA_ADDR_WIDTH) and a wider command-integrity domain.
// d2h responses carry no address and reuse tlul_pkg types.

package dma_tlul_pkg;

  import tlul_pkg::*;
  import dma_pkg::*;

  // Wide host-port address width (64-bit).
  parameter int unsigned DmaTlAw = dma_pkg::DMA_ADDR_WIDTH;

  // Command-integrity ECC width and SECDED payload width for the wide command word.
  // DmaH2DCmdMaxWidth must be >= $bits(dma_tl_h2d_cmd_intg_t).
  parameter int DmaH2DCmdIntgWidth = 8;
  parameter int DmaH2DCmdMaxWidth  = 80;

  // Reserved-field width that fills the a_user to exactly TL_AUW. Mirrors stock
  // tlul_pkg::RsvdWidth, but accounts for this struct's wider (8-bit) cmd_intg so that
  // $bits(dma_tl_a_user_t) == top_pkg::TL_AUW.
  parameter int DmaRsvdWidth = top_pkg::TL_AUW - prim_mubi_pkg::MuBi4Width -
                               DmaH2DCmdIntgWidth - tlul_pkg::DataIntgWidth;

  typedef struct packed {
    logic [DmaRsvdWidth-1:0]       rsvd;
    prim_mubi_pkg::mubi4_t         instr_type;
    logic [DmaH2DCmdIntgWidth-1:0] cmd_intg;
    logic [DataIntgWidth-1:0]      data_intg;
  } dma_tl_a_user_t;

  parameter dma_tl_a_user_t DMA_TL_A_USER_DEFAULT = '{
    rsvd: '0,
    instr_type: prim_mubi_pkg::MuBi4False,
    cmd_intg:  {DmaH2DCmdIntgWidth{1'b1}},
    data_intg: {DataIntgWidth{1'b1}}
  };

  // Command word for command integrity: like tlul_pkg::tl_h2d_cmd_intg_t with a DmaTlAw address.
  typedef struct packed {
    prim_mubi_pkg::mubi4_t        instr_type;
    logic        [DmaTlAw-1:0]    addr;
    tl_a_op_e                     opcode;
    logic  [top_pkg::TL_DBW-1:0]  mask;
  } dma_tl_h2d_cmd_intg_t;

  typedef struct packed {
    logic                         a_valid;
    tl_a_op_e                     a_opcode;
    logic                  [2:0]  a_param;
    logic  [top_pkg::TL_SZW-1:0]  a_size;
    logic  [top_pkg::TL_AIW-1:0]  a_source;
    logic        [DmaTlAw-1:0]    a_address;
    logic  [top_pkg::TL_DBW-1:0]  a_mask;
    logic   [top_pkg::TL_DW-1:0]  a_data;
    dma_tl_a_user_t               a_user;

    logic                         d_ready;
  } dma_tl_h2d_t;

  // Responses carry no address; reuse the standard TLUL d2h type verbatim.
  typedef tlul_pkg::tl_d2h_t dma_tl_d2h_t;

  // Blanked a_data value; all-1s rationale: see tlul_pkg::BlankedAData.
  localparam logic [top_pkg::TL_DW-1:0] DmaBlankedAData = {top_pkg::TL_DW{1'b1}};

  localparam dma_tl_h2d_t DMA_TL_H2D_DEFAULT = '{
    d_ready:  1'b1,
    a_opcode: tl_a_op_e'('0),
    a_user:   DMA_TL_A_USER_DEFAULT,
    a_data:   DmaBlankedAData,
    default:  '0
  };

  localparam dma_tl_d2h_t DMA_TL_D2H_DEFAULT = tlul_pkg::TL_D2H_DEFAULT;

  // extract variables used for command checking
  function automatic dma_tl_h2d_cmd_intg_t dma_extract_h2d_cmd_intg(dma_tl_h2d_t tl);
    dma_tl_h2d_cmd_intg_t payload;
    logic unused_tlul;
    unused_tlul = ^tl;
    payload.addr = tl.a_address;
    payload.opcode = tl.a_opcode;
    payload.mask = tl.a_mask;
    payload.instr_type = tl.a_user.instr_type;
    return payload;
  endfunction // dma_extract_h2d_cmd_intg

  // calculate ecc for command checking
  function automatic logic [DmaH2DCmdIntgWidth-1:0] dma_get_cmd_intg(dma_tl_h2d_t tl);
    logic [DmaH2DCmdIntgWidth-1:0] cmd_intg;
    logic [DmaH2DCmdMaxWidth-1:0] unused_cmd_payload;
    dma_tl_h2d_cmd_intg_t cmd;
    cmd = dma_extract_h2d_cmd_intg(tl);
    {cmd_intg, unused_cmd_payload} =
        prim_secded_pkg::prim_secded_inv_88_80_enc(DmaH2DCmdMaxWidth'(cmd));
   return cmd_intg;
  endfunction  // dma_get_cmd_intg

endpackage
