# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
TileLink UL sequence item: one request/response transaction on the TL-UL interface.
Stores A-channel fields (address, opcode, size, data, mask, source, etc.) and
D-channel fields (opcode, data, source, error, etc.). The monitor creates items
on A/D handshakes and sets channel (A_CHANNEL or D_CHANNEL). A host driver uses
the A channel; a device driver uses the D channel. Used by the TL agent and scoreboard.
"""

from enum import IntEnum

import vsc
from dv_lib.dv_base_seq_item import dv_base_seq_item
from interfaces.tl_widths import (apply_tl_width_overrides, get_tl_widths,
                                  register_tl_width_refresher)


class TlSeqItemChannel(IntEnum):
    """Set by the monitor to indicate which channel produced this item."""

    A_CHANNEL = 0
    D_CHANNEL = 1


# Default widths (match current SV defaults unless overridden in Python).
_widths = get_tl_widths()
AddrWidth = _widths.tl_aw
DataWidth = _widths.tl_dw
SizeWidth = _widths.tl_szw
MaskWidth = _widths.tl_dbw
SourceWidth = _widths.tl_aiw
AUserWidth = _widths.tl_auw
DUserWidth = _widths.tl_duw
OpcodeWidth = 3
ParamWidth = _widths.tl_param_w


def override_widths(**overrides: int) -> None:
    apply_tl_width_overrides(**overrides)


def _refresh_tl_seq_item_widths(widths) -> None:
    global AddrWidth, DataWidth, SizeWidth, MaskWidth, SourceWidth, AUserWidth, DUserWidth
    global OpcodeWidth, ParamWidth

    AddrWidth = widths.tl_aw
    DataWidth = widths.tl_dw
    SizeWidth = widths.tl_szw
    MaskWidth = widths.tl_dbw
    SourceWidth = widths.tl_aiw
    AUserWidth = widths.tl_auw
    DUserWidth = widths.tl_duw
    OpcodeWidth = widths.tl_opcode_w
    ParamWidth = widths.tl_param_w


register_tl_width_refresher(_refresh_tl_seq_item_widths)
_refresh_tl_seq_item_widths(get_tl_widths())

# TL-UL opcode encodings used by the SV implementation.
PutFullData = 0
PutPartialData = 1
AccessAck = 0
AccessAckData = 1
Get = 4


def _mask_is_full(a_mask: int, a_size: int) -> bool:
    return _countones(a_mask) == (1 << a_size)


def _mask_low_in_inactive_lanes(a_mask: int, a_addr: int, a_size: int) -> bool:
    active_mask = _get_active_mask(a_addr, a_size)
    return (a_mask & ~active_mask) == 0


def _addr_aligned_to_size(a_addr: int, a_size: int) -> bool:
    return (a_addr & ((1 << a_size) - 1)) == 0


def _below_max_a_size(a_size: int) -> bool:
    return a_size <= 2


def _size_gte_mask(a_mask: int, a_size: int) -> bool:
    return (1 << a_size) >= _countones(a_mask)


def _countones(value: int) -> int:
    return int(bin(int(value) & ((1 << MaskWidth) - 1)).count("1"))


def _a_opcode_is_valid(a_opcode: int) -> bool:
    return a_opcode in {Get, PutFullData, PutPartialData}


def _get_active_mask(a_addr: int, a_size: int) -> int:
    lane_shift = int(a_addr) & ((1 << SizeWidth) - 1)
    active_bits = (1 << (1 << int(a_size))) - 1
    return (active_bits << lane_shift) & ((1 << MaskWidth) - 1)


class _TlSeqItemCommon(dv_base_seq_item):
    """Shared TL item helpers for both vsc-backed and compatibility implementations."""

    def __init__(self, name: str = ""):
        super().__init__(name)
        self.channel: TlSeqItemChannel = TlSeqItemChannel.A_CHANNEL
        self.req_abort_after_a_valid_len: bool = False
        self.rsp_abort_after_d_valid_len: bool = False
        self.req_completed: bool = False
        self.rsp_completed: bool = False
        self._saved_a_chan: dict[str, int] | None = None

    def _field_names(self) -> tuple[str, ...]:
        return (
            "a_addr",
            "a_data",
            "a_mask",
            "a_size",
            "a_param",
            "a_source",
            "a_opcode",
            "a_user",
            "d_param",
            "d_data",
            "d_source",
            "d_size",
            "d_opcode",
            "d_error",
            "d_user",
            "d_sink",
            "a_valid_delay",
            "a_valid_len",
            "d_valid_delay",
            "d_valid_len",
        )

    def clone(self) -> "tl_seq_item":
        cloned = type(self)(self.get_name() + "_clone")
        cloned.channel = self.channel
        for field in self._field_names():
            setattr(cloned, field, int(getattr(self, field)))
        cloned.req_abort_after_a_valid_len = bool(
            self.req_abort_after_a_valid_len)
        cloned.rsp_abort_after_d_valid_len = bool(
            self.rsp_abort_after_d_valid_len)
        cloned.req_completed = bool(self.req_completed)
        cloned.rsp_completed = bool(self.rsp_completed)
        return cloned

    def convert2string(self) -> str:
        a_opcode_name = {
            PutFullData: "PutFullData",
            PutPartialData: "PutPartialData",
            Get: "Get",
        }.get(int(self.a_opcode), f"Invalid, value: {int(self.a_opcode)}")
        d_opcode_name = {
            AccessAck: "AccessAck",
            AccessAckData: "AccessAckData",
        }.get(int(self.d_opcode), f"Invalid, value: {int(self.d_opcode)}")
        return (
            f"a_addr = 0x{int(self.a_addr):x} "
            f"a_data = 0x{int(self.a_data):x} "
            f"a_mask = 0x{int(self.a_mask):x} "
            f"a_size = 0x{int(self.a_size):x} "
            f"a_param = 0x{int(self.a_param):x} "
            f"a_source = 0x{int(self.a_source):x} "
            f"a_opcode = {a_opcode_name} "
            f"a_user = 0x{int(self.a_user):x} "
            f"d_data = 0x{int(self.d_data):x} "
            f"d_size = 0x{int(self.d_size):x} "
            f"d_param = 0x{int(self.d_param):x} "
            f"d_source = 0x{int(self.d_source):x} "
            f"d_opcode = {d_opcode_name} "
            f"d_error = {int(bool(self.d_error))} "
            f"d_user = {int(self.d_user)} "
            f"d_sink = {int(self.d_sink)} "
            f"req_abort_after_a_valid_len = {int(bool(self.req_abort_after_a_valid_len))} "
            f"rsp_abort_after_d_valid_len = {int(bool(self.rsp_abort_after_d_valid_len))} "
            f"req_completed = {int(bool(self.req_completed))} "
            f"rsp_completed = {int(bool(self.rsp_completed))}")

    def do_compare(self, rhs, comparer=None) -> bool:
        if not isinstance(rhs, type(self)):
            return False
        return (int(self.a_addr) == int(rhs.a_addr) and
                int(self.a_data) == int(rhs.a_data) and
                int(self.a_mask) == int(rhs.a_mask) and
                int(self.a_size) == int(rhs.a_size) and
                int(self.a_param) == int(rhs.a_param) and
                int(self.a_source) == int(rhs.a_source) and
                int(self.a_opcode) == int(rhs.a_opcode) and
                int(self.a_user) == int(rhs.a_user) and
                int(self.d_data) == int(rhs.d_data) and
                int(self.d_size) == int(rhs.d_size) and
                int(self.d_param) == int(rhs.d_param) and
                int(self.d_source) == int(rhs.d_source) and
                int(self.d_opcode) == int(rhs.d_opcode) and
                bool(self.d_error) == bool(rhs.d_error) and
                int(self.d_user) == int(rhs.d_user) and
                int(self.d_sink) == int(rhs.d_sink))

    def _normalize_legal_a_chan(self) -> None:
        self.a_opcode = int(self.a_opcode)
        if not _a_opcode_is_valid(self.a_opcode):
            self.a_opcode = Get

        self.a_size = min(int(self.a_size), 2)
        align = 1 << int(self.a_size)
        self.a_addr = int(self.a_addr) & ~((align - 1) if align > 1 else 0)

        active_mask = _get_active_mask(int(self.a_addr), int(self.a_size))
        if int(self.a_opcode) == PutFullData:
            self.a_mask = active_mask
        elif int(self.a_mask) == 0 or not _mask_low_in_inactive_lanes(
                int(self.a_mask), int(self.a_addr), int(self.a_size)):
            self.a_mask = active_mask
        elif not _size_gte_mask(int(self.a_mask), int(self.a_size)):
            self.a_mask = active_mask

        self.a_param = 0
        self.d_param = 0
        self.d_error = bool(self.d_error)

    def _capture_a_chan(self) -> None:
        self._saved_a_chan = {
            field: int(getattr(self, field))
            for field in ("a_addr", "a_data", "a_mask", "a_size", "a_param",
                          "a_source", "a_opcode", "a_user")
        }

    def _restore_a_chan(self) -> None:
        if self._saved_a_chan is None:
            return
        for field, value in self._saved_a_chan.items():
            setattr(self, field, value)

    def get_exp_d_error(self) -> bool:
        return (self.get_error_a_opcode_invalid() or
                self.get_error_size_gte_mask() or
                self.get_error_PutFullData_mask_size_mismatched() or
                self.get_error_addr_size_misaligned() or
                self.get_error_mask_not_in_active_lanes() or
                self.get_error_size_over_max())

    def get_error_a_opcode_invalid(self) -> bool:
        return not _a_opcode_is_valid(int(self.a_opcode))

    def get_written_data(self) -> int:
        if not self.is_write():
            raise ValueError(
                "get_written_data() may only be called on a write")
        masked_data = 0
        for i in range(MaskWidth):
            if (int(self.a_mask) >> i) & 1:
                masked_data |= int(self.a_data) & (0xFF << (8 * i))
        return masked_data

    def get_error_PutFullData_mask_size_mismatched(self) -> bool:
        return int(self.a_opcode) == PutFullData and not _mask_is_full(
            int(self.a_mask), int(self.a_size))

    def get_error_size_gte_mask(self) -> bool:
        return int(self.a_opcode) != PutFullData and not _size_gte_mask(
            int(self.a_mask), int(self.a_size))

    def get_error_addr_size_misaligned(self) -> bool:
        return not _addr_aligned_to_size(int(self.a_addr), int(self.a_size))

    def get_error_mask_not_in_active_lanes(self) -> bool:
        return not _mask_low_in_inactive_lanes(int(
            self.a_mask), int(self.a_addr), int(self.a_size))

    def get_error_size_over_max(self) -> bool:
        return not _below_max_a_size(int(self.a_size))

    def randomize_a_chan_with_protocol_error(self) -> None:
        self.randomize()

        opcode_mask = (1 << OpcodeWidth) - 1
        invalid_opcodes = [
            op for op in range(opcode_mask + 1) if not _a_opcode_is_valid(op)
        ]
        max_addr = (1 << AddrWidth) - 1
        max_size = (1 << SizeWidth) - 1
        max_mask = (1 << MaskWidth) - 1

        def _set_invalid_opcode() -> None:
            self.a_opcode = self.random.choice(
                invalid_opcodes) if invalid_opcodes else opcode_mask

        def _set_invalid_mask() -> None:
            active_mask = _get_active_mask(int(self.a_addr), int(self.a_size))
            inactive_mask = max_mask & ~active_mask
            if inactive_mask != 0:
                forced = 1 << self.random.choice(
                    [i for i in range(MaskWidth) if (inactive_mask >> i) & 1])
                self.a_mask = forced | (self.random.getrandbits(MaskWidth) &
                                        inactive_mask)
            else:
                self.a_opcode = PutFullData
                cleared = self.random.randrange(0, MaskWidth)
                self.a_mask = max_mask & ~(1 << cleared)

        def _set_size_too_small_for_mask() -> None:
            self.a_opcode = self.random.choice([Get, PutPartialData])
            self.a_size = self.random.choice([0, 1])
            need_bits = (1 << int(self.a_size)) + 1
            positions = self.random.sample(range(MaskWidth),
                                           k=min(need_bits, MaskWidth))
            self.a_mask = 0
            for pos in positions:
                self.a_mask |= 1 << pos

        def _set_misaligned_addr() -> None:
            align = 1 << int(self.a_size)
            if align <= 1:
                self.a_size = self.random.choice([1, 2])
                align = 1 << int(self.a_size)
            base = self.random.randrange(0, max_addr + 1) & ~(align - 1)
            misalign = self.random.randrange(1, align)
            self.a_addr = (base | misalign) & max_addr

        def _set_size_over_max() -> None:
            illegal_sizes = [
                sz for sz in range(max_size + 1) if not _below_max_a_size(sz)
            ]
            self.a_size = self.random.choice(
                illegal_sizes) if illegal_sizes else max_size

        self.random.choice([
            _set_invalid_opcode,
            _set_invalid_mask,
            _set_size_too_small_for_mask,
            _set_misaligned_addr,
            _set_size_over_max,
        ])()

    def is_write(self) -> bool:
        return int(self.a_opcode) in {PutFullData, PutPartialData}

    def is_ok(self) -> bool:
        exp_d_opcode = AccessAckData if int(
            self.a_opcode) == Get else AccessAck
        return int(self.d_opcode) == exp_d_opcode and int(
            self.a_source) == int(self.d_source)

    def is_a_chan_intg_ok(self, throw_error: bool = True) -> bool:
        return True

    def is_d_chan_intg_ok(
        self,
        en_rsp_intg_chk: int = 1,
        en_data_intg_chk: int = 1,
        throw_error: bool = True,
    ) -> bool:
        return True


@vsc.randobj
class tl_seq_item(_TlSeqItemCommon):
    """TileLink UL sequence item backed by class-level vsc constraints."""

    def __init__(self, name: str = ""):
        super().__init__(name)
        self.a_addr = vsc.rand_bit_t(AddrWidth)
        self.a_data = vsc.rand_bit_t(DataWidth)
        self.a_mask = vsc.rand_bit_t(MaskWidth)
        self.a_size = vsc.rand_bit_t(SizeWidth)
        self.a_param = vsc.rand_bit_t(ParamWidth)
        self.a_source = vsc.rand_bit_t(SourceWidth)
        self.a_opcode = vsc.rand_bit_t(OpcodeWidth)
        self.a_user = vsc.rand_bit_t(AUserWidth)

        self.d_param = vsc.rand_bit_t(ParamWidth)
        self.d_data = vsc.rand_bit_t(DataWidth)
        self.d_source = vsc.rand_bit_t(SourceWidth)
        self.d_size = vsc.rand_bit_t(SizeWidth)
        self.d_opcode = vsc.rand_bit_t(OpcodeWidth)
        self.d_error = vsc.rand_bit_t(1)
        self.d_user = vsc.rand_bit_t(DUserWidth)
        self.d_sink = vsc.rand_bit_t(1)

        self.a_valid_delay = vsc.rand_uint32_t()
        self.a_valid_len = vsc.rand_uint32_t()
        self.d_valid_delay = vsc.rand_uint32_t()
        self.d_valid_len = vsc.rand_uint32_t()

        self._a_chan_rand_enabled = True
        self._protocol_constraints_enabled = True

    @vsc.constraint
    def param_c(self):
        self.a_param == 0
        self.d_param == 0

    @vsc.constraint
    def no_d_error_c(self):
        self.d_error == 0

    @vsc.constraint
    def a_valid_len_c(self):
        self.a_valid_len in vsc.rangelist(vsc.rng(1, 10))

    @vsc.constraint
    def d_valid_len_c(self):
        self.d_valid_len in vsc.rangelist(vsc.rng(1, 10))

    @vsc.constraint
    def valid_delay_c(self):
        self.a_valid_delay in vsc.rangelist(vsc.rng(0, 50))
        self.d_valid_delay in vsc.rangelist(vsc.rng(0, 50))

    @vsc.constraint
    def d_opcode_c(self):
        self.d_opcode in vsc.rangelist(AccessAckData, AccessAck)

    @vsc.constraint
    def a_opcode_c(self):
        self.a_opcode in vsc.rangelist(Get, PutFullData, PutPartialData)

    @vsc.constraint
    def max_size_c(self):
        self.a_size <= 2

    def pre_randomize(self) -> None:
        with vsc.raw_mode():
            for field in (
                    "a_addr",
                    "a_data",
                    "a_mask",
                    "a_size",
                    "a_param",
                    "a_source",
                    "a_opcode",
                    "a_user",
            ):
                self.__dict__[field].rand_mode = bool(
                    self._a_chan_rand_enabled)

        self.a_opcode_c.constraint_mode(
            bool(self._protocol_constraints_enabled))
        self.max_size_c.constraint_mode(
            bool(self._protocol_constraints_enabled))

    def post_randomize(self) -> None:
        if self._a_chan_rand_enabled and self._protocol_constraints_enabled:
            self._normalize_legal_a_chan()
        elif not self._a_chan_rand_enabled:
            self._restore_a_chan()
        self.d_error = bool(self.d_error)

    def disable_a_chan_randomization(self) -> None:
        self._capture_a_chan()
        self._a_chan_rand_enabled = False

    def disable_a_chan_protocol_constraint(self) -> None:
        self._protocol_constraints_enabled = False
