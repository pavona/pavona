# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
This contains a class to access the otp_ctrl's configuration from its ipconfig
files.
"""
from typing import List, Dict

from topgen.lib import Name


class OtpCtrlIpConfig:
    def __init__(self, ipconfig: object, id_prefix: Name):
        """
        Initialize an `IpConfig` from an already loaded and parsed `ipconfig.hjson`
        file, as well as a top configuration. The `id_prefix` argument defines the
        prefix to be used for partition identifiers.
        """
        self._param_values = ipconfig["param_values"]
        self._id_prefix = id_prefix

    def sw_readable(self, partition) -> bool:
        """
        Returns true iff a partition should be marked as software-readable.
        """
        if partition.get("read_lock") not in ["CSR", "None"]:
            return False
        if partition.get("secret"):
            return False
        if not partition.get("sw_digest") and not partition.get("hw_digest"):
            return False
        return True

    def partitions(self) -> List[Dict]:
        """
        Return the list of all OTP partitions.
        """
        return [
            {
                "name": Name.from_snake_case(partition["name"]),
                "id": self._id_prefix + Name.from_snake_case(partition["name"]),
                "variant": partition["variant"],
                "secret": partition["secret"],
                "sw_readable": self.sw_readable(partition),
                "sw_digest": partition["sw_digest"],
                "hw_digest": partition["hw_digest"],
                "read_lock": partition["read_lock"],
                "zeroizable": partition["zeroizable"],
            }
            for partition in self._param_values["otp_mmap"]["partitions"]
        ]
