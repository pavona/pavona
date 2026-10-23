#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Script that invokes Bazel to build and deploy software collateral for a simulation.

MOTIVE
------
Bazel is used to build device software for Pavona.
Many different software binaries may be run on or loaded into a Pavona
system in simulation, which Bazel Targets are used to define and build.

Bazel rules can output multiple files, and the software collateral that
is actually needed by the simulator may be different depending on configuration,
such as if the binary is scrambled/unscrambled, .vmem or .bin format, etc.
Our rules are designed to build many possible pieces of collateral at once, all
with the same common root filename, but with different suffixes and file extensions
that differentiate their formats and uses.
To 'connect' a particular piece of software collateral with the correct
mechanism to load it into the sim, we append some extra metadata to the Bazel
Label. We refer to this extra data as 'flags'. The first flag is always the
integer 'index', which identifies which device memory system the image should be
loaded into (e.g. ROM, OTP, Flash, etc). The flag "signed" is used to set the SW
image extension correctly. The flag "test_in_rom" is used to indicate a test runs
directly out of ROM instead of flash. There are more possible flags documented below.

A string for each sw image (root filename + index + flags) is also passed through
to the testbench, which re-parses it (in chip_env_cfg.sv) to extract the index and
flags which determines which piece of collateral should be loaded (by filename)
to which simulated memory model.

ACTIONS
-------
- Loop through the list of 'sw_images' provided (label + flags)
- Build the Bazel Target for each label
- Use Bazel 'cquery' to locate the output files for the target
- Copy the output files to the simulation working directory

With --prebuild, the same is done for the software of many tests at once, into
the cache their sw_build steps copy from (--cache-dir), ahead of the runs.

CACHING
-------
dvsim gives each of its invocations a directory of its own (--cache-dir),
holding one entry per distinct set of images the selected tests need. The
prebuild fills it before the runs start, and each test then copies its own
images out of it instead of building them.

That directory is new on every dvsim invocation, so an entry is never stale.
A new directory does not mean a rebuild, though: Bazel compiles only what has
changed, so the prebuild usually just copies software it had already built.
The last few of these directories are kept and older ones are removed.

A test whose images are not in the cache builds them itself. That happens when
the cfg sets no prebuild command, and when the prebuild ran but could not build
those particular images.

DETAILS
-------
The arg `sw_images` is a space-separated list of images required for a test.
Each item in the list may have additional metadata / flags appended using
the delimiter ':'.

Expected format:

  <package>:<target>:<index>:<flag1>:<flag2>:...
  ↑                 ↑
  └──────label──────┘

e.g.

  //sw/device/silicon_creator/manuf/base/binaries:ft_personalize_sival:1:silicon_creator:signed
  ↑                                                                   ↑ ↑               ↑     ↑
  └──────────────────────────────label────────────────────────────────┴─┴─────flag1─────┴flag2┘
                                                                     index

If one delimiter is detected, then the full string is considered to be the
<label> (i.e. package+target).
If two delimiters are detected, then it must be <label> followed by <index>.
All trailing <flags> after the <index> are optional.
Flags have no specific schema, and ordering of flags (after the index) is not significant.
A list 'KNOWN_FLAGS' is maintained in this file to ensure each flag is documented.

After the Bazel Target is built, we use `bazel cquery` to locate the built
software artifacts so they can be copied to the test bench run directory.
We only copy device SW images, and do not copy host-side artifacts (like
opentitantool) that are also dependencies of the Bazel test target.
"""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import os
import sys
import shutil
import shlex
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional
import textwrap
import time

import logging

logger = logging.getLogger(__name__)

BAZEL_COMMON_CQUERY_FLAGS = ["--ui_event_filters=-info", "--noshow_progress"]

BAZEL_RETRYABLE_ERROR = "BUILD file not found in directory '' of external repository"
BAZEL_RETRY_DELAY_SECS = 30

# Query files (passed via --starlark:file)
BAZEL_STARLARK_FILE_DATA_RUNFILES_FILES_QUERY = (
    Path(__file__).parent / "queries" / "DATA_RUNFILES_FILES_QUERY.cquery"
).absolute()
BAZEL_STARLARK_FILE_FILES_QUERY = (
    Path(__file__).parent / "queries" / "FILES_QUERY.cquery"
).absolute()

# The following dict maps rule kinds to the starlark expression required
# to print the files we need to deploy from them.
BAZEL_STARLARK_QUERY_RULE_KIND = {
    "pavona_test": BAZEL_STARLARK_FILE_DATA_RUNFILES_FILES_QUERY,
    "pavona_binary": BAZEL_STARLARK_FILE_FILES_QUERY,
    "alias": BAZEL_STARLARK_FILE_FILES_QUERY,
}

ENV = os.environ.copy()

# Keep all flags documented.
KNOWN_FLAGS = [
    # Rules generated by the 'pavona_test' macro
    "new_rules",
    # Tests that run in ROM instead of Flash
    "test_in_rom",
    # For pre-compiled binaries (i.e. outside of the normal flow)
    "prebuilt",
    # Manually added when instantiating rules to use a flash image built for
    # the `silicon_creator` device. This is used for GLS tests that integrate
    # the ROM macro, which is built for the `silicon_creator` device, not the
    # `sim_dv` device.
    "silicon_creator",
    # Used to mark tests generated by the `pavona_flash_binary` or `pavona_binary`
    # Bazel macros directly, instead of the `pavona_test` macro.
    "ot_flash_binary",
    # If the image builds a signed binary, then this flag should be added to
    # correctly locate the output binary by name.
    "signed",
    # Also used to mark images that build binaries signed with fake keys, to
    # then also correctly locate the output binary by name.
    "fake_ecdsa_dev_key_0",
    "fake_ecdsa_prod_key_0",
    "fake_ecdsa_test_key_0",
    "fake_rsa_dev_key_0",
    "fake_rsa_prod_key_0",
    "fake_rsa_test_key_0",
    # Don't filter out runfiles for other sw_build_devices if this flag is present
    "dont_filter",
]

""" This enum should match the enum in `hw/top_<>/dv/env/chip_env_pkg.sv`. """


class sw_type_e(Enum):
    SwTypeROM = 0  # Ibex SW - first stage boot ROM.
    SwTypeTestSlotA = 1  # Ibex SW - test SW in (flash) slot A.
    SwTypeTestSlotB = 2  # Ibex SW - test SW in (flash) slot B.
    SwTypeACC = 3  # Acc SW
    SwTypeOtp = 4  # Customized OTP image
    SwTypeDebug = 5  # Debug SW - injected into SRAM.
    SwTypeCtnRAM = 6  # Ibex SW - test SW in CTN SRAM.
    SwTypeSecondROM = 7  # Ibex SW - second stage boot ROM


class BazelRunner:
    """A collection of functions useful for running Bazel operations."""

    def __init__(self):
        self.cmd = ""
        self.airgapped_opts = []
        self.build_opts = []
        self.cquery_opts_common = list(BAZEL_COMMON_CQUERY_FLAGS)

    def __str__(self):
        s = textwrap.dedent(f"""
        BazelRunner:
          cmd={self.cmd}
          airgapped_opts={self.airgapped_opts}
          build_opts={self.build_opts}
          cquery_common_opts={self.cquery_opts_common}
        """)
        return s

    def build(self, labels: list[str], opts: list[str] = [], check: bool = True) -> bool:
        """Build the labels. Returns whether the build succeeded.

        With check, a failed build exits the script instead.
        """
        build_cmd = (
            self.cmd,
            "build",
            *self.airgapped_opts,
            *self.build_opts,
            *labels,
            *opts,
        )
        logger.info(f"build_cmd = {' '.join(build_cmd)}")
        return self._run_cmd(build_cmd, check=check) is not None

    def query(self, label: str, opts: list[str]) -> list[str]:
        query_cmd = (
            self.cmd,
            "query",
            *self.airgapped_opts,
            label,
            *opts,
        )
        logger.info(f"query_cmd = {' '.join(query_cmd)}")
        return self._run_cmd(query_cmd)

    def cquery(self, label: str, opts: tuple[str]) -> tuple[str]:
        cquery_cmd = (
            self.cmd,
            "cquery",
            *self.airgapped_opts,
            label,
            *self.cquery_opts_common,
            *opts,
        )
        logger.info(f"cquery_cmd = {' '.join(cquery_cmd)}")
        return self._run_cmd(cquery_cmd)

    def info(self, key: str) -> str:
        """Return a single value from `bazel info`, e.g. "execution_root"."""
        info_cmd = (
            self.cmd,
            "info",
            *self.airgapped_opts,
            key,
        )
        logger.info(f"info_cmd = {' '.join(info_cmd)}")
        return self._run_cmd(info_cmd)[0]

    def _run_cmd(self, cmd: list[str], check: bool = True) -> Optional[list[str]]:
        """Run a single subprocess command.

        Returns:
            Each (non-empty) line of the stdout as a list of strings. If the
            command fails, exits the script, or without check returns None.
        """

        cmd = [x for x in cmd if x]  # Remove empty strings
        logger.debug(f"_run_cmd -> cmd:\n{cmd}")

        res = subprocess.run(cmd, capture_output=True, encoding="utf-8", text=True)
        if res.returncode != 0 and BAZEL_RETRYABLE_ERROR in res.stderr:
            logger.warning(
                "_run_cmd -> an external repository was incomplete, "
                f"retrying in {BAZEL_RETRY_DELAY_SECS}s:\n{res.stderr}"
            )
            time.sleep(BAZEL_RETRY_DELAY_SECS)
            res = subprocess.run(cmd, capture_output=True, encoding="utf-8", text=True)

        if res.returncode != 0:
            print("---- STDOUT ----")
            print(res.stdout, flush=True)
            print("---- STDERR ----")
            print(res.stderr, flush=True)
            if not check:
                return None
            sys.exit(f"_run_cmd -> had a non-zero return code of {res.returncode}.")

        logger.debug("_run_cmd -> stdout:\n%s\n", res.stdout)
        logger.debug("_run_cmd -> stderr:\n%s\n", res.stderr)

        stdout_lines = res.stdout.split("\n")
        return [s for s in stdout_lines if s]


@dataclass
class ImageString:
    """Parse the custom format used to add metadata to bazel targets for loading in simulation."""

    raw: str
    label: str = field(init=False)
    package: str = field(init=False)
    target: str = field(init=False)
    index: sw_type_e = field(init=False)
    flags: set[str] = field(init=False)

    def __post_init__(self):
        parts = self.raw.split(":")
        assert len(parts) >= 3, "Image string needs at least label+index at minimum."

        self.package = parts[0]
        self.target = parts[1]
        try:
            self.index = sw_type_e(int(parts[2]))
        except ValueError as e:
            sys.exit(f"Invalid index value: {e}")
        self.flags = set(parts[3:])
        self.label = f"{self.package}:{self.target}"

        for flag in self.flags:
            assert flag in KNOWN_FLAGS, f"Unknown flag '{flag}' used in sw_image '{self.raw}'"
        logger.debug(f"flags={self}")


@dataclass
class ImageQuery:
    """The metadata for each image required to locate all artifacts after building.

    The ImageQuery.label (runfile query) may be different to the ImageString.label
    (+sw_images input label) as sometimes the query label is modified to append extra metadata
    to locate the correct rule.
    One example of this is if the 'silicon_creator' flag is present, in which case
    '_silicon_creator' is appended to the query label.
    """

    image_string: ImageString
    label: str
    cquery: str
    kind: str


def _make_bazel_runner(args) -> BazelRunner:
    """Set up the Bazel invocations for the build options in args."""

    bazel_runner = BazelRunner()

    bazel_runner.cmd = "./bazelisk.sh"
    external_opts = args.sw_build_opts
    bazel_runner.build_opts = external_opts + [
        "--define",
        "DISABLE_VERILATOR_BUILD=true",
    ]
    bazel_runner.cquery_opts_common += external_opts

    # In the air-gapped environment, the following environment variable will exist.
    if ENV.get("BAZEL_PYTHON_WHEELS_REPO"):
        # We need to change our bazel invocation as follows when running air-gapped.
        bazel_runner.cmd = "bazel"
        bazel_runner.airgapped_opts = [
            "--define",
            "SPECIFY_BINDGEN_LIBSTDCXX=true",
            f"--distdir={ENV.get('BAZEL_DISTDIR')}",
            f"--repository_cache={ENV.get('BAZEL_CACHE')}",
        ]

    # Export this environment variable to build with a non-default OTP permutation
    if ENV.get("BAZEL_OTP_DATA_PERM_FLAG"):
        bazel_runner.build_opts += [
            f"--//util/design/data:data_perm={ENV.get('BAZEL_OTP_DATA_PERM_FLAG')}",
        ]

    # Print a summary of the accumulated bazel_runner configuration that we will use to
    # assemble all further bazel operations.
    logger.info(bazel_runner)
    return bazel_runner


def _image_query(image: str, args, bazel_runner: BazelRunner) -> ImageQuery:
    """Determine the label to build for an image, and the cquery for its files."""

    image_string = ImageString(image)

    if sw_type_e(image_string.index) in (
        sw_type_e.SwTypeROM,
        sw_type_e.SwTypeTestSlotA,
        sw_type_e.SwTypeTestSlotB,
        sw_type_e.SwTypeCtnRAM,
        sw_type_e.SwTypeSecondROM,
        sw_type_e.SwTypeACC,
    ):
        if "silicon_creator" in image_string.flags:
            # Add the flag `silicon_creator` when using a flash image built
            # for the `silicon_creator` device.
            # This is used for GLS tests that integrate the ROM macro, which
            # is built for the `silicon_creator` device, not the `sim_dv` device.
            #
            # Currently, the '_silicon_creator' suffix is added manually when
            # instantiating rules.
            label = f"{image_string.label}_silicon_creator"
        else:
            # If test type is `pavona_test` and the flash image was generated
            # by the `pavona_test` Bazel macro itself, or it was generated
            # by the `pavona_flash_binary` or `pavona_binary` Bazel macros,
            # then we need to append the device suffix.
            label = f"{image_string.label}_{args.sw_build_device}"

        # For this type of image, relevant files may be present in both the 'data'
        # and 'srcs' attributes of the target. Query for both.
        cquery = f"labels(data, {label}) union labels(srcs, {label})"

    else:
        # For all other values of sw_type_e, the label/query is just the label
        # passed as input (minus all trailing flags).
        label = image_string.label
        cquery = image_string.label

    # Query to determine what 'kind' the target is
    kind_query = bazel_runner.cquery(label, ["--output=label_kind"])
    kind = kind_query[0].split(" ")[0]

    return ImageQuery(image_string, label, cquery, kind)


def _image_runfiles(iq: ImageQuery, args, bazel_runner: BazelRunner) -> list[str]:
    """Return the built files to deploy for an image."""

    # First, run the query to get the maximal set of runfiles for the image
    runfiles = _get_image_runfiles(iq, bazel_runner)

    # Some rules may return runfiles for many different software devices, but
    # we only require the files for a specific device (passed by --sw-build-device)
    # Our bazel rules always append the device as the final element of the filename
    # before any extensions (the final string fragment before the first period)
    # Perform a crude string-contains check to determine if this is one of those rules,
    # and if so, remove files unrelated to this device
    dev = args.sw_build_device

    def _f_endswith_dev(f: Path) -> bool:
        f_stem = str(f).split(".")[0]
        return f_stem.endswith(dev)

    is_device_specific = any([_f_endswith_dev(Path(f)) for f in runfiles])
    if is_device_specific and ("dont_filter" not in iq.image_string.flags):
        logger.info(
            f"This query returned device_specific '{dev}' files, filtering "
            "out runfiles for other devices..."
        )
        runfiles = list(filter(lambda f: _f_endswith_dev(Path(f)), runfiles))

    return runfiles


def _exec_root(bazel_runner: BazelRunner) -> Path:
    """Return Bazel's execution root."""
    exec_root = Path(bazel_runner.info("execution_root"))
    logger.info(f"execution root: {exec_root}\n")
    return exec_root


def _deploy_software_collateral(args) -> None:
    """Build one test's software images and copy them into its run directory."""

    images_str = "\n".join(args.sw_images)
    logger.info(
        "Building and deploying collateral for the following images:\n"
        "[IMAGES]\n"
        f"{images_str}\n"
        "[RUN_DIR]\n"
        f"{args.run_dir}\n"
    )

    bazel_runner = _make_bazel_runner(args)

    # Determine the final label and cquery expression to build and get the
    # artifacts for each image.
    image_query_map = {}
    for image in args.sw_images:
        image_query_map[image] = _image_query(image, args, bazel_runner)

    logger.info("Image query parameters determined.\n")

    # Build all the software artifacts
    bazel_labels = [v.label for v in image_query_map.values()]
    logger.info("Building all labels...")
    bazel_runner.build(bazel_labels)
    logger.info("All labels built.\n")

    exec_root = _exec_root(bazel_runner)

    # Now the build is complete, deploy the files for each target
    for image in args.sw_images:
        logger.info(f"Querying runfiles for image : {image}")
        runfiles = _image_runfiles(image_query_map[image], args, bazel_runner)

        # Now copy any runfiles for this image to the test's working directory so they
        # can be accessed easily via relative path.
        _copy_files_to_run_dir(runfiles, args.run_dir, exec_root)
        runfiles_str = "\n".join(runfiles)
        logger.info(
            f"Deployed the following collateral:\n[IMAGE]\n{image}\n[FILES]\n{runfiles_str}\n"
        )


def _cache_key(args) -> str:
    """Name of the cache entry for the software of args."""
    return hashlib.sha256(json.dumps([
        args.sw_images, args.sw_build_opts, args.sw_build_device,
        ENV.get("BAZEL_OTP_DATA_PERM_FLAG", ""),
    ]).encode()).hexdigest()[:16]


def _deploy_from_cache(args) -> None:
    """Copy one test's software out of the cache, or build it in this run.

    Runs once per seed. The prebuild has normally built every set of images
    the cfg needs already, so this only copies. It falls back to building
    when the cfg prebuilds nothing, or when the prebuild could not build
    these particular images.
    """
    entry = args.cache_dir / _cache_key(args)
    complete = entry / ".complete"
    if not complete.exists():
        logger.info(f"No prebuilt software in {entry}, building it here.")
        _deploy_software_collateral(args)
        return

    files = [f for f in entry.iterdir() if f != complete]
    for f in files:
        shutil.copyfile(f, args.run_dir / f.name)
    files_str = "\n".join(str(f) for f in files)
    logger.info(f"Deployed from the software cache:\n{files_str}\n")


def _prebuild(manifest: Path, cache_dir: Path) -> None:
    """Build the software of many tests at once, into the cache they copy from.

    An entry that could not be built or deployed is left out. The tests that
    need it build it themselves, as without a prebuild, and fail with the reason.
    """
    entries = [
        argparse.Namespace(
            sw_images=_space_sep_str(e["sw_images"]),
            sw_build_opts=_space_sep_str(e["sw_build_opts"]),
            sw_build_device=e["sw_build_device"],
        )
        for e in json.loads(manifest.read_text())
    ]
    logger.info(f"Prebuilding the software of {len(entries)} set(s) of images into {cache_dir}")

    # Create scratch cache
    cache_dir.mkdir(parents=True, exist_ok=True)

    # Bazel builds one configuration per invocation
    groups: dict[tuple, list] = {}
    for e in entries:
        groups.setdefault((tuple(e.sw_build_opts), e.sw_build_device), []).append(e)

    deployed = 0
    for (opts, device), group in groups.items():
        logger.info(f"Building {len(group)} set(s) of images with {list(opts)} for {device}")
        bazel_runner = _make_bazel_runner(group[0])

        queries = {}
        for image in dict.fromkeys(i for e in group for i in e.sw_images):
            try:
                # Get real Bazel label
                queries[image] = _image_query(image, group[0], bazel_runner)
            except SystemExit as err:
                logger.error(f"Cannot resolve {image}, its tests will build it themselves: {err}")

        labels = list(dict.fromkeys(q.label for q in queries.values()))
        logger.info(f"Building {len(labels)} label(s)...")
        if not bazel_runner.build(labels, ["--keep_going"], check=False):
            logger.warning(
                "Some software did not build (see above). The tests that need it "
                "will build it themselves and report why."
            )
        exec_root = _exec_root(bazel_runner)

        runfiles = {}
        for e in group:
            key = _cache_key(e)
            entry = cache_dir / key
            # If complete exists, then it has been deployed already
            if (entry / ".complete").exists():
                deployed += 1
                continue
            shutil.rmtree(entry, ignore_errors=True)
            entry.mkdir()
            try:
                for image in e.sw_images:
                    if image not in runfiles:
                        runfiles[image] = _image_runfiles(queries[image], e, bazel_runner)
                    _copy_files_to_run_dir(runfiles[image], entry, exec_root)
            except (SystemExit, KeyError, OSError) as err:
                shutil.rmtree(entry, ignore_errors=True)
                logger.error(
                    f"Cannot deploy {' '.join(e.sw_images)}, its tests will build "
                    f"it themselves: {err!r}"
                )
                continue
            (entry / ".complete").touch()
            deployed += 1

    logger.info(f"Prebuilt {deployed} of {len(entries)} set(s) of images.")


def _get_image_runfiles(iq: ImageQuery, bazel_runner: BazelRunner) -> list[str]:
    """Run the target/kind-specific Bazel queries to get the runfiles list for this image."""

    if logger.level <= logging.INFO:
        location_query = bazel_runner.query(iq.label, ["--output=location"])
        location = location_query[0].split(" ")[0]
        logger.info(f"bazel target location: {location}")

    # Depending on the target 'kind', we may need to query differently to get the
    # path inside the bazel build hierarchy to the build results, and also to filter
    # the query only for targets / files which are strictly necessary for simulation.
    # _Note_
    # We may also want to extract collateral to assist debug and development, such as
    # disassembly files for given binaries.
    runfiles: list[str] = []

    logger.info(f"kind = {iq.kind}")
    if iq.kind in BAZEL_STARLARK_QUERY_RULE_KIND:
        # For targets of this kind, we can query directly for the set of runfiles.
        # The query may have a slightly different starlark expression to extract the
        # files from the target depending on the kind.

        runfiles = bazel_runner.cquery(
            label=iq.label,
            opts=[
                "--output=starlark",
                f"--starlark:file={BAZEL_STARLARK_QUERY_RULE_KIND[iq.kind]}",
            ],
        )

    else:
        # For all other kinds, we have to do two queries to reach the runfiles. The first
        # query may return a list of labels from the rule's attributes (e.g. data, srcs),
        # which we tidy up and filter out targets which we know will return unused dependencies.
        deps = bazel_runner.cquery(
            label=f"{iq.cquery}",
            opts=[
                "--output=starlark",
            ],
        )

        # Bazel 6 cquery outputs repository targets in canonical format (@//blabla)
        # whereas bazel 5 does not, so strip leading @ if present.
        deps = [dep.lstrip("@") for dep in deps]
        logger.info(f"deps = {deps}")

        for label in deps:
            if any(
                [
                    # - OTP preload images are copied
                    label.startswith("//hw/top_*/ip_autogen/otp_ctrl/data"),
                    # - Any deps from the following directories/packages are _not_ copied:
                    #   - hw/
                    #   - util/
                    #   - sw/host/
                    (not any(label.startswith(s) for s in ("//hw", "//util", "//sw/host"))),
                ]
            ):
                runfiles += bazel_runner.cquery(
                    label,
                    [
                        "--output=starlark",
                        f"--starlark:file={BAZEL_STARLARK_FILE_FILES_QUERY}",
                    ],
                )

    return runfiles


def _copy_files_to_run_dir(files: list[str], run_dir: Path, exec_root: Path) -> None:
    """Copy all target artifacts to the run directory.

    Relative paths are resolved against exec_root, Bazel's execution root.

    If the artifact is a .bin, and a .elf file of the same name also exists,
    also copy the equivalent .elf file.
    """

    for f in [Path(f) for f in files]:
        src = f if f.is_absolute() else exec_root / f
        shutil.copyfile(src, run_dir / f.name)
        # If we are copying a .bin file, and the corresponding .elf file exists, also copy that
        maybe_elf = src.with_suffix(".elf")
        if f.suffix == "bin" and maybe_elf.exists():
            shutil.copy(maybe_elf, run_dir)


def _space_sep_str(value):
    return list(filter(None, value.split(" ")))


def _main() -> None:
    def _int_or_str(value):
        try:
            return int(value)
        except Exception:
            return value

    parser = argparse.ArgumentParser(
        # Use the module description to generate CLI --help docs
        description=(__doc__.splitlines()[0]),
        epilog=(80 * "-" + f"\n\n{__doc__}"),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--sw-images",
        type=_space_sep_str,
        default=[],
        help="Bazel label + additional metadata to describe the needed sw collateral",
    )
    parser.add_argument(
        "--sw-build-opts",
        type=_space_sep_str,
        default=[],
        help="Additional opts to be passed while building software",
    )
    parser.add_argument("--sw-build-device")
    parser.add_argument("--seed", type=int, help="Seed")
    parser.add_argument("--build-seed", type=_int_or_str, help="Build Seed")
    parser.add_argument(
        "--run-dir",
        type=Path,
        help="Run directory where the software artifacts should be deployed to",
    )
    parser.add_argument(
        "--cache-dir",
        type=Path,
        help="Directory holding the software prebuilt for this dvsim invocation. "
        "Filled once by --prebuild; each test then copies its own images from it "
        "instead of building them.",
    )
    parser.add_argument(
        "--prebuild",
        type=Path,
        help="Build the software of every test listed in this JSON manifest into "
        "--cache-dir, instead of deploying one test's software.",
    )
    args = parser.parse_args()

    log_level = logging.INFO
    log_format = "%(levelname)s: [%(filename)s:%(lineno)d] %(message)s"
    logging.basicConfig(level=log_level, format=log_format)

    logger.info("Command: %s", shlex.join(sys.argv))
    logger.info("Parsed arguments:")
    for name, val in sorted(vars(args).items()):
        logger.info("  %s = %r", name, val)

    if args.prebuild:
        if not args.cache_dir:
            parser.error("--prebuild needs --cache-dir")
        # Whatever goes wrong, the tests build their own software, so this
        # never fails the regression.
        try:
            _prebuild(args.prebuild, args.cache_dir)
        except (Exception, SystemExit) as err:
            logger.exception(f"Prebuild stopped, the tests will build their own software: {err!r}")
    elif args.cache_dir:
        _deploy_from_cache(args)
    else:
        _deploy_software_collateral(args)


if __name__ == "__main__":
    sys.exit(_main())
