# util/vendor.py: Vendor-in Components

Not all code contained in this repository is actually developed within this repository.
Code which we include from external sources is placed in `vendor` sub-directories (e.g. `hw/vendor`) and copied over from upstream sources.
The process of copying the upstream sources is called vendoring, and it is automated by the `util/vendor` tool.

The `util/vendor` tool can go beyond simply copying in source files: it can patch them, it can export patches from commits in a Git repository, and it can commit the resulting changes with a meaningful commit message.

## Tool usage overview

<!-- BEGIN CMDGEN util/selfdoc.py quote:util/vendor.py --help -->
```
$ util/vendor.py --help
usage: vendor [-h] [--update] [--refresh-patches] [--commit]
              [--desc-override DESC_OVERRIDES] [--verbose]
              file

A tool to copy source code from upstream into this repository. For an
introduction to using this tool, see doc/contributing/hw/vendor.md in this
repository. For full documentation, see util/doc/vendor.md.

positional arguments:
  file                  vendoring description file (*.vendor.hjson)

options:
  -h, --help            show this help message and exit
  --update, -U          Update locked version of repository with upstream
                        changes
  --refresh-patches     Refresh the patches from the patch repository
  --commit, -c          Commit the changes
  --desc-override DESC_OVERRIDES, -D DESC_OVERRIDES
                        Override a setting in the description file. Format:
                        -Dsome.key=value. Can be used multiple times.
  --verbose, -v         Verbose
```
<!-- END CMDGEN -->

## The vendor description file

For each vendored-in component a description file must be created, which serves as input to the `util/vendor` tool.
The vendor description file is stored in `vendor/<vendor>_<name>.vendor.hjson`.
By convention all imported code is named `<vendor>_<name>`, with `<vendor>` typically being the GitHub user or organization name, and `<name>` the project name.
It is recommended to use only lower-case characters.

A full commented example of a vendor description file is given below.
All relative paths are relative to the description file.
Optional parts can be removed if they are not used.

```
{
  // Name of the vendored-in project
  name: "other_project",

  // Target directory: typically equal to the name
  // All imported code is copied into this directory
  target_dir: "other_project",

  // Git upstream source code repository
  upstream: {
    // Upstream Git repository URL. HTTPS URLs are preferred.
    url: "https://github.com/vendor-org/other-project",
    // Upstream revision or branch. Can be a commit hash or a branch name.
    rev: "my-branch-foo",
  },

  // Optional: Pick specific files or subdirectories from upstream and
  // specify where to put them.
  mapping: [
    {from: 'src', to: 'the-source'},
    {from: 'doc', to: 'some/documentation', patch_dir: 'doc_patches'}
  ]

  // Optional: Apply patches from the following directory to the upstream
  // sources
  patch_dir: "patches/other_project",

  // Optional: Update patches in |patch_dir| from a Git repository
  // If util/vendor is run with --refresh-patches, all commits in the repository
  // at |url| between |rev_base| and |rev_patched| are exported into the
  // |patch_dir|, replacing all existing patches.
  patch_repo: {
    url: "git@github.com:pavona/other-patch.git",
    rev_base: "3aa544f6",
    rev_patched: "ee041e0",
  },

  // Optional: Exclude files or directories from the upstream sources
  // The standard glob wildcards (*, ?, etc.) are supported.
  exclude_from_upstream: [
    "src/top.sv",
    "src_files.yml",
  ]
}
```

If only the contents of a single subdirectory (including its children) of an upstream repository are to be copied in, the optional `only_subdir` key of can be used in the `upstream` section to specify the subdirectory to be copied.
The contents of that subdirectory will populate the `target_dir` directly (without any intervening directory levels).

For a more complicated set of copying rules ("get directories `A/B` and `A/C` but not anything else in `A`"), use a `mapping` list.
Each element of the list should be a dictionary with keys `from` and `to`.
The value of `from` should be a path relative to the source directory (either the top of the cloned directory, or the `only_subdir` subdirectory, if set).
The value of `to` should be a path relative to `target_dir`.

If `patch_dir` is supplied, it names a directory containing patches to be applied to the vendored code.
If there is no `mapping` list, this directory's patches are applied in lexicographical order relative to `target_dir`.
If there is a mapping list, each element of the list may contain a `patch_dir` key.
The value at that key is a directory, relative to the global `patch_dir` and patches in that directory are applied in lexicographical order relative to the target directory of the mapping, `to`.

In the example vendor description file below, the mpsse directory is populated from the chromiumos platform2 repository, extracting just the few files in the trunks/ftdi subdirectory.

```
{
  name: "mpsse",
  target_dir: "mpsse",

  upstream: {
    url: "https://chromium.googlesource.com/chromiumos/platform2/",
    rev: "master",
    only_subdir: "trunks/ftdi",
  },
}
```

## Updating and The Vendor Lock File

In order to document which version of a repository has been cloned and committed to the repository with the vendor tool, a vendor lock file is stored in `vendor/<vendor>_<name>.lock.hjson`.
This contains only the upstream information, including the URL and the exact git revision that was cloned.

Beyond just documentation, this enables users to re-clone the previously-cloned upstream repository -- including re-applying patches, choosing subdirectories, and excluding additional files -- without having to integrate any upstream changes.
Indeed the default behavior of the vendor tool is to use the upstream information from `<vendor>_<name>.lock.hjson` if this file exists.

Once the lock file exists, the vendor tool will only use the upstream information in `<vendor>_<name>.vendor.json` if the `--update` command-line option is used.

## Examples

### Re-clone code and apply new file exclusions or patches

```command
$ cd $REPO_TOP
$ ./util/vendor.py hw/vendor/google_riscv-dv.vendor.hjson -v
```

### Update code and commit the new code

This will generate a commit message based off the git shortlog between the
previously cloned revision and the newly cloned revision of the repository.

```command
$ cd $REPO_TOP
$ ./util/vendor.py hw/vendor/google_riscv-dv.vendor.hjson -v --update --commit
```
