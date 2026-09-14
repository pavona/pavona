# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink host sequence for customized protocol-invalid items."""

from .tl_host_single_seq import tl_host_single_seq


class tl_host_custom_seq(tl_host_single_seq):
    """Disable protocol constraints and allow the caller to fully customize A-channel fields."""

    def randomize_req(self, req, idx: int):
        self.control_addr_alignment = True
        self.control_rand_size = True
        self.control_rand_opcode = True
        req.disable_a_chan_protocol_constraint()
        super().randomize_req(req, idx)
