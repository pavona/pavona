# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

from typing import Optional

from shared.insn_yaml import InsnsFile

from ..config import Config
from ..program import ProgInsn, Program
from ..model import Model
from ..snippet import ProgSnippet
from ..snippet_gen import GenCont, GenRet, SnippetGen


class ClearWsr(SnippetGen):
    ''' A snippet generator to XOR wide state registers after blanking
        in order to allow for bignum instruction execution with known
        register values in the ISS model. This is most important for
        verifying the PQC vector extensions which perform computation
        based on known wide data registers and the specialized MOD reg.
    '''

    starts_program = True

    def __init__(self, cfg: Config, insns_file: InsnsFile) -> None:
        super().__init__()

        # bn.xor insn
        self.bn_xor = self._get_named_insn(insns_file, 'bn.xor')
        self.bn_xor_wrd_op_type = self.bn_xor.operands[0].op_type
        self.bn_xor_wrs1_op_type = self.bn_xor.operands[1].op_type
        self.bn_xor_wrs2_op_type = self.bn_xor.operands[1].op_type

        # bn.wsrw insn
        self.bn_wsrw = self._get_named_insn(insns_file, 'bn.wsrw')
        self.bn_wsrw_wsr_op_type = self.bn_wsrw.operands[0].op_type
        self.bn_wsrw_wrs_op_type = self.bn_wsrw.operands[1].op_type

    def gen(self,
            cont: GenCont,
            model: Model,
            program: Program) -> Optional[GenRet]:
        ''' Generate XOR operations for each WSR and wide data register
            in order to clear the value to a default of 0 after internal
            blanking of registers.
        '''

        # Make sure there is enough fuel to clear register values
        if model.fuel < 34:
            return None

        if program.get_insn_space_at(model.pc) <= 34:
            return None

        if program.space < 34:
            return None

        insn_list = []
        for i in range(32):
            # First 3 operands are wrd, wrs1, wrs2
            xor_op_vals = [i] * 3
            # Last 3 operands are not used
            for j in range(3):
                xor_op_vals.append(0)
            assert len(xor_op_vals) == len(self.bn_xor.operands)
            prog_xor_insn = ProgInsn(self.bn_xor, xor_op_vals, None)
            insn_list.append(prog_xor_insn)

        mem_type = 'wsr'
        wsrw_wsr = model._kmac_wsr_addr['MOD']
        addr = wsrw_wsr
        wsrw_wrs = 0
        wsrw_op_vals = [wsrw_wsr, wsrw_wrs]

        assert len(wsrw_op_vals) == len(self.bn_wsrw.operands)
        prog_wsrw_insn = ProgInsn(self.bn_wsrw, wsrw_op_vals, (mem_type, addr))
        insn_list.append(prog_wsrw_insn)

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

        return None
