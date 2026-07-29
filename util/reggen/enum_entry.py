# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

from typing import Dict

from reggen.lib import check_str, check_int
from basegen.validate import create_validator
from basegen.lib import cast_hjson_values


ENUM_ENTRY_VALIDATOR = create_validator('urn:reggen:enum_entry')


class EnumEntry:

    def __init__(self, where: str, max_val: int, raw: object):
        if not isinstance(raw, dict):
            raise TypeError('must instantiate enum entry with dict: enum at ' + where)
        ENUM_ENTRY_VALIDATOR.validate(cast_hjson_values(raw))

        self.name = check_str(raw['name'], 'name field of {}'.format(where))
        self.desc = check_str(raw['desc'], 'desc field of {}'.format(where))
        self.value = check_int(raw['value'], 'value field of {}'.format(where))
        if not (0 <= self.value <= max_val):
            raise ValueError(
                f"value for {where} is {self.value}, which isn't representable "
                f"in the field (representable range: 0 .. {max_val}).")

    def _asdict(self) -> Dict[str, object]:
        return {'name': self.name, 'desc': self.desc, 'value': str(self.value)}
