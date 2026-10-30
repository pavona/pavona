# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import os
import tempfile
from pathlib import Path

from sim.load_elf import load_elf
from sim.standalonesim import StandaloneSim
from acc_as import assemble
from acc_ld import link


def asm_and_link_one_file(asm_path: str, work_dir: Path) -> str:
    """Assemble and link file at asm_path in work_dir.

    Returns the path to the resulting ELF

    """
    obj_path = Path(os.path.join(work_dir, "tst.o"))
    elf_path = Path(os.path.join(work_dir, "tst"))

    as_result = assemble(["-o", str(obj_path), str(asm_path)])
    assert as_result == 0, f"Failed to assemble test {asm_path}"
    assert obj_path.exists(), "Object file does not exist"
    ld_result = link(["-o", str(elf_path), str(obj_path)])
    assert ld_result == 0, f"Failed to link test {asm_path}"
    assert elf_path.exists(), "Elf file does not exist"
    return str(elf_path)


def prepare_sim_for_asm_file(
    asm_file: str, tmpdir: Path, collect_stats: bool
) -> StandaloneSim:
    """Set up the simulation of a single assembly file.

    The returned simulation is ready to be run through the run() method.

    """
    assert os.path.exists(asm_file)
    elf_file = asm_and_link_one_file(asm_file, tmpdir)

    sim = StandaloneSim(False)
    load_elf(sim, elf_file)

    sim.state.ext_regs.commit()
    sim.start(collect_stats)
    return sim


def prepare_sim_for_asm_str(
    assembly: str, tmpdir: Path, collect_stats: bool
) -> StandaloneSim:
    """Set up the simulation for an assembly snippet passed as string.

    The returned simulation is ready to be run through the run() method.

    """
    with tempfile.NamedTemporaryFile("w", dir=tmpdir) as fp:
        fp.write(assembly)
        fp.flush()
        return prepare_sim_for_asm_file(fp.name, tmpdir, collect_stats)
