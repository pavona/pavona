// Copyright Pavona contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Assertions for the memset (read_en=0) and verify (write_en=0) operations:
//  - no source port traffic during a memset, no destination port traffic during a verify;
//  - the FSM never deadlocks for either op, always reaching DmaShaFinalize or DmaIdle.
// Bound into `dma` from `dma_bind`.

`include "prim_assert.sv"

module dma_memset_verify_sva
  import dma_pkg::*;
(
  input logic            clk_i,
  input logic            rst_ni,
  input logic            gated_clk,
  input dma_ctrl_state_e ctrl_state_q,
  input logic            do_read,
  input logic            do_write,
  input logic            read_issue,
  input logic            write_issue
);

  // No-traffic safety: a memset (read_en=0) must never issue a source read request, and a verify
  // (write_en=0) must never issue a destination write request. `read_issue`/`write_issue` are the
  // hard-gated request strobes to the source/destination ports, so a stray field fault cannot
  // synthesize unchecked traffic without tripping these.
  `ASSERT(MemsetNoSrcTraffic_A, !do_read |-> !read_issue, gated_clk, !rst_ni)
  `ASSERT(VerifyNoDstTraffic_A, !do_write |-> !write_issue, gated_clk, !rst_ni)

  // No-deadlock liveness: once the per-beat region is entered for a memset or a verify, the FSM
  // must eventually reach a terminal state (DmaShaFinalize for a digesting op, otherwise DmaIdle).
  // Uses the ungated clock so the property is not vacuously stalled by the operation's clock gate.
  // Disabled around an in-progress error/abort, which legitimately diverts the FSM to DmaError/Idle.
  `ASSERT(MemsetNoDeadlock_A,
          (ctrl_state_q inside {DmaSendWrite, DmaWaitWriteResponse}) && !do_read |->
          s_eventually (ctrl_state_q inside {DmaIdle, DmaShaFinalize, DmaError}),
          clk_i, !rst_ni)
  `ASSERT(VerifyNoDeadlock_A,
          (ctrl_state_q inside {DmaSendRead, DmaWaitReadResponse, DmaShaWait}) && !do_write |->
          s_eventually (ctrl_state_q inside {DmaIdle, DmaShaFinalize, DmaError}),
          clk_i, !rst_ni)

endmodule
