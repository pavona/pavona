# Git-less Repo Considerations

There are two ways to install Pavona: the first is to run `git clone` and pull the repo straight from GitHub, and the second way is to use the available tarball package (which does not retain git collateral).
Cloning the repo is the default method, as the repo utilizes some of the features of git to track changes, but the repo can still be used without being a git repo.

There are a few different ways in which the repo tries to use git that should be considered if you are using the "gitless" version of the repo:
* The repo may try to find its own top directory using git.
* The repo may try to get the hash of the current git commit or diff in order to track new changes.
* The repo may use git branch or commit details to create new (state-specific) directories.
* The repo will use git commands to vendor in code from other git repos.

If you are using the gitless tarball version of this repo, below are the ways the default repo behavior changes given that the repo is not a git repo.
Note that there is nothing stopping you from uncompressing the tarball, installing the repo requirements, and running `git init` to make it a new git repository with fresh history.

## Testing the gitless package

In this repo, there is a bash script named `ci/scripts/check-gitless.sh`.
Run this script to run a few preliminary tests to check if the repo is functioning properly.

Use the option `-e` to have the script stop after finding the first failure.
Use option `-t <dvsim_tool>` to also run some dvsim tests with a given tool.
Using `-h` will print the script usage.

This sanity check will output logs for any errors found along the way (as `gitless.log` in the repo root).

## Using Bazel and bitstream caches

This repository by default [relies on caching FPGA bitstreams](../contributing/fpga/ref_manual_fpga.md) to save time.
Because the gitless repo is not tied to a commit along the main branch, the bitstream cache can only be instantiated locally.

The script `rules/scripts/initialize_bitstream_cache.sh` can create a new bitstream cache by building the specified bitstream and initializing the correct files for the bitstream cache.
Another workaround for bitstream cache requirements is simply using the flag `--define bitstream=skip` if a bitstream has already been built or `--define bitstream=vivado` to use Vivado to build a new bitstream for any targets that require one.

## Finding the repo's top directory

In the gitless repo, scripts that need to find the top directory will simply use relative paths instead of commands like `git rev-parse --show-toplevel`.
This is the most minor and easily substituted switch between git and gitless, but it does imply that most scripts in the repo should not be moved around to different directories.

## Tracking changes

As git is a version control system, it is natural for the repo to track code changes with it.
Using the gitless repo does not have the same capabilities.

Many of the scripts in the `ci/scripts` directory use git in order to limit their linting/file checking scope.
They cannot be used in the gitless package, as they will error out.
These files include (under `ci/scripts`): [`python-lint.sh`](../../ci/scripts/python-lint.sh), [`include-guard.sh`](../../ci/scripts/include-guard.sh), [`clang-format.sh`](../../ci/scripts/clang-format.sh), [`rust-format.sh`](../../ci/scripts/rust-format.sh), [`whitespace.sh`](../../ci/scripts/whitespace.sh), [`check-licence-headers.sh`](../../ci/scripts/whitespace.sh), [`lint-commits.sh`](../../ci/scripts/lint-commits.sh).
Other similarly constrained files include: [`util/lint_commits.py`](../../util/lint_commits.py), [`util/diff_generated_util_output.py`](../../util/diff_generated_util_output.py).

A similar git functionality that simply cannot be replicated in the gitless release is git bisect, which traverses git history.
As such, [`util/fpga/bitstream_bisect.py`](../../util/fpga/bitstream_bisect.py) is unviable in gitless.

## Vendored code

This repo also vendors in some software and hardware from other quality codebases.
Git is used to patch vendored code and pull from repository remotes.
Since git is one of the install requirements for this repo, and each source of the vendored code is a git repo itself, there should be no problems here.

As the repo currently chooses to vendor, most of the functionality will still work for vendoring in code.
However, patches may not be committed to the main Pavona repo unless it is a git repo.
For more information, see the documentation on vendoring [hardware](../contributing/hw/vendor.md) and [software](../../third_party/README.md).
