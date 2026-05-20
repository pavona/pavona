# Formal Verification Setup

_Before following this guide, make sure you've followed the [dependency installation and software build instructions](README.md)._

This document aims help you get started with a formal verification effort.
While most of the focus is on development of a testbench from scratch, it should also be useful to understand how to contribute to an existing effort.

Please refer to the [assertions](../../hw/formal/README.md) for information on how formal verification is done in Pavona.

## Formal property verification (FPV)

The formal property verification is used to prove assertions in the target.
There are three sets of FPV jobs in Pavona. They are all under the directory `hw/top_egret/formal`.
* `top_egret_fpv_ip_cfgs.hjson`: List of IP targets.
* `top_egret_fpv_prim_cfgs.hjson`: List of prim targets (such as counters, fifos, etc) that are usually imported by an IP.
* `top_egret_fpv_sec_cm_cfgs.hjson`: List of IPs that contains standard security countermeasure assertions. This FPV environment only proves these security countermeasure assertions. Detailed description of this FPV use case is documented in [Running FPV on security blocks for common countermeasure primitives](../../hw/formal/README.md#running-fpv-on-security-blocks-for-common-countermeasure-primitives).

To automatically create a FPV testbench, it is recommended to use the [fpvgen](../../util/fpvgen/README.md) tool to create a template.
To run the FPV tests in `dvsim`, please add the target to the corresponding `top_egret_fpv_{category}_cfgs.hjson` file , then run with command:
```console
util/dvsim/dvsim.py hw/top_egret/formal/top_egret_fpv_{category}_cfgs.hjson --select-cfgs {target_name}
```

It is recommended to add the FPV target to [lint](../../hw/lint/README.md) script `hw/top_egret/lint/top_egret_fpv_lint_cfgs.hjson` to quickly find typos.

## Formal connectivity verification

The connectivity verification is mainly used for exhaustively verifying system-level connections.
User can specify the connection ports via a CSV format file in `hw/top_egret/formal/conn_csvs` folder.
User can trigger top_egret's connectivity test using `dvsim`:
```
util/dvsim/dvsim.py hw/top_egret/formal/chip_conn_cfg.hjson
```

The connectivity testplan is documented under `hw/top_egret/data/chip_conn_testplan.hjson`.
