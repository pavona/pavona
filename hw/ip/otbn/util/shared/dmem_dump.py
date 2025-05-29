# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import re
import struct
from typing import List

from hw.ip.otbn.util.shared.mem_layout import get_memory_layout

_DMEM_RE = re.compile(r'\s*(?P<start>\d+)-(?P<end>\d+)\s*=\s*(?P<value>(:?0x[0-9a-f]+))$')

def parse_dmem_exp(exp: str) -> List[int]:
    '''Parse expected output definition for dmem.

    Expects each line to be of the form <index_start>-<index_end> = <value>,
    where <index_{start,end}> are decimal byte offsets defining the dmem range
    and <value> defining the data to be present in this memory region given as
    hexadecimal with leading '0x' and padded to the size of the range.

    Ranges may appear in arbitrary order but must not overlap. Comments use
    '#'; any content in a line following '#' will be ignored.

    Returns a list of size `get_memory_layout().dmem_size_bytes` where each
    element represents one byte of the expected dmem. Undefined bytes are
    initialized as None.
    '''
    dmem_bytes = [None] * get_memory_layout().dmem_size_bytes

    for line in exp.split('\n'):
        # Remove comments and ignore blank lines.
        line = line.split('#', 1)[0].strip()
        if not line:
            continue

        m = _DMEM_RE.match(line)
        if not m:
            raise ValueError(f'Failed to parse dmem dump line ({line:!r}).')

        start = int(m.group("start"))
        end = int(m.group("end"))
        value = m.group("value")[2:]

        if len(value) // 2 != ((end + 1) - start):
            raise ValueError(f'Range does not match length of value:\
                             {len(value) // 2} vs. {(end + 1) - start}')

        if any(dmem_bytes[start:(end + 1)]):
            raise ValueError('Ranges overlapping.')

        dmem_bytes[start:(end + 1)] = [int(value[i:i + 2], 16) for i in
                                       range(0, len(value), 2)]
    return dmem_bytes


def parse_actual_dmem(dump: bytes) -> bytes:
    '''Parse the dmem dump.

    Returns the dmem bytes except integrity info.
    '''
    dmem_bytes = []
    hexdump = dump[6:]
    bindump =  bytes.fromhex(hexdump.decode('ascii'))
    # 8 32-bit data words + 1 byte integrity info per word = 40 bytes
    bytes_w_integrity = 8 * 4 + 8
    for w in struct.iter_unpack(f"<{bytes_w_integrity}s", bindump):
        tmp = []
        # discard byte indicating integrity status
        for v in struct.iter_unpack("<BI", w[0]):
            dmem_bytes += v[1].to_bytes(4, "little")
    assert len(dmem_bytes) == get_memory_layout().dmem_size_bytes
    return bytes(dmem_bytes)
