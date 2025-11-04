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
from Crypto.Hash import cSHAKE128, cSHAKE256, SHAKE128, SHAKE256, SHA3_224, \
    SHA3_256, SHA3_384, SHA3_512
from .trace import Trace
from .ext_regs import OTBNExtRegs
DEBUG_KMAC = False
OTBN_PQC = True


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


class KmacBlock:
    '''Emulates the KMAC hardware block.'''
    _CMD_START = 0x1d
    _CMD_PROCESS = 0x2e
    _CMD_RUN = 0x31
    _CMD_DONE = 0x16
    _STATUS_IDLE = 'IDLE'
    _STATUS_ABSORB = 'ABSORB'
    _STATUS_SQUEEZE = 'SQUEEZE'
    _MODE_SHA3 = 0x0
    _MODE_SHAKE = 0x1
    _MODE_CSHAKE = 0x2
    _STRENGTH_128 = 0x0
    _STRENGTH_224 = 0x1
    _STRENGTH_256 = 0x2
    _STRENGTH_384 = 0x3
    _STRENGTH_512 = 0x4

    # Message FIFO size in bytes. See:
    # https://github.com/lowRISC/opentitan/blob/1b56f197b49d5f597867561d0a153d2e7a985909/hw/ip/kmac/rtl/kmac_pkg.sv#L37
    # https://github.com/lowRISC/opentitan/blob/1b56f197b49d5f597867561d0a153d2e7a985909/hw/ip/kmac/rtl/sha3_pkg.sv#L52
    _MSG_FIFO_SIZE_BYTES = 10 * 8
    _MSG_PACKER_SIZE_BYTES = 2 * 8

    # Rate at which the Keccak core absorbs data from the message FIFO
    # (bytes/cycle). See:
    # https://github.com/lowRISC/opentitan/blob/1b56f197b49d5f597867561d0a153d2e7a985909/hw/ip/kmac/rtl/keccak_round.sv#L50
    _MSG_FIFO_ABSORB_BYTES_PER_CYCLE = 8

    # If the packer in the Keccak MSG FIFO fills up completely, it must flush
    # before it can consume new data.
    _MSG_FIFO_PACKER_FLUSH_LATENCY = 2

    # Cycles for a Keccak round. See:
    # https://opentitan.org/book/hw/ip/kmac/doc/theory_of_operation.html#keccak-round
    _KECCAK_CYCLES_PER_ROUND = 4
    _KECCAK_NUM_ROUNDS = 24
    # It takes 3 cycles until the finished digest is exposed to the application interface.
    _KECCAK_LATENCY_DIGEST_EXPOSED = 3
    # It takes 2 additional cycles when the Keccak permutation logic is done
    # for operations to continue (e.g. padding logic to resume)
    _KECCAK_LATENCY_DONE = 2

    # Number of bytes that can be sent to KMAC per cycle over the application
    # interface.
    _APP_INTF_BYTES_PER_CYCLE = 8

    # FIFO within OTBN that waits to send message data over the application
    # interface. Without this we'd have to stall on every message WSR write
    # while we wait to send data to KMAC.
    _APP_INTF_FIFO_SIZE_BYTES = 64

    # After setting the KMAC_CFG register, it takes two cycles until the KMAC_STATUS
    # register changes its value to ready.
    # The third cycle holds the CFG word with KMAC now ready, 4th cycle is MSG
    _APP_INTF_READY_LATENCY = 4

    # If a new chunk of the digest is requested for the DIGEST REG, there is a delay of
    # X cycles.
    _SHIFT_DIGEST_LATENCY = 1
    # If a request for a new chunk of the digest exceeds the rate (for XOFs)
    # the application interface triggers a new permutation.
    _NEW_PERMUTATION_LATENCY = _KECCAK_CYCLES_PER_ROUND * _KECCAK_NUM_ROUNDS + \
        _KECCAK_LATENCY_DIGEST_EXPOSED + _SHIFT_DIGEST_LATENCY

    def __init__(self):
        self._reset()
        self._status = self._STATUS_IDLE
        self._mode = self._MODE_SHA3
        self._strength = self._STRENGTH_128
        self._read_offset = 0
        self._padded = False
        self._padding_only = False
        self._app_intf_ready = False
        self._app_intf_ready_pending_ctr = None
        self._app_intf_fifo_ready = True
        self._app_intf_fifo_ready_next = True
        self._app_intf_fifo_flush = False
        self._pending_app_intf_last = False
        self._app_intf_last = False
        self._app_intf_last_latch = False
        self._msg_fifo_flush_ctr = 0
        self._msg_fifo_flush = False
        self._msg_fifo_flushed = False
        self._msg_fifo_packer_flushed = False
        self._msg_fifo_packer_flush_ctr = 0
        self._msg_fifo_packer_flushing = False
        self._automatically_write_digest = True
        self._digest_ready = False
        self._digest_ready_next = False
        self._digest_read = False
        self._leftover_digest_bytes = 0
        self._shift_digest_reg = False
        self._new_permutation = False
        self._digest_request_ctr = 0
        self._skip_digest_shift_cycle = False
        self._kmac_undersized_err = False
        self._kmac_oversized_err = False

    def _reset(self) -> None:
        self._status = self._STATUS_IDLE
        self._core_cycles_remaining = None
        self._state = None
        self._rate_bytes = None
        self._read_offset = 0
        self._strength = self._STRENGTH_128
        self._padded = False
        self._padding_only = False
        self._mode = self._MODE_SHA3
        self._msg_fifo = bytes()
        self._app_intf_fifo = bytes()
        self._app_intf_bytes_sent = 0
        self._app_intf_sending = False
        self._app_intf_writing = False
        self._app_intf_ready = False
        self._app_intf_ready_pending_ctr = None
        self._pending_app_intf_last = False
        self._app_intf_last = False
        self._app_intf_last_latch = False
        self._app_intf_fifo_ready = True
        self._app_intf_fifo_ready_next = True
        self._app_intf_fifo_flush = False
        self._core_pending_bytes = 0
        self._core_pending_bytes_next = 0
        self._msg_len = 0
        self._msg_size = 0
        self._pending_process = False
        self._msg_fifo_flush_ctr = 0
        self._msg_fifo_flush = False
        self._msg_fifo_flushed = False
        self._msg_fifo_packer_flushed = False
        self._msg_fifo_packer_flushing = False
        self._msg_fifo_packer_flush_ctr = 0
        self._automatically_write_digest = True
        self._digest_ready = False
        self._digest_ready_next = False
        self._digest_read = False
        self._leftover_digest_bytes = 0
        self._shift_digest_reg = False
        self._new_permutation = False
        self._digest_request_ctr = 0
        self._skip_digest_shift_cycle = False
        self._kmac_undersized_err = False
        self._kmac_oversized_err = False

    def set_configuration(self, mode: int, strength: int, msg_len: int) -> None:
        kmac_debug_print(f"\tSetting KMAC config: mode = {mode}, \
                         strength = {strength}, len = {msg_len}")
        self._mode = mode
        self._strength = strength
        self._msg_len = msg_len
        self._msg_size = msg_len
        self._app_intf_bytes_sent = 0
        self._app_intf_ready_pending_ctr = 0
        self._app_intf_last_latch = False
        # Reset error flags
        self._kmac_undersized_err = False
        self._kmac_oversized_err = False
        self.start()

    def get_error(self) -> int:
        return 0

    def get_ready(self) -> int:
        return self._app_intf_ready

    def get_done(self) -> int:
        return int(self.digest_ready())

    def get_undersized(self) -> int:
        return self._kmac_undersized_err

    def get_oversized(self) -> int:
        return self._kmac_oversized_err

    def message_done(self) -> None:
        '''Indicate that the message input is done.'''
        # Don't issue the `process` command yet; wait for FIFOs to clear.
        kmac_debug_print("\tKMAC message done, pending process")
        self._pending_process = True

    def is_idle(self) -> bool:
        return self._status == self._STATUS_IDLE

    def is_absorbing(self) -> bool:
        return self._status == self._STATUS_ABSORB

    def is_squeezing(self) -> bool:
        return self._status == self._STATUS_SQUEEZE

    def digest_req_err(self) -> bool:
        msg_req_err = (self._msg_len > 0
                       and len(self._app_intf_fifo) < 8
                       and self._msg_len > len(self._app_intf_fifo))
        if (
            not self._app_intf_last_latch
            and msg_req_err
            and not self._app_intf_sending
            and not self._app_intf_writing
        ):
            return True
        else:
            return False

    def digest_ready(self) -> bool:
        kmac_debug_print(f"\tKMAC Digest Ready Req: \
                        autowrite={self._automatically_write_digest} \
                        shift={self._shift_digest_reg} \
                        permute={self._new_permutation} \
                        read={self._digest_read} ready={self._digest_ready} \
                        read_offset={self._read_offset} \
                        leftover={self._leftover_digest_bytes}")

        # This helper function is executed during a digest wsrr insn
        # Check if there is an undersized message at this point
        digest_err = self.digest_req_err()

        # If there is an undersized error we inject a "last" to the message request
        # to prevent stalling and raise an error flag to the status reg
        if digest_err and not self._kmac_undersized_err:
            kmac_debug_print(f"Transaction Error: {digest_err}")
            msg_fifo_write_ready = self.msg_fifo_bytes_available() >= self._APP_INTF_BYTES_PER_CYCLE
            if msg_fifo_write_ready and not self._msg_fifo_packer_flushing:
                nbytes = min(len(self._app_intf_fifo), self._APP_INTF_BYTES_PER_CYCLE)
                last_byte_valid = self._msg_size % 8
                kmac_debug_print(f"MSG Size: {self._msg_size}")
                if (last_byte_valid == 0):
                    last_byte_valid = 8

                if len(self._app_intf_fifo) < last_byte_valid:
                    padding_size = last_byte_valid - nbytes
                    self._app_intf_fifo += bytes(padding_size)

                nbytes = last_byte_valid

                self._msg_fifo += self._app_intf_fifo[:nbytes]
                self._app_intf_fifo = bytes()
                self._app_intf_bytes_sent += nbytes
                # Artificially change the msg size
                self._msg_size = self._app_intf_bytes_sent
                self._msg_len = 0
                self._app_intf_sending = True

                self._kmac_undersized_err = digest_err
                kmac_debug_print("Inserting Artificial Last MSG")
                self.message_done()
                self._app_intf_last = True

        if self._automatically_write_digest:
            if self._digest_ready:
                self._digest_read = True
                self._automatically_write_digest = False
                return True
            else:
                return False
        elif self._shift_digest_reg or self._new_permutation:
            return False
        elif self._digest_read:
            self._digest_read = False
            if self._rate_bytes > self._read_offset + 32:
                self._shift_digest_reg = True
            elif self._leftover_digest_bytes + self._rate_bytes - self._read_offset >= 32:
                # Even if we can not directly get 32 bytes without
                # a new permutation, we have n leftover bytes
                # (8 for SHAKE128/256). Therefore after 4 permutations
                # we have 32 bytes available without a new permutation.
                self._leftover_digest_bytes = 0
                self._shift_digest_reg = True
                # For the next squeeze request, we do not have the latency
                # for shifting the remaining bits from the state.
                self._skip_digest_shift_cycle = True
            else:
                self._new_permutation = True
                self._leftover_digest_bytes += max(self._rate_bytes - self._read_offset, 0)
                self._read_offset = 0
            self._digest_ready_next = False
            return False
        elif self._digest_ready:
            self._digest_read = True
            return True
        else:
            return False

    def start(self) -> None:
        '''Starts a hashing operation.'''
        if not self.is_idle():
            raise ValueError('KMAC: Cannot issue `start` command in '
                             f'{self._status} status.')
        self._status = self._STATUS_ABSORB
        self._msg_fifo_flush_ctr = 0

        if self._mode == self._MODE_SHA3:
            if self._strength == self._STRENGTH_128:
                raise ValueError(f'KMAC: Invalid config: \
                                 mode = {self._mode} and \
                                 strength = {self._strength}')
            elif self._strength == self._STRENGTH_224:
                self._state = SHA3_224.new()
                self._rate_bytes = (1600 - (224 * 2)) // 8
            elif self._strength == self._STRENGTH_256:
                self._state = SHA3_256.new()
                self._rate_bytes = (1600 - (256 * 2)) // 8
            elif self._strength == self._STRENGTH_384:
                self._state = SHA3_384.new()
                self._rate_bytes = (1600 - (384 * 2)) // 8
            elif self._strength == self._STRENGTH_512:
                self._state = SHA3_512.new()
                self._rate_bytes = (1600 - (512 * 2)) // 8
        elif self._mode == self._MODE_SHAKE:
            if self._strength == self._STRENGTH_128:
                self._state = SHAKE128.new()
                self._rate_bytes = (1600 - (128 * 2)) // 8
            elif self._strength == self._STRENGTH_256:
                self._state = SHAKE256.new()
                self._rate_bytes = (1600 - (256 * 2)) // 8
            else:
                raise ValueError(f'KMAC: Invalid config: \
                                 mode = {self._mode} and \
                                 strength = {self._strength}')
        elif self._mode == self._MODE_CSHAKE:
            if self._strength == self._STRENGTH_128:
                self._state = cSHAKE128.new()
                self._rate_bytes = (1600 - (128 * 2)) // 8
            elif self._strength == self._STRENGTH_256:
                self._state = cSHAKE256.new()
                self._rate_bytes = (1600 - (256 * 2)) // 8
            else:
                raise ValueError(f'KMAC: Invalid config: \
                                 mode = {self._mode} and \
                                 strength = {self._strength}')

        # Important assumption: since we send data to the core in fixed-size
        # chunks, we need to make sure the chunk size divides the rate.
        assert self._rate_bytes % self._MSG_FIFO_ABSORB_BYTES_PER_CYCLE == 0

    def msg_fifo_bytes_available(self) -> int:
        return self._MSG_FIFO_SIZE_BYTES + self._MSG_PACKER_SIZE_BYTES - len(self._msg_fifo)

    def app_intf_fifo_bytes_available(self) -> int:
        return self._APP_INTF_FIFO_SIZE_BYTES - len(self._app_intf_fifo)

    def app_intf_fifo_ready(self) -> bool:
        # If the AppIntf FIFO is ready and the current size of the contents is less than or equal
        # to 8B we can absorb
        # FIFO size is 64B allowing for a full length word even if there is 8B or less
        return (
            self._app_intf_fifo_ready
            and len(self._app_intf_fifo) <= self._APP_INTF_BYTES_PER_CYCLE
        )

    def write_to_app_intf_fifo(self, msg: bytes) -> bool:
        '''Appends new message data to an ongoing hashing operation.

        Check `app_intf_fifo_bytes_available` to ensure there is enough space
        in the FIFO before attempting to write.
        '''
        if not self.is_absorbing():
            raise ValueError(f'KMAC: Cannot write in {self._status} status.')
        kmac_debug_print(f"\tAttempting write to App FIFO: \
                        ready = {self.app_intf_fifo_ready()}, \
                        fifo len = {len(self._app_intf_fifo)}")
        # If there is more than 8B we can not yet write
        if (
            not self.app_intf_fifo_ready()
            or len(self._app_intf_fifo) > self._APP_INTF_BYTES_PER_CYCLE
        ):
            return False
        self._app_intf_fifo += msg
        return True

    def _start_keccak_core(self, absorbed) -> None:
        kmac_debug_print("\tStarting round logic")
        if absorbed:
            self._core_cycles_remaining = self._KECCAK_NUM_ROUNDS * \
                self._KECCAK_CYCLES_PER_ROUND + \
                self._KECCAK_LATENCY_DIGEST_EXPOSED
            kmac_debug_print(f"In Absorbed | remaining_cycles = {self._core_cycles_remaining}")
        else:
            self._core_cycles_remaining = self._KECCAK_NUM_ROUNDS * \
                self._KECCAK_CYCLES_PER_ROUND + self._KECCAK_LATENCY_DONE
            kmac_debug_print(f"Not Absorbed | remaining_cycles = {self._core_cycles_remaining}")

    def _core_is_busy(self) -> None:
        return self._core_cycles_remaining is not None and self._core_cycles_remaining > 0

    def _core_can_absorb(self) -> None:
        # With _core_cycles_remaining we count the cycles for the Keccak round logic and
        # additional cycles for the application interface to propagate the digest. The core
        # is able to absorb new data into its state one cycle before the counter hits zero.
        return self._core_cycles_remaining is None or self._core_cycles_remaining <= 2

    def _process(self) -> None:
        '''Issues a `process` command to the KMAC block.

        Signals to the hardware that the message is done and it should compute
        a digest. The amount of digest computed depends on the rate of the
        Keccak function instantiated (1600 - capacity, e.g. 1344 bits for
        SHAKE128).
        '''
        if not self.is_absorbing():
            raise ValueError('KMAC: Cannot issue `process` command in '
                             f'{self._status} status.')
        kmac_debug_print("\tKMAC START PROCESS")
        self._status = self._STATUS_SQUEEZE
        self._start_keccak_core(True)

    def run(self) -> None:
        '''Issues a `run` command to the KMAC block.

        This command should be issued if additional digest data, beyond the
        Keccak rate, is needed. It runs the Keccak core again to generate new
        digest material. The state buffer is invalid until the core computation
        is complete; the caller needs to read the previous digest before
        calling run().
        '''
        if not self.is_squeezing():
            raise ValueError('KMAC: Cannot issue `run` command in '
                             f'{self._status} status.')
        kmac_debug_print("\tKMAC RUN PROCESS")
        self._start_keccak_core(True)
        self._read_offset = 0

    def done(self) -> None:
        '''Finishes a hashing operation.'''
        if not self.is_squeezing():
            raise ValueError('KMAC: Cannot issue `done` command in '
                             f'{self._status} status.')
        self._status = self._STATUS_IDLE
        self._cycles_until_ready = None
        self._state = None
        self._reset()

    def step(self) -> None:
        if self.is_idle():
            return

        kmac_debug_print(f"CYCLE - Stepping KMAC, \
                        remaining_cycles = {self._core_cycles_remaining}, \
                        core_pending_bytes = {self._core_pending_bytes}, \
                        available = {self._rate_bytes - self._core_pending_bytes} \
                        pending_process = {self._pending_process}, \
                        digest_req_ctr = {self._digest_request_ctr}, \
                        MSG FIFO SIZE = {len(self._msg_fifo)}")

        if self._app_intf_ready_pending_ctr is not None:
            self._app_intf_ready_pending_ctr += 1
            if self._app_intf_ready_pending_ctr == self._APP_INTF_READY_LATENCY:
                kmac_debug_print("\tKMAC App Iface Ready")
                self._app_intf_ready = True
                self._app_intf_ready_pending_ctr = None

        kmac_debug_print(f"Last Latch: {self._app_intf_last_latch} \
                        | Msg Len: {self._msg_len} \
                        | AppIntf Size: {len(self._app_intf_fifo)} \
                        | Ready Next: {self._app_intf_fifo_ready_next}")

        kmac_debug_print(f"Pending LAST Status: {self._pending_app_intf_last}")

        # MSG FIFO -> KECCAK STATE
        self._core_pending_bytes = self._core_pending_bytes_next
        core_available = self._rate_bytes - self._core_pending_bytes
        absorb_rate = self._MSG_FIFO_ABSORB_BYTES_PER_CYCLE
        # We determine if the message fifo has space before it writes to the
        # Keccak state to model the actual hardware.
        # If the FIFO is full, it can only be written in the next cycle.
        msg_fifo_write_ready = self.msg_fifo_bytes_available() >= self._APP_INTF_BYTES_PER_CYCLE
        if core_available >= 1 and self._core_can_absorb():
            if self._msg_fifo_flush:
                kmac_debug_print(f"\tIncrementing MSG FIFO FLUSH CTR: \
                                {self._msg_fifo_flush_ctr} -> {self._msg_fifo_flush_ctr + 1}")
                self._msg_fifo_flush_ctr += 1
            if len(self._msg_fifo) >= absorb_rate:
                kmac_debug_print(f"\tMSG FIFO -> STATE: Absorbing 64-bit: \
                          {self._msg_fifo[:absorb_rate][::-1].hex()}")
                # Absorb a new chunk of the message.
                self._core_pending_bytes_next = self._core_pending_bytes + absorb_rate
                self._state.update(self._msg_fifo[:absorb_rate])
                self._msg_fifo = self._msg_fifo[absorb_rate:]
            elif self._pending_process:
                # Push the remainder of the message (if present) plus some
                # padding. We model the timing of pushing the padding but not
                # the padding itself, since the SHA3 library does that for us.
                if len(self._msg_fifo) > 0:
                    # Model flushing the message fifo: If we have non-word-length data
                    # in the packer, we need two flush cycles for the packer and one
                    # for the fifo. If we only have word-length data, we need one cycle
                    # for the packer and one for the fifo. If we get the flush signal
                    # before the last word is absorbed, the flushing of the packer is
                    # "hidden" and we only have one additional cycle of effective delay
                    # for flusing the fifo.
                    if self._msg_fifo_flush_ctr > 0:
                        kmac_debug_print(f"\tMSG FIFO -> STATE: \
                                  Absorbing last data (smaller than word): \
                                  {self._msg_fifo[:absorb_rate][::-1].hex()}, \
                                  flush_ctr = {self._msg_fifo_flush_ctr}")
                        # model cycle for consuming the last data
                        self._state.update(self._msg_fifo)
                        self._core_pending_bytes_next = \
                            self._core_pending_bytes + len(self._msg_fifo)
                        self._msg_fifo = bytes()
                elif not self._msg_fifo_packer_flushed and self._msg_fifo_flush_ctr <= 2 \
                        and not self._padding_only:
                    kmac_debug_print("\tFlushing MSG FIFO PACKER")
                    self._msg_fifo_packer_flushed = True
                elif not self._msg_fifo_flushed and not self._padding_only:
                    kmac_debug_print("\tFlushing MSG FIFO")
                    self._msg_fifo_flushed = True
                elif self._core_pending_bytes < self._rate_bytes and not self._core_is_busy():
                    # model padding cycles
                    self._padded = True
                    self._msg_fifo_flush = False
                    padding_len = absorb_rate - (self._core_pending_bytes % 8)
                    self._core_pending_bytes_next = self._core_pending_bytes + padding_len
                    kmac_debug_print(f"\tApply Padding with Len {padding_len}")

        # APP FIFO -> MSG FIFO
        self._msg_fifo_flush = self._pending_process
        kmac_debug_print(f"\tSetting MSG Fifo Flush to Pending Process: {self._msg_fifo_flush}")
        if self._app_intf_last:
            self._app_intf_ready = False

        # The fifo will be ready in the next clock cycle if there is 8B or less
        if len(self._app_intf_fifo) <= self._APP_INTF_BYTES_PER_CYCLE:
            kmac_debug_print("\tAPP INTF FIFO LESS THAN ONE WORD IN NEXT STEP")
            self._app_intf_fifo_ready_next = True
        else:
            self._app_intf_fifo_ready_next = False

        # Set Latch for error detection
        if (self._app_intf_bytes_sent == self._msg_size):
            self._app_intf_last_latch = True

        self._app_intf_sending = False
        if msg_fifo_write_ready and not self._msg_fifo_packer_flushing and self._app_intf_ready:
            # Pass data from the application interface FIFO to the message FIFO.
            nbytes = min(len(self._app_intf_fifo), self._APP_INTF_BYTES_PER_CYCLE, self._msg_len)
            if nbytes >= self._APP_INTF_BYTES_PER_CYCLE:
                kmac_debug_print(f"\tAPP FIFO -> MSG FIFO: Absorbing {nbytes} \
                            bytes: \
                            {hex(int.from_bytes(self._app_intf_fifo[:nbytes], 'little'))}, \
                            size of contents in MSG FIFO before new data: {len(self._msg_fifo)}")
                self._msg_fifo += self._app_intf_fifo[:nbytes]
                self._app_intf_fifo = self._app_intf_fifo[nbytes:]
                self._msg_len -= nbytes
                self._app_intf_bytes_sent += nbytes
                self._app_intf_sending = True

            elif (self._app_intf_fifo_flush and nbytes < self._APP_INTF_BYTES_PER_CYCLE):
                kmac_debug_print(f"\tAPP FIFO -> MSG FIFO: Absorbing {nbytes} \
                            bytes: \
                            {hex(int.from_bytes(self._app_intf_fifo[:nbytes], 'little'))}, \
                            size of contents in MSG FIFO before new data: {len(self._msg_fifo)}")
                self._msg_fifo += self._app_intf_fifo[:nbytes]
                self._app_intf_fifo = self._app_intf_fifo[nbytes:]
                self._msg_len -= nbytes
                self._app_intf_bytes_sent += nbytes
                self._app_intf_fifo_flush = False
                self._app_intf_sending = True

            # Flushing the APP FIFO has an extra clock cycle to read
            elif (
                self._msg_len < self._APP_INTF_BYTES_PER_CYCLE
                and self._msg_len != 0
                and len(self._app_intf_fifo) >= self._msg_len
            ):
                if (len(self._app_intf_fifo) < 8):
                    # Flushing the APP FIFO has an extra clock cycle to read
                    self._app_intf_fifo_flush = True
                else:
                    # This is an oversized message and has filled the next
                    # word therefore no etra flush cycle
                    self._msg_fifo += self._app_intf_fifo[:nbytes]
                    self._app_intf_fifo = self._app_intf_fifo[8:]
                    self._msg_len -= nbytes
                    self._app_intf_bytes_sent += nbytes
                    self._app_intf_sending = True

            kmac_debug_print(f"\tMSG FIFO SIZE: {len(self._msg_fifo)}")
        else:
            # Once the FIFO fills up completely, the packer must flush completely until it can
            # consume new data.
            if self._msg_fifo_packer_flush_ctr == 0:
                self._msg_fifo_packer_flushing = True
            if core_available >= absorb_rate and self._core_can_absorb():
                self._msg_fifo_packer_flush_ctr += 1
            if self._msg_fifo_packer_flush_ctr == self._MSG_FIFO_PACKER_FLUSH_LATENCY:
                self._msg_fifo_packer_flushing = False
                self._msg_fifo_packer_flush_ctr = 0
            kmac_debug_print(f"\tMSG FIFO FULL, flush ctr = {self._msg_fifo_packer_flush_ctr}")
        if self._msg_len == 0 and not self._app_intf_last:
            kmac_debug_print("\tAPP FIFO last")
            self.message_done()
            self._app_intf_last = True

        self._app_intf_fifo_ready = self._app_intf_fifo_ready_next

        # Digest Register
        self._digest_ready = self._digest_ready_next
        if self._shift_digest_reg:
            if self._digest_request_ctr < self._SHIFT_DIGEST_LATENCY:
                self._digest_request_ctr += 1
                self._digest_ready_next = False
            else:
                self._shift_digest_reg = False
                self._digest_request_ctr = 0
                self._digest_ready_next = True
        elif self._new_permutation:
            if self._digest_request_ctr < self._NEW_PERMUTATION_LATENCY:
                if self._skip_digest_shift_cycle:
                    self._skip_digest_shift_cycle = False
                    # model the one cycle the next permutation is faster
                    # if we do not need to squeeze remaining bits from
                    # the digest
                    self._digest_request_ctr += 1
                self._digest_request_ctr += 1
                self._digest_ready_next = False
            else:
                self._new_permutation = False
                self._digest_request_ctr = 0
                self._digest_ready_next = True
        else:
            self._digest_ready_next = self.is_squeezing() and (self._core_cycles_remaining == 0)

        # Either step the core or check if we can start it.
        if self._core_is_busy():
            self._core_cycles_remaining -= 1
            kmac_debug_print("\tProcessing")
        elif self._core_pending_bytes == self._rate_bytes:
            self._start_keccak_core(False)
            self._core_pending_bytes = 0
            self._core_pending_bytes_next = 0
            if self._pending_process and not self._msg_fifo and not self._padded:
                # We need an extra Keccak permutation for the padding, but no delay for flushing
                # the message fifo is needed.
                self._padding_only = True
            if self._pending_process and not self._msg_fifo and self._padded:
                kmac_debug_print("\tStarting processing")
                # Just finished padding; send the process command.
                self._process()
                self._pending_process = False
                self._msg_fifo_flush_ctr = 0
                self._msg_fifo_flushed = False
                self._msg_fifo_packer_flushed = False

        # The following check determines if there is an oversized message and will flush the
        # remaining bytes to avoid stalling while setting the error flag high
        if (
            self._app_intf_last_latch
            and self._app_intf_bytes_sent >= self._msg_size
            and len(self._app_intf_fifo) > 0
        ):
            self._pending_app_intf_last = False
            nbytes = min(len(self._app_intf_fifo), self._APP_INTF_BYTES_PER_CYCLE)
            self._app_intf_fifo = self._app_intf_fifo[nbytes:]
            self._kmac_oversized_err = True
            kmac_debug_print("FLUSHING FIFO WITH OVERSIZED MSG")

            # The fifo will be ready in the next clock cycle if there is 8B or less
            if len(self._app_intf_fifo) <= self._APP_INTF_BYTES_PER_CYCLE:
                kmac_debug_print("\tAPP INTF FIFO LESS THAN ONE WORD IN NEXT STEP")
                self._app_intf_fifo_ready_next = True
            else:
                self._app_intf_fifo_ready_next = False

        if self._pending_app_intf_last and len(self._app_intf_fifo) > self._msg_len:
            self._app_intf_fifo = self._app_intf_fifo[:self._msg_len]
            self._kmac_oversized_err = True
            kmac_debug_print("FLUSHING FIFO WITH OVERSIZED MSG")

        if (
            self._msg_len <= len(self._app_intf_fifo)
            and self._msg_len <= self._APP_INTF_BYTES_PER_CYCLE
            and len(self._app_intf_fifo) <= self._APP_INTF_BYTES_PER_CYCLE
        ):
            self._pending_app_intf_last = True
        else:
            self._pending_app_intf_last = False

    def max_read_bytes(self) -> int:
        '''Returns the maximum readable bytes before a `run` command.'''
        # SHA3
        if self._mode == self._MODE_SHA3:
            if self._strength == self._STRENGTH_512:
                return 64 - self._read_offset
            elif self._strength == self._STRENGTH_256:
                return 32 - self._read_offset
        # XOFs
        return None

    def read(self, num_bytes: int) -> bytes:
        if self.max_read_bytes() is not None and num_bytes > self.max_read_bytes():
            raise ValueError('KMAC: Read request exceeds Keccak rate.')
        if self._mode == self._MODE_SHAKE or self._mode == self._MODE_CSHAKE:
            # XOFs SHAKE and CSHAKE
            self._read_offset += num_bytes
            ret = self._state.read(num_bytes)
        else:
            # SHA3
            ret = self._state.digest()[self._read_offset: self._read_offset + num_bytes]
            self._read_offset += num_bytes
        return ret


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
        self._kmac.step()
        self._kmac._app_intf_writing = False
        kmac_debug_print("\tFETCHING STARTING FIFO STATUS")
        self._pending_write_stall_pw = self._pending_write_to_app_intf
        self._start_cycle_fifo_ready = self._kmac.app_intf_fifo_ready()
        # KMAC_MSG reg -> FIFO
        if self._pending_write_to_app_intf:
            strb_len = self._partial_ispr.read_mask()
            value_bytes = int.to_bytes(self._value, byteorder='little', length=32)[:strb_len]
            kmac_debug_print("\tPending write to App FIFO")
            if (
                self._kmac._app_intf_last_latch
                or (self._kmac._pending_app_intf_last and not self.pending_write())
                or self._kmac._app_intf_fifo_flush
            ):
                kmac_debug_print("DROPPING WRITE TO FIFO FROM OVERSIZED MSG")
                self._pending_write_to_app_intf = False
                self._pending_write_stall_pw = False
            elif not self._kmac._app_intf_last and self._kmac.write_to_app_intf_fifo(value_bytes):
                kmac_debug_print(f"\tKMAC_MSG -> APP FIFO: Writing \
                                 {len(value_bytes)} bytes to App FIFO")
                self._pending_write_to_app_intf = False
                self._kmac._app_intf_writing = True

    def pending_write(self) -> bool:
        return self._pending_write_stall_pw or self._kmac._app_intf_fifo_flush

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
    def __init__(self, ext_regs: OTBNExtRegs) -> None:
        self.KeyS0 = SideloadKey('KeyS0')
        self.KeyS1 = SideloadKey('KeyS1')
        self.Kmac = KmacBlock()

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

        self._by_idx = {
            0: self.MOD,
            1: self.RND,
            2: self.URND,
            3: self.ACC,
            4: self.KeyS0L,
            5: self.KeyS0H,
            6: self.KeyS1L,
            7: self.KeyS1H,
            8: self.KMAC_CFG,
            9: self.KMAC_MSG,
            10: self.KMAC_DIGEST,
            11: self.ACCH,
        }

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
        if OTBN_PQC:
            ret += self.ACCH.changes()
        ret += self.KeyS0.changes()
        ret += self.KeyS1.changes()
        if OTBN_PQC:
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
