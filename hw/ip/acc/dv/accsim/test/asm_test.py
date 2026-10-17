# Copyright zeroRISC Inc & MPI-SP.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

'''Tests for acc_as.py's handling of macro/.irp/.irpc parameters used as
bn.* operands (see Transformer.mk_symbolic_line in acc_as.py).

simple/macros/*.s exercises this end to end but can't express expected
failures, and only covers the instructions/operands it happens to use. Here
we instead check the symbolic encoding against the literal-operand path for
every bn.* operand in the ISA, plus the various ways a parameterized
operand can be rejected.
'''

import io
import os
import subprocess
import sys

import py

UTIL_DIR = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'util')
sys.path.insert(0, UTIL_DIR)

import acc_as  # noqa: E402
from shared.insn_yaml import load_insns_yaml  # noqa: E402
from shared.operand import ImmOperandType, IsrOperandType, RegOperandType  # noqa: E402

ACC_AS = os.path.join(UTIL_DIR, 'acc_as.py')


def _make_transformer() -> acc_as.Transformer:
    insns_file = load_insns_yaml()
    return acc_as.Transformer(io.StringIO(), '<test>', 0, insns_file, [], {})


def test_symbolic_register_operand_matches_literal_encoding() -> None:
    '''_symbolic_bits_expr's output, evaluated, must match bits.encode()'''
    insns_file = load_insns_yaml()
    xf = _make_transformer()
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
            for idx in (0, 1, 17, 31):
                expr = xf._symbolic_bits_expr(field.scheme_field.bits,
                                              str(idx))
                got = eval(expr)  # noqa: S307 (test-controlled expression)
                want = field.scheme_field.bits.encode(idx)
                assert got == want, (insn.mnemonic, field.value, idx)
                checked += 1
    assert checked > 0


def test_symbolic_immediate_operand_matches_literal_encoding() -> None:
    '''_imm_symbolic_enc_expr's output, evaluated, must match op_val_to_enc_val()'''
    insns_file = load_insns_yaml()
    xf = _make_transformer()
    checked = 0
    for insn in insns_file.insns:
        if insn.encoding is None:
            continue
        for field in insn.encoding.fields.values():
            if not isinstance(field.value, str):
                continue
            op_type = insn.name_to_operand[field.value].op_type
            if (not isinstance(op_type, ImmOperandType) or
                    isinstance(op_type, IsrOperandType)):
                continue
            if op_type.pc_rel or op_type.width is None:
                continue

            enc_lo, enc_hi = op_type.get_enc_range()
            for offset_val in {enc_lo, enc_hi, 0}:
                # Reconstruct an operand-value expression that maps to this
                # offset_val, undoing what op_val_to_enc_val will do to it.
                op_val = (offset_val + op_type.enc_offset) << op_type.shift

                enc_expr, _guards = xf._imm_symbolic_enc_expr(
                    insn, field.value, op_type, str(op_val))
                # "/" is exact here (the corresponding .if guard would catch
                # a non-exact shift), so "//" evaluates it identically.
                got = eval(enc_expr.replace('/', '//'))  # noqa: S307
                want = op_type.op_val_to_enc_val(op_val, None)
                assert got == want, (insn.mnemonic, field.value, op_val)
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


def test_out_of_range_parameterized_immediate_is_rejected(tmpdir: py.path.local) -> None:
    src = ('.macro m d, a, n\n'
          '    bn.addi \\d, \\a, \\n\n'
          '.endm\n'
          'm w0, w1, 2000\n'
          'ecall\n')
    proc = _run_acc_as(tmpdir, src)
    assert proc.returncode != 0
    assert 'out of range' in proc.stderr


def test_endloop_with_no_open_loop_inside_macro_is_rejected(tmpdir: py.path.local) -> None:
    src = ('.macro m\n'
          '    endloop\n'
          '.endm\n'
          'm\n'
          'ecall\n')
    proc = _run_acc_as(tmpdir, src)
    assert proc.returncode != 0
    assert 'no open loop' in proc.stderr
