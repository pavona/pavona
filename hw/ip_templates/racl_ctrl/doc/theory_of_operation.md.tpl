# Theory of Operation

${"##"} Block Diagram

![RACL Ctrl Block Diagram](./racl_ctrl_block_diagram.svg)

${"##"} Introduction
RACL is a lightweight, fine-grained access control mechanism to restrict CSR access to specific originators, which fulfils this need.
The RACL controller is the hardware that implements part of this mechanism. For more information regarding the RACL protocol, see [here](../../../../../doc/contributing/hw/racl/README.md)

${"##"} RACL Controller

For a top-level that uses RACL, there is an associated RACL Controller (`racl_ctrl`), which acts as the interface between the TileLink bus and the RACL matching logic.
The RACL Controller implements the policy registers, distributes them to subscribing IPs and collects error logs from them through its hardware interface.

<!-- BEGIN-FEATURE: RACL.POLICY_ENFORCEMENT -->
<!-- BEGIN-FEATURE: RACL.ROT_POLICY -->
${"###"} RACL Policies
Each policy register takes the form of a pair of permission bitmaps, `ReadPerm` and `WritePerm`, where each bit corresponds to a role.
E.g., if 16 different roles are defined, the register looks as follows, where the bit position of each role is defined by the role encoding that is specified via the `role_id` in the [top level configuration file](../../../../../doc/contributing/hw/racl/README.md#top-level-racl-configuration).

|                 | Role 0 | Role 1 | ... | Role 14 | Role 15 |
|-----------------|:------:|:------:|:---:|:-------:|:-------:|
| *Bit position:* | *0*    | *1*    | ... | *14*    | *15*    |
| `WritePerm`     |        |        |     |         |         |
| `ReadPerm`      |        |        |     |         |         |

Each `ReadPerm` bit indicates if the corresponding role (see column header) has read permission to objects (e.g., registers) controlled by this policy.
Each `WritePerm` bit indicates if the corresponding role has write permission.
When the bit is 1, the corresponding permission is granted and when it is 0 it is denied.

The policy registers is mapped as shown below.
Note, the policy registers are 64-bit aligned to allow room for future use.

| Name     | Offset | Bits 31:16  | Bits 15:0  |
|----------|:------:|:-----------:|:----------:|
| Policy 0 | 0x000  | `writePerm` | `readPerm` |
|          | 0x004  | reserved    | reserved   |
| Policy 1 | 0x008  | `writePerm` | `readPerm` |
|          | 0x00c  | reserved    | reserved   |
| Policy 2 | 0x010  | `writePerm` | `readPerm` |
|          | 0x014  | reserved    | reserved   |
| Policy 3 | 0x018  | `writePerm` | `readPerm` |
|          | 0x01c  | reserved    | reserved   |
| Policy 4 | 0x020  | `writePerm` | `readPerm` |
|          | 0x024  | reserved    | reserved   |

In the [RACL configuration file](../../../../../doc/contributing/hw/racl/README.md#top-level-racl-configuration), exactly one policy must be defined with `rot_private: true`.
This policy is then used to statically protect the policy registers themselves.
The read and write permissions are used from this policy as defined in the configuration file at design time.
For all policy registers, the configuration specified in the configuration file is the reset default value.
However, depending on the permissions defined for the `rot_private`-designated policy, the policy registers may also be updated at runtime.
<!-- END-FEATURE: RACL.ROT_POLICY -->

${"####"} Distribution of policies

RACL policies on the system can be configured through [registers](./registers.md) in `racl_ctrl`.
Each policy is specified in a register named after that policy.
The set of policies is then distributed by `racl_ctrl` through a single vector called `racl_policies_o`.
<!-- END-FEATURE: RACL.POLICY_ENFORCEMENT -->

<!-- BEGIN-FEATURE: RACL.ERROR_LOG -->
<!-- BEGIN-FEATURE: RACL.ERROR_ARBITRATION -->
<!-- BEGIN-FEATURE: RACL.EXT_USE -->
${"##"} Error logs

A subscribing IP can log an error with `racl_ctrl` using the IP's item in the `racl_error_i` port.
Similarly, a RACL error from outside of the system can be reported through a particular index of the `racl_error_external_i` port.
If multiple errors are logged at the same cycle, arbitration will record the one with the lowest index in this list:
- Items from `racl_error_i` (internal errors)
- Items from `racl_error_external_i` (errors from outside of the system)
- An error reported by `racl_ctrl` itself.

If there is more than one error reported (concurrently or over several cycles), the `error_log.overflow` field will be set.
The log can be cleared by writing `1` to the `error_log.valid` field.
This clears every field of `error_log` and the `error_log_address` register.
Writing `0` to `error_log.valid` has no effect.
During a RACL error, `error_log.valid` is set and an interrupt is raised.
<!-- END-FEATURE: RACL.ERROR_LOG -->
<!-- END-FEATURE: RACL.ERROR_ARBITRATION -->
<!-- END-FEATURE: RACL.EXT_USE -->

${"##"} Alerts and security

A TileLink transaction with incorrect integrity bits will cause a TL integrity error.
This generates a `fatal_fault` alert.
% if enable_shadow_reg:

This instantiation of `racl_ctrl` uses shadowed policy registers.
A storage error (meaning that the shadowed copy is not an inverse) causes the `fatal_fault` alert.
An update error causes the `recov_ctrl_update_err` alert, which is not fatal.
% endif

<!-- BEGIN-FEATURE: RACL.EXT_USE -->
${"##"} Out of Tree Usage

RACL may also be used outside of Pavona.
For this purpose, the RACL controller provides an additional input to collect error logs from externally subscribing IPs.
See the [interface documentation for the Dragonfly racl_ctrl](interfaces.md).
Additionally, the [`util/raclgen.py`](../../../../../util/raclgen/README.md) tool can be used to generate the necessary policy selection vectors.
<!-- END-FEATURE: RACL.EXT_USE -->

<!-- BEGIN-FEATURE: RACL.ERROR_ARBITRATION -->
${"##"} RTL Implementation

RACL is opt-in.
If no `racl.hjson` is defined in the top-level HJSON and no RACL mappings are used there, no RACL logic is generated.
There will be no logic overhead to the design (see [System with No RACL Use](#system-with-no-racl-use) for details).

![Implementation structure](implementation.svg)

The tooling generates a parameterized RACL controller based on the top-level [configuration](../../../../../doc/contributing/hw/racl/README.md#configuration).
This controller implements the policy registers (statically protected via the `rot_private`-designated policy) and exposes all policies via a top-level vector.

![Connections](connections.svg)

The RACL policy vector gets distributed to all IPs that subscribe to that RACL Controller group.
The RACL policy vector, along with a static per-instance selection vector is routed to the IP that subscribes to RACL.
A RACL-supported IP's top-level I/O interface is changed to include RACL signals such as the policy vector, a policy selection vector, and a RACL error log output.

These wires are routed to the internal reg\_top.
If IPs use more than one reg\_top, each reg\_top will get a dedicated selection vector.
- `racl_policies_i`: A vector of all possible policies defined by `racl.hjson`.
  This is coming from the RACL controller.
- `racl_policy_sel_i`: A vector of indices that select the policy from the policy vector.
  Entry 0 of this array defines the policy selection for register 0 in that IP, entry 1 defines the selection for register 1, etc.
  In the example from [the RACL spec](../../../../doc/contributing/hw/racl/README.md#top-level_racl_configuration), the vector might look like `[1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 2, 1]`.
  + If an IP features multiple reg\_tops, each will have its own `racl_policy_sel_<reg_top_name>_i` policy selector input.
    `racl_violation_o` will then be the OR combination of violations among reg\_tops.
    If multiple RACL violations can happen at the same time, they must be arbitrated appropriately before passing the error log to the RACL controller.
<!-- END-FEATURE: RACL.ERROR_ARBITRATION -->

${"###"} System with No RACL Use
The system supports instantiating IPs with and without RACL alongside.
If an IP is instantiated in a non-RACL use case, no overhead is added to the IP.
The additional inputs are tied off, and the outputs are left open.
Inside the IP, the RACL comparison logic is gated via a per-instance synthesis parameter, hence the (unused) RACL logic appears neither in synthesis nor in DV.
If the system does not use RACL at all, there is no overhead in terms of additional transported bits in the crossbar.
