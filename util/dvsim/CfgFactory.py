# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import logging as log
import sys
import os

from CfgJson import load_hjson
from utils import parse_hjson

import FormalCfg
import CdcCfg
import RdcCfg
import LintCfg
import SimCfg
import SynCfg


def _load_cfg(path, initial_values):
    '''Worker function for make_cfg.

    initial_values is passed to load_hjson (see documentation there).

    Returns a pair (cls, hjson_data) on success or raises a RuntimeError on
    failure.

    '''
    # Set the `self_dir` template variable to the path of the currently
    # processed Hjson file.
    assert 'self_dir' in initial_values
    initial_values['self_dir'] = os.path.dirname(path)

    # Start by loading up the hjson file and any included files
    hjson_data = load_hjson(path, initial_values)

    # Look up the value of flow in the loaded data. This is a required field,
    # and tells us what sort of FlowCfg to make.
    flow = hjson_data.get('flow')
    if flow is None:
        raise RuntimeError('{!r}: No value for the "flow" key. Are you sure '
                           'this is a dvsim configuration file?'
                           .format(path))

    classes = [
        RdcCfg.RdcCfg,
        CdcCfg.CdcCfg,
        LintCfg.LintCfg,
        SynCfg.SynCfg,
        FormalCfg.FormalCfg,
        SimCfg.SimCfg
    ]
    found_cls = None
    known_types = []
    for cls in classes:
        assert cls.flow is not None
        known_types.append(cls.flow)
        if cls.flow == flow:
            found_cls = cls
            break
    if found_cls is None:
        raise RuntimeError('{}: Configuration file sets "flow" to {!r}, but '
                           'this is not a known flow (known: {}).'
                           .format(path, flow, ', '.join(known_types)))

    return (found_cls, hjson_data)


def _make_child_cfg(path, args, initial_values, seed_index=None, default_reseed=1):
    try:
        cls, hjson_data = _load_cfg(path, initial_values)
    except RuntimeError as err:
        log.error(str(err))
        sys.exit(1)

    # Since this is a child configuration (from some primary configuration),
    # make sure that we aren't ourselves a primary configuration. We don't need
    # multi-level hierarchies and this avoids circular dependencies.
    if 'use_cfgs' in hjson_data:
        raise RuntimeError('{}: Configuration file has use_cfgs, but is '
                           'itself included from another configuration.'
                           .format(path))

    if seed_index:
        reseed_source(hjson_data, seed_index, default_reseed)

    # Call cls as a constructor. Note that we pass None as the mk_config
    # argument: this is not supposed to load anything else.
    return cls(path, hjson_data, args, None)


def reseed_source(graded_reseeds: dict, seed_index: dict, default_reseed: int):
    '''Source resets for each test that has a reseed if the flag --reseed-source was passed.
    '''
    hjson_name = graded_reseeds["name"]
    log.debug("========== %s ==========", hjson_name)
    log.debug("before:")
    count_reseeds(graded_reseeds)

    hit = False
    variant = graded_reseeds.get("variant")
    for hjson_test in graded_reseeds.get("tests", []):
        resolved_name = hjson_test["name"].replace("{name}", graded_reseeds["name"])

        for candidate in [hjson_test["name"], resolved_name]:
            key = (candidate, graded_reseeds["name"], variant)
            if key in seed_index:
                hit = True
                entry = seed_index[key]
                if "reseed" in entry:
                    hjson_test["reseed"] = entry["reseed"]
                if "seeds" in entry:
                    hjson_test["seeds"] = entry["seeds"]
                break  # Assume one match per test

    if "reseed" in graded_reseeds.keys() and hit:
        graded_reseeds["reseed"] = default_reseed

    log.debug("after:")
    count_reseeds(graded_reseeds)


def count_reseeds(graded_reseeds):
    '''Helper function used in debug for counting seeds after override
    '''
    total = 0
    for test in graded_reseeds.get("tests", []):
        global_reseed = graded_reseeds.get("reseed", 1)
        reseed = test.get("reseed", global_reseed)
        testname = test["name"].replace("{name}", graded_reseeds["name"])
        log.debug(" %s: %d", testname, reseed)
        total += reseed
    log.debug("  Total: %d", total)
    return total


def make_cfg(path, args, proj_root):
    '''Make a flow config by loading the config file at path
    '''
    initial_values = {
        'proj_root': proj_root,
        'self_dir': os.path.dirname(path),
    }
    if args.tool is not None:
        initial_values['tool'] = args.tool

    try:
        cls, hjson_data = _load_cfg(path, initial_values)
    except RuntimeError as err:
        log.error(str(err))
        sys.exit(1)

    seed_index = {}
    default_reseed = 1
    if args.reseed_source:
        seed_data = parse_hjson(args.reseed_source)

        # Collect test seeds in a lookup dictionary
        for seed_test in seed_data.get("tests", []):
            variant = seed_test.get("variant")
            key = (seed_test["test"], seed_test["name"], variant)
            seed_index[key] = seed_test

        default_reseed = seed_data.get("reseed", 1)

        # If it is a single config, just change the reseeds now
        if 'use_cfgs' not in hjson_data and seed_data:
            reseed_source(hjson_data, seed_index, default_reseed)

    def factory(child_path):
        child_ivs = initial_values.copy()
        child_ivs['flow'] = hjson_data['flow']
        return _make_child_cfg(child_path, args, child_ivs, seed_index, default_reseed)

    return cls(path, hjson_data, args, factory)
