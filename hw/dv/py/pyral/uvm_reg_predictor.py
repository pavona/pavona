# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Predictor scaffold."""

from __future__ import annotations

from .uvm_reg_item import uvm_reg_item


class uvm_reg_predictor:
    """Generic predictor API for monitor-driven mirroring."""

    def __init__(self, name: str = "uvm_reg_predictor"):
        self.name = name
        self.map = None
        self.adapter = None

    def configure(self, reg_map=None, adapter=None) -> None:
        self.map = reg_map
        self.adapter = adapter

    def predict(self, rw: uvm_reg_item):
        del rw
        raise NotImplementedError(
            "uvm_reg_predictor.predict() must be implemented")
