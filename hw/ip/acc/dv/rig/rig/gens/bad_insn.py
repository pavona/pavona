# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import random
from typing import Optional, Union

from shared.insn_yaml import InsnsFile

from ..config import Config
from ..program import DummyProgInsn, ProgInsn, Program
from ..model import Model
from ..snippet import ProgSnippet
from ..snippet_gen import GenCont, GenRet, SnippetGen


class BadInsn(SnippetGen):
    '''A simple snippet generator that generates one invalid instruction'''

    ends_program = True

    def __init__(self, cfg: Config, insns_file: InsnsFile) -> None:
        super().__init__()

        # Take a copy of the instructions file: we'll need it when generating
        # random data in order to make sure we generate junk.
        self.insns_file = insns_file

        # Generate a separate list of only vector extension instructions
        self.pqc_insns = []
        self.pqc_weights = []
        for insn in insns_file.insns:
            weight = cfg.insn_weights.get(insn.mnemonic)
            if weight > 0:
                if insn.pqc:
                    self.pqc_insns.append(insn)
                    self.pqc_weights.append(weight)

    def _get_badbits(self) -> int:
        for _ in range(50):
            data = random.getrandbits(32)
            # Is this (by fluke) actually a valid instruction? It's not very
            # likely, but we need to check that it isn't.
            if self.insns_file.mnem_for_word(data) is None:
                return data

        # Since the encoding density isn't all that high (< 25%), the chances
        # of getting here are vanishingly small (should be < 2^100). Just
        # assert that it doesn't happen.
        assert 0

    def _gen_bad_pqc(self, model: Model) -> ProgInsn:
        weights = list(self.pqc_weights)
        # If vector instructions are legal then we can only create illegal decodings
        # of the bn.mulv variants via the type enum and lane index.
        if model.pqc:
            weights = [
                w if insn.mnemonic in {'bn.mulv', 'bn.mulv.l'} else 0
                for w, insn in zip(weights, self.pqc_insns)
            ]
            assert any(w > 0 for w in weights)
        prog_insn = None
        while prog_insn is None:
            idx = random.choices(range(len(self.pqc_insns)), weights=weights)[0]
            assert weights[idx] > 0

            # Try to fill out the instruction. On failure, clear the weight for
            # this index and go around again. We take the copy here, rather
            # than outside the loop, because we don't expect this to happen
            # very often.
            insn = self.pqc_insns[idx]
            op_vals = []  # type: list[int]
            for operand in insn.operands:
                op_val = model.pick_operand_value(operand.op_type)

                if op_val is None:
                    raise ValueError("Op Val produced for instruction is not valid")

                if (len(op_vals) == len(insn.operands) - 1) and model.pqc:
                    # Ensure an illegal type enum for bn.mulv if vector instructions are expected.
                    # Otherwise any vector instruction will be illegal and fields don't matter.
                    if (insn.mnemonic == "bn.mulv"):
                        while operand.op_type.op_val_to_str(op_val, 0) != '""':  # Empty enum is ""
                            op_val = model.pick_operand_value(operand.op_type)
                            if op_val is None:
                                raise ValueError("Op Val produced for instruction is not valid")

                    # bn.mulv.l will be made illegal by its lane index since bn.mulv/bn.mulv.l
                    # share the same encoding scheme/illegal insn logic in the decoder.
                    # Ensure that we have some combination of bn.mulv.l.8 to create an illegal idx.
                    if (insn.mnemonic == "bn.mulv.l"):
                        while not operand.op_type.op_val_to_str(op_val, 0).startswith(".8"):
                            op_val = model.pick_operand_value(operand.op_type)
                            if op_val is None:
                                raise ValueError("Op Val produced for instruction is not valid")

                op_vals.append(op_val)

            # Force out of range lane index if vector instructions are expected
            # by forcing lane index range (0,7) to (8,15) for bn.mulv.l
            if (
                (insn.mnemonic == "bn.mulv.l") and
                operand.op_type.op_val_to_str(op_vals[-1], 0).startswith(".8") and
                op_vals[-2] < 8 and
                model.pqc
            ):
                op_vals[-2] = op_vals[-2] + 8

            assert len(op_vals) == len(insn.operands)
            prog_insn = ProgInsn(insn, op_vals, None)

            if prog_insn is None:
                weights = self.weights.copy()
                weights[idx] = 0
                continue

        return prog_insn

    def gen(self,
            cont: GenCont,
            model: Model,
            program: Program) -> Optional[GenRet]:
        # Create union of valid typing
        prog_insn: Union[DummyProgInsn, ProgInsn]

        # Choose between illegal random bit instruction. Example: (illegal mnemonic/funct)
        # Or an illegal vector instruction. Example: (valid mnemonic + illegal "type" field)
        if random.choice([True, False]):
            prog_insn = DummyProgInsn(self._get_badbits())
        else:
            prog_insn = self._gen_bad_pqc(model)

        snippet = ProgSnippet(model.pc, [prog_insn])
        snippet.insert_into_program(program)
        return (snippet, model)

    def pick_weight(self,
                    model: Model,
                    program: Program) -> float:
        # Choose small weights when we've got lots of room and large ones when
        # we haven't.
        room = min(model.fuel, program.space)
        assert 0 < room
        return (1e-10 if room > 5
                else 0.1 if room > 1
                else 1e10)
