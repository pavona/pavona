// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

mod autogen;

#[cfg(feature = "egret")]
pub use autogen::egret::{
    DirectPads, MuxedPads, PinmuxInsel, PinmuxMioOut, PinmuxOutsel, PinmuxPeripheralIn,
};
#[cfg(feature = "egret")]
pub use top_egret::top_egret::*;

#[cfg(feature = "dragonfly")]
pub use autogen::dragonfly::{
    DirectPads, MuxedPads, PinmuxInsel, PinmuxMioOut, PinmuxOutsel, PinmuxPeripheralIn,
};
#[cfg(feature = "dragonfly")]
pub use top_dragonfly::top_dragonfly::*;
