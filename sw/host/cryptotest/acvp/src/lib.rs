// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

//! Assembly of ACVP vector set responses, one file per vector set.

use std::collections::BTreeMap;
use std::fs;
use std::path::PathBuf;

use anyhow::{Context, Result};
use clap::Args;
use serde::Deserialize;
use serde_json::{Map, Value, json};

/// Protocol version the assembled responses declare.
const ACV_VERSION: &str = "1.0";

/// The response fields of one test case, excluding `tcId`.
pub type Fields = Map<String, Value>;

/// A vector set's header, and the key its test cases are grouped under.
#[derive(Debug, PartialEq, Eq, PartialOrd, Ord)]
struct VectorSet {
    algorithm: String,
    mode: String,
    revision: String,
    is_sample: bool,
    vs_id: u64,
}

/// Where a test case came from; empty on non-ACVP vectors.
#[derive(Debug, Default, Deserialize)]
pub struct AcvpIds {
    #[serde(default)]
    pub algorithm: String,
    #[serde(default)]
    pub mode: String,
    #[serde(default)]
    pub revision: String,
    #[serde(default)]
    pub is_sample: bool,
    #[serde(default)]
    pub vs_id: u64,
    #[serde(default)]
    pub tg_id: u64,
}

/// Hex as ACVP writes it: uppercase, no separators.
pub fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02X}")).collect()
}

/// ACVP options, to be flattened into a harness's own `Opts`.
#[derive(Debug, Args)]
pub struct AcvpOpts {
    /// Where to write the responses. Defaults to the undeclared outputs.
    #[arg(long)]
    pub response_out: Option<PathBuf>,

    /// Vector files to answer instead of the ones the target pins.
    #[arg(long)]
    pub acvp_json: Vec<String>,
}

impl AcvpOpts {
    /// The vector files to run: the session's own, if it supplied any.
    pub fn vectors<'a>(&'a self, pinned: &'a [String]) -> &'a [String] {
        if self.acvp_json.is_empty() {
            pinned
        } else {
            &self.acvp_json
        }
    }

    fn response_dir(&self) -> Option<PathBuf> {
        self.response_out
            .clone()
            .or_else(|| std::env::var_os("TEST_UNDECLARED_OUTPUTS_DIR").map(PathBuf::from))
    }
}

/// Reads cryptotest vector files.
pub fn read_vectors<T: serde::de::DeserializeOwned>(paths: &[String]) -> Result<Vec<T>> {
    let mut cases = Vec::new();
    for path in paths {
        let raw = fs::read_to_string(path).with_context(|| format!("reading {path}"))?;
        cases.extend(
            serde_json::from_str::<Vec<T>>(&raw).with_context(|| format!("parsing {path}"))?,
        );
    }
    Ok(cases)
}

/// Compares an output field, if the vector says what to expect.
pub fn check_output(name: &str, tc_id: u64, actual: &[u8], expected: &[u8]) {
    if expected.is_empty() {
        return;
    }
    assert_eq!(actual, expected, "test #{tc_id}: {name} mismatch");
}

/// Collects test case responses and writes them per vector set.
#[derive(Debug, Default)]
pub struct ResponseBuilder {
    sets: BTreeMap<VectorSet, BTreeMap<u64, Vec<(u64, Fields)>>>,
}

impl ResponseBuilder {
    pub fn new() -> Self {
        Self::default()
    }

    /// Records the response fields for one test case.
    pub fn add(&mut self, ids: &AcvpIds, tc_id: u64, fields: Fields) {
        self.sets
            .entry(VectorSet {
                algorithm: ids.algorithm.clone(),
                mode: ids.mode.clone(),
                revision: ids.revision.clone(),
                is_sample: ids.is_sample,
                vs_id: ids.vs_id,
            })
            .or_default()
            .entry(ids.tg_id)
            .or_default()
            .push((tc_id, fields));
    }

    /// Writes one response file per vector set.
    pub fn finish(&self, opts: &AcvpOpts) -> Result<()> {
        if self.sets.is_empty() {
            return Ok(());
        }
        if let Some(dir) = opts.response_dir() {
            fs::create_dir_all(&dir)
                .with_context(|| format!("creating response directory {}", dir.display()))?;
            for (set, groups) in &self.sets {
                let name = if set.mode.is_empty() {
                    format!("{}-{}.json", set.algorithm, set.vs_id)
                } else {
                    format!("{}-{}-{}.json", set.algorithm, set.mode, set.vs_id)
                };
                let path = dir.join(name);
                fs::write(&path, self.document(set, groups)?)
                    .with_context(|| format!("writing {}", path.display()))?;
                log::info!("Wrote ACVP response {}", path.display());
            }
        }
        Ok(())
    }

    /// One vector set, in the two-element submission form.
    fn document(
        &self,
        set: &VectorSet,
        groups: &BTreeMap<u64, Vec<(u64, Fields)>>,
    ) -> Result<String> {
        let test_groups: Vec<Value> = groups
            .iter()
            .map(|(tg_id, tests)| {
                let tests: Vec<Value> = tests
                    .iter()
                    .map(|(tc_id, fields)| {
                        let mut test = Map::new();
                        test.insert("tcId".to_string(), json!(tc_id));
                        test.extend(fields.clone());
                        Value::Object(test)
                    })
                    .collect();
                json!({"tgId": tg_id, "tests": tests})
            })
            .collect();
        let mut header = json!({
            "vsId": set.vs_id,
            "algorithm": set.algorithm,
            "mode": set.mode,
            "revision": set.revision,
            "isSample": set.is_sample,
            "testGroups": test_groups,
        });
        // Algorithms such as the AES modes have no mode.
        if set.mode.is_empty() {
            header.as_object_mut().unwrap().remove("mode");
        }
        let response = json!([{"acvVersion": ACV_VERSION}, header]);
        Ok(serde_json::to_string_pretty(&response)?)
    }
}
