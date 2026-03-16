# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of
# "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN"
# (https://eprint.iacr.org/2025/2028)
# Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham.

import sys
from typing import Optional, Union
from Crypto.Hash import cSHAKE128, cSHAKE256, SHAKE128, SHAKE256, SHA3_224, \
    SHA3_256, SHA3_384, SHA3_512
DEBUG_KMAC = False


def kmac_debug_print(text: str) -> None:
    if DEBUG_KMAC:
        print(text, file=sys.stderr)


class KmacBlock:
    '''Emulates the KMAC hardware interface.'''
    _CMD_START = 0x1d
    _CMD_PROCESS = 0x2e
    _CMD_RUN = 0x31
    _CMD_DONE = 0x16
    _STATUS_IDLE = 'IDLE'
    _STATUS_ABSORB = 'ABSORB'
    _STATUS_SQUEEZE = 'SQUEEZE'
    # The following MODE and STRENGTH values are mapped to their corresponding enums in
    # `hw/ip/kmac/rtl/kmac_pkg.sv`. This is required to do any hardware simulation that
    # uses the real KMAC IP and accsim.
    _MODE_SHA3 = 0x0
    _MODE_SHAKE = 0x2
    _MODE_CSHAKE = 0x3
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

    # FIFO within ACC that waits to send message data over the application
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

    # Set valid typing
    _state: Union[SHA3_224.SHA3_224_Hash, SHA3_256.SHA3_256_Hash, SHA3_384.SHA3_384_Hash,
                  SHA3_512.SHA3_512_Hash, cSHAKE128.cSHAKE_XOF, SHAKE128.SHAKE128_XOF,
                  SHAKE256.SHAKE256_XOF, None] = None

    def __init__(self) -> None:
        self._reset()
        self._status = self._STATUS_IDLE
        self._core_cycles_remaining: Optional[int] = None
        self._mode = self._MODE_SHA3
        self._strength = self._STRENGTH_128
        self._read_offset = 0
        self._padded = False
        self._padding_only = False
        self._app_intf_ready = False
        self._app_intf_ready_pending_ctr: Optional[int] = None
        self._app_intf_fifo_ready = True
        self._app_intf_fifo_ready_next = True
        self._app_intf_fifo_flush = False
        self._app_fifo_after_flush = False
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
        self._rate_bytes = 0
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
        self._app_fifo_after_flush = False
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
        self._app_fifo_after_flush = False
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
        # When the FIFO is flushing it is illegal to write to
        if (
            not self.app_intf_fifo_ready()
            or len(self._app_intf_fifo) > self._APP_INTF_BYTES_PER_CYCLE
            or self._app_intf_fifo_flush
        ):
            return False
        self._app_intf_fifo += msg
        return True

    def _start_keccak_core(self, absorbed: bool) -> None:
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

    def _core_is_busy(self) -> bool:
        return self._core_cycles_remaining is not None and self._core_cycles_remaining > 0

    def _core_can_absorb(self) -> bool:
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
                if self._state is None:
                    raise ValueError("KMAC: Hash state not initialized")
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
                        if self._state is None:
                            raise ValueError("KMAC: Hash state not initialized")
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
                self._app_fifo_after_flush = True
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
                    kmac_debug_print("FLUSHING APP INTF")
                else:
                    # This is an oversized message and has filled the next
                    # word therefore no etra flush cycle
                    self._msg_fifo += self._app_intf_fifo[:nbytes]
                    self._app_intf_fifo = self._app_intf_fifo[8:]
                    self._msg_len -= nbytes
                    self._app_intf_bytes_sent += nbytes
                    self._app_intf_sending = True
                    self._kmac_oversized_err = True

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

        if (
            self._digest_read and self._digest_ready
            and not self._shift_digest_reg and not self._new_permutation
        ):
            # If we have read the digest then set ready to False as well for proper status sampling
            self._digest_read = False
            self._digest_ready = False
            if self._rate_bytes > self._read_offset + 32:
                self._shift_digest_reg = True
                self._digest_request_ctr += 1
            elif self._leftover_digest_bytes + self._rate_bytes - self._read_offset >= 32:
                # Even if we can not directly get 32 bytes without
                # a new permutation, we have n leftover bytes
                # (8 for SHAKE128/256). Therefore after 4 permutations
                # we have 32 bytes available without a new permutation.
                self._leftover_digest_bytes = 0
                self._shift_digest_reg = True
                self._digest_request_ctr += 1
                # For the next squeeze request, we do not have the latency
                # for shifting the remaining bits from the state.
                self._skip_digest_shift_cycle = True
            else:
                if self._mode in [self._MODE_SHAKE, self. _MODE_CSHAKE]:
                    # For XOF modes, eagerly trigger a new permutation.
                    self._new_permutation = True
                    self._digest_request_ctr += 1
                    self._leftover_digest_bytes += max(self._rate_bytes - self._read_offset, 0)
                    self._read_offset = 0
            self._digest_ready_next = False

        # Either step the core or check if we can start it.
        if self._core_is_busy():
            if self._core_cycles_remaining is not None:
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

    def max_read_bytes(self) -> Optional[int]:
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
        if self._state is None:
            raise ValueError("KMAC: Hash state not initialized")
        max_bytes = self.max_read_bytes()
        if max_bytes is not None and num_bytes > max_bytes:
            raise ValueError('KMAC: Read request exceeds Keccak rate.')
        if self._mode == self._MODE_SHAKE or self._mode == self._MODE_CSHAKE:
            # XOFs SHAKE and CSHAKE
            self._read_offset += num_bytes
            if hasattr(self._state, "read"):
                ret = self._state.read(num_bytes)
        else:
            # SHA3
            if hasattr(self._state, "digest"):
                ret = self._state.digest()[self._read_offset: self._read_offset + num_bytes]
            self._read_offset += num_bytes
        return ret
