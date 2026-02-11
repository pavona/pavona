# GitHub Notes

The Pavona source tree is maintained on GitHub in a monolithic repository called [pavona](https://github.com/pavona/pavona).

These notes are for people who intend to contribute to the Pavona source code.
If you don't intend to do this, you can simply clone the Pavona repository following the [Getting Started](../getting_started/README.md) guide.
The Getting Started guide describes exactly what you need to do with Git, but there is much more to Git and GitHub than cloning a repo; see [try.github.io](https://try.github.io).

## Getting a working repository

To develop in the repository you will need to get a copy on your local machine.
To contribute back to the main repository through the _pull request_ process, you need to first make your own _fork_ of the repository.
Once you have forked the main repository, you will clone your fork to your local machine.

First, log into GitHub and go to the [pavona repository](https://github.com/pavona/pavona), then click "Fork".
On the "Create a new fork" page, fill in or adjust the Owner and Description fields as needed, then click "Create fork".
This creates a copy of the Pavona repository in your own account that you can directly edit.

Then, configure Git on your local machine with your name and email address.
These commands will set your name and email for all uses of Git on your local machine, so you may have already completed these steps.
In that case, there is no need to repeat these commands.
(See below if you want to use a different email address for this repo.)

Check the parameters:
```console
$ git config -l
```

If "user.name" and "user.email" do not appear, then set them:

```console
$ git config --global user.name "My Name"
$ git config --global user.email "my_name@email.com"
```

`git` will take care of prompting for your GitHub user name and password when it is required, but it can be useful to allow it to cache these credentials (set here to an hour using the timeout in seconds) so you don't have to enter every time:

```console
$ git config --global credential.helper 'cache --timeout=3600'
```

Now, clone your fork of the Pavona repository:

```console
$ git clone git@github.com:<your GitHub username>/pavona
```

A directory called `pavona` should appear in your current working directory.
To make it easy to fetch changes from the original Pavona repository (also called "upstream"), add a new Git _remote_.
Print the known Git remotes with `git remote -v`:

```console
$ git remote add upstream git@github.com:pavona/pavona
$ git remote -v
origin      git@github.com:<your GitHub username>/pavona (fetch)
origin      git@github.com:<your GitHub username>/pavona (push)
upstream    git@github.com:pavona/pavona (fetch)
upstream    git@github.com:pavona/pavona (push)
```

To fetch changes made upstream (without affecting your current work), use `git fetch`:

```console
$ git fetch upstream
```

## Working in your local repository

The repository that you have created locally will initially be on the `master` branch.
In general, your fork's `master` branch should track the `master` branch upstream.
The recommended flow is to make your own branch; it is conventionally named based on the change you are making.
The following Git command creates a new branch called `my-new-change` and switches to it:

```console
$ git checkout -b my-new-change
```

To check the status of your changes at any time, use `git status`:

```console
$ git status
On branch my-new-change
nothing to commit, working tree clean
```

`git status` will indicate the state of files added, deleted, or edited in this repository.

Once you are happy with your changes, stage them for commit with `git add`:

```console
$ git add <files to add>
```

Use `git status` and `git diff --staged` to review your changes.
When you are satisfied with your changes, create a commit:

```console
$ git commit -s
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

```console
$ git status
$ git push origin my-new-change
```

Then you need to go to your repository in GitHub and either select branch from the pulldown or often there is a status message that you can click on, review the changes and make a Pull Request.
You can add reviewers and get your change reviewed.

If you need to make changes to satisfy the reviews then you do that in your local repository on the same branch.
You will need to `add` files and commit again.
It is normally best to squash your changes into a single commit by doing it with `--amend` which will give you a chance to edit the message.
If you do this you need to force `-f` the push back to your repo.

```console
$ git add <files to add>
$ git commit --amend
$ git status
$ git push -f origin my-new-change
```

Once the reviewers are happy you can "Rebase and Merge" the Pull Request on GitHub, delete the branch there (it offers to do this when you do the merge).
You can delete the branch in your local repository with:

```console
$ git checkout master
$ git branch -D my-new-change
```

When a Pull Request contain multiple commits, those commits should be logically independent.
Interactive rebase can be used to manipulate commits in a pull request to achieve that goal.
Rebasing is commonly used to squash commits that fix up issues reported during review back into the relevant commit.

```console
$ git rebase -i `git merge-base {current_branch} master`
```

Then, an editor will open.
Follow the instructions given there, to reorder and combine commits, or to change the commit message.
Then update the PR branch in the GitHub remote repository.

```console
$ git push -f origin HEAD
```

## Automatically adding a Signed-off-by line for your commits

One option to avoid having to remember to add `-s` to `git commit` is to configure `git` to append it to your commit messages for you.
This can be done using an executable hook.
An appropriate hook can be installed by executing this from the root of your repository checkout:

```console
$ cat <<"EOF" > .git/hooks/prepare-commit-msg
#!/bin/sh

# Add a Signed-off-by line to the commit message if not already present.
git interpret-trailers --if-exists doNothing --trailer \
  "Signed-off-by: $(git config user.name) <$(git config user.email)>" \
  --in-place "$1"
EOF
$ chmod +x .git/hooks/prepare-commit-msg
```

## Update your repository with changes in the upstream repository

There is a little work to do to keep everything in sync.
Normally you want to first get your local repository `master` branch up to date with the upstream repository (**upstream**) and then you use that to update your fork (**origin**).

```console
$ git checkout master
$ git pull --ff-only upstream master
$ git push origin
```

If you do this while you have changes on some other branch then before a Pull Request will work you need to be sure your branch merges cleanly into the newly updated upstream master branch.
Assuming you got the local `master` branch up to date with the procedure above you can now _rebase_ your changes on the new `master`.
Assuming you have your changes on the local branch `my-new-change`:

```console
$ git checkout my-new-change
$ git rebase master
```

If you are lucky this will just work, it unwinds your changes, gets the updated `master` and replays your changes.
If there are conflicts then you need a big pot of coffee and patience (see next section).

Once everything has rebased properly you can do


```console
$ git log
```

And see that the changes you committed on the branch are at the top of the log followed by the latest changes on the `master` branch.

Note: be mindful about which branch you are working on.
If you have added new commits to your local `master` branch, aligning it with `upstream` using `git pull --ff-only` may fail.
An alternative is to use `git pull --rebase` in that case, which directly rebases your local `master` branch onto `upstream/master`.
Do not use plain `git pull` or `git merge` commands, as they do not preserve a linear commit history.
See also [this tutorial](https://www.atlassian.com/git/tutorials/merging-vs-rebasing) to learn more about `git rebase` vs `git merge`.

## Dealing with conflicts after a rebase

If a rebase fails because of conflicts between your changes and the code you are rebasing to then git will leave your working directories in a bit of a mess and expect you to fix it.
Often the conflict is simple (e.g. you and someone else added a new routine at the same place in the file) and resolution is simple (have both in the new output).
Sometimes there is more to untangle if different changes were done to the same routine.
In either case Git has marked that you are in a conflict state and work is needed before you can go back to using your local Git tree as usual.

The Git output actually describes what to do (once you are used to how to read it).
For example:

```console
$ git rebase master
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

```console
$ git rebase --abort
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

```console
$ git status
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

```console
$ git add build_docs.py
$ git rebase --continue
Applying: [util][pystyle] Clean Python style in single file tools
```

If there were more than one patch outstanding (which isn't usual if you use the `commit --amend` flow) then you may get subsequent conflicts following the `rebase --continue` as other patches are replayed.

You can check the rebase worked as expected by looking at the log to see your branch is one commit (or more if there were more) ahead of the `master` branch.

```console
$ git log

commit dd8721d2b1529c575c4aef988219fbf2ecd3fd1b (HEAD -> sastyle)
Author: Mark Hayter <mark.hayter@gmail.com>
Date:   Thu Jan 10 09:41:20 2019 +0000

    [util][pystyle] Clean Python style in single file tools

    Result of lintpy.py --fix on the diff and build_docs tools

    Tested with  ./diff_generated_util_output.py master

commit cb85dc42199e925ad09c45d33f6483a14764b93e (upstream/master, origin/master, origin/HEAD, master)

```

This shows the new commit (`HEAD` of the branch `sastyle`) and the preceding commit is at the `master` branch (and at the same point as `master` on both `origin` and `upstream` so everything is in sync at `master`).

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

```console
$ git fetch upstream pull/{ID}/head:{BRANCH_NAME}
$ # e.g. git fetch upstream pull/5/head:docgen_review
$ git checkout {BRANCH_NAME}
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

    ```console
    $ git checkout -b br_localandremote br_localfix
    $ git fetch upstream pull/345/head:pr_345
    $ git rebase pr_345
    ```

* The `cherry-pick` method:

    ```console
    $ git checkout -b br_localandremote br_localfix
    $ git fetch upstream pull/345/head:pr_345
    $ # find the commit ID from pr_345 that you want to merge: b345232342ff
    $ git cherry-pick b345232342ff
    ```
* The `merge` method:

    ```console
    $ git fetch upstream pull/345/head:pr_345
    $ git checkout -b br_localandremote br_localfix
    $ git merge pr_345
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

    ```console
    $ git fetch upstream pull/{ID}/head:{BRANCH_NAME}
    $ git checkout {BRANCH_NAME}
    ```

* Step 2: Make necessary changes

    ```console
    $ git add...
    $ git commit -m "Add CFG examples to UART specification"
    ```

* Step 3: Create your GitHub branch for the pull request

    ```console
    $ git push -u origin {BRANCH_NAME}:<remote_branch_name>
    ```

    You can use any branch name for the pull request.
    If you want to the created branch name same as local branch name, this can simply be:

    ```console
    $ git push -u origin HEAD
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
