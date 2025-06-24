# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.


from typing import Dict, Iterator, Optional
import sys

from .constants import ErrBits
from .flags import FlagReg
from .isa import (OTBNInsn, RV32RegReg, RV32RegImm,
                  RV32ImmShift, insn_for_mnemonic, logical_byte_shift,
                  bit_shift,
                  extract_quarter_word, extract_sub_word)
from .state import OTBNState

DEBUG_MEM = False
DEBUG_BRANCH = False
DEBUG_ARITH = False
DEBUG_KMAC = False
DEBUG_FLOW = False

STACK_BENCH = False
STACK_SIZE = 20000


def eprint(text):
    print(text, file=sys.stderr)


def cmod(n, q):
    t = n % q
    # if t > floor(q / 2):
    #     t -= q
    return t


def cmod_single(n, q):
    if n < 0:
        return n + q
    elif n >= q:
        return n - q
    else:
        return n


class ADD(RV32RegReg):
    insn = insn_for_mnemonic('add', 3)

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_unsigned()
        val2 = state.gprs.get_reg(self.grs2).read_unsigned()
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return

        result = (val1 + val2) & ((1 << 32) - 1)
        if DEBUG_ARITH or (STACK_BENCH and self.grd == 2):
            eprint(f"add {val1} + {val2} = {result}")

        if STACK_BENCH and self.grd == 2:
            with open("/home/dev/src/stack_bench.txt", "r") as f:
                try:
                    prev_min = int(f.readline(), 10)
                except ValueError:
                    prev_min = 0
            print(f"result: {result} ")
            print(f"prev_min: {prev_min} ")
            print(f"STACK_SIZE - result: {STACK_SIZE - result}")
            if (STACK_SIZE - result) > prev_min:
                with open("/home/dev/src/stack_bench.txt", "w") as f:
                    f.write(str(STACK_SIZE - result))

        state.gprs.get_reg(self.grd).write_unsigned(result)


class ADDI(RV32RegImm):
    insn = insn_for_mnemonic('addi', 3)

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_unsigned()
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return

        result = (val1 + self.imm) & ((1 << 32) - 1)
        if DEBUG_ARITH or (STACK_BENCH and self.grd == 2):
            eprint(f"addi {val1} + {self.imm} = {result}")

        if STACK_BENCH and self.grd == 2 and self.imm != 0:
            with open("/home/dev/src/stack_bench.txt", "r") as f:
                try:
                    prev_min = int(f.readline(), 10)
                except ValueError:
                    prev_min = 0
            print(f"result: {result} ")
            print(f"prev_min: {prev_min} ")
            print(f"STACK_SIZE - result: {STACK_SIZE - result}")
            if (STACK_SIZE - result) > prev_min:
                with open("/home/dev/src/stack_bench.txt", "w") as f:
                    f.write(str(STACK_SIZE - result))

        state.gprs.get_reg(self.grd).write_unsigned(result)


class LUI(OTBNInsn):
    insn = insn_for_mnemonic('lui', 2)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.grd = op_vals['grd']
        self.imm = op_vals['imm']

    def execute(self, state: OTBNState) -> None:
        state.gprs.get_reg(self.grd).write_unsigned(self.imm << 12)


class SUB(RV32RegReg):
    insn = insn_for_mnemonic('sub', 3)

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_unsigned()
        val2 = state.gprs.get_reg(self.grs2).read_unsigned()
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return

        result = (val1 - val2) & ((1 << 32) - 1)
        if DEBUG_ARITH:
            eprint(f"sub {val1} - {val2} = {result}")
        state.gprs.get_reg(self.grd).write_unsigned(result)


class SLL(RV32RegReg):
    insn = insn_for_mnemonic('sll', 3)

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_unsigned()
        val2 = state.gprs.get_reg(self.grs2).read_unsigned() & 0x1f
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return

        result = (val1 << val2) & ((1 << 32) - 1)
        if DEBUG_ARITH:
            eprint(f"sll {hex(val1)} << {(val2)} = {hex(result)}")
        state.gprs.get_reg(self.grd).write_unsigned(result)


class SLLI(RV32ImmShift):
    insn = insn_for_mnemonic('slli', 3)

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_unsigned()
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return
        result = (val1 << self.shamt) & ((1 << 32) - 1)
        if DEBUG_ARITH:
            eprint(f"slli {hex(val1)} << {self.shamt} = {hex(result)}")
        state.gprs.get_reg(self.grd).write_unsigned(result)


class SRL(RV32RegReg):
    insn = insn_for_mnemonic('srl', 3)

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_unsigned()
        val2 = state.gprs.get_reg(self.grs2).read_unsigned() & 0x1f
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return

        result = val1 >> val2
        if DEBUG_ARITH:
            eprint(f"srl {hex(val1)} >> {(val2)} = {hex((result) & ((1 << 32) - 1))}")
        state.gprs.get_reg(self.grd).write_unsigned(result)


class SRLI(RV32ImmShift):
    insn = insn_for_mnemonic('srli', 3)

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_unsigned()
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return
        result = val1 >> self.shamt
        if DEBUG_ARITH:
            eprint(f"srli {hex(val1)} >> {self.shamt} = {hex(result)}")
        state.gprs.get_reg(self.grd).write_unsigned(result)


class SRA(RV32RegReg):
    insn = insn_for_mnemonic('sra', 3)

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_signed()
        val2 = state.gprs.get_reg(self.grs2).read_unsigned() & 0x1f
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return

        result = val1 >> val2
        if DEBUG_ARITH:
            eprint(f"sra {hex(val1)} >> {val2} = {hex(result)}")
        state.gprs.get_reg(self.grd).write_signed(result)


class SRAI(RV32ImmShift):
    insn = insn_for_mnemonic('srai', 3)

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_signed()
        val2 = self.shamt
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return

        result = val1 >> val2
        state.gprs.get_reg(self.grd).write_signed(result)


class AND(RV32RegReg):
    insn = insn_for_mnemonic('and', 3)

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_unsigned()
        val2 = state.gprs.get_reg(self.grs2).read_unsigned()
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return

        result = val1 & val2
        if DEBUG_ARITH:
            eprint(f"and {hex(val1)} & {hex(val2)} = {hex(val1 & val2)}")
        state.gprs.get_reg(self.grd).write_unsigned(result)


class ANDI(RV32RegImm):
    insn = insn_for_mnemonic('andi', 3)

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_unsigned()
        val2 = self.to_2s_complement(self.imm)
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return
        if DEBUG_ARITH:
            eprint(f"andi {hex(val1)} & {hex(val2)} = {hex(val1 & val2)}")
        result = val1 & val2
        state.gprs.get_reg(self.grd).write_unsigned(result)


class OR(RV32RegReg):
    insn = insn_for_mnemonic('or', 3)

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_unsigned()
        val2 = state.gprs.get_reg(self.grs2).read_unsigned()
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return
        if DEBUG_ARITH:
            eprint(f"or {hex(val1)} | {hex(val2)} = {hex(val1 | val2)}")
        result = val1 | val2
        state.gprs.get_reg(self.grd).write_unsigned(result)


class ORI(RV32RegImm):
    insn = insn_for_mnemonic('ori', 3)

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_unsigned()
        val2 = self.to_2s_complement(self.imm)
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return

        result = val1 | val2
        state.gprs.get_reg(self.grd).write_unsigned(result)


class XOR(RV32RegReg):
    insn = insn_for_mnemonic('xor', 3)

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_unsigned()
        val2 = state.gprs.get_reg(self.grs2).read_unsigned()
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return

        result = val1 ^ val2
        state.gprs.get_reg(self.grd).write_unsigned(result)


class XORI(RV32RegImm):
    insn = insn_for_mnemonic('xori', 3)

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_unsigned()
        val2 = self.to_2s_complement(self.imm)
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return

        result = val1 ^ val2
        state.gprs.get_reg(self.grd).write_unsigned(result)


class LW(OTBNInsn):
    insn = insn_for_mnemonic('lw', 3)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.grd = op_vals['grd']
        self.offset = op_vals['offset']
        self.grs1 = op_vals['grs1']

    def execute(self, state: OTBNState) -> Optional[Iterator[None]]:
        # LW executes over two cycles. On the first cycle, we read the base
        # address, compute the load address and check it for correctness, then
        # perform the load itself, returning the result.
        #
        # On the second cycle, we write the result to the destination register.

        base = state.gprs.get_reg(self.grs1).read_unsigned()
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return None

        addr = (base + self.offset) & ((1 << 32) - 1)

        if not state.dmem.is_valid_32b_addr(addr):
            if DEBUG_MEM:
                print(f"lw {base} {self.offset}: failed", file=sys.stderr)
            state.stop_at_end_of_cycle(ErrBits.BAD_DATA_ADDR)
            return None

        result = state.dmem.load_u32(addr)

        # Stall for a single cycle for memory to respond
        yield None

        if DEBUG_MEM:
            print(f"lw {base} {self.offset}", file=sys.stderr)

        if result is None:
            state.stop_at_end_of_cycle(ErrBits.DMEM_INTG_VIOLATION)
            return None

        if DEBUG_MEM:
            print(f"\t{format(result, '08x')}", file=sys.stderr)

        state.gprs.get_reg(self.grd).write_unsigned(result)
        return None


class SW(OTBNInsn):
    insn = insn_for_mnemonic('sw', 3)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.grs2 = op_vals['grs2']
        self.offset = op_vals['offset']
        self.grs1 = op_vals['grs1']

    def execute(self, state: OTBNState) -> None:
        base = state.gprs.get_reg(self.grs1).read_unsigned()
        addr = (base + self.offset) & ((1 << 32) - 1)
        value = state.gprs.get_reg(self.grs2).read_unsigned()
        if DEBUG_MEM:
            print(f"sw {base} {self.offset}: {format(value, '08x')}", file=sys.stderr)
        bad_grs1 = state.gprs.call_stack_err and (self.grs1 == 1)

        saw_err = False

        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            saw_err = True

        if not state.dmem.is_valid_32b_addr(addr) and not bad_grs1:
            state.stop_at_end_of_cycle(ErrBits.BAD_DATA_ADDR)
            saw_err = True

        if saw_err:
            return

        state.dmem.store_u32(addr, value)


class BEQ(OTBNInsn):
    insn = insn_for_mnemonic('beq', 3)
    affects_control = True
    has_fetch_stall = True

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.grs1 = op_vals['grs1']
        self.grs2 = op_vals['grs2']
        self.offset = op_vals['offset']

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_unsigned()
        val2 = state.gprs.get_reg(self.grs2).read_unsigned()
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return
        if DEBUG_BRANCH:
            eprint(f"Branch: {val1} ?== {val2} to {self.offset}")
        tgt_pc = self.offset & ((1 << 32) - 1)
        if val1 == val2:
            if DEBUG_BRANCH:
                eprint("taken")
            if not state.is_pc_valid(tgt_pc):
                state.stop_at_end_of_cycle(ErrBits.BAD_INSN_ADDR)
            else:
                state.set_next_pc(tgt_pc)
        else:
            if DEBUG_BRANCH:
                eprint("not taken")


class BNE(OTBNInsn):
    insn = insn_for_mnemonic('bne', 3)
    affects_control = True
    has_fetch_stall = True

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.grs1 = op_vals['grs1']
        self.grs2 = op_vals['grs2']
        self.offset = op_vals['offset']

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_unsigned()
        val2 = state.gprs.get_reg(self.grs2).read_unsigned()

        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return
        if DEBUG_BRANCH:
            eprint(f"Branch: {val1} ?!= {val2} to {self.offset}")
        tgt_pc = self.offset & ((1 << 32) - 1)
        if val1 != val2:
            if DEBUG_BRANCH:
                eprint("taken")
            if not state.is_pc_valid(tgt_pc):
                state.stop_at_end_of_cycle(ErrBits.BAD_INSN_ADDR)
            else:
                state.set_next_pc(tgt_pc)
        else:
            if DEBUG_BRANCH:
                eprint("not taken")


class JAL(OTBNInsn):
    insn = insn_for_mnemonic('jal', 2)
    affects_control = True
    has_fetch_stall = True

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.grd = op_vals['grd']
        self.offset = op_vals['offset']

    def execute(self, state: OTBNState) -> None:
        mask32 = ((1 << 32) - 1)
        link_pc = (state.pc + 4) & mask32
        state.gprs.get_reg(self.grd).write_unsigned(link_pc)
        if DEBUG_FLOW:
            eprint(f"jal {self.offset}")
        next_pc = self.offset & mask32
        if not state.is_pc_valid(next_pc):
            state.stop_at_end_of_cycle(ErrBits.BAD_INSN_ADDR)
        else:
            state.set_next_pc(next_pc)


class JALR(OTBNInsn):
    insn = insn_for_mnemonic('jalr', 3)
    affects_control = True
    has_fetch_stall = True

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.grd = op_vals['grd']
        self.grs1 = op_vals['grs1']
        self.offset = op_vals['offset']

    def execute(self, state: OTBNState) -> None:
        val1 = state.gprs.get_reg(self.grs1).read_unsigned()
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return

        mask32 = ((1 << 32) - 1)
        link_pc = (state.pc + 4) & mask32

        state.gprs.get_reg(self.grd).write_unsigned(link_pc)

        next_pc = (val1 + self.offset) & mask32
        if not state.is_pc_valid(next_pc):
            state.stop_at_end_of_cycle(ErrBits.BAD_INSN_ADDR)
        else:
            state.set_next_pc(next_pc)


class CSRRS(OTBNInsn):
    insn = insn_for_mnemonic('csrrs', 3)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.grd = op_vals['grd']
        self.csr = op_vals['csr']
        self.grs1 = op_vals['grs1']

    def execute(self, state: OTBNState) -> Optional[Iterator[None]]:
        if not state.csrs.check_idx(self.csr):
            # Invalid CSR index. Stop with an illegal instruction error.
            state.stop_at_end_of_cycle(ErrBits.ILLEGAL_INSN)
            return None

        bits_to_set = state.gprs.get_reg(self.grs1).read_unsigned()
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return None

        if self.csr == 0xfc0:
            # A read from RND. If a RND value is not available, request_value()
            # initiates or continues an EDN request and returns False. If a RND
            # value is available, it returns True.
            while not state.wsrs.RND.request_value():
                # There's a pending EDN request. Stall for a cycle.
                yield None

        # At this point, the CSR is ready. Read, update and write back to grs1.
        old_val = state.read_csr(self.csr)
        new_val = old_val | bits_to_set
        state.gprs.get_reg(self.grd).write_unsigned(old_val)
        if self.grs1 != 0:
            state.write_csr(self.csr, new_val)

        return None


class CSRRW(OTBNInsn):
    insn = insn_for_mnemonic('csrrw', 3)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.grd = op_vals['grd']
        self.csr = op_vals['csr']
        self.grs1 = op_vals['grs1']

    def execute(self, state: OTBNState) -> Optional[Iterator[None]]:
        # eprint("csrrw")
        if not state.csrs.check_idx(self.csr):
            # Invalid CSR index. Stop with an illegal instruction error.
            state.stop_at_end_of_cycle(ErrBits.ILLEGAL_INSN)
            return None

        new_val = state.gprs.get_reg(self.grs1).read_unsigned()
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return None

        if self.csr == 0xfc0 and self.grd != 0:
            # A read from RND. If a RND value is not available, request_value()
            # initiates or continues an EDN request and returns False. If a RND
            # value is available, it returns True.
            while not state.wsrs.RND.request_value():
                # There's a pending EDN request. Stall for a cycle.
                yield None

        # At this point, the CSR is either ready or unneeded. Read it if
        # necessary and write to grd, then overwrite with new_val.

        if self.grd != 0:
            old_val = state.read_csr(self.csr)
            state.gprs.get_reg(self.grd).write_unsigned(old_val)

        state.write_csr(self.csr, new_val)
        return None


class ECALL(OTBNInsn):
    insn = insn_for_mnemonic('ecall', 0)

    def execute(self, state: OTBNState) -> None:
        # Set INTR_STATE.done and STATUS, reflecting the fact we've stopped.
        state.stop_at_end_of_cycle(err_bits=0)


class LOOP(OTBNInsn):
    insn = insn_for_mnemonic('loop', 2)
    affects_control = True

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.grs = op_vals['grs']
        self.bodysize = op_vals['bodysize']

    def execute(self, state: OTBNState) -> None:
        num_iters = state.gprs.get_reg(self.grs).read_unsigned()
        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            return

        if num_iters == 0:
            state.stop_at_end_of_cycle(ErrBits.LOOP)
        else:
            state.loop_start(num_iters, self.bodysize)


class LOOPI(OTBNInsn):
    insn = insn_for_mnemonic('loopi', 2)
    affects_control = True

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.iterations = op_vals['iterations']
        self.bodysize = op_vals['bodysize']

    def execute(self, state: OTBNState) -> None:
        if DEBUG_FLOW:
            eprint("LOOPI")
        if self.iterations == 0:
            state.stop_at_end_of_cycle(ErrBits.LOOP)
        else:
            state.loop_start(self.iterations, self.bodysize)


class BNADD(OTBNInsn):
    insn = insn_for_mnemonic('bn.add', 6)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.shift_type = op_vals['shift_type']
        self.shift_bytes = op_vals['shift_bits'] // 8
        self.flag_group = op_vals['flag_group']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()
        b_shifted = logical_byte_shift(b, self.shift_type, self.shift_bytes)

        full_result = a + b_shifted
        mask256 = (1 << 256) - 1
        masked_result = full_result & mask256
        carry_flag = bool((full_result >> 256) & 1)
        flags = FlagReg.mlz_for_result(carry_flag, masked_result)

        if DEBUG_ARITH:
            eprint(f"bn.add 0x{format(a, '064x')} + 0x{format(b, '064x')} = "
                   f"{format(a+b, '064x')} = {format(masked_result, '064x')}")

        state.wdrs.get_reg(self.wrd).write_unsigned(masked_result)
        state.set_flags(self.flag_group, flags)


class BNADDC(OTBNInsn):
    insn = insn_for_mnemonic('bn.addc', 6)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.shift_type = op_vals['shift_type']
        self.shift_bytes = op_vals['shift_bits'] // 8
        self.flag_group = op_vals['flag_group']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()
        b_shifted = logical_byte_shift(b, self.shift_type, self.shift_bytes)

        carry = int(state.csrs.flags[self.flag_group].C)
        full_result = a + b_shifted + carry
        mask256 = (1 << 256) - 1
        masked_result = full_result & mask256
        carry_flag = bool((full_result >> 256) & 1)
        flags = FlagReg.mlz_for_result(carry_flag, masked_result)

        state.wdrs.get_reg(self.wrd).write_unsigned(masked_result)
        state.set_flags(self.flag_group, flags)


class BNADDI(OTBNInsn):
    insn = insn_for_mnemonic('bn.addi', 4)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs = op_vals['wrs']
        self.imm = op_vals['imm']
        self.flag_group = op_vals['flag_group']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs).read_unsigned()
        b = self.imm

        full_result = a + b
        mask256 = (1 << 256) - 1
        masked_result = full_result & mask256
        if DEBUG_ARITH:
            eprint(f"bn.addi {format(a, '064x')} + {b} = {format(a+b, '064x')} = "
                   f"{format(masked_result, '064x')}")
        carry_flag = bool((full_result >> 256) & 1)
        flags = FlagReg.mlz_for_result(carry_flag, masked_result)

        state.wdrs.get_reg(self.wrd).write_unsigned(masked_result)
        state.set_flags(self.flag_group, flags)


class BNADDM(OTBNInsn):
    insn = insn_for_mnemonic('bn.addm', 3)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()
        mod_val = state.wsrs.MOD.read_unsigned()

        result = a + b

        if result >= mod_val:
            result -= mod_val

        result = result & ((1 << 256) - 1)

        if DEBUG_ARITH:
            eprint(f"bn.addm 0x{format(a, '064x')} + 0x{format(b, '064x')} = "
                   f"{format(a+b, '064x')} = {format(result, '064x')}")
            if result >= mod_val:
                eprint("incomplete reduction")

        state.wdrs.get_reg(self.wrd).write_unsigned(result)


class BNADDV(OTBNInsn):
    insn = insn_for_mnemonic('bn.addv', 4)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.type = op_vals['type']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()
        mod_val = state.wsrs.MOD.read_unsigned()
        red = True if self.type > 1 else False
        size = 32 if (self.type % 2 == 0) else 16
        mod_val = extract_sub_word(mod_val, size, 0)
        result = 0

        for i in range(256 // size - 1, -1, -1):
            ai = OTBNInsn.from_2s_complement(extract_sub_word(a, size, i), size)
            bi = OTBNInsn.from_2s_complement(extract_sub_word(b, size, i), size)
            resulti = ai + bi
            if red:
                resulti = cmod_single(resulti, mod_val)
            if DEBUG_ARITH:
                eprint(f"addvm {ai} + {bi} = {ai + bi} = {resulti}")
            result <<= size
            result |= (OTBNInsn.to_2s_complement(resulti, size) & ((1 << size) - 1))

        result = result & ((1 << 256) - 1)
        state.wdrs.get_reg(self.wrd).write_unsigned(result)


class BNMULV(OTBNInsn):
    insn = insn_for_mnemonic('bn.mulv', 5)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.type = op_vals['type']
        self.lane = op_vals['lane']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()

        # the lower 4 types are without reduction
        red = True if self.type > 3 else False
        # see instruction scheme for details
        lane_mode = True if self.type in [2, 3, 6, 7] else False
        size = None
        if (self.type % 2) == 0:
            size = 32
        else:
            size = 16
        mod_val = extract_sub_word(state.wsrs.MOD.read_unsigned(), size, 0)
        qinv_val = extract_sub_word(state.wsrs.MOD.read_unsigned(), size, (32 // size))
        result = state.wdrs.get_reg(self.wrd).read_unsigned()

        # Extract the lane
        if lane_mode:
            bi = OTBNInsn.from_2s_complement(extract_sub_word(b, size, self.lane), size)

        for i in range(256 // size - 1, -1, -1):
            ai = OTBNInsn.from_2s_complement(extract_sub_word(a, size, i), size)
            if not lane_mode:
                bi = OTBNInsn.from_2s_complement(extract_sub_word(b, size, i), size)

            resulti = (ai * bi)  # TODO: match to hw implementation

            if red:
                t = ((resulti % (2**size)) * qinv_val) % (2**size)
                resulti = (resulti + t * mod_val) >> size
                if resulti >= mod_val:
                    resulti -= mod_val

            if DEBUG_ARITH:
                eprint(f"modulus {mod_val}")
                eprint(f"mulmv {ai} * {bi} = {ai * bi} = {resulti}")

            result <<= size
            result |= (OTBNInsn.to_2s_complement(resulti, size) & ((1 << size) - 1))
        result &= ((1 << 256) - 1)
        state.wdrs.get_reg(self.wrd).write_unsigned(result)
        if red:
            yield None
            yield None
            yield None
            yield None

            yield None
            yield None
            yield None
            yield None

            yield None
            yield None
            yield None
        else:
            yield None
            yield None
            yield None
        state.wsrs.ACC.write_unsigned(result)


class BNMULQACC(OTBNInsn):
    insn = insn_for_mnemonic('bn.mulqacc', 6)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.zero_acc = op_vals['zero_acc']
        self.wrs1 = op_vals['wrs1']
        self.wrs1_qwsel = op_vals['wrs1_qwsel']
        self.wrs2 = op_vals['wrs2']
        self.wrs2_qwsel = op_vals['wrs2_qwsel']
        self.acc_shift_imm = op_vals['acc_shift_imm']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()

        a_qw = extract_quarter_word(a, self.wrs1_qwsel)
        b_qw = extract_quarter_word(b, self.wrs2_qwsel)

        mul_res = a_qw * b_qw

        acc = state.wsrs.ACC.read_unsigned()
        if self.zero_acc:
            acc = 0

        acc += (mul_res << self.acc_shift_imm)

        truncated = acc & ((1 << 256) - 1)

        if DEBUG_ARITH:
            eprint(f"mulqacc {a_qw} * {b_qw} = {truncated}")

        state.wsrs.ACC.write_unsigned(truncated)


class BNMULQACCWO(OTBNInsn):
    insn = insn_for_mnemonic('bn.mulqacc.wo', 8)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.zero_acc = op_vals['zero_acc']
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs1_qwsel = op_vals['wrs1_qwsel']
        self.wrs2 = op_vals['wrs2']
        self.wrs2_qwsel = op_vals['wrs2_qwsel']
        self.acc_shift_imm = op_vals['acc_shift_imm']
        self.flag_group = op_vals['flag_group']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()

        a_qw = extract_quarter_word(a, self.wrs1_qwsel)
        b_qw = extract_quarter_word(b, self.wrs2_qwsel)

        mul_res = a_qw * b_qw

        acc = state.wsrs.ACC.read_unsigned()
        if self.zero_acc:
            acc = 0

        acc += (mul_res << self.acc_shift_imm)

        truncated = acc & ((1 << 256) - 1)
        state.wdrs.get_reg(self.wrd).write_unsigned(truncated)
        state.wsrs.ACC.write_unsigned(truncated)
        if DEBUG_ARITH:
            eprint(f"mulqacc.wo {a_qw} * {b_qw} = {truncated}")
        state.set_mlz_flags(self.flag_group, truncated)


class BNMULQACCSO(OTBNInsn):
    insn = insn_for_mnemonic('bn.mulqacc.so', 9)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.zero_acc = op_vals['zero_acc']
        self.wrd = op_vals['wrd']
        self.wrd_hwsel = op_vals['wrd_hwsel']
        self.wrs1 = op_vals['wrs1']
        self.wrs1_qwsel = op_vals['wrs1_qwsel']
        self.wrs2 = op_vals['wrs2']
        self.wrs2_qwsel = op_vals['wrs2_qwsel']
        self.acc_shift_imm = op_vals['acc_shift_imm']
        self.flag_group = op_vals['flag_group']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()

        a_qw = extract_quarter_word(a, self.wrs1_qwsel)
        b_qw = extract_quarter_word(b, self.wrs2_qwsel)

        mul_res = a_qw * b_qw

        acc = state.wsrs.ACC.read_unsigned()
        if self.zero_acc:
            acc = 0

        acc += (mul_res << self.acc_shift_imm)
        truncated = acc & ((1 << 256) - 1)

        if DEBUG_ARITH:
            eprint(f"mulqacc.so {a_qw} * {b_qw} = {truncated}")

        # Split the result into low and high parts
        lo_part = truncated & ((1 << 128) - 1)
        hi_part = truncated >> 128

        # Shift out the low part of the result
        hw_shift = 128 * self.wrd_hwsel
        hw_mask = ((1 << 128) - 1) << hw_shift
        old_wrd = state.wdrs.get_reg(self.wrd).read_unsigned()
        new_wrd = (old_wrd & ~hw_mask) | (lo_part << hw_shift)
        state.wdrs.get_reg(self.wrd).write_unsigned(new_wrd)

        # Write back the high part of the result
        state.wsrs.ACC.write_unsigned(hi_part)

        old_flags = state.csrs.flags[self.flag_group]
        if self.wrd_hwsel:
            new_flags = FlagReg(C=old_flags.C,
                                M=bool((lo_part >> 127) & 1),
                                L=old_flags.L,
                                Z=old_flags.Z and lo_part == 0)
        else:
            new_flags = FlagReg(C=old_flags.C,
                                M=old_flags.M,
                                L=bool(lo_part & 1),
                                Z=lo_part == 0)
        state.set_flags(self.flag_group, new_flags)


class BNSUB(OTBNInsn):
    insn = insn_for_mnemonic('bn.sub', 6)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.shift_type = op_vals['shift_type']
        self.shift_bytes = op_vals['shift_bits'] // 8
        self.flag_group = op_vals['flag_group']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()
        b_shifted = logical_byte_shift(b, self.shift_type, self.shift_bytes)

        full_result = a - b_shifted
        mask256 = (1 << 256) - 1
        masked_result = full_result & mask256
        carry_flag = bool((full_result >> 256) & 1)
        flags = FlagReg.mlz_for_result(carry_flag, masked_result)

        if DEBUG_ARITH:
            eprint(f"bn.sub 0x{format(a, '064x')} - 0x{format(b, '064x')} = "
                   f"{format(a-b, '064x')} = {format(masked_result, '064x')}")

        state.wdrs.get_reg(self.wrd).write_unsigned(masked_result)
        state.set_flags(self.flag_group, flags)


class BNSUBB(OTBNInsn):
    insn = insn_for_mnemonic('bn.subb', 6)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.shift_type = op_vals['shift_type']
        self.shift_bytes = op_vals['shift_bits'] // 8
        self.flag_group = op_vals['flag_group']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()
        b_shifted = logical_byte_shift(b, self.shift_type, self.shift_bytes)
        borrow = int(state.csrs.flags[self.flag_group].C)

        full_result = a - b_shifted - borrow
        mask256 = (1 << 256) - 1
        masked_result = full_result & mask256
        carry_flag = bool((full_result >> 256) & 1)
        flags = FlagReg.mlz_for_result(carry_flag, masked_result)

        state.wdrs.get_reg(self.wrd).write_unsigned(masked_result)
        state.set_flags(self.flag_group, flags)


class BNSUBI(OTBNInsn):
    insn = insn_for_mnemonic('bn.subi', 4)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs = op_vals['wrs']
        self.imm = op_vals['imm']
        self.flag_group = op_vals['flag_group']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs).read_unsigned()
        b = self.imm

        full_result = a - b
        mask256 = (1 << 256) - 1
        masked_result = full_result & mask256
        carry_flag = bool((full_result >> 256) & 1)
        flags = FlagReg.mlz_for_result(carry_flag, masked_result)

        state.wdrs.get_reg(self.wrd).write_unsigned(masked_result)
        state.set_flags(self.flag_group, flags)


class BNSUBM(OTBNInsn):
    insn = insn_for_mnemonic('bn.subm', 3)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()
        mod_val = state.wsrs.MOD.read_unsigned()

        result = a - b
        if result < 0:
            result += mod_val

        result = result & ((1 << 256) - 1)

        if DEBUG_ARITH:
            eprint(f"bn.subm 0x{format(a, '064x')} - 0x{format(b, '064x')} = "
                   f"{format(a-b, '064x')} = {format(result, '064x')}")

        state.wdrs.get_reg(self.wrd).write_unsigned(result)


class BNSUBV(OTBNInsn):
    insn = insn_for_mnemonic('bn.subv', 4)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.type = op_vals['type']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()
        mod_val = state.wsrs.MOD.read_unsigned()
        red = True if self.type > 1 else False
        size = 32 if (self.type % 2 == 0) else 16
        mod_val = extract_sub_word(mod_val, size, 0)
        result = 0

        for i in range(256 // size - 1, -1, -1):
            ai = OTBNInsn.from_2s_complement(extract_sub_word(a, size, i), size)
            bi = OTBNInsn.from_2s_complement(extract_sub_word(b, size, i), size)
            resulti = ai - bi
            if red:
                resulti = cmod_single(resulti, mod_val)
            if DEBUG_ARITH:
                eprint(f"subvm {ai} - {bi} = {ai - bi} = {resulti}")
            result <<= size
            result |= (OTBNInsn.to_2s_complement(resulti, size) & ((1 << size) - 1))

        result &= ((1 << 256) - 1)
        state.wdrs.get_reg(self.wrd).write_unsigned(result)


class BNAND(OTBNInsn):
    insn = insn_for_mnemonic('bn.and', 6)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.shift_type = op_vals['shift_type']
        self.shift_bytes = op_vals['shift_bits'] // 8
        self.flag_group = op_vals['flag_group']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()
        b_shifted = logical_byte_shift(b, self.shift_type, self.shift_bytes)

        result = a & b_shifted

        if DEBUG_ARITH:
            eprint(f"bn.and {format(a,'064x')} & {format(b_shifted, '064x')} = "
                   f"{format(result, '064x')}")

        state.wdrs.get_reg(self.wrd).write_unsigned(result)
        state.set_mlz_flags(self.flag_group, result)


class BNOR(OTBNInsn):
    insn = insn_for_mnemonic('bn.or', 6)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.shift_type = op_vals['shift_type']
        self.shift_bytes = op_vals['shift_bits'] // 8
        self.flag_group = op_vals['flag_group']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()
        b_shifted = logical_byte_shift(b, self.shift_type, self.shift_bytes)

        result = a | b_shifted

        if DEBUG_ARITH:
            eprint(f"bn.or {format(a,'064x')} & {format(b_shifted, '064x')} = "
                   f"{format(result, '064x')}")

        state.wdrs.get_reg(self.wrd).write_unsigned(result)
        state.set_mlz_flags(self.flag_group, result)


class BNNOT(OTBNInsn):
    insn = insn_for_mnemonic('bn.not', 5)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs = op_vals['wrs']
        self.shift_type = op_vals['shift_type']
        self.shift_bytes = op_vals['shift_bits'] // 8
        self.flag_group = op_vals['flag_group']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs).read_unsigned()
        a_shifted = logical_byte_shift(a, self.shift_type, self.shift_bytes)

        result = a_shifted ^ ((1 << 256) - 1)
        state.wdrs.get_reg(self.wrd).write_unsigned(result)
        state.set_mlz_flags(self.flag_group, result)


class BNXOR(OTBNInsn):
    insn = insn_for_mnemonic('bn.xor', 6)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.shift_type = op_vals['shift_type']
        self.shift_bytes = op_vals['shift_bits'] // 8
        self.flag_group = op_vals['flag_group']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()
        b_shifted = logical_byte_shift(b, self.shift_type, self.shift_bytes)

        result = a ^ b_shifted
        if DEBUG_ARITH:
            eprint(f"bn.xor 0x{format(a, '064x')} ^ 0x{format(b_shifted, '064x')} = "
                   f"{format(a^b, '064x')} = {format(result, '064x')}")
        state.wdrs.get_reg(self.wrd).write_unsigned(result)
        state.set_mlz_flags(self.flag_group, result)


class BNRSHI(OTBNInsn):
    insn = insn_for_mnemonic('bn.rshi', 4)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.imm = op_vals['imm']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()

        result = (((a << 256) | b) >> self.imm) & ((1 << 256) - 1)
        if DEBUG_ARITH:
            eprint(f"bn.rshi {format(a, '064x')}, {format(b, '064x')} = {format(result, '064x')}")
        state.wdrs.get_reg(self.wrd).write_unsigned(result)


class BNSHV(OTBNInsn):
    insn = insn_for_mnemonic('bn.shv', 6)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.type = op_vals['type']
        self.shift_type = op_vals['shift_type']
        self.shift_bits = op_vals['shift_bits']
        self.shift_arith = op_vals['shift_arith']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()

        size = 32 if self.type == 0 else 16

        result = 0

        for i in range((256 - size) // size, -1, -1):
            ai = extract_sub_word(a, size, i)
            if self.shift_arith:
                ai_shifted = bit_shift(ai, self.shift_type, self.shift_bits, size, arith=True)
            else:
                ai_shifted = bit_shift(ai, self.shift_type, self.shift_bits, size)

            resulti = ai_shifted
            result = (result << size) | (resulti & ((1 << size) - 1))

        state.wdrs.get_reg(self.wrd).write_unsigned(result)


class BNSEL(OTBNInsn):
    insn = insn_for_mnemonic('bn.sel', 5)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.flag_group = op_vals['flag_group']
        self.flag = op_vals['flag']

    def execute(self, state: OTBNState) -> None:
        flag_is_set = state.csrs.flags[self.flag_group].get_by_idx(self.flag)
        wrs = self.wrs1 if flag_is_set else self.wrs2
        value = state.wdrs.get_reg(wrs).read_unsigned()
        if DEBUG_ARITH:
            eprint(f"bn.sel {flag_is_set} -> {format(value, '064x')}")
        state.wdrs.get_reg(self.wrd).write_unsigned(value)


class BNCMP(OTBNInsn):
    insn = insn_for_mnemonic('bn.cmp', 5)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.shift_type = op_vals['shift_type']
        self.shift_bytes = op_vals['shift_bits'] // 8
        self.flag_group = op_vals['flag_group']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()
        b_shifted = logical_byte_shift(b, self.shift_type, self.shift_bytes)

        full_result = a - b_shifted
        mask256 = (1 << 256) - 1
        masked_result = full_result & mask256
        carry_flag = bool((full_result >> 256) & 1)
        flags = FlagReg.mlz_for_result(carry_flag, masked_result)

        if DEBUG_ARITH:
            eprint(f"bn.cmp {format(a, '064x')}, {format(b_shifted, '064x')} = "
                   f"{format(full_result, '064x')}")
            eprint(f"\tCarry: {carry_flag}")

        state.set_flags(self.flag_group, flags)


class BNCMPB(OTBNInsn):
    insn = insn_for_mnemonic('bn.cmpb', 5)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.shift_type = op_vals['shift_type']
        self.shift_bytes = op_vals['shift_bits'] // 8
        self.flag_group = op_vals['flag_group']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()
        b_shifted = logical_byte_shift(b, self.shift_type, self.shift_bytes)
        borrow = int(state.csrs.flags[self.flag_group].C)

        full_result = a - b_shifted - borrow
        mask256 = (1 << 256) - 1
        masked_result = full_result & mask256
        carry_flag = bool((full_result >> 256) & 1)
        flags = FlagReg.mlz_for_result(carry_flag, masked_result)

        state.set_flags(self.flag_group, flags)


class BNLID(OTBNInsn):
    insn = insn_for_mnemonic('bn.lid', 5)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.grd = op_vals['grd']
        self.grd_inc = op_vals['grd_inc']
        self.offset = op_vals['offset']
        self.grs1 = op_vals['grs1']
        self.grs1_inc = op_vals['grs1_inc']

    def execute(self, state: OTBNState) -> Optional[Iterator[None]]:
        # BN.LID executes over two cycles. On the first cycle, we read the base
        # address, compute the load address and check it for correctness,
        # increment any GPRs, then perform the load itself. On the second
        # cycle, update the WDR with the result.

        if self.grs1_inc and self.grd_inc:
            state.stop_at_end_of_cycle(ErrBits.ILLEGAL_INSN)
            return None

        grs1_val = state.gprs.get_reg(self.grs1).read_unsigned()
        addr = (grs1_val + self.offset) & ((1 << 32) - 1)
        grd_val = state.gprs.get_reg(self.grd).read_unsigned()
        if DEBUG_MEM:
            print(f"bn.lid {grs1_val} {self.offset}", file=sys.stderr)
        bad_grs1 = state.gprs.call_stack_err and (self.grs1 == 1)
        bad_grd = state.gprs.call_stack_err and (self.grd == 1)

        saw_err = False

        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            saw_err = True

        if grd_val > 31 and not bad_grd:
            state.stop_at_end_of_cycle(ErrBits.ILLEGAL_INSN)
            saw_err = True

        if not state.dmem.is_valid_256b_addr(addr) and not bad_grs1:
            state.stop_at_end_of_cycle(ErrBits.BAD_DATA_ADDR)
            saw_err = True

        if saw_err:
            return None

        wrd = grd_val & 0x1f
        value = state.dmem.load_u256(addr)

        if self.grd_inc:
            new_grd_val = grd_val + 1
            state.gprs.get_reg(self.grd).write_unsigned(new_grd_val)

        if self.grs1_inc:
            new_grs1_val = (grs1_val + 32) & ((1 << 32) - 1)
            state.gprs.get_reg(self.grs1).write_unsigned(new_grs1_val)

        # Stall for a single cycle for memory to respond
        yield None

        if value is None:
            state.stop_at_end_of_cycle(ErrBits.DMEM_INTG_VIOLATION)
            return None

        if DEBUG_MEM:
            print(f"\t {format(value, '064x')}", file=sys.stderr)

        state.wdrs.get_reg(wrd).write_unsigned(value)
        return None


class BNSID(OTBNInsn):
    insn = insn_for_mnemonic('bn.sid', 5)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.grs2 = op_vals['grs2']
        self.grs2_inc = op_vals['grs2_inc']
        self.offset = op_vals['offset']
        self.grs1 = op_vals['grs1']
        self.grs1_inc = op_vals['grs1_inc']

    def execute(self, state: OTBNState) -> Optional[Iterator[None]]:
        if self.grs1_inc and self.grs2_inc:
            state.stop_at_end_of_cycle(ErrBits.ILLEGAL_INSN)
            return None

        grs1_val = state.gprs.get_reg(self.grs1).read_unsigned()
        addr = (grs1_val + self.offset) & ((1 << 32) - 1)
        grs2_val = state.gprs.get_reg(self.grs2).read_unsigned()

        bad_grs1 = state.gprs.call_stack_err and (self.grs1 == 1)
        bad_grs2 = state.gprs.call_stack_err and (self.grs2 == 1)
        if DEBUG_MEM:
            print(f"bn.sid {grs1_val} {self.offset} <- {grs2_val}", file=sys.stderr)
        saw_err = False

        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            saw_err = True

        if grs2_val > 31 and not bad_grs2:
            state.stop_at_end_of_cycle(ErrBits.ILLEGAL_INSN)
            saw_err = True

        if not state.dmem.is_valid_256b_addr(addr) and not bad_grs1:
            state.stop_at_end_of_cycle(ErrBits.BAD_DATA_ADDR)
            saw_err = True

        if saw_err:
            return None

        if self.grs1_inc:
            new_grs1_val = (grs1_val + 32) & ((1 << 32) - 1)
            state.gprs.get_reg(self.grs1).write_unsigned(new_grs1_val)

        if self.grs2_inc:
            new_grs2_val = grs2_val + 1
            state.gprs.get_reg(self.grs2).write_unsigned(new_grs2_val)

        yield None

        wrs = grs2_val & 0x1f
        wrs_val = state.wdrs.get_reg(wrs).read_unsigned()
        if DEBUG_MEM:
            print(f"\t {format(wrs_val, '064x')}", file=sys.stderr)
        state.dmem.store_u256(addr, wrs_val)
        return None


class BNMOV(OTBNInsn):
    insn = insn_for_mnemonic('bn.mov', 2)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs = op_vals['wrs']

    def execute(self, state: OTBNState) -> None:
        value = state.wdrs.get_reg(self.wrs).read_unsigned()
        state.wdrs.get_reg(self.wrd).write_unsigned(value)


class BNMOVR(OTBNInsn):
    insn = insn_for_mnemonic('bn.movr', 4)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.grd = op_vals['grd']
        self.grd_inc = op_vals['grd_inc']
        self.grs = op_vals['grs']
        self.grs_inc = op_vals['grs_inc']

    def execute(self, state: OTBNState) -> Optional[Iterator[None]]:
        if DEBUG_ARITH:
            eprint("MOVR")
        if self.grs_inc and self.grd_inc:
            state.stop_at_end_of_cycle(ErrBits.ILLEGAL_INSN)
            return None

        grd_val = state.gprs.get_reg(self.grd).read_unsigned()
        grs_val = state.gprs.get_reg(self.grs).read_unsigned()

        bad_grs = state.gprs.call_stack_err and (self.grs == 1)
        bad_grd = state.gprs.call_stack_err and (self.grd == 1)

        saw_err = False

        if state.gprs.call_stack_err:
            state.stop_at_end_of_cycle(ErrBits.CALL_STACK)
            saw_err = True

        if grd_val > 31 and not bad_grd:
            state.stop_at_end_of_cycle(ErrBits.ILLEGAL_INSN)
            saw_err = True

        if grs_val > 31 and not bad_grs:
            state.stop_at_end_of_cycle(ErrBits.ILLEGAL_INSN)
            saw_err = True

        if saw_err:
            return None

        wrd = grd_val & 0x1f
        wrs = grs_val & 0x1f

        if self.grd_inc:
            new_grd_val = grd_val + 1
            state.gprs.get_reg(self.grd).write_unsigned(new_grd_val)

        if self.grs_inc:
            new_grs_val = grs_val + 1
            state.gprs.get_reg(self.grs).write_unsigned(new_grs_val)

        yield None

        value = state.wdrs.get_reg(wrs).read_unsigned()
        state.wdrs.get_reg(wrd).write_unsigned(value)
        return None


class BNWSRR(OTBNInsn):
    insn = insn_for_mnemonic('bn.wsrr', 2)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wsr = op_vals['wsr']

    def execute(self, state: OTBNState) -> Optional[Iterator[None]]:
        # The first, and possibly only, cycle of execution.
        if not state.wsrs.check_idx(self.wsr):
            # Invalid WSR index. Stop with an illegal instruction error.
            state.stop_at_end_of_cycle(ErrBits.ILLEGAL_INSN)
            return None

        if self.wsr == 0x1:
            # A read from RND. If a RND value is not available, request_value()
            # initiates or continues an EDN request and returns False. If a RND
            # value is available, it returns True.
            while not state.wsrs.RND.request_value():
                # There's a pending EDN request. Stall for a cycle.
                yield None

        if self.wsr == 0xA:
            # A read from KMAC_DIGEST. If a digest value is not available, request_value()
            # initiates or continues the request for the next digest word from KMAC and
            # returns false. If a digest value is available, it returns True.
            while not state.wsrs.KMAC_DIGEST.request_value():
                # There's a pending KMAC request. Stall for a cycle.
                yield None

        # At this point, the WSR is ready. Does it have a valid value? (It
        # might not if this is a sideload key register and keymgr hasn't
        # provided us with a value). If not, fail with a KEY_INVALID error.
        if not state.wsrs.has_value_at_idx(self.wsr):
            state.stop_at_end_of_cycle(ErrBits.KEY_INVALID)
            return None

        # The WSR is ready and has a value. Read it.
        val = state.wsrs.read_at_idx(self.wsr)
        if DEBUG_KMAC:
            eprint(f"read WSR: {format(val, '064x')}")
        state.wdrs.get_reg(self.wrd).write_unsigned(val)
        return None


class BNWSRW(OTBNInsn):
    insn = insn_for_mnemonic('bn.wsrw', 2)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wsr = op_vals['wsr']
        self.wrs = op_vals['wrs']

    def execute(self, state: OTBNState) -> None:
        if DEBUG_KMAC:
            print("\tRun BNWSRW")
        dest_wsrs = state.wsrs._by_idx[self.wsr]
        if self.wsr == 0x9:
            # A write to KMAC_MSG might stall, if the register has not yet pushed
            # all its contents to the FIFO connected to the KMAC app interface.
            while not state.wsrs.KMAC_MSG.request_write():
                if DEBUG_KMAC:
                    print("\tBNWSRW to KMAC_MSG stall")
                dest_wsrs.stalled = True
                yield None

        val = state.wdrs.get_reg(self.wrs).read_unsigned()
        if DEBUG_KMAC or DEBUG_ARITH:
            eprint(f"write WSR: {format(val, '064x')}")
        state.wsrs.write_at_idx(self.wsr, val)


class BNTRN(OTBNInsn):
    insn = insn_for_mnemonic('bn.trn', 4)

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.type = op_vals['type']

    def execute(self, state: OTBNState) -> None:
        a = state.wdrs.get_reg(self.wrs1).read_unsigned()
        b = state.wdrs.get_reg(self.wrs2).read_unsigned()

        # see instruction scheme for details
        mode_2 = True if self.type in [4, 5, 6, 7] else False
        size = None
        if (self.type % 4) == 0:
            size = 16
        elif (self.type % 4) == 1:
            size = 32
        elif (self.type % 4) == 2:
            size = 64
        else:
            size = 128
        result = 0

        if mode_2:
            a >>= size
            b >>= size

        for i in range(256 // size - 2, -1, -2):
            ai = extract_sub_word(a, size, i)
            bi = extract_sub_word(b, size, i)
            result = (result << size) | bi
            result = (result << size) | ai

        result = result & ((1 << 256) - 1)
        if (DEBUG_ARITH):
            eprint(f"trn: {format(a,'064x')}, {format(b,'064x')}, {format(result, '064x')}")
        state.wdrs.get_reg(self.wrd).write_unsigned(result)


INSN_CLASSES = [
    ADD, ADDI, LUI, SUB, SLL, SLLI, SRL, SRLI, SRA, SRAI,
    AND, ANDI, OR, ORI, XOR, XORI,
    LW, SW,
    BEQ, BNE, JAL, JALR,
    CSRRS, CSRRW,
    ECALL,
    LOOP, LOOPI,

    BNADD, BNADDC, BNADDI, BNADDM, BNADDV,
    BNMULV,
    BNMULQACC, BNMULQACCWO, BNMULQACCSO,
    BNSUB, BNSUBB, BNSUBI, BNSUBM, BNSUBV,
    BNAND, BNOR, BNNOT, BNXOR,
    BNSHV,
    BNRSHI,
    BNSEL,
    BNCMP, BNCMPB,
    BNLID, BNSID,
    BNMOV, BNMOVR, BNTRN,
    BNWSRR, BNWSRW
]
