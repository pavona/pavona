# Continuous Integration

All changes to Pavona source code are tested thoroughly in a continuous integration system.
Tests run automatically when changes are proposed for inclusion by submitting a pull request, and on the `main` branch after changes are merged.
This ensures that the source code meets certain quality criteria at all points in time, as defined by the tests which are executed.

Read on to learn more about the types of tests, and the infrastructure that runs these tests.

## How to report CI problems

If you detect CI failures which look like they might not be related to the tested code, but the test infrastructure, please file an [issue on GitHub](https://github.com/pavona/pavona/issues).

## Overview

![CI Overview](pavona-ci-diagram.svg)

Pavona uses [GitHub Actions](https://github.com/features/actions) as continuous integration provider: test jobs are described in an GitHub Actions-specific way, and then executed on compute resources, some of which are provided by GitHub, and others of which are provided by the project.

## Test descriptions

All tests are described in a GitHub Actions-specific YAML syntax.
`$REPO_TOP/.github/workflows/ci.yml` is the main configuration file for all public CI jobs.

GitHub Actions documentation can be found at [https://docs.github.com/en/actions](https://docs.github.com/en/actions).

## Runner environments

Each job in the YAML file also specifies which type of compute resource it wants to run on.
An individual compute resource is called a *runner*, and we separate runners by giving them distinct labels for runners with different capability.

All self-hosted runners (i.e. non-GitHub runners) are managed by the Pavona organization.

All runners provide ephemeral test environments: the test environment is initialized at the start of a test job and completely destroyed at the end.

## Job scheduling, build triggers and status reporting

When an event, e.g. the creation of new pull requests, are triggered, GitHub Actions compares them with the configured workflow triggers in the `.github/workflows/ci.yml` file.
It then processes the workflow description and queues and dispatches test jobs to the respective runners, taking test dependencies into account.

After the runner has completed a test job it reports back the result GitHub Actions, which makes this information (build artifacts and logs) available to users through the web UI.
The status of GitHub Actions is displayed below a pull request, as marks next to commits, and in various other places.

---

*Pavona's CI instance was donated by zeroRISC Inc.*
