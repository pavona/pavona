# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Launcher implementation to run jobs as subprocesses on the local machine."""

import datetime
import os
import re
import shlex
import signal
import subprocess
from pathlib import Path
from typing import Union

from Launcher import ErrorMessage, Launcher, LauncherBusy, LauncherError

# How much of the end of each log read to carry over to the next one, so that a
# start marker split across two reads is still matched. Comfortably longer than
# the lines being looked for
_LOG_SCAN_TAIL_CHARS = 256


def _read_vmhwm_mb(pid: int) -> Union[float, None]:
    """Return a process's peak resident set size in MB, read from procfs.

    VmHWM is a high water mark that the kernel maintains from the moment the
    process starts, so a single read reports the true peak so far. That means
    there is no need to sample continuously and no way for a spike between two
    reads to go unnoticed.

    Opening unbuffered and reading once skips the buffering and UTF-8 decoding on
    a call made for every running job on every poll. VmHWM sits in the first
    kilobyte, so the long bitmasks at the end of the file do not matter.

    Returns None if the process has already exited or procfs cannot be read. A
    process with no memory map of its own, such as a kernel thread, reports no
    VmHWM at all and also comes back as None.
    """
    try:
        with open(f"/proc/{pid}/status", "rb", buffering=0) as f:
            blob = f.read(4096)
    except OSError:
        return None

    start = blob.find(b"VmHWM:")
    if start < 0:
        return None
    end = blob.find(b"kB", start)
    if end < 0:
        return None

    try:
        # The value is in kB, per proc(5).
        return int(blob[start + len(b"VmHWM:"):end]) / 1024
    except ValueError:
        return None


def _iter_job_pids(pid: int):
    """Yield the given process and every descendant of it.

    Descendants are read from /proc/<pid>/task/<tid>/children, which lists a
    thread's direct children. Walking down from the job costs a couple of reads
    per process belonging to it, rather than a scan of every process on the
    machine, which would be orders of magnitude dearer.

    Processes that exit midway through the walk are skipped rather than raising,
    since a job's process tree changes shape while it runs.
    """
    pending = [pid]
    seen = set()

    while pending:
        current = pending.pop()
        if current in seen:
            continue
        seen.add(current)
        yield current

        task_dir = f"/proc/{current}/task"
        try:
            tids = os.listdir(task_dir)
        except OSError:
            continue

        for tid in tids:
            try:
                with open(f"{task_dir}/{tid}/children", encoding="UTF-8") as f:
                    children = f.read().split()
            except OSError:
                continue

            for child in children:
                try:
                    pending.append(int(child))
                except ValueError:
                    continue


class LocalLauncher(Launcher):
    """Implementation of Launcher to launch jobs in the user's local workstation."""

    # Re-discover the job's process tree once every this many polls. See
    # _sample_peak_rss() for why the tree is not walked afresh every time.
    pid_walk_interval = 30

    def __init__(self, deploy) -> None:
        """Initialize common class members."""
        super().__init__(deploy)

        # Popen object when launching the job.
        self._process = None
        self._log_file = None

        # The job's process tree, and the countdown to re-walking it.
        self._job_pids = []
        self._pid_walk_countdown = 0

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
                    # Give the job a process group of its own. The command we
                    # run is a make wrapper which spawns the simulator as a
                    # separate process, so a group is what lets us later signal
                    # the whole job rather than just the wrapper. See
                    # _signal_job_group().
                    start_new_session=True,
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
        if self._reap() is None:
            # Still running.
            timeout_reason = self._timeout_reason()
            if timeout_reason is not None:
                self._kill_with_reason(timeout_reason)
                return "K"

            return "D"

        status, err_msg = self._check_status()
        self._post_finish(status, err_msg)

        return self.status

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

    def _reap(self) -> Union[int, None]:
        """Reap the process if it has finished, returning its exit code.

        Returns None while the process is still running.

        We reap with os.wait4() rather than Popen.poll() so as to receive the
        rusage that the kernel hands over at reap time. Its ru_maxrss field is
        the job's peak resident set size, and the moment the process is gone
        that number is unknowable, so for a job that runs to completion this is
        the only chance to capture it. The kernel rolls the peak of a reaped
        descendant into its parent's figure, so this covers the simulator even
        though the process we launched is only its wrapper.
        """
        if self._process.returncode is None:
            try:
                pid, wait_status, usage = os.wait4(self._process.pid, os.WNOHANG)
            except ChildProcessError:
                # Something else already reaped it, so the rusage is lost. Fall
                # back to Popen's own bookkeeping for the exit code.
                self._process.poll()
            else:
                if pid == 0:
                    return None

                # Record the exit code the way Popen would have, which also
                # tells Popen not to try reaping the child a second time.
                self._process.returncode = os.waitstatus_to_exitcode(wait_status)
                # ru_maxrss is in kB on Linux.
                self._record_peak_rss(usage.ru_maxrss / 1024)

        self.exit_code = self._process.returncode
        return self.exit_code

    def _record_peak_rss(self, peak_rss_mb: Union[float, None]) -> None:
        """Keep the largest peak resident set size seen for this job, in MB."""
        if peak_rss_mb is None:
            return
        if (
            self.deploy.job_peak_rss is None
            or peak_rss_mb > self.deploy.job_peak_rss  # noqa: W503
        ):
            self.deploy.job_peak_rss = peak_rss_mb

    def _sample_peak_rss(self) -> Union[float, None]:
        """Read the running job's peak resident set size so far, in MB.

        The process dvsim launches is a make wrapper, and the simulator it goes
        on to spawn is where the memory actually goes, so reading the launched
        process alone reports a handful of MB and misses the job entirely. Walk
        the whole tree instead and report the largest peak in it.

        The largest rather than the total, because VmHWM is a per-process high
        water mark and the peaks of two processes need not coincide, so adding
        them up would overstate the job. For the shapes dvsim runs, where one
        simulator dwarfs its wrapper, the largest peak is the job's peak. A job
        with two large processes running at once would be understated.

        Returns None once the processes have gone, since procfs then has nothing
        left to tell us about them.
        """
        if self._process is None:
            return None

        # Walking the tree costs a read per thread of every process in the job,
        # whereas reading the peaks costs one read per process, so the walk is
        # what to avoid repeating. An EDA job's tree settles as soon as its
        # simulator is up and does not change shape after that, so re-walk it
        # only occasionally. Discovering a process late does not lose any of its
        # peak, because VmHWM covers the whole life of the process.
        #
        # Until the job has spawned something below the wrapper, though, keep
        # walking on every poll: a job can balloon within seconds of starting,
        # and the memory budget must not be blind while that happens. The walk
        # is cheap in that window, since a wrapper has a single thread.
        if len(self._job_pids) < 2 or self._pid_walk_countdown <= 0:
            self._job_pids = list(_iter_job_pids(self._process.pid))
            self._pid_walk_countdown = self.pid_walk_interval
        self._pid_walk_countdown -= 1

        peak_rss_mb = None
        for pid in self._job_pids:
            pid_peak_mb = _read_vmhwm_mb(pid)
            if pid_peak_mb is None:
                continue
            if peak_rss_mb is None or pid_peak_mb > peak_rss_mb:
                peak_rss_mb = pid_peak_mb

        self._record_peak_rss(peak_rss_mb)
        return peak_rss_mb

    def _kill_with_reason(self, message: str) -> None:
        """Kill the job and record why dvsim decided to kill it."""
        self._kill()
        self._post_finish(
            "K",
            ErrorMessage(line_number=None, message=message, context=[message]),
        )

    def _signal_job_group(self, sig: int) -> None:
        """Send a signal to every process belonging to the job.

        Signaling only the process we launched is not enough: that process is a
        make wrapper, and the simulator it spawns is a separate process, so the
        wrapper dies while the simulator carries on holding its license and
        writing its wave dump. The job has a process group of its own (see
        _do_launch), so one killpg reaches all of it.

        Falls back to signaling just the process we have a handle on when the
        group cannot be used, and gives up quietly if that process has gone too,
        which only happens when the job was on its way out regardless.
        """
        if self._process is None:
            return

        try:
            pgid = os.getpgid(self._process.pid)
        except OSError:
            pgid = None

        # Only signal the group if it really is the job's own. A job launched
        # without a new session of its own sits in dvsim's group, and signaling
        # that would take down dvsim itself along with every other running job.
        # The interactive path deliberately does not start a new session, so
        # this is reachable rather than theoretical.
        if pgid is not None and pgid != os.getpgid(0):
            try:
                os.killpg(pgid, sig)
                return
            except OSError:
                pass

        try:
            self._process.send_signal(sig)
        except OSError:
            pass

    def _kill(self) -> None:
        """Kill the running job.

        Try to kill the whole job. Send SIGTERM first, wait a bit, and then send
        SIGKILL if it didn't work.
        """
        if self._process is None:
            # process already dead or didn't start
            return

        # Read the job's peak memory before signaling it. This is the last
        # moment at which procfs can still tell us, and a killed job is exactly
        # the case where the tool never gets to report the figure itself.
        self._sample_peak_rss()

        self._signal_job_group(signal.SIGTERM)
        try:
            # The wrapper exiting is the best proxy we have for the job being
            # done: it does not return until the simulator it spawned has gone.
            self._process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            self._signal_job_group(signal.SIGKILL)

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
            # One cheap procfs read before it dies, so that even a force-quit
            # leaves the job's memory figure behind for the report.
            self._sample_peak_rss()
            self._signal_job_group(signal.SIGKILL)
            self._process.poll()

        # Finish the job off properly even though we are in a hurry: this is
        # what sizes the output directory and records the job as killed, and
        # it is the whole point of force-quitting rather than crashing out.
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
