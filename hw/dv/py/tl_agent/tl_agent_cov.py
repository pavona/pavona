# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""TileLink agent coverage."""

from __future__ import annotations

from typing import Optional

import vsc
from pyuvm import uvm_component

from .tl_agent_cfg import tl_agent_cfg
from .tl_seq_item import (AccessAck, AccessAckData, DataWidth, Get, MaskWidth,
                          PutFullData, PutPartialData, SizeWidth, SourceWidth,
                          tl_seq_item)


@vsc.covergroup
class _ToggleCovCg:

    def __init__(self, name: str) -> None:
        super().__init__()
        self.options.per_instance = True
        self.with_sample(value=vsc.bit_t(1))
        self.cp_value = vsc.coverpoint(
            self.value,
            bins={
                "zero": vsc.bin(0),
                "one": vsc.bin(1),
            },
        )
        self.set_name(name)


@vsc.covergroup
class _PendingReqOnRstCg:

    def __init__(self, name: str) -> None:
        super().__init__()
        self.options.per_instance = True
        self.with_sample(req_pending=vsc.bit_t(1))
        self.cp_req_pending = vsc.coverpoint(
            self.req_pending,
            bins={
                "zero": vsc.bin(0),
                "one": vsc.bin(1),
            },
        )
        self.set_name(name)


@vsc.covergroup
class _MaxOutstandingCg:

    def __init__(self, name: str, max_outstanding: int) -> None:
        super().__init__()
        self.options.per_instance = True
        self.with_sample(num_outstanding=vsc.uint32_t())
        max_outstanding = max(1, int(max_outstanding))
        ignore_bins = {
            "zero_outstanding": vsc.bin(0),
        }
        if max_outstanding > 1:
            ignore_bins["unsupported_values"] = vsc.bin((2, max_outstanding))
        self.cp_num_of_outstanding = vsc.coverpoint(
            self.num_outstanding,
            bins={
                "values": vsc.bin(1),
            },
            ignore_bins=ignore_bins,
        )
        self.set_name(name)


@vsc.covergroup
class _TlAChanCovCg:

    def __init__(self, name: str, valid_source_width: int) -> None:
        super().__init__()
        self.options.per_instance = True
        self.with_sample(
            a_opcode=vsc.bit_t(3),
            a_mask=vsc.bit_t(MaskWidth),
            a_size=vsc.uint8_t(),
            a_source=vsc.bit_t(SourceWidth),
        )
        max_mask = (1 << MaskWidth) - 1
        biggest_size = (DataWidth >> 3).bit_length() - 1
        source_max = max(0, (1 << int(valid_source_width)) - 1)

        def _mask_bin_value(bin_info) -> int:
            if bin_info.name == "all_enables":
                return max_mask
            if bin_info.name.startswith("others[") and bin_info.name.endswith(
                    "]"):
                return int(bin_info.name[7:-1])
            raise ValueError(f"Unexpected mask bin name: {bin_info.name}")

        def _size_bin_value(bin_info) -> int:
            if bin_info.name == "biggest_size":
                return biggest_size
            if bin_info.name.startswith("others[") and bin_info.name.endswith(
                    "]"):
                return int(bin_info.name[7:-1]) - 1
            raise ValueError(f"Unexpected size bin name: {bin_info.name}")

        def _mask_is_legal_for_size(mask: int, size: int) -> bool:
            lane_mask = (1 << MaskWidth) - 1
            align_mask = (1 << size) - 1
            for addr in range(1 << SizeWidth):
                if addr & align_mask:
                    continue
                active_bits = (1 << (1 << size)) - 1
                active_mask = (active_bits << addr) & lane_mask
                if (mask & ~active_mask) == 0:
                    return True
            return False

        def _opcode_mask_size_illegal(opcode_bin, mask_bin, size_bin) -> bool:
            opcode_name = opcode_bin.name
            mask = _mask_bin_value(mask_bin)
            size = _size_bin_value(size_bin)

            if mask == 0:
                return True
            if not _mask_is_legal_for_size(mask, size):
                return True
            if opcode_name == "PutFullData":
                return mask.bit_count() != (1 << size)
            return mask.bit_count() > (1 << size)

        mask_bins = {"all_enables": vsc.bin(max_mask)}
        if max_mask > 0:
            mask_bins["others"] = vsc.bin_array([], [0, max_mask - 1])
        mask_ignore_bins = {"zero_mask": vsc.bin(0)}

        size_bins = {"biggest_size": vsc.bin(biggest_size)}
        if biggest_size > 0:
            size_bins["others"] = vsc.bin_array([], [0, biggest_size - 1])

        self.cp_opcode = vsc.coverpoint(
            self.a_opcode,
            bins={
                "Get": vsc.bin(Get),
                "PutFullData": vsc.bin(PutFullData),
                "PutPartialData": vsc.bin(PutPartialData),
            },
        )
        self.cp_mask = vsc.coverpoint(
            self.a_mask,
            bins=mask_bins,
            ignore_bins=mask_ignore_bins,
        )
        self.cp_size = vsc.coverpoint(self.a_size, bins=size_bins)
        self.cp_source = vsc.coverpoint(
            self.a_source,
            bins={"valid_sources": vsc.bin_array([], [0, source_max])},
        )
        self.cp_opcode_mask_size = vsc.cross(
            [self.cp_opcode, self.cp_mask, self.cp_size],
            ignore_bins={
                "illegal_combinations": _opcode_mask_size_illegal,
            },
        )
        self.set_name(name)


@vsc.covergroup
class _TlDChanCovCg:

    def __init__(self, name: str) -> None:
        super().__init__()
        self.options.per_instance = True
        self.with_sample(
            d_opcode=vsc.bit_t(3),
            a_size=vsc.uint8_t(),
            d_error=vsc.bit_t(1),
        )
        biggest_size = (DataWidth >> 3).bit_length() - 1
        size_bins = {"biggest_size": vsc.bin(biggest_size)}
        if biggest_size > 0:
            size_bins["others"] = vsc.bin_array([], [0, biggest_size - 1])

        self.cp_opcode = vsc.coverpoint(
            self.d_opcode,
            bins={
                "AccessAck": vsc.bin(AccessAck),
                "AccessAckData": vsc.bin(AccessAckData),
            },
        )
        self.cp_size = vsc.coverpoint(self.a_size, bins=size_bins)
        self.cp_error = vsc.coverpoint(
            self.d_error,
            bins={
                "zero": vsc.bin(0),
                "one": vsc.bin(1),
            },
        )
        self.cp_opcode_size = vsc.cross([self.cp_opcode, self.cp_size])
        self.set_name(name)


class tl_agent_cov(uvm_component):
    """TileLink agent coverage."""

    TL_ERROR_NAMES = (
        "invalid_a_opcode",
        "PutFullData_mask_not_match_size",
        "addr_not_align_mask",
        "addr_not_align_size",
        "mask_not_in_active_lanes",
        "size_over_max",
    )

    def __init__(self,
                 name: str,
                 parent: Optional[uvm_component] = None) -> None:
        super().__init__(name, parent)
        self.cfg: Optional[tl_agent_cfg] = None
        self.m_pending_req_on_rst_cg: Optional[_PendingReqOnRstCg] = None
        self.m_max_outstanding_cg: Optional[_MaxOutstandingCg] = None
        self.m_outstanding_item_w_same_addr_cov_obj: Optional[
            _ToggleCovCg] = None
        self.en_cov_outstanding_item_w_same_addr: bool = True
        self.m_tl_a_chan_cov_cg: Optional[_TlAChanCovCg] = None
        self.m_tl_d_chan_cov_cg: Optional[_TlDChanCovCg] = None
        self.m_tl_error_cov_objs: dict[str, _ToggleCovCg] = {}

    def build_phase(self) -> None:
        super().build_phase()
        path = self.get_full_name()
        max_outstanding = 1 if self.cfg is None else max(
            1, int(self.cfg.max_outstanding_req))
        valid_source_width = SourceWidth if self.cfg is None else int(
            self.cfg.valid_a_source_width)

        self.m_pending_req_on_rst_cg = _PendingReqOnRstCg(
            f"{path}::m_pending_req_on_rst_cg")
        self.m_max_outstanding_cg = _MaxOutstandingCg(
            f"{path}::m_max_outstanding_cg",
            max_outstanding,
        )

        if max_outstanding > 1 and self.en_cov_outstanding_item_w_same_addr:
            self.m_outstanding_item_w_same_addr_cov_obj = _ToggleCovCg(
                f"{path}::m_outstanding_item_w_same_addr_cov_obj")

        if str(getattr(self.cfg, "if_mode", "Host")).lower() == "host":
            self.m_tl_a_chan_cov_cg = _TlAChanCovCg(
                f"{path}::m_tl_a_chan_cov_cg",
                valid_source_width,
            )
            for error_name in self.TL_ERROR_NAMES:
                self.m_tl_error_cov_objs[error_name] = _ToggleCovCg(
                    f"{path}::{error_name}")
        else:
            self.m_tl_d_chan_cov_cg = _TlDChanCovCg(
                f"{path}::m_tl_d_chan_cov_cg")

    def sample(self, item: tl_seq_item) -> None:
        """Sample transaction completion coverage."""
        if self.cfg is None:
            return

        if str(getattr(self.cfg, "if_mode", "Host")).lower() == "host":
            if not item.get_exp_d_error():
                if self.m_tl_a_chan_cov_cg is not None:
                    self.m_tl_a_chan_cov_cg.sample(
                        int(item.a_opcode),
                        int(item.a_mask),
                        int(item.a_size),
                        int(item.a_source),
                    )
            else:
                self._sample_error_toggle("invalid_a_opcode",
                                          item.get_error_a_opcode_invalid())
                self._sample_error_toggle(
                    "PutFullData_mask_not_match_size",
                    item.get_error_PutFullData_mask_size_mismatched(),
                )
                misaligned = item.get_error_addr_size_misaligned()
                self._sample_error_toggle("addr_not_align_mask", misaligned)
                self._sample_error_toggle("addr_not_align_size", misaligned)
                self._sample_error_toggle(
                    "mask_not_in_active_lanes",
                    item.get_error_mask_not_in_active_lanes(),
                )
                self._sample_error_toggle("size_over_max",
                                          item.get_error_size_over_max())
        elif self.m_tl_d_chan_cov_cg is not None:
            self.m_tl_d_chan_cov_cg.sample(
                int(item.d_opcode),
                int(item.a_size),
                int(bool(item.d_error)),
            )

    def _sample_error_toggle(self, name: str, value: bool) -> None:
        cg = self.m_tl_error_cov_objs.get(name)
        if cg is not None:
            cg.sample(int(bool(value)))
