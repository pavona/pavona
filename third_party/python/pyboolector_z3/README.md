# pyboolector Z3 compatibility package

This package provides the small PyBoolector API surface used by Pavona's
locked `pyvsc` version. It keeps `pyvsc` import and dependency metadata
compatible while implementing the solver operations on top of `z3-solver`.

The package is built as a pure-Python wheel and resolved through
`third_party/python/wheels` when `python-requirements.txt` is generated.
This avoids native PyBoolector source builds on Linux arm64.
