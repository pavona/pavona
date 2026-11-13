/* Copyright Konrad Jansen, Vincent Quentin Ulitzsch, Niclas Kuehnapfel */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Linker script for the testbench's flat SRAM at address zero.
 * Ibex requires the exception entry at 0x00 and reset entry at 0x80.
 * start.S places both in .init.
 * LENGTH must match MemSizeByte in ibex_resiliator_top.sv.
 */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY {
  ram(rwxa) : ORIGIN = 0x00000000, LENGTH = 0x20000
}

/* Required by sw/device/info_sections.ld, included at the end. Nothing here
 * uses DV logging, so the offset is irrelevant; match the ROM's choice. */
_dv_log_offset = 0x0;

SECTIONS {
  /* Trap handler at 0x0 and reset vector at 0x80. */
  .init ORIGIN(ram) : {
    KEEP(*(.init))
  } > ram

  .text : {
    /* //sw/device/lib/crt puts its helpers in .crt. */
    *(.crt)
    *(.text)
    *(.text.*)
  } > ram

  .rodata : {
    *(.rodata)
    *(.rodata.*)
    *(.srodata)
    *(.srodata.*)
  } > ram

  .data : {
    *(.data)
    *(.data.*)
    *(.sdata)
    *(.sdata.*)
  } > ram

  /* crt_section_clear requires both bounds to be word aligned. */
  .bss : ALIGN(4) {
    _bss_start = .;
    *(.bss)
    *(.bss.*)
    *(.sbss)
    *(.sbss.*)
    *(COMMON)
    . = ALIGN(4);
    _bss_end = .;
  } > ram

  /* Full-descending stack from the top of SRAM. */
  _stack_top = ORIGIN(ram) + LENGTH(ram);

  /* Non-allocated sections the toolchain and host tools expect, plus the
   * /DISCARD/ block. In particular this provides .ot.status_create_record,
   * which pavona_binary's module-ID validation requires to be present even
   * when nothing here uses the status_t machinery. */
  INCLUDE sw/device/info_sections.ld
}
