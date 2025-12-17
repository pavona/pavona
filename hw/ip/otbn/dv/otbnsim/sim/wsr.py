# Copyright lowRISC contributors (OpenTitan project).
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of
# "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN"
# (https://eprint.iacr.org/2025/2028)
# Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham.
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0


import sys
from typing import List, Optional, Sequence, Tuple
from .trace import Trace
from .ext_regs import OTBNExtRegs
from .kmac import KmacBlock
DEBUG_KMAC = False


def kmac_debug_print(text):
    if DEBUG_KMAC:
        print(text, file=sys.stderr)


class TraceWSR(Trace):
    def __init__(self, wsr_name: str, new_value: Optional[int]):
        self.wsr_name = wsr_name
        self.new_value = new_value

    def trace(self) -> str:
        s = '{} = '.format(self.wsr_name)
        if self.new_value is None:
            s += '0x' + 'x' * 8
        else:
            s += '{:#x}'.format(self.new_value)
        return s

    def rtl_trace(self) -> str:
        return '> {}: {}'.format(self.wsr_name,
                                 Trace.hex_value(self.new_value, 256))


class WSR:
    '''Models a Wide Status Register'''
    def __init__(self, name: str):
        self.name = name
        self._pending_write = False

    def has_value(self) -> bool:
        '''Return whether the WSR has a valid value'''
        return True

    def on_start(self) -> None:
        '''Reset the WSR if necessary for the start of an operation'''
        return

    def read_unsigned(self) -> int:
        '''Get the stored value as a 256-bit unsigned value'''
        raise NotImplementedError()

    def write_unsigned(self, value: int) -> None:
        '''Set the stored value as a 256-bit unsigned value'''
        raise NotImplementedError()

    def read_signed(self) -> int:
        '''Get the stored value as a 256-bit signed value'''
        uval = self.read_unsigned()
        return uval - (1 << 256 if uval >> 255 else 0)

    def write_signed(self, value: int) -> None:
        '''Set the stored value as a 256-bit signed value'''
        assert -(1 << 255) <= value < (1 << 255)
        uval = (1 << 256) + value if value < 0 else value
        self.write_unsigned(uval)

    def commit(self) -> None:
        '''Commit pending changes'''
        self._pending_write = False

    def abort(self) -> None:
        '''Abort pending changes'''
        self._pending_write = False

    def changes(self) -> Sequence[Trace]:
        '''Return list of pending architectural changes'''
        return []


class DumbWSR(WSR):
    '''Models a WSR without special behaviour'''
    def __init__(self, name: str):
        super().__init__(name)
        self._value = 0
        self._next_value: Optional[int] = None

    def on_start(self) -> None:
        self._value = 0
        self._next_value = None

    def read_unsigned(self) -> int:
        return self._value

    def write_unsigned(self, value: int) -> None:
        assert 0 <= value < (1 << 256)
        self._next_value = value
        self._pending_write = True

    def write_invalid(self) -> None:
        self._next_value = None
        self._pending_write = True

    def commit(self) -> None:
        if self._next_value is not None:
            self._value = self._next_value
        self._next_value = None
        self._pending_write = False

    def abort(self) -> None:
        self._next_value = None
        self._pending_write = False

    def changes(self) -> List[TraceWSR]:
        return ([TraceWSR(self.name, self._next_value)]
                if self._pending_write else [])


class RandWSR(WSR):
    '''The magic RND WSR

    RND is special as OTBN can stall on reads to it. A read from RND either
    immediately returns data from a cache of a previous EDN request (triggered
    by writing to the RND_PREFETCH CSR) or waits for data from the EDN. To
    model this, anything reading from RND must first call `request_value` which
    returns True if the value is available.

    '''
    def __init__(self, name: str, ext_regs: OTBNExtRegs):
        super().__init__(name)

        self._random_value: Optional[int] = None
        self._next_random_value: Optional[int] = None
        self._ext_regs = ext_regs

        # The pending_request flag says that we've started an instruction that
        # reads from RND. Using it means that we can avoid repeated requests
        # from the EdnClient which is important because it avoids a request on
        # the single cycle where the EdnClient has passed data back to us but
        # that data hasn't yet been committed. If we sent another request on
        # that cycle, the EdnClient would start another transaction.
        self._pending_request = False
        self._next_pending_request = False

        self._fips_err = False
        self.fips_err_escalate = False

        self._rep_err = False
        self.rep_err_escalate = False

    def read_unsigned(self) -> int:
        assert self._random_value is not None
        self._next_random_value = None
        self.rep_err_escalate = self._rep_err
        self.fips_err_escalate = self._fips_err
        return self._random_value

    def read_u32(self) -> int:
        '''Read a 32-bit unsigned result'''
        self.rep_err_escalate = self._rep_err
        self.fips_err_escalate = self._fips_err
        return self.read_unsigned() & ((1 << 32) - 1)

    def write_unsigned(self, value: int) -> None:
        '''Writes to RND are ignored

        Note this is different to `set_unsigned`. This is used by executing
        instruction, see `set_unsigned` docstring for more details
        '''
        return

    def on_start(self) -> None:
        self._next_random_value = None
        self._next_pending_request = False
        self.fips_err_escalate = False
        self.rep_err_escalate = False

    def commit(self) -> None:
        self._random_value = self._next_random_value
        self._pending_request = self._next_pending_request

    def request_value(self) -> bool:
        '''Signals intent to read RND, returns True if a value is available'''
        if self._random_value is not None:
            return True
        if not self._pending_request:
            self._next_pending_request = True
            self._ext_regs.rnd_request()
        return False

    def set_unsigned(self, value: int, fips_err: bool, rep_err: bool) -> None:
        '''Sets a random value that can be read by a future `read_unsigned`

        This is different to `write_unsigned`, that is used by an executing
        instruction to write to RND. This is used by the simulation environment
        to provide a value that is later read by `read_unsigned` and doesn't
        relate to instruction execution (e.g. in an RTL simulation it monitors
        the EDN bus and supplies the simulator with an RND value when a fresh
        one is seen on the EDN bus).
        '''
        assert 0 <= value < (1 << 256)
        self._fips_err = fips_err
        self._rep_err = rep_err
        self.fips_err_escalate = False
        self.rep_err_escalate = False
        self._next_random_value = value
        self._next_pending_request = False


class URNDWSR(WSR):
    '''Models URND PRNG Structure'''
    def __init__(self, name: str):
        super().__init__(name)
        seed = [0x84ddfadaf7e1134d, 0x70aa1c59de6197ff,
                0x25a4fe335d095f1e, 0x2cba89acbe4a07e9]
        self._state = [seed, 4 * [0], 4 * [0], 4 * [0], 4 * [0]]
        self._next_value = 0
        self._value = 0
        self.running = False

    def rol(self, n: int, d: int) -> int:
        '''Rotate n left by d bits'''
        return ((n << d) & ((1 << 64) - 1)) | (n >> (64 - d))

    def read_u32(self) -> int:
        '''Read a 32-bit unsigned result'''
        return self.read_unsigned() & ((1 << 32) - 1)

    def write_unsigned(self, value: int) -> None:
        '''Writes to URND are ignored'''
        return

    def on_start(self) -> None:
        self.running = False

    def read_unsigned(self) -> int:
        return self._value

    def state_update(self, data_in: List[int]) -> List[int]:
        a_in = data_in[3]
        b_in = data_in[2]
        c_in = data_in[1]
        d_in = data_in[0]

        a_out = a_in ^ b_in ^ d_in
        b_out = a_in ^ b_in ^ c_in
        c_out = a_in ^ ((b_in << 17) & ((1 << 64) - 1)) ^ c_in
        d_out = self.rol(d_in ^ b_in, 45)
        assert a_out < (1 << 64)
        assert b_out < (1 << 64)
        assert c_out < (1 << 64)
        assert d_out < (1 << 64)
        return [d_out, c_out, b_out, a_out]

    def set_seed(self, value: List[int]) -> None:
        assert len(value) == 4
        self.running = True
        self._state[0] = value
        # Step immediately to update the internal state with the new seed
        self.step()

    def step(self) -> None:
        if self.running:
            mask64 = (1 << 64) - 1
            mid = 4 * [0]
            nv = 0
            for i in range(4):
                st_i = self._state[i]
                self._state[(i + 1) & 3] = self.state_update(st_i)
                mid[i] = (st_i[3] + st_i[0]) & mask64
                nv |= ((self.rol(mid[i], 23) + st_i[3]) & mask64) << (64 * i)
            self._next_value = nv

    def commit(self) -> None:
        self._value = self._next_value

    def changes(self) -> List[TraceWSR]:
        # Our URND model doesn't track (or report) changes to its internal
        # state.
        raise NotImplementedError


class KeyTrace(Trace):
    def __init__(self, name: str, new_value: Optional[int]):
        self.name = name
        self.new_value = new_value

    def trace(self) -> str:
        val_desc = '(unset)' if self.new_value is None else self.new_value
        return '{} = {}'.format(self.name, val_desc)


class SideloadKey:
    '''Represents a sideloaded key, with 384 bits of data and a valid signal'''
    def __init__(self, name: str):
        self.name = name
        self._value: Optional[int] = None
        self._new_value: Optional[Tuple[bool, int]] = None

    def has_value(self) -> bool:
        return self._value is not None

    def read_unsigned(self, shift: int) -> int:
        # The simulator should be careful not to call read_unsigned() unless it
        # has first checked that the value exists.
        assert self._value is not None

        mask256 = (1 << 256) - 1
        return (self._value >> shift) & mask256

    def set_unsigned(self, value: Optional[int]) -> None:
        '''Unlike the WSR write_unsigned, this takes effect immediately

        That way, we can correctly model the combinatorial path from sideload
        keys to the WSR file in the RTL. Note that we do still report the
        change until the next commit.
        '''
        assert value is None or (0 <= value < (1 << 384))
        self._value = value
        self._new_value = (False, 0) if value is None else (True, value)

    def changes(self) -> List[KeyTrace]:
        if self._new_value is not None:
            vld, value = self._new_value
            return [KeyTrace(self.name, value if vld else None)]
        else:
            return []

    def commit(self) -> None:
        self._new_value = None


class KeyWSR(WSR):
    def __init__(self, name: str, shift: int, key_reg: SideloadKey):
        assert 0 <= shift < 384
        super().__init__(name)
        self._shift = shift
        self._key_reg = key_reg

    def has_value(self) -> bool:
        return self._key_reg.has_value()

    def read_unsigned(self) -> int:
        return self._key_reg.read_unsigned(self._shift)

    def write_unsigned(self, value: int) -> None:
        return


class KmacPartialWriteISPR(WSR):
    '''Keccak partial write WSR

    This register defines the number of valid bytes in the
    KmacMsgWSR register for writing partial words and STRB
    on the KMAC Req AppIntf
    '''
    def __init__(self, name: str, kmac: KmacBlock):
        super().__init__(name)
        self._kmac = kmac
        self._value = None
        self._next_value = None

    def read_unsigned(self) -> int:
        return self._value

    def read_mask(self) -> int:
        if self._value is None:
            return 32
        elif self._value > 32:
            raise ValueError(f'Invalid mask size for KMAC_PARTIAL_WRITE: {self._value:#066x}')
        return self._value

    def write_unsigned(self, value: int) -> None:
        self._next_value = value
        self._pending_write = True

    def commit(self) -> None:
        if self._pending_write:
            self._value = self._next_value
            kmac_debug_print(f"\tREG -> KMAC_PARTIAL_WRITE reg: {hex(self._next_value)}")
        super().commit()

    def changes(self) -> Sequence[Trace]:
        '''Return list of pending architectural changes'''
        return ([TraceWSR(self.name, self._next_value)]
                if self._pending_write else [])


class KmacMsgWSR(WSR):
    '''Keccak message WSR: sends data to the KMAC hardware block.

    Reads from this register always return 0.

    When KMAC is in the "absorb" state, writes to this register will trigger
    writes to KMAC's message FIFO. Otherwise, writes will be ignored.

    KMAC can only receive about 64 bits of data per cycle via the hardware
    application interface. If there is not enough space in the internal FIFO to
    hold the data from a new write, the instruction stalls while it waits for
    space to become available.
    '''
    def __init__(self, name: str, kmac: KmacBlock, partial_ispr: KmacPartialWriteISPR):
        super().__init__(name)
        self._kmac = kmac
        self._pending_write_to_app_intf = False
        self._pending_write_stall_pw = False
        self._start_cycle_fifo_ready = False
        self._prev_fifo_ready = True
        self._next_value = None
        self._value = None
        self._partial_ispr = partial_ispr

    def read_unsigned(self) -> int:
        return 0

    def write_unsigned(self, value: int) -> None:
        assert 0 <= value < (1 << 256)
        self._next_value = value
        self._pending_write = True

    def write_invalid(self) -> None:
        self._next_value = None
        self._pending_write = True

    def step(self) -> None:
        self._kmac._app_intf_writing = False
        kmac_debug_print("\tFETCHING STARTING FIFO STATUS")
        self._pending_write_stall_pw = self._pending_write_to_app_intf
        self._start_cycle_fifo_ready = self._kmac.app_intf_fifo_ready()
        if self._kmac._app_fifo_after_flush:
            self._pending_write_stall_pw = False
        # KMAC_MSG reg -> FIFO
        if self._pending_write_to_app_intf:
            strb_len = self._partial_ispr.read_mask()
            value_bytes = int.to_bytes(self._value, byteorder='little', length=32)[:strb_len]
            kmac_debug_print("\tPending write to App FIFO")
            if (
                self._kmac._app_intf_last_latch
                or (self._kmac._pending_app_intf_last and not self.pending_write_pw())
                and not self._kmac._app_intf_fifo_flush
            ):
                kmac_debug_print("DROPPING WRITE TO FIFO FROM OVERSIZED MSG")
                self._kmac._kmac_oversized_err = True
                self._pending_write_to_app_intf = False
                self._pending_write_stall_pw = False
            elif not self._kmac._app_intf_last and self._kmac.write_to_app_intf_fifo(value_bytes):
                kmac_debug_print(f"\tKMAC_MSG -> APP FIFO: Writing \
                                 {len(value_bytes)} bytes to App FIFO")
                self._pending_write_to_app_intf = False
                self._kmac._app_intf_writing = True

    def pending_write_pw(self) -> bool:
        if self._kmac._app_intf_fifo_flush and not self._pending_write_to_app_intf:
            return False
        else:
            return self._pending_write_stall_pw

    def request_write(self) -> bool:
        return self._start_cycle_fifo_ready

    def commit(self) -> None:
        # reg -> KMAC_MSG reg
        if self._pending_write:
            self._pending_write = False
            if self._next_value is not None:
                kmac_debug_print(f"\tREG -> KMAC_MSG reg: {hex(self._next_value)}")
                self._value = self._next_value
                if self._kmac._app_intf_last_latch or self._kmac._pending_app_intf_last:
                    self._pending_write_to_app_intf = False
                    self._kmac._kmac_oversized_err = True
                else:
                    self._pending_write_to_app_intf = True
                self._pending_write_stall_pw = True
            else:
                # Silence F841 warning until we reimplement the KMAC interface.
                value_bytes = None  # noqa: F841
        super().commit()

    def changes(self) -> Sequence[Trace]:
        '''Return list of pending architectural changes'''
        return ([TraceWSR(self.name, self._next_value)]
                if self._pending_write else [])


class KmacCfgWSR(WSR):
    '''Keccak config WSR: used to set SHA3 mode and Keccak Strength
    '''
    def __init__(self, name: str, kmac: KmacBlock, partial_ispr: KmacPartialWriteISPR):
        super().__init__(name)
        self._value = 0
        self._kmac = kmac
        self._partial_ispr = partial_ispr

    def read_unsigned(self) -> int:
        return self._value

    def write_unsigned(self, value: int) -> None:
        self._next_value = value
        self._pending_write = True

    def commit(self) -> None:
        if self._pending_write:
            self._value = self._next_value
            # We reset the PW value each config write to reduce uneccesary writes
            self._partial_ispr._value = 32
            kmac_debug_print(f"\tREG -> KMAC_MSG reg: {hex(self._next_value)}")
            if self._value == (1 << 31):
                # config value to release KMAC app intf
                # should be done once before OTBN yiels
                # to Ibex
                self._kmac._reset()
            else:
                mode = self._value & 0b11
                strength = (self._value >> 2) & 0b111
                msg_len = self._value >> 5
                self._kmac._reset()
                self._kmac.set_configuration(mode, strength, msg_len)
        super().commit()

    def changes(self) -> Sequence[Trace]:
        '''Return list of pending architectural changes'''
        return ([TraceWSR(self.name, self._next_value)]
                if self._pending_write else [])


class KmacStatusWSR(WSR):
    '''Keccak status WSR
    '''
    def __init__(self, name: str, kmac: KmacBlock):
        super().__init__(name)
        self._kmac = kmac

    def read_unsigned(self) -> int:
        value = self._kmac.get_undersized() << 4
        value += self._kmac.get_oversized() << 3
        value += self._kmac.get_error() << 2
        value += self._kmac.get_ready() << 1
        value += self._kmac.get_done()
        return value

    def write_unsigned(self, value: int) -> None:
        return

    def changes(self) -> Sequence[Trace]:
        '''Return list of pending architectural changes'''
        return ([TraceWSR(self.name, self._next_value)]
                if self._pending_write else [])


class KmacDigestWSR(WSR):
    '''Keccak digest WSR: recieves data from the KMAC hardware block.

    This register is not writeable; writes are always discarded.

    If KMAC is in the "idle" state, reads always return 0. When KMAC is in the
    "absorb" state, reading from this register will issue a `process` command;
    KMAC will move into the "squeeze" state and begin computing the digest.
    OTBN will stall until the digest computation finishes, and KMAC sends the
    first 256 bits of the digest as the read result.

    Reads from this register in the "squeeze" state will pull 256-bit slices of
    the digest sequentially from KMAC. The amount of digest available after
    `process` depends on the rate of the specific Keccak instantiation. If 256
    bits of digest are not available, a read from this register will issue the
    `run` command to KMAC and again OTBN will stall until the full 256 bits is
    ready.
    '''
    def __init__(self, name: str, kmac: KmacBlock):
        super().__init__(name)
        self._kmac = kmac
        self._next_value = None
        self._has_value = False

    def has_value(self) -> bool:
        return self._has_value

    def request_value(self) -> bool:
        '''Returns true if the full register value is ready,
        but only one cycle after digest_ready() is asserted,
        modeling the OTBN app_req.next behavior'''
        self._has_value = self._kmac.digest_ready()

        kmac_debug_print(f"\tKMAC_DIGEST - Request value: {self._has_value}")
        return self._has_value

    def read_unsigned(self) -> int:
        value = int.from_bytes(self._kmac.read(32), byteorder='little')
        kmac_debug_print(f"\tRead value: {hex(value)}")
        return value

    def write_unsigned(self, value: int) -> None:
        return

    def write_invalid(self) -> None:
        self._next_value = None
        self._pending_write = True

    def commit(self) -> None:
        if self._next_value is not None:
            self._value = self._next_value
        else:
            self._value = None
        super().commit()


class WSRFile:
    '''A model of the WSR file'''
    def __init__(self, ext_regs: OTBNExtRegs, kmac: KmacBlock, pqc: bool) -> None:
        self.EN_PQC = pqc
        self.KeyS0 = SideloadKey('KeyS0')
        self.KeyS1 = SideloadKey('KeyS1')
        self.Kmac = kmac

        self.MOD = DumbWSR('MOD')
        self.RND = RandWSR('RND', ext_regs)
        self.URND = URNDWSR('URND')
        self.ACC = DumbWSR('ACC')
        self.ACCH = DumbWSR('ACCH')
        self.KeyS0L = KeyWSR('KeyS0L', 0, self.KeyS0)
        self.KeyS0H = KeyWSR('KeyS0H', 256, self.KeyS0)
        self.KeyS1L = KeyWSR('KeyS1L', 0, self.KeyS1)
        self.KeyS1H = KeyWSR('KeyS1H', 256, self.KeyS1)
        self.KMAC_STATUS = KmacStatusWSR('KMAC_STATUS', self.Kmac)
        self.KMAC_DIGEST = KmacDigestWSR('KMAC_DIGEST', self.Kmac)
        self.KMAC_PARTIAL_WRITE = KmacPartialWriteISPR('KMAC_PARTIAL_WRITE', self.Kmac)
        self.KMAC_CFG = KmacCfgWSR('KMAC_CFG', self.Kmac, self.KMAC_PARTIAL_WRITE)
        self.KMAC_MSG = KmacMsgWSR('KMAC_MSG', self.Kmac, self.KMAC_PARTIAL_WRITE)

        # These are the common index regardless of PQC enable or not
        self._by_idx = {
            0: self.MOD,
            1: self.RND,
            2: self.URND,
            3: self.ACC,
            4: self.KeyS0L,
            5: self.KeyS0H,
            6: self.KeyS1L,
            7: self.KeyS1H,
        }

        if self.EN_PQC:
            self._by_idx.update({
                8: self.KMAC_CFG,
                9: self.KMAC_MSG,
                10: self.KMAC_DIGEST,
                11: self.ACCH,
            })

    def on_start(self) -> None:
        '''Called at the start of an operation

        This clears values that don't persist between runs (everything except
        RND and the key registers)
        '''
        for reg in self._by_idx.values():
            reg.on_start()

    def check_idx(self, idx: int) -> bool:
        '''Return True if idx is a valid WSR index'''
        return idx in self._by_idx

    def has_value_at_idx(self, idx: int) -> int:
        '''Return True if the WSR at idx has a valid valu.

        Assumes that idx is a valid index (call check_idx to ensure this).

        '''
        return self._by_idx[idx].has_value()

    def read_at_idx(self, idx: int) -> int:
        '''Read the WSR at idx as an unsigned 256-bit value

        Assumes that idx is a valid index (call check_idx to ensure this).

        '''
        return self._by_idx[idx].read_unsigned()

    def write_at_idx(self, idx: int, value: int) -> None:
        '''Write the WSR at idx as an unsigned 256-bit value

        Assumes that idx is a valid index (call check_idx to ensure this).

        '''
        return self._by_idx[idx].write_unsigned(value)

    def commit(self) -> None:
        self.MOD.commit()
        self.RND.commit()
        self.URND.commit()
        self.ACC.commit()
        self.ACCH.commit()
        self.KeyS0.commit()
        self.KeyS1.commit()
        self.KMAC_MSG.commit()
        self.KMAC_CFG.commit()
        self.KMAC_DIGEST.commit()
        self.KMAC_PARTIAL_WRITE.commit()

    def abort(self) -> None:
        self.MOD.abort()
        self.RND.abort()
        self.URND.abort()
        self.ACC.abort()
        self.ACCH.abort()
        # We commit changes to the sideloaded keys from outside, even if the
        # instruction itself gets aborted.
        self.KeyS0.commit()
        self.KeyS1.commit()
        self.KMAC_MSG.abort()
        self.KMAC_CFG.abort()
        self.KMAC_DIGEST.abort()
        self.KMAC_PARTIAL_WRITE.abort()

    def changes(self) -> List[Trace]:
        ret: List[Trace] = []
        ret += self.MOD.changes()
        ret += self.RND.changes()
        ret += self.ACC.changes()
        if self.EN_PQC:
            ret += self.ACCH.changes()
        ret += self.KeyS0.changes()
        ret += self.KeyS1.changes()
        if self.EN_PQC:
            ret += self.KMAC_MSG.changes()
            ret += self.KMAC_CFG.changes()
            ret += self.KMAC_STATUS.changes()
            ret += self.KMAC_DIGEST.changes()
            ret += self.KMAC_PARTIAL_WRITE.changes()
        return ret

    def set_sideload_keys(self,
                          key0: Optional[int],
                          key1: Optional[int]) -> None:
        self.KeyS0.set_unsigned(key0)
        self.KeyS1.set_unsigned(key1)

    def wipe(self) -> None:
        self.MOD.write_invalid()
        self.ACC.write_invalid()
        self.ACCH.write_invalid()
        self.KMAC_MSG.write_invalid()
        self.KMAC_DIGEST.write_invalid()
