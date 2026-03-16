# QEMU

By default, the build system will download a pre-built release of a [QEMU fork](https://github.com/lowRISC/qemu/).
In order to support local development and testing, the build system also supports a way to build QEMU from source.
See instructions below.

## Building from source using Bazel

To perform local development, you first need to check out a copy of the [QEMU fork](https://github.com/lowRISC/qemu/) and switch to the correct branch.

The following step must only be done once:
```bash
# Run the following commands at the root of your QEMU checkout.
touch REPO.bazel
ln -s "/path/to/your/repo/third_party/qemu/BUILD.qemu_opentitan.bazel" "BUILD.bazel"
```

Once done, every time you compile something using QEMU, you need to tell Bazel to use your QEMU repository instead of downloading a release archive.
This is done by passing the following command-line argument to bazel:
```
--override_repository="+qemu+qemu_pavona_src=/path/to/your/qemu/repo/"
```
For example:
```bash
./bazelisk.sh cquery --override_repository=... @qemu_opentitan//:build/qemu-system-riscv32
```
Since this can become quite tedious, you also have the option of adding this to your local bazelrc file. The recommended way of doing is to create a `.bazelrc-site` file at the root of the repo (if it doesn't exist) and add:
```
common --override_repository=...
```

**Important note:** when using this override, Bazel will essentially share your QEMU source repository.
In particular, the content of the `build/` directory will be used to support incremental compilation in Bazel.
The content of this directory can change when you run the Bazel command.
Bazel will automatically watch all files in the QEMU repository so that it can rebuild it if it changes.

# Troubleshooting

## Bazel tells me that `+qemu+qemu_pavona_src` is not a valid repository name

Unfortunately bazel requires the canonical name of the repository to be given on the command line and this name may change in the future.
If this happens, you can run the following commands to figure out the canonical name:
```bash
./bazelisk.sh mod dump_repo_mapping "" | jq .qemu_pavona_src
```
If it's not the root repository, you will need to update the above command to pass the canonical name of the repository instead of `""`.

# How does it work?

When passing `--override_repository="+qemu+qemu_pavona_src=/path/to/your/qemu/repo/"`, the `qemu_bazel_build_or_forward` repository rules detect the override by looking for a specific marker file which is added to the release archive.
If an override is detected, the repository rule will run the `build_qemu.sh` script inside the user's QEMU source directory.
This script configures QEMU if necessary and then builds everything using ninja.
Finally, it uses the release script to create a fake release archive.
The repository rule then extracts this archive into the repository so that the content looks identical to normal, downloaded release.
Finally, the repository rule also asks Bazel to watch all the files in the QEMU source directory, except for the `build/` directory.
