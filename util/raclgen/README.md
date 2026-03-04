# Raclgen: Generate RACL documentation and parameters

This tool is a helper script for generating output from register access control list (RACL) information.
It can:
* given a top configuration file, generate Markdown documentation of the RACL configurations
* given a RACL configuration file, IP block description, and RACL mapping file generate a set of SystemVerilog parameters

By default, these outputs are piped into standard output.
The documentation generated will consist of a set of RACL configuration tables for each IP in the specified top.
The SV parameters generated will the be a set of parameters of type `racl_policy_sel_t` that characterize the given IP's RACL policies.
The SV output is partially derived from the topgen template [`toplevel_racl_pkg_parameters.tpl`](../topgen/templates/toplevel_racl_pkg_parameters.tpl).

For an example of what raclgen output looks like, consult [`hw/top_darjeeling/ip_autogen/racl_ctrl/doc/racl_configuration.md`](../../hw/top_darjeeling/ip_autogen/racl_ctrl/doc/racl_configuration.md) and [`hw/top_darjeeling/rtl/autogen/top_darjeeling_racl_pkg.sv`](../../hw/top_darjeeling/rtl/autogen/top_darjeeling_racl_pkg.sv).

Like ipgen, raclgen can be used both as a command line tool and a Python library.

For more information about the concept of RACL itself, see the [general RACL overview](../../doc/contributing/hw/racl/README.md).

## RACL Configuration and Mapping

The RACL configuration schema is as follows:
| Key             | Kind     | Type  | Description                                                        |
| --------------- | -------- | ----- | ------------------------------------------------------------------ |
| error_response  | required | bool  | When true, return TLUL error on denied RACL access, otherwise not. |
| role_bit_lsb    | required | int   | RACL role bit LSB within the TLUL user bit vector.                 |
| role_bit_msb    | required | int   | RACL role bit MSB within the TLUL user bit vector.                 |
| ctn_uid_bit_lsb | required | int   | CTN UID bit LSB within the TLUL user bit vector.                   |
| ctn_uid_bit_msb | required | int   | CTN UID bit MSB within the TLUL user bit vector.                   |
| roles           | required | list  | List, specifying all RACL roles.                                   |
| policies        | required | group | Dict, specifying the policies of all RACL groups.                  |

The RACL mapping schema is as follows:
| Key       | Kind     | Type  | Description                                                                                                                                                     |
| --------- | -------- | ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| registers | optional | group | Dict, specifying the policy for each register.                                                                                                                  |
| windows   | optional | group | Dict, specifying the policy for each window.                                                                                                                    |
| ranges    | optional | list  | List, specifying the policy for each range; each element in this list must be a dict which contains the keys `base` (int), `size` (int), and `policy` (string). |

The default RACL configuration is:
```hjson
{
  "error_response": "false",
  "role_bit_lsb": 0,
  "role_bit_msb": 0,
  "ctn_uid_bit_lsb": 0,
  "ctn_uid_bit_msb": 0,
  "nr_role_bits": 1,
  "nr_ctn_uid_bits": 1,
  "nr_policies": 1,
  "policies": {},
  "rot_private_policy_rd": 0,
  "rot_private_policy_wr": 0
}
```

## Usage

```shell
$ util/raclgen.py --help
usage: 
raclgen.py --doc DOC
    Generates markdown documentation of the RACL configuration for a given top.

raclgen.py --racl-config RACL_CONFIG --ip IP --mapping MAPPING [--if-name IF_NAME]
    Generates the RACL policy selection vector for the given IP, RACL mapping, and interface name.
              

options:
  -h, --help            show this help message and exit
  --doc DOC, -d DOC     Path to top_topname.gen.hjson.
  --racl-config RACL_CONFIG, -r RACL_CONFIG
                        Path to RACL config hjson file.
  --ip IP, -i IP        Path to IP block hjson file.
  --mapping MAPPING, -m MAPPING
                        Path to RACL mapping hjson file.
  --if-name IF_NAME     TLUL path interface name. Required if multiple bus_interfaces exist.
```
