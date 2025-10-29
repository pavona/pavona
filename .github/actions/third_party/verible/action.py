#!/usr/bin/env python3

import os
import subprocess
import click
import warnings


def recursive_find(file_extensions, pwd):
    files = set()
    for obj in os.listdir(pwd):
        obj = os.path.join(pwd, obj)
        if os.path.isdir(obj):
            files.update(recursive_find(file_extensions, obj))
        if os.path.isfile(obj):
            _, ext = os.path.splitext(obj)
            if ext in file_extensions:
                files.add(obj)
    return files


def log_raw(issues, filename):
    with open(filename, 'w') as f:
        f.write(issues)


def print_annotations(issues):
    '''
    Print linter output in a way
    that is parsed by GitHub and used to annotate code automatically
    '''
    for issue in issues.splitlines():
        file_name, line, column, issue = issue.split(":", 3)
        print(f'::error file={file_name},line={line},col={column}::{issue}')


def unwrap_from_gha_string(args):
    # unwrap paths stored in GHA argument as a multiline string
    # each element in {args} can be either a file name
    #    or multiple file names concatenated with '\n'
    # for example: path=('./ibex/rtl\n./ibex/rtl/ibex_alu.sv\n', 'foobar')
    # returns a set of separate file names
    elements = set()
    for arg in args:
        new_elems = arg.split()
        elements.update(new_elems)

    return elements


def find_sources_in_paths(paths, exts):
    '''Scan {paths} for files with extensions from set
    '''
    files = set()
    for filename in paths:
        # check if filename is a directory or a source file
        if os.path.isdir(filename):
            new_files = recursive_find(exts, filename)
            files.update(new_files)
        elif os.path.isfile(filename):
            files.add(filename)
        else:
            warnings.warn(f"{filename} is not a valid file name!")

    return files


@click.command()
@click.option('--conf-file', '-c', type=str, required=False,
              help='lint rules configuration file')
@click.option('--extra-opts', '-e', required=False,
              help='extra options for the linter')
@click.option('--exclude-paths', '-x', required=False,
              help='exclude these paths from the files to lint')
@click.option('--extensions', '-t', type=str, required=False,
              help='lint files with these extensions (starting with a dot, split by comma)')
@click.option('--log-file', '-l', type=str, required=False,
              help='log file name')
@click.option('--patch', '-p', type=str, required=False,
              help='patch file name')
@click.argument('path', nargs=-1, required=True)
def main(conf_file, extra_opts, exclude_paths, extensions, log_file, patch, path):
    '''
    Lint .v and .sv files specified in PATHs
    '''
    if conf_file:  # GitHub Actions passes "" here if it's not used
        conf_file = ['--rules_config', conf_file]
    else:
        conf_file = []

    if extra_opts:
        extra_opts = extra_opts.split()
    else:
        extra_opts = []

    if patch:
        patch = ["--autofix=patch", "--autofix_output_file=" + patch]
    else:
        patch = []

    if extensions:
        extensions = set(ext if ext.startswith('.') else '.' + ext for ext in extensions.split())
    else:
        extensions = {'.v', '.sv'}

    paths = unwrap_from_gha_string(path)
    # set of target files to lint
    files = find_sources_in_paths(paths, extensions)

    if exclude_paths:
        for p in exclude_paths.split():
            # get rid of every file which starts with this path
            files = {f for f in files if not f.startswith(p)}

    if not files:
        warnings.warn("File set is empty, the action has nothing to do.")
        exit()

    command = (["verible-verilog-lint"]
               + patch + conf_file + extra_opts + list(files))
    print("Running " + " ".join(command) + "\n\n")
    verible_linted = subprocess.run(command, capture_output=True)

    issues = verible_linted.stderr.decode("utf-8")
    log_raw(issues, log_file if log_file else 'verible-verilog-lint.log')


if __name__ == '__main__':
    main()
