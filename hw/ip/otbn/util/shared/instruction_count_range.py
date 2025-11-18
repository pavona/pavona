#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

from enum import Enum
from math import inf
from typing import Dict, Optional, Tuple

from .control_flow import (ControlGraph, Cycle, Ecall, ImemEnd, LoopEnd,
                           LoopStart, Ret, program_control_graph,
                           subroutine_control_graph)
from .decode import OTBNProgram
from .information_flow_analysis import get_subroutine_loop_iters


class StopPoint(Enum):
    LOOP_END = 'loop end'
    RET = 'ret'
    ECALL = 'ecall'


def _get_insn_count_range(
        program: OTBNProgram, graph: ControlGraph, start_pc: int,
        stop_at: StopPoint, loop_iters: Optional[Dict[int, int]],
        thru_label: Optional[str],
        exclude_labels: list[str]) -> Optional[Tuple[int, int]]:
    '''Return minimum and maximum instruction counts across control paths.

    In the presence of control-flow cycles or loops with a non-constant
    number of iterations, the maximum number of iterations will be
    None, because there's no clear maximum number of times the loop/cycle
    could run.

    The `stop_at` parameter indicates the expected end point of the control
    flow path(s) from this starting point. It is not currently supported for
    control flow paths from a single start point to have different endings --
    for instance, for one branch to end the program with `ecall` and another to
    return to the caller with `ret`. This is because, for instance, if this
    function is called recursively on a subroutine (stop_at = RET), then the
    caller needs to know the min/max instruction count *after the subroutine
    call returns*, and it would require substantial additional tracking to
    account for some additional, separate path that ends the program entirely.

    In all cases, the function will raise an error if it encounters one of the
    other stopping points; for instance, if an `ecall` instruction appears when
    `stop_at` = RET, then there will be an error. The function will return the
    min/max instruction counts across *all control-flow paths* from the given
    start point to the stopping point.
    '''
    section, edges = graph.get_entry(start_pc)
    sec_count = len(section.get_insn_sequence(program))

    # Special case for when we're in a loop; if we have the loop end and one
    # other edge, this represents the option to either continue the loop or
    # stop. In this case, we don't want to follow the "stop" branch, but rather
    # simply return the min/max from ending the loop here.
    if any([isinstance(e, LoopEnd) for e in edges]):
        assert stop_at == StopPoint.LOOP_END
        # At a loop end, we expect exactly two edges; one to end the loop and
        # one to go back to the start and do another iteration.
        assert len(edges) == 2
        return (sec_count, sec_count)

    # Find the minimum/maximum instruction counts for all next edges.
    min_counts = []
    max_counts = []
    for loc in edges:
        if isinstance(loc, Ecall) or isinstance(loc, ImemEnd):
            # An ecall during a called procedure indicates a failure case,
            # which we shouldn't include in our analysis.
            if stop_at == StopPoint.RET:
                continue
            assert stop_at == StopPoint.ECALL
            # If we haven't reached the required function, then we don't have
            # any relevant instruction bounds to report.
            if thru_label is not None:
                continue
            loc_min, loc_max = 0, 0
        elif isinstance(loc, Ret):
            assert stop_at == StopPoint.RET
            # If we haven't reached the required function, then we don't have
            # any relevant instruction bounds to report.
            if thru_label is not None:
                continue
            loc_min, loc_max = 0, 0
        elif isinstance(loc, LoopEnd):
            # All LoopEnds should have been handled above!
            assert False, f'Unexpected loop end at PC {section.end:#x}'
        elif isinstance(loc, LoopStart):
            # Calculate the number of iterations if possible.
            num_iterations = loop_iters.get(section.end)
            if num_iterations is not None:
                loop_range = _get_insn_count_range(program, graph,
                                                   loc.loop_start_pc,
                                                   StopPoint.LOOP_END,
                                                   loop_iters, thru_label,
                                                   exclude_labels)
                if loop_range is None:
                    continue
                loop_min, loop_max = loop_range
                loop_min *= min(num_iterations)
                loop_max *= max(num_iterations)
            else:
                # Cannot determine # iterations statically.
                loop_min, loop_max = 0, inf

            # Calculate the instruction count range after the loop.
            post_loop_range = _get_insn_count_range(program, graph,
                                                    loc.loop_end_pc + 4,
                                                    stop_at, loop_iters,
                                                    thru_label, exclude_labels)
            if post_loop_range is None:
                continue
            post_loop_min, post_loop_max = post_loop_range
            loc_min = loop_min + post_loop_min
            loc_max = loop_max + post_loop_max
        elif isinstance(loc, Cycle):
            # For cycles, the minimum is 0 (if the cycle is never traversed)
            # and the maximum is None (because we can't easily calculate
            # statically how many times the cycle will be traversed).
            loc_min, loc_max = 0, inf
        else:
            insn = program.get_insn(section.end)
            operands = program.get_operands(section.end)
            if insn.mnemonic == 'jal' and operands['grd'] == 1:
                # Jumping to another subroutine; count the range for the
                # subroutine itself, and if we've gone through the required.
                jump_range = _get_insn_count_range(program, graph, loc.pc,
                                                   StopPoint.RET, loop_iters,
                                                   None, exclude_labels)
                if jump_range is None:
                    continue
                jump_min, jump_max = jump_range
                # Calculate the instruction count range after returning from
                # the jump.
                post_jump_range = _get_insn_count_range(
                    program, graph, section.end + 4, stop_at, loop_iters,
                    thru_label, exclude_labels)
                if post_jump_range is None:
                    continue
                post_jump_min, post_jump_max = post_jump_range
                loc_min = jump_min + post_jump_min
                loc_max = jump_max + post_jump_max
            else:
                # First, make sure this edge doesn't take us to an excluded label
                skip_loc = False
                for exclude_label in exclude_labels:
                    exclude_pc = program.get_pc_at_symbol(exclude_label)
                    if loc.pc == exclude_pc:
                        skip_loc = True
                        break
                if skip_loc:
                    continue

                # If we haven't passed through the required label, but
                # this step will take us there, we can recurse without having
                # to continue to look for the subroutine.
                edge_thru_label = thru_label
                if thru_label is not None:
                    thru_pc = program.get_pc_at_symbol(thru_label)
                    if loc.pc == thru_pc:
                        edge_thru_label = None

                # If not a jump, then this is just a normal PC (i.e. a branch).
                # Follow the branch to get the min/max range.
                loc_range = _get_insn_count_range(program, graph, loc.pc,
                                                  stop_at, loop_iters,
                                                  edge_thru_label,
                                                  exclude_labels)
                if loc_range is None:
                    continue
                loc_min, loc_max = loc_range

        # Add the count for this edge to the list.
        min_counts.append(loc_min + sec_count)
        max_counts.append(loc_max + sec_count)

    if len(min_counts) == 0 or len(max_counts) == 0:
        # No valid edges, so we can't proceed.
        return None

    return (min(min_counts), max(max_counts))


def program_insn_count_range(program: OTBNProgram,
                             thru_label: Optional[str],
                             exclude_labels) -> Tuple[int, Optional[int]]:
    '''Return minimum and maximum instruction counts for the program.

    Wrapper for `_get_insn_count_range` that works on the full program; it
    starts at graph.start and returns the instruction counts for all paths that
    lead to the end of the program.
    '''
    if thru_label is not None:
        subroutine_graph = subroutine_control_graph(program, thru_label)
        loop_iters = get_subroutine_loop_iters(program, subroutine_graph, thru_label,
                                               {})
    else:
        loop_iters = {}
    program_graph = program_control_graph(program)
    count_range = _get_insn_count_range(program, program_graph,
                                        program_graph.start, StopPoint.ECALL,
                                        loop_iters, thru_label, exclude_labels)
    if count_range is None:
        raise ValueError('No control flow path found.')
    min_count, max_count = count_range
    if max_count == inf:
        max_count = None
    return min_count, max_count


def subroutine_insn_count_range(program: OTBNProgram,
                                subroutine: str) -> Tuple[int, Optional[int]]:
    '''Return minimum and maximum instruction counts for the subroutine.

    Wrapper for `_get_insn_count_range` that works on a subroutine; it starts
    at graph.start and returns the instruction counts for all paths that lead
    to a return to the original caller. If a path leads to the program ending
    (i.e. an `ecall` instruction), then there will be an error.
    '''
    graph = subroutine_control_graph(program, subroutine)
    min_count, max_count = _get_insn_count_range(program, graph, graph.start,
                                                 StopPoint.RET, {}, None)
    if max_count == inf:
        max_count = None
    return min_count, max_count
