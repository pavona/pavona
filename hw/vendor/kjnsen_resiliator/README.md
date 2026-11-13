# Resiliator

Resiliator is an RTL-based simulation framework, which uses Verilator to exhaustively evaluate the resilience of given hardware-software combinations against single bit-flip fault injection (FI) attacks.

**Input:** Resiliator needs an RTL design of a CPU, firmware to run on that CPU, and a security property (e.g., a certain authentication check should not be bypassed).

**Output:** Resiliator gives you a list of (cycle, flip-flop) pairs that successfully bypass the security property when flipped.

It allows you to customize the set of flip-flops (FFs) that are targeted, as well as the window of cycles during which the FIs are tested ("injection window"). Each FI attack is evaluated using your own security property and the (intermediate) results can be viewed during and after the FI campaign. You can also run a single simulation and analyse how the fault propagates through the design.

Resiliator was developed by Konrad Jansen, with/under the supervision of Vincent Ulitzsch and Niclas Kühnapfel (from TU Berlin). Please open an issue or contact Konrad Jansen <resiliator@qwui.net> if you have any questions.

## Installation

Clone this repository:

```
git clone git@github.com:kjnsen/resiliator.git
```

Additionally, you need to grab and build a custom fork of Verilator, specially modified for Resiliator, from [https://github.com/kjnsen/verilator](https://github.com/kjnsen/verilator):

```
git clone git@github.com:kjnsen/verilator.git
cd verilator
git checkout resiliator
autoconf
./configure
make -j `nproc`
```

## How to use this framework 

### Setup

- **Connecting:** Instantiate your complete design in `rtl/sim_top.v` using the provided inputs clk and rst.

*Note: If you are testing a RISC-V core, you may have a look at all files with the suffix `_rv`. They contain a simple memory with wishbone interface to RISC-V cores, which may be helpful to some people, but you do not have to use them.*
- **Fail signal:** You may connect the output signal `fail` to some internal condition, which indicates that the core noticed and thwarted the attack. When `fail` is raised, the simulation immediately assumes that the attack has failed. If your core has alert outputs that indicate security issues, these might be good candidates to be connected to the `fail` signal. 
- **Gpio signal:** Make sure that the testbench can communicate with your design. This must be done through the output signal `gpio`. You have two options:
    - Either: Make sure that writing to memory address `GPIO_ADDRESS` (see `hw_config.cfg`) writes to output `gpio` instead. Then include the appropriate macros from `firmware/injection.h` into your firmware.
    - Or: Directly control the output signal `gpio` from within the (System-)Verilog code and assign the appropriate values (see `rtl/injection.vh`) in the correct cycles.
- **Macros:** Either way, the macros (not exact names) have the following meaning:
    - `start_injecting`: Sets the beginning of the injection window to the current cycle
    - `end_injecting`: Sets the end of the injection window to the current cycle
    - `success`: Reports for a single simulation that the attack was successful
    - `failure`: Reports for a single simulation that the attack was unsuccessful (Should be encountered in the golden (FI-free) simulation)
    - `success_if(condition)`: Hardened if-statement, which reports a successful attack if the condition is met
    - `checkpoint`: Can be used in combination with `cp_success`
    - `cp_success`: Reports a successful attack if `checkpoint` has been encountered, else failure is reported

*Note: If `end_injecting` is not used, `failure` will set the end of the injection window to the current cycle. The injection window can also be controlled using command-line arguments, thus `start_injecting` and `end_injecting` are not strictly necessary.*
- **Firmware loading:** Enable loading the firmware into memory using the command `$value$plusargs("firmware=%s", <reg for firmware filename>)` in your design. You can look at an example of how to do it in `rtl/sim_rv.v`.

*Note: This setup assumes there is only one memory that needs to have data loaded from a file. If that is not the case, use multiple such commands and adjust `Makefile` (look for uses of "BINARY") and `run_sim.sh`.*
- **Compilation:** Compile your firmware under test for your core (potentially having included the macros).
- **Configuration:** Fill in `hw_config.cfg` and `tb_config.cfg`.
- Execute the Makefile.

### Execution

Run `./run_sim.sh`. The following arguments may be used:

- **Single simulation**:
    - `-c <cycle> -f <index of FF>`: Only do one simulation with a bitflip at the specified cycle and FF index (see `obj_dir/resiliator_flops.cpp` for the array of FFs with commented indices).
    - `-d`: Log the difference between the golden and the faulty simulation (requires `-c` and `-f`). The result can be viewed using `view_diff.py` (see Evaluation).
- **Tracing (`.vcd` outputs):**
    - `-v`: Trace the full simulation.
    - `-v <c1>-<c2>`: Trace from cycle `c1` to `c2`. 
    - `-v <c1>-`: Trace from cycle `c1` until the end.
    - `-v -<c2>`: Trace until cycle `c2`, starting at the cycle specified by `-c` or the beginning of the injection window (if `-c` was not used).
- **Injection window:**
    - `-w <c1>-<c2>`: Sets the injection window to the given cycles. If `c1` or `c2` is omitted (`-w <c1>-`/`-w -<c2>`), the corresponding side of the injection window is determined normally, i.e. by the encountered values at the `gpio` signal.
- **Golden simulation management:**
    - `-s`: Save the findings of the golden simulation to a file.
    - `-l`: Load and use the findings of a golden simulation from a file instead of running it.

### Evaluation

- All files produced by Resiliator will be written into the directory identified by `OUT_DIR` (see `tb_config.cfg`).
- During the exhaustive FI campaign, sending `s\n` to stdin (press 's' and Enter) makes it print current statistics about the ongoing campaign.
- When the exhaustive FI campaign is done, the same statistics (also on a per-FF basis) as well as details on the successful FI attacks will be present in `OUT_DIR/sim_results`.
- When using the option `-d`, the propagation of the fault can be inspected using `view_diff.py`. It uses the framework `streamlit`, see [https://docs.streamlit.io/](https://docs.streamlit.io/).
