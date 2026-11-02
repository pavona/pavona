# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
from pathlib import Path
from basegen.lib import REPO_TOP, import_hjson
from jsonschema.exceptions import ValidationError
from referencing.jsonschema import SchemaRegistry, SchemaResource, DRAFT202012

from basegen.validate import (validate_schema, all_validation_errors,
                              TOPCFG_VALIDATOR, SEEDCFG_VALIDATOR,
                              IP_BLOCK_VALIDATOR,
                              XBAR_VALIDATOR,
                              TPL_PARAM_VALIDATOR, IP_CONFIG_VALIDATOR,
                              RACL_VALIDATOR, RACL_MAPPING_VALIDATOR,
                              document_schema, correct_doc_links)
from basegen.validate import create_validator

import sys
import pytest

BAD_INPUTS = (
    {},
    {"foo": 2},
    {"name": "foo", "clocking": {}},
    {"null": 1}
)

# test_topcfg_validation
KNOWN_GOOD_TOPCFGS = tuple(
    import_hjson(topcfg)
    for topcfg in REPO_TOP.glob("hw/top_*/data/top_*.hjson")
    if "seed" not in topcfg.name
)

# test_seedcfg_validation
KNOWN_GOOD_SEEDCFGS = tuple(
    import_hjson(seedcfg)
    for seedcfg in REPO_TOP.glob("hw/top_*/data/top_*_seed.*.hjson")
)

# test_ip_block_validation
KNOWN_GOOD_IPDESCS = tuple(
    import_hjson(ipdesc)
    for ipdesc in REPO_TOP.glob("hw/ip/*/data/*.hjson")
    if (ipdesc.stem == ipdesc.parents[1].name
        and ipdesc.stem != "tlul"))  # tlul is not an IP

# test_xbarcfg_validation
KNOWN_GOOD_XBARCFGS = tuple(
    import_hjson(xbar_cfg)
    for xbar_cfg in REPO_TOP.glob(
        "hw/top_*/ip/xbar_*/data/autogen/xbar_*.gen.hjson")
)

# test_tplparam_validation
KNOWN_GOOD_TPLPARAMS = tuple(
    param
    for tpldesc in REPO_TOP.glob("hw/ip_templates/*/data/*.tpldesc.hjson")
    for param in import_hjson(tpldesc)["template_param_list"]
)

# test_ipcfg_validation
KNOWN_GOOD_IPCFGS = tuple(
    import_hjson(ipcfg)
    for ipcfg in REPO_TOP.glob("hw/top_*/ip_autogen/*/data/*.ipconfig.hjson")
)

# test_racl_validation
KNOWN_GOOD_RACLS = tuple(
    import_hjson(racl)
    for racl in REPO_TOP.glob("hw/top_*/data/racl/racl.hjson")
)

# test_mapping_validation
KNOWN_GOOD_MAPPINGS = tuple(
    import_hjson(racl)
    for racl in REPO_TOP.glob("hw/top_*/data/racl/*_mapping.hjson")
)


NESTED_SCHEMAS = (
    {
        "$id": "urn:test_basegen:parent",
        "title": "Parent",
        "description": "This schema references another schema.",
        "properties": {
            "my_child": {"$ref": "urn:test_basegen:child"}}},
    {
        "$id": "urn:test_basegen:child",
        "title": "Child of parent",
        "required": ["foo"],
        "properties": {
            "foo": {"type": "integer"}}}
)
_PARENT, _CHILD = NESTED_SCHEMAS
TEST_REGISTRY = SchemaRegistry().with_resources((
    (_PARENT["$id"], SchemaResource(_PARENT, DRAFT202012)),
    (_CHILD["$id"], SchemaResource(_CHILD, DRAFT202012))
)).crawl()

# test_document_schema
# test_document_schema_links
# test_correct_doc_links
TEST_DIR = Path(__file__).parent.resolve()
DOC_KEY = TEST_DIR / "doc_key.md"

# test_nested_schemas
GOOD_PARENTS = ({}, {"my_child": {"foo": 3}})
BAD_PARENTS = ({"my_child": {}},
               {"my_child": {"foo": "3"}})


def _validate_good_and_bad_inputs(good_inps, bad_inps, validator, desc=""):
    assert len(good_inps) > 0, "unable to test validation with no good inputs"
    assert len(bad_inps) > 0, "unable to test validation with no bad inputs"
    for good in good_inps:
        validator.validate(good)
    for bad in bad_inps:
        try:
            validator.validate(bad)  # should raise validation error
        except ValidationError:
            continue
        raise Exception(f"{desc} validation incorrectly approved bad input!"
                        f"\n\t{bad}")


def test_topcfg_validation():
    _validate_good_and_bad_inputs(KNOWN_GOOD_TOPCFGS, BAD_INPUTS,
                                  TOPCFG_VALIDATOR, "top config")

    # validate_schema should be equivalent to Validator.validate
    for good in KNOWN_GOOD_TOPCFGS:
        validate_schema(good, "urn:topgen:topcfg")
    for bad in BAD_INPUTS:
        try:
            validate_schema(bad, "urn:topgen:topcfg")
        except ValidationError:
            continue
        raise Exception("top config validation (direct) incorrectly approved"
                        f" bad config!\n\t{bad}")


def test_seedcfg_validation():
    _validate_good_and_bad_inputs(KNOWN_GOOD_SEEDCFGS,
                                  BAD_INPUTS,
                                  SEEDCFG_VALIDATOR,
                                  "topgen seed configuration")


def test_ip_block_validation():
    _validate_good_and_bad_inputs(KNOWN_GOOD_IPDESCS,
                                  BAD_INPUTS,
                                  IP_BLOCK_VALIDATOR,
                                  "IP block description")


def test_xbarcfg_validation():
    _validate_good_and_bad_inputs(KNOWN_GOOD_XBARCFGS,
                                  BAD_INPUTS,
                                  XBAR_VALIDATOR,
                                  "crossbar configuration")


def test_tplparam_validation():
    _validate_good_and_bad_inputs(KNOWN_GOOD_TPLPARAMS,
                                  BAD_INPUTS,
                                  TPL_PARAM_VALIDATOR,
                                  "template parameter")


def test_ipcfg_validation():
    _validate_good_and_bad_inputs(KNOWN_GOOD_IPCFGS,
                                  BAD_INPUTS,
                                  IP_CONFIG_VALIDATOR,
                                  "IP template config")


def test_racl_validation():
    _validate_good_and_bad_inputs(KNOWN_GOOD_RACLS,
                                  BAD_INPUTS,
                                  RACL_VALIDATOR,
                                  "RACL configuration")


def test_mapping_validation():
    # raclgen requires only one key in dict, mapping is the corresponding value
    # see: raclgen.lib.parse_racl_mapping
    _validate_good_and_bad_inputs(
        [list(mapping.values())[0] for mapping in KNOWN_GOOD_MAPPINGS],
        [list(mapping.values())[0] for mapping in BAD_INPUTS
         if len(mapping.keys()) == 1],
        RACL_MAPPING_VALIDATOR,
        "RACL mapping")


def test_document_schema():
    expected = "\n".join(DOC_KEY.read_text().splitlines()[8:])
    result = document_schema(
        outfile=None, schema=_CHILD, registry=TEST_REGISTRY)
    assert result.splitlines() == expected.splitlines()


def test_document_schema_links():
    expected = "\n".join(DOC_KEY.read_text().splitlines()[:7])
    result = document_schema(
        outfile=None, schema=_PARENT, registry=TEST_REGISTRY,
        link_correction={"use_link": True, "registry": TEST_REGISTRY})
    assert result.splitlines() == expected.splitlines()


def test_correct_doc_links():
    text = "\n".join([document_schema(outfile=None, schema=_PARENT,
                                      registry=TEST_REGISTRY),
                      document_schema(outfile=None, schema=_CHILD,
                                      registry=TEST_REGISTRY)])
    result = correct_doc_links(text, registry=TEST_REGISTRY)
    assert result == DOC_KEY.read_text()


def test_nested_schemas():
    validator = create_validator("urn:test_basegen:parent", TEST_REGISTRY)
    _validate_good_and_bad_inputs(GOOD_PARENTS,
                                  BAD_PARENTS,
                                  validator,
                                  "schema which references another schema")


def test_all_validation_errors():
    bad_data = {}  # this is empty, so each required field should yield error
    validator = TOPCFG_VALIDATOR
    required_keys = validator.schema["required"]

    all_errors = all_validation_errors(bad_data, validator)

    assert len(all_errors) == len(required_keys)


if __name__ == "__main__":
    sys.exit(pytest.main())
