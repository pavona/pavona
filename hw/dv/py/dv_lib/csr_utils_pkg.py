# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Python CSR access helpers built on top of the DV RAL overlay."""

from __future__ import annotations

import asyncio
from enum import Enum, auto
from typing import Any

from pyral import UVM_PATH, UVM_PREDICT, UVM_STATUS

from .dv_base_reg import dv_base_reg

try:
    from cocotb.triggers import Timer, with_timeout
except ImportError:  # pragma: no cover
    Timer = None
    with_timeout = None


class compare_op_e(Enum):
    EQ = auto()
    CASE_EQ = auto()
    NE = auto()
    CASE_NE = auto()
    GT = auto()
    GE = auto()
    LT = auto()
    LE = auto()


default_timeout_ns = 2_000_000
default_spinwait_timeout_ns = 10_000_000
default_csr_blocking = True
default_csr_check = True


def get_mem_by_addr(ral, addr: int):
    aligned = addr & ~0x3
    mem = ral.default_map.get_mem_by_offset(aligned)
    if mem is None:
        raise KeyError(f"Can't find any mem with addr 0x{addr:x}")
    return mem


def get_mem_access_by_addr(ral, addr: int) -> str:
    return get_mem_by_addr(ral, addr).get_access()


def get_reg_fld_mirror_value(ral, reg_name: str, field_name: str = "") -> int:
    csr = ral.get_reg_by_name(reg_name)
    if csr is None:
        raise KeyError(f"Unknown register {reg_name}")
    if field_name:
        fld = csr.get_field_by_name(field_name)
        if fld is None:
            raise KeyError(f"Unknown field {field_name} in {reg_name}")
        return fld.get_mirrored_value()
    return csr.get_mirrored_value()


def get_csr_val_with_updated_field(field, csr_value: int,
                                   field_value: int) -> int:
    mask = field.get_mask()
    shift = field.get_lsb_pos()
    return (csr_value & ~(mask << shift)) | ((mask & field_value) << shift)


async def csr_wait(csr) -> None:
    while getattr(csr, "_access_lock").locked():
        await _sleep_ns(1)


async def csr_update(
    csr,
    check: bool = default_csr_check,
    path: UVM_PATH = UVM_PATH.DEFAULT,
    blocking: bool = default_csr_blocking,
    timeout_ns: int = default_timeout_ns,
    reg_map=None,
    user_ftdr=None,
    en_shadow_wr: bool = True,
):
    if not csr.needs_update():
        return UVM_STATUS.IS_OK
    value = 0
    for field in csr.get_fields():
        value |= field.XupdateX() << field.get_lsb_pos()
    return await csr_wr(
        ptr=csr,
        value=value,
        check=check,
        path=path,
        blocking=blocking,
        backdoor=False,
        timeout_ns=timeout_ns,
        predict=False,
        reg_map=reg_map,
        user_ftdr=user_ftdr,
        en_shadow_wr=en_shadow_wr,
    )


async def csr_wr(
    ptr,
    value: int,
    check: bool = default_csr_check,
    path: UVM_PATH = UVM_PATH.DEFAULT,
    blocking: bool = default_csr_blocking,
    backdoor: bool = False,
    timeout_ns: int = default_timeout_ns,
    predict: bool = False,
    reg_map=None,
    user_ftdr=None,
    en_shadow_wr: bool = True,
):
    if backdoor:
        return await csr_poke(ptr, value, check=check, predict=predict)
    csr, field = decode_csr_or_field(ptr)
    if field is not None:
        value = get_csr_val_with_updated_field(field, csr.get_mirrored_value(),
                                               value)
    coro = csr_wr_sub(csr, value, check, path, timeout_ns, predict, reg_map,
                      user_ftdr, en_shadow_wr)
    if blocking:
        return await coro
    return asyncio.create_task(coro)


async def csr_wr_sub(
    csr,
    value: int,
    check: bool = default_csr_check,
    path: UVM_PATH = UVM_PATH.DEFAULT,
    timeout_ns: int = default_timeout_ns,
    predict: bool = False,
    reg_map=None,
    user_ftdr=None,
    en_shadow_wr: bool = True,
):
    try:
        await csr_pre_write_sub(csr, en_shadow_wr)
        await _with_timeout(
            csr_wr_and_predict_sub(csr, value, check, path, predict, reg_map,
                                   user_ftdr),
            timeout_ns,
            f"Timeout waiting to csr_wr {csr.get_name()}",
        )
        if en_shadow_wr and isinstance(csr,
                                       dv_base_reg) and csr.get_is_shadowed():
            await _with_timeout(
                csr_wr_and_predict_sub(csr, value, check, path, predict,
                                       reg_map, user_ftdr),
                timeout_ns,
                f"Timeout waiting to second shadow csr_wr {csr.get_name()}",
            )
        return UVM_STATUS.IS_OK
    finally:
        await csr_post_write_sub(csr, en_shadow_wr)


async def csr_wr_and_predict_sub(csr, value: int, check: bool, path: UVM_PATH,
                                 predict: bool, reg_map, user_ftdr):
    if user_ftdr is not None:
        csr.set_frontdoor(user_ftdr)
    status = await csr.write(value=value, reg_map=reg_map, path=path)
    if check and status != UVM_STATUS.IS_OK:
        raise RuntimeError(f"trying to write csr {csr.get_name()}")
    if status == UVM_STATUS.IS_OK and predict:
        csr.predict(value=value,
                    kind=UVM_PREDICT.WRITE,
                    path=path,
                    reg_map=reg_map)


async def csr_pre_write_sub(csr, en_shadow_wr: bool) -> None:
    if isinstance(csr, dv_base_reg) and csr.get_is_shadowed() and en_shadow_wr:
        await csr.atomic_en_shadow_wr.acquire()


async def csr_post_write_sub(csr, en_shadow_wr: bool) -> None:
    if isinstance(csr, dv_base_reg) and csr.get_is_shadowed() and en_shadow_wr:
        if csr.atomic_en_shadow_wr.locked():
            csr.atomic_en_shadow_wr.release()


async def csr_poke(ptr,
                   value: int,
                   check: bool = default_csr_check,
                   predict: bool = False,
                   kind: str = ""):
    csr, field = decode_csr_or_field(ptr)
    old_mirrored_val = field.get_mirrored_value(
    ) if field is not None else csr.get_mirrored_value()
    status = await (field.poke(value, kind=kind)
                    if field is not None else csr.poke(value, kind=kind))
    if check and status != UVM_STATUS.IS_OK:
        raise RuntimeError(f"poke failed for {ptr.get_name()}")
    if not predict or kind == "BkdrRegPathRtlShadow":
        if field is not None:
            field.predict(old_mirrored_val,
                          kind=UVM_PREDICT.DIRECT,
                          path=UVM_PATH.BACKDOOR)
        else:
            csr.predict(old_mirrored_val,
                        kind=UVM_PREDICT.DIRECT,
                        path=UVM_PATH.BACKDOOR)
    return status


async def csr_rd(
    ptr,
    check: bool = default_csr_check,
    path: UVM_PATH = UVM_PATH.DEFAULT,
    blocking: bool = default_csr_blocking,
    backdoor: bool = False,
    timeout_ns: int = default_timeout_ns,
    reg_map=None,
    user_ftdr=None,
):
    coro = csr_rd_sub(ptr, backdoor, check, path, timeout_ns, reg_map,
                      user_ftdr)
    if blocking:
        return await coro
    return asyncio.create_task(coro)


async def csr_rd_sub(ptr, backdoor: bool, check: bool, path: UVM_PATH,
                     timeout_ns: int, reg_map, user_ftdr):
    if backdoor:
        return UVM_STATUS.IS_OK, await csr_peek(ptr, check)
    csr, field = decode_csr_or_field(ptr)
    if user_ftdr is not None:
        csr.set_frontdoor(user_ftdr)

    async def _read():
        if field is not None:
            return await field.read(reg_map=reg_map, path=path)
        return await csr.read(reg_map=reg_map, path=path)

    status, value = await _with_timeout(
        _read(), timeout_ns, f"Timeout waiting to csr_rd {csr.get_name()}")
    if check and status != UVM_STATUS.IS_OK:
        raise RuntimeError(f"trying to read csr/field {ptr.get_name()}")
    return status, value


async def csr_peek(ptr,
                   check: bool = default_csr_check,
                   kind: str = "") -> int:
    del check, kind
    csr, field = decode_csr_or_field(ptr)
    if field is not None:
        _, value = await field.read(path=UVM_PATH.BACKDOOR)
        return value
    _, value = await csr.read(path=UVM_PATH.BACKDOOR)
    return value


async def csr_rd_check(
    ptr,
    check: bool = default_csr_check,
    path: UVM_PATH = UVM_PATH.DEFAULT,
    blocking: bool = default_csr_blocking,
    backdoor: bool = False,
    timeout_ns: int = default_timeout_ns,
    compare: bool = True,
    compare_vs_ral: bool = False,
    compare_mask: int = -1,
    compare_value: int = 0,
    err_msg: str = "",
    reg_map=None,
    user_ftdr=None,
):
    if not blocking:
        return asyncio.create_task(
            csr_rd_check(
                ptr,
                check=check,
                path=path,
                blocking=True,
                backdoor=backdoor,
                timeout_ns=timeout_ns,
                compare=compare,
                compare_vs_ral=compare_vs_ral,
                compare_mask=compare_mask,
                compare_value=compare_value,
                err_msg=err_msg,
                reg_map=reg_map,
                user_ftdr=user_ftdr,
            ))
    status, obs = await csr_rd(
        ptr,
        check=check,
        path=path,
        blocking=True,
        backdoor=backdoor,
        timeout_ns=timeout_ns,
        reg_map=reg_map,
        user_ftdr=user_ftdr,
    )
    csr, field = decode_csr_or_field(ptr)
    exp = field.get_mirrored_value(
    ) if field is not None else csr.get_mirrored_value()
    if compare_vs_ral:
        compare_value = exp
    if compare and status == UVM_STATUS.IS_OK:
        obs_masked = obs & compare_mask
        exp_masked = compare_value & compare_mask
        if obs_masked != exp_masked:
            raise AssertionError(
                f"{ptr.get_name()} mismatch: obs=0x{obs_masked:x} exp=0x{exp_masked:x} {err_msg}"
            )
    return status, obs


async def read_and_check_all_csrs(ral) -> None:
    for csr in ral.get_registers():
        await csr_rd_check(csr, compare_vs_ral=True)


async def csr_spinwait(
    ptr,
    exp_data: int,
    check: bool = default_csr_check,
    path: UVM_PATH = UVM_PATH.DEFAULT,
    reg_map=None,
    user_ftdr=None,
    spinwait_delay_ns: int = 0,
    timeout_ns: int = default_spinwait_timeout_ns,
    compare_op: compare_op_e = compare_op_e.EQ,
    backdoor: bool = False,
):

    async def _poll():
        while True:
            if spinwait_delay_ns:
                await _sleep_ns(spinwait_delay_ns if not backdoor else max(
                    spinwait_delay_ns, 1))
            _, read_data = await csr_rd(
                ptr,
                check=check,
                path=path,
                blocking=True,
                backdoor=backdoor,
                reg_map=reg_map,
                user_ftdr=user_ftdr,
            )
            if _compare(read_data, exp_data, compare_op):
                return read_data

    return await _with_timeout(_poll(), timeout_ns,
                               f"timeout {ptr.get_name()} exp=0x{exp_data:x}")


def decode_csr_or_field(ptr) -> tuple[Any, Any]:
    if hasattr(ptr, "get_fields"):
        return ptr, None
    if hasattr(ptr, "get_parent"):
        return ptr.get_parent(), ptr
    raise TypeError(f"Unsupported CSR object type: {type(ptr)!r}")


def _compare(read_data: int, exp_data: int, compare_op: compare_op_e) -> bool:
    if compare_op in {compare_op_e.EQ, compare_op_e.CASE_EQ}:
        return read_data == exp_data
    if compare_op in {compare_op_e.NE, compare_op_e.CASE_NE}:
        return read_data != exp_data
    if compare_op == compare_op_e.GT:
        return read_data > exp_data
    if compare_op == compare_op_e.GE:
        return read_data >= exp_data
    if compare_op == compare_op_e.LT:
        return read_data < exp_data
    if compare_op == compare_op_e.LE:
        return read_data <= exp_data
    raise ValueError(f"invalid operator: {compare_op}")


async def _sleep_ns(delay_ns: int) -> None:
    if Timer is not None:
        await Timer(delay_ns, unit="ns")
        return
    await asyncio.sleep(delay_ns / 1_000_000_000)


async def _with_timeout(coro, timeout_ns: int, message: str):
    if with_timeout is not None:
        return await with_timeout(coro, timeout_ns, "ns")
    try:
        return await asyncio.wait_for(coro, timeout_ns / 1_000_000_000)
    except TimeoutError as exc:
        raise TimeoutError(message) from exc
