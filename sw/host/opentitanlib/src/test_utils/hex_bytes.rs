// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

//! Serde helper for ujson `bytes` fields, which travel as hex strings.

use arrayvec::ArrayVec;
use serde::de::Error;
use serde::{Deserialize, Deserializer, Serializer};

pub fn serialize<S, const N: usize>(
    value: &ArrayVec<u8, N>,
    serializer: S,
) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    serializer.serialize_str(&hex::encode(value.as_slice()))
}

pub fn deserialize<'de, D, const N: usize>(deserializer: D) -> Result<ArrayVec<u8, N>, D::Error>
where
    D: Deserializer<'de>,
{
    let string = String::deserialize(deserializer)?;
    let bytes = hex::decode(&string).map_err(D::Error::custom)?;
    let mut value = ArrayVec::<u8, N>::new();
    value.try_extend_from_slice(&bytes).map_err(|_| {
        D::Error::custom(format!("expected at most {N} bytes, got {}", bytes.len()))
    })?;
    Ok(value)
}
