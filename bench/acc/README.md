# ACC Benchmarks

Benchmark every ACC crypto operation and report the cycle counts and the code size of the ACC binaries:

```sh
bench/acc/collect_stats.sh //sw/acc/crypto/tests:benchmarks
logs=bench/acc/logs/$(git log -n1 --pretty=%h)
bench/acc/analyze_stats.py $logs --csv $logs/cycles.csv --size-csv $logs/sizes.csv
```

To benchmark another operation, set `stats = STATS` on its test and add it to a `*_benchmarks` suite in [sw/acc/crypto/tests](../../sw/acc/crypto/tests/BUILD).
Tests named `<op>_test[<N>][_<variant>]` are averaged into one row per operation and variant.

The code size covers the `run_*` binaries in [sw/acc/crypto](../../sw/acc/crypto/BUILD).
