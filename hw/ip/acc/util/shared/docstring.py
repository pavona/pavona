# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
'''Find the docstrings of labels in ACC assembly.'''

import re
from typing import List, Optional, Tuple


def docstring_above(lines: List[str], idx: int) -> Optional[Tuple[int, str]]:
    '''Return the line index and text of the docstring of lines[idx].'''
    nearest = None
    i = idx - 1
    while i >= 0:
        stripped = lines[i].strip()
        if stripped.endswith('*/'):
            end = i
            while i >= 0 and '/*' not in lines[i]:
                i -= 1
            if i < 0:
                break
            text = '\n'.join(re.sub(r'^\s*(/\*+|\*/|\*)', '', line).strip()
                             for line in lines[i:end + 1])
            if 'clobbered registers:' in text.lower():
                return i, text
            if nearest is None:
                nearest = (i, text)
        elif stripped and not stripped.startswith(('.', '#', '//')):
            break
        i -= 1
    return nearest
