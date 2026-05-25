<!--
Copyright zeroRISC Inc.
Licensed under the Apache License, Version 2.0, see LICENSE for details.
SPDX-License-Identifier: Apache-2.0
-->

# Frequently Asked Questions

## General

<!-- markdownlint-disable MD026 -->
### What is continuous integration?

Continuous Integration (CI) is the development practice of rapidly including new source code changes into a main branch, which ensuring that the combined source code is in a workable state, usually via automated testing.

<!-- markdownlint-disable MD026 -->
### What is the purpose continuous integration?

CI ensures that all source code merged into protected branches meets prespecified quality and correctness standards.
This allows contributors to rely on a stable development base for testing new changes, and maintainers to confidently cut releases without performing extensive additional manual testing.

<!-- markdownlint-disable MD026 -->
### How do I use the continuous integration service?

Upon creating a Pull Request (PR) in GitHub against the `pavona` respository, continuous integration jobs will automatically trigger.
You can check the status of the running CI jobs in the `Checks` tab after navigating to your Pull Request.

We also run nightly and weekly regressions on main branches that trigger automatically and include tests that are not reasonable to run on every PR.
You can view the result of the most recent regression by navigating to the repository's `Actions` tab and clicking the `Nightly` or `Weekly` workflow on the left pane.

## Contributing Tests

<!-- markdownlint-disable MD026 -->
### I added a new Bazel test to the repository. How can I have the CI run it?

The CI uses the `tags` attribute in Bazel to determine if (and where) to run a test you declare.
In most cases, any Bazel tests you add to the repository are automatically captured by the appropriate CI check.

Any test that does not rely on Verilator, the ACC simulator, or an FPGA is automatically classified as a software unit test (see the `Build and test software` check).

All tests under `//sw/acc/crypto/...` are triaged under the `Run ACC crypto tests` check.

For FPGA and Verilator tests, the necessary tags to triage the test in the CI are automatically applied by the execution environment.
For example, adding the `//hw/top_egret:fpga_cw310_test_rom` to `exec_env` in the `pavona_test` rule automatically instructs the CI to run the test in the `CW310 Test ROM tests` check, via the `cw310_test_rom` tag.

**Note**: If you want to include a test in the repository, but want the CI to _skip_ it, you can add either the `broken` or `skip_in_ci` tag, as appropriate.

<!-- markdownlint-disable MD026 -->
### Why didn't the CI run my test?

Most likely it was filtered out.
Bazel has two types of test filters `test_tag_filters`, and `test_timeout_filters`.
Tag filters are used to ensure tests that need a certain environment, like a CW310 with a specific bitstream, are captured by the job that provides that environment.
Timeout filters are used to ensure tests that take a long time to run are not run on every pull request.
Some longer-running tests, such as the CW310 cryptotest framework tests, are reserved for the Nightly CI.

If you think a job should have captured your test, check which filters were applied.
Depending on the test type, these will be listed either in the main workflow file under `.github/workflows/`, or in a CI-specific shell script under `ci/scripts/`.

<!-- markdownlint-disable MD026 -->
### How do I add a new CI job?

CI jobs are defined using the [GitHub Actions YAML syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) in `.github/workflows/`.
Depending on what platform support your job needs, make sure you configure the correct _runner environment_ for your job. See [here](README.md#runner-environments) for more details.

## Feature Support

<!-- markdownlint-disable MD026 -->
### What platforms are available for testing?

All runners use a container image based on Ubuntu 24.04.
This image comes with Pavona's `apt-requirements.txt` pre-installed, but contains very few packages otherwise installed.
Language-specific tools like `rustc` must be installed separately by jobs if needed.

In addition, the CI offers runners with the following testing platforms:

- Vivado 2024.1
- Vivado Lab Edition 2024.2 (included by default in FPGA runners).
- ChipWhisperer CW310 FPGA boards with attached HyperDebug boards.
- ChipWhisperer CW340 FPGA boards with attached HyperDebug boards.

See [Runner Environments](README.md#runner-environments) for more details on how to access these platforms in jobs.

<!-- markdownlint-disable MD026 -->
### Why do checks on my PR take a long time to start?

We cap the maximum number of jobs our runner machines can run at a time, to ensure that currently-executing jobs have access to ample CPU and memory resources.
Additionally, FPGA jobs may not start right away because our FPGAs can only service a single job at a time.

<!-- markdownlint-disable MD026 -->
### Can I contribute my own hardware to the public CI?

Thank you for your interest and support!
We are interested in allowing collaborators to provide hardware and EDA software licenses to the CI.
If this is of interest to you, please contact us by opening a [support ticket](mailto:expo-ci-support@zerorisc.com).

## Troubleshooting

<!-- markdownlint-disable MD026 -->
### A check failed on my Pull Request. How can I determine the cause?

You can view the log for the CI job by clicking on the workflow under the `Checks` tab and then the name of the specific job that failed.
The log displays the shell output from the job.

**Note**: GitHub Actions uses the exit code the running shell on each job step to determine the pass/fail step.
If the log indicates that your job should succeed, but it is getting flagged as a failure, ensure that a process is not silently exiting with a nonzero exit code.

<!-- markdownlint-disable MD026 -->
### Can I rerun a failed check without pushing a new change?

Yes. After all jobs in a workflow complete, GitHub allows you to rerun specific jobs by hovering over the job name and clicking the rerun icon.
You can also rerun the entire workflow or all failed jobs using the button in the upper-right corner of the workflow page.

While we keep the option to rerun jobs available as a courtesy, as sometimes hardware tests can be flaky, we ask you to respect the fact that the CI is a shared resource and try to debug issues locally before triggering a rerun.

<!-- markdownlint-disable MD026 -->
### Why does my test pass locally, but fail on the CI?

While our CI environment is designed to replicate a generic Pavona development environment, it is not always possible to match your exact environment.
If you are unable to reproduce a failure locally, here are some things to check:

- **Missing Packages**: Does your test implicitly rely on packages that are not listed in `apt-requirements.txt`, or `python-requirements.txt`?
  Our CI environment automatically installs packages listed in these files, but is otherwise a bare Ubuntu 24.04 environment.
- **Environment Variables**: Does your test require specific environment variables to be set that are not specified in the Bazel target?
  `Command not found` errors due to missing entries in `$PATH` are a common failure mode.
  Also note that GitHub Actions does not maintain environment variables or `PATH` entries between steps in a job unless the settings are written to `GITHUB_ENV` or `GITHUB_PATH`, respectively (see `.github/actions/prepare-env/action.yml` for examples).
- **Software Support**: Does your test require specific software to be installed that does not exist in the CI environment, or exists at a different path?
  See also [the FAQ above](faq.md#what-platforms-are-available-for-testing) regarding platform support.
- **FPGA Connectivity**: If you are encountering issues with your test connecting to an FPGA (i.e. you see an error like `Found no USB device`), make sure your code does not rely on specific path names for the FPGA device files, including the TTY files.
  In other words, do not hard-code paths like `/dev/ttyACM0` anywhere. The indices appended to these device paths are not stable; the UART could be `/dev/ttyACM0` on one run and `/dev/ttyACM42` on the next.

If you continue to have issues troubleshooting your job on the CI, feel free to [reach out to us](#support).

## Support

<!-- markdownlint-disable MD026 -->
### How can I get help with CI issues?

If something isn't working, we recommend filing an issue on `pavona` so others can benefit from your findings. For more personalized assistance, you can open a support ticket by contacting [expo-ci-support@zerorisc.com](mailto:expo-ci-support@zerorisc.com).

<!-- markdownlint-disable MD026 -->
### How can I find out about new features and planned maintenance on the CI?

Request to be added to our [mailing list](https://groups.google.com/a/zerorisc.com/g/expo-ci-no-reply)!
We post updates regarding soon-to-release CI features and notifications about planned maintenance outages.

<!-- markdownlint-disable MD026 -->
### How can I request new features for the CI?

The Pavona project is interested in user feedback on how to make the CI better.
If there is something you would like to see on the CI that we do not support yet, please create a GitHub Issue or [open a support ticket](mailto:expo-ci-support@zerorisc.com).
