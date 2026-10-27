# GitHub Notes

The Pavona source tree is maintained on GitHub in a monolithic repository called [pavona](https://github.com/pavona/pavona).

These notes are for people who intend to contribute to the Pavona source code.
If you don't intend to do this, you can simply clone the Pavona repository following the [Getting Started](../getting_started/README.md) guide.
The Getting Started guide describes exactly what you need to do with Git, but there is much more to Git and GitHub than cloning a repo; see [try.github.io](https://try.github.io).

## Getting a working repository

To develop in the repository you will need to get a copy on your local machine.
To contribute back to the main repository through the _pull request_ (PR) process, you need to first make your own _fork_ of the repository.
Once you have forked the main repository, you will clone your fork to your local machine.

First, log into GitHub and go to the [pavona repository](https://github.com/pavona/pavona), then click "Fork".
On the "Create a new fork" page, fill in or adjust the Owner and Description fields as needed, then click "Create fork".
This creates a copy of the Pavona repository in your own account that you can directly edit.

Then, configure Git on your local machine with your name and email address.
These commands will set your name and email for all uses of Git on your local machine, so you may have already completed these steps.
In that case, there is no need to repeat these commands.
(See below if you want to use a different email address for this repo.)

Check the parameters:
```sh
git config -l
```

If "user.name" and "user.email" do not appear, then set them:

```sh
git config --global user.name "My Name"
git config --global user.email "my_name@email.com"
```

`git` will take care of prompting for your GitHub user name and password when it is required, but it can be useful to allow it to cache these credentials (set here to an hour using the timeout in seconds) so you don't have to enter every time:

```sh
git config --global credential.helper 'cache --timeout=3600'
```

Now, clone your fork of the Pavona repository:

```sh
git clone git@github.com:<your GitHub username>/pavona
```

A directory called `pavona` should appear in your current working directory.
To make it easy to fetch changes from the original Pavona repository (also called "upstream"), add a new Git _remote_.
Print the known Git remotes with `git remote -v`:

```sh
git remote add upstream git@github.com:pavona/pavona
git remote -v
```
which prints something like:
```
origin      git@github.com:<your GitHub username>/pavona (fetch)
origin      git@github.com:<your GitHub username>/pavona (push)
upstream    git@github.com:pavona/pavona (fetch)
upstream    git@github.com:pavona/pavona (push)
```

To fetch changes made upstream (without affecting your current work), use `git fetch`:

```sh
git fetch upstream
```

## Working in your local repository

The repository that you have created locally will initially be on the `main` branch.
In general, your fork's `main` branch should track the `main` branch upstream.
The recommended flow is to make your own branch; it is conventionally named based on the change you are making.
The following Git command creates a new branch called `my-new-change` and switches to it:

```sh
git checkout -b my-new-change
```

To check the status of your changes at any time, use `git status`:

```sh
git status
```
which prints something like:
```
On branch my-new-change
nothing to commit, working tree clean
```

`git status` will indicate the state of files added, deleted, or edited in this repository.

Once you are happy with your changes, stage them for commit with `git add`:

```sh
git add <files to add>
```

Use `git status` and `git diff --staged` to review your changes.
When you are satisfied with your changes, create a commit:

```sh
git commit -s
```

The commit will make you add a message.
The first line of this is a short summary of the change.
It should be prefixed with a word in square brackets indicating the area being changed, typically the IP or tool name.
For example:

```console
[doc] Add notes on using GitHub and the repo
```

After this there should be a blank line and the main description of the change.
If you are fixing an issue then add a line at the end of the message `Fixes #nn` where `nn` is the issue number.
This will link the fix and close out the issue when your commit is eventually merged into the upstream repository.
If the change is an attempted fix that has not yet had confirmation from verification engineers, it should not close the related issue.
In this case, write `Related to #nn` in the commit message rather than `Fixes #nn`.

The commit message will end with a "Signed-off-by" line inserted by `git` due to using the `-s` option to `git commit`.
Adding this line certifies you agree to the statement in [CONTRIBUTING.md](../../CONTRIBUTING.md), indicating your contribution is made under the Contributor License Agreement.

When you have finished everything locally, you can push your branch (e.g. `my-new-change`) to **your** GitHub repository (the **origin**):

```sh
git status
git push origin my-new-change
```

Then you need to go to your repository in GitHub and either select branch from the pulldown or often there is a status message that you can click on, review the changes and make a Pull Request.
You can add reviewers and get your change reviewed.

If you need to make changes to satisfy the reviews then you do that in your local repository on the same branch.
You will need to `add` files and commit again.
It is normally best to squash your changes into a single commit by doing it with `--amend` which will give you a chance to edit the message.
If you do this you need to force `-f` the push back to your repo.

```sh
git add <files to add>
git commit --amend
git status
git push -f origin my-new-change
```

Once the reviewers are happy you can "Rebase and Merge" the Pull Request on GitHub, delete the branch there (it offers to do this when you do the merge).
You can delete the branch in your local repository with:

```sh
git checkout main
git branch -D my-new-change
```

When a Pull Request contain multiple commits, those commits should be logically independent.
Interactive rebase can be used to manipulate commits in a pull request to achieve that goal.
Rebasing is commonly used to squash commits that fix up issues reported during review back into the relevant commit.

```sh
git rebase -i `git merge-base {current_branch} main`
```

Then, an editor will open.
Follow the instructions given there, to reorder and combine commits, or to change the commit message.
Then update the PR branch in the GitHub remote repository.

```sh
git push -f origin HEAD
```

## Automatically adding a Signed-off-by line for your commits

One option to avoid having to remember to add `-s` to `git commit` is to configure `git` to append it to your commit messages for you.
This can be done using an executable hook.
An appropriate hook can be installed by executing this from the root of your repository checkout:

```sh
cat <<"EOF" > .git/hooks/prepare-commit-msg
#!/bin/sh

# Add a Signed-off-by line to the commit message if not already present.
git interpret-trailers --if-exists doNothing --trailer \
  "Signed-off-by: $(git config user.name) <$(git config user.email)>" \
  --in-place "$1"
EOF
chmod +x .git/hooks/prepare-commit-msg
```

## Commit messages

There are many useful guides available on [how to write commit messages and why](https://chris.beams.io/posts/git-commit/).

Some simple and useful guidelines are:
* A commit message consists of a subject line followed by an optional body.
* Keep the subject line short.
  Ideally under 50 characters.
* Capitalize the subject line.
* Use the imperative mood in the subject line.
* Use the present tense ("Add feature" not "Added feature").
* When changes are restricted to a specific area, you should add a tag to the start of the subject line in square brackets, e.g. "\[uart/rtl\] Rework Tx FSM".
  See also: [subject tags](#subject-tags).
* Do not end the subject line with a period.
* Separate subject from body with a blank line.
* Wrap the body at 72 characters.
* Use the body to explain what and why (rather than how).

The messages of signed-off commits ([indicating acceptance](../../CONTRIBUTING.md) of the Contributor License Agreement) also include a "signed-off-by" line.

## Update your repository with changes in the upstream repository

There is a little work to do to keep everything in sync.
Normally you want to first get your local repository `main` branch up to date with the upstream repository (**upstream**) and then you use that to update your fork (**origin**).

```sh
git checkout main
git pull --ff-only upstream main
git push origin
```

If you do this while you have changes on some other branch then before a Pull Request will work you need to be sure your branch merges cleanly into the newly updated upstream main branch.
Assuming you got the local `main` branch up to date with the procedure above you can now _rebase_ your changes on the new `main`.
Assuming you have your changes on the local branch `my-new-change`:

```sh
git checkout my-new-change
git rebase main
```

If you are lucky this will just work, it unwinds your changes, gets the updated `main` and replays your changes.
If there are conflicts then you need a big pot of coffee and patience (see next section).

Once everything has rebased properly you can do


```sh
git log
```

And see that the changes you committed on the branch are at the top of the log followed by the latest changes on the `main` branch.

Note: be mindful about which branch you are working on.
If you have added new commits to your local `main` branch, aligning it with `upstream` using `git pull --ff-only` may fail.
An alternative is to use `git pull --rebase` in that case, which directly rebases your local `main` branch onto `upstream/main`.
Do not use plain `git pull` or `git merge` commands, as they do not preserve a linear commit history.
See also [this tutorial](https://www.atlassian.com/git/tutorials/merging-vs-rebasing) to learn more about `git rebase` vs `git merge`.

## Dealing with conflicts after a rebase

If a rebase fails because of conflicts between your changes and the code you are rebasing to then git will leave your working directories in a bit of a mess and expect you to fix it.
Often the conflict is simple (e.g. you and someone else added a new routine at the same place in the file) and resolution is simple (have both in the new output).
Sometimes there is more to untangle if different changes were done to the same routine.
In either case Git has marked that you are in a conflict state and work is needed before you can go back to using your local Git tree as usual.

The Git output actually describes what to do (once you are used to how to read it).
For example:

```sh
git rebase main
```
which prints something like:
```
First, rewinding head to replay your work on top of it...
Applying: [util][pystyle] Clean Python style in single file tools
Using index info to reconstruct a base tree...
M       util/diff_generated_util_output.py
M       util/build_docs.py
Falling back to patching base and 3-way merge...
Auto-merging util/build_docs.py
CONFLICT (content): Merge conflict in util/build_docs.py
Auto-merging util/diff_generated_util_output.py
error: Failed to merge in the changes.
Patch failed at 0001 [util][pystyle] Clean Python style in single file tools
Use 'git am --show-current-patch' to see the failed patch

Resolve all conflicts manually, mark them as resolved with
"git add/rm <conflicted_files>", then run "git rebase --continue".
You can instead skip this commit: run "git rebase --skip".
To abort and get back to the state before "git rebase", run "git rebase --abort".
```

The last line of this gives the ultimate out.
You can abort the rebase and figure some other way to proceed.
As it says, this is done with:

```sh
git rebase --abort
```

After executing this command you are back to a clean tree with your changes intact, but they are still based on whatever the earlier state of the repository was.
Normally you will have to resolve the conflict sometime, but the escape hatch can be useful if you don't have time immediately!

In the normal case, read the output to find the file with the problem.
In this case `Merge conflict in util/build_docs.py` (the merge of `util/diff_generated_util_output.py` was successful even though it is mentioned in the middle of what looks like error output).

If the file is opened with an editor the points at which there are conflicts will have diff-style change information embedded in to them.
For example:

```console
<<<<<<< HEAD
import livereload

import docgen.generate
=======
import docgen
import livereload
>>>>>>> [util][pystyle] Clean Python style in single file tools

```

In this case, the upstream repository's copy of `util/build_docs.py` was modified to import `docgen.generate` rather than just `docgen`.
Because git couldn't automatically merge that change with the one we made, it gave up.
The code between `<<<<<<< HEAD` and `=======` represents the change in the upstream repository and the code between `=======` and `>>>>>>>` represents the change in our copy.

These lines have to be edited to get the correct merged result and the diff markers removed.
There may be multiple points in the file where fixes are needed.
Once all conflicts have been addressed the file can be `git add`ed and once all files addressed the rebase continued.

After the fix a status report will remind you where you are.

```sh
git status
```
which prints something like:
```
rebase in progress; onto cb85dc4
You are currently rebasing branch 'sastyle' on 'cb85dc4'.
  (all conflicts fixed: run "git rebase --continue")

Changes to be committed:
  (use "git reset HEAD <file>..." to unstage)

        modified:   diff_generated_util_output.py
        modified:   build_docs.py

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git checkout -- <file>..." to discard changes in working directory)

        modified:   build_docs.py
```

This gives the same instructions as the original merge failure message and gives the comfort that all conflicts were fixed.
To finish up you need to follow the instructions.

```sh
git add build_docs.py
git rebase --continue
```
which prints something like:
```
Applying: [util][pystyle] Clean Python style in single file tools
```

If there were more than one patch outstanding (which isn't usual if you use the `commit --amend` flow) then you may get subsequent conflicts following the `rebase --continue` as other patches are replayed.

You can check the rebase worked as expected by looking at the log to see your branch is one commit (or more if there were more) ahead of the `main` branch.

```sh
git log
```
which prints something like:
```
commit dd8721d2b1529c575c4aef988219fbf2ecd3fd1b (HEAD -> sastyle)
Author: Mark Hayter <mark.hayter@gmail.com>
Date:   Thu Jan 10 09:41:20 2019 +0000

    [util][pystyle] Clean Python style in single file tools

    Result of lintpy.py --fix on the diff and build_docs tools

    Tested with  ./diff_generated_util_output.py main

commit cb85dc42199e925ad09c45d33f6483a14764b93e (upstream/main, origin/main, origin/HEAD, main)
```

This shows the new commit (`HEAD` of the branch `sastyle`) and the preceding commit is at the `main` branch (and at the same point as `main` on both `origin` and `upstream` so everything is in sync at `main`).

At this point the conflicts have been cleared and the local repository can be used as expected.

You may find it useful to change the default for the way git reports conflicts in a file.
See [Take the pain out of git conflict resolution: use diff3](https://blog.nilbus.com/take-the-pain-out-of-git-conflict-resolution-use-diff3/)

## Adding changes to commits on an existing branch

Sometimes it might be necessary to modify individual commits of a branch.
In such cases, you can use the `git commit --fixup=<commit>`.
This creates a fixup commit which changes the content of `<commit>` but leaves its log message untouched.
The commit created has a subject composed of `fixup!` followed by the subject line from the commit.
The fixup commit is squashed into `<commit>` by `git rebase --autosquash <commit>~1`.
It could also be useful to set the `rebase.autosquash` setting to `true` using `git config --global rebase.autosquash true`.
This way, `--autosquash` does not have to be added to the command all the time.

## Downloading a pull request to our local repo

With the commands below, you can checkout a pull request from the upstream repository to your local repo.

```sh
git fetch upstream pull/{ID}/head:{BRANCH_NAME}
# e.g. git fetch upstream pull/5/head:docgen_review
git checkout {BRANCH_NAME}
```

### Applying the pull request to the local commit

In some cases, you might need to apply a pull request on top of your local commits.
For instance, if one user prepares a verification test case and finds a bug.
Another user fixed it and created a pull request.
The first user needs to test if the fix works on the new verification environment.

In this case, it is recommended to create a new branch on top of the local commit and `rebase`, `cherry-pick`, or `merge` the pull request.
Assume you have a branch name `br_localfix` which has an update for the verification environment.
If the other user created a pull request with ID #345, which has a fix for the design bug, then you can apply the pull request into new branch `br_localandremote` with the following three methods:

* The `rebase` method:

    ```sh
    git checkout -b br_localandremote br_localfix
    git fetch upstream pull/345/head:pr_345
    git rebase pr_345
    ```

* The `cherry-pick` method:

    ```sh
    git checkout -b br_localandremote br_localfix
    git fetch upstream pull/345/head:pr_345
    # find the commit ID from pr_345 that you want to merge: b345232342ff
    git cherry-pick b345232342ff
    ```
* The `merge` method:

    ```sh
    git fetch upstream pull/345/head:pr_345
    git checkout -b br_localandremote br_localfix
    git merge pr_345
    ```

The `rebase` method is more convenient than `cherry-pick` if you have more than one commit ID to merge.
The `merge` method can only be used for local testing as the upstream repository does not allow merge commits.
Sometimes, applying other contributors' pull requests can result in conflicts if both commits have the same change.
In that case, you should resolve the conflicts and continue the merge.
Section [Dealing with conflicts after a rebase](#dealing-with-conflicts-after-a-rebase) has detailed guidance on how to solve conflicts.

## Creating updates on top of a pending pull request

In some cases, you might want to directly change other contributor's pull request.
The process is quite complicated so please follow the instruction below step-by-step with caution:

* Step 1: Checkout the other pull request branch

    ```sh
    git fetch upstream pull/{ID}/head:{BRANCH_NAME}
    git checkout {BRANCH_NAME}
    ```

* Step 2: Make necessary changes

    ```sh
    git add...
    git commit -m "Add CFG examples to UART specification"
    ```

* Step 3: Create your GitHub branch for the pull request

    ```sh
    git push -u origin {BRANCH_NAME}:<remote_branch_name>
    ```

    You can use any branch name for the pull request.
    If you want to the created branch name same as local branch name, this can simply be:

    ```sh
    git push -u origin HEAD
    ```

* Step 4: Create a pull request into the other contributor's forked repository

    To create a pull request in other's forked repository, you can follow the same method as creating a pull request as section [Working in your local repo](#working-in-your-local-repo) explained in details.
    Once the other contributor's pull request is merged into the upstream repository, you will need to create a pull request in that upstream repository instead.

These are all the steps needed.
Once your pull request is reviewed and merged, you will be able to see that the commit is also visible in the original pull request.

## Dealing with email notifications

In your profile settings, under notifications, you can set up whether you get email notifications and what your default email address is.
Under the "Custom routing" you can choose to receive emails from upstream repositories at a different email address in case you're active in multiple organizations.
You can also filter GitHub emails based on the To and CC fields.
For example, notifications related to the this repository will be sent from `pavona@noreply.github.com`.
The CC field can include any of the following depending on the type of notification:
- `assign@noreply.github.com`
- `author@noreply.github.com`
- `ci-activity@noreply.github.com`
- `comment@noreply.github.com`
- `mention@noreply.github.com`
- `subscribed@noreply.github.com`
These can help you set up automatically sorting emails into specific folders.

## Labeling and assigning issues and pull requests

Labels can be useful for categorizing, prioritizing, and assigning open issues and PRs.
Anyone may assign the appropriate labels to an issue or PR.
If possible, you should also add a meaningful tag to the subject line of your issue or PR as outlined in [subject tags](#subject-tags).

Assignees indicate people who are actively working on an issue, so it's best to let people assign themselves when they start working on it.
If you'd like to bring an issue to the attention of a particular contributor or ask if they might be able to help solve it, simply mention them in a comment (e.g., "@*githubname* what do you think?")).
Anyone who feels qualified to help should respond to issues, though if you're working outside your usual area of expertise and making a best-effort guess, it's polite to say so.

For PRs, it does not make sense to assign people, but when creating a PR, you should request a review from other people familiar in the corresponding area.
This includes:
* people regularly working on the affected parts of the code, and
* people involved in discussing the solution of the problem addressed by the PR.

However, review requests are not obligations to perform a review.
Reviewers may not be able to review every requesting PR.

## Referencing issues and pull requests

Commits and PRs related to existing issues or PRs should reference those to provide better context.
References should always be accompanied by a brief summary of the outcome of the referenced discussion and how the current PR/commit/issue relates to that.
References are not only relevant for [automatically closing issues](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue#linking-a-pull-request-to-an-issue-using-a-keyword) but also for documentation.

Both long references such as `pavona/pavona#1` and short references `#1` can be used in commit messages.
However, short references should not be used in the subject line, as they might accidentally create links to unrelated issues if commits containing such references end up in other repositories, e.g., when vendoring in external sources.

For this project, the format `ISSUE=#XX` for `PR=#XX` is recommended, since these markers make it easy for tools to find the related references.

See also: [References and URLs on GitHub](https://help.github.com/en/github/writing-on-github/autolinked-references-and-urls).

## Subject tags

If code changes, issues, or pull requests are restricted to a specific area, adding a tag in square brackets (e.g., "\[uart/rtl\]") to the subject line can help to identify areas affected by changes.
Tags are particularly helpful when dealing with pull requests as they can guide team members for code review and simplify later retrieval of specific PRs through the GitHub web interface.

You can add multiple tags separated by a comma (e.g., "\[top, dv\]") to indicate that multiple separated areas are affected.
In addition, you can add further levels of hierarchy to make the indication more precise such as "\[uart/rtl\]" instead of just "\[uart\]", "\[sw/device\]" instead of "\[sw\]".

## PR scope, number of commits

A PR should contain all the code changes required to address an issue or implement a change.
At the same time, a PR should be as small as possible to simplify and speed up the review process.
It may make sense to break down larger contributions into multiple self-contained PRs.
This does not hold for bug fixes: a single PR is sufficient to fix a bug.

Regardless, each individual commit should be atomic.
The code base should remain usable even with only the first commit of a PR, or the first PR of a series of PRs, merged.

Code changes not strictly related to the target feature, major change, or issue should go into a separate PR.

In some cases, preparatory code changes may be required before a change is implemented, or a new feature may require changes in a somewhat unrelated part of the code.
For example, it may be the case that the register interface of an IP must be updated using the latest version of the register tool, before a new register required for the targeted feature can be added.
Such changes, if small, can be in the same PR, but they should be in a separate commit with a reasonable commit message explaining why the change is necessary.

PRs with more, smaller commits instead of a few large commits simplifies debugging.

## Code review

The main purpose of code review is to make sure the code changes appropriately solve the problem the PR intends to address.
It is thus vital to provide meaningful commit messages and PR descriptions with references to issues where problems and the proposed solutions are outlined.

Code review is a core part of high quality implementation.
It helps ensure that:
* The design follows good practices.
* The code matches the style guides.
* The code is appropriately commented.
* Code changes are reflected in the documentation.
* The changes are reasonably structured.
* Commit messages are meaningful.

When doing code review, you should check if these guidelines are followed.
If some of the points are not met, or if you see potential improvements in the modified areas, bring this up in a comment.
The author of the PR will then address or comment on all feedback.
It is generally the responsibility of the reviewer who started the discussion to decide whether the feedback has been addressed appropriately.
If the author and the reviewer cannot find agreement, a third party should be brought into the discussion.

When reviewing code and giving/discussing feedback, keep in mind that:
* Code review is not design review.
  If a PR comes without clear motivation or is not aligned with project intent, this should be discussed first and separately from the actual code review.
* This is a collaborative, distributed open-source project bringing lots of people together with different motivations and backgrounds.
  Many people will see the same issue from different viewpoints.
  Always be friendly and patient.

See also: [reviewing pull requests on GitHub](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/reviewing-proposed-changes-in-a-pull-request).

## How to receive a code review?

Code review may be an intimidating process, especially if you're new to the open-source community.
Getting lots of comments on even minor style violations can be disheartening.
Know that your contributions are always appreciated - the reality is that in many cases initial code review is the most scrutiny a given piece of code will get.
Therefore, it is worth pushing to ensure it meets all coding standards rather than hoping it will be fixed in the future.

## Merging PRs

Changes made because of review feedback should go into the corresponding commits in the PR instead of having a single commit containing all changes addressing the feedback.
To keep a clean, linear history, no merge commits and no long series of "fixup" patches.
Instead, use rebase to restructure your work as a series of logically ordered, atomic patches (`git rebase -i` helps).
PRs should not be squashed when merging; keep the individual commits including commit messages making up the PR.

To reduce the risk of accidentally introducing bugs or breaking existing functionality, we leverage [continuous integration](./ci/README.md) (CI) checks on every PR.
The results of these CI checks [can be viewed](./ci/faq.md) through the GitHub web interface.
In general, CI should pass before merging any PRs.

If the CI checks for a PR succeed and the PR affects larger parts of the code base, it may be best to wait 24 hours before merging.
This allows project contributors spread across their many time zones an opportunity to provide feedback.

## TODO comments

We track non-trivial pieces of work via GitHub issues rather than TODO comments in the code.
We do not use TODO(name) comments as used in some code bases - if it is important enough to assign someone, it is worth tracking via an issue.

If you as a code reviewer come across TODOs, you should encourage the author to create a GitHub issue to track the work item, which can be referenced using a comment such as `// TODO(pavona/pavona#<issue_number>): <brief description>`.
Code authors are encouraged to use TODO rather than FIXME.

## Auto-generated code

This repo includes utilities to automatically generate parts of the source code based on configuration files and templates.
Examples for auto-generated RTL code include the register interface of the peripheral IP cores (using the register tool reggen), the top level (using topgen) and the main TL-UL crossbar (using tlgen).
Some of these auto-generated source files are checked into (committed to) the repository.
This allows people to both build the system without having to invoke the utilities and easily compare generated output after changes (with `git diff`).

To prevent people from editing auto-generated top-level files, these files both contain a header marking them as such, and they live in subfolders called `autogen/`.
When implementing changes that affect auto-generated files, the configuration or template file must be edited, the auto-generated files need to be regenerated and everything needs to be committed to the repository.

It can be helpful to split changes to auto-generated files into multiple commits:
* changes to any templates or scripts
* the re-generated source files
