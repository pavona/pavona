#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import unittest

from shared.information_flow import (DmemInformationFlowNode,
                                     InformationFlowGraph, InformationFlowNode)


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


if __name__ == '__main__':
    unittest.main()
