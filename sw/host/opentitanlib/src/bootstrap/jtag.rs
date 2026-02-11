// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use anyhow::Result;

use crate::app::{TransportWrapper, UartRx};
use crate::bootstrap::{Bootstrap, UpdateProtocol};
use crate::io::jtag::JtagTap;
use crate::transport::{Capability, ProgressIndicator};

/// Implements the JTAG bootstrap protocol using OpenOCD.
pub struct Jtag;

impl Jtag {
    /// Creates a new `Primitive` protocol updater from `options`.
    pub fn new() -> Self {
        Jtag {}
    }
}

impl UpdateProtocol for Jtag {
    fn verify_capabilities(
        &self,
        _container: &Bootstrap,
        transport: &TransportWrapper,
    ) -> Result<()> {
        transport.capabilities()?.request(Capability::JTAG).ok()
    }

    fn uses_common_bootstrap_reset(&self) -> bool {
        false
    }

    /// Performs the update protocol using the `transport` with the firmware `payload`.
    fn update(
        &self,
        container: &Bootstrap,
        transport: &TransportWrapper,
        payload: &[u8],
        progress: &dyn ProgressIndicator,
    ) -> Result<()> {
        // Spawn an OpenOCD instance to communicate with the JTAG using the
        // transport.
        let jtag_chain = container.jtag_params.create(transport)?;

        // Connect to the JTAG RISC-V TAP.
        let mut jtag = jtag_chain.connect(JtagTap::RiscvTap)?;

        progress.new_stage("", payload.len());

        // Write the payload data to memory in 2048-byte increments.
        let mut current = 0usize;
        let mut chunk = 0u32;
        let target_addr = container.target_addr.ok_or(anyhow::Error::msg(
            "JTAG bootstrap reuquires `--target_addr` to be set.",
        ))?;
        let total = payload.len().div_ceil(2048);
        while current < payload.len() {
            let end = current.saturating_add(2048).min(payload.len());
            let current_u32: u32 = current
                .try_into()
                .expect("Payload too large for 32-bit address space.");
            log::debug!(
                "Writing chunk {} of {} (offset {:x?}, target: {:x?})",
                chunk,
                total,
                current,
                target_addr.saturating_add(current_u32),
            );
            // Check if chunk is all 1s. We can skip it if it is.
            if (&payload[current..end])
                .iter()
                .find(|v| **v != 0xff)
                .is_some()
            {
                jtag.write_memory(
                    target_addr.saturating_add(current_u32),
                    &payload[current..end],
                )?;
            }
            current = end;
            chunk = chunk.saturating_add(1);
            progress.progress(current);
        }
        if !container.leave_in_bootstrap {
            // We opt out of the `common_bootstrap_reset` option because we do not
            // want to set BOOTSTRAP GPIO pins (Darjeeling has no native
            // ROM_BOOTSTRAP mechanism).
            //
            // Instead, we still want to reset the chip so that the ROM will boot to
            // our bootstrapped payload. We do this here.
            transport.reset(if container.clear_uart_rx {
                UartRx::Clear
            } else {
                UartRx::Keep
            })?;
        }
        Ok(())
    }
}
