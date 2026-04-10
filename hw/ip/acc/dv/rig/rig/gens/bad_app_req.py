# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import random
from enum import Enum, auto

from shared.insn_yaml import InsnsFile

from .app_req import KmacAppReqInsn, FillWsrwMode, FillWsrrMode
from ..config import Config
from ..program import ProgInsn, Program
from ..model import Model


class BadKmacAppReqInsn(KmacAppReqInsn):
    '''A snippet generator that generates program ending kmac instructions.
    This includes oversized/undersized messages, fifo overflows, invalid
    share read/writes.
    '''

    pqc_program = True
    ends_program = True

    def __init__(self, cfg: Config, insns_file: InsnsFile) -> None:
        super().__init__(cfg, insns_file)

        self._error_mode = KmacErrorMode.MalformedSize
        self._size_mode = SizeErrorMode.AltCFG

    def _gen(self, model: Model, program: Program) -> list[ProgInsn]:
        """ Helper function to build and return a full instruction list for the given message size.
            The list of instructions returned are illegal for KMAC operations.
        """
        # Take a clean KMAC operation to inject errors into
        insn_list = super()._gen(model, program)

        # Split the valid errors by masking mode
        if self._masked_mode:
            self._error_mode = random.choices([KmacErrorMode.MalformedSize,
                                              KmacErrorMode.Overflow],
                                              weights=[1, 0.5])[0]
        else:
            self._error_mode = random.choices([KmacErrorMode.MalformedSize,
                                              KmacErrorMode.IllegalMsg,
                                              KmacErrorMode.IllegalDigest],
                                              weights=[0.5, 1, 1])[0]

        print(self._error_mode)

        # Inject based on error mode chosen
        if self._error_mode == KmacErrorMode.MalformedSize:
            err_insn_list = self._inject_size(model, insn_list)
        elif self._error_mode == KmacErrorMode.IllegalMsg:
            err_insn_list = self._inject_illegal_msg(model, insn_list)
        elif self._error_mode == KmacErrorMode.IllegalDigest:
            err_insn_list = self._inject_illegal_digest(model, insn_list)
        elif self._error_mode == KmacErrorMode.Overflow:
            err_insn_list = self._inject_fifo_overflow(model, insn_list)

        return err_insn_list

    def _inject_size(self, model: Model, insn_list: list[ProgInsn]) -> list[ProgInsn]:
        ''' Makes a malformed sized message both oversized and undersized '''
        cfg_insn_idx = []
        pw_insn_idx = []
        msg0_insn_idx = []
        msg1_insn_idx = []
        insn_cnt = 0

        err_insn_list = insn_list

        for insn in insn_list:
            if (
                insn.insn.mnemonic == 'bn.wsrw' and
                insn.operands[0] == model._kmac_wsr_addr["KMAC_MSG"]
            ):
                # This is a valid write to the KMAC MSG0 register
                msg0_insn_idx.append(insn_cnt)
            if (
                insn.insn.mnemonic == 'bn.wsrw' and
                insn.operands[0] == model._kmac_wsr_addr["KMAC_MSG1"]
            ):
                # This is a valid write to the KMAC MSG0 register
                msg1_insn_idx.append(insn_cnt)
            if (
                insn.insn.mnemonic == 'csrrw' and
                insn.operands[1] == model._kmac_csr_addr["KMAC_CFG"]
            ):
                # This is a valid write to the KMAC CFG register
                cfg_insn_idx.append(insn_cnt)
            if (
                insn.insn.mnemonic == 'csrrw' and
                insn.operands[1] == model._kmac_csr_addr["KMAC_PW"]
            ):
                # This is a valid write to the KMAC PW register
                pw_insn_idx.append(insn_cnt)

            insn_cnt += 1

        assert msg0_insn_idx[0] is not None
        assert cfg_insn_idx[0] is not None
        if self._masked_mode:
            assert msg1_insn_idx[0] is not None

        self._size_mode = random.choices([SizeErrorMode.AltCFG,
                                         SizeErrorMode.AltPW,
                                         SizeErrorMode.InsertPW,
                                         SizeErrorMode.InsertMSG],
                                         weights=[1, 1, 1, 1])[0]

        if self._size_mode == SizeErrorMode.AltCFG:
            # Inject an error into the config to cause a mismatch in the size
            # Use the first cfg instruction to modify the length
            cfg_wrs = insn_list[cfg_insn_idx[0]].operands[2]
            inject_idx = cfg_insn_idx[0]

            addi_op_vals = []
            addi_imm_op_val = model.pick_operand_value(self.addi_imm_op_type)
            assert addi_imm_op_val is not None
            addi_imm_op_val = addi_imm_op_val & 0x7E0  # Apply mask to not change the strength/mode
            addi_op_vals.append(cfg_wrs)
            addi_op_vals.append(cfg_wrs)
            addi_op_vals.append(addi_imm_op_val)

            prog_insn = ProgInsn(self.addi, addi_op_vals, None)
            err_insn_list.insert(inject_idx, prog_insn)

        if self._size_mode == SizeErrorMode.AltPW:
            # Change an existing PW mask value
            # It is possible to not have any partial write
            if pw_insn_idx is not None:
                addi_op_vals = []
                # Change the addi instruction before the csrrw into partial write
                addi_idx = (random.choice(pw_insn_idx) - 1)
                # Get the destination register
                addi_grd_val = insn_list[addi_idx].operands[0]
                addi_op_vals.append(addi_grd_val)
                addi_grs1_val = 0x0
                addi_op_vals.append(addi_grs1_val)
                # Set the range for PW value
                addi_imm_val = random.randint(1, 31)
                addi_op_vals.append(addi_imm_val)
                assert len(addi_op_vals) == len(self.addi.operands)
                prog_insn = ProgInsn(self.addi, addi_op_vals, None)
                err_insn_list[addi_idx] = prog_insn

            else:
                # If there is no partial words then we will add one to shorten the message
                self._size_mode == SizeErrorMode.InsertPW

        if self._size_mode == SizeErrorMode.InsertPW:
            inject_idx = random.choice(pw_insn_idx)

        if self._size_mode == SizeErrorMode.InsertMSG:
            inject_idx = random.choice(msg0_insn_idx)
            self._share0_wrs = insn_list[msg0_insn_idx[0]].operands[1]
            if self._masked_mode:
                assert msg1_insn_idx is not None
                self._share1_wrs = insn_list[msg1_insn_idx[0]].operands[1]

            # If masked then add pairs of message writes
            for _ in range(random.randint(1, 4)):
                self._fill_wsrw_mode = FillWsrwMode.MSG
                prog_insn = self.fill_bn_wsrw(model)
                err_insn_list.insert(inject_idx, prog_insn)
                if self._masked_mode:
                    self._fill_wsrw_mode = FillWsrwMode.MSG1
                    prog_insn = self.fill_bn_wsrw(model)
                    err_insn_list.insert(inject_idx, prog_insn)

        return err_insn_list

    def _inject_illegal_msg(self, model: Model, insn_list: list[ProgInsn]) -> list[ProgInsn]:
        ''' Adds an illegal MSG write in unmasked mode '''
        insn_idx = []
        insn_cnt = 0

        err_insn_list = insn_list

        for insn in insn_list:
            if (
                insn.insn.mnemonic == 'bn.wsrw' and
                insn.operands[0] == model._kmac_wsr_addr["KMAC_MSG"]
            ):
                # This is a valid write to the KMAC MSG0 register
                insn_idx.append(insn_cnt)
            insn_cnt += 1

        assert insn_idx[0] is not None

        self._fill_wsrw_mode = FillWsrwMode.MSG1
        self._share1_wrs = insn_list[insn_idx[0]].operands[1]
        prog_insn = self.fill_bn_wsrw(model)

        inject_idx = random.choice(insn_idx)
        err_insn_list.insert(inject_idx, prog_insn)

        return err_insn_list

    def _inject_illegal_digest(self, model: Model, insn_list: list[ProgInsn]) -> list[ProgInsn]:
        ''' Adds an illegal DIGEST read in unmasked mode '''
        insn_idx = []
        insn_cnt = 0

        err_insn_list = insn_list

        for insn in insn_list:
            if (
                insn.insn.mnemonic == 'bn.wsrr' and
                insn.operands[1] == model._kmac_wsr_addr["KMAC_DIGEST"]
            ):
                # This is a valid read from the KMAC DIGEST0 register
                insn_idx.append(insn_cnt)
            insn_cnt += 1

        assert insn_idx[0] is not None

        self._fill_wsrr_mode = FillWsrrMode.DIGEST1
        prog_insn = self.fill_bn_wsrr(model)

        inject_idx = random.choice(insn_idx)
        err_insn_list.insert(inject_idx, prog_insn)

        return err_insn_list

    def _inject_fifo_overflow(self, model: Model, insn_list: list[ProgInsn]) -> list[ProgInsn]:
        ''' Makes a deadlock by filling a message FIFO in masked mode '''
        msg0_insn_idx = []
        msg1_insn_idx = []
        insn_cnt = 0
        msg0_fill = True

        err_insn_list = insn_list

        for insn in insn_list:
            if (
                insn.insn.mnemonic == 'bn.wsrw' and
                insn.operands[0] == model._kmac_wsr_addr["KMAC_MSG"]
            ):
                # This is a valid write to the KMAC MSG0 register
                msg0_insn_idx.append(insn_cnt)
            if (
                insn.insn.mnemonic == 'bn.wsrw' and
                insn.operands[0] == model._kmac_wsr_addr["KMAC_MSG1"]
            ):
                # This is a valid write to the KMAC MSG1 register
                msg1_insn_idx.append(insn_cnt)
            insn_cnt += 1

        assert msg0_insn_idx[0] is not None
        if msg1_insn_idx is not None:
            msg0_fill = random.choices([True, False], weights=[1, 1])[0]

        # Decide which FIFO to inject multiple writes too in order to overflow
        if msg0_fill:
            self._fill_wsrw_mode = FillWsrwMode.MSG
            self._share1_wrs = insn_list[msg0_insn_idx[0]].operands[1]
            msg0_prog_insn = self.fill_bn_wsrw(model)
            inject_idx = random.choice(msg0_insn_idx)
            for _ in range(random.randint(2, 4)):
                err_insn_list.insert(inject_idx, msg0_prog_insn)
        elif msg1_insn_idx is not None and not msg0_fill:
            self._fill_wsrw_mode = FillWsrwMode.MSG1
            self._share1_wrs = insn_list[msg1_insn_idx[0]].operands[1]
            msg1_prog_insn = self.fill_bn_wsrw(model)
            inject_idx = random.choice(msg1_insn_idx)
            for _ in range(random.randint(2, 4)):
                err_insn_list.insert(inject_idx, msg1_prog_insn)

        return err_insn_list


class KmacErrorMode(Enum):
    MalformedSize = auto()
    IllegalMsg = auto()
    IllegalDigest = auto()
    Overflow = auto()


class SizeErrorMode(Enum):
    AltCFG = auto()
    AltPW = auto()
    InsertPW = auto()
    InsertMSG = auto()
