# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

from typing import Any, List
import hjson
from pathlib import Path
import re


REPO_TOP = Path(__file__).parents[2].resolve()


class Name:
    """
    We often need to format names in specific ways; this class does so.

    To simplify parsing and reassembling of name strings, this class
    stores the name parts as a canonical list of strings internally
    (in self._parts). The content of a name cannot be changed once it is
    created.

    The "from_*" functions parse and split a name string into the canonical
    list, whereas the "as_*" functions reassemble the canonical list in the
    format specified.

    For example, ex = Name.from_snake_case("example_name") gets split into
    ["example", "name"] internally, and ex.as_camel_case() reassembles this
    internal representation into "ExampleName".
    """

    def __add__(self, other: 'Name') -> 'Name':
        return Name(list(self._parts) + list(other._parts))

    def __repr__(self) -> str:
        return "Name({})".format(self._parts)

    def __hash__(self) -> int:
        return hash(self._parts)

    def __eq__(self, other: object) -> bool:
        if not isinstance(object, Name):
            return NotImplemented
        return self._parts == other._parts

    @staticmethod
    def from_snake_case(input: str) -> 'Name':
        return Name(input.split("_"))

    @staticmethod
    def to_camel_case(input: str) -> str:
        return Name.from_snake_case(input).as_camel_case()

    def __init__(self, parts: List[str]):
        self._parts = tuple(parts)
        for p in parts:
            assert len(p) > 0, "cannot add zero-length name piece"

    def as_snake_case(self) -> str:
        return "_".join([p.lower() for p in self._parts])

    def as_camel_case(self) -> str:
        out = ""
        for p in self._parts:
            # If we're about to join two parts which would introduce adjacent
            # numbers, put an underscore between them.
            if out[-1:].isnumeric() and p[:1].isnumeric():
                out += "_" + p
            else:
                out += p.capitalize()
        return out

    def as_c_define(self) -> str:
        return "_".join([p.upper() for p in self._parts])

    def as_c_enum(self) -> str:
        return "k" + self.as_camel_case()

    def as_c_type(self) -> str:
        return self.as_snake_case() + "_t"

    def as_rust_type(self) -> str:
        return self.as_camel_case()

    def as_rust_const(self) -> str:
        return "_".join([p.upper() for p in self._parts])

    def as_rust_enum(self) -> str:
        return self.as_camel_case()

    def as_sv_define(self) -> str:
        return "_".join([p.upper() for p in self._parts])

    def as_sv_enum(self) -> str:
        return self.as_camel_case()

    def as_sv_type(self) -> str:
        return self.as_snake_case() + "_t"

    def remove_part(self, part_to_remove: str) -> "Name":
        return Name([p for p in self._parts if p != part_to_remove])


##################
# HJSON HANDLING #
##################

def cast_hjson_values(hjson_inp: Any) -> Any | dict[str, Any]:
    """Cast values from an Hjson file into their Python equivalents.

    According to the Pavona style guide, any type of value may be put into
    quotes for clarity in an Hjson file, but this will cause the Python hjson
    library to cast all those values as strings. Instead, they should be
    correctly typed.
    """
    if type(hjson_inp) in (bool, int, float) or hjson_inp is None:
        return hjson_inp

    # casting single value
    if isinstance(hjson_inp, str):
        # none
        if hjson_inp == "null":
            return None

        # bool
        if hjson_inp.lower() == "true":
            return True
        elif hjson_inp.lower() == "false":
            return False

        # float
        if "." in hjson_inp:
            try:
                return float(hjson_inp)
            except ValueError:
                pass

        # int (can be hex or binary)
        digits = re.sub(r"[,_'\s]", "", hjson_inp)
        if digits.isalnum():
            non_decimal = re.match(r"^\d*?(?P<base_prefix>[xb])(?P<digits>[0-9a-fA-F]+)$", digits)
            try:
                if not non_decimal:
                    base = 10
                else:
                    base_prefix, digits = non_decimal.groups()
                    match base_prefix:
                        case "x":
                            base = 16
                        case "b":
                            base = 2
                        case "_":
                            raise ValueError("unknown base prefix specified")
                return int(digits, base=base)
            except ValueError:
                pass

        # str
        return hjson_inp

    # casting set of values (must recurse/cast each value individually too)
    if isinstance(hjson_inp, list):
        return [cast_hjson_values(item) for item in hjson_inp]
    if isinstance(hjson_inp, dict):
        return {cast_hjson_values(k): cast_hjson_values(v) for k, v in hjson_inp.items()}

    raise TypeError(f"Item of unknown type {type(hjson_inp)} found in HJSON.")


def import_hjson(file: Path | str, no_casting: bool = False) -> dict[str, Any]:
    """Import an Hjson file into an OrderedDict.

    Optionally, do not try to re-cast values from the Hjson (from
    strings to other types).
    """
    file = Path(file).resolve()
    raw_hjson = hjson.loads(file.read_text())
    if no_casting:
        return raw_hjson  # type: ignore
    return cast_hjson_values(raw_hjson)
