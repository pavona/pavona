# ACC memutil wrapper

This code is a wrapper around `VerilatorMemUtil` (defined in
`hw/dv/verilator/cpp`).

To use it, depend on the core file. If you're using dvsim, you'll also
need to include `acc_memutil_sim_opts.hjson` in your simulator
configuration and add `"{tool}_acc_memutil_build_opts"` to the
`en_build_modes` variable.
