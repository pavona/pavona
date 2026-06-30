# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

from pathlib import Path
from basegen.lib import cast_hjson_values, import_hjson


# test_cast_hjson_values
MOCK_TO_CAST = {
    "null": ["item1", "2", "0xF"],
    "2": {"3": "0b11", "yes": "true", "no": "False", "pie": "3.14"}
}
MOCK_CASTED = {
    None: ["item1", 2, 15],
    2: {3: 3, "yes": True, "no": False, "pie": 3.14}
}

# test_cast_hjson_values_ints
MOCK_INT_CONVERSIONS = {
    "1'b1": 1,
    "12345": 12345,
    "0xff": 255,
    "0b1001_1101_0000": 2512
}

# test_import_hjson
MOCK_HJSON_TEXT = """{
  foo: [2, "2", "6.28"]
}
"""
MOCK_HJSON_WITH_CASTING = {"foo": [2, 2, 6.28]}
MOCK_HJSON_NO_CASTING = {"foo": [2, "2", "6.28"]}


def test_cast_hjson_values():
    assert cast_hjson_values(MOCK_TO_CAST) == MOCK_CASTED


def test_cast_hjson_values_ints():
    for input_str, int_equiv in MOCK_INT_CONVERSIONS.items():
        assert cast_hjson_values(input_str) == int_equiv


def test_import_hjson():
    mock_hjson = Path(__file__).parent / "mock.hjson"
    mock_hjson.write_text(MOCK_HJSON_TEXT)
    assert import_hjson(mock_hjson) == MOCK_HJSON_WITH_CASTING
    assert import_hjson(str(mock_hjson.resolve()), True) == MOCK_HJSON_NO_CASTING
    mock_hjson.unlink()
