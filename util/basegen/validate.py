# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import jsonschema
from referencing.jsonschema import SchemaRegistry, SchemaResource, DRAFT202012
from referencing import Resource
from .lib import REPO_TOP, import_hjson


SCHEMA_DIRS = {REPO_TOP / "util" / "topgen" / "schemas"}

BUILTIN_SCHEMAS = []
for sd in SCHEMA_DIRS:
    BUILTIN_SCHEMAS += list(import_hjson(hj) for hj in sd.rglob("*.hjson"))
BUILTIN_SCHEMAS_REGISTRY = SchemaRegistry().with_resources(
    (s["$id"], SchemaResource(s, DRAFT202012))
    for s in BUILTIN_SCHEMAS).crawl()


def validate_schema(data: dict, schema: dict | str | Resource,
                    registry: SchemaRegistry = BUILTIN_SCHEMAS_REGISTRY) -> None:
    # cast schema as dict for the jsonschema.validate function
    if isinstance(schema, str):
        schema = registry[schema]  # Resource
    if isinstance(schema, Resource):
        schema = schema.contents

    jsonschema.validate(data, schema, registry=registry)
