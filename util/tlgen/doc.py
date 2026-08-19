# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Generate self-documentation for a TL-UL crossbar."""

from basegen.validate import document_schema
import jsonschema2md


def selfdoc(heading: int, cmd: str = "") -> str:
    """Return self-documentation for TL crossbar."""
    schema_parser = jsonschema2md.Parser(header_level=heading)

    return "\n".join([document_schema(outfile=None,
                                      schema="urn:tlgen:xbar",
                                      schema_parser=schema_parser),
                      document_schema(outfile=None,
                                      schema="urn:tlgen:node",
                                      schema_parser=schema_parser)])
