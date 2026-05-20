# Raclgen: Generate RACL documentation and parameters

This tool is a helper script for generating output from register access control list (RACL) information.
It can:
* given a top configuration file, generate Markdown documentation of the RACL configurations
* given a RACL configuration file, IP block description, and RACL mapping file generate a set of SystemVerilog parameters

By default, these outputs are piped into standard output.
The documentation generated will consist of a set of RACL configuration tables for each IP in the specified top.
The SV parameters generated will the be a set of parameters of type `racl_policy_sel_t` that characterize the given IP's RACL policies.
The SV output is partially derived from the topgen template [`toplevel_racl_pkg_parameters.tpl`](../topgen/templates/toplevel_racl_pkg_parameters.tpl).

For an example of what raclgen output looks like, consult [`hw/top_dragonfly/ip_autogen/racl_ctrl/doc/racl_configuration.md`](../../hw/top_dragonfly/ip_autogen/racl_ctrl/doc/racl_configuration.md) and [`hw/top_dragonfly/rtl/autogen/top_dragonfly_racl_pkg.sv`](../../hw/top_dragonfly/rtl/autogen/top_dragonfly_racl_pkg.sv).

Like ipgen, raclgen can be used both as a command line tool and a Python library.

For more information about the concept of RACL itself, see the [general RACL overview](../../doc/contributing/hw/racl/README.md).

## Usage

<!-- BEGIN CMDGEN util/selfdoc.py quote:util/raclgen.py --help -->
```
$ util/raclgen.py --help
usage: 
    raclgen.py --doc DOC
        Generates markdown documentation of the RACL configuration for a given top.

    raclgen.py --racl-config RACL_CONFIG --ip IP --mapping MAPPING [--if-name IF_NAME]
        Generates the RACL policy selection vector for the given IP, RACL mapping, and
        interface name.

options:
  -h, --help            show this help message and exit
  --doc DOC, -d DOC     Path to top_topname.gen.hjson.
  --racl-config RACL_CONFIG, -r RACL_CONFIG
                        Path to RACL config hjson file.
  --ip IP, -i IP        Path to IP block hjson file.
  --mapping MAPPING, -m MAPPING
                        Path to RACL mapping hjson file.
  --if-name IF_NAME     TLUL path interface name. Required if multiple
                        bus_interfaces exist.
```
<!-- END CMDGEN -->
