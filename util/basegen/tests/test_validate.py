# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
from basegen.lib import REPO_TOP, import_hjson
from jsonschema.exceptions import ValidationError
from referencing.jsonschema import SchemaRegistry, SchemaResource, DRAFT202012

from basegen.validate import (validate_schema, all_validation_errors,
                              TOPCFG_VALIDATOR, IP_BLOCK_VALIDATOR,
                              XBAR_VALIDATOR,
                              TPL_PARAM_VALIDATOR, IP_CONFIG_VALIDATOR,
                              RACL_VALIDATOR, RACL_MAPPING_VALIDATOR)


# test_topcfg_validation
KNOWN_GOOD_TOPCFGS = (
    import_hjson(REPO_TOP / "hw/top_dragonfly/data/top_dragonfly.hjson"),
    import_hjson(REPO_TOP / "hw/top_egret/data/top_egret.hjson")
)
KNOWN_BAD_TOPCFGS = ({}, {"foo": 2})

# test_ip_block_validation
KNOWN_GOOD_IPDESCS = tuple(
    import_hjson(ipdesc)
    for ipdesc in REPO_TOP.glob("hw/ip/*/data/*.hjson")
    if (ipdesc.stem == ipdesc.parents[1].name
        and ipdesc.stem != "tlul"))  # tlul is not an IP
KNOWN_BAD_IPDESCS = ({}, {"name": "foo", "clocking": {}})

# test_xbarcfg_validation
KNOWN_GOOD_XBARCFGS = tuple(
    import_hjson(xbar_cfg)
    for xbar_cfg in REPO_TOP.glob(
        "hw/top_*/ip/xbar_*/data/autogen/xbar_*.gen.hjson")
)
KNOWN_BAD_XBARCFGS = ({},)

# test_tplparam_validation
KNOWN_GOOD_TPLPARAMS = tuple(
    param
    for tpldesc in REPO_TOP.glob("hw/ip_templates/*/data/*.tpldesc.hjson")
    for param in import_hjson(tpldesc)["template_param_list"]
)
KNOWN_BAD_TPLPARAMS = ({},)

# test_ipcfg_validation
KNOWN_GOOD_IPCFGS = tuple(
    import_hjson(ipcfg)
    for ipcfg in REPO_TOP.glob("hw/top_*/ip_autogen/*/data/*.ipconfig.hjson")
)
KNOWN_BAD_IPCFGS = ({},)

# test_racl_validation
KNOWN_GOOD_RACLS = tuple(
    import_hjson(racl)
    for racl in REPO_TOP.glob("hw/top_*/data/racl/racl.hjson")
)
KNOWN_BAD_RACLS = ({},)

# test_mapping_validation
KNOWN_GOOD_MAPPINGS = tuple(
    import_hjson(racl)
    for racl in REPO_TOP.glob("hw/top_*/data/racl/*_mapping.hjson")
)
KNOWN_BAD_MAPPINGS = ({}, {"null": 1})

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
    assert len(KNOWN_GOOD_TOPCFGS) > 0 and len(KNOWN_BAD_TOPCFGS) > 0
    for good in KNOWN_GOOD_TOPCFGS:
        validate_schema(good, "urn:topgen:topcfg")  # should be equivalent
        TOPCFG_VALIDATOR.validate(good)
    for bad in KNOWN_BAD_TOPCFGS:
        try:
            TOPCFG_VALIDATOR.validate(bad)
        except ValidationError:
            continue
        raise Exception("top config validation (direct) incorrectly approved"
                        f" bad config!\n\t{bad}")


def test_ip_block_validation():
    assert len(KNOWN_GOOD_IPDESCS) > 0 and len(KNOWN_BAD_IPDESCS) > 0
    for good in KNOWN_GOOD_IPDESCS:
        IP_BLOCK_VALIDATOR.validate(good)
    for bad in KNOWN_BAD_IPDESCS:
        try:
            IP_BLOCK_VALIDATOR.validate(bad)
        except ValidationError:
            continue
        raise Exception("IP block description validation incorrectly approved"
                        f" bad description!\n\t{bad}")


def test_xbarcfg_validation():
    assert len(KNOWN_GOOD_XBARCFGS) > 0 and len(KNOWN_BAD_XBARCFGS) > 0
    for good in KNOWN_GOOD_XBARCFGS:
        XBAR_VALIDATOR.validate(good)
    for bad in KNOWN_BAD_XBARCFGS:
        try:
            XBAR_VALIDATOR.validate(bad)
        except ValidationError:
            continue
        raise Exception("Crossbar configuration validation incorrectly"
                        f" approved bad xbar config!\n\t{bad}")


def test_tplparam_validation():
    assert len(KNOWN_GOOD_TPLPARAMS) > 0 and len(KNOWN_BAD_TPLPARAMS) > 0
    for good in KNOWN_GOOD_TPLPARAMS:
        TPL_PARAM_VALIDATOR.validate(good)
    for bad in KNOWN_BAD_TPLPARAMS:
        try:
            TPL_PARAM_VALIDATOR.validate(bad)
        except ValidationError:
            continue
        raise Exception("Template parameter validation incorrectly approved"
                        f" bad template param input!\n\t{bad}")


def test_ipcfg_validation():
    assert len(KNOWN_GOOD_IPCFGS) > 0 and len(KNOWN_BAD_IPCFGS) > 0
    for good in KNOWN_GOOD_IPCFGS:
        IP_CONFIG_VALIDATOR.validate(good)
    for bad in KNOWN_BAD_IPCFGS:
        try:
            IP_CONFIG_VALIDATOR.validate(bad)
        except ValidationError:
            continue
        raise Exception("IP template config validation incorrectly approved"
                        f" bad IP config!\n\t{bad}")


def test_racl_validation():
    assert len(KNOWN_GOOD_RACLS) > 0 and len(KNOWN_BAD_RACLS) > 0
    for good in KNOWN_GOOD_RACLS:
        RACL_VALIDATOR.validate(good)
    for bad in KNOWN_BAD_RACLS:
        try:
            RACL_VALIDATOR.validate(bad)
        except ValidationError:
            continue
        raise Exception("RACL configuration validation incorrectly approved"
                        f" bad config!\n\t{bad}")


def test_mapping_validation():
    assert len(KNOWN_GOOD_MAPPINGS) > 0 and len(KNOWN_BAD_MAPPINGS) > 0
    for good in KNOWN_GOOD_MAPPINGS:
        # raclgen requires only one key, mapping is value
        # see: raclgen.lib.parse_racl_mapping
        assert len(good.keys()) == 1
        good_mapping = list(good.values())[0]
        RACL_MAPPING_VALIDATOR.validate(good_mapping)
    for bad in KNOWN_BAD_MAPPINGS:
        if len(bad.keys()) != 1:
            continue  # raclgen checks for only one key
        try:
            RACL_MAPPING_VALIDATOR.validate(list(bad.values())[0])
        except ValidationError:
            continue
        raise Exception("RACL mapping validation incorrectly approved bad"
                        f" mapping input!\n\t{bad}")


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


def test_all_validation_errors():
    bad_data = {}  # this is empty, so each required field should yield error
    validator = TOPCFG_VALIDATOR
    required_keys = validator.schema["required"]

    all_errors = all_validation_errors(bad_data, validator)

    assert len(all_errors) == len(required_keys)
