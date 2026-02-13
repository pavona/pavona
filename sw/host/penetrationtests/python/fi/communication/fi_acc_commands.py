# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Communication interface for OpenTitan ACC FI framework.

Communication with OpenTitan happens over the uJSON command interface.
"""
import json
import time
from sw.host.penetrationtests.python.util import common_library


class OTFIAcc:
    def __init__(self, target) -> None:
        self.target = target

    def _ujson_acc_fi_cmd(self) -> None:
        self.target.write(json.dumps("AccFi").encode("ascii"))
        time.sleep(0.003)

    def acc_char_dmem_access(self) -> None:
        """Starts the acc.fi.char.dmem.access test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # CharDmemAccess command.
        self.target.write(json.dumps("CharDmemAccess").encode("ascii"))

    def acc_char_dmem_write(self) -> None:
        """Starts the acc.fi.char.dmem.write test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # CharDmemWrite command.
        self.target.write(json.dumps("CharDmemWrite").encode("ascii"))

    def acc_char_rf(self) -> None:
        """Starts the acc.fi.char.rf test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # CharRF command.
        self.target.write(json.dumps("CharRF").encode("ascii"))

    def acc_char_beq(self) -> None:
        """Starts the acc.fi.char.beq test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # CharBeq command.
        self.target.write(json.dumps("CharBeq").encode("ascii"))

    def acc_char_jal(self) -> None:
        """Starts the acc.fi.char.jal test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # CharJal command.
        self.target.write(json.dumps("CharJal").encode("ascii"))

    def acc_char_mem(self, byte_offset, num_words, imem, dmem, first_call) -> None:
        """Starts the acc.fi.char.mem test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # CharMem command.
        self.target.write(json.dumps("CharMem").encode("ascii"))
        if first_call:
            parameters = {
                "byte_offset": byte_offset,
                "num_words": num_words,
                "imem": imem,
                "dmem": dmem,
            }
            self.target.write(json.dumps(parameters).encode("ascii"))

    def acc_char_bn_sel(self, data) -> None:
        """Starts the acc.fi.char.bn.sel test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # CharBnSel command.
        self.target.write(json.dumps("CharBnSel").encode("ascii"))
        parameters = {"big_num": data}
        self.target.write(json.dumps(parameters).encode("ascii"))

    def acc_char_bne(self) -> None:
        """Starts the acc.fi.char.bne test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # CharBne command.
        self.target.write(json.dumps("CharBne").encode("ascii"))

    def acc_char_bn_rshi(self, data) -> None:
        """Starts the acc.fi.char.bn.rshi test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # CharBnRshi command.
        self.target.write(json.dumps("CharBnRshi").encode("ascii"))
        parameters = {"big_num": data}
        self.target.write(json.dumps(parameters).encode("ascii"))

    def acc_char_bn_wsrr(self) -> None:
        """Starts the acc.fi.char.bn.wsrr test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # CharBnWsrr command.
        self.target.write(json.dumps("CharBnWsrr").encode("ascii"))

    def acc_char_lw(self) -> None:
        """Starts the acc.fi.char.lw test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # CharLw command.
        self.target.write(json.dumps("CharLw").encode("ascii"))

    def acc_char_unrolled_reg_op_loop(self) -> None:
        """Starts the acc.fi.char.unrolled.reg.op.loop test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # CharUnrolledRegOpLoop command.
        self.target.write(json.dumps("CharUnrolledRegOpLoop").encode("ascii"))

    def acc_char_unrolled_dmem_op_loop(self) -> None:
        """Starts the acc.fi.char.unrolled.dmem.op.loop test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # CharUnrolledDmemOpLoop command.
        self.target.write(json.dumps("CharUnrolledDmemOpLoop").encode("ascii"))

    def acc_char_hardware_reg_op_loop(self) -> None:
        """Starts the acc.fi.char.hardware.reg.op.loop test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # CharHardwareRegOpLoop command.
        self.target.write(json.dumps("CharHardwareRegOpLoop").encode("ascii"))

    def acc_char_hardware_dmem_op_loop(self) -> None:
        """Starts the acc.fi.char.hardware.dmem.op.loop test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # CharMemOpLoop command.
        self.target.write(json.dumps("CharHardwareDmemOpLoop").encode("ascii"))

    def acc_key_sideload(self) -> None:
        """Starts the acc.fi.key_sideload test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # KeySideload command.
        self.target.write(json.dumps("KeySideload").encode("ascii"))

    def acc_load_integrity(self) -> None:
        """Starts the acc.fi.load_integrity test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # LoadIntegrity command.
        self.target.write(json.dumps("LoadIntegrity").encode("ascii"))

    def acc_pc(self, pc) -> None:
        """Starts the acc.pc test."""
        # AccFi command.
        self._ujson_acc_fi_cmd()
        # PC command.
        self.target.write(json.dumps("PC").encode("ascii"))
        parameters = {"pc": pc}
        self.target.write(json.dumps(parameters).encode("ascii"))

    def init_keymgr(self, test: str) -> None:
        """Initialize the key manager on the chip.
        Args:
            test: Name of the test. Used to determine if key manager init is
                  needed.
        """
        if "key_sideload" in test:
            # AccFi command.
            self._ujson_acc_fi_cmd()
            # InitTrigger command.
            self.target.write(json.dumps("InitKeyMgr").encode("ascii"))

    def init(
        self,
        core_config: dict = common_library.default_core_config,
        sensor_config: dict = common_library.default_sensor_config,
        alert_config: dict = common_library.default_alert_config,
    ) -> tuple:
        """Initialize the ACC FI code on the chip.

        Returns:
            Device id
            The sensor control config
            The alert config
            The owner page
            The boot log
            The boot measurements
            The testOS version
        """

        # AccFi command.
        self._ujson_acc_fi_cmd()
        # Init command.
        self.target.write(json.dumps("Init").encode("ascii"))

        # Write each configuration block to the target.
        self.target.write(json.dumps(core_config).encode("ascii"))
        self.target.write(json.dumps(sensor_config).encode("ascii"))
        self.target.write(json.dumps(alert_config).encode("ascii"))

        device_id = self.target.read_response()
        sensors = self.target.read_response()
        alerts = self.target.read_response()
        owner_page = self.target.read_response()
        boot_log = self.target.read_response()
        boot_measurements = self.target.read_response()
        version = self.target.read_response()
        return (
            device_id,
            sensors,
            alerts,
            owner_page,
            boot_log,
            boot_measurements,
            version,
        )

    def start_test(self, cfg: dict) -> None:
        """Start the selected test.

        Call the function selected in the config file. Uses the getattr()
        construct to call the function.

        Args:
            cfg: Config dict containing the selected test.
        """
        test_function = getattr(self, cfg["test"]["which_test"])
        test_function()

    def write_payload(self, payload: dict) -> None:
        """Send test payload to OpenTitan.
        Args:
            payload: The data to send to the target.
        """
        self.target.write(json.dumps(payload).encode("ascii"))
