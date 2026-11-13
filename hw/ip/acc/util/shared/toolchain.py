# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import glob
import os
from typing import Optional


# GNU-style tool name -> the binary the in-tree LLVM toolchain provides.
_LLVM_TOOL_NAMES = {
    'gcc': 'clang',
    'as': 'clang',
    'ld': 'ld.lld',
    'ar': 'llvm-ar',
    'objcopy': 'llvm-objcopy',
    'objdump': 'llvm-objdump',
}


def _find_bazel_llvm_tool(tool_name: str) -> Optional[str]:
    '''Find tool_name in the Bazel LLVM toolchain under bazel-*/external/.'''
    llvm_name = _LLVM_TOOL_NAMES.get(tool_name)
    if llvm_name is None:
        return None

    repo_root = os.path.dirname(os.path.abspath(__file__))
    while not os.path.exists(os.path.join(repo_root, 'MODULE.bazel')):
        parent = os.path.dirname(repo_root)
        if parent == repo_root:
            return None
        repo_root = parent

    # The repo dir carries bzlmod-version prefixes; match its stable suffix.
    pattern = os.path.join(repo_root, 'bazel-*', 'external',
                           '*llvm_toolchain_llvm', 'bin', llvm_name)
    matches = sorted(glob.glob(pattern))
    return matches[0] if matches else None


def find_tool(tool_name: str) -> str:
    '''Return a string describing how to invoke the given RISC-V tool

    Try to resolve the tool in the following way, stopping after the first
    match:

    1. Use the path set in the RV32_TOOL_<tool_name> environment variable.
    2. Use the path set in $TOOLCHAIN_PATH/bin/riscv32-unknown-elf-<tool_name>.
    3. Look for riscv32-unknown-elf-<tool_name> in the system PATH.
    4. Look in the default toolchain install location, /tools/riscv/bin.
    5. Fall back to the in-tree LLVM toolchain under bazel-*/external/.

    For methods (1) and (2), if the expected environment variable is set but
    the tool isn't found, an error is raised. An error is also raised if none
    of methods (1)-(5) find the tool.
    '''
    tool_env_var = 'RV32_TOOL_' + tool_name.upper()
    configured_tool_path = os.environ.get(tool_env_var)
    if configured_tool_path is not None:
        if not os.path.exists(configured_tool_path):
            raise RuntimeError('No such file: {!r} (derived from the '
                               '{!r} environment variable when trying '
                               'to find the {!r} tool).'.format(
                                   configured_tool_path, tool_env_var,
                                   tool_name))
        return configured_tool_path

    expanded = 'riscv32-unknown-elf-' + tool_name
    toolchain_path = os.environ.get('TOOLCHAIN_PATH')
    if toolchain_path is not None:
        tool_path = os.path.join(toolchain_path, 'bin', expanded)
        if not os.path.exists(tool_path):
            raise RuntimeError('No such file: {!r} (derived from the '
                               'TOOLCHAIN_PATH environment variable when '
                               'trying to find the {!r} tool).'
                               .format(tool_path, tool_name))
        return tool_path

    default_location = '/tools/riscv/bin'
    paths = os.get_exec_path() + [default_location]
    for exec_path in paths:
        tool_path = os.path.join(exec_path, expanded)
        if os.path.exists(tool_path):
            return tool_path

    # Fall back to the in-tree LLVM toolchain, so standalone runs need no setup.
    llvm_tool_path = _find_bazel_llvm_tool(tool_name)
    if llvm_tool_path is not None:
        return llvm_tool_path

    llvm_name = _LLVM_TOOL_NAMES.get(tool_name, expanded)
    raise RuntimeError(
        'Unable to find the {!r} tool. The ACC tools use the in-tree LLVM '
        'toolchain, materialised by Bazel under bazel-*/external/, but {!r} '
        'was not found there (nor {!r} on PATH or in {!r}). Run any Bazel '
        'build once to fetch it (e.g. \'./bazelisk.sh build //hw/ip/acc/...\'), '
        'then retry, or set {!r} to the tool directly (RV32_TOOL_GCC/AS must '
        'be clang, RV32_TOOL_LD must be ld.lld).'
        .format(tool_name, llvm_name, expanded, default_location,
                tool_env_var))
