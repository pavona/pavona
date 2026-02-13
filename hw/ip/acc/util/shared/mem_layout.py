# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

'''Simple code that understands enough of acc.hjson to get a memory layout

Each memory will have an associated "window" entry, which has an offset from
the start of the IP block's register space. This offset will be treated as an
LMA for this memory and these memory LMAs will be used uniformly in
ACC-specific tooling. This avoids the result depending on the address layout
of the wider chip.

In particular, note that ACC ELF binaries will use these LMAs (the VMAs are in
ACC's address space, with both IMEM and DMEM starting at 0). A tool that takes
such binaries and incorporates them into a top-level image will need to do
address translation (essentially, just adding the base address of the ACC IP
block).

'''

from typing import Dict, Optional, Tuple

from reggen.reg_block import RegBlock

from .acc_reggen import load_registers

# A window is represented as (offset, size)
_Window = Tuple[int, int]

# This needs to be kept in sync with the parameter of the same name in
# acc_pkg.sv
_DmemScratchSizeBytes = 1024


def extract_windows(reg_byte_width: int, regs: object) -> Dict[str, _Window]:
    '''Make sense of the list of register definitions and extract memories'''

    windows = {}

    assert isinstance(regs, RegBlock)
    for entry in regs.windows:
        name = entry.name or 'Window at +{:#x}'.format(entry.offset)

        # Should be guaranteed by RegBlock constructor
        assert name not in windows

        windows[name] = (entry.offset, entry.size_in_bytes)

    return windows


class AccMemoryLayout:
    def __init__(self, windows: Dict[str, _Window]):
        imem_window = windows.get('IMEM')
        if imem_window is None:
            raise RuntimeError('acc.hjson has no IMEM window')

        dmem_window = windows.get('DMEM')
        if dmem_window is None:
            raise RuntimeError('acc.hjson has no DMEM window')

        self.imem_address = imem_window[0]
        self.imem_size_bytes = imem_window[1]

        self.dmem_address = dmem_window[0]
        self.dmem_bus_size_bytes = dmem_window[1]
        self.dmem_size_bytes = dmem_window[1] + _DmemScratchSizeBytes


_LAYOUT: Optional[AccMemoryLayout] = None


def get_memory_layout() -> AccMemoryLayout:
    '''Read acc.hjson to get IMEM / DMEM layout

    Returns a dictionary with two entries, keyed 'IMEM' and 'DMEM'. The value
    at each entry is a pair (offset, size_in_bytes).

    '''
    global _LAYOUT
    if _LAYOUT is not None:
        return _LAYOUT

    reg_byte_width, registers = load_registers()
    windows = extract_windows(reg_byte_width, registers)

    _LAYOUT = AccMemoryLayout(windows)
    return _LAYOUT
