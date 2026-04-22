# Request for Comments 2026-02: Versioning

* Authors: [Viveca Pannell](mailto:vpannell@zerorisc.com), [Quan Nguyen](mailto:qmn@zerorisc.com)
* Last updated: April 22, 2026

## Introduction

This RFC covers basic repo versioning--namely, which schemes to use and how to implement it.

The repository needs versioning to help its users reason about the quality and compatibility of its parts, especially as they change over time.
The Pavona project will track all parts of the repo with only one version number.
Instead of semantic versioning, it will use calendar versioning (`YYYY.MM`) to coincide with major repo releases, with patch numbers to represent subsequent patches.

### Proposal

![Summary of versioning](./overview.svg)

The purpose of versioning is to keep track of development progress and give users a common baseline point at which to most easily use the repo tools at hand.

The project will version the repo as a whole.
Versioning will use a release-date-plus-patch-number versioning scheme of `[YYYY].[MM].p[#]`.
Version tracking will utilize git tags.

For each official repo release: a release branch `release/[YYYY].[MM]` will be created, with valid releases marked by git tags of the form `release/[YYYY].[MM].p[#]` (eg., `release/2026.04.p2`).
Each release will also be made available on GitHub under “Releases”.

### Intent

This guidebook is written to aid the repo launch in implementing a functional versioning scheme and adequate version control processes.

Potential problems to avoid:
- Frustrating new users who find bugs on the main branch, which is actively developed and unstable.
- Difficulties with incompatible or broken parts.
- Incorrect or difficult-to-find version information.

These things can hinder development and contribution, deter adoption of the repo, and lead to messy engineering kludges and/or code rot.
Implementing a well-defined versioning scheme can provide an edition of the repo that is out-of-box usable, mitigating such difficulties.

## Defining Versions

A simple version numbering scheme can go a long way: it can be both easy to implement and provide a quick way to supply information.
The project will use a calendar versioning scheme of `[YYYY].[MM].p[#]`, filled in with the year and month of a given major repository release, plus a patch number.

### Version Labels

Version tracking will be done via git tags and branches.

Git branches enable a continuous line of development separate from main.

Git tags enable users to retrieve specific versions of the repo and/or its components, track development over time, and examine diffs across versions.
Releases will use signed (annotated) tags in order to store more information about the tag as well as verify the tagger's identity.
Multiple tags may be applied to a single commit, so assigning a version tag will not interfere with using tags for other purposes.
Tags [should never be renamed or moved](https://git-scm.com/docs/git-tag#_on_re_tagging) (this indicates that something has really gone wrong).

For each release date, a new release branch `release/[YYYY].[MM]` will be created.
Each release will have a corresponding git tag on its latest commit, labeled `release/[YYYY].[MM].p[#]`, starting with patch number 0, the initial release (zero patches received).

Repo content will not be required to contain the repo version number because it would require too much effort to keep every versioned file in sync.
Only the release's git tag will convey version information.

### Version Information

The version number provides information on: 1\) compatibility of repo content, 2\) the version being stable or deprecated, and 3\) how many bug fixes it has received:

1. Only two versions numbers that have the same version date, even if differing in patch number, will be considered compatible.
   All repo content from compatible versions must remain compatible with one another.
   This includes keeping any external dependencies constant from patch to patch: for example, if version `2026.04.p4` requires package `foo` at version `3.14`, then so should version `2026.04.p5`.

2. The version's release date conveys the timeline for how long it is considered stable: releases are stable and supported from the time the initial release tag is pushed until a fixed time after the release date (see below discussion on release development and end-of-life).

3. Updates applied to a release branch after initial release should only consist of bug fixes in order to maintain release branch stability.
   Each incoming fix will be considered a new patch, constituting a new tag along the branch.
   Patches should not alter the release date numbers, and patch numbers must always increment by one (regardless of the size or subject of the code changes).

## Release Development

![Example of release branch evolution; initial release must occur in February 2026](./development.svg)

In accordance with good practices, development should begin on separate branches, not directly on main or on any release branch.
Changes can then be merged into or rebased onto these central branches after making a pull request (PR) and getting reviewer approval.

### Schedule

On schedule, a new release branch will be created from the latest commit on main, and that commit should be tagged with `cut/[YYYY].[MM]` to designate the point at which the release branch `release/[YYYY].[MM]` diverges.
A regular, predictable release schedule chosen and clear communication will help instill trust in the repo; therefore, it is advantageous to select a specific cadence rather than individual release months.

Releases will occur twice per year.
Release branches, accordingly, will be created three months before the release date to allot adequate time for preparing the initial release.

Patches to supported repo releases may occur at any point in time between the initial release and end-of-life.
Repo versions will no longer be supported two years after their initial release date, and a version that has reached end-of-life may no longer receive any patches.

At this time, a reasonable release schedule seems to be every April and every October, starting with April 2026.
This means new release branches will be created every January and July, and release `2026.04` will be deprecated at the end of April 2028.

#### Initial Release

Initial releases should always come out on time: once a release date is selected, the initial release *must* be made during that month, rolling back any unfinished features as necessary.
They can occur at any point during the release month.

Part of the preparation for initial release includes aggregating a set of conditions for the release to be deemed "stable" (discussed more below).
Before initial release, the content of the release branch should be considered a release candidate, as it has not yet been stabilized.
Additional commits may be made on the release branch (possibly cherry-picked from main) to prepare a minimally buggy, well-tested, and well-documented repo until the initial release has been tagged.

Once the tip of the release branch can be considered stable, it can be tagged with `release/[YYYY].[MM].p0` to indicate that the release is ready for use.

#### Patch Philosophy

Importantly: release numbers never change nor decrement.
After the initial release, any updates on a release branch *must* constitute a new patch, and previous patches should never be amended or rescinded (a new patch may undo some of the things changed in a previous patch, but this does not change the git history nor patch numbering).

Once an initial release has been made, the release branch should be considered a snapshot in time, remaining mostly static.
The only changes that should be made are fixes addressing issues found when using that specific version of the repo.
This will keep releases stable and minimize the number of patches a release branch receives over its lifetime.

All development for new features and improvements should instead go to main.

Generally speaking, changes on main should only be incorporated into the release branch before the initial release, at which point the two branches are considered to have diverged.
If the same bug is found on both branches post-release, two separate PRs--one against each branch--is warranted.
After initial release, any sets of commits made to a release branch should constitute a new patch.

#### Support Window

Repo maintainers and contributors should not make any patches to deprecated releases nor be required to help users with new issues found when using deprecated versions.
A given version's lifespan should be a hard cutoff for whether it will be supported, at which point the end user is "on their own".
Individuals may apply changes to deprecated releases on their own forks, but these changes will never be merged into the central Pavona repository.

Deprecated branches should remain on GitHub but should no longer receive any updates.
They exist as historical references.

### Release Preparation Process

The technical committee or repository governing body will decide these criteria for each release by the time the release branch is cut.
They will also decide the primary set of contributors responsible for meeting these criteria in time for initial release and properly documenting the release.
They may also, if warranted, assign responsibility for maintaining a given release branch after initial release.

All criteria for a properly prepared release must be met prior to initial release and should be openly published upon release.
The release standards should err on the side of having quality (better tested, albeit fewer, features) rather than quantity (less thorough testing).

This should also include a set of tests that will be run by CI on all incoming release-branch PRs (this can be the same set of tests run against PRs on main).
Development of new release readiness metrics may refer to previous releases' criteria.

Similarly, any documentation that misaligns with the code should be updated prior to an initial release.

While version information could potentially be tracked in some files within the repo, for now they can be ignored.
However, hardware quality information, such as the `life_stage`, `design_stage`, `verification_stage`, and `dif_stage` fields in an IP block’s Hjson should be up-to-date at initial release.
This information must be kept accurate in order to retain trust in the repo.

#### Mechanics

In the future, it may be very helpful to have automations for cutting and archiving release branches on schedule as well as tagging the latest patches after each release-branch PR, but for now these things may be done manually.
The initial patch tag should always be manually created as a way to improve release stability (ie., require human eyes to carefully check that the release is ready).

#### Release Packaging

Making it easy for users to access the repo is of utmost importance, especially since many individuals will simply want to use the repo rather than contribute to it, and packaging should help in this aim.

Users will be encouraged to clone the repo for themselves as the primary method of installing Pavona, but this may not be suitable for all situations.
GitHub provides [an easy interface](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository) for generating release packages, so the alternative to cloning for users is downloading the release packages from GitHub.
Any git tags may be used to mark a release, but only the `release/*` tags will be used for this purpose.
GitHub releases automatically provide both ZIP and TAR archive files of the repo using `git archive`.

Each version of the repo, including each patch, should be made a release on GitHub, and every initial release (patch 0\) must be supplemented with adequate release notes in the description box.
Patch/non-initial releases may come with autogenerated patch notes or hand-written patch notes if appropriate.

Release packages must be made publicly available within the chosen release month.

### Supporting Versioning

Discipline will be the main requirement in sustaining a well-versioned repo.
To this end, version management should be made as easy as possible.

Some simple ways to aid versioning are:

- Implementing automation when feasible.
- Encouraging contributors to address issues in releases in addition to working off of main.
- Quickly fixing any mistakes in repo releases (in the release content or in its version labels).
- High, objective, and unambiguous standards for release content.

It is better to have something simply not build than to find a bug late in development.
At some point, the various Bazel, Python, and Bash scripts (which currently ignore versioning) that constitute the repo's build tooling should have access to version information, but this is not required at this time.

Of course, documentation, active engagement in discussions, good communication, and examples can always help inform users on how to best implement changes in Pavona; however, at the end of the day, it really comes down to responsible contributors’ and maintainers’ actions to keep the repo properly versioned.

## Procedures

Well-defined procedures will help with contributor discipline.
The following sections are subject to revision, but they should provide a good starting point.

### New Initial Release

1. Ensure that the new release branch has been properly created (branch cut tagged properly, proper permissions on release branch).
2. Review the set of criteria for when the release is considered "ready/stable".
    * This includes any overall milestones to complete.
    * This includes any tests that the release branch must always pass (which can be run by CI for every release-branch PR).
    * This includes any metrics to publish to the Pavona website to demonstrate the release's quality (eg., coverage tests).
3. Before the full release is ready, ensure quality of new initial release and publish metrics.
    * Routinely evaluate the repo in accord with agreed upon standards (compare to milestones, run test suite, gather metrics).
    * Fix any bugs found and update documentation along the way.
      Backport any bugfixes found in main to the release branch.
4. At initial release, tag the latest commit on the release branch as `release/[YYYY].[MM].p0` and publish release metrics.
5. Create a new repo release package on GitHub.
    * Create a release on GitHub titled “[YYYY].[MM].p[#]” from the `release/[YYYY].[MM].p[#]` git tag.
    * Select the branch cut tag (`cut/[YYYY].[MM]`) as the "previous" tag
       Write release notes.
    * Publish.

### Pull Requests for Patches

Contributors’ Checklist:

1. Make sure you are working on a derivative of the release branch.
   It is possible that the release branch and main have diverged.
2. Make a PR on GitHub to bring changes into the release branch.
   Follow standard contribution procedures.
    * Specify any significant changes introduced by this patch in the PR description and/or comments.
3. After the PR is merged, check that the latest release branch commit is tagged with the new patch number and that there is a new patch release on GitHub.
   If not, notify the release maintainers.

Reviewers’ Checklist (for Versioning):

- [ ] Are these changes appropriate as a release patch (fixes only), or do they belong on main (improvements, new features)?
- [ ] Are these changes being made prior to release deprecation?
- [ ] After PR merge: has the latest patch been properly tagged and release notes written in?

### Revising Versioning Scheme

This will follow the standard RFC process.
All version-related documentation should be updated accordingly, should the RFC be approved.

### Git Reference

Possibly-helpful commands for the less git-inclined (this is simply querying and adding tags):

- Check which version of the repo you’re using: `git describe --tags --match “release/*” --abbrev=0`
- Checkout a new version of the repo: `git checkout <version tag>`
- Find all available releases: `git tag --list “release/*”`
  - Find most recent releases: `git tag --list “release/*” --sort=-committerdate` (most recent at top)
  - Find latest/"current" release number for a given commit: `git describe --tags --abbrev=0 --match "release/*" <commit>`
- Tag a commit: `git tag <tag name> <commit, defaults to HEAD>`
  - Pushing that tag upstream (tags are not pushed by default): `git push <remote> --tags`
  - Options for annotated tags: `-a` (annotate), `-s` (sign), `-u <key id>` (sign tag with local user key), `-m “<message>”` (tag message)
- Look at git tag details: `git cat-file tag <tag>`

# References

- Version number schemes: [semantic versioning (semver)](https://semver.org/), [calendar versioning (calver)](https://calver.org/)
- GitHub feature documentation: [releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository), [actions](https://docs.github.com/en/actions), [REST API](https://docs.github.com/en/rest)
- Git tags info: [basics](https://git-scm.com/book/en/v2/Git-Basics-Tagging), [reference](https://git-scm.com/docs/git-tag)
    - [Tag naming](https://git-scm.com/docs/git-tag#Documentation/git-tag.txt-tagname) can be checked with [`git check-ref-format`](https://git-scm.com/docs/git-check-ref-format)
    - [Setting up signing keys](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key)
- Some case studies:
    - [Ubuntu versioning model](https://en.wikipedia.org/wiki/Ubuntu_version_history)
    - [Synopsys' product release conventions](https://www.synopsys.com/content/dam/synopsys/support/documents/compute-platforms/Synopsys-Release-Types-cust2.pdf)
    - [The phenomenon of dependency hell](https://en.wikipedia.org/wiki/Dependency_hell)
    - IP management systems like [Keysight's](https://www.keysight.com/us/en/products/software/pathwave-design-software/design-data-and-ip-management/ip-management-hub.html), [SilvaCo's](https://silvaco.com/design-ip/ip-management/), and [ICManage's](https://www.icmanage.com/)
- FuseSoC version handling: [core files](https://fusesoc.readthedocs.io/en/stable/user/build_system/core_files.html#the-core-name-version-and-description), [dependencies](https://fusesoc.readthedocs.io/en/stable/user/build_system/dependencies.html#version-constraints), [config files](https://fusesoc.readthedocs.io/en/stable/user/package_manager/index.html#core-libraries), [pulling from different versions of a repo](https://github.com/olofk/fusesoc/issues/736#issuecomment-2696563930), [favoring semantic versioning](https://github.com/olofk/fusesoc/issues/565)

## Supplementary Discussion

### Central principles in versioning

As stated earlier, versioning is meant to be helpful to development and usage of the repo, not a hindrance to contribution.
When all else fails, or when the versioning seems to be failing in its aim, some helpful tenets to consider are:

* Let what should be stable stay stable.
* Start simple and complicate things later as needed.
* Utility over convention, but consider carefully why convention was there in the first place.
* A principal limitation of open-source projects is often manpower; don’t do something without knowing there will be enough people working on it.
* Documentation is good.

### Versioning silicon

Part of the reason devising this repo’s versioning is not as straightforward as selecting a versioning scheme for other repositories is because it will be a mixed open source repository of both hardware and software.
This has affected the decisions in this document in a few ways:

- Hardware changes are more difficult to categorize than software changes.
  What does “backwards-compatible” mean?
  How to deal with non-text files?
  How to most easily map out “dependencies” when certain parts in a system depend on knowing the entirety of it?
- Release timelines for software are often much shorter than those for hardware.
  This is because the amount of additional design verification collateral needed for testing hardware may at times be more than the amount of testing required for software.
  The tapeout pipeline is very slow and cautious.

However, apart from these considerations, repo versioning should, by and large, mimic those of already established open source projects.

### Document scope

So far, this document mainly covers how to describe versions/naming and package releases.
It does not cover:
- who arbitrates release schedule
- how releases are publicized
- git history philosophy for the repo (eg., how to do merges and rebasing, linearity)

... and much more.

### Keeping the repo as a single whole

Original ideations about repo versioning treated version numbers as potentially being assigned to various parts within the repo instead.
We examined trying to version various levels of hardware (prims, IP blocks, and tops) in depth, then considered division of the repo into host and device.
Ultimately, however, we resolved to keep the repo as a whole versioned for a variety of practical reasons.

The first reason was the issue with coordinating among moving parts.
With the variety of files within the repo, we would have seen immensely differing development speeds, metrics of importance, and definitions for what “backwards compatible” means.
It would have required us to contrive a whole set of definitions and standards for each segment of the repo, which is not necessary at this time (“if it ain’t broke, don’t fix it”, especially if the effort required is significantly more than a quick fix), and to check compatibility for every “connected” part.
In addition, we would have to decide where to track the various versions, adding yet more complexity to versioning than simple git tags.

We also resolved to version the repo monolithically because this is, after all, an open source project.
At this time, the project likely does not have enough people working on it to maintain a complex versioning strategy, and providing source code gives end users much more power to manipulate the repo themselves for their individual use cases.
Instead of having a small team constantly swamped with maintaining backwards compatibility and support for many releases, the onus is on the individual user themselves to port in a different version of something within the repo if so desired.

Yet another reason for versioning the repo as one is simple: given our initial timeline estimates for release frequency and lifespan, it is simply not necessary to catalogue the change for each component.
Each release will likely get few enough patches that it will be easy to find when a given file was updated.

### Why calver/calendar-based versioning?

Versioning based on date helps provide historical context (eg., “I noticed a new bug sometime around June, so let’s see changes made around that time”) and inherently imply compatibility between versioned items.
It is also more broadly applicable than the oft-adopted semver scheme (for example: what does it mean for a piece of hardware to be “backwards compatible”?).

It seems that calver is gaining momentum due to the advantages it has over other versioning schemes with regard to unambiguity and time-specificity; many projects in recent years have switched over to calver or at least considered it.

The main warning from detractors of calver (aside from backwards compatibility in projects that have been using another versioning scheme for a long time) is that calver must still mean *something* about the code other than just a datetime.
In our case, it is a version of the repo that is usable as a starting point: minimal bugs, well-coordinated parts, adequate documentation, and published test results at a fixed point in time.

Changes between versions should be clearly communicated (especially “breaking” ones that will make integrating previous version parts more difficult), and releases should always be made on a meaningful (predictable, consistent, appropriate for the speed of development) schedule.

### Calver with FuseSoC

An important note about calver and FuseSoC: FuseSoC uses the okonomiyaki Python library to determine versions, which assumes semantic versioning rather than calendar versioning.
This can [pose a problem](https://github.com/olofk/fusesoc/issues/565) when calver versions are used in FuseSoC core files, so instead the version number in the core files should be ignored.

However, FuseSoC can [pull previous versions of the repo](https://github.com/olofk/fusesoc/issues/736#issuecomment-2696563930) and add them to core library; this can be done in the command line or in a [fusesoc.conf](https://fusesoc.readthedocs.io/en/stable/user/package_manager/index.html#core-libraries) file.


### How big of a change warrants a new version?

Any functional change, large or small, should require an increment in patch number.

Because this project has a lot of moving parts, it will be difficult to tell how momentous a change is and how possible it is to affect something that might seem completely unrelated.
There is currently no clean way to quantify the size of a change, and instead of wasting time debating about how changes should be categorized, it will be much simpler to count any updates as new patches.

The only changes that could possibly be excluded here are minor typo fixes in comments and documentation or code reorganization for simple readability.
These changes do not affect repo usage and can easily be lumped in with the next set of functional changes.

While patch number does not specify the size of any given update, it’s more important to know when anything changes.
Trying to qualify a change may prove difficult, and git logs should be adequate for examining specific versions.

Why not just use commit hashes along the release branch instead of patch number, keeping only the versioning at the latest point in the release branch?
Patch number inherently has an order and can differentiate between unstable (not tagged) and stable release status; with commit hashes, it’s unclear when one hash precedes the other, and there’s no way to tell at what point the release branch became stable.
Patch number is also easier to remember than commit hashes.

### Practicality of git tags

Git tags have been selected as the central mode of storing version information for multiple reasons:

* GitHub releases are already done with git tags.
* Clear visibility in the git history.
* Tags are required to be unique, hence no duplicate version numbers.
* Tags are simple to implement.
* No code duplication.
* Limiting available versions avoids incorrect version naming.
* Annotated tags [specifically](https://git-scm.com/book/en/v2/Git-Basics-Tagging)…
  * Store tag metadata (tagger name, email, and date).
  * Include a tagging message, which may provide supplemental information.
  * Can be signed and verified.

Git tags have some limitations that can be worked around, especially with the fact that git tags are commit-specific.
Since rebasing or amending commits does not retain git tags (these actions create new commits), there will be a no-rebase and no-amend policy on the release branch: once changes are brought in to it, they are final.
Future commits may revert previous changes as needed.
Tags can be manually moved, but doing so is tedious and highly discouraged.

### Survey of infrastructure needed

Below are some suggestions of problems that arise when trying to keep a solid versioning scheme intact and possible ways to mitigate these risks.

| *Need*                                                            | *Possible Solution(s)*                                                                                                                                                                                                                           |
| :---------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Communicate versioning requirements                               | Documentation: contributors’ guides, workflow walkthroughs, versioning docs. Discussion threads to clear up any confusion (these may even lead to RFCs for revising repo versioning). Example tops/projects.                                     |
| Communicate new version information                               | Well-written release notes and commit messages. Responsiveness to filed issues and discussions.                                                                                                                                                  |
| Ease the process of incrementing version numbers for contributors | Scripts to check where version numbers should be incremented; this requires a well-defined repo directory structure.                                                                                                                             |
| Prevent mistakes in versioning                                    | Strong PR processes (may require a reviewer’s guide/checklists/additional documentation) and automated checks. Tests that can be run locally to check if versioning has been done correctly. Tailor tooling to correctly handle versioned items. |

### The versionless main

At this point, it may be clear that there is no versioning to be done with changes made to main.
This may cause some concern, as development on main will then not be easily tracked.

On the other hand, this risk is well-mitigated by having a consistent and frequent release schedule; though development on main may continue without a release number, it will not be long before the next release branch is cut.
Differences between release branches will be small enough that users will have enough granularity to know approximately where certain changes were made and will more easily be able to pull and adapt specific parts from previous versions as needed.

### Retaining unsupported release branches

One thing to consider is how long unsupported releases should remain available in the public repo.

Advantages to keeping deprecated releases available:
- Historic info about development direction.
- Helps users of deprecated records maintain a fixed reference.
    - Record-keeping for security and safety issues found in the future.
    - Standards compliance.
- Allows access to older versions if specific desired features or properties no longer exist in newer versions.

Disadvantages to keeping deprecated releases available:
- Noise (eg. questions or suggestions about development for unsupported versions from unknowing users) / not communicating unsupported status as well.
- Ever-increasing repo size.
- Unused branches that have no reason to exist.

All these considered, a proper long term deprecation protocol should be decided with appropriate measures and timing.

### Gitless

GitHub uses `git archive` to create ZIP and TAR files for download on the release pages.

However, these archive files are not git repos upon extraction and are not equivalent to clones.
Therefore, most of the repo features should work outside of a git repo, and capabilities that require the Pavona repo to have git initialized should have this reflected in documentation.
