# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""PyBoolector compatibility API backed by z3-solver.

The released pyvsc package imports PyBoolector directly. Pavona only needs a
small bit-vector solver surface from that API, so this module provides that
surface without depending on the native PyBoolector extension.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
from functools import reduce
from itertools import count
from typing import Any

import z3


class BtorOption(IntEnum):
    """Subset of Boolector options used by pyvsc."""

    BTOR_OPT_INCREMENTAL = 1
    BTOR_OPT_MODEL_GEN = 2


BTOR_OPT_INCREMENTAL = BtorOption.BTOR_OPT_INCREMENTAL
BTOR_OPT_MODEL_GEN = BtorOption.BTOR_OPT_MODEL_GEN


@dataclass(frozen=True)
class _BitVecSort:
    width: int


class BoolectorNode:
    """Wrapper exposing the attributes pyvsc expects from Boolector nodes."""

    def __init__(
        self,
        owner: "Boolector",
        expr: z3.ExprRef,
        width: int,
        *,
        is_bool: bool = False,
    ) -> None:
        self._owner = owner
        self.expr = expr
        self.width = int(width)
        self._is_bool = is_bool

    @property
    def assignment(self) -> str:
        if self._owner.model is None:
            raise RuntimeError("No model is available; call Sat() before reading assignment")

        value = self._owner.model.eval(self.expr, model_completion=True)
        if z3.is_bool(value):
            intval = 1 if z3.is_true(value) else 0
        else:
            intval = value.as_long()

        return format(intval & ((1 << self.width) - 1), f"0{self.width}b")

    def __str__(self) -> str:
        return str(self.expr)


class Boolector:
    """Small PyBoolector-compatible facade implemented with a Z3 solver."""

    SAT = 10
    UNSAT = 20
    UNKNOWN = 0

    _ids = count()

    def __init__(self) -> None:
        self._solver = z3.Solver()
        self._assumptions: list[z3.BoolRef] = []
        self.model: z3.ModelRef | None = None

    def Set_opt(self, _option: BtorOption, _value: Any) -> None:
        return None

    def BitVecSort(self, width: int) -> _BitVecSort:
        width = int(width)
        if width < 1:
            raise ValueError(f"Bit-vector width must be positive, got {width}")
        return _BitVecSort(width)

    def Var(self, sort: _BitVecSort, symbol: str | None = None) -> BoolectorNode:
        name = symbol or f"pyboolector_z3_{next(self._ids)}"
        return BoolectorNode(self, z3.BitVec(name, sort.width), sort.width)

    def Const(self, value: int, width: int) -> BoolectorNode:
        width = int(width)
        if width < 1:
            raise ValueError(f"Bit-vector width must be positive, got {width}")
        mask = (1 << width) - 1
        return BoolectorNode(self, z3.BitVecVal(int(value) & mask, width), width)

    def Assert(self, node: BoolectorNode) -> None:
        self._solver.add(self._as_bool(node))

    def Assume(self, node: BoolectorNode) -> None:
        self._assumptions.append(self._as_bool(node))

    def Sat(self) -> int:
        result = self._solver.check(*self._assumptions)
        self._assumptions.clear()

        if result == z3.sat:
            self.model = self._solver.model()
            return self.SAT
        if result == z3.unsat:
            self.model = None
            return self.UNSAT

        self.model = None
        return self.UNKNOWN

    def Eq(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs, rhs = self._coerce_eq_pair(lhs, rhs)
        return self._bool_node(lhs == rhs)

    def Ne(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs, rhs = self._coerce_eq_pair(lhs, rhs)
        return self._bool_node(lhs != rhs)

    def Ugt(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs, rhs = self._coerce_bv_pair(lhs, rhs)
        return self._bool_node(z3.UGT(lhs, rhs))

    def Ugte(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs, rhs = self._coerce_bv_pair(lhs, rhs)
        return self._bool_node(z3.UGE(lhs, rhs))

    def Ult(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs, rhs = self._coerce_bv_pair(lhs, rhs)
        return self._bool_node(z3.ULT(lhs, rhs))

    def Ulte(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs, rhs = self._coerce_bv_pair(lhs, rhs)
        return self._bool_node(z3.ULE(lhs, rhs))

    def Sgt(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs, rhs = self._coerce_bv_pair(lhs, rhs)
        return self._bool_node(lhs > rhs)

    def Sgte(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs, rhs = self._coerce_bv_pair(lhs, rhs)
        return self._bool_node(lhs >= rhs)

    def Slt(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs, rhs = self._coerce_bv_pair(lhs, rhs)
        return self._bool_node(lhs < rhs)

    def Slte(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs, rhs = self._coerce_bv_pair(lhs, rhs)
        return self._bool_node(lhs <= rhs)

    def Add(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs, rhs = self._coerce_bv_pair(lhs, rhs)
        return self._bv_node(lhs + rhs, lhs.size())

    def Sub(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs, rhs = self._coerce_bv_pair(lhs, rhs)
        return self._bv_node(lhs - rhs, lhs.size())

    def Mul(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs, rhs = self._coerce_bv_pair(lhs, rhs)
        return self._bv_node(lhs * rhs, lhs.size())

    def Udiv(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs, rhs = self._coerce_bv_pair(lhs, rhs)
        return self._bv_node(z3.UDiv(lhs, rhs), lhs.size())

    def Urem(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs, rhs = self._coerce_bv_pair(lhs, rhs)
        return self._bv_node(z3.URem(lhs, rhs), lhs.size())

    def And(self, *nodes: BoolectorNode) -> BoolectorNode:
        if not nodes:
            return self.Const(1, 1)
        if all(node._is_bool for node in nodes):
            return self._bool_node(z3.And(*[node.expr for node in nodes]))

        width = max(node.width for node in nodes)
        exprs = [self._as_bv(node, width) for node in nodes]
        return self._bv_node(reduce(lambda lhs, rhs: lhs & rhs, exprs), width)

    def Or(self, *nodes: BoolectorNode) -> BoolectorNode:
        if not nodes:
            return self.Const(0, 1)
        if all(node._is_bool for node in nodes):
            return self._bool_node(z3.Or(*[node.expr for node in nodes]))

        width = max(node.width for node in nodes)
        exprs = [self._as_bv(node, width) for node in nodes]
        return self._bv_node(reduce(lambda lhs, rhs: lhs | rhs, exprs), width)

    def Xor(self, *nodes: BoolectorNode) -> BoolectorNode:
        if not nodes:
            return self.Const(0, 1)
        if all(node._is_bool for node in nodes):
            return self._bool_node(reduce(z3.Xor, [node.expr for node in nodes]))

        width = max(node.width for node in nodes)
        exprs = [self._as_bv(node, width) for node in nodes]
        return self._bv_node(reduce(lambda lhs, rhs: lhs ^ rhs, exprs), width)

    def Not(self, node: BoolectorNode, *_unused: BoolectorNode) -> BoolectorNode:
        if node._is_bool:
            return self._bool_node(z3.Not(node.expr))
        return self._bv_node(~self._as_bv(node), node.width)

    def Sll(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs_bv = self._as_bv(lhs)
        rhs_bv = self._as_bv(rhs, lhs.width)
        return self._bv_node(lhs_bv << rhs_bv, lhs.width)

    def Srl(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        lhs_bv = self._as_bv(lhs)
        rhs_bv = self._as_bv(rhs, lhs.width)
        return self._bv_node(z3.LShR(lhs_bv, rhs_bv), lhs.width)

    def Uext(self, node: BoolectorNode, amount: int) -> BoolectorNode:
        if amount <= 0:
            return node
        return self._bv_node(z3.ZeroExt(amount, self._as_bv(node)), node.width + amount)

    def Sext(self, node: BoolectorNode, amount: int) -> BoolectorNode:
        if amount <= 0:
            return node
        return self._bv_node(z3.SignExt(amount, self._as_bv(node)), node.width + amount)

    def Slice(self, node: BoolectorNode, upper: int, lower: int) -> BoolectorNode:
        upper = int(upper)
        lower = int(lower)
        if upper < lower:
            raise ValueError(f"Slice upper bound {upper} is less than lower bound {lower}")
        return self._bv_node(
            z3.Extract(int(upper), int(lower), self._as_bv(node)),
            upper - lower + 1,
        )

    def Cond(
        self,
        cond: BoolectorNode,
        true_node: BoolectorNode,
        false_node: BoolectorNode,
    ) -> BoolectorNode:
        cond_expr = self._as_bool(cond)
        if true_node._is_bool or false_node._is_bool:
            return self._bool_node(
                z3.If(cond_expr, self._as_bool(true_node), self._as_bool(false_node))
            )

        width = max(true_node.width, false_node.width)
        return self._bv_node(
            z3.If(cond_expr, self._as_bv(true_node, width), self._as_bv(false_node, width)),
            width,
        )

    def Implies(self, lhs: BoolectorNode, rhs: BoolectorNode) -> BoolectorNode:
        return self._bool_node(z3.Implies(self._as_bool(lhs), self._as_bool(rhs)))

    def _bool_node(self, expr: z3.BoolRef) -> BoolectorNode:
        return BoolectorNode(self, expr, 1, is_bool=True)

    def _bv_node(self, expr: z3.BitVecRef, width: int) -> BoolectorNode:
        return BoolectorNode(self, expr, int(width))

    def _as_bool(self, node: BoolectorNode) -> z3.BoolRef:
        if node._is_bool:
            return node.expr
        return self._as_bv(node) != z3.BitVecVal(0, node.width)

    def _as_bv(self, node: BoolectorNode, width: int | None = None) -> z3.BitVecRef:
        target_width = node.width if width is None else int(width)
        if target_width < 1:
            raise ValueError(f"Bit-vector width must be positive, got {target_width}")

        if node._is_bool:
            expr = z3.If(
                node.expr,
                z3.BitVecVal(1, target_width),
                z3.BitVecVal(0, target_width),
            )
            return expr

        expr = node.expr
        if target_width == node.width:
            return expr
        if target_width > node.width:
            return z3.ZeroExt(target_width - node.width, expr)
        return z3.Extract(target_width - 1, 0, expr)

    def _coerce_bv_pair(
        self,
        lhs: BoolectorNode,
        rhs: BoolectorNode,
    ) -> tuple[z3.BitVecRef, z3.BitVecRef]:
        width = max(lhs.width, rhs.width)
        return self._as_bv(lhs, width), self._as_bv(rhs, width)

    def _coerce_eq_pair(
        self,
        lhs: BoolectorNode,
        rhs: BoolectorNode,
    ) -> tuple[z3.ExprRef, z3.ExprRef]:
        if lhs._is_bool or rhs._is_bool:
            return self._as_bool(lhs), self._as_bool(rhs)
        return self._coerce_bv_pair(lhs, rhs)
