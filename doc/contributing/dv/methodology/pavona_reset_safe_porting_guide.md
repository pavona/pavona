# Pavona DV — Reset-Safe Testbench Porting Guide
Author(s): [Yogish Sekhar](mailto:ycsekhar@zerorisc.com)
Reviewers: [Quan Nguyen](mailto:qmn@zerorisc.com), [Guillermo Maturana](mailto:matute@zerorisc.com)
Last Updated: March 27, 2026

**TL;DR:**
For engineers porting existing block-level testbenches to the Pavona reset-safe infrastructure
Based on RFC-2025-01 and cip_lib / dv_lib patterns

---

## 1. Introduction & Purpose

This guide walks a new Pavona contributor through every concrete step required to make an existing SV-UVM block-level testbench fully reset-safe under the Pavona methodology. It is written for engineers who are comfortable with UVM basics but are unfamiliar with Pavona specific reset management framework.

By the end of this guide you will understand:

- Why Pavona is migrating to use a structured, framework-level approach to resets instead of ad-hoc `initial` blocks.
- How the Stop-Clean-Restart pattern should map onto every testbench layer (driver, monitor, agent, sequence, scoreboard).
- What files to touch and what changes to make for each layer.
- How to validate that your port is correct.

> **NOTE:** All code snippets and class names refer to the Pavona repository. Canonical base classes live under `hw/dv/sv/dv_lib/` and `hw/dv/sv/cip_lib/`. The `ac_range_check` IP is used as a worked example throughout.

---

## 2. Background: Why Reset Safety Matters

### 2.1 The fundamental UVM-reset mismatch

UVM is designed around **continuous forward progress** — once a sequence starts a transaction it expects `item_done()` to arrive. A hardware reset violates that contract: the driver halts mid-transaction, `item_done()` never arrives, and the sequencer deadlocks or drives stale data.

Standard UVM sub-phases (`reset_phase`, `configure_phase`, ...) are rarely sufficient because they require deep UVM internals knowledge and do not scale to asynchronous reset events. The Pavona approach instead bakes reset awareness directly into every component without phase-jumping.

### 2.2 The Stop-Clean-Restart pattern

Every testbench layer obeys the same three-step protocol whenever a reset is detected:

| Step | What happens |
|------|-------------|
| **Stop** | Kill the active thread (`get_and_drive` / `collect_trans` / `main_thread`). Call `item_done()` if a transaction was in-flight to unblock the sequencer. |
| **Clean** | Drive the interface back to its idle/default state. Clear FIFO state, scoreboard prediction queues, error flags, and per-address state machines. |
| **Restart** | Wait for reset deassertion and the DUT to be stable, then re-launch the thread from its entry point. |

The master virtual sequence is the sole exception: it is **never** killed by the virtual sequencer. Instead it monitors reset itself (via `monitor_reset()`) and is responsible for killing appropriate child sequences and for restarting them after deassertion.

---

## 3. Prerequisites & Codebase Orientation

### 3.1 Repository layout

Understand the folder structure before touching any file:

```
hw/dv/sv/dv_lib/
  dv_rst_safe_base_driver.sv     // Reset-safe driver base
  dv_rst_safe_base_agent.sv      // Reset-safe agent base
  dv_rand_rst_safe_base_vseq.sv  // Reset-safe virtual-sequence base
  dv_test_seq_parameters.sv      // TEST_PARAMS_T contract

hw/dv/sv/cip_lib/seq_lib/
  cip_rand_rst_safe_base_vseq.sv // CIP layer above dv_lib

// Auto-generated IPs:
hw/<top>/ip_templates/<ip>/dv/env/seq_lib/
  <ip>_rand_rst_safe_base_vseq.sv // IP-specific layer (your target)

// Hand-written IPs:
hw/ip/<ip>/dv/env/seq_lib/
  <ip>_rand_rst_safe_base_vseq.sv // IP-specific layer (your target)
```

### 3.2 Class hierarchy

The inheritance chain for a typical CIP IP is:

```
dv_rand_rst_safe_base_vseq
  └── cip_rand_rst_safe_base_vseq
        └── <ip>_rand_rst_safe_base_vseq - you implement reset_trigger_thread() & main_thread()
```

The `body()` task — which orchestrates reset loops, process threading, and the Stop-Clean-Restart cycle — is fully implemented in `dv_rand_rst_safe_base_vseq`. **You never override it.**

### 3.3 Key classes to read before starting

- `dv_rst_safe_base_driver.sv` — understand `run_phase()` process threading model.
- `dv_rand_rst_safe_base_vseq.sv` — read `body()` top to bottom; understand `test_params` and `config_params` factories.
- `cip_rand_rst_safe_base_vseq.sv` — understand what CIP pre-populates (e.g. RAL model access, TL-UL checks).
- `ac_range_check_rand_rst_safe_base_vseq.sv` — the complete reference implementation you are modelling.

---

## 4. Step-by-Step Porting Procedure

> **Follow these steps in order.** Each step includes a "What to change" description and a "How to verify" subsection. Never skip verification — reset bugs are subtle.

---

### Step 1 — Audit the Existing Testbench

Before writing any code, document the current state of your IP's testbench. Answer every question in the checklist below.

| Component / Area | Questions to answer |
|-----------------|---------------------|
| **Drivers** | List every driver class. Does it extend `uvm_driver` or a cip/dv base? Does its `run_phase()` have any reset detection? Does it call `seq_item_port.get_next_item()` directly without a wrapper? |
| **Monitors** | List every monitor class. Does its `run_phase()` handle reset (kill `collect_trans` on reset assertion)? |
| **Agents** | Does any agent extend `dv_rst_safe_base_agent`? Is there a reset thread in the agent's `run_phase`? |
| **Sequencers** | Are any sequencers flagged `do_not_reset`? This flag is required for the `clk_rst_agent` sequencer. |
| **Scoreboard** | Does it clear expected/actual data on reset? Does it subscribe to the reset monitor's analysis port? |
| **Virtual Seqs** | Is there a base virtual sequence? Does it call `monitor_reset()`? Does it have a separate `reset_trigger_thread()` and `main_thread()`? |
| **Reset Agent** | Is there a dedicated `clk_rst_agent`? Does the env configure `reset_domain` on each agent's `cfg`? |
| **Config** | Does the env `cfg` have a `reset_domain` handle? Is it set before `build_phase` completes? |

---

### Step 2 — Port the Driver(s)

#### 2a. Change base class

Every driver that sends transactions to a hardware interface must derive from `dv_rst_safe_base_driver` (or a class that already does so in the hierarchy).

```systemverilog
// BEFORE
class my_driver extends uvm_driver #(my_seq_item);

// AFTER
class my_driver extends dv_rst_safe_base_driver #(my_seq_item);
```

#### 2b. Implement the two mandatory virtual methods

The base class `run_phase()` calls two pure-virtual tasks that you must implement:

```systemverilog
// 1. Drive the interface back to its idle / default state
function void reset_interface_and_driver();
  vif.req   <= '0;
  vif.valid <= '0;
  // ... clear every signal that the driver can assert to its reset value
endfunction

// 2. Normal transaction loop (no reset logic needed here)
task get_and_drive();
  forever begin
    get_next_item(req);      // use the WRAPPED call, not seq_item_port directly
    drive_transaction(req);  // your existing drive logic
    // item_done() is called inside drive_transaction() when the item is processed
  end
endtask
```

> **CRITICAL:** Always use the `get_next_item()` wrapper provided by the base class, **not** `seq_item_port.get_next_item()` directly. The wrapper is reset-aware and will block until the driver is allowed to fetch transactions.

#### 2c. Remove any reset logic from `get_and_drive()`

The base class `run_phase()` handles all reset detection, thread killing, and restart. Your `get_and_drive()` should contain only the normal stimulus-driving loop — no reset checks, no `forever-fork-disable` patterns, and no `@(negedge rst_n)` sensitivity.

#### 2d. Verify the driver

- Run a simple sanity test. Manually force a reset mid-test using the reset sequence.
- Confirm the driver does not deadlock (simulation does not hang after reset deassertion).
- Confirm `vif` signals return to idle values during reset assertion.
- Confirm `get_and_drive()` restarts and drives new transactions after reset deassertion.

---

### Step 3 — Port the Monitor(s)

#### 3a. Change base class

Extend `dv_rst_safe_base_monitor` (or the CIP equivalent) rather than `uvm_monitor`.

#### 3b. Implement `reset_monitor()` and `collect_trans()`

Similar to the driver, the base monitor's `run_phase()` spawns two threads: one that watches reset and one that collects transactions. You must supply:

```systemverilog
// Put all transaction observation logic here
task collect_trans();
  forever begin
    // sample interface signals, build transactions, write to analysis port
  end
endtask

// Drive the monitor back to clean state on reset assertion
function void reset_monitor();
  // clear any in-progress transaction buffer
  partial_txn = null;
endfunction
```

#### 3c. Verify the monitor

- Confirm the monitor does not emit spurious transactions during reset (no analysis port writes between reset assertion and deassertion).
- Confirm it resumes correct sampling after reset deassertion.

---

### Step 4 — Port the Agent(s)

#### 4a. Change base class

```systemverilog
// BEFORE
class my_agent extends uvm_agent;

// AFTER
class my_agent extends dv_rst_safe_base_agent #(my_cfg);
```

#### 4b. Set `reset_domain` in the env/test

Each agent's `cfg` must have its `reset_domain` handle set to the correct `reset_domain` object before the `run_phase` begins. This is typically done in the env's `connect_phase` or the test's `build_phase`:

```systemverilog
// In env.sv connect_phase
m_my_agent.cfg.reset_domain = cfg.reset_domain;
```

#### 4c. Mark the `clk_rst_agent` sequencer as `do_not_reset`

The sequencer on the `clk_rst_agent` drives reset itself and must never be stopped when reset is asserted. Set:

```systemverilog
m_clk_rst_agent.sequencer.do_not_reset = 1'b1;
```

> **IMPORTANT:** If you forget `do_not_reset` on the `clk_rst_agent` sequencer, the agent's `run_phase` will call `stop_sequences()` on the very sequencer that is driving reset, creating a deadlock.

#### 4d. Verify the agent

- Confirm the agent's `run_phase` log shows `"POR Deasserted"` exactly once at startup.
- Confirm `"Reset Asserted"` and `"Reset Deasserted"` messages appear for each reset event.
- Confirm `"Sequences Stopped"` appears after `"Reset Asserted"` for all agents except `clk_rst`.

---

### Step 5 — Port the Scoreboard

#### 5a. Subscribe to the reset monitor analysis port

The preferred mechanism is an analysis port connection from the reset monitor to the scoreboard. In the env's `connect_phase`:

```systemverilog
// env.sv connect_phase
m_clk_rst_agent.monitor.reset_ap.connect(m_scoreboard.reset_export);
```

#### 5b. Implement the reset handler

In the scoreboard, implement `write_reset()` (the analysis port sink) that clears all state when called:

```systemverilog
function void write_reset(reset_txn_t txn);
  if (txn.is_assert) begin
    exp_queue.delete();
    act_queue.delete();
    pending_checks.delete();
    error_pending.clear();   // clear mem_bkdr_event_t state if applicable
  end
endfunction
```

#### 5c. Handle the `error_pending` state machine

If your scoreboard models backdoor memory access events (e.g. for `mem_bkdr_util`), the `ap_bkdr_write` analysis port and the `error_pending` per-address flag must also be cleared on reset. Case A (clean backdoor write) and Case B (error-injection write) diverge here: only Case B sets `error_pending`, and that flag must survive until the DUT processes the error — but not across a reset boundary.

#### 5d. Verify the scoreboard

- Run a test that performs a reset mid-way through a sequence of register writes.
- Confirm no spurious mismatches are reported immediately after deassertion.
- Confirm the scoreboard correctly tracks post-reset register default values.

---

### Step 6 — Create the IP Reset-Safe Base Virtual Sequence

This is the primary user-visible step. The Pavona requires an IP-specific class that extends `cip_rand_rst_safe_base_vseq` and implements `reset_trigger_thread()` and `main_thread()`.

#### 6a. Create the file

The file lives under one of two paths depending on whether the IP is auto-generated or hand-written:

```
// Auto-generated IP src or tpl:
hw/<top>/ip_templates/<ip>/dv/env/seq_lib/<ip>_rand_rst_safe_base_vseq.sv(.tpl)

// Auto-generated IP (processed .tpl files):
hw/<top>/ip_autogen/<ip>/dv/env/seq_lib/<ip>_rand_rst_safe_base_vseq.sv

// Hand-written IP:
hw/ip/<ip>/dv/env/seq_lib/<ip>_rand_rst_safe_base_vseq.sv
```

```systemverilog
class <ip>_rand_rst_safe_base_vseq
    extends cip_rand_rst_safe_base_vseq #(
    .CFG_T               (<ip>_env_cfg),
    .COV_T               (<ip>_env_cov),
    .VIRTUAL_SEQUENCER_T (<ip>_virtual_sequencer),
    .TEST_PARAMS_T       (dv_test_seq_parameters),
    .CONFIG_PARAMS_T     (<ip>_config_params)
  );
```

#### 6b. Register with the factory

```systemverilog
  `uvm_object_utils(<ip>_rand_rst_safe_base_vseq)
```

#### 6c. Implement `reset_trigger_thread()` and `main_thread()`

`reset_trigger_thread()` is the counterpart to `main_thread()`. It runs as an **independent, concurrent thread** alongside `main_thread()` inside each reset loop iteration. Its sole job is to assert reset at a random point while the DUT is operational and then signal back to `body()` that reset has been seen.
Never put reset-triggering logic inside `main_thread()`.

`main_thread()` is the test stimulus. It must be **reset-free** — no reset detection, no `@(negedge rst_n)`, no `disable fork`. The framework guarantees it is only called when the DUT is out of reset and stable.

```systemverilog
task reset_trigger_thread();
  delay_seq  del_seq;
  reset_seq  rst_seq;

  // A random delay execution just to ensure main_thread() is in functional state before reset is
  // triggered. 'rand_reset_delay' is a control knob declared in parent
  // cip_rand_rst_safe_base_vseg.
  del_seq = delay_seq::type_id::create("del_seq:reset_trigger");
  del_seq.delay_time_steps = rand_reset_delay;
  del_seq.start(p_sequencer.delay_sequencer_h);

  // Execute the reset sequence on the clk reset sequencer
  rst_seq = reset_seq::type_id::create("rst_seq");
  rst_seq.start(p_sequencer.clk_rst_sequencer_h);
endtask
```

```systemverilog
task main_thread();
  // Example: write a random set of CSRs, read them back
  ral_seq_t ral_seq;
  ral_seq = ral_seq_t::type_id::create("ral_seq");
  ral_seq.start(p_sequencer.ral_sequencer);
endtask
```

**Critical timing constraint:** `reset_trigger_thread()` **must always complete before `main_thread()`**. If `main_thread()` finishes first, `body()` logs a warning and the reset loop was wasted. Tune `reset_assertion_delay` to be shorter than the expected `main_thread()` runtime.

**What you must NOT do inside `reset_trigger_thread()`:**

- Do not call `wait_reset_deassert()` — `body()` waits for deassertion and restarts the loop.
- Do not kill `main_thread()` — `body()` does that after `reset_trigger_thread()` returns.
- Do not run any functional stimulus — this thread only drives the reset mechanism.
- Do not access the DUT's data path interfaces — only the `clk_rst_sequencer` is in scope here.

**Disabling random reset for specific tests:**

When a test needs a deterministic reset at a precise point (e.g. proving Flash non-volatility, OTP zeroization), set `reset_testing = DISABLE` in `test_params` to suppress `reset_trigger_thread()` entirely, then drive reset manually from `main_thread()` at the exact required moment using the reset sequence directly.

```systemverilog
// In a directed test that needs reset at a specific point:
vseq.test_params.reset_testing.rand_mode(0);
vseq.test_params.reset_testing = dv_test_seq_parameters::DISABLE;
```

#### 6d. Optionally override `dut_init()`

`dut_init()` is called once after each reset deassertion, before `main_thread()` begins. Use it to program mandatory DUT registers and wait for the DUT to reach an operational state.

```systemverilog
task dut_init(string reset_kind = "HARD");
  super.dut_init(reset_kind);
  // Configure mandatory IP settings after every reset
  csr_wr(.ptr(ral.<enable_reg>), .value(1));
endtask
```

#### 6e. Verify the virtual sequence

- Run with `reset_testing = ENABLE`, `num_reset_loops = 3`.
- Confirm `body()` log shows `"Reset Loop: Starting Forks"` and `"killing main_thread()"` for each loop.
- Confirm simulation completes without deadlock and without fatal errors.

---

### Step 7 — Configure Test Parameters & Config Parameters

#### 7a. Test Parameters (`dv_test_seq_parameters` or a derived class)

Test parameters are randomized **exactly once** at test start and survive across resets. They control the high-level shape of the test.

| Field | Purpose |
|-------|---------|
| `reset_testing` | `ENABLE` or `DISABLE`. When `DISABLE`, only one reset loop runs (POR only). |
| `num_reset_loops` | Number of POR + mid-test reset cycles. Randomized at test start, decremented each loop. |
| `do_dut_init` | Whether `dut_init()` is called after each reset. Set to 0 for tests that need a raw post-POR state. |
| `reset_assertion_delay` | Random delay from start of `main_thread()` until reset is triggered. Must be long enough for at least one meaningful transaction. |
| `length_reset_assertion` | How long reset is held asserted (in clock cycles). Must meet DUT minimum reset pulse width. |

#### 7b. Config Parameters (IP-specific)

Config parameters are re-randomized every time `main_thread()` is entered. They define the DUT configuration for one reset-to-reset interval.

```systemverilog
class <ip>_config_params extends uvm_object;
  rand int unsigned num_transactions;
  rand my_mode_e    mode;

  constraint c_num_txn { num_transactions inside {[1:50]}; }

  function new(string name = "<ip>_config_params");
    super.new(name);
  endfunction

endclass
```

Create and randomize a local instance inside `main_thread()` at the start of each invocation — it will be automatically destroyed on the next reset because its scope ends.

> **Design rule:** If a parameter needs to be read after a reset (e.g. "how many loops remain"), it must live in `TEST_PARAMS_T`. If it only describes the current operational window, it belongs in `CONFIG_PARAMS_T`.

---

### Step 8 — Wire Everything into the Env and Test

#### 8a. Env `build_phase`

- Instantiate all agents using `` `uvm_component_utils `` and the factory.
- Create the `reset_domain` object and assign it to every agent cfg: `m_<agent>.cfg.reset_domain = cfg.reset_domain;`
- Set `m_clk_rst_agent.sequencer.do_not_reset = 1` after building the agent.

#### 8b. Env `connect_phase`

- Connect monitor analysis ports to scoreboards.
- Connect reset monitor analysis port to scoreboard reset sink.

#### 8c. Test `run_phase`

All tests must use the reset-safe sequence as their base. A typical test only overrides specific constraints:

```systemverilog
class my_specific_test extends <ip>_base_test;
  task run_phase(uvm_phase phase);
    <ip>_rand_rst_safe_base_vseq vseq;
    phase.raise_objection(this);
    vseq = <ip>_rand_rst_safe_base_vseq::type_id::create("vseq");
    vseq.set_sequencer(p_sequencer);
    vseq.test_params.reset_testing.rand_mode(0);
    vseq.test_params.reset_testing = dv_test_seq_parameters::ENABLE;
    vseq.start(p_sequencer);
    phase.drop_objection(this);
  endtask
endclass
```

---

## 5. Validation Checklist

Run through every row before declaring the port complete:

| Check | Pass criterion |
|-------|---------------|
| Sim starts without fatal | No `` `uvm_fatal `` in build/connect/run_phase before POR. |
| POR completes correctly | Log shows `"POR Released"` in driver and `"POR Deasserted"` in agent. DUT register defaults pass. |
| Mid-test reset (1 loop) | Set `num_reset_loops = 2`, `reset_testing = ENABLE`. Confirm `"killing main_thread()"` and restart without deadlock. |
| Multi-loop reset | Set `num_reset_loops = 5`. Confirm all loops complete, no mismatches. |
| Driver idle on reset | Waveform check: all driver output signals return to 0/idle during reset assertion window. |
| Monitor quiet on reset | No analysis port writes from monitor between reset assertion and deassertion. |
| Scoreboard clean on reset | No mismatches attributed to stale pre-reset transactions. |
| No deadlock on timeout | Run with `UVM_TIMEOUT = 5ms`. Simulation terminates normally. |
| `do_not_reset` on `clk_rst` | `grep do_not_reset` in env. Confirm it is set to 1 for the `clk_rst_agent` sequencer. |
| `reset_domain` set for all | Confirm `cfg.reset_domain` is non-null in every agent's `run_phase`. |
| Config params re-randomize | Add `$display` in `<ip>_config_params::post_randomize()`. Confirm it fires once per `main_thread` entry. |
| Test params stable | Add `$display` in `test_params` post-randomize. Confirm it fires exactly once across all loops. |
| Coverage collected | Reset assertion and deassertion events are covered in the functional coverage plan. |

---

## 6. Common Pitfalls & How to Avoid Them

| Pitfall | Root cause & fix |
|---------|-----------------|
| Calling `seq_item_port.get_next_item()` directly | Always use the base class wrapper `get_next_item()`. The raw call bypasses reset-awareness and will deadlock when reset arrives mid-arbitration. |
| Forgetting `item_done()` before kill | If the driver is killed while `processing_item` is set, the base class automatically calls `item_done()`. However, if you override `run_phase` without calling `super`, you must call `item_done()` manually. |
| Reset logic inside `main_thread()` | `main_thread()` must be reset-free. Do not add `@(posedge cfg.clk_rst_vif.rst_n)` or `disable fork` inside it. The framework already handles this outside. |
| Forgetting `do_not_reset` on `clk_rst` sequencer | Leads to deadlock: the agent kills the sequencer that is in the middle of driving the reset signal, so reset never deasserts. |
| Config params created at test start | Config params must be created inside `main_thread()` so they go out of scope at the start of each new reset loop. If created once at test start they carry stale values across resets. |
| Direct reset polarity assumption | Always use `cfg.reset_domain.wait_reset_assert()` and `wait_reset_deassert()` rather than `@(negedge rst_n)`. This abstracts polarity and ensures synchronization to the clock edge. |
| Scoreboard not cleared on reset | Connect the reset monitor analysis port to the scoreboard and implement `write_reset()`. Without this, pre-reset predictions will cause false failures on post-reset reads. |
| Assuming DUT is clean after reset without checking | Run a post-reset register readback after every reset deassertion. For Flash/OTP/ReRAM blocks, explicitly verify non-volatile state. |
| Using `#delay` instead of clock-aligned deassertion | Never use `#10ns` for reset timing. Always use the reset sequence's built-in clock-edge-aligned deassertion mechanism. |
| Omitting stabilization cycles after deassertion | The reset sequence provides a randomized post-deassertion wait. Do not start `main_thread()` transactions until `dut_init()` has completed. This is handled automatically by the base `body()` task. |

---

## 7. Reference: Key Base Class API

Methods marked **IMPLEMENT** must be provided by your derived class. Methods marked **DO NOT OVERRIDE** must not be changed.

| Method | Class | Directive | Notes |
|--------|-------|-----------|-------|
| `reset_interface_and_driver()` | `dv_rst_safe_base_driver` | **IMPLEMENT** | Drive all interface outputs to idle. |
| `get_and_drive()` | `dv_rst_safe_base_driver` | **IMPLEMENT** | Transaction loop with no reset logic. |
| `get_next_item(req)` | `dv_rst_safe_base_driver` | **DO NOT OVERRIDE** | Use in `get_and_drive()` instead of `seq_item_port.get_next_item()`. |
| `run_phase()` | `dv_rst_safe_base_driver` | **DO NOT OVERRIDE** | Contains the POR wait, fork/process model. |
| `collect_trans()` | `dv_rst_safe_base_monitor` | **IMPLEMENT** | Transaction observation loop. |
| `reset_monitor()` | `dv_rst_safe_base_monitor` | **IMPLEMENT** | Clear in-progress transaction state. |
| `run_phase()` | `dv_rst_safe_base_agent` | **DO NOT OVERRIDE** | Contains `agent_reset_thread`. |
| `body()` | `dv_rand_rst_safe_base_vseq` | **DO NOT OVERRIDE** | Orchestrates reset loops, forks. |
| `main_thread()` | `dv_rand_rst_safe_base_vseq` | **IMPLEMENT** | Reset-free stimulus generation. |
| `dut_init()` | `cip_rand_rst_safe_base_vseq` | *Optionally override* | Post-reset DUT setup. |
| `monitor_reset()` | `dv_rand_rst_safe_base_vseq` | **DO NOT OVERRIDE** | Syncs `in_reset` flag. |
| `reset_trigger_thread()` | `dv_rand_rst_safe_base_vseq` | **IMPLEMENT** | Drives reset at a random point during `main_thread()`. Do not kill `main_thread()` or wait for deassertion inside it. |

---

## 8. Worked Example: ac_range_check

The `ac_range_check` IP is the canonical reference for this porting pattern inside Pavona.

### 8.1 File created

`ac_range_check` is an auto-generated IP, so the file lives under `ip_autogen/`:

```
hw/top_dragonfly/ip_autogen/ac_range_check/dv/env/seq_lib/
  ac_range_check_rand_rst_safe_base_vseq.sv
```

### 8.2 Class declaration

The class extends `cip_rand_rst_safe_base_vseq`, parameterized with IP-specific `CFG_T`, `COV_T`, `VIRTUAL_SEQUENCER_T`, `TEST_PARAMS_T`, and `CONFIG_PARAMS_T`. It registers itself with the factory using `` `uvm_object_utils ``.

### 8.3 `main_thread()` implementation

The implementation limits itself entirely to:

- Randomizing the number of address-range entries to program.
- Writing the `ALERT_EN`, `RANGE_BASE`, `RANGE_LIMIT`, `RANGE_PERM` registers via the RAL model.
- Issuing a set of read-back checks against expected values.

No reset polling, no `@negedge rst_n`, no `disable fork` — all of that is handled by the base class `body()`.

### 8.4 Config parameters

An `ac_range_check_config_params` class holds `num_ranges` (how many ranges to configure per test window) and a `range_cfg` array. These are randomized fresh at the start of each `main_thread()` invocation so each reset-to-reset window exercises a different configuration point.

### 8.5 `dut_init()` override

After each reset, the override writes the `ALERT_EN` register with its power-on default and waits for the alert handshake to settle before returning control to `body()`, which then calls `main_thread()`.

---

## 9. Do's and Don'ts Quick Reference

### Do's ✅

- Use `cfg.reset_domain.wait_reset_assert()` and `wait_reset_deassert()` everywhere. These are clock-edge-aligned and polarity-abstract.
- Keep `main_thread()` completely reset-free. All reset management lives in the base class.
- Set `do_not_reset = 1` on the `clk_rst_agent` sequencer.
- Clear **all** scoreboard queues in `write_reset()`. Missing even one will cause false failures.
- Create `CONFIG_PARAMS_T` inside `main_thread()` (not in `body` or test). This ensures clean re-randomization per reset window.
- Parameterize reset timing (pulse width, delay) so different tests can override via constraints.
- Include post-reset functional checks in scoreboards — use CSR readback sequences.
- Collect reset assertion/deassertion events in the functional coverage plan.

### Don'ts ❌

- **Never** override `body()` in any derived virtual sequence.
- **Never** call `seq_item_port.get_next_item()` directly in any driver.
- **Never** add reset detection (`@posedge`/`@negedge` reset) inside `get_and_drive()` or `collect_trans()`.
- **Never** use `#<time>` delays for reset timing. Use the reset sequence control knobs.
- **Never** forget to subscribe the scoreboard to the reset monitor analysis port.
- **Never** drive reset from multiple sources — centralize all reset control in the `clk_rst_agent`.
- **Never** start transactions immediately after `dut_init()` without allowing the stabilization period.
- **Never** leave reset polarity ambiguous — always use `reset_n` (active-low) consistently.

---

## 10. Further Reading

- RFC-2025-01: [Reset Management in DV Testbenches](../../../../rfc/rfc-2026-01-DV-Reset-Management/rfc_2026_01_dv_reset_management.md)
- [Building Scalable System Verilog UVM Infrastructure for Open Silicon IPs](./building_scalable_system_verilog_uvm_infrastructure_for_open_silicon_ips.md)
- `dv_rand_rst_safe_base_vseq.sv` — `hw/dv/sv/dv_lib/`
- `cip_rand_rst_safe_base_vseq.sv` — `hw/dv/sv/cip_lib/seq_lib/`
- `ac_range_check_rand_rst_safe_base_vseq.sv` — canonical reference implementation

---

*End of Porting Guide*
