# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Helpers shared by the ACVP prompt parsers."""

import json


def load_vector_set(path):
    """Reads a vector set.
    Sample vectors are bare objects, while production vectors are a
    two-element array. We support both here."""
    with open(path) as f:
        data = json.load(f)
    return data[1] if isinstance(data, list) else data


def apply_expected(test_vectors, path):
    """Folds an expectedResults.json onto the test cases, the way the
    Wycheproof vectors carry theirs. A prompt with no answers is answered
    without checking, which is the production case."""
    if path is None:
        return
    expected = load_vector_set(path)
    answers = {test["tcId"]: test
               for group in expected["testGroups"]
               for test in group["tests"]}
    for vector in test_vectors:
        answer = answers.get(vector["test_case_id"], {})
        for name, value in answer.items():
            if name == "tcId":
                continue
            if name == "testPassed":
                vector["result"] = value
            else:
                vector["expected_" + name] = list(bytes.fromhex(value))


def acvp_common(data, group):
    """The identifiers the harness needs to rebuild the response.
    Algorithms such as the AES modes have no mode."""
    common = {
        "vendor": "acvp",
        "algorithm": data["algorithm"],
    }
    if "mode" in data:
        common["mode"] = data["mode"]
    common.update({
        "revision": data["revision"],
        "is_sample": data.get("isSample", False),
        "vs_id": data["vsId"],
        "tg_id": group["tgId"],
    })
    return common
