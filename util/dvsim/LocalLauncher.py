# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Launcher implementation to run jobs as subprocesses on the local machine."""

import datetime
import os
import re
import shlex
import subprocess
from pathlib import Path
from typing import Union

from Launcher import ErrorMessage, Launcher, LauncherBusy, LauncherError

# How much of the end of each log read to carry over to the next one, so that a
# start marker split across two reads is still matched. Comfortably longer than
# the lines being looked for
_LOG_SCAN_TAIL_CHARS = 256


class LocalLauncher(Launcher):
    """Implementation of Launcher to launch jobs in the user's local workstation."""

    def __init__(self, deploy) -> None:
        """Initialize common class members."""
        super().__init__(deploy)

        # Popen object when launching the job.
        self._process = None
        self._log_file = None

        # When the job started doing its work, as opposed to when it was
        # launched. None until we see it start. See _detect_job_start().
        self._run_start_time = None

        # How far through the log we have looked for the job starting, and the
        # tail of what we read, so a marker split across two reads is not missed.
        self._log_scan_offset = 0
        self._log_scan_tail = ""

    def _do_launch(self) -> None:
        # Update the shell's env vars with self.exports. Values in exports must
        # replace the values in the shell's env vars if the keys match.
        exports = os.environ.copy()
        exports.update(self.deploy.exports)

        # Clear the magic MAKEFLAGS variable from exports if necessary. This
        # variable is used by recursive Make calls to pass variables from one
        # level to the next. Here, self.cmd is a call to Make but it's
        # logically a top-level invocation: we don't want to pollute the flow's
        # Makefile with Make variables from any wrapper that called dvsim.
        if "MAKEFLAGS" in exports:
            del exports["MAKEFLAGS"]

        self._dump_env_vars(exports)

        if not self.deploy.sim_cfg.interactive:
            log_path = Path(self.deploy.get_log_path())
            timeout_mins = self.deploy.get_timeout_mins()

            self.timeout_secs = timeout_mins * 60 if timeout_mins else None

            try:
                self._log_file = log_path.open(
                    "w",
                    encoding="UTF-8",
                    errors="surrogateescape",
                )
                self._log_file.write(f"[Executing]:\n{self.deploy.cmd}\n\n")
                self._log_file.flush()

                self._process = subprocess.Popen(
                    shlex.split(self.deploy.cmd),
                    bufsize=4096,
                    universal_newlines=True,
                    stdout=self._log_file,
                    stderr=self._log_file,
                    env=exports,
                )

            except BlockingIOError as e:
                raise LauncherBusy(f"Failed to launch job: {e}") from e

            except subprocess.SubprocessError as e:
                raise LauncherError(f"IO Error: {e}\nSee {log_path}") from e

            finally:
                self._close_job_log_file()
        else:
            # Interactive: Set RUN_INTERACTIVE to 1
            exports["RUN_INTERACTIVE"] = "1"

            # Interactive. stdin / stdout are transparent
            # no timeout and blocking op as user controls the flow
            print("Interactive mode is not supported yet.")
            print(f"Cmd : {self.deploy.cmd}")
            self._process = subprocess.Popen(
                shlex.split(self.deploy.cmd),
                stdin=None,
                stdout=None,
                stderr=subprocess.STDOUT,
                # string mode
                universal_newlines=True,
                env=exports,
            )

            # Wait until the process exit
            self._process.wait()

        self._link_odir("D")

    def poll(self) -> Union[str, None]:
        """Check status of the running process.

        This returns 'D', 'P', 'F', or 'K'. If 'D', the job is still running.
        If 'P', the job finished successfully. If 'F', the job finished with
        an error. If 'K' it was killed.

        This function must only be called after running self.dispatch_cmd() and
        must not be called again once it has returned 'P' or 'F'.
        """
        if self._process is None:
            return "E"

        elapsed_time = datetime.datetime.now() - self.start_time
        self.job_runtime_secs = elapsed_time.total_seconds()
        if self._process.poll() is None:
            timeout_reason = self._timeout_reason()
            if timeout_reason is not None:
                self._kill_with_reason(timeout_reason)
                return "K"

            return "D"

        self.exit_code = self._process.returncode
        status, err_msg = self._check_status()
        self._post_finish(status, err_msg)

        return self.status

    def _kill_with_reason(self, message: str) -> None:
        """Kill the job and record why dvsim decided to kill it."""
        self._kill()
        self._post_finish(
            "K",
            ErrorMessage(line_number=None, message=message, context=[message]),
        )

    def _detect_job_start(self) -> None:
        """Look for the point in the log where the job started doing its work.

        Sets _run_start_time when one of the deploy's started_patterns turns up.
        Only the bytes added to the log since the last look are read, so the cost
        does not grow with the log, and nothing is read at all once the job has
        started.
        """
        patterns = self.deploy.started_patterns
        if not patterns:
            # Nothing marks the start for this flow, so treat the job as under
            # way from the moment it was launched.
            self._run_start_time = self.start_time
            return

        try:
            with open(self.deploy.get_log_path(), "rb") as f:
                f.seek(self._log_scan_offset)
                chunk = f.read()
                self._log_scan_offset = f.tell()
        except OSError:
            # The log is not there yet, or cannot be read. Try again next poll.
            return

        if not chunk:
            return

        text = self._log_scan_tail + chunk.decode("UTF-8", errors="surrogateescape")
        for pattern in patterns:
            if re.search(pattern, text, re.MULTILINE):
                self._run_start_time = datetime.datetime.now()
                self._log_scan_tail = ""
                return

        # Hold on to the tail, so that a marker straddling two reads still
        # matches when the rest of it arrives
        self._log_scan_tail = text[-_LOG_SCAN_TAIL_CHARS:]

    def _timeout_reason(self) -> Union[str, None]:
        """Return why the job ought to be killed for taking too long, or None.

        A job is timed from the point where it starts doing its work rather than
        from the point where it was launched, because the gap between the two is
        spent queueing for a license.

        The waiting and the running phases therefore get separate limits and
        separate messages, so that a report can tell a job that never got a
        license apart from one that genuinely ran too long.
        """
        if self.deploy.gui:
            # The user is driving, so nothing counts as too slow
            return None

        if self._run_start_time is None:
            self._detect_job_start()

        if self._run_start_time is None:
            wait_mins = Launcher.max_job_wait_mins
            if wait_mins and self.job_runtime_secs > wait_mins * 60:
                return (
                    f"Job did not start running within {wait_mins} minutes of "
                    f"being launched, so it was most likely still waiting for a "
                    f"license"
                )
            return None

        if not self.timeout_secs:
            return None

        run_secs = (
            datetime.datetime.now() - self._run_start_time
        ).total_seconds()
        if run_secs > self.timeout_secs:
            timeout_mins = self.deploy.get_timeout_mins()
            return f"Job timed out after running for {timeout_mins} minutes"

        return None

    def _kill(self) -> None:
        """Kill the running process.

        Try to kill the running process. Send SIGTERM first, wait a bit,
        and then send SIGKILL if it didn't work.
        """
        if self._process is None:
            # process already dead or didn't start
            return

        self._process.terminate()
        try:
            self._process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            self._process.kill()

    def kill(self) -> None:
        """Kill the running process.

        This must be called between dispatching and reaping the process (the
        same window as poll()).
        """
        self._kill()
        self._post_finish(
            "K",
            ErrorMessage(line_number=None, message="Job killed!", context=[]),
        )

    def force_kill(self) -> None:
        """SIGKILL the process without waiting around for it to die.

        We deliberately do not block on the process here. A job that is stuck
        in uninterruptible IO (writing a large wave dump over NFS, say) does
        not die the moment SIGKILL lands, and a force-quit must not hang on it.
        poll() reaps the process if it has already gone and returns at once if
        it has not, leaving a zombie that is cleaned up when dvsim exits.
        """
        if self._process is not None:
            self._process.kill()
            self._process.poll()

        # Finish the job off properly even though we are in a hurry: this is
        # what records the job as killed, and it is the whole point of
        # force-quitting rather than crashing out.
        self._post_finish(
            "K",
            ErrorMessage(
                line_number=None,
                message="Job force-killed when dvsim was force-quit.",
                context=[],
            ),
        )

    def _post_finish(self, status: str, err_msg: Union[ErrorMessage, None]) -> None:
        self._close_job_log_file()
        self._process = None
        super()._post_finish(status, err_msg)

    def _close_job_log_file(self) -> None:
        """Close the file descriptors associated with the process."""
        if self._log_file:
            self._log_file.close()
