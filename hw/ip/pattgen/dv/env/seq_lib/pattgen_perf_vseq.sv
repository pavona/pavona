// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// basic perf test vseq
class pattgen_perf_vseq extends pattgen_base_vseq;
  `uvm_object_utils(pattgen_perf_vseq)

  // reduce num_trans due to long running simulations
  constraint num_trans_c        { num_trans inside {[3:6]}; }

  function new (string name="");
    super.new(name);
    pattgen_max_dly = 0;
  endfunction

  // override this function for pattgen_perf test
  function pattgen_channel_cfg get_random_channel_config(uint channel);
    pattgen_channel_cfg ch_cfg;
    ch_cfg = pattgen_channel_cfg::type_id::create($sformatf("channel_cfg_%0d", channel));
    `DV_CHECK_RANDOMIZE_WITH_FATAL(ch_cfg,
      ch_cfg.prediv dist {0 :/ 1, 1024 :/ 1};
      ch_cfg.len    dist {0 :/ 1,   63 :/ 1};
      ch_cfg.reps   dist {0 :/ 1, 1023 :/ 1};
      // 2 * (prediv + 1) * (len + 1) * (reps + 1) = duration (in clock cycles) of a pattern
      // The timeout for pattgen tests is set to 600ms; we set these parameters to never
      // exceed the timeout for the duration of a pattern.
      // Assuming the minimum clock for simulation (check dv_macros.svh) of
      // 5Mhz, we get:
      //  max duration = (2 * 500,000 cycles) / 5MHz = 200ms
      // Which will be below the timeout
      (ch_cfg.prediv + 1) * (ch_cfg.len + 1) * (ch_cfg.reps + 1) <= 32'd500_000; // 200ms
      // dependent constraints
      solve ch_cfg.len before ch_cfg.data;
      ch_cfg.data inside {[0 : (1 << (ch_cfg.len + 1)) - 1]};
    )
    return ch_cfg;
  endfunction : get_random_channel_config

endclass : pattgen_perf_vseq
