# Copyright zeroRISC Inc & MPI-SP.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

'''Tests for acc_as.py's handling of macro/.irp/.irpc parameters used as
bn.* operands (see Transformer.mk_symbolic_line in acc_as.py).

simple/macros/*.s exercises this end to end but can't express expected
failures, and only covers the registers it happens to use. Here we instead
check the symbolic encoding against the literal-operand path for every
register operand in the ISA, plus the various ways a parameterized operand
can be rejected.
'''

import os
import subprocess
import sys

import py

UTIL_DIR = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'util')
sys.path.insert(0, UTIL_DIR)

from shared.insn_yaml import load_insns_yaml  # noqa: E402
from shared.operand import RegOperandType  # noqa: E402

ACC_AS = os.path.join(UTIL_DIR, 'acc_as.py')


def test_symbolic_register_operand_matches_literal_encoding() -> None:
    '''mk_symbolic_line emits "sym << lsb" for a register operand, which is
    only equivalent to BitRanges.encode() because every register field in
    the ISA is a single contiguous range. Check that holds everywhere: a
    split register field would otherwise be silently mis-encoded.

    '''
    insns_file = load_insns_yaml()
    checked = 0
    for insn in insns_file.insns:
        if insn.encoding is None:
            continue
        for field in insn.encoding.fields.values():
            if not isinstance(field.value, str):
                continue
            op_type = insn.name_to_operand[field.value].op_type
            if not isinstance(op_type, RegOperandType):
                continue

            bits = field.scheme_field.bits
            assert len(bits.ranges) == 1, (insn.mnemonic, field.value)
            _, lsb = bits.ranges[0]
            for idx in (0, 1, 17, 31):
                assert idx << lsb == bits.encode(idx), (insn.mnemonic,
                                                        field.value, idx)
                checked += 1
    assert checked > 0


def _run_acc_as(tmpdir: py.path.local, src: str) -> 'subprocess.CompletedProcess[str]':
    src_file = os.path.join(tmpdir, 'in.s')
    with open(src_file, 'w') as f:
        f.write(src)
    out_file = os.path.join(tmpdir, 'out.o')
    return subprocess.run([ACC_AS, '-o', out_file, src_file],
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          universal_newlines=True)


def test_backslash_outside_body_is_rejected(tmpdir: py.path.local) -> None:
    proc = _run_acc_as(tmpdir, 'bn.xor \\a, w0, w1\necall\n')
    assert proc.returncode != 0
    assert 'not inside a' in proc.stderr


def test_altmacro_is_rejected(tmpdir: py.path.local) -> None:
    proc = _run_acc_as(tmpdir, '.altmacro\necall\n')
    assert proc.returncode != 0
    assert 'not supported' in proc.stderr


def test_parameterized_enum_operand_is_rejected(tmpdir: py.path.local) -> None:
    src = ('.macro m d, a, b, dir\n'
          '    bn.add \\d, \\a, \\b \\dir 3\n'
          '.endm\n'
          'm w0, w1, w2, <<\n'
          'ecall\n')
    proc = _run_acc_as(tmpdir, src)
    assert proc.returncode != 0
    assert 'cannot be a macro' in proc.stderr


def test_li_with_parameterized_immediate_is_rejected(tmpdir: py.path.local) -> None:
    src = ('.macro m r, n\n'
          '    li \\r, \\n\n'
          '.endm\n'
          'm x5, 100\n'
          'ecall\n')
    proc = _run_acc_as(tmpdir, src)
    assert proc.returncode != 0
    assert 'LI cannot take' in proc.stderr


def test_parameterized_immediate_is_rejected(tmpdir: py.path.local) -> None:
    src = ('.macro m d, a, n\n'
          '    bn.addi \\d, \\a, \\n\n'
          '.endm\n'
          'm w0, w1, 5\n'
          'ecall\n')
    proc = _run_acc_as(tmpdir, src)
    assert proc.returncode != 0
    assert 'only register operands can' in proc.stderr


def test_endloop_with_no_open_loop_inside_macro_is_rejected(tmpdir: py.path.local) -> None:
    src = ('.macro m\n'
          '    endloop\n'
          '.endm\n'
          'm\n'
          'ecall\n')
    proc = _run_acc_as(tmpdir, src)
    assert proc.returncode != 0
    assert 'no open loop' in proc.stderr
