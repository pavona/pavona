# Contributing Guide

Welcome to Pavona, the premier open-source silicon ecosystem!
This project is organized for the benefit of everyone.
This code from this project is permissively licensed, which means that anyone can use it.
To make it possible for anyone to use the code, contributors must meet a few obligations.

This guide summarizes how to contribute to this project.
These sections are lay-summaries of their official counterparts; refer to the linked authoritative versions for complete details.

For most people, contributing to the project follows these steps:

1. Understand how you can use the project.
2. If you'd like to participate, engage in mailing lists and on GitHub.
3. If you'd like to contribute code, determine which contributor license agreement (CLA) applies, and sign it.
4. If you're contributing code, follow the guidelines for submitting pull requests and the review process.

## Using the project

This project is licensed under the Apache License, Version 2.0.

To simply use the project (including reading the code, downloading the code, making private modifications, building the software and hardware contained here) does not require any of the steps described below.
Please read [LICENSE.md](LICENSE.md) to fully understand how to use, reproduce, and distribute the contents of this project.

## Participating in the project

Open source thrives on global participation and cooperation.
There are many ways to participate in the Pavona project.

### Mailing lists

The project offers several mailing lists open to everyone.
Participation in the mailing lists only requires subscribing with an email address.
They are:

* technical@pavona.org – an open mailing list for broad technical discussions and open to all who subscribe.
* info@pavona.org – an inbound-only mailing list for general questions about the project.
* announcements@pavona.org – an outbound-only low-volume channel for important announcements about the project.
* security-disclosures@pavona.org – an inbound-only mailing list for confidential security disclosures.

### GitHub issues and pull requests

Most technical discussions around specific features and bugs occur on the Pavona GitHub repository at [github.com/pavona/pavona](http://github.com/pavona/pavona).
The main way to file a bug report is to open an issue on GitHub.
Participating on GitHub requires a GitHub account.

## Contributing to the project

If you would like to submit a pull request or otherwise contribute to the project, you'll need to complete a Contributor License Agreement (CLA).
The type of CLA you will complete depends on whether you are contributing on an individual basis or on behalf of a corporation.
If you are contributing on behalf of a corporation, it will also depend on whether your company is a member of GlobalPlatform, Pavona's parent organization.

### Individuals

If you are contributing as an individual, please see [CLA-Individual](CLA-Individual).
You will need to sign this document and email the signed document to the listed email address.
The Pavona project contains a CLA assistant that will automatically check that you have agreed to the terms of the CLA.

### Corporate

If you are an employee of a corporation and your contributions would be covered by an intellectual property agreement, please direct your manager, or the person capable of signing agreements on behalf of your company, to [CLA-Corporate](CLA-Corporate).
Similar to the process for individuals, the CLA assistant will check that you or your company have completed the corporate CLA.

### Corporate (GlobalPlatform member)

If you are an employee of a corporation that is a member of GlobalPlatform, it is unnecessary to sign a separate corporate CLA.

## Signing off your commits

When authoring a commit message, you are required to sign off your commit, indicating that you understand and accept the terms of the applicable CLA.
This is covered by the "Signed-off-by: Name \<Email\>" line at the bottom of every commit.

Git makes it easy to sign off commits.
Be sure that your name and email are set correctly by using `git config` if necessary.
Then, whenever creating a commit, use `git commit -s` rather than the usual `git commit`.
This automatically adds the Signed-off-by line.
If commits are missing this line, use `git commit --amend` or `git rebase` to add the lines manually.
The Pavona CI system automatically checks for signatures.

## Submitting code via pull request

The primary way of contributing code to Pavona is by opening a pull request.
See the [GitHub documentation](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request) for how to submit a pull request (PR).
A brief summary of the code submission process is below, which will be familiar to those submitting pull requests to other GitHub repositories.

1. Clone the Pavona repository to a fork on your GitHub account.
2. Make changes to your code and commit them to your Pavona fork.
3. Open a pull request against the Pavona repository.
4. Participate in the review process, responding to comments and implementing changes from reviewers.
5. Once your changes are approved, merge your pull request into the Pavona repository.

Contributors are expected to abide by the guidelines for submitting PRs.
Some key guidelines are:

* Commits need to be signed off (see above).
* Contents of pull requests are rigorously checked by the continuous integration system, which checks for code quality, style, and any regressions.
  These checks need to pass before merging code.
* The repository uses a rebase approach to merging.
  No merge commits are permitted.

For more information, consult the [GitHub notes](./doc/contributing/github_notes.md).
