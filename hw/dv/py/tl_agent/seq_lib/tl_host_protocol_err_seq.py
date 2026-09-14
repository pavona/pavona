# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink host sequence that forces protocol errors."""

import random

from ..tl_seq_item import tl_seq_item
from .tl_host_single_seq import tl_host_single_seq


class tl_host_protocol_err_seq(tl_host_single_seq):
    """Generate a request that should trigger a TL protocol error response."""

    def randomize_req(self, req: tl_seq_item, idx: int):
        req.a_valid_delay = random.randint(self.min_req_delay,
                                           self.max_req_delay)
        req.randomize_a_chan_with_protocol_error()
