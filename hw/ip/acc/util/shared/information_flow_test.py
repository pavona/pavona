#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import unittest

from shared.information_flow import (NUM_WDRS, DmemInformationFlowNode,
                                     InformationFlowGraph,
                                     InformationFlowNode, InsnInformationFlow)
from shared.insn_yaml import load_insns_yaml


class TestInformationFlowGraphSimplify(unittest.TestCase):

    def test_different_types(self) -> None:
        graph = InformationFlowGraph({})
        sink = DmemInformationFlowNode(0x0, 0x100)
        sources = [
            DmemInformationFlowNode(0x0, 0x100),
            InformationFlowNode("x3")
        ]

        # Manually assign graph.flow to circumvent the extra .simplify() call
        # performed in .__init__()
        graph.flow = {sink: sources}
        graph.simplify()

        # Make sure the sources are kept as is.
        self.assertEqual(graph.flow, {
            sink:
            {DmemInformationFlowNode(0x0, 0x100),
             InformationFlowNode("x3")}
        })

    def test_out_of_order(self) -> None:
        graph = InformationFlowGraph({})
        sink = DmemInformationFlowNode(0x0, 0x100)
        sources = [
            DmemInformationFlowNode(0x0, 0x100),
            DmemInformationFlowNode(0x200, 0x300),
            DmemInformationFlowNode(0x100, 0x200)
        ]

        # Manually assign graph.flow to circumvent the extra .simplify() call
        # performed in .__init__()
        graph.flow = {sink: sources}
        graph.simplify()

        # Make sure the sources were coalesced properly.
        self.assertEqual(graph.flow,
                         {sink: {DmemInformationFlowNode(0x0, 0x300)}})

    def test_different_types_out_of_order(self) -> None:
        graph = InformationFlowGraph({})
        sink = DmemInformationFlowNode(0x0, 0x100)
        sources = [
            InformationFlowNode("x3"),
            DmemInformationFlowNode(0x0, 0x100),
            DmemInformationFlowNode(0x200, 0x300),
            InformationFlowNode("x4"),
            DmemInformationFlowNode(0x100, 0x200)
        ]

        # Manually assign graph.flow to circumvent the extra .simplify() call
        # performed in .__init__()
        graph.flow = {sink: sources}
        graph.simplify()

        # Make sure the sources were coalesced properly.
        self.assertEqual(
            graph.flow, {
                sink: {
                    DmemInformationFlowNode(0x0, 0x300),
                    InformationFlowNode("x3"),
                    InformationFlowNode("x4")
                }
            })


class TestIndirectWDRReference(unittest.TestCase):

    # bn.lid x5, 0(x10): the destination WDR is the one x5 names.
    LID_OPS = {'grd': 5, 'grs1': 10, 'offset': 0, 'grs1_inc': 0, 'grd_inc': 0}
    # bn.sid x5, 0(x10): the source WDR is the one x5 names.
    SID_OPS = {'grs1': 10, 'grs2': 5, 'offset': 0, 'grs1_inc': 0, 'grs2_inc': 0}

    @staticmethod
    def _iflow(mnemonic: str) -> InsnInformationFlow:
        return load_insns_yaml().mnemonic_to_insn[mnemonic].iflow

    def test_constant_index(self) -> None:
        flow = self._iflow('bn.lid').evaluate(self.LID_OPS, {'x5': 3}, True)

        # x5 is known, so only w3 is written, and fully.
        self.assertEqual(flow.flow, {
            InformationFlowNode('w3'): {InformationFlowNode('dmem')}
        })

    def test_unknown_index_as_sink(self) -> None:
        flow = self._iflow('bn.lid').evaluate(self.LID_OPS, {}, True)

        # Every WDR is a may-write sink, and x5 selects which one.
        self.assertEqual(flow.flow, {
            InformationFlowNode('w{}'.format(i)): {
                InformationFlowNode('dmem'),
                InformationFlowNode('w{}'.format(i)),
                InformationFlowNode('x5'),
            }
            for i in range(NUM_WDRS)
        })

    def test_unknown_index_as_source(self) -> None:
        flow = self._iflow('bn.sid').evaluate(self.SID_OPS, {}, True)

        # Any WDR may be the one stored, so all of them flow to dmem.
        sources = {InformationFlowNode('w{}'.format(i)) for i in range(NUM_WDRS)}
        sources |= {InformationFlowNode('dmem'), InformationFlowNode('x5')}
        self.assertEqual(flow.flow, {InformationFlowNode('dmem'): sources})

    def test_coarse_dmem_sink_keeps_own_value(self) -> None:
        flow = self._iflow('bn.sid').evaluate(self.SID_OPS, {'x5': 3}, True)

        # The coarse dmem node stands for all of memory, so it is a may-write.
        self.assertEqual(flow.flow, {
            InformationFlowNode('dmem'): {InformationFlowNode('dmem'),
                                          InformationFlowNode('w3')}
        })

    def test_tracked_dmem_sink_is_overwritten(self) -> None:
        constants = {'x5': 3, 'x10': 0x100}
        flow = self._iflow('bn.sid').evaluate(self.SID_OPS, constants, False)

        # A tracked range is covered by the store, so it is not a may-write.
        self.assertEqual(flow.flow, {
            DmemInformationFlowNode(0x100, 0x120): {InformationFlowNode('w3')}
        })

    def test_tracked_dmem_needs_a_constant_index(self) -> None:
        iflow = self._iflow('bn.lid')

        # Tracking dmem precisely needs both the address and the WDR index.
        self.assertEqual(iflow.required_constants(self.LID_OPS, False),
                         {'x5', 'x10'})
        with self.assertRaises(RuntimeError):
            iflow.evaluate(self.LID_OPS, {}, False)


if __name__ == '__main__':
    unittest.main()
