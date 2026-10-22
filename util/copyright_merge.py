# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""
Copy the copyright lines from a generator's source file into its output.
"""

import re
from typing import List, Optional, Tuple

COMMENT_MARKERS = ('//', '#')
COPYRIGHT_PATTERN = r'(Copyright\s|Modified by\s)'
# REUSE-IgnoreStart
LICENSE_PATTERN = r'(Licensed under|SPDX-License-Identifier:)'
# REUSE-IgnoreEnd


def _get_comment_char(line: str, comment_markers: Tuple[str, ...]) -> Optional[str]:
    """Return the comment marker the line starts with, or None."""
    for comment in comment_markers:
        if line.startswith(comment):
            return comment
    return None


def _get_matching_text(line: str, comment_markers: Tuple[str, ...], pattern: str) -> Optional[str]:
    """Return line's text without its comment marker if it matches the pattern, or None."""
    marker = _get_comment_char(line, comment_markers)
    if marker is None:
        return None
    text = line[len(marker):].strip()
    return text if re.match(pattern, text, re.IGNORECASE) else None


def _extract(text: str, comment_markers: Tuple[str, ...], pattern: str) -> List[Tuple[int, str]]:
    """Return lines (and their index) of the first comment block that match the pattern."""
    matches = []
    for i, line in enumerate(text.split('\n')):
        if _get_comment_char(line, comment_markers) is None:
            break
        match = _get_matching_text(line, comment_markers, pattern)
        if match is not None:
            matches.append((i, match))
    return matches


def extract_copyright(text: str,
                      comment_markers: Tuple[str, ...] = COMMENT_MARKERS
                      ) -> List[str]:
    """Return copyright lines of the first comment block."""
    return [line for _, line in _extract(text, comment_markers, COPYRIGHT_PATTERN)]


def extract_license(text: str,
                    comment_markers: Tuple[str, ...] = COMMENT_MARKERS
                    ) -> List[str]:
    """Return license lines of the first comment block."""
    return [line for _, line in _extract(text, comment_markers, LICENSE_PATTERN)]


def merge_copyright(text: str, copyrights: List[str], comment_marker: str = '//') -> str:
    """Add copyrights missing from text's leading comment block.
    Missing lines are placed after the last existing copyright line.
    """
    match = _extract(text, (comment_marker,), COPYRIGHT_PATTERN)
    if not match:
        return text
    present = {copyright_text for _, copyright_text in match}
    insert_at = match[-1][0] + 1  # index of last copyright line + 1
    missing = [f'{comment_marker} {c}' for c in copyrights if c not in present]
    text_lines = text.split('\n')
    text_lines[insert_at:insert_at] = missing
    return '\n'.join(text_lines)


def merge_copyright_from(text: str, src_text: str, comment_marker: str = '//',
                         src_comment_markers: Tuple[str, ...] = COMMENT_MARKERS) -> str:
    """Add the missing copyrights of src_text to text."""
    return merge_copyright(text, extract_copyright(src_text, src_comment_markers), comment_marker)
