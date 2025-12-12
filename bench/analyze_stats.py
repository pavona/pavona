#! /usr/bin/env python3

import argparse
import pathlib
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
            ops[op] = {k:[] for k in stats}
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

    return out


def pretty_print_table(rows, aligns):
    if len(rows) == 0:
        return None
    ncols = len(rows[0])
    assert len(aligns) == ncols
    assert all([len(r) == ncols for r in rows])
    assert all([x in ['l','r'] for x in aligns])
    rows = [[str(x) for x in r] for r in rows]
    col_widths = [max([len(r[i]) for r in rows]) for i in range(ncols)]
    for r in rows:
        line = ''
        for i in range(ncols):
            if aligns[i] == 'l':
                line += r[i]
            line += ' ' * (col_widths[i] - len(r[i]))
            if aligns[i] == 'r':
                line += r[i]
        print(line)


def format_change(new, base, statname):
    '''Represents change in benchmark values as a table row.'''
    newval = new[statname]
    baseval = base[statname]
    diff = newval - baseval
    sign = '' if diff < 0 else '+'
    pct = (diff / baseval) * 100
    return [baseval, ' -> ', newval, f' ({sign}{diff},', f'{sign}{pct:.02f}%)']


def compare_stats(stats1, stats2):
    ops1 = set(stats1.keys())
    ops2 = set(stats2.keys())
    ops = ops1 & ops2
    diff = (ops1 - ops) | (ops2 - ops)
    if diff:
        print(f'Warning: skipping operations that only appear in one dataset: {diff}')

    for op in sorted(list(ops)):
        print(f'--- {op} ---')
        rows = []
        rows.append(['Average cycles: '] + format_change(stats1[op], stats2[op], 'avg_cycles'))
        rows.append(['Median cycles: '] + format_change(stats1[op], stats2[op], 'median_cycles'))
        aligns = ['l', 'r', 'r', 'r', 'r', 'r']
        pretty_print_table(rows, aligns)


def print_stats(stats):
    for op in sorted(stats.keys()):
        op_stats = stats[op]
        print(f'--- {op} ({op_stats["count"]} tests) ---')
        print('Average cycles:', op_stats['avg_cycles'])
        print('Median cycles: ', op_stats['median_cycles'])
        print('Minimum cycles:', op_stats['min_cycles'])
        print('Maximum cycles:', op_stats['max_cycles'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument(
        'benchdir', type=pathlib.Path,
         help=('Directory with collected execution stats.'))
    parser.add_argument(
        '--compare', type=pathlib.Path, required=False,
         help=('Second directory with collected execution stats, for comparison.'))
    args = parser.parse_args()

    files = parse_dir_stats(args.benchdir) 
    stats = analyze_stats(files)

    if args.compare:
        cfiles = parse_dir_stats(args.compare) 
        cstats = analyze_stats(cfiles)
        print(f'Comparing {args.benchdir.name} against baseline {args.compare.name}.')
        compare_stats(stats, cstats)
    else:
        print_stats(stats)
