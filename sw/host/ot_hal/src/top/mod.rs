// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

mod autogen;

#[cfg(feature = "earlgrey")]
pub use autogen::earlgrey::{
    DirectPads, MuxedPads, PinmuxInsel, PinmuxMioOut, PinmuxOutsel, PinmuxPeripheralIn,
};
#[cfg(feature = "earlgrey")]
pub use top_earlgrey::top_earlgrey::*;

#[cfg(feature = "darjeeling")]
pub use autogen::darjeeling::{
    DirectPads, MuxedPads, PinmuxInsel, PinmuxMioOut, PinmuxOutsel, PinmuxPeripheralIn,
};
#[cfg(feature = "darjeeling")]
pub use top_darjeeling::top_darjeeling::*;
