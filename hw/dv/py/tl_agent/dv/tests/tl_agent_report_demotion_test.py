# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Integration test for pyuvm report severity changes."""

from pyuvm import UVM_ERROR, UVM_INFO, UVM_LOW

from .tl_agent_base_test import tl_agent_base_test


class tl_agent_report_demotion_test(tl_agent_base_test):
    """Prove that a selected error is demoted without hiding other errors."""

    REPORT_ID = "TL_KNOWN_ISSUE"
    REPORT_MESSAGE = "known protocol issue is waived by this test"

    def add_message_demotes(self, catcher):
        super().add_message_demotes(catcher)
        self.demotion_catcher = catcher
        catcher.add_change_sev(self.REPORT_ID, r"known protocol issue",
                               UVM_INFO)

    async def run_phase(self):
        _, matched_severity = self.demotion_catcher.catch_fields(
            self.REPORT_ID,
            self.REPORT_MESSAGE,
            UVM_ERROR,
        )
        _, unmatched_severity = self.demotion_catcher.catch_fields(
            "TL_UNMATCHED_ISSUE",
            self.REPORT_MESSAGE,
            UVM_ERROR,
        )
        assert matched_severity == UVM_INFO
        assert unmatched_severity == UVM_ERROR

        report_server = self._get_report_server()
        stats = report_server.get_stats()
        info_before = stats.info_count
        error_before = stats.error_count

        self.uvm_report.error(self.REPORT_ID, self.REPORT_MESSAGE)

        assert stats.info_count == info_before + 1
        assert stats.error_count == error_before
        self.uvm_report.info(
            "TL_REPORT_DEMOTION_TEST",
            "verified UVM_ERROR to UVM_INFO severity change",
            UVM_LOW,
        )

        await super().run_phase()
