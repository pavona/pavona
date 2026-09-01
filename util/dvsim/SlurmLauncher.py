# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import logging as log
import os
import shlex
import shutil
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Union

from Launcher import ErrorMessage, Launcher, LauncherError
from utils import VERBOSE


def _parse_size_mb(text: str) -> Union[float, None]:
    """Convert a size as Slurm writes it into MB, or None if it is not one.

    sacct and sstat report sizes with a single letter unit and sometimes a
    decimal point, as in `1234K` or `1.50G`. A bare number means bytes. An
    empty field, which is what a step that has reported nothing yet gives, is
    not a size.
    """
    text = text.strip()
    if not text:
        return None

    scale = {'K': 1 / 1024, 'M': 1.0, 'G': 1024.0, 'T': 1024.0 * 1024}
    factor = 1 / (1024 * 1024)
    if text[-1].upper() in scale:
        factor = scale[text[-1].upper()]
        text = text[:-1]

    try:
        return float(text) * factor
    except ValueError:
        return None


SLURM_QUEUE = os.environ.get("SLURM_QUEUE", "hw-m")
SLURM_MEM = os.environ.get("SLURM_MEM", "16G")
SLURM_MINCPUS = os.environ.get("SLURM_MINCPUS", "8")
SLURM_TIMEOUT = os.environ.get("SLURM_TIMEOUT", "240")
SLURM_CPUS_PER_TASK = os.environ.get("SLURM_CPUS_PER_TASK", "8")
SLURM_SETUP_CMD = os.environ.get("SLURM_SETUP_CMD", "")


class SlurmLauncher(Launcher):
    # How long to leave between asking Slurm for a job's memory. Each ask is a
    # subprocess and a round trip to the controller, so at one poll a second
    # across a full regression an unthrottled check would be a considerable
    # load on the controller for a figure that moves slowly.
    mem_poll_interval_secs = 30

    def __init__(self, deploy):
        '''Initialize common class members.'''

        super().__init__(deploy)

        # Popen object when launching the job.
        self.process = None
        self.slurm_log_file = Path(self.deploy.get_log_path() + '.slurm')
        self.slurm_script_file = None

        # Where the job writes its own Slurm job id, so that the peak memory
        # can be asked for without having to search the queue for the job.
        self.slurm_jobid_file = Path(f'{self.slurm_log_file}.jobid')
        self._slurm_job_id = None
        self._last_mem_poll = None

    def _do_launch(self):
        # replace the values in the shell's env vars if the keys match.
        exports = os.environ.copy()
        exports.update(self.deploy.exports)

        # Clear the magic MAKEFLAGS variable from exports if necessary. This
        # variable is used by recursive Make calls to pass variables from one
        # level to the next. Here, self.cmd is a call to Make but it's
        # logically a top-level invocation: we don't want to pollute the flow's
        # Makefile with Make variables from any wrapper that called dvsim.
        if 'MAKEFLAGS' in exports:
            del exports['MAKEFLAGS']
        self._dump_env_vars(exports)

        # Write command to a script on shared storage to avoid quoting issues
        # with bash -c "..." when the command contains double quotes.
        script_dir = self.slurm_log_file.parent
        try:
            script_dir.mkdir(parents=True, exist_ok=True)
        except OSError as e:
            raise LauncherError(f'File Error: {e}\n'
                                f'Could not create the job directory {script_dir}')

        # The job reports its own id, which is the cheapest way for the
        # launcher to learn it: srun does not hand it back, and searching the
        # queue for the job by name costs a round trip per job.
        script_body = '#!/bin/bash\n'
        script_body += f'echo "${{SLURM_JOB_ID}}" > {self.slurm_jobid_file}\n'
        if SLURM_SETUP_CMD:
            script_body += f'{SLURM_SETUP_CMD}\n'
        script_body += f'{self.deploy.cmd}\n'

        try:
            with tempfile.NamedTemporaryFile(mode='w', suffix='.sh',
                                             dir=script_dir, delete=False) as f:
                f.write(script_body)
                self.slurm_script_file = Path(f.name)
            self.slurm_script_file.chmod(0o755)
        except OSError as e:
            raise LauncherError(f'File Error: {e}\n'
                                f'Could not write the job script in {script_dir}')

        # Encapsulate the run command with the slurm invocation. srun forwards
        # its standard input to the job by default, so every concurrent job
        # would contend for the terminal that dvsim was started from and stall
        # until that terminal delivered input.
        slurm_cmd = (f'srun -p {SLURM_QUEUE} --mem={SLURM_MEM} --mincpus={SLURM_MINCPUS} '
                     f'--time={SLURM_TIMEOUT} --cpus-per-task={SLURM_CPUS_PER_TASK} '
                     f'--job-name={shlex.quote(self.deploy.full_name)} '
                     f'--input=none {self.slurm_script_file}')

        try:
            with self.slurm_log_file.open('w') as out_file:
                out_file.write("[Executing]:\n{}\n\n".format(self.deploy.cmd))
                out_file.flush()

                log.log(VERBOSE, 'Executing slurm command: %s', slurm_cmd)
                log.log(VERBOSE, 'Job script:\n%s', script_body)
                self.process = subprocess.Popen(shlex.split(slurm_cmd),
                                                bufsize=4096,
                                                universal_newlines=True,
                                                stdin=subprocess.DEVNULL,
                                                stdout=out_file,
                                                stderr=out_file,
                                                env=exports)
        except IOError as e:
            raise LauncherError(f'File Error: {e}\nError while handling {self.slurm_log_file}')
        except subprocess.SubprocessError as e:
            raise LauncherError(f'IO Error: {e}\nSee {self.deploy.get_log_path()}')
        finally:
            self._close_process()

        self._link_odir("D")

    def poll(self):
        '''Check status of the running process

        This returns 'D', 'P' or 'F'. If 'D', the job is still running. If 'P',
        the job finished successfully. If 'F', the job finished with an error.

        This function must only be called after running self.dispatch_cmd() and
        must not be called again once it has returned 'P' or 'F'.
        '''

        assert self.process is not None
        self._tick_runtime()
        if self.process.poll() is None:
            reason = self._limit_exceeded()
            if reason is not None:
                self._kill_with_reason(reason)
                return 'K'

            return 'D'

        # Copy slurm job results to log file
        if self.slurm_log_file.exists():
            try:
                with self.slurm_log_file.open('r') as slurm_file:
                    try:
                        with open(self.deploy.get_log_path(), 'a') as out_file:
                            shutil.copyfileobj(slurm_file, out_file)
                    except IOError as e:
                        raise LauncherError(f'File Error: {e} when handling '
                                            f'{self.deploy.get_log_path()}')
                # Remove the temporary file from the slurm process
                self.slurm_log_file.unlink()
            except IOError as e:
                raise LauncherError(f'File Error: {e} when handling {self.slurm_log_file}')

        self.exit_code = self.process.returncode
        status, err_msg = self._check_status()
        self._post_finish(status, err_msg)
        return status

    def kill(self):
        '''Kill the running process.

        This must be called between dispatching and reaping the process (the
        same window as poll()).
        '''
        self._kill()
        self._post_finish(
            'K',
            ErrorMessage(line_number=None, message='Job killed!', context=[]))

    def _job_id(self) -> Union[str, None]:
        """Return the job's Slurm id, or None before the job has reported it.

        The job writes it once, at the top of the generated script, so there is
        nothing to re-read after the first success.
        """
        if self._slurm_job_id is None:
            try:
                self._slurm_job_id = self.slurm_jobid_file.read_text().strip() or None
            except OSError:
                return None
        return self._slurm_job_id

    def _peak_mem_mb(self) -> Union[float, None]:
        """Return the largest peak resident set size seen for this job, in MB.

        Slurm measures the job on the node that runs it and sstat reports that
        without needing the accounting database, which is what makes a memory
        ceiling enforceable for a job dvsim cannot see. Asking is expensive
        enough to be throttled, so between asks the figure already recorded is
        returned unchanged.
        """
        job_id = self._job_id()
        if job_id is None:
            return self.deploy.job_peak_rss

        now = time.monotonic()
        if (self._last_mem_poll is not None and
                now - self._last_mem_poll < self.mem_poll_interval_secs):
            return self.deploy.job_peak_rss
        self._last_mem_poll = now

        try:
            result = subprocess.run(
                ['sstat', '-a', '-n', '-P', '-j', job_id, '-o', 'MaxRSS'],
                capture_output=True, text=True, timeout=30)
        except (OSError, subprocess.SubprocessError):
            return self.deploy.job_peak_rss

        # A job between steps, or one that has just finished, reports nothing.
        for line in result.stdout.splitlines():
            self._record_peak_rss(_parse_size_mb(line))

        return self.deploy.job_peak_rss

    def _sample_before_ending(self) -> None:
        """Ask for the job's memory one last time while it can still answer.

        A job that is about to be killed is exactly the job whose tool never
        gets to report the figure itself, and sstat has nothing to say about a
        job that has gone. The throttle is cleared so that this ask is not the
        one that gets skipped.
        """
        self._last_mem_poll = None
        self._peak_mem_mb()

    def force_kill(self) -> None:
        """Kill the job at once, without waiting for it to wind down.

        Invoked when dvsim is force-quit. Terminating srun releases the
        allocation, and not waiting matters because a job stuck writing a wave
        dump over NFS does not die promptly and a force-quit must not hang on
        it.
        """
        if self.process is not None:
            self._sample_before_ending()
            self.process.kill()
            self.process.poll()

        self._post_finish(
            'K',
            ErrorMessage(line_number=None,
                         message='Job force-killed when dvsim was force-quit.',
                         context=[]))

    def _kill(self) -> None:
        '''Cancel the job by terminating the srun that holds it.

        srun forwards the signal to the job and releases the allocation, so
        there is no need to reach for scancel.
        '''
        if self.process is None:
            return

        self._sample_before_ending()

        # Send SIGTERM first, wait a bit, and then send SIGKILL if it did not
        # work.
        self.process.terminate()
        try:
            self.process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            self.process.kill()

    def _post_finish(self, status, err_msg):
        super()._post_finish(status, err_msg)
        if self.slurm_script_file and self.slurm_script_file.exists():
            self.slurm_script_file.unlink()
            self.slurm_script_file = None
        if self.slurm_jobid_file.exists():
            self.slurm_jobid_file.unlink()
        self._close_process()
        self.process = None

    def _close_process(self):
        '''Close the file descriptors associated with the process.'''

        assert self.process
        if self.process.stdout:
            self.process.stdout.close()
