# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import random
from typing import Optional
from enum import Enum, auto

from shared.insn_yaml import InsnsFile

from ..config import Config
from ..program import ProgInsn, Program
from ..model import Model
from ..snippet import ProgSnippet
from ..snippet_gen import GenCont, GenRet, SnippetGen


class KmacAppReqInsn(SnippetGen):
    ''' A snippet generator for creating KMAC AppIntf transactions.
        Transactions consist of loading a random value into a WDR
        and generating a sequence with a randomized msg len, sha3 mode,
        keccak strength, and return digest amount. In the case of a
        transaction being too large for the remaining model fuel, the
        generator attempts to run again with half the message size. When
        the message size is <= 32B the generator produces the least number
        of instructions and is guarenteed to fit.
    '''

    pqc_program = True

    def __init__(self, cfg: Config, insns_file: InsnsFile) -> None:
        super().__init__()

        # bn.wsrw insn
        self.bn_wsrw = self._get_named_insn(insns_file, 'bn.wsrw')
        self.bn_wsrw_wsr_op_type = self.bn_wsrw.operands[0].op_type
        self.bn_wsrw_wrs_op_type = self.bn_wsrw.operands[1].op_type
        self._wsrw_wrs = 0

        # bn.wsrr insn
        self.bn_wsrr = self._get_named_insn(insns_file, 'bn.wsrr')
        self.bn_wsrr_wrd_op_type = self.bn_wsrr.operands[0].op_type
        self.bn_wsrr_wsr_op_type = self.bn_wsrr.operands[1].op_type

        # csrrw insn
        self.csrrw = self._get_named_insn(insns_file, 'csrrw')
        self.csrrw_grd_op_type = self.csrrw.operands[0].op_type
        self.csrrw_csr_op_type = self.csrrw.operands[1].op_type
        self.csrrw_grs1_op_type = self.csrrw.operands[2].op_type
        self._csrrw_grs1 = 0

        # li insn
        self.li = self._get_named_insn(insns_file, 'li')
        self.li_grd_op_type = self.li.operands[0].op_type
        self.li_imm_op_type = self.li.operands[1].op_type

        # addi insn (substitute for li)
        self.addi = self._get_named_insn(insns_file, 'addi')
        self.addi_grd_op_type = self.addi.operands[0].op_type
        self.addi_grs1_op_type = self.addi.operands[1].op_type
        self.addi_imm_op_type = self.addi.operands[2].op_type

        # lui insn (substitute for li)
        self.lui = self._get_named_insn(insns_file, 'lui')
        self.lui_grd_op_type = self.lui.operands[0].op_type
        self.lui_imm_op_type = self.lui.operands[1].op_type

        self._target_mod_addr = 0

        # kmac msg configurations
        self._msg_size = 0
        self._pw_size = 0
        self._sha3_mode = 0
        self._keccak_strength = 0
        self._cfg_done = 0

        # li insn mode
        self._fill_li_mode = FillLiMode.CFG

        # bn.wsrr insn mode
        self._fill_wsrr_mode = FillWsrrMode.MSG

        # bn.wsrw insn mode
        self._fill_wsrw_mode = FillWsrwMode.MSG

    def gen(self,
            cont: GenCont,
            model: Model,
            program: Program) -> Optional[GenRet]:
        ''' Generate the block of AppReq instructions for each stage.
            First checks if there is sufficient room for instructions
            Then generates the KMAC configuration
        '''

        # Return None if there are less than 50 instruction spaces remaining
        # because this is the safe minimum to complete an entire transaction.
        # We would need to either jump or do an ECALL to avoid getting stuck.
        # The true minimum is around 37 insns, but malformed messages can
        # increase / decrease this within a limited number of insns
        if program.get_insn_space_at(model.pc) <= 50:
            return None

        if program.space < 50:
            return None

        if model.fuel < 50:
            return None

        # Reset Variables
        self._target_mod_addr = model._kmac_csr_addr["MOD0"]

        # Randomly choose a SHA3 Mode and Keccak Strength
        self._sha3_mode = random.choices([Sha3Mode.Sha3, Sha3Mode.Shake], weights=[1, 1])[0]
        if (self._sha3_mode == Sha3Mode.Sha3):
            self._keccak_strength = random.choices([KeccakStrength.L256, KeccakStrength.L512],
                                                   weights=[1, 1])[0]
        elif (self._sha3_mode == Sha3Mode.Shake):
            self._keccak_strength = random.choices([KeccakStrength.L128, KeccakStrength.L256],
                                                   weights=[1, 1])[0]

        # Alternatively determine the amount of fuel required for the constructed
        # kmac req and determine if the model has sufficient fuel remaining to
        # complete the transactio / request. Loop 5 times or until msg size < 32B
        # (512 / 256 / 128 / 64 / 32)

        size_behavior = random.choices(
            ["normal", "large"],
            weights=[90, 10]
        )[0]

        if size_behavior == "normal":
            self._msg_size = random.randint(1, 512)
        else:
            self._msg_size = random.randint(2048, 8192)
            print(f"[DEBUG] LARGE MESSAGE: {self._msg_size}")

        while True:
            insn_list = self._gen(model, program)
            if (
                len(insn_list) < model.fuel
                and len(insn_list) < program.space
                and len(insn_list) < program.get_insn_space_at(model.pc)
                or self._msg_size <= 32
            ):
                break
            self._msg_size //= 2

        if (
            len(insn_list) >= model.fuel
            or len(insn_list) >= program.space
            or len(insn_list) >= program.get_insn_space_at(model.pc)
        ):
            return None

        snippet = ProgSnippet(model.pc, insn_list)
        snippet.insert_into_program(program)

        for insn in insn_list:
            model.update_for_insn(insn)
            model.pc += 4

        return (snippet, model)

    def _gen(self, model: Model, program: Program):
        """ Helper function to build and return a full instruction list for the given message size.
            Attempts to regularly change the partial word size during the message.
        """
        insn_list = []

        size_behavior = random.choices(
            ["normal", "undersized", "oversized"],
            weights=[80, 10, 10]
        )[0]

        # Change message size based on behavior
        if size_behavior == "undersized":
            if self._msg_size > 2:
                target_bytes = random.randint(1, self._msg_size - 1)
            else:
                target_bytes = self._msg_size
        elif size_behavior == "oversized":
            # Up to 64 bytes over
            target_bytes = self._msg_size + random.randint(1, 64)
        else:
            target_bytes = self._msg_size

        remaining_bytes = target_bytes

        self._cfg_done = 0
        self._pw_size = 32
        write_pw_pair = False

        writes_before_change = random.randint(1, 5)
        current_write_count = 0

        rsp_max_cnt = min(model.fuel - 35, program.space - 35, 6)
        num_digest_rd = 0
        if ((self._sha3_mode == Sha3Mode.Sha3)
                and (self._keccak_strength == KeccakStrength.L256)):
            num_digest_rd = 1
        elif ((self._sha3_mode == Sha3Mode.Sha3)
                and (self._keccak_strength == KeccakStrength.L512)):
            num_digest_rd = 2
        elif (self._sha3_mode == Sha3Mode.Shake):
            num_digest_rd = random.randint(1, rsp_max_cnt)

        # Reset Variables
        self._target_mod_addr = model._kmac_csr_addr["MOD0"]

        # Fill WSR register with 8 li/csrrw pairs
        msg_insns = self.fill_msg_insns(model)
        for insn in msg_insns:
            insn_list.append(insn)

        # CFG Start
        cfg_start_insns = self.fill_cfg_insns(model)
        for insn in cfg_start_insns:
            insn_list.append(insn)

        # While loop to send MSG body
        while (remaining_bytes > 0):
            # Check if we should change partial_write size
            if (current_write_count >= writes_before_change and remaining_bytes > 0):
                self._pw_size = random.randint(1, 32)
                writes_before_change = random.randint(1, 5)
                current_write_count = 0
                write_pw_pair = True

            # This is preparation the final write
            if (remaining_bytes <= self._pw_size):
                self._pw_size = remaining_bytes
                write_pw_pair = True

            # If the MSG SIZE is <= 32B perform a single write
            if (self._msg_size <= 32):
                self._pw_size = self._msg_size
                write_pw_pair = True

            # Update the PW register size
            if (write_pw_pair is True):
                # Create an li/csrrw pair for the new size
                self._fill_li_mode = FillLiMode.PW
                write_pw_pair = False
                pw_insns = self.fill_pw_insns(model)
                for insn in pw_insns:
                    insn_list.append(insn)

            # Do a kmac msg write
            self._fill_wsrw_mode = FillWsrwMode.MSG
            prog_wsrw_msg = self.fill_bn_wsrw(model)
            remaining_bytes -= self._pw_size
            current_write_count += 1
            insn_list.append(prog_wsrw_msg)

        # Digest reads
        for _ in range(num_digest_rd):
            self._fill_wsrr_mode = FillWsrrMode.DIGEST
            prog_wsrr_digest = self.fill_bn_wsrr(model)
            insn_list.append(prog_wsrr_digest)

        # Status read
        op_vals = []
        mem_type = 'csr'

        csrrw_grd_val = 0x0
        while (csrrw_grd_val <= 0x1):
            csrrw_grd_val = model.pick_operand_value(self.csrrw_grd_op_type)

        op_vals.append(csrrw_grd_val)
        csrrw_csr_val = model._kmac_csr_addr["KMAC_STATUS"]
        op_vals.append(csrrw_csr_val)
        csrrw_grs1_val = 0x0
        op_vals.append(csrrw_grs1_val)
        addr = csrrw_csr_val

        assert len(op_vals) == len(self.csrrw.operands)
        status_insn = ProgInsn(self.csrrw, op_vals, (mem_type, addr))

        insn_list.append(status_insn)

        # CFG end insns
        self._cfg_done = 1
        cfg_stop_insns = self.fill_cfg_insns(model)
        for insn in cfg_stop_insns:
            insn_list.append(insn)

        return insn_list

    def fill_msg_insns(self, model: Model):
        insn_list = []

        self._fill_li_mode = FillLiMode.MSG
        for _ in range(8):
            prog_lui_msg, prog_addi_msg = self.fill_li(model)
            self._csrrw_grs1 = prog_lui_msg.operands[0]
            prog_csrrw_msg = self.fill_csrrw(model)
            self._target_mod_addr += 1
            insn_list.append(prog_lui_msg)
            insn_list.append(prog_addi_msg)
            insn_list.append(prog_csrrw_msg)

        self._fill_wsrr_mode = FillWsrrMode.MSG
        prog_wsrr_msg = self.fill_bn_wsrr(model)
        self._wsrw_wrs = prog_wsrr_msg.operands[0]
        insn_list.append(prog_wsrr_msg)

        return insn_list

    def fill_cfg_insns(self, model: Model):
        insn_list = []

        self._fill_li_mode = FillLiMode.CFG
        prog_lui_cfg, prog_addi_cfg = self.fill_li(model)
        self._csrrw_grs1 = prog_lui_cfg.operands[0]
        prog_csrrw_cfg = self.fill_csrrw(model)
        insn_list.append(prog_lui_cfg)
        insn_list.append(prog_addi_cfg)
        insn_list.append(prog_csrrw_cfg)

        return insn_list

    def fill_pw_insns(self, model: Model):
        insn_list = []

        addi_op_vals = []

        # Create the destination register operand
        while True:
            addi_grd_val = model.pick_operand_value(self.addi_grd_op_type)
            if not model.is_const('gpr', addi_grd_val):
                # 0x0 is not writeable and 0x1 is SP
                if addi_grd_val != 0x0 and addi_grd_val != 0x1:
                    break

        addi_grs1_val = 0x0
        addi_imm_val = self._fill_li_pw()

        addi_op_vals.append(addi_grd_val)
        addi_op_vals.append(addi_grs1_val)
        addi_op_vals.append(addi_imm_val)

        assert len(addi_op_vals) == len(self.addi.operands)
        prog_addi_insn = ProgInsn(self.addi, addi_op_vals, None)

        self._csrrw_grs1 = prog_addi_insn.operands[0]
        prog_csrrw_pw = self.fill_csrrw(model)

        insn_list.append(prog_addi_insn)
        insn_list.append(prog_csrrw_pw)

        return insn_list

    def fill_csrrw(self, model: Model) -> Optional[ProgInsn]:
        ''' Function to fill the opcode values for a csrrw insn '''

        # Initialize opcode vals for csrrw instruction
        op_vals = []
        mem_type = 'csr'

        # Create the destination register operand
        csrrw_grd_val = model.pick_operand_value(self.csrrw_grd_op_type)

        # Dont want grd to be 0x1 to prevent call stack write
        if (csrrw_grd_val <= 0x1):
            csrrw_grd_val = 0x2

        csrrw_grd_val = 0x0

        op_vals.append(csrrw_grd_val)

        if (self._fill_li_mode == FillLiMode.CFG):
            csrrw_csr_val = model._kmac_csr_addr["KMAC_CFG"]
        elif (self._fill_li_mode == FillLiMode.PW):
            csrrw_csr_val = model._kmac_csr_addr["KMAC_PW"]
        elif (self._fill_li_mode == FillLiMode.MSG):
            csrrw_csr_val = self._target_mod_addr

        op_vals.append(csrrw_csr_val)
        addr = csrrw_csr_val

        # Takes the grs1 target of the previous li insn
        op_vals.append(self._csrrw_grs1)

        assert len(op_vals) == len(self.csrrw.operands)
        return ProgInsn(self.csrrw, op_vals, (mem_type, addr))

    def fill_li(self, model: Model) -> Optional[ProgInsn]:
        ''' Function to fill the (lui + addi) instructions needed for li pseudo insn '''

        # TODO: Add model check to see if reg is const

        # Intialize opcode vals for li instruction
        lui_op_vals = []
        addi_op_vals = []

        # Create the destination register operand
        while True:
            li_grd_val = model.pick_operand_value(self.li_grd_op_type)
            if not model.is_const('gpr', li_grd_val):
                # 0x0 is not writeable and 0x1 is SP
                if li_grd_val != 0x0 and li_grd_val != 0x1:
                    break

        # Source reg for addi should be same as destination (addi x7, x7, 0x20) ex
        addi_grs1_val = li_grd_val

        # Append op vals
        lui_op_vals.append(li_grd_val)
        addi_op_vals.append(li_grd_val)
        addi_op_vals.append(addi_grs1_val)

        if (self._fill_li_mode == FillLiMode.CFG):
            lui_imm_val, addi_imm_val = self._fill_li_cfg()
        elif (self._fill_li_mode == FillLiMode.MSG):
            lui_imm_val, addi_imm_val = self._fill_li_msg(model)
        else:
            raise ValueError(f"Unknown fill_li_mode: {self._fill_li_mode}")

        lui_op_vals.append(lui_imm_val)
        addi_op_vals.append(addi_imm_val)

        assert len(lui_op_vals) == len(self.lui.operands)
        assert len(addi_op_vals) == len(self.addi.operands)

        prog_lui_insn = ProgInsn(self.lui, lui_op_vals, None)
        prog_addi_insn = ProgInsn(self.addi, addi_op_vals, None)

        return prog_lui_insn, prog_addi_insn

    def _fill_li_pw(self) -> Optional[int]:
        ''' Helper function to generate appropriate imm value for partial word insn '''
        addi_imm_op_val = self._pw_size & 0xFFF

        return addi_imm_op_val

    def _fill_li_cfg(self) -> Optional[int]:
        ''' Helper function to generate appropriate imm value for kmac cfg '''

        # Create the destination register operand
        whole_words = self._msg_size // 8
        byte_remainder = self._msg_size % 8

        # Create the bit mask
        cfg_mask = 0
        cfg_mask |= (self._sha3_mode.value & 0b11) << 0          # Sha3 Mode [1:0]
        cfg_mask |= (self._keccak_strength.value & 0b111) << 2   # Strength  [4:2]
        cfg_mask |= (byte_remainder & 0b111) << 5                # Msg Bytes [7:5]
        cfg_mask |= (whole_words & 0x7FFFFF) << 8                # Msg Words [30:8]
        cfg_mask |= (self._cfg_done & 0b1) << 31                 # Cfg Done  [31]

        lui_imm_op_val = cfg_mask >> 12
        addi_imm_op_val = cfg_mask & 0xFFF

        # Check if addi MSB is 1 because of signed arithmetic
        if addi_imm_op_val & (1 << 11):
            lui_imm_op_val += 1

        return lui_imm_op_val, addi_imm_op_val

    def _fill_li_msg(self, model: Model) -> Optional[int]:
        ''' Helper function to generate random imm payload for kmac msg '''

        lui_imm_op_val = model.pick_operand_value(self.lui_imm_op_type)
        addi_imm_op_val = model.pick_operand_value(self.addi_imm_op_type)

        return lui_imm_op_val, addi_imm_op_val

    def fill_bn_wsrr(self, model: Model) -> Optional[ProgInsn]:
        ''' Function to generate wsrr insn opcode values '''

        # Intialize opcode vals for bn.wsrr instruction
        op_vals = []
        mem_type = 'wsr'

        # Pick destination register
        bn_wsrr_wrd_val = model.pick_operand_value(self.bn_wsrr_wrd_op_type)
        op_vals.append(bn_wsrr_wrd_val)

        # Pick source WSR addr
        if (self._fill_wsrr_mode == FillWsrrMode.MSG):
            bn_wsrr_wsr_val = model._kmac_wsr_addr["MOD"]
        elif (self._fill_wsrr_mode == FillWsrrMode.DIGEST):
            bn_wsrr_wsr_val = model._kmac_wsr_addr["KMAC_DIGEST"]

        op_vals.append(bn_wsrr_wsr_val)
        addr = bn_wsrr_wsr_val

        assert len(op_vals) == len(self.bn_wsrr.operands)
        return ProgInsn(self.bn_wsrr, op_vals, (mem_type, addr))

    def fill_bn_wsrw(self, model: Model) -> Optional[ProgInsn]:
        ''' Function to generate wsr insn opcode values '''

        # Intialize opcode vals for bn.wsrw instruction
        op_vals = []
        mem_type = 'wsr'

        # Pick destination register
        if (self._fill_wsrw_mode == FillWsrwMode.MSG):
            bn_wsrw_wsr_val = model._kmac_wsr_addr["KMAC_MSG"]

        op_vals.append(bn_wsrw_wsr_val)
        addr = bn_wsrw_wsr_val

        # Pick source WSR Addr
        bn_wsrw_wrs_val = self._wsrw_wrs
        op_vals.append(bn_wsrw_wrs_val)

        assert len(op_vals) == len(self.bn_wsrw.operands)
        return ProgInsn(self.bn_wsrw, op_vals, (mem_type, addr))


class Sha3Mode(Enum):
    Sha3 = 0b00
    Shake = 0b10
    CShake = 0b11


class KeccakStrength(Enum):
    L128 = 0b000
    L224 = 0b001
    L256 = 0b010
    L384 = 0b011
    L512 = 0b100


class FillLiMode(Enum):
    CFG = auto()
    MSG = auto()
    PW = auto()


class FillWsrrMode(Enum):
    MSG = auto()
    DIGEST = auto()


class FillWsrwMode(Enum):
    MSG = auto()
