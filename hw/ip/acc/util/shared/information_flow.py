# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Modified by Ruben Niederhagen and Hoang Nguyen Hien Pham - authors of
# "Improving ML-KEM & ML-DSA on OpenTitan - Efficient Multiplication Vector Instructions for OTBN"
# (https://eprint.iacr.org/2025/2028).
# Copyright Ruben Niederhagen and Hoang Nguyen Hien Pham.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

from copy import deepcopy
from typing import Any, Dict, Iterable, List, Optional, Sequence, Set, Tuple

from serialize.parse_helpers import check_keys, check_list, check_str

from .isr import Isr
from .operand import ImmOperandType, IsrOperandType, Operand, RegOperandType

FLAG_NAMES = ['c', 'm', 'l', 'z']

# Deliberately invalid CSR address used by unimp.
UNIMP_CSR_ADDR = 3072

# Registers that can be involved in information flow without being an operand
SPECIAL_REG_NAMES = ['mod', 'acc', 'acch', 'kmac_core', 'rnd', 'urnd']

# ISRs that should have different information-flow node(s) than their name
ISR_REMAPPING = {
    'fg0': ['fg0-' + x for x in FLAG_NAMES],
    'fg1': ['fg1-' + x for x in FLAG_NAMES],
    'flags':
    ['fg0-' + x for x in FLAG_NAMES] + ['fg1-' + x for x in FLAG_NAMES],
    'mod0': ['mod'],
    'mod1': ['mod'],
    'mod2': ['mod'],
    'mod3': ['mod'],
    'mod4': ['mod'],
    'mod5': ['mod'],
    'mod6': ['mod'],
    'mod7': ['mod'],
    'kmac_msg': ['kmac_core'],
    'kmac_msg1': ['kmac_core'],
    'kmac_digest': ['kmac_core'],
    'kmac_digest1': ['kmac_core'],
}


class InformationFlowNode:
    '''Represents a node in the information flow graph.

    A node is anything that can hold information; it can be a register, flag, or
    memory location.
    '''

    def __init__(self, name: str):
        self.name = name

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, InformationFlowNode):
            return False
        return self.name == other.name

    def overlaps(self, other: 'InformationFlowNode') -> bool:
        '''Returns true if self and other refer to the same underlying location.'''
        return self == other

    def intersection(
            self,
            other: 'InformationFlowNode') -> Optional['InformationFlowNode']:
        '''Returns a new node which is the intersection of the two nodes.

        Returns None if the nodes do not overlap.
        '''
        if not self.overlaps(other):
            return None
        return InformationFlowNode(self.name)

    def subtract(self,
                 other: 'InformationFlowNode') -> List['InformationFlowNode']:
        '''Returns a new node with the intersection of self and other removed.

        Returns self if self and other do not overlap and None if they are equal.
        '''
        if not self.overlaps(other):
            return [self]
        return []

    def union(self,
              other: 'InformationFlowNode') -> Optional['InformationFlowNode']:
        '''Try to merge self and other.'''
        if self.overlaps(other):
            return self
        return None

    def starts_at(self) -> Optional[int]:
        '''Provide the start address of a node which can span a range of
        addresses.

        Used to ensure that overlapping sets of nodes of the same type can be
        unioned in order; this prevents needing to check all pairs of nodes
        for overlap, and instead allows a simple fold after sorting by start
        address.

        Returns None if this node is not of a type that can span a range of
        addresses, meaning the 'start address' of the node isn't important.
        '''
        return None

    def pretty(self, dmem_symbols: Dict[str, int]) -> List[str]:
        '''Pretty-print the node. May return multiple names.'''
        return [self.name]

    def __hash__(self) -> int:
        return hash(self.name)


class DmemInformationFlowNode(InformationFlowNode):
    '''Represents a memory range.'''

    def __init__(self, start: int, end: int):
        super().__init__(f'dmem:{start:#06x}-{end:#06x}')
        assert start < end
        self.start = start
        self.end = end

    def overlaps(self, other: InformationFlowNode) -> bool:
        if not isinstance(other, DmemInformationFlowNode):
            return False
        if self.start <= other.start and self.end > other.start:
            return True
        return other.start <= self.start and other.end > self.start

    def intersection(
            self, other: InformationFlowNode) -> Optional[InformationFlowNode]:
        if not isinstance(other,
                          DmemInformationFlowNode) or not self.overlaps(other):
            return None
        start = max(self.start, other.start)
        end = min(self.end, other.end)
        return DmemInformationFlowNode(start, end)

    def subtract(self,
                 other: InformationFlowNode) -> List[InformationFlowNode]:
        if not isinstance(other,
                          DmemInformationFlowNode) or not self.overlaps(other):
            return [self]
        out: List[InformationFlowNode] = []
        if self.start < other.start:
            out.append(DmemInformationFlowNode(self.start, other.start))
        if other.end < self.end:
            out.append(DmemInformationFlowNode(other.end, self.end))
        return out

    def starts_at(self) -> Optional[int]:
        return self.start

    def union(self,
              other: 'InformationFlowNode') -> Optional['InformationFlowNode']:
        '''Try to merge self and other.'''
        if not isinstance(other, DmemInformationFlowNode):
            return None
        if other.start <= self.start <= other.end:
            return DmemInformationFlowNode(other.start,
                                           max(self.end, other.end))
        elif self.start <= other.start <= self.end:
            return DmemInformationFlowNode(self.start,
                                           max(other.end, self.end))
        return None

    def pretty(self, dmem_symbols: Dict[str, int] = {}) -> List[str]:
        labels = [([k], v) for k, v in dmem_symbols.items()
                  if self.start <= v < self.end]
        if not labels:
            return [self.name]
        labels.sort(key=lambda x: x[1])
        lengths = []
        i = 0
        while i < len(labels):
            names, start = labels[i]
            if i + 1 < len(labels):
                end = labels[i + 1][1]
                if end == start:
                    names.extend(labels[i + 1][0])
                    del labels[i + 1]
                    continue
            else:
                end = self.end
            lengths.append(end - start)
            i += 1
        result = []
        for i in range(len(labels)):
            names = labels[i][0]
            assert len(names) > 0
            if len(names) > 1:
                label_str = '(' + ','.join(names) + ')'
            else:
                label_str = names[0]
            result.append(f'{label_str}[:{lengths[i]}]')
        if labels[0][1] != self.start:
            result.insert(
                0,
                DmemInformationFlowNode(self.start, labels[0][1]).name)
        return result


def _copy_flow(
    flow: Dict[InformationFlowNode, Set[InformationFlowNode]]
) -> Dict[InformationFlowNode, Set[InformationFlowNode]]:
    '''Copies a flow dictionary, sharing the nodes it refers to.

    Nodes are immutable value objects, so only the dictionary and the source
    sets need to be fresh.
    '''
    return {sink: set(sources) for sink, sources in flow.items()}


class InformationFlowGraph:
    '''Represents an information flow graph.

    The graph is represented as a `flow` dictionary mapping each "sink" node to
    a set of "source" nodes. Nodes are represented as strings. All nodes which
    are modified at all in the information flow should be represented as sinks
    in the `flow` dictionary. If a node does not appear, that means that it is
    unmodified.

    Note that it is possible for a sink node to be mapped to an empty set; that
    means the sink is overwritten with a constant value, and information is not
    flowing to it from any nodes (including its own previous value).
    '''

    def __init__(self,
                 flow: Dict[InformationFlowNode, Set[InformationFlowNode]],
                 exists: bool = True):
        self.flow = flow

        # Should not be modified directly. See the nonexistent() method
        # documentation for details of what this flag means.
        self.exists = exists

        self.simplify()

    @staticmethod
    def empty() -> 'InformationFlowGraph':
        '''Represents the graph for a path in which nothing is modified.

        For instance, if a block of code could be executed or not depending on
        the processor state, then the path where the block is not executed
        would be an empty() graph. Then, one could use update() to get a graph
        representing the combination of the two possibilities.
        '''
        return InformationFlowGraph({})

    @staticmethod
    def nonexistent() -> 'InformationFlowGraph':
        '''Represents the graph for a nonexistent path.

        There is an important distinction between this and an "empty" graph. In
        particular, for any graph G, G.update(nonexistent) = G, which is not
        the case for a merely "empty" graph; since the update() method is
        combining all possible paths, an empty graph means we need to consider
        that all nodes might be unmodified, while a nonexistent graph has no
        possible paths and therefore no effect.

        A nonexistent graph can be thought of as "None", but handling it
        directly within the class reduces the need for None checks.

        For instance, imagine we want to represent the information flow for
        only paths of a program that end in RET. If no paths from the current
        point end in RET (because, for instance, all paths end the program with
        ECALL), then a nonexistent graph would represent the information flow.
        '''
        return InformationFlowGraph({}, False)

    def sources(self, sink: InformationFlowNode) -> Set[InformationFlowNode]:
        '''Returns all sources for the given sink.'''
        overlapping = [s for s in self.flow if s.overlaps(sink)]
        if len(overlapping) == 0:
            # if the sink does not appear, it is unmodified, meaning its only
            # source is itself
            return {sink}
        out = set()
        for s in overlapping:
            out |= self.flow[s]
        return out

    def sinks(self, source: str) -> Set[InformationFlowNode]:
        '''Returns all sinks for the given source.'''
        out = set()
        for sink in self.flow:
            if any([s.name == source for s in self.flow[sink]]):
                out.add(sink)
        if any([s.name == source for s in self.flow]):
            # Implicitly, the source is unmodified and depends on itself
            out.add(InformationFlowNode(source))
        return out

    def all_sources(self) -> Set[InformationFlowNode]:
        '''Returns all sources in the graph.'''
        out: Set[InformationFlowNode] = set()
        return out.union(*self.flow.values())

    def all_sinks(self) -> Set[InformationFlowNode]:
        '''Returns all sinks in the graph.'''
        return set(self.flow.keys())

    def sources_for_any(self,
                        sinks: Iterable[str]) -> Set[InformationFlowNode]:
        '''Returns all nodes that are a source for any of the given sinks.

        Important: this does not handle partial overlap of e.g. DMEM ranges! It
        only returns sources for the sinks exactly.
        '''
        out: Set[InformationFlowNode] = set()
        return out.union(*(self.sources(InformationFlowNode(s))
                           for s in sinks))

    def remove_source(self, node: str) -> None:
        '''Removes the node from the graph anywhere it appears as a source.

        If the node is not a source in the graph, does nothing.
        '''
        for sources in self.flow.values():
            for src in sources:
                if src.name == node:
                    sources.discard(src)
                    break

    def remove_sink(self, node: str) -> None:
        '''Removes the node from the graph anywhere it appears as a sink.

        If the node is not a sink in the graph, does nothing.
        '''
        sink_nodes = [n for n in self.flow if n.name == node]
        assert len(sink_nodes) <= 1
        if sink_nodes:
            self.flow.pop(sink_nodes[0], None)

    def simplify(self) -> None:
        '''Merge adjacent nodes in the graph (e.g. DMEM ranges).'''
        for sink in self.flow.keys():
            # Split out the keys with "starts at" values, as these need to be
            # combined in starting order for the below to work
            #
            # TODO: potentially make .starts_at() return a tuple with a domain
            # separation enum value alongside the start address, to allow
            # for multiple ranged information flow node types (e.g. not just
            # DmemInformationFlowNode)
            start_sources: List[Tuple[int, InformationFlowNode]] = []
            non_start_sources: List[InformationFlowNode] = []
            for s in self.flow[sink]:
                start = s.starts_at()
                if start is None:
                    non_start_sources.append(s)
                else:
                    start_sources.append((start, s))
            sources = [
                s for _, s in sorted(start_sources, key=lambda p: p[0])
            ] + non_start_sources
            i = 0
            while i < len(sources):
                node1 = sources[i]
                j = i + 1
                while j < len(sources):
                    node2 = sources[j]
                    node12 = node1.union(node2)
                    if node12 is not None:
                        node1 = node12
                        del sources[j]
                    else:
                        j += 1
                sources[i] = node1
                i += 1
            self.flow[sink] = set(sources)

    def update(self, other: 'InformationFlowGraph') -> None:
        '''Updates self to include the information flow from other.

        Every sink that appears in either or both graphs will, in the updated
        self, have sources formed from the union of its sources in both graphs.
        Sinks that appear in only one graph will have sources formed of the
        union of their sources in the graph in which they appear and themselves
        (because a sink not appearing in a graph implicitly means the value is
        unchanged).

        Sinks that overlap but are not equal will be split into up to 3 entries:
        the overlapping portion and the portions covered by only one of the
        sinks. The overlapping portion will depend on the union of the two
        sources, while the non-overlapping portions will depend on the same
        sources they did in self/other.

        Important note: updating with an empty graph will not be a no-op. An
        empty graph implies everything remains unmodified, so combining an
        empty graph with something that *overwrites* a value (i.e. a graph with
        a sink whose sources do not include itself) will add the "value doesn't
        change" information flow (i.e. the sink will be added to its own
        sources).

        Does not modify other.
        '''
        if not other.exists:
            # If the other graph is nonexistent, then this is a no-op.
            return

        if not self.exists:
            # Updating a nonexistent graph with another graph should return the
            # other graph; since we need to modify self, we change this graph's
            # flow to match other's.
            self.flow = _copy_flow(other.flow)
            self.exists = other.exists
            return

        for sink1, sources1 in other.flow.items():
            overlapping = [s for s in self.flow if s.overlaps(sink1)]
            if not overlapping:
                # implicitly, a non-updated value depends only on itself (NOT
                # an empty set, which would indicate a value that is
                # overwritten with a constant)
                self.flow[sink1] = {sink1} | sources1

            for sink2 in overlapping:
                if sink1 == sink2:
                    self.flow[sink1].update(sources1)
                    continue
                sources2 = self.flow[sink2]
                self.flow.pop(sink2, None)
                rem1 = sink1.subtract(sink2)
                rem2 = sink2.subtract(sink1)
                inter = sink1.intersection(sink2)
                for node in rem1:
                    self.flow[node] = set(sources1)
                for node in rem2:
                    self.flow[node] = set(sources2)
                if inter is not None:
                    self.flow[inter] = sources1 | sources2

        self.simplify()

        return

    def combine(self, other: 'InformationFlowGraph') -> None:
        '''Updates self to incorporate information flow from other.

        The difference between combine() and update() is subtle and only
        affects nodes that are sinks in one graph but not the other. In update(),
        these nodes depend implicitly on themselves. In combine(), the graph
        that mentions them takes precedence and if it indicates an overwrite,
        then an overwrite will be present in the result.

        In practical terms, the idea of update() is that self and other
        represent two possible paths with different information flows that need
        to be merged. The idea of combine() is that self and other are parts of
        the same information flow dictionary.

        Does not modify other.
        '''
        for sink1, sources1 in other.flow.items():
            if not any([s.overlaps(sink1) for s in self.flow]):
                self.flow[sink1] = set()

        self.update(other)
        return

    def seq(self, other: 'InformationFlowGraph') -> 'InformationFlowGraph':
        '''Performs sequential composition of information flow graphs.

        Returns the information flow graph that results from self sequentially
        composed with other. For example, if these are the two graphs (b and c
        being the sinks of self and e and d being the sinks of other):

          self:        other:
            a,d -> b     b   -> e
            a,b -> c     f   -> d
                         b,c -> c

        ...then the result of this operation will be:

            a,d   -> e
            f     -> d
            a,b,d -> c

        Defensively copies all source sets for the new graph.
        '''
        if not self.exists or not other.exists:
            # If either this or the other graph is nonexistent, then the
            # sequence is nonexistent.
            return InformationFlowGraph.nonexistent()

        flow = {}
        for sink, sources in other.flow.items():
            new_sources = set()
            for source in sources:
                overlapping = [s for s in self.flow if s.overlaps(source)]
                if overlapping:
                    for node in overlapping:
                        # connect sink and source even for partial overlap
                        new_sources.update(self.flow[node])
                else:
                    # source is not a sink in self's flow; assume it stays
                    # constant
                    new_sources.add(source)
            flow[sink] = new_sources

        for sink, sources in self.flow.items():
            overlapping = [s for s in flow if s.overlaps(sink)]
            if overlapping:
                # if one of our original sinks partly overlaps with a new sink
                # (partial overwrite), we should propagate only the
                # non-overlapping part.
                for node in overlapping:
                    rem = sink.subtract(node)
                    for n in rem:
                        flow[n] = sources.copy()
            else:
                # sink is not updated in other's flow
                flow[sink] = sources.copy()

        return InformationFlowGraph(flow)

    def __deepcopy__(self,
                     memo: Optional[Dict[int, Any]]) -> 'InformationFlowGraph':
        return InformationFlowGraph(_copy_flow(self.flow), self.exists)

    def loop(self, max_iterations: int = 1000) -> 'InformationFlowGraph':
        '''Returns graph representing all possible repetitions of seq() of this
        graph with itself.

        The graph will be the combination of all possible chainings of this
        graph with itself, including 0 chainings (i.e. an empty graph). The
        result will be equivalent to:

        g = InformationFlowGraph({})
        for _ in range(infinity):
            g.update(g.seq(g))

        It is important to ensure that the total number of nodes in the set is
        limited, otherwise the computation could infinite-loop; the computation
        stops when the update becomes a no-op (signalling that the graph has
        stabilized), which is only guaranteed to happen if the node set is
        finite. By default, an error will be produced after a certain maximum
        number of iterations, but the caller can override this by setting
        `max_iterations` to None.

        Returns a new graph; the input graph is unmodified.
        '''
        if not self.exists:
            # Looping a nonexistent graph results in a nonexistent graph.
            return InformationFlowGraph.nonexistent()

        graph = InformationFlowGraph.empty()
        ctr = 0
        while (max_iterations is None or ctr < max_iterations):
            old = deepcopy(graph)
            graph.update(graph.seq(self))
            if (old == graph):
                # Graph has stabilized; further iterations will not change it.
                return graph
            ctr += 1

        raise RuntimeError(
            'Maximum number of iterations ({}) exceeded when looping '
            'information-flow graph. Is the set of possible nodes larger '
            'than the maximum iterations?'.format(max_iterations))

    def clobbered(self) -> str:
        '''Return a human-readable description of clobbered registers and flags.

        For example:
        clobbered registers: x3 to x5, w2 to w10, acc
        clobbered flag groups: FG0
        '''
        if not self.exists:
            return 'Nonexistent information-flow graph (no possible paths).'

        def _combine_ranges(nums: List[int]) -> List[Tuple[int, int]]:
            '''Convert a list of numbers into a list of ranges.

            For example, [1, 3, 4, 5] would become [(1, 1), (3,5)].
            '''
            if len(nums) == 0:
                return []

            ranges = []
            start = nums[0]
            end = nums[0]
            for n in nums[1:]:
                if n == end + 1:
                    end = n
                else:
                    ranges.append((start, end))
                    start = n
                    end = n
            ranges.append((start, end))
            return ranges

        def _stringify_range(prefix: str, r: Tuple[int, int]) -> str:
            start, end = r
            if start == end:
                return f'{prefix}{start}'
            return f'{prefix}{start} to {prefix}{end}'

        # First transform the nodes into a list of special registers plus
        # registers that may get represented as a range, stored as numbers.
        special = []
        flag_groups = set()
        wregs = []
        xregs = []
        for sink in self.flow:
            if sink.name == 'x1':
                # Not real registers or flags, ignore
                continue
            elif sink.name == 'dmem' or sink.name.startswith('dmem:'):
                # Memory is not a register; do not list it as clobbered.
                continue
            elif sink.name.startswith('kmac'):
                # KMAC peripheral interface, not a register; do not list it.
                continue
            elif sink.name.startswith('w') and sink.name[1:].isdigit():
                wregs.append(int(sink.name[1:]))
            elif sink.name.startswith('x') and sink.name[1:].isdigit():
                xregs.append(int(sink.name[1:]))
            elif sink.name.startswith('fg0'):
                flag_groups.add('FG0')
            elif sink.name.startswith('fg1'):
                flag_groups.add('FG1')
            else:
                special.append(sink.name)

        # Combine the ranges.
        w_ranges = _combine_ranges(sorted(wregs))
        x_ranges = _combine_ranges(sorted(xregs))

        # Stringify ranges
        regs = [_stringify_range('x', r) for r in x_ranges]
        regs += [_stringify_range('w', r) for r in w_ranges]
        regs += special
        regs_line = '* clobbered registers: ' + ', '.join(regs)
        flags_str = 'none' if len(flag_groups) == 0 else ', '.join(
            sorted(list(flag_groups)))
        flags_line = '* clobbered flag groups: ' + flags_str
        return regs_line + '\n' + flags_line

    def pretty(self,
               indent: int = 0,
               dmem_symbols: Dict[str, int] = {}) -> str:
        '''Return a human-readable representation of the graph.'''
        prefix = ' ' * indent
        if not self.exists:
            return prefix + 'Nonexistent information-flow graph (no possible paths).'

        flow_strings = {}
        for sink in self.flow:
            for sink_name in sink.pretty(dmem_symbols):
                assert sink_name not in flow_strings
                flow_strings[sink_name] = [
                    x for s in self.flow[sink] for x in s.pretty(dmem_symbols)
                ]
        max_sink_chars = max([len(s) for s in flow_strings.keys()], default=0)
        lines = []
        for sink_str in sorted(flow_strings.keys()):
            sources_str = ', '.join(sorted(flow_strings[sink_str]))
            padding = ' ' * (max_sink_chars - len(sink_str))
            lines.append('{}{}{} <- {}'.format(prefix, sink_str, padding,
                                               sources_str))
        return '\n'.join(lines)

    def __eq__(self, other: object) -> bool:
        '''Compare two information flow graphs for equality.

        Two graphs are considered equal iff the underlying flow dictionaries
        are equal.
        '''
        if not isinstance(other, InformationFlowGraph):
            return False
        return self.flow == other.flow


class InsnInformationFlowNode:
    '''Represents an information flow node whose value may depend on operands.
    '''

    def required_constants(self, op_vals: Dict[str, int],
                           coarse_dmem: bool) -> Set[str]:
        '''Returns the names of regs that must be constant for `evaluate()`.

        For instance, for an indirect reference of a WDR via a GPR, the GPR's
        value must be constant for the node to be evaluated. Subclasses that
        require constants override this method.

        When `coarse_dmem` is true, treat DMEM as a single information-flow
        node rather than tracking values more precisely; in this case, for
        example, addresses of DMEM loads would not be required constants.
        '''
        return set()

    def is_read_only(self, op_vals: Dict[str, int]) -> bool:
        return False

    def evaluate(self, op_vals: Dict[str, int], constant_regs: Dict[str, int],
                 coarse_dmem: bool) -> List[InformationFlowNode]:
        '''Determines information flow graph for the instruction.

        Evaluates the information-flow node according to the given operand
        values. The `constant_regs` dictionary is only used to access values in
        `self.required_constants()`; changes to other values will have no
        effect.
        '''
        raise NotImplementedError()


class InsnRegOperandNode(InsnInformationFlowNode):
    '''Represents a specific register operand for an instruction.'''

    def __init__(self, op: Operand):
        if not isinstance(op.op_type, RegOperandType):
            raise ValueError(
                'Attempt to construct a register-operand information flow '
                'node from a non-register operand {} of type {}'.format(
                    op.name, op.op_type))
        self.op = op
        self.is_wide = op.op_type.reg_type == 'wdr'

    def _get_reg_name(self, op_vals: Dict[str, int]) -> str:
        return self.op.op_type.op_val_to_str(op_vals[self.op.name], None)

    def is_read_only(self, op_vals: Dict[str, int]) -> bool:
        # x0 is the only read-only register
        return self._get_reg_name(op_vals) == 'x0'

    def evaluate(self, op_vals: Dict[str, int], constant_regs: Dict[str, int],
                 coarse_dmem: bool) -> List[InformationFlowNode]:
        if self.op.name not in op_vals:
            raise ValueError(
                'Operand {} not found in provided operand values: {}'.format(
                    self.op.name, op_vals.keys()))
        return [InformationFlowNode(self._get_reg_name(op_vals))]


class InsnIsrOperandNode(InsnInformationFlowNode):
    '''Represents an ISR operand for an instruction.'''

    def __init__(self, op: Operand):
        if not isinstance(op.op_type, IsrOperandType):
            raise ValueError(
                'Attempt to construct a register-operand information flow '
                'node from a non-register operand {} of type {}'.format(
                    op.name, op.op_type))
        self.op = op

    def _get_isr(self, op_vals: Dict[str, int]) -> Optional[Isr]:
        addr = op_vals[self.op.name]
        if addr == UNIMP_CSR_ADDR:
            return None
        return self.op.op_type.isrs.addr_to_isr[addr]  # type: ignore

    def is_read_only(self, op_vals: Dict[str, int]) -> bool:
        isr = self._get_isr(op_vals)
        if isr is None:
            return True
        return isr.read_only

    def evaluate(self, op_vals: Dict[str, int], constant_regs: Dict[str, int],
                 coarse_dmem: bool) -> List[InformationFlowNode]:
        if self.op.name not in op_vals:
            raise ValueError(
                'Operand {} not found in provided operand values: {}'.format(
                    self.op.name, op_vals.keys()))
        isr = self._get_isr(op_vals)
        if isr is None:
            return []
        if isr.name in ISR_REMAPPING:
            return [
                InformationFlowNode(name) for name in ISR_REMAPPING[isr.name]
            ]
        return [InformationFlowNode(isr.name)]


class InsnDmemOperandNode(InsnInformationFlowNode):
    '''Represents a specific dmem range for an instruction.

    The dmem location consists of a GPR operand and an offset.
    '''

    def __init__(self, addr_op: Operand, offset_op: Operand, width: int):
        if not isinstance(addr_op.op_type, RegOperandType):
            raise ValueError(
                'Attempt to construct a dmem information flow node from a '
                'non-register address operand {} of type {}'.format(
                    addr_op.name, addr_op.op_type))
        if not isinstance(offset_op.op_type, ImmOperandType):
            raise ValueError(
                'Attempt to construct a dmem information flow node from a '
                'non-immediate offset operand {} of type {}'.format(
                    offset_op.name, offset_op.op_type))
        self.addr_op = addr_op
        self.offset_op = offset_op
        self.width = width

    def required_constants(self, op_vals: Dict[str, int],
                           coarse_dmem: bool) -> Set[str]:
        if coarse_dmem:
            return set()
        addr_reg_val = op_vals[self.addr_op.name]
        addr_reg_name = self.addr_op.op_type.op_val_to_str(addr_reg_val, None)
        return set([addr_reg_name])

    def evaluate(self, op_vals: Dict[str, int], constant_regs: Dict[str, int],
                 coarse_dmem: bool) -> List[InformationFlowNode]:
        if coarse_dmem:
            return [InformationFlowNode('dmem')]
        if self.addr_op.name not in op_vals:
            raise ValueError(
                'Operand {} not found in provided operand values: {}'.format(
                    self.addr_op.name, op_vals.keys()))
        if self.offset_op.name not in op_vals:
            raise ValueError(
                'Operand {} not found in provided operand values: {}'.format(
                    self.offset_op.name, op_vals.keys()))
        addr_reg_val = op_vals[self.addr_op.name]
        addr_reg_name = self.addr_op.op_type.op_val_to_str(addr_reg_val, None)
        if addr_reg_name not in constant_regs:
            raise RuntimeError(
                'Cannot analyze information flow; cannot determine which '
                'DMEM region is referenced by non-constant GPR {} (constant '
                'regs are: {})'.format(addr_reg_name, constant_regs.keys()))
        addr = constant_regs[addr_reg_name]
        offset = op_vals[self.offset_op.name]
        return [
            DmemInformationFlowNode(addr + offset, addr + offset + self.width)
        ]


def _eval_indirect_wdr(gpr: str,
                       constant_regs: Dict[str, int]) -> InformationFlowNode:
    if gpr not in constant_regs:
        raise RuntimeError(
            'Cannot analyze information flow; cannot determine which '
            'WDR is referenced by non-constant GPR {} (constant regs '
            'are: {})'.format(gpr, constant_regs.keys()))
    wdr_idx = constant_regs[gpr]
    wdr_name = 'w{}'.format(wdr_idx)
    return InformationFlowNode(wdr_name)


class InsnIndirectWDRNode(InsnInformationFlowNode):
    '''Represents an indirect reference to a WDR via a GPR.'''

    def __init__(self, op: Operand):
        if not isinstance(op.op_type, RegOperandType):
            raise ValueError(
                'Attempt to construct an indirect-WDR operand information '
                'flow node from a non-register operand {} of type {}'.format(
                    op.name, op.op_type))
        if not op.op_type.reg_type == 'gpr':
            raise ValueError(
                'Attempt to construct an indirect-WDR operand information '
                'flow node from a non-GPR register operand {} of type {}'.
                format(op.name, op.op_type.reg_type))
        self.op = op

    def _get_gpr_name(self, op_vals: Dict[str, int]) -> str:
        if self.op.name not in op_vals:
            raise ValueError(
                'Operand {} not found in provided operand values: {}'.format(
                    self.op.name, op_vals.keys()))
        return self.op.op_type.op_val_to_str(op_vals[self.op.name], None)

    def required_constants(self, op_vals: Dict[str, int],
                           coarse_dmem: bool) -> Set[str]:
        # In coarse mode (instruction-count analysis) the specific WDR touched
        # by an indirect reference does not affect control flow, so do not
        # require the index register to be a compile-time constant.
        if coarse_dmem:
            return set()
        return {self._get_gpr_name(op_vals)}

    def evaluate(self, op_vals: Dict[str, int], constant_regs: Dict[str, int],
                 coarse_dmem: bool) -> List[InformationFlowNode]:
        gpr = self._get_gpr_name(op_vals)
        if coarse_dmem and gpr not in constant_regs:
            # The index is not statically known (e.g. a loop-carried WDR index
            # in a variable-count loop). Fall back to a single conservative node
            # standing in for the referenced WDR; the exact WDR is irrelevant to
            # instruction counting.
            return [InformationFlowNode('wref-{}'.format(gpr))]
        return [_eval_indirect_wdr(gpr, constant_regs)]


class InsnGroupFlagNode(InsnInformationFlowNode):
    '''Represents a flag node whose group depends on the flag_group operand.'''

    def __init__(self, flag: str):
        flag = flag.lower()
        if flag not in FLAG_NAMES:
            raise ValueError(
                'Invalid flag name: "{}". Valid names are: {}'.format(
                    flag, FLAG_NAMES))
        self.flag = flag
        self.constant_dependent = False

    def evaluate(self, op_vals: Dict[str, int], constant_regs: Dict[str, int],
                 coarse_dmem: bool) -> List[InformationFlowNode]:
        if 'flag_group' not in op_vals:
            raise ValueError(
                'Operand flag_group not found in provided operand values: {}'.
                format(op_vals.keys()))
        flag_name = 'fg{}-{}'.format(op_vals['flag_group'], self.flag)
        return [InformationFlowNode(flag_name)]


class InsnConstantNode(InsnInformationFlowNode):
    '''Represents instruction node whose value does not depend on operands.'''

    def __init__(self, name: str):
        self.name = name
        self.constant_dependent = False

    def evaluate(self, op_vals: Dict[str, int], constant_regs: Dict[str, int],
                 coarse_dmem: bool) -> List[InformationFlowNode]:
        return [InformationFlowNode(self.name)]


def _parse_iflow_nodes(
        node: str, what: str,
        operands: List[Operand]) -> List[InsnInformationFlowNode]:
    '''Parses information flow node(s) from the instruction description.

    Valid information flow nodes are one of the following:
    - the name of a *register* operand from the operands list
    - "wref-<reg operand name>" for instructions where a WDR is indirectly
      accessed via a GPR; in this case <reg operand name> is the GPR and must
      be in the operands list
    - "dmem-<reg operand name>-<width>" for instructions where memory is
      accessed via a GPR; in this case there must also be an immediate operand
      called "offset" and <width> is the size of the access in bytes.
    - one of the special strings "acch", "acc", or "mod"
    - a flag (represented as "<flag group>-<flag>", where <flag group> can
      be either "fg0", "fg1", or (if the instruction has a flag_group
      operand) simply "flags" to select the current flag group, and <flag>
      can be l, c, m, z, or "all".

    Raises a ValueError if the node does not have a valid format.
    '''
    node = node.lower()

    # Check if node is a register operand
    for op in operands:
        if node == op.name:
            if isinstance(op.op_type, IsrOperandType):
                return [InsnIsrOperandNode(op)]
            if not isinstance(op.op_type, RegOperandType):
                raise RuntimeError(
                    'Information-flow node {} matches operand name, but '
                    'operand type is not a register (type {}). Note that '
                    'immediate operands cannot be information-flow nodes.'.
                    format(node, type(op.op_type)))
            return [InsnRegOperandNode(op)]

    # Check if node is an indirect reference to a WDR through a GPR
    if node.startswith('wref-'):
        gpr = node[len('wref-'):]
        for op in operands:
            if gpr == op.name:
                if not (isinstance(op.op_type, RegOperandType) and
                        op.op_type.reg_type == 'gpr'):
                    raise RuntimeError(
                        'Operand {} in indirect reference {} is not a GPR '
                        '(type {}). Only GPRs can be indirect references.'.
                        format(gpr, node, type(op.op_type)))
                return [InsnIndirectWDRNode(op)]
        raise RuntimeError(
            'Could not find GPR operand corresponding to {} when decoding '
            'indirect reference {}. Operand names: {}'.format(
                gpr, node, ', '.join([op.name for op in operands])))

    # Check if node is a DMEM reference.
    if node.startswith('dmem-'):
        fields = node.split('-')
        if len(fields) != 3:
            raise RuntimeError(
                'Invalid dmem information-flow reference format: {}'.format(
                    node))
        _, gpr, width = fields
        if not width.isnumeric():
            raise RuntimeError(
                'Invalid dmem write width {} in information-flow reference: {}'
                .format(width, node))
        width = int(width)  # type: ignore
        offset = None
        for op in operands:
            if op.name == 'offset' and isinstance(op.op_type, ImmOperandType):
                offset = op
        if offset is None:
            raise RuntimeError(
                'No offset operand found for DMEM reference: {}'.format(node))
        for op in operands:
            if gpr == op.name:
                if not (isinstance(op.op_type, RegOperandType) and
                        op.op_type.reg_type == 'gpr'):
                    raise RuntimeError(
                        'Operand {} in memory reference {} is not a GPR '
                        '(type {}). Only GPRs can be memory references.'.
                        format(gpr, node, type(op.op_type)))
                return [InsnDmemOperandNode(op, offset, width)]  # type: ignore

    # Check if node is a special string, indicating a special register that can
    # be involved in an instruction's information flow *without* being one of
    # the operands.
    if node in SPECIAL_REG_NAMES:
        return [InsnConstantNode(node)]

    # Try to interpret node as a flag or set of flags
    node_split = node.split('-')
    if len(node_split) != 2:
        raise ValueError('Cannot parse information flow node {} for {}'.format(
            node, what))
    flag_group_str, flag = node_split

    # Case where flag group depends on the flag_group operand
    if flag_group_str == 'flags':
        if flag == 'all':
            return [InsnGroupFlagNode(flag) for flag in FLAG_NAMES]
        return [InsnGroupFlagNode(flag)]
    elif flag_group_str == 'fg0' or flag_group_str == 'fg1':
        if flag == 'all':
            return [
                InsnConstantNode('{}-{}'.format(flag_group_str, flag))
                for flag in FLAG_NAMES
            ]
        return [InsnConstantNode('{}-{}'.format(flag_group_str, flag))]
    else:
        raise ValueError('Cannot parse information flow node {} for {}'.format(
            node, what))


class InsnInformationFlowTest:
    '''Wrapper class for tests for information-flow rules.'''

    def __init__(self, as_string: str, operand: str, value: Any):
        self.as_string = as_string
        self.operand = operand
        self.value = value
        assert isinstance(value, str) or isinstance(value, int)

    def get_value(self, op_vals: Dict[str, int]) -> int:
        if isinstance(self.value, int):
            return self.value
        return op_vals[self.value]

    def check(self, op_vals: Dict[str, int]) -> bool:
        # Should be overridden by subclasses
        raise NotImplementedError()

    def __repr__(self) -> str:
        return 'InsnInformationFlowTest: {}'.format(self.as_string)


class EqTest(InsnInformationFlowTest):
    '''Tests that the operand is equal to the value.'''

    def check(self, op_vals: Dict[str, int]) -> bool:
        return op_vals[self.operand] == self.get_value(op_vals)


class NotEqTest(InsnInformationFlowTest):
    '''Tests that the operand is not equal to the value.'''

    def check(self, op_vals: Dict[str, int]) -> bool:
        return not (op_vals[self.operand] == self.get_value(op_vals))


class GeqTest(InsnInformationFlowTest):
    '''Tests that the operand is greater than or equal to the value.'''

    def check(self, op_vals: Dict[str, int]) -> bool:
        return op_vals[self.operand] >= self.get_value(op_vals)


class LeqTest(InsnInformationFlowTest):
    '''Tests that the operand is less than or equal to the value.'''

    def check(self, op_vals: Dict[str, int]) -> bool:
        return op_vals[self.operand] <= self.get_value(op_vals)


class MultiTest(InsnInformationFlowTest):
    '''Combination of multiple tests.'''

    def __init__(self, tests: List[InsnInformationFlowTest]):
        self.tests = tests

    def check(self, op_vals: Dict[str, int]) -> bool:
        return all(t.check(op_vals) for t in self.tests)


def _parse_iflow_test(test_yml: object, what: str,
                      operands: List[Operand]) -> InsnInformationFlowTest:
    '''Parses an item in the "test" list of a YAML information-flow rule.

    Tests are expected to be strings of the form "<operand> <comparison>
    <value>", where:
      - <operand> is the name of one of the instruction's operands
      - <comparison> is "==", "!=", ">=", or "<="
      - <value> is an integer that is within the allowed range of values
        for this operand (for instance, for a flag group it would be 0 or 1,
        and for a register it would be between 0 and 31).

    Returns a function that takes operand values as input and returns true if
    the test passes.
    '''
    test = check_str(test_yml, what)
    test = test.lower()
    test_split = test.split(' ')
    if len(test_split) != 3:
        raise ValueError(
            'Invalid information flow test format (expected "<operand> '
            '<comparison> <value>"): got {} (for {})'.format(test, what))
    opname, comparison, value = test_split

    opnames = [op.name for op in operands]
    if opname not in opnames:
        raise ValueError(
            'Invalid information flow test format for {}: operand {} not '
            'found in operands list: {}'.format(what, opname, opnames))

    try:
        value = int(value, 0)  # type: ignore
    except ValueError:
        # operand; ignore and keep as string
        pass

    constructors = {
        '==': EqTest,
        '!=': NotEqTest,
        '>=': GeqTest,
        '<=': LeqTest,
    }
    constructor = constructors.get(comparison, None)
    if constructor is None:
        raise ValueError('Unrecognized comparison {} for {}'.format(
            comparison, what))
    return constructor(test, opname, value)


class InsnInformationFlowRule:
    '''A rule describing a single step of information flowing to one or more
       nodes from one or more nodes.'''

    def __init__(self, flows_to: Sequence[InsnInformationFlowNode],
                 flows_from: Sequence[InsnInformationFlowNode],
                 test: InsnInformationFlowTest):
        self.flows_to = flows_to
        self.flows_from = flows_from
        self.test = test

    def required_constants(self, op_vals: Dict[str, int],
                           coarse_dmem: bool) -> Set[str]:
        '''Returns the names of regs that must be constant for `evaluate()`.'''
        if not self.test.check(op_vals):
            # Rule is not triggered
            return set()
        out = set()
        for node in self.flows_to:
            out.update(node.required_constants(op_vals, coarse_dmem))
        for node in self.flows_from:
            out.update(node.required_constants(op_vals, coarse_dmem))
        return out

    def evaluate(self, op_vals: Dict[str, int], constant_regs: Dict[str, int],
                 coarse_dmem: bool) -> InformationFlowGraph:
        if not self.test.check(op_vals):
            # Rule is not triggered
            return InformationFlowGraph.nonexistent()
        sources = set()
        for insn_node in self.flows_from:
            for node in insn_node.evaluate(op_vals, constant_regs,
                                           coarse_dmem):
                sources.add(node)
        flow = {}
        for insn_node in self.flows_to:
            for node in insn_node.evaluate(op_vals, constant_regs,
                                           coarse_dmem):
                if not insn_node.is_read_only(op_vals):
                    assert node not in flow
                    flow[node] = sources.copy()
            if coarse_dmem and isinstance(insn_node, InsnDmemOperandNode):
                # if we are doing coarse dmem tracking, then the single "dmem"
                # node should not get overwritten by writes; it should always
                # inherit its own previous value as well.
                flow[node].add(node)
        return InformationFlowGraph(flow)

    @staticmethod
    def from_yaml(yml: object, what: str,
                  insn_operands: List[Operand]) -> 'InsnInformationFlowRule':
        rule = check_keys(yml, what, ['to', 'from'], ['test'])

        to_what = '"to" list for {}'.format(what)
        flows_to = []
        for node_yml in check_list(rule['to'], to_what):
            node_what = 'node {} in {}'.format(node_yml, to_what)
            nodes = _parse_iflow_nodes(check_str(node_yml, node_what),
                                       node_what, insn_operands)
            flows_to.extend(nodes)

        from_what = '"from" list for {}'.format(what)
        flows_from = []
        for node_yml in check_list(rule['from'], from_what):
            node_what = 'node {} in {}'.format(node_yml, from_what)
            nodes = _parse_iflow_nodes(check_str(node_yml, node_what),
                                       node_what, insn_operands)
            flows_from.extend(nodes)

        test_yml = rule.get('test', None)
        if test_yml is None:
            tests = []
        else:
            test_what = 'test field for {}'.format(what)
            tests = [
                _parse_iflow_test(t, test_what, insn_operands)
                for t in check_list(test_yml, test_what)
            ]
        return InsnInformationFlowRule(flows_to, flows_from, MultiTest(tests))


class InsnInformationFlow:
    '''Represents information flow for a single instruction.'''

    def __init__(self, rules: List[InsnInformationFlowRule]) -> None:
        self.rules = rules

    def required_constants(self, op_vals: Dict[str, int],
                           coarse_dmem: bool) -> Set[str]:
        '''Returns the names of regs that must be constant for `evaluate()`.'''
        return {
            const
            for rule in self.rules
            for const in rule.required_constants(op_vals, coarse_dmem)
        }

    def evaluate(self, op_vals: Dict[str, int], constant_regs: Dict[str, int],
                 coarse_dmem: bool) -> InformationFlowGraph:
        graph = InformationFlowGraph.nonexistent()
        for rule in self.rules:
            rule_graph = rule.evaluate(op_vals, constant_regs, coarse_dmem)
            graph.combine(rule_graph)

        return graph

    @staticmethod
    def from_yaml(yml: Optional[object], what: str,
                  insn_operands: List[Operand]) -> 'InsnInformationFlow':

        if yml is None:
            # Default behavior: all source registers flow to all destination
            # registers, no other information flow or special registers
            sources = [
                InsnRegOperandNode(op) for op in insn_operands if
                isinstance(op.op_type, RegOperandType) and op.op_type.is_src()
            ]
            dests = [
                InsnRegOperandNode(op) for op in insn_operands
                if isinstance(op.op_type, RegOperandType) and
                op.op_type.is_dest()
            ]
            return InsnInformationFlow(
                [InsnInformationFlowRule(dests, sources, MultiTest([]))])

        rule_list = check_list(yml, what)
        rules = []
        for idx, rule_yml in enumerate(rule_list):
            rule_what = 'rule at index {} for {}'.format(idx, what)
            rule = InsnInformationFlowRule.from_yaml(rule_yml, rule_what,
                                                     insn_operands)
            rules.append(rule)
        return InsnInformationFlow(rules)
