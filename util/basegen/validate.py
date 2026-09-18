# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import jsonschema
from jsonschema.validators import Draft202012Validator
from jsonschema.exceptions import ValidationError
from referencing.jsonschema import SchemaRegistry, SchemaResource, DRAFT202012
from referencing import Resource

import logging as log
import jsonschema2md

from typing import Any, TextIO
from .lib import REPO_TOP, import_hjson


SCHEMA_DIRS = {REPO_TOP / "util" / "basegen" / "schemas",
               REPO_TOP / "util" / "ipgen" / "schemas",
               REPO_TOP / "util" / "reggen" / "schemas",
               REPO_TOP / "util" / "tlgen" / "schemas",
               REPO_TOP / "util" / "topgen" / "schemas"}

BUILTIN_SCHEMAS = []
for sd in SCHEMA_DIRS:
    BUILTIN_SCHEMAS += list(import_hjson(hj) for hj in sd.rglob("*.hjson"))
BUILTIN_SCHEMAS_REGISTRY = SchemaRegistry().with_resources(
    (s["$id"], SchemaResource(contents=s, specification=DRAFT202012))
    for s in BUILTIN_SCHEMAS).crawl()


def _resolve_schema(schema: dict[str, Any] | str | SchemaResource,
                    registry: SchemaRegistry = BUILTIN_SCHEMAS_REGISTRY) -> dict[str, Any]:
    """Flexibly get the correct schema from a dict, URN string, or SchemaResource. If the schema
    is a string, search the registry for that URN.
    """
    # cast schema as dict for the jsonschema.validate function
    if isinstance(schema, str):
        schema = registry[schema]  # Resource
    if isinstance(schema, Resource):
        schema = schema.contents
    return schema


def validate_schema(data: dict[str, Any], schema: dict[str, Any] | str | Resource,
                    registry: SchemaRegistry = BUILTIN_SCHEMAS_REGISTRY) -> None:
    """Validate some data against a given schema."""
    schema = _resolve_schema(schema, registry)
    jsonschema.validate(data, schema, registry=registry)


def create_validator(schema: dict[str, Any] | str | Resource,
                     registry: SchemaRegistry = BUILTIN_SCHEMAS_REGISTRY) -> Draft202012Validator:
    """Create a Validator object for validating schemas (metaschema 2020-12)."""
    schema = _resolve_schema(schema, registry)
    return Draft202012Validator(schema, registry=registry)


# validation method here can be schema or validator
def all_validation_errors(data: dict[str, Any],
                          validation: dict[str, Any] | str | Resource | Draft202012Validator,
                          prefix: str | None = None,
                          registry: SchemaRegistry = BUILTIN_SCHEMAS_REGISTRY,
                          log_errors: bool = True) -> list[ValidationError]:
    if not isinstance(validation, Draft202012Validator):
        validation = create_validator(validation, registry)

    errors = list(validation.iter_errors(data))
    if log_errors:
        for err in errors:
            validation_path = err.absolute_path
            if prefix is not None:
                validation_path.appendleft(prefix)
            log.error(f"(validation error, {'.'.join(str(part) for part in validation_path)})"
                      f" {err.message}")

    return errors


def document_schema(outfile: TextIO | None,
                    schema: dict[str, Any] | str | Resource,
                    schema_parser: jsonschema2md.Parser = jsonschema2md.Parser(header_level=2),
                    registry: SchemaRegistry = BUILTIN_SCHEMAS_REGISTRY) -> str | None:
    """Document the requirements of a given schema in Markdown formatting.

    Output can either be directly written to text or returned as str. Schema documentation may be
    particularly useful for documenting the input file requirements for specific tools.
    """
    schema = _resolve_schema(schema, registry)
    schema_desc = schema_parser.parse_schema(schema)
    doc_text = "".join(schema_desc)

    if outfile is None:
        return doc_text
    else:
        outfile.write(doc_text)
    return None
