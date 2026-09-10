# Memory Protection

The Ibex core lacks a [Memory Management Unit (MMU)](https://en.wikipedia.org/wiki/Memory_management_unit), so the memory access policy is controlled using the RISC-V enhanced physical memory protection (ePMP).
In addition, the option for a single- or dual-stage ROM in different top-level designs presents unique challenges for correctly managing memory access.
This document describes the management of the ePMP at each stage of the boot.

## Background: ePMP on Ibex

ePMP controls what regions of the Ibex RISC-V core’s memory map may be used for what purpose at what time.
Ibex contains 16 *slots* for ePMP configurations that apply access controls to different regions of the address space.

The addresses referenced by each ePMP region are controlled by the `PMPADDR0`–`PMPADDR15` registers.
Access controls for each region are controlled by individual bytes within four 4-byte registers, `PMPCFG0`–`PMPCFG3`.
For example, the least-significant byte (LSB) of `PMPCFG0` controls the configuration for the region assigned to `PMPADDR0`.
The second-LSB of `PMPCFG0` is associated with `PMPADDR1`, and so on.

Below is a table summarizing the registers controlling each region:

| Entry | Address Register | Configuration Bits       |
| ------ | ---------------- | ------------------------ |
| 0      | `PMPADDR0`       | `PMPCFG0 & 0xff`         |
| 1      | `PMPADDR1`       | `(PMPCFG0 >> 8) & 0xff`  |
| 2      | `PMPADDR2`       | `(PMPCFG0 >> 16) & 0xff` |
| 3      | `PMPADDR3`       | `(PMPCFG0 >> 24) & 0xff` |
| 4      | `PMPADDR4`       | `PMPCFG1 & 0xff`         |
| 5      | `PMPADDR5`       | `(PMPCFG1 >> 8) & 0xff`  |
| 6      | `PMPADDR6`       | `(PMPCFG1 >> 16) & 0xff` |
| 7      | `PMPADDR7`       | `(PMPCFG1 >> 24) & 0xff` |
| 8      | `PMPADDR8`       | `PMPCFG2 & 0xff`         |
| 9      | `PMPADDR9`       | `(PMPCFG2 >> 8) & 0xff`  |
| 10     | `PMPADDR10`      | `(PMPCFG2 >> 16) & 0xff` |
| 11     | `PMPADDR11`      | `(PMPCFG2 >> 24) & 0xff` |
| 12     | `PMPADDR12`      | `PMPCFG3 & 0xff`         |
| 13     | `PMPADDR13`      | `(PMPCFG3 >> 8) & 0xff`  |
| 14     | `PMPADDR14`      | `(PMPCFG3 >> 16) & 0xff` |
| 15     | `PMPADDR15`      | `(PMPCFG3 >> 24) & 0xff` |

### ePMP Addressing Modes

ePMP supports multiple options for encoding an address range that make different tradeoffs between the number of ePMP slots consumed and required alignment of the region.

The simplest addressing mode is **Top of Range (TOR)**.
A TOR region specifies explicitly the start and end address of the region, consuming two consecutive ePMP slots.
Per the RISC-V spec, the TOR address mode is only set to the `PMPCFG*` byte associated with the slot containing the upper-bound of the range.
The slot containing the lower-bound has its configuration byte set to `OFF`, even though its `PMPADDR*` register is set.

The other important addressing mode is **Naturally Aligned Power of Two (NAPOT)**.
NAPOT regions consume only one ePMP slot instead of two, but the memory region is required to be a power-of-two size and have its start address aligned to a multiple of its size.
For example, a 64-kibibyte NAPOT region must be aligned to a 64K boundary.
The `PMPADDR` register for a NAPOT region is encoded as `start >> 2 | (end - start - 1) >> 3)`.
The **Naturally Aligned 4-byte (NA4)** region type is a variation of NAPOT that locks the alignment to 4-bytes.

### Access Control

RISC-V provides three mechanisms for enforcing security constraints on different levels of the software stack with respect to ePMP: *privilege levels* and *locking*.

RISC-V has three privilege levels (from most to least restrictive): **User (U)**, **Supervisor (S)**, and **Machine (M)**.
The **Machine Mode Whitelist Policy (MMWP)** bit of the `MSECCFG` register controls whether writes by M-Mode code to unmapped regions should trigger a fault.
In addition, each ePMP slot has a `Locked` bit.
The relationship between this bit and the privilege modes changes dramatically depending on the value of the **Machine Mode Lockdown (MML)** bit of the `MSECCFG` register.
After a reset, `MML=0`, and it can be irreversibly set to 1 at any point during boot.

#### When `MML=0`

In this mode, the `Locked` bit on an ePMP slot means that the restrictions of the slot apply to M-Mode in addition to U/S-Mode, and the slot cannot be modified by M-Mode code *unless* the **Read Lock Bypass (`RLB`)** bit is set.
`RLB` is set to 1 at boot and can be irreversibly cleared at any point during boot.

For security, locked regions must reside in the lowest-numbered slots when jumping to untrusted code using this mode.
This is because RISC-V accepts the lowest-numbered matching slot in the event of a region overlap.
If a lower-numbered slot than a locked region uses were unlocked, malicious firmware could overwrite the unlocked slot to grant arbitrary permissions to the same address range as the locked slot.

#### When `MML=1`

In this mode, the `Locked` bit has an entirely different meaning.
Setting `Locked` on a slot when `MML=1` marks the slot as accessible only in M-Mode.
When `Locked` is clear, the slot is accessible only in U/S-Mode.
An exception is slots marked both writable and executable, which mark the slot as *shared* between M-Mode and U/S-Mode, rather than actually granting write and execute permissions at the same time.

An additional consequence of having MML set is that the restrictions imposed by setting `Locked` when `MML=0` always apply, regardless of whether `Locked` is set or not.
This means that `MML`=1 and `RLB`=0 implies no ePMP updates can be performed until the next reset, even by M-Mode code.

## Boot ePMP Management Sequence

The remainder of this document describes the management of ePMP at each stage of the boot flow, from chip reset through user application execution.

### Ibex ePMP State on Reset

Ibex is [hard-coded](https://github.com/pavona/pavona/blob/main/hw/top_dragonfly/rtl/ibex_pmp_reset_pkg.sv) to boot with the following ePMP configuration.
Notably, `MMWP` is set to 1 from the outset and can never be cleared at any time.
As a result, the configuration below enables the ROM to execute and read/write to CSRs, but it cannot access any other memory until it performs explicit ePMP configuration.

- `MMWP=1`
- `MML=0`
- `RLB=1`

| Entry | Memory Block | Address Mode | Access Modes | Locked? |
| ----- | ------------ | ------------ | ------------ | :-----: |
| 0     |              | OFF          |              |         |
| 1     |              | OFF          |              |         |
| 2     | ROM          | NAPOT        | ReadExecute  | X       |
| 3     |              | OFF          |              |         |
| 4     |              | OFF          |              |         |
| 5     |              | OFF          |              |         |
| 6     |              | OFF          |              |         |
| 7     |              | OFF          |              |         |
| 8     |              | OFF          |              |         |
| 9     |              | OFF          |              |         |
| 10    | MMIO (lo)    | OFF\*[^1]    |              |         |
| 11    | MMIO (hi)    | TOR          | ReadWrite    | X       |
| 12    |              | OFF          |              |         |
| 13    |              | OFF[^2]      |              |         |
| 14    |              | OFF          |              |         |
| 15    |              | OFF          |              |         |

### ROM Initial Setup

Shortly after reset, the ROM updates the ePMP from the initial boot configuration to:

1. Restrict its own execute permission to the address range that actually contains its `.text` region.
1. Grant itself read-write access to the main SRAM, allowing it to set up a stack for itself.
1. Set up a guard region that will trigger a fault if the stack overflows.
1. In the single-stage ROM only, grant itself read-access to the region containing the silicon creator firmware at rest, so it can verify its manifest.

- `MMWP=1`
- `MML=0`
- `RLB=1`

| Entry | Memory Block            | Address Mode | Access Modes | Locked? |
| ----- | ----------------------- | ------------ | ------------ | :-----: |
| 0     | ROM Text (lo)           | OFF\*        |              |         |
| 1     | ROM Text (hi)           | TOR          | ReadExecute  | X       |
| 2     | ROM                     | NAPOT        | ReadOnly     | X       |
| 3     |                         | OFF          |              |         |
| 4     |                         | OFF          |              |         |
| 5     |                         | OFF          |              |         |
| 6     |                         | OFF          |              |         |
| 7     |                         | OFF          |              |         |
| 8     |                         | OFF          |              |         |
| 9     |                         | OFF          |              |         |
| 10    | MMIO (lo)               | OFF\*        |              |         |
| 11    | MMIO (hi)               | TOR          | ReadWrite    | X       |
| 12    |                         | OFF          |              |         |
| 13    | FLASH (single ROM only) | NAPOT        | ReadOnly     | X       |
| 14    | Stack Guard             | NA4          | NoAccess     | X       |
| 15    | Main SRAM               | NAPOT        | ReadWrite    | X       |

### ROM Boot Transition

When the ROM has completed its initial setup of the hardware and prepares the next boot stage, we encounter our first divergence in the ePMP setup, depending on whether our design has a single-stage or dual-stage ROM.
In a single-stage ROM, the ePMP is configured for the ROM to jump directly to the silicon creator firmware.
In a dual-stage ROM, the first-stage ROM configures ePMP for patching and execution of the second-stage ROM.

#### Single Stage ROM

- `MMWP=1`
- `MML=0`
- `RLB=1`

| Entry | Memory Block            | Address Mode | Access Modes | Locked? |
| ----- | ----------------------- | ------------ | ------------ | :-----: |
| 0     | ROM Text (lo)           | OFF\*        |              |         |
| 1     | ROM Text (hi)           | TOR          | ReadExecute  | X       |
| 2     | ROM                     | NAPOT        | ReadOnly     | X       |
| 3     | Si Creator FW Text (lo) | OFF\*        |              |         |
| 4     | Si Creator FW Text (hi) | TOR          | ReadExecute  | X       |
| 5     | Si Creator FW (Virtual) | NAPOT        | ReadOnly     | X       |
| 6     |                         | OFF          |              |         |
| 7     |                         | OFF          |              |         |
| 8     |                         | OFF          |              |         |
| 9     |                         | OFF          |              |         |
| 10    | MMIO (lo)               | OFF\*        |              |         |
| 11    | MMIO (hi)               | TOR          | ReadWrite    | X       |
| 12    |                         | OFF          |              |         |
| 13    | FLASH                   | NAPOT        | ReadOnly     | X       |
| 14    | Stack Guard             | NA4          | NoAccess     | X       |
| 15    | Main SRAM               | NAPOT        | ReadWrite    | X       |

#### Dual Stage ROM

- `MMWP=1`
- `MML=0`
- `RLB=1`

| Entry | Memory Block    | Address Mode | Access Modes | Locked? |
| ----- | --------------- | ------------ | ------------ | :-----: |
| 0     | ROM0 Text (lo)  | OFF\*        |              |         |
| 1     | ROM0 Text (hi)  | TOR          | ReadExecute  | X       |
| 2     | ROM0            | NAPOT        | ReadOnly     | X       |
| 3     | ROM1 Text (lo)  | OFF\*        |              |         |
| 4     | ROM1 Text (hi)  | TOR          | ReadExecute  | X       |
| 5     | ROM1            | NAPOT        | ReadOnly     | X       |
| 6     | ROM1 Patch (lo) | OFF\*        |              |         |
| 7     | ROM1 Patch (hi) | TOR          | ReadExecute  | X       |
| 8     |                 | OFF          |              |         |
| 9     |                 | OFF          |              |         |
| 10    | MMIO (lo)       | OFF\*        |              |         |
| 11    | MMIO (hi)       | TOR          | ReadWrite    | X       |
| 12    |                 | OFF          |              |         |
| 13    |                 | OFF          |              |         |
| 14    | Stack Guard     | NA4          | NoAccess     | X       |
| 15    | Main SRAM       | NAPOT        | ReadWrite    | X       |

### ROM1 Initialization (Dual-stage ROM only)

After the ROM0 jumps execution to the ROM1, the ROM1 enables access to the Mailbox RAM.
We also see the first instance of what we’ll call the *waterfall technique*, a pattern that will repeat in all later boot stages.
Slots 0-2, formerly occupied by the ROM0, are now used to store a duplicate of the regions for ROM1, copied from slots 3-5.
This will allow us to overwrite the original slots for the ROM1 the silicon creator firmware in the next stage.
This pattern always works regardless of how many boot stages exist before or after the current stage, allowing later stages like the silicon creator firmware to always perform the same slot transitions regardless of whether it was booted by a single-stage or dual-stage ROM.

- `MMWP=1`
- `MML=0`
- `RLB=1`

| Entry | Memory Block    | Address Mode | Access Modes | Locked? |
| ----- | --------------- | ------------ | ------------ | :-----: |
| 0     | ROM1 Text (lo)  | OFF\*        |              |         |
| 1     | ROM1 Text (hi)  | TOR          | ReadExecute  | X       |
| 2     | ROM1            | NAPOT        | ReadOnly     | X       |
| 3     | ROM1 Text (lo)  | OFF\*        |              |         |
| 4     | ROM1 Text (hi)  | TOR          | ReadExecute  | X       |
| 5     | ROM1            | NAPOT        | ReadOnly     | X       |
| 6     | ROM1 Patch (lo) | OFF\*        |              |         |
| 7     | ROM1 Patch (hi) | TOR          | ReadExecute  | X       |
| 8     |                 | OFF          |              |         |
| 9     |                 | OFF          |              |         |
| 10    | MMIO (lo)       | OFF\*        |              |         |
| 11    | MMIO (hi)       | TOR          | ReadWrite    | X       |
| 12    | Mailbox RAM     | NAPOT        | ReadWrite    | X       |
| 13    | FLASH           | NAPOT        | ReadOnly     | X       |
| 14    | Stack Guard     | NA4          | NoAccess     | X       |
| 15    | Main SRAM       | NAPOT        | ReadWrite    | X       |

### ROM1 Boot Transition (Dual-stage ROM only)

Here, we prepare to boot the silicon creator firmware, which we can load in slots 3-5, now that we copied the ROM1 regions to slots 0-2 in the previous step.

- `MMWP=1`
- `MML=0`
- `RLB=1`

| Entry | Memory Block            | Address Mode | Access Modes | Locked? |
| ----- | ----------------------- | ------------ | ------------ | :-----: |
| 0     | ROM1 Text (lo)          | OFF\*        |              |         |
| 1     | ROM1 Text (hi)          | TOR          | ReadExecute  | X       |
| 2     | ROM1                    | NAPOT        | ReadOnly     | X       |
| 3     | Si Creator FW Text (lo) | OFF\*        |              |         |
| 4     | Si Creator FW Text (hi) | TOR          | ReadExecute  | X       |
| 5     | Si Creator FW (Virtual) | NAPOT        | ReadOnly     | X       |
| 6     | ROM1 Patch (lo)         | OFF\*        |              |         |
| 7     | ROM1 Patch (hi)         | TOR          | ReadExecute  | X       |
| 8     |                         | OFF          |              |         |
| 9     |                         | OFF          |              |         |
| 10    | MMIO (lo)               | OFF\*        |              |         |
| 11    | MMIO (hi)               | TOR          | ReadWrite    | X       |
| 12    | Mailbox RAM             | NAPOT        | ReadWrite    | X       |
| 13    | FLASH                   | NAPOT        | ReadOnly     | X       |
| 14    | Stack Guard             | NA4          | NoAccess     | X       |
| 15    | Main SRAM               | NAPOT        | ReadWrite    | X       |

### Silicon Creator Firmware Initialization

After the ROM (or ROM1) jumps execution to the silicon creator firmware, we run another round of the waterfall technique.
We revoke access to the ROM (or ROM1) by overwriting slots 0-2 with a copy of the silicon creator firmware regions from slots 3-5.
The slots that contained the ROM1 patch are also cleared.

- `MMWP=1`
- `MML=0`
- `RLB=1`

| Entry | Memory Block            | Address Mode | Access Modes | Locked? |
| ----- | ----------------------- | ------------ | ------------ | :-----: |
| 0     | Si Creator FW Text (lo) | OFF\*        |              |         |
| 1     | Si Creator FW Text (hi) | TOR          | ReadExecute  | X       |
| 2     | Si Creator FW (Virtual) | NAPOT        | ReadOnly     | X       |
| 3     | Si Creator FW Text (lo) | OFF\*        |              |         |
| 4     | Si Creator FW Text (hi) | TOR          | ReadExecute  | X       |
| 5     | Si Creator FW (Virtual) | NAPOT        | ReadOnly     | X       |
| 6     |                         | OFF          |              |         |
| 7     |                         | OFF          |              |         |
| 8     |                         | OFF          |              |         |
| 9     |                         | OFF          |              |         |
| 10    | MMIO (lo)               | OFF\*        |              |         |
| 11    | MMIO (hi)               | TOR          | ReadWrite    | X       |
| 12    | Mailbox RAM             | NAPOT        | ReadWrite    | X       |
| 13    | FLASH                   | NAPOT        | ReadOnly     | X       |
| 14    | Stack Guard             | NA4          | NoAccess     | X       |
| 15    | Main SRAM               | NAPOT        | ReadWrite    | X       |

### Silicon Creator Firmware Boot Transition

When the Silicon Creator Firmware prepares to boot the Silicon Owner Firmware, it loads its memory regions in slots-3-5.

- `MMWP=1`
- `MML=0`
- `RLB=1`

| Entry | Memory Block            | Address Mode | Access Modes | Locked? |
| ----- | ----------------------- | ------------ | ------------ | :-----: |
| 0     | Si Creator FW Text (lo) | OFF\*        |              |         |
| 1     | Si Creator FW Text (hi) | TOR          | ReadExecute  | X       |
| 2     | Si Creator FW (Virtual) | NAPOT        | ReadOnly     | X       |
| 3     | Si Owner FW Text (lo)   | OFF\*        |              |         |
| 4     | Si Owner FW Text (hi)   | TOR          | ReadExecute  | X       |
| 5     | Si Owner FW (Virtual)   | NAPOT        | ReadOnly     | X       |
| 6     |                         | OFF          |              |         |
| 7     |                         | OFF          |              |         |
| 8     |                         | OFF          |              |         |
| 9     |                         | OFF          |              |         |
| 10    | MMIO (lo)               | OFF\*        |              |         |
| 11    | MMIO (hi)               | TOR          | ReadWrite    | X       |
| 12    | Mailbox RAM             | NAPOT        | ReadWrite    | X       |
| 13    | FLASH                   | NAPOT        | ReadOnly     | X       |
| 14    | Stack Guard             | NA4          | NoAccess     | X       |
| 15    | Main SRAM               | NAPOT        | ReadWrite    | X       |

Later boot stages (Silicon Owner, Platform Integrator, Platform Owner) repeat this two-step procedure (controlled by the functions `epmp_advance_boot_stage` and `epmp_prepare_boot_stage`, repsectively, in the code) to bootstrap the following stage.

### Suggested Layout for Kernel With Applications

In the final boot stage (the Platform Owner in this example, but could be an earlier stage if an integration chooses not to make use of all four logical boot stages), may desire to run an OS kernel with applications that utilize isolated ePMP regions.
Below is a suggested ePMP layout for such a use-case that is consistent with the above design.

Note that this example sets `MML=1`, which allows the kernel to prevent userland applications from arbitrarily upgrading their access permissions.
As detailed above, this changes the meaning of the Locked bit from *access controls affect M-Mode* to *accessible only in M-Mode if set, only in U/S-Mode if unset*.
Once `MML` is set, it is important not to clear `RLB`, as this would forfeit the kernel's ability to reconfigure ePMP slots until the next reset.

- `MMWP=1`
- `MML=1`
- `RLB=1`

| Entry | Memory Block                     | Address Mode | Access Modes | Locked? |
| ----- | -------------------------------- | ------------ | ------------ | :-----: |
| 0     | Plat Owner FW (Kernel) Text (lo) | OFF\*        |              |         |
| 1     | Plat Owner FW (Kernel) Text (hi) | TOR          | ReadExecute  | X       |
| 2     | Userland TOR region \#1 (lo)     | OFF\*        |              |         |
| 3     | Userland TOR region \#1 (hi)     | TOR          | ?            |         |
| 4     | Userland TOR region \#2 (lo)     | OFF\*        |              |         |
| 5     | Userland TOR region \#2 (hi)     | TOR          | ?            |         |
| 6     | Userland TOR region \#3 (lo)     | OFF\*        |              |         |
| 7     | Userland TOR region \#3 (hi)     | TOR          | ?            |         |
| 8     | Userland TOR region \#4 (lo)     | OFF\*        |              |         |
| 9     | Userland TOR region \#4 (hi)     | TOR          | ?            |         |
| 10    | MMIO (lo)                        | OFF\*        |              |         |
| 11    | MMIO (hi)                        | TOR          | ReadWrite    | X       |
| 12    | Mailbox RAM                      | NAPOT        | ReadWrite    | X       |
| 13    | Plat Owner FW (Kernel)           | NAPOT        | ReadOnly     | X       |
| 14    | Stack Guard                      | NA4          | NoAccess     | X       |
| 15    | Main SRAM                        | NAPOT        | ReadWrite    | X       |

Upon jumping to userland, the kernel can isolate the target application's memory by disabling the slots corresponding to the kernel and other applications.
The details of such a configuration are implementation-dependent.

## Testplan

On device tests require the DV address space be writable so that the test result can be reported.
To allow this, the test (running in place of the silicon creator firmware), can allocate an additional slot for this.

- `MMWP=1`
- `MML=0`
- `RLB=1`

| Entry | Memory Block            | Address Mode | Access Modes | Locked? |
| ----- | ----------------------- | ------------ | ------------ | :-----: |
| 0     | Si Creator FW Text (lo) | OFF\*        |              |         |
| 1     | Si Creator FW Text (hi) | TOR          | ReadExecute  | X       |
| 2     | Si Creator FW (Virtual) | NAPOT        | ReadOnly     | X       |
| 3     | Si Creator FW Text (lo) | OFF\*        |              |         |
| 4     | Si Creator FW Text (hi) | TOR          | ReadExecute  | X       |
| 5     | Si Creator FW (Virtual) | NAPOT        | ReadOnly     | X       |
| 6     | DV Testbench            | NA4          | ReadWrite    | X       |
| 7     |                         | OFF          |              |         |
| 8     |                         | OFF          |              |         |
| 9     |                         | OFF          |              |         |
| 10    | MMIO (lo)               | OFF\*        |              |         |
| 11    | MMIO (hi)               | TOR          | ReadWrite    | X       |
| 12    | Mailbox RAM             | NAPOT        | ReadWrite    | X       |
| 13    | FLASH                   | NAPOT        | ReadOnly     | X       |
| 14    | Stack Guard             | NA4          | NoAccess     | X       |
| 15    | Main SRAM               | NAPOT        | ReadWrite    | X       |

### Functional Test (simulation/FPGA)

The functional test will consists of the ROM (or ROM0/ROM1) images(s) and a placeholder binary running in place of the silicon creator firmware.
The functional test will verify that the state of the ePMP registers matches the configuration listed under [ROM Initial Setup](memory_protection.md#rom-initial-setup) when the ROM's C code is first reached, and the configuration listed under either [ROM Boot Transition](memory_protection.md#rom-boot-transition) or [ROM1 Boot Transition](memory_protection.md#rom1-boot-transition-dual-stage-rom-only), depending on the design, when the placeholder binary is reached.

### Unit tests

Unit tests can make use of the existing CSR unit test framework.
The focus of these tests will be on making sure that the verification functionality in the ROM validates the PMP configuration correctly.

### Error handling tests

The Memory Protection module is not responsible for testing the state of the ePMP CSRs when the boot sequence is aborted.
The Shutdown module tests must ensure that the ePMP CSRs are locked down correctly when an error occurs.

[^1]:  `OFF` slots marked with an asterisk (\*) are used as the lower-end of a TOR region, so the value of the corresponding `PMPADDR` register is still significant.

[^2]:  Slot 13 used to map to the Debug ROM for `rv_dm`. However, `rv_dm` was updated to ignore ePMP, so this was removed from the Dragonfly reference design in [6f8003d](https://github.com/pavona/pavona/commit/6f8003d3f749d4ce5008e37ad7f9268f2bd28225), and the Egret reference design in [pavona\#295](https://github.com/pavona/pavona/pull/295).
