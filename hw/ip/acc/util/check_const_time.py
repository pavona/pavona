#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import sys

from shared.check import CheckResult
from shared.constants import parse_required_constants
from shared.control_flow import program_control_graph, subroutine_control_graph
from shared.decode import decode_elf
from shared.information_flow_analysis import (get_program_iflow,
                                              get_subroutine_iflow,
                                              parse_information_flow_node,
                                              stringify_control_deps)


def main() -> int:
    parser = argparse.ArgumentParser(
        description='Analyze whether secret data affects the control flow of '
        'an ACC program or subroutine.')
    parser.add_argument('elf', help=('The .elf file to check.'))
    parser.add_argument('--verbose', action='store_true')
    parser.add_argument(
        '--subroutine',
        required=False,
        help=('The specific subroutine to check. If not provided, the start '
              'point is _imem_start (whole program).'))
    parser.add_argument(
        '--ignore',
        nargs='+',
        type=str,
        required=False,
        help=('The specific subroutines to ignore. Use this argument '
              'if violations should be ignored for a subroutine.'))
    parser.add_argument(
        '--constants',
        nargs='+',
        type=str,
        required=False,
        help=('Registers which are required to be constant at the start of the '
              'subroutine. Only valid if `--subroutine` is passed. Write '
              'in the form "reg:value", e.g. x3:5. Only GPRs are accepted as '
              'required constants.'))
    parser.add_argument(
        '--secret',
        nargs='+',
        type=str,
        required=False,
        help=('Initial secret information-flow nodes. If not provided, '
              'assume everything is secret unless --public is specified; '
              'check that the subroutine or program has only one possible '
              'control-flow path regardless of input.'))
    parser.add_argument(
        '--public',
        nargs='+',
        type=str,
        required=False,
        help=('Initially NOT secret information-flow nodes. If specified, '
              'assume everything else is secret. Cannot be specified at the '
              'same time as --secret.'))
    args = parser.parse_args()

    # Load the program.
    program = decode_elf(args.elf)

    # Parse initial constants.
    if args.constants is None:
        constants = {}
    else:
        if args.subroutine is None:
            raise ValueError('Cannot require initial constants for a whole '
                             'program; use --subroutine to analyze a specific '
                             'subroutine.')
        constants = parse_required_constants(args.constants)

    if args.secret and args.public:
        raise ValueError('Cannot specify --secret and --public together.')

    # Parse the secrets as information-flow nodes.
    secret_nodes = set()
    if args.secret:
        for secret in args.secret:
            secret_nodes.add(parse_information_flow_node(secret))

    # Parse the public values as information-flow nodes.
    public_nodes = set()
    if args.public:
        for public in args.public:
            public_nodes.add(parse_information_flow_node(public))

    # Compute control graph and get all nodes that influence control flow.
    program = decode_elf(args.elf)
    if args.subroutine is None:
        graph = program_control_graph(program)
        to_analyze = 'entire program'
        _, control_deps = get_program_iflow(program, graph)
    else:
        graph = subroutine_control_graph(program, args.subroutine)
        to_analyze = 'subroutine {}'.format(args.subroutine)
        _, _, control_deps = get_subroutine_iflow(program, graph,
                                                  args.subroutine, constants)

    control_deps_ignore = {}
    if args.ignore is not None:
        for subroutine in args.ignore:
            graph = subroutine_control_graph(program, subroutine)
            _, _, control_deps_ignore_temp = get_subroutine_iflow(program, graph,
                                                                  subroutine, {})
            control_deps_ignore.update(control_deps_ignore_temp)

    if args.secret is None:
        if args.public is not None:
            secret_control_deps = {
                node: pcs
                for node, pcs in control_deps.items()
                if node not in public_nodes}
        else:
            if args.verbose:
                print(
                    'No specific secrets provided; checking that {} has only one '
                    'control-flow path'.format(to_analyze))
            secret_control_deps = control_deps
    else:
        if args.verbose:
            print('Analyzing {} with initial secrets {} and initial constants {}'.format(
                to_analyze, args.secret, constants))
        # If secrets were provided, only show the ways in which those specific
        # nodes could influence control flow.
        secret_control_deps = {
            node: pcs
            for node, pcs in control_deps.items() if node in args.secret
        }

    secret_control_deps_filt = {k: v for k, v in secret_control_deps.items()
                                if v not in control_deps_ignore.values()}

    out = CheckResult()

    if len(secret_control_deps_filt) != 0:
        msg = 'The following secrets may influence control flow:\n  '
        msg += '\n  '.join(stringify_control_deps(program,
                                                  secret_control_deps_filt))
        out.err(msg)

    if args.verbose or out.has_errors() or out.has_warnings():
        print(out.report())

    if out.has_errors() or out.has_warnings():
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
