# DVSim

DVSim is a build and run system written in Python that runs a variety of EDA tool flows.
There are multiple steps involved in running EDA tool flows.
DVSim encapsulates them all to provide a single, standardized command-line interface to launch them.
While DVSim was written to support Pavona, it can be used for any ASIC project.

All EDA tool flows on Pavona are launched using the DVSim tool.
The following flows are currently supported:

* Simulations
* Coverage Unreachability Analysis (UNR)
* Formal (formal property verification (FPV), and connectivity)
* Lint (semantic and stylistic)
* Synthesis
* CDC
* RDC

## Installation

Clone the Pavona repository by following the [Getting Started](../../doc/getting_started/README.md) steps.
The rest of the documentation will assume `$REPO_TOP` as the root of the local Pavona repository.
DVSim is located at `$REPO_TOP/util/dvsim/dvsim.py`.

DVSim relies on the following third-party Python libraries:
* **[Hjson](https://hjson.github.io/)**: to parse the Hjson DUT configuration data.
* **[Enlighten](https://python-enlighten.readthedocs.io/en/stable/)**: to track the progress of the EDA tool flows on the console in a readable way.
* **[Mistletoe](https://pypi.org/project/mistletoe)**: to convert Markdown format to HTML, used for testplan descriptions and EDA tool flow reports.
* **[Premailer](https://pypi.org/project/premailer/)**: to inline a block of CSS into the generated HTML report.
* **[cssutils](https://pypi.org/project/cssutils/)**: the CSS parser Premailer uses. DVSim imports it directly only to set its log level, so that CSS warnings do not drown out the flow's own output.
* **[Beautiful Soup](https://pypi.org/project/beautifulsoup4/)**: to query and rewrite the generated HTML, which is how report tables get tagged for styling and how an entry is added to a dashboard index.
* **[Tabulate](https://pypi.org/project/tabulate/)**: to pretty-print tabular data when displaying the report on the console.

These dependencies are already listed in `$REPO_TOP/python-requirements.txt`.
See [Python Environment Setup](../../doc/getting_started/setup_python.md) for how to install them.

## Quick start

Run the smoke regression for a block, on the local machine:

```
util/dvsim/dvsim.py hw/ip/uart/dv/uart_sim_cfg.hjson -i smoke --local
```

List what a configuration offers before running it:

```
util/dvsim/dvsim.py hw/ip/uart/dv/uart_sim_cfg.hjson --list
```

Name a tool when you want a specific one rather than the configuration's default:

```
util/dvsim/dvsim.py hw/top_egret/lint/top_egret_lint_cfgs.hjson --tool veriblelint
```

The rest of this page covers where the output goes, how a job is judged to have passed,
reproducing a failure, waves, coverage, timeouts and publishing, and ends with every switch
DVSim accepts.
For the terms used here, see the [glossary](./doc/glossary.md).
For how DVSim is put together internally, see the [design document](./doc/design_doc.md).

## Invocation

Every invocation names one configuration Hjson file, and optionally a list of things to run from it.

```
util/dvsim/dvsim.py hw/ip/uart/dv/uart_sim_cfg.hjson -i smoke
```

The positional configuration file argument is easy to lose in a long command line.
Either put it first, as above, or end the options with `--`:

```
util/dvsim/dvsim.py -i smoke -- hw/ip/uart/dv/uart_sim_cfg.hjson
```

`-i` defaults to `smoke`, so a bare invocation runs the smoke regression.

A configuration can name the tool itself, in any flow, and most do: the synthesis, formal, CDC
and RDC configurations default to `dc`, `jaspergold`, `meridiancdc` and `meridianrdc`
respectively, and each block's simulation configuration names its simulator, commonly `vcs`.
`--tool` is how you pick a different one, and it wins over whatever the configuration says.

```
util/dvsim/dvsim.py hw/ip/uart/dv/uart_sim_cfg.hjson -i smoke --tool xcelium
```

The lint configurations are the case where `--tool` is not optional.
They support several lint tools and select the tool-specific configuration by name, so they
deliberately set no default:

```
util/dvsim/dvsim.py hw/top_egret/lint/top_egret_lint_cfgs.hjson --tool veriblelint
```

A simulation run with no tool from either source is a fatal error.

## Finding out what a configuration offers

`--list` parses the configuration and prints what can be run, without running anything:

```
util/dvsim/dvsim.py hw/ip/uart/dv/uart_sim_cfg.hjson --list
```

The output can be narrowed to one or more of `build_modes`, `run_modes`, `tests` and `regressions`:

```
util/dvsim/dvsim.py hw/ip/uart/dv/uart_sim_cfg.hjson --list tests regressions
```

`-i` accepts both test names and regression names, mixed freely.
Names are matched as shell-style globs, so `-i uart_tx_*` runs every test whose name starts
with `uart_tx_`.
Matching is case-sensitive, which matters for the per-stage regressions DVSim derives from the
testplan: those are `V1`, `V2`, `V2S` and `V3`, not `v1`.

## Primary configurations

A [primary configuration](./doc/glossary.md#primary-configuration) lists other configurations rather than tests.
Running one runs every configuration it names, and produces a summary report across all of them.

`--select-cfgs` restricts the run to named configurations:

```
util/dvsim/dvsim.py hw/top_egret/dv/top_egret_sim_cfgs.hjson --select-cfgs uart i2c
```

`--cfg-groups` selects instead by a named group defined in the primary configuration.
A group is a `cfgs` list plus optional overrides, and the overrides are applied to the
selected configurations' tests:

```hjson
cfg_groups: {
  nightly_long: {
    cfgs: ["uart", "i2c"]
    run_timeout_mins: 240
    reseed: 50
  }
}
```

The overrides a group may set are `reseed`, `run_timeout_mins` and `run_timeout_multiplier`.
They sit above the regression and test settings and below anything passed on the command line.
`--cfg-groups` selects configurations only; `-i` still chooses which tests or regressions run
within them.
`--select-cfgs` takes precedence over `--cfg-groups` when both are given.

## Where the output goes

DVSim writes everything below a [scratch root](./doc/glossary.md#scratch-directory), keyed by branch so that two branches do not
collide:

```
{scratch_root}/{branch}/{name}-{flow}-{tool}/
```

`{scratch_root}` comes from `--scratch-root`, else from the `SCRATCH_ROOT` environment
variable, else defaults to `./scratch`.
`{branch}` comes from `--branch`, else from the current git branch, with slashes replaced by
dashes.
That directory, called the scratch path, is printed near the top of the log of every run.

Inside it, a simulation flow lays out:

| Path                          | Contents                                                           |
| ----------------------------- | ------------------------------------------------------------------ |
| `{build_mode}/`               | One build. `build.log` is the tool log, `env_vars` the environment. |
| `{index}.{test}/latest/`      | The most recent run of that test. `run.log` is the tool log.        |
| `{index}.{test}/{timestamp}/` | Earlier runs of the same test, kept as a backup.                    |
| `reports/latest/report.html`  | The full report for this invocation.                                |
| `reports/latest/report.json`  | The same results as machine-readable data, one entry per seed.      |
| `dispatched/`, `passed/`, `failed/`, `killed/` | Symbolic links to job directories by outcome.      |

The `dispatched`, `passed`, `failed` and `killed` directories are the fastest way to reach a
failing run: the link is created as soon as the job retires, so it is there while the rest of
the regression is still going.

Each time a job runs, its previous `latest` directory is renamed to the timestamp at which it
was created.
`--max-odirs` sets how many of those backups to keep, defaulting to 5.
`--purge` clears the scratch directory before starting.
`--build-unique` appends a timestamp to the build directory, so a second invocation from
another terminal does not disturb a build already in progress.

## Reading the result

The console shows a status line per job category that refreshes every `--print-interval`
seconds, defaulting to 10.
A shortened report is printed to the console when the run finishes, and the full version is
written to `reports/latest/report.html`.

A job's outcome is not the tool's exit code.
Tools exit zero when the tool itself worked, which says nothing about whether the test passed.
DVSim decides by matching patterns in the job's log: every pass pattern must appear, and no
fail pattern may.
A job that hits a license error pattern is reported as killed rather than failed, so that a
license outage does not read as a DV failure.

Failures are grouped by the similarity of their error signature, so a report of a hundred
failing seeds normally reduces to a handful of distinct problems.

### Where the run's data ends up

`reports/latest/report.html` is the readable report and `reports/latest/report.json` is the
same run as data.
Reports are kept for 90 days, with older ones under sibling timestamped directories.

`report.json` is the record to query rather than scrape, and it holds two views of the run.
`results` is the aggregated view: `testpoints` with their stage and per-test pass counts,
`unmapped_tests`, `testplan_stage_summary`, `coverage` percentages, and `failure_buckets`
carrying each failing seed's log path, line number and surrounding text.
`tests` is the raw view, one entry per seed, and it exists only in the JSON:

| Field                              | Meaning                                                    |
| ---------------------------------- | ------------------------------------------------------------ |
| `seed`, `status`, `start`          | The seed, its `P`/`F`/`K` outcome, and when it launched.    |
| `wall_time_s`, `cpu_time_s`        | Wall clock time and the tool's own reported runtime.        |
| `simulated_time_us`               | How much simulated time the test covered.                   |
| `peak_rss_mb`, `data_structure_size_mb` | Peak resident set size and the tool's data structure size. |
| `odir_size_mb`                     | Disk the run directory took.                                |
| `fail_msg`                         | Why it failed or was killed. For a killed job this is the only record of the reason. |

Alongside these, the top level names the block, variant, tool, timestamp, git revision and
branch, and the build seed when one was used.

For simulations, `--map-full-testplan` annotates the complete testplan with the results, rather
than only the testpoints touched by this run.

## Seeds and reseeding

Each simulation run gets a randomly picked seed unless told otherwise, and reruns of the same
test are distinguished by seed and by an integer index in the run directory name.

- `--reseed N` overrides the configured reseed count and runs each test N times.
- `--reseed-multiplier N` scales each configured reseed count by N, which keeps the ratio
  between tests intact while running more of everything.
- `--fixed-seed S` runs everything with seed S, and implies `--reseed 1`.
- `--seeds S1 S2 ...` assigns specific seeds to the items in the order they are run.
- `--reseed-source PATH` takes the per-test reseed counts from an Hjson file instead of from
  the configuration.
- `--build-seed` randomizes the build itself, which is what exercises unpacked-array and
  variable initialization randomization.

The file `--reseed-source` reads is produced by `util/grade_regression_vcs.py`, which grades a
finished regression and works out how many seeds each test is worth keeping.
It runs `urg` over the merged coverage database, so it is VCS only, and it finds its inputs by
looking for `<unit>-sim-vcs` directories under a regression root:

```
util/grade_regression_vcs.py /path/to/scratch/<branch> -o grading_report.hjson
util/dvsim/dvsim.py hw/ip/uart/dv/uart_sim_cfg.hjson -i nightly --reseed-source grading_report.hjson
```

Extending grading to the other simulators is TBD: each one reports graded and unique tests in
its own format, so the parsing and the merged database discovery both need a tool-neutral
equivalent before `--reseed-source` can be fed from an Xcelium or Questa run.

To reproduce a failure, take the seed from the report or from the failing run's `run.log` and
pass it back:

```
util/dvsim/dvsim.py hw/ip/uart/dv/uart_sim_cfg.hjson -i uart_smoke --fixed-seed 1234567890 -w fsdb
```

## Waves and debug

Waves are off by default because they cost time and disk.
`--waves` turns them on and takes the format: `fsdb`, `shm`, `vpd`, `vcd`, `evcd` or `fst`.
Which formats a configuration supports is declared by `supported_wave_formats`.

`--max-waves` caps how many runs dump waves, defaulting to 5, which keeps a large regression
from filling the disk.
By default a failing test is automatically rerun with waves enabled; `--no-rerun` turns that
off.

`--gui` runs the flow in the tool's GUI instead of batch mode, and `--gui-debug` additionally
enables breakpoints, live values and transaction recording, at a significant performance cost.
`--interactive` runs the job in the foreground without a GUI, passing the tool's output
through and accepting input.
All three modes require a single configuration, and GUI mode narrows that to a single test.
Timeouts do not apply in GUI mode, on the grounds that a job someone is stepping through is
not a job that has hung.
The tool also stops keeping the log current there, so the pass and fail patterns are not
applied and the outcome is not read off the log.

`--verbosity` sets the simulation's own verbosity from none to debug.
`--verbose` sets DVSim's verbosity, which is a different thing: use it when the problem is in
the flow rather than in the design.
`--dry-run` prints the commands each job would run, without running them.

## Timeouts and resource limits

Two separate clocks apply to a run.
`--run-wait-timeout-mins` bounds how long a job may sit before it starts doing work, which
normally means queueing for a license, and defaults to 180 minutes.
`--run-timeout-mins` bounds the work itself and only starts counting once the job is under way,
so a license queue cannot eat into it.
Pass `0` to the former to wait indefinitely.

`--run-timeout-multiplier` scales the configured run timeouts uniformly, which is the usual way
to run gate-level or foundry simulations without editing every test.
`--build-timeout-mins` bounds builds.
In batch mode neither clock is ever off: a job with no timeout from the configuration or the
command line falls back to 60 minutes.
GUI mode is the exception, where neither applies.

`--max-job-mem-gb` kills any single job whose peak resident set size passes the given ceiling.
Only that job dies; the rest of the regression carries on and the report says why it died.
The ceiling is only enforced by launchers that can measure a running job, which today means
`LocalLauncher`.
A batch system that runs the job on another machine applies its own memory limit instead.

`--max-parallel` caps how many jobs run at once, defaulting to 16 or to `DVSIM_MAX_PARALLEL`
if that is set.
It applies to local dispatch only; a batch system does its own scheduling.

## Coverage

`--cov` collects coverage, which adds a merge job and a report job that depend on every test in
the run.

- `--cov-merge-previous` merges the new coverage database with the one from the previous run.
- `--cov-analyze` skips building and running, and opens the coverage from the last run for
  analysis.
- `--cov-unr` runs unreachability analysis and generates a report. This supports VCS only.

## Choosing where jobs run

The [launcher](./doc/glossary.md#launcher) is chosen by the `DVSIM_LAUNCHER` environment variable, which is a property of the
site rather than of the run.
Valid values are `local`, `lsf`, `sge`, `nc`, `slurm` and `edacloud`.
An unrecognized value falls back to the local launcher with a warning.

`--local` forces local dispatch regardless of `DVSIM_LAUNCHER`, which is the quickest way to
run one test without involving the farm.
`--remote` copies the repository into the scratch area first, for launchers whose compute nodes
cannot see the working directory.
`--job-prefix` prepends a string to every tool command, which is how a wrapper such as a
profiler or a resource limiter gets in front of the tool.

## Publishing results

`--publish REPO` pushes the generated report to a GitHub repository, for example
`git@github.com:org/repo.git`.
`--publish-prev REPO` publishes the reports already sitting in the `latest` subdirectories from
an earlier invocation, without rerunning anything; it needs the flow and tool to be resolvable,
so pass `--tool` and `-i` if the configuration does not supply them.

`--publish-mode` chooses what goes out.
`public`, the default, publishes only sanitized report numbers.
`private` additionally publishes the native tool coverage databases and `report.json`, and
points the dashboard's coverage link at the native tool reports inside the published
repository.
`report.json` therefore only leaves the scratch area in `private` mode.

### Batch groups

A [batch run](./doc/glossary.md#batch-run) over a primary configuration produces one summary
table.
With dozens of configurations in it, that table is easier to read split into sections, so
`use_cfgs` accepts a dict of named [batch groups](./doc/glossary.md#batch-group) instead of a
flat list, as `hw/dv/all_sim_cfgs.hjson` does:

```hjson
use_cfgs: {
  ip: [
    "{proj_root}/hw/ip/adc_ctrl/dv/adc_ctrl_sim_cfg.hjson",
    "{proj_root}/hw/ip/aes/dv/aes_masked_sim_cfg.hjson",
  ]
  top_egret: [
    "{proj_root}/hw/top_egret/dv/chip_egret_sim_cfg.hjson",
  ]
}
```

Each group name becomes a heading row above its configurations in the summary.
The grouping is presentational: it changes how results are laid out, not what is dispatched or
in what order.
The flat list form stays valid and produces a single ungrouped table.

Publishing authenticates over SSH.
Either the `SSH_KEY_PASSPHRASE` environment variable is set, or a deploy key that needs no
passphrase is available.

## Environment variables

| Variable                     | Effect                                                                       |
| ---------------------------- | ---------------------------------------------------------------------------- |
| `DVSIM_LAUNCHER`             | Which launcher to use. Defaults to `local`.                                   |
| `DVSIM_MAX_PARALLEL`         | Default for `--max-parallel`.                                                 |
| `SCRATCH_ROOT`               | Default for `--scratch-root`.                                                 |
| `SSH_KEY_PASSPHRASE`         | Passphrase for the key used to publish results.                               |
| `GIT_SSH_COMMAND`            | Honored when DVSim checks access to the results repository.                   |
| `<PROJECT>_PYVENV`           | Python virtualenv to activate before running jobs on external machines.       |
| `<PROJECT>_PYVENV_<LAUNCHER>`| The same, for one launcher only. Takes precedence over `<PROJECT>_PYVENV`.    |

The Slurm launcher additionally reads `SLURM_QUEUE`, `SLURM_MEM`, `SLURM_CPUS_PER_TASK`,
`SLURM_MINCPUS`, `SLURM_TIMEOUT` and `SLURM_SETUP_CMD`, defaulting to `hw-m`, `16G`, `8`, `8`,
`240` and empty respectively.

## Common workflows

Run one test once, locally, with waves:

```
util/dvsim/dvsim.py hw/ip/uart/dv/uart_sim_cfg.hjson -i uart_smoke --local -r 1 -w fsdb
```

Build without running, to check that the testbench still compiles:

```
util/dvsim/dvsim.py hw/ip/uart/dv/uart_sim_cfg.hjson --build-only
```

Rerun against an existing build, skipping the build step:

```
util/dvsim/dvsim.py hw/ip/uart/dv/uart_sim_cfg.hjson -i uart_smoke --run-only
```

Run the nightly regression with coverage and publish the report:

```
util/dvsim/dvsim.py hw/ip/uart/dv/uart_sim_cfg.hjson -i nightly --cov --publish git@github.com:org/repo.git
```

## Command line reference

This section lists every switch DVSim accepts, grouped the way `dvsim.py --help` groups them.

```
util/dvsim/dvsim.py <cfg-hjson-file> [-h] [options]
```

The configuration file is positional.
Because several options take a variable number of values, put the configuration file ahead of
the options, or terminate the options with `--`.

### General

| Switch            | Default | Description                                                                                                                                  |
| ----------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `<cfg-hjson-file>` |        | The configuration Hjson file to run. Required.                                                                                               |
| `--version`       |         | Print the version and exit.                                                                                                                  |
| `--tool`, `-t`    | from cfg | The EDA tool to use, overriding the configuration's own choice. Needed where the configuration sets no default, which is the lint flow. One of `vcs`, `questa`, `xcelium`, `ascentlint`, `verixcdc`, `mrdc`, `veriblelint`, `verilator`, `dc`. |
| `--list`, `-l`    |         | Parse the configuration, list what can be run, and exit. Takes an optional space-separated filter from `build_modes`, `run_modes`, `tests`, `regressions`. |

### Choosing what to run

| Switch          | Default   | Description                                                                                                                        |
| --------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `-i`, `--items` | `smoke`   | Space-separated list of tests or regressions to run.                                                                               |
| `--select-cfgs` |           | For a primary configuration, run only the named configurations. Without it, every configuration in the primary is processed.       |
| `--cfg-groups`  |           | For a primary configuration, run only the configurations in the named `cfg_groups` and apply each group's overrides. Independent of `-i`. |

### Dispatch options

| Switch                      | Default | Description                                                                                                                       |
| --------------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `--job-prefix`              | empty   | Prepend this string to every tool command.                                                                                        |
| `--local`                   | off     | Force jobs onto the local machine, overriding `DVSIM_LAUNCHER`.                                                                   |
| `--remote`                  | off     | Copy the repository into the scratch area before dispatching.                                                                     |
| `--max-parallel`, `-mp`     | 16      | Run at most N builds or tests at a time. Falls back to `DVSIM_MAX_PARALLEL`. Local dispatch only.                                 |
| `--max-job-mem-gb`          | off     | Kill any single job whose peak resident set size passes this many gigabytes. Only that job dies, and the report says why. Enforced only by launchers that can measure a running job. |
| `--run-wait-timeout-mins`   | 180     | Give up on a job that has not started work within this many minutes of being launched, which normally means it is queueing for a license. `0` waits indefinitely. Separate from `--run-timeout-mins`. |
| `--gui`                     | off     | Run the flow in the tool's GUI rather than in batch mode.                                                                         |
| `--gui-debug`, `-gd`        | off     | GUI mode plus tool debug features: breakpoints, live values, transaction recording. Xcelium only at present, and slow.            |
| `--interactive`             | off     | Run the job in non-GUI interactive mode, passing tool output through and accepting input.                                         |

### File management

| Switch                  | Default          | Description                                                                                                        |
| ----------------------- | ---------------- | -------------------------------------------------------------------------------------------------------------------- |
| `--scratch-root`, `-sr` | `./scratch`      | Where build and run directories go. Falls back to `SCRATCH_ROOT`.                                                  |
| `--proj-root`, `-pr`    | enclosing git repo | The root of the project.                                                                                         |
| `--branch`, `-br`       | current git branch | The branch component of the output path. Slashes become dashes.                                                  |
| `--max-odirs`, `-mo`    | 5                | Keep this many backed-up output directories per job and discard the rest.                                          |
| `--purge`               | off              | Clean the scratch directory before running.                                                                        |

See [Where the output goes](#where-the-output-goes) for the resulting directory layout.

### Options for building

| Switch                  | Default | Description                                                                                                      |
| ----------------------- | ------- | -------------------------------------------------------------------------------------------------------------------- |
| `--build-only`, `-bu`   | off     | Stop after building; do not run anything.                                                                        |
| `--build-unique`        | off     | Append a timestamp to the build directory, so a concurrent invocation from another terminal does not collide.    |
| `--build-opts`, `-bo`   | none    | Extra options passed on every build command line.                                                                |
| `--build-modes`, `-bm`  | none    | Apply these build modes to all build and run targets.                                                            |
| `--build-timeout-mins`  | 60      | Kill a build that runs longer than this. Falls back to 60 minutes when nothing else sets it. Not applied in GUI mode. |

### Options for running

| Switch                      | Default | Description                                                                                                  |
| --------------------------- | ------- | ---------------------------------------------------------------------------------------------------------------- |
| `--run-only`, `-ru`         | off     | Skip the build step and assume the executables already exist.                                                |
| `--run-opts`, `-ro`         | none    | Extra options passed on every run command line.                                                              |
| `--run-modes`, `-rm`        | none    | Apply these run modes to every simulation run.                                                               |
| `--profile`, `-p`           | off     | Turn on simulation profiling. Takes `time` or `mem`, defaulting to `time` when given bare.                   |
| `--xprop-off`               | off     | Turn off X-propagation.                                                                                      |
| `--no-rerun`                | off     | Do not automatically rerun a failing test with waves enabled.                                                |
| `--run-timeout-mins`        | 60      | Kill a run that has been working for longer than this. Counts from when the job starts work, not from launch. Falls back to 60 minutes when nothing else sets it. Not applied in GUI mode. |
| `--run-timeout-multiplier`  | 1       | Scale every run timeout by this factor. Typically used for gate-level and foundry runs.                      |
| `--verbosity`, `-v`         | from cfg | Simulation verbosity: `n`, `l`, `m`, `h`, `f` or `d`.                                                       |

### Build and test seeds

| Switch                       | Default | Description                                                                                              |
| ---------------------------- | ------- | ------------------------------------------------------------------------------------------------------------ |
| `--build-seed`               | off     | Randomize the build. Takes an optional seed; otherwise picks a random 256-bit value.                     |
| `--seeds`, `-s`              | none    | Seeds to apply to the items being run, in the order they are passed.                                     |
| `--fixed-seed`, `-fs`        | none    | Run every item with this seed. Implies `--reseed 1`.                                                     |
| `--reseed`, `-r`             | from cfg | Run each test this many times, with a new seed each time, overriding the configuration.                 |
| `--reseed-multiplier`, `-rx` | 1       | Scale each configured reseed count by this factor, preserving the ratio between tests.                   |
| `--reseed-source`, `-rs`     | none    | Path to an Hjson file that supplies the seeds to run, after grading.                                     |

### Dumping waves

| Switch                | Default                     | Description                                                                     |
| --------------------- | --------------------------- | ----------------------------------------------------------------------------------- |
| `--waves`, `-w`       | off                         | Dump waves in the given format: `fsdb`, `shm`, `vpd`, `vcd`, `evcd` or `fst`.   |
| `--max-waves`, `-mw`  | 5                           | Dump waves for at most this many runs, counting automatic reruns.               |
| `--dump-script`, `-ds`| `hw/dv/tools/sim.tcl`       | A custom dump script, relative to the project root.                             |

### Generating simulation coverage

| Switch                  | Default | Description                                                                     |
| ----------------------- | ------- | ----------------------------------------------------------------------------------- |
| `--cov`, `-c`           | off     | Collect coverage.                                                               |
| `--cov-merge-previous`  | off     | Merge the previous coverage database with the new one. Needs `--cov`.           |
| `--cov-unr`             | off     | Run unreachability analysis and generate a report. VCS only.                    |
| `--cov-analyze`         | off     | Analyze the coverage from the last run instead of building or running anything. |

### Generating and publishing results

| Switch                | Default  | Description                                                                                                                         |
| --------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `--map-full-testplan` | off      | Annotate the complete testplan with results, not only the testpoints this run touched.                                              |
| `--publish`           | none     | Publish the results to the given GitHub repository. Needs `SSH_KEY_PASSPHRASE` or a passphrase-free deploy key.                     |
| `--publish-prev`      | none     | Publish the reports already in the `latest` subdirectories, without rerunning. Needs the flow and tool to be resolvable.             |
| `--publish-mode`      | `public` | `public` publishes sanitized report numbers only. `private` also publishes the native tool coverage databases and points the dashboard's coverage link at them. |

### Controlling DVSim itself

| Switch                  | Default   | Description                                                                            |
| ----------------------- | --------- | ------------------------------------------------------------------------------------------ |
| `--print-interval`, `-pi` | 10      | Refresh the console status every this many seconds.                                    |
| `--verbose`             | off       | Print verbose DVSim messages. `--verbose=debug` prints more still.                     |
| `--dry-run`, `-n`       | off       | Print the commands each job would run, without running them.                           |

## Other related documents

* [Design document](./doc/design_doc.md)
* [Testplanner tool](./doc/testplanner.md)
* [Glossary](./doc/glossary.md)

## Bugs

Please see [the Pavona GitHub issues list](https://github.com/pavona/pavona/issues) for open bugs and feature requests.
