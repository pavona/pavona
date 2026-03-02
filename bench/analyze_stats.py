#! /usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import csv
import pathlib
import math
import re

CYCLES_PAT = re.compile(r'.*instructions in ([0-9]+) cycles.')
FILENAME_PAT = re.compile(r'(.*)_test[0-9]+.stats')


def parse_file_stats(file):
    stats = {}
    for line in file.readlines():
        m = re.match(CYCLES_PAT, line)
        if m:
            stats['total_cycles'] = int(m.group(1))
    if 'total_cycles' not in stats:
        raise ValueError(f'Unable to find cycle count in file: {file.name}')
    return stats


def parse_dir_stats(dirpath):
    out = {}
    for path in dirpath.iterdir():
        with path.open() as f:
            out[path.name] = parse_file_stats(f)
    return out


def analyze_stats(file_stats):
    ops = {}
    for filename, stats in file_stats.items():
        m = re.match(FILENAME_PAT, filename)
        if not m:
            raise ValueError(f'Unexpected file name format: {filename}')
        op = m.group(1)
        if op in ops:
            assert all(k in ops[op] for k in stats)
            assert all(k in stats for k in ops[op])
        else:
            ops[op] = {k: [] for k in stats}
        for k, v in stats.items():
            ops[op][k].append(v)

    out = {}
    for op, stats in ops.items():
        total_cycles = stats['total_cycles']
        count = len(total_cycles)
        assert count != 0
        out[op] = {}
        out[op]['count'] = count
        out[op]['avg_cycles'] = sum(total_cycles) // count
        out[op]['min_cycles'] = min(total_cycles)
        out[op]['max_cycles'] = max(total_cycles)
        total_cycles.sort()
        if count % 2:
            median_cycles = total_cycles[count // 2]
        else:
            below = total_cycles[(count // 2) - 1]
            above = total_cycles[(count // 2)]
            median_cycles = (below + above) // 2
        out[op]['median_cycles'] = median_cycles
        out[op]['stddev'] = round(get_stddev(total_cycles))

    return out


def pretty_print_table(rows):
    if len(rows) == 0:
        return None
    ncols = len(rows[0])
    assert all([len(r) == ncols for r in rows])
    rows = [[str(x) for x in r] for r in rows]
    col_widths = [max([len(r[i]) for r in rows]) for i in range(ncols)]
    for r in rows:
        line = ''
        for i in range(ncols):
            padding = ' ' * (col_widths[i] - len(r[i]))
            if i == 0:
                # first column is left-aligned
                line += r[i]
                line += padding
            else:
                # introduce separator
                line += ' | '
                # non-first columns are right-aligned
                line += padding
                line += r[i]
        print(line)


def get_variance(nums):
    '''Calculates the statistical variance of a set of numbers.

    The variance is the average squared distance from the mean.
    '''
    mean = sum(nums) / len(nums)
    sqdiff = [(mean - n)**2 for n in nums]
    return sum(sqdiff) / len(sqdiff)


def get_stddev(nums):
    '''Calculates the standard deviation of a set of numbers.

    The standard deviation is the square root of the variance.
    '''
    return math.sqrt(get_variance(nums))


def evaluate_samples(samples):
    '''Given a set of statistical samples, determine the quality of the sampling.'''
    # Find operations that appear in all samples.
    ops = None
    for stats in samples:
        if ops is None:
            ops = set(stats.keys())
        else:
            ops &= set(stats.keys())

    for op in ops:
        counts = [stats[op]['count'] for stats in samples]
        if len(set(counts)) != 1:
            print(f'Warning: test counts for {op} differ across samples: {counts}')

    rows = [['Operation', 'Weighted avg cycles', 'Stddev of avg cycles', 'Relative stdddev']]
    means = {}
    for op in sorted(list(ops)):
        weighted_avgs = [stats[op]['count'] * stats[op]['avg_cycles'] for stats in samples]
        counts = [stats[op]['count'] for stats in samples]
        means[op] = sum(weighted_avgs) / sum(counts)

    # Get the average cycles for each operation across the samples and
    # calculate the standard deviation.
    for op in sorted(list(ops)):
        avgs = [stats[op]['avg_cycles'] for stats in samples]
        stddev = round(get_stddev(avgs))
        mean = round(means[op])
        stddev_pct = (100 * stddev) / mean
        rows.append([f'{op}', f'{mean}', f'{stddev}', f'{stddev_pct:.02f}'])
    return rows


def compare_stats(stats1, stats2):
    ops1 = set(stats1.keys())
    ops2 = set(stats2.keys())
    ops = ops1 & ops2
    diff = (ops1 - ops) | (ops2 - ops)
    if diff:
        print(f'Warning: skipping operations that only appear in one dataset: {diff}')

    rows = [['Measurement', 'Baseline', 'New', 'Percentage change']]
    for op in sorted(list(ops)):
        for stat in ['avg_cycles', 'median_cycles']:
            new = stats1[op][stat]
            base = stats2[op][stat]
            diff = new - base
            pct = (diff / base) * 100
            rows.append([f'{op} {stat}', f'{base}', f'{new}', f'{pct:.02f}'])
    return rows


def get_stats(stats):
    rows = [['Operation', 'Measurement', 'Value']]
    measurements = [
        'count',
        'avg_cycles',
        'median_cycles',
        'min_cycles',
        'max_cycles',
        'stddev']
    for op in sorted(stats.keys()):
        op_stats = stats[op]
        for measurement in measurements:
            rows.append([f'{op}', measurement, op_stats[measurement]])
    return rows


def write_csv(samples, csvpath):
    measurements = ['count', 'avg_cycles', 'median_cycles', 'min_cycles', 'max_cycles']
    header = ['operation'] + measurements
    with csvpath.open('w') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        for stats in samples:
            for op in stats:
                writer.writerow([op] + [stats[op][m] for m in measurements])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Analyze and compare collected execution stats for OTBN programs.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='The number of directories determines the type of analysis.\n'
        '- 1 directory: print aggregate statistics for the sample.\n'
        '- 2 directories: compare the first measurements against the second.\n'
        '- 3+ directories: analyze the quality (e.g. stddev) of the sampling method.')
    parser.add_argument(
        'benchdir', nargs='+', type=pathlib.Path,
        help=('Directories with stat logs to analyze.'))
    parser.add_argument(
        '--csv', required=False, type=pathlib.Path,
        help=('CSV file for results.'))
    args = parser.parse_args()

    samples = []
    for d in args.benchdir:
        files = parse_dir_stats(d)
        samples.append(analyze_stats(files))

    if args.csv is not None:
        write_csv(samples, args.csv)

    if len(args.benchdir) == 0:
        raise ValueError('Must specify at least one statistics directory.')
    elif len(args.benchdir) == 1:
        pretty_print_table(get_stats(samples[0]))
    elif len(args.benchdir) == 2:
        print(f'Comparing {args.benchdir[0].name} against baseline {args.benchdir[1].name}.')
        table = compare_stats(*samples)
        pretty_print_table(table)
    else:
        print(f'Evaluating {len(samples)} samples...')
        table = evaluate_samples(samples)
        pretty_print_table(table)
