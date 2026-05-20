// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Include top-specific HALs.
#[cfg(feature = "dragonfly")]
pub mod dragonfly;
#[cfg(feature = "egret")]
pub mod egret;
