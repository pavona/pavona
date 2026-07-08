# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
from basegen.lib import REPO_TOP, import_hjson
from jsonschema.exceptions import ValidationError
from referencing.jsonschema import SchemaRegistry, SchemaResource, DRAFT202012

from basegen.validate import validate_schema, create_validator


# test_topcfg_validation
KNOWN_GOOD_TOPCFGS = (
    REPO_TOP / "hw" / "top_dragonfly" / "data" / "top_dragonfly.hjson",
    REPO_TOP / "hw" / "top_egret" / "data" / "top_egret.hjson"
)
KNOWN_BAD_TOPCFGS = ({}, {"foo": 2})

# test_ip_block_validation
KNOWN_GOOD_IPDESCS = {ipdesc if (ipdesc.name == ipdesc.parents[1].name) else None
                      for ipdesc in (REPO_TOP / "hw" / "ip").glob("*/data/*.hjson")}
KNOWN_GOOD_IPDESCS.remove(None)
KNOWN_BAD_IPDESCS = ({}, {"name": "foo", "clocking": {}})

# test_nested_schemas
NESTED_SCHEMAS = (
    {
        "$id": "urn:test_basegen:parent",
        "properties": {
            "my_child": {"$ref": "urn:test_basegen:child"}}},
    {
        "$id": "urn:test_basegen:child",
        "required": ["foo"],
        "properties": {
            "foo": {"type": "integer"}}}
)
GOOD_PARENTS = ({}, {"my_child": {"foo": 3}})
BAD_PARENTS = ({"my_child": {}},
               {"my_child": {"foo": "3"}})


def test_topcfg_validation():
    topcfg_validator = create_validator("urn:topgen:topcfg")
    for good in KNOWN_GOOD_TOPCFGS:
        validate_schema(import_hjson(good), "urn:topgen:topcfg")
        topcfg_validator.validate(import_hjson(good))
    for bad in KNOWN_BAD_TOPCFGS:
        try:
            validate_schema(bad, "urn:topgen:topcfg")
        except ValidationError:
            continue
        raise Exception("top config validation (direct) incorrectly approved bad config!"
                        f"\n\t{bad}")

        try:
            topcfg_validator.validate(bad)
        except ValidationError:
            continue
        raise Exception("top config validation (validator) incorrectly approved bad config!"
                        f"\n\t{bad}")


def test_ip_block_validation():
    for good in KNOWN_GOOD_IPDESCS:
        validate_schema(import_hjson(good), "urn:reggen:ip_block")
    for bad in KNOWN_BAD_IPDESCS:
        try:
            validate_schema(bad, "urn:reggen:ip_block")
        except ValidationError:
            continue
        raise Exception("IP block description validation incorrectly approved bad description!"
                        f"\n\t{bad}")


def test_nested_schemas():
    parent, child = NESTED_SCHEMAS
    registry = SchemaRegistry().with_resources((
        (parent["$id"], SchemaResource(parent, DRAFT202012)),
        (child["$id"], SchemaResource(child, DRAFT202012))
    )).crawl()

    for good in GOOD_PARENTS:
        validate_schema(good, "urn:test_basegen:parent", registry)
    for bad in BAD_PARENTS:
        try:
            validate_schema(bad, "urn:test_basegen:parent", registry)
        except ValidationError:
            continue
        raise Exception("nested schema failed to catch bad dataset:"
                        f"\n\t{bad}")
