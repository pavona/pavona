// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Imports for the functions defined in acc_memutil.h. There are documentation comments explaining
// what the functions do there.
`ifndef SYNTHESIS
package acc_memutil_pkg;

  import "DPI-C" function chandle AccMemUtilMake(string top_scope);

  import "DPI-C" function void AccMemUtilFree(chandle mem_util);

  import "DPI-C" context function bit AccMemUtilLoadElf(chandle mem_util, string elf_path);

  import "DPI-C" function bit AccMemUtilStageElf(chandle mem_util, string elf_path);

  import "DPI-C" function int AccMemUtilGetSegCount(chandle mem_util, bit is_imem);

  import "DPI-C" function bit AccMemUtilGetSegInfo(chandle mem_util, bit is_imem, int seg_idx,
                                                    output bit [31:0] seg_off,
                                                    output bit [31:0] seg_size);

  import "DPI-C" function bit AccMemUtilGetSegData(chandle mem_util, bit is_imem, int word_off,
                                                    output bit [31:0] data_value);

  import "DPI-C" function int AccMemUtilGetExpEndAddr(chandle mem_util);

  import "DPI-C" function bit AccMemUtilGetLoopWarp(chandle           mem_util,
                                                     bit [31:0]        addr,
                                                     bit [31:0]        from_cnt,
                                                     output bit [31:0] to_cnt);

  import "DPI-C" function int AccMemUtilGetNumLoopWarps(chandle mem_util);

  import "DPI-C" function void AccMemUtilGetLoopWarpByIndex(chandle           mem_util,
                                                             int               idx,
                                                             output bit [31:0] addr,
                                                             output bit [31:0] from_cnt,
                                                             output bit [31:0] to_cnt);
endpackage
`endif // SYNTHESIS
