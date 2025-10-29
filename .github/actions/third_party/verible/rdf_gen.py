#!/usr/bin/env python3
import re
import click
import json
from unidiff import PatchSet


class Fix:
    def __init__(self, filename, text, start_line, end_line):
        self.filename = filename
        self.text = text
        self.start_line = start_line
        self.end_line = end_line

    def __repr__(self):
        return 'Fix: ' + self.filename


class ErrorMessage:
    def __init__(self, filename, line, column, message):
        self.filename = filename
        self.line = line
        self.column = column
        self.message = message
        self.suggestion = None

    def __repr__(self):
        return f'{self.filename}:{self.line}:{self.column}: {self.message}'

    def fix(self, suggestion):
        '''Adds a change suggestion to an existing ErrorMessage'''
        self.suggestion = suggestion

    def as_rdf_dict(self):
        '''Creates a dictionary with data used as a component
        in Reviewdog Diagnostic Format

        The result is a dict for a single element of 'diagnostics' node in RDF
        implements this structure:
        https://github.com/reviewdog/reviewdog/blob/master/proto/rdf/reviewdog.proto#L39
        '''
        result = {
            'message': self.message,
            'location': {
                'path': self.filename,
                'range': {
                    'start': {'line': self.line, 'column': self.column}
                }
            },
            'severity': 'WARNING',
            # rule code is embedded in the message, but we can move it here:
            # 'code':
        }

        if self.suggestion:
            result['suggestions'] = [{
                'range': {
                    'start': {'line': self.line, 'column': self.column},
                    'end': {'line': self.suggestion.end_line}
                },
                'text': self.suggestion.text
            }]

        return result


def error_messages_to_rdf(messages):
    '''Create a dictionary structured as Reviewdog Diagnostic Format
    using ErrorMessages

    implements this structure:
    https://github.com/reviewdog/reviewdog/blob/master/proto/rdf/reviewdog.proto#L23

    Returns
    -------
        a dictionary ready to be json-dumped to look like this:
        https://github.com/reviewdog/reviewdog/tree/master/proto/rdf#rdjson

    '''
    result = {
        'source': {'name': 'verible-verilog-lint',
                   'url': 'https://github.com/chipsalliance/verible'},
        'severity': 'WARNING'
    }
    result['diagnostics'] = tuple([msg.as_rdf_dict() for msg in messages])
    return result


def read_efm(filename):
    '''Reads errorformat-ed log from linter

    the syntax of each line should be: "%f:%l:%c: %m"
    the fields are documented here:
        https://vim-jp.org/vimdoc-en/quickfix.html#error-file-format
    all non-matching lines are skipped

    Returns
    -------
        a list of ErrorMessage, an instance for each error is created
    '''
    with open(filename, 'r') as f:
        lines = f.readlines()

    messages = []
    for line in lines:
        data = re.split(':', line)
        if len(data) < 4:
            # skip this line, it's not errorformat
            continue
        if len(data) > 4:
            # there are ':' inside the message part
            # merge the message part into one string
            data = data[0:3] + [':'.join(data[3:])]

        data[2] = re.split("-", data[2])[0]

        # now the data has 4 elements
        data = [elem.strip() for elem in data]
        messages.append(
            ErrorMessage(data[0], int(data[1]), int(data[2]), data[3])
        )

    return messages


def read_diff(filename):
    '''Read unified diff file with code changes

    Returns
    -------
        a list of Fix, an instance for each hunk in the diff file is created
    '''
    patch_set = PatchSet.from_filename(filename, encoding='utf-8')
    fixes = []

    # iterating over a PatchSet returns consecutive lines
    # indexing [] a PatchSet returns patches for consecutive files
    for file_no in range(len(patch_set)):
        patch = patch_set[file_no]
        path = patch.path
        for hunk in patch:
            removed_lines = [
                line[1:] for line in hunk.source if line.startswith('-')
            ]
            added_lines = [
                line[1:] for line in hunk.target if line.startswith('+')
            ]
            start_line = hunk.source_start + 1
            end_line = hunk.source_start + 1 + len(removed_lines)

            # if the fix only deletes text,
            #     added_lines will be empty as expected
            # if the fix only adds text
            #     start_line == end_line as expected
            fixes.append(
                Fix(path, ''.join(added_lines), start_line, end_line)
            )

    return fixes


def apply_fixes(err_messages, fixes):
    '''Add change suggestions to ErrorMessages using Fix objects

    this function matches Fixes with their corresponding ErrorMessages
    using file names and line numbers, then applies the Fixes

    Prints a message if a Fix doesn't match any of the ErrorMessages
        the Fix is skipped in this case

    Returns
    -------
        None
    '''
    for fix in fixes:
        filtered_msgs = [
            msg for msg in err_messages
            if msg.filename == fix.filename and msg.line == fix.start_line
        ]

        if not filtered_msgs:
            # Did not find any errors to be solved by fix
            continue

        filtered_msgs[0].fix(fix)


@click.command()
@click.option('--efm-file', '-e', type=click.Path(exists=True), required=True,
              help='name of a file containing linter output in errorformat')
@click.option('--diff-file', '-d', type=click.Path(exists=True),
              required=False, help='name of a file containing '
                                   'change suggestions in diff format')
def main(efm_file, diff_file):
    '''Generate Reviewdog Diagnostic Format file,
    using a log file from a linter (errorformat) and optionally a patch with
    fix suggestions
    '''
    messages = read_efm(efm_file)

    if diff_file:
        fixes = read_diff(diff_file)
        apply_fixes(messages, fixes)

    print(json.dumps(error_messages_to_rdf(messages)))


if __name__ == '__main__':
    main()
