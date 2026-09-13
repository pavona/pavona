# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Shared seeded-RNG helpers for UVM objects."""

import os
import random
import zlib
from typing import Optional

from .dv_cocotb_utils import get_plusarg

_name_instance_counts: dict[str, int] = {}


def _base_seed_from_env() -> int:
    for key in ("DV_RANDOM_SEED", "SVSEED", "ntb_random_seed", "UVM_SEED",
                "seed"):
        value = get_plusarg(key)
        if value is not None:
            try:
                return int(value, 0)
            except ValueError:
                pass
        value = os.getenv(key)
        if value is None:
            continue
        try:
            return int(value, 0)
        except ValueError:
            continue
    return 1


def _allocate_instance_index(name: str) -> int:
    idx = _name_instance_counts.get(name, 0)
    _name_instance_counts[name] = idx + 1
    return idx


def _derive_seed(base_seed: int, name: str, instance_index: int) -> int:
    token = f"{int(base_seed)}:{name}:{int(instance_index)}"
    return zlib.crc32(token.encode("utf-8")) & 0xFFFFFFFF


def ensure_seeded_rng(obj,
                      *,
                      base_seed: Optional[int] = None,
                      name: Optional[str] = None) -> random.Random:
    """
    Ensure `obj` has a deterministic `random.Random` at `obj.random`.

    The final seed is derived from a process-wide base seed and object name,
    so each object gets an independent deterministic stream.
    """

    seed_base = _base_seed_from_env() if base_seed is None else int(base_seed)
    obj_name = name or (obj.get_name() if hasattr(obj, "get_name") and
                        callable(obj.get_name) else obj.__class__.__name__)
    instance_index = _allocate_instance_index(obj_name)
    seed = _derive_seed(seed_base, obj_name, instance_index)

    rng = getattr(obj, "random", None)
    if not isinstance(rng, random.Random):
        rng = random.Random()
        setattr(obj, "random", rng)

    rng.seed(seed)
    setattr(obj, "random_seed", seed)
    setattr(obj, "random_instance_index", instance_index)
    setattr(obj, "random_seed_base", int(seed_base))
    setattr(obj, "random_seed_name", obj_name)
    _ensure_seeded_randstate(obj, seed)
    return rng


def _ensure_seeded_randstate(obj, seed: int) -> None:
    if not hasattr(obj, "set_randstate"):
        return

    try:
        from vsc.model.rand_state import RandState
    except Exception:
        return

    obj_name = (obj.get_name() if hasattr(obj, "get_name") and
                callable(obj.get_name) else obj.__class__.__name__)
    obj.set_randstate(RandState.mkFromSeed(int(seed), obj_name))
    setattr(obj, "random_state_seed", int(seed))
