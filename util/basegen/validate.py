# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import jsonschema
from jsonschema.validators import Draft202012Validator
from jsonschema.exceptions import ValidationError
from referencing.jsonschema import SchemaRegistry, SchemaResource, DRAFT202012
from referencing import Resource

import re
import logging as log
import jsonschema2md

from typing import Any, TextIO
from .lib import REPO_TOP, import_hjson


SCHEMA_DIRS = {REPO_TOP / "util" / "basegen" / "schemas",
               REPO_TOP / "util" / "ipgen" / "schemas",
               REPO_TOP / "util" / "raclgen" / "schemas",
               REPO_TOP / "util" / "reggen" / "schemas",
               REPO_TOP / "util" / "tlgen" / "schemas",
               REPO_TOP / "util" / "topgen" / "schemas"}

BUILTIN_SCHEMAS = []
for sd in SCHEMA_DIRS:
    BUILTIN_SCHEMAS += list(import_hjson(hj) for hj in sd.rglob("*.hjson"))
BUILTIN_SCHEMAS_REGISTRY = SchemaRegistry().with_resources(
    (s["$id"], DRAFT202012.create_resource(s))
    for s in BUILTIN_SCHEMAS).crawl()


###############################
# Schema validation functions #
###############################

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


########################
# Schema documentation #
########################

def document_schema(outfile: TextIO | None,
                    schema: dict[str, Any] | str | Resource,
                    schema_parser: jsonschema2md.Parser = jsonschema2md.Parser(header_level=2),
                    registry: SchemaRegistry = BUILTIN_SCHEMAS_REGISTRY,
                    link_correction: dict[str, Any] | None = None) -> str | None:
    """Document the requirements of a given schema in Markdown formatting.

    Output can either be directly written to text or returned as str. Schema documentation may be
    particularly useful for documenting the input file requirements for specific tools.
    """
    schema = _resolve_schema(schema, registry)
    schema_desc = schema_parser.parse_schema(schema)
    doc_text = "".join(schema_desc)

    if link_correction is not None:
        doc_text = correct_doc_links(doc_text, **link_correction)

    if outfile is None:
        return doc_text
    else:
        outfile.write(doc_text)
    return None


def correct_doc_links(
    doc_text: str,
    use_link: bool | None = None,
    registry: SchemaRegistry = BUILTIN_SCHEMAS_REGISTRY
) -> str:
    """Correct jsonschema2md link rendering.

    By default, jsonschema2md does not properly address URN-identified schemas.
    Since URN does not convey the path to the original schema file, instead
    search for a header with the schema name and link to that if it exists,
    else remove the link.

    If `use_link` is manually passed in, all links will be either removed or
    updated without searching for the header in the text.
    """
    doc_link_re = r"Refer to \*\[(?P<urn>.+?)\]\((?P<badlink>.+?)\)\*\."
    for ref in re.finditer(doc_link_re, doc_text):
        urn = ref.group("urn")
        schema = _resolve_schema(urn, registry)

        # use_link can override heading search
        if use_link is None:
            linked_heading = re.search(f"^#+\\s+{schema['title']}\\s*?$",
                                       doc_text,
                                       flags=re.M)
            link_exists = linked_heading is not None
        else:
            link_exists = use_link

        # replace broken link
        if link_exists:
            cleaned_title = re.sub(r"[^A-Za-z -]", "", schema['title'].lower())
            repl = re.sub(ref.group("badlink"),
                          f"#{'-'.join(cleaned_title.split())}",
                          ref.group(0))
        else:
            repl = f"Refer to *{urn}*."  # no link if no subsection

        doc_text = doc_text.replace(ref.group(0), repl)

    return doc_text


##############
# Validators #
##############

TOPCFG_VALIDATOR = create_validator("urn:topgen:topcfg")

IP_BLOCK_VALIDATOR = create_validator("urn:reggen:ip_block")

XBAR_VALIDATOR = create_validator("urn:tlgen:xbar")

TPL_PARAM_VALIDATOR = create_validator("urn:ipgen:template_parameter")
IP_CONFIG_VALIDATOR = create_validator("urn:ipgen:ip_config")

RACL_VALIDATOR = create_validator("urn:raclgen:racl")
RACL_MAPPING_VALIDATOR = create_validator("urn:raclgen:mapping")
