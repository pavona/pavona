# Interface Signals

<!-- BEGIN CMDGEN util/regtool.py --interfaces ./hw/top_dragonfly/ip/ast/data/ast.hjson -->
Referring to the [Comportable guideline for peripheral device functionality](../../../../../doc/contributing/hw/comportability), the module **`ast`** has the following hardware interfaces defined
- Primary Clock: **`clk_ast_tlul_i`**
- Other Clocks: **`clk_ast_alert_i`**, **`clk_ast_rng_i`**
- Bus Device Interfaces (TL-UL): **`tl`**
- Bus Host Interfaces (TL-UL): *none*
- Peripheral Pins for Chip IO: *none*
- Interrupts: *none*
- Security Alerts: *none*
- Security Countermeasures: *none*

## [Inter-Module Signals](../../../../../doc/contributing/hw/comportability#inter-signal-handling)

| Port Name   | Package::Struct   | Type    | Act   |   Width | Description   |
|:------------|:------------------|:--------|:------|--------:|:--------------|
| tl          | tlul_pkg::tl      | req_rsp | rsp   |       1 |               |


<!-- END CMDGEN -->

The remainder of this document describes the AST-specific signals, including the
analog and power connections that are not visible to the comportable tooling.

## Table notes

### Signal naming conventions used in this document

Signal naming generally complies with the [Verilog style guide](../../../../../doc/contributing/style_guides/verilog_coding_style.md) names and suffixes with some augmentations:
- Clock signals start with clk_*

- Inputs and outputs are marked with *_i/o

- Analog signals are marked with *_a

- Non-core level signals are marked with *_h

- Dual and negative polarity signals are marked with *_p/n

### Clock domains column

- sys - system clock, mainly used for high performance and security
 modules. Up to 100MHz

- io - peripheral clock source, mainly used for peripherals and I/O
 related functionality. Up to 96MHz (divided by 4 by the clock
 manager)

- aon - Always-on domain clock. The only active clock while chip is in
 deep-sleep power state, 200KHz

- async - when listed as async, it means it does not matter what domain
 drives the signal

- Input clocks: Each functional interface has a dedicated clock named
 after the interface.

<table>
<colgroup>
<col style="width: 20%" />
<col style="width: 4%" />
<col style="width: 7%" />
<col style="width: 7%" />
<col style="width: 59%" />
</colgroup>
<thead>
<tr class="even">
<td><strong>Signal Name &amp; Affiliation</strong></td>
<td><strong>I/O</strong></td>
<td><p><strong>Width/</strong></p>
<p><strong>Type/</strong></p>
<p><strong>Struct</strong></p></td>
<td><strong>Clock Domain</strong></td>
<td><strong>Description</strong></td>
</tr>
<tr class="odd">
<td colspan="5"><strong>Power Supplies</strong></td>
</tr>
<tr class="even">
<td>VCC</td>
<td>I</td>
<td></td>
<td></td>
<td><p>VCC is the main power supply. It is driven from an external
source and is used to power the internal VCMAIN and VCAON power
domains.</p>
<p>VCC must always be present when the device is functioning; VCC is
also used to power a number of pads that must be always on when the
device is functioning.</p></td>
</tr>
<tr class="odd">
<td>AVCC</td>
<td>I</td>
<td></td>
<td></td>
<td>Analog blocks power supply. AVCC and AGND are analog supply and
ground signals for the AST analog functions. They mainly serve for ADC
and USB clock functionality. AVCC is expected to be driven by the same
voltage regulator and have similar power availability as VCC. AVCC and
AGND have dedicated package balls/pins. In the future, package pins
sharing with VCC and GND may be considered based on post-silicon test
results.</td>
</tr>
<tr class="even">
<td>VCMAIN</td>
<td>O</td>
<td></td>
<td></td>
<td>Main core power, driven by internal capless voltage regulator</td>
</tr>
<tr class="odd">
<td>VCAON</td>
<td>O</td>
<td></td>
<td></td>
<td>Core voltage power for always-on domain (same voltage range as
VCMAIN)</td>
</tr>
<tr class="even">
<td>VIOA</td>
<td>I</td>
<td></td>
<td></td>
<td>IO supply, powering a set of pads. Unlike VCC, the IO supplies can
be turned off by external components and the device will continue to
function, the unpowered pads however, become inoperable.</td>
</tr>
<tr class="odd">
<td>VIOB</td>
<td>I</td>
<td></td>
<td></td>
<td>Same as VIOA, but for a different set of pads.</td>
</tr>
<tr class="even">
<td>GND</td>
<td>I</td>
<td></td>
<td></td>
<td>Ground</td>
</tr>
<tr class="odd">
<td>AGND</td>
<td>I</td>
<td></td>
<td></td>
<td>Analog ground (see AVCC for further details)</td>
</tr>
<tr class="even">
<td colspan="5"><strong>Power Control and Reset</strong></td>
</tr>
<tr class="odd">
<td>otp_power_seq_i</td>
<td>I</td>
<td>2</td>
<td>async</td>
<td>Contains the power sequencing signals coming from the OTP
macro.</td>
</tr>
<tr class="even">
<td>otp_power_seq_h_o</td>
<td>O</td>
<td>2</td>
<td>async</td>
<td>Contains the power sequencing signals going to the OTP macro
(<strong>VCC domain</strong>).</td>
</tr>
<tr class="odd">
<td><p>vcmain_pok</p>
<p>(aka vcmain_pok_o)</p></td>
<td>O</td>
<td>ast_pwst</td>
<td>async</td>
<td>Main core power-exist indication. Used by the power
manager to determine the state of the main digital supply during power
up and power down sequencing.</td>
</tr>
<tr class="even">
<td><p>vcaon_pok</p>
<p>(aka vcaon_pok_o)</p></td>
<td>O</td>
<td>ast_pwst</td>
<td>async</td>
<td>Always-on power-exist indication. Used by the power
manager for power-on reset root.</td>
</tr>
<tr class="odd">
<td><p>vioa_pok</p>
<p>(aka vioa_pok_o)</p></td>
<td>O</td>
<td>ast_pwst</td>
<td>async</td>
<td>VIOA power-exist indications. Used as a power-OK status signal.</td>
</tr>
<tr class="even">
<td><p>viob_pok</p>
<p>(aka viob_pok_o)</p></td>
<td>O</td>
<td>ast_pwst</td>
<td>async</td>
<td>VIOB power-exist indication. Used as a power-OK status signal.</td>
</tr>
<tr class="odd">
<td>por_ni</td>
<td>I</td>
<td>1</td>
<td>async</td>
<td>Power on reset input signal to AST. See <a
href="#resets"><u>Resets</u></a> section for further details</td>
</tr>
<tr class="even">
<td>main_pd_ni</td>
<td>I</td>
<td>1</td>
<td>aon</td>
<td>Power down enable for main core power<br />
0: main core power is down (deep-sleep state)<br />
1: main core power is up<br />
It may take up to 200 uS from this signal transition to power switching
completion by AST (not including boot time and so). Note that flash must
be prepared for power down before this signal is asserted.</td>
</tr>
<tr class="odd">
<td>main_env_iso_en_i</td>
<td>I</td>
<td>1</td>
<td>aon</td>
<td><p>Preliminary indication of VCMAIN isolation signal (main_iso_en)
assertion. It is used by AST logic to latch interface signals which may
no longer be valid after main_iso_en is active. This signal must be set
at least 30ns before main_iso_en is active and must remain active at
least 30ns after main_iso_en is no longer active.</p>
<p>Note that main_iso_en itself asserts ahead of main_pd_ni. ie, the
pwrmgr will set this signal to '1' before requesting the power be turned
off. Similar, on power-on, the isolation is only released after power is
restored and all powered off modules have been reset.</p></td>
</tr>
<tr class="even">
<td>ast_init_done_o</td>
<td>O</td>
<td>mubi4</td>
<td>tlul</td>
<td>When set, it indicates that the AST initialization was performed.
Note that this signal may not be set while the chip is in TEST* or RMA
lifecycle states.</td>
</tr>
<tr class="odd">
<td colspan="5"><strong>Clock Outputs</strong></td>
</tr>
<tr class="even">
<td>clk_src_sys_o</td>
<td>O</td>
<td>1</td>
<td>sys</td>
<td>100 MHz clock with jitter (main clock domain). Used as the main
system clock.</td>
</tr>
<tr class="odd">
<td>clk_src_sys_val_o</td>
<td>O</td>
<td>1</td>
<td>async</td>
<td>System clock valid. Used as "ack" signals for the power
manager</td>
</tr>
<tr class="even">
<td>clk_src_sys_en_i</td>
<td>I</td>
<td>1</td>
<td>aon</td>
<td>System clock enable.</td>
</tr>
<tr class="odd">
<td>clk_src_sys_jen_i</td>
<td>I</td>
<td>mubi4</td>
<td>async</td>
<td>System clock jitter enable</td>
</tr>
<tr class="even">
<td>clk_src_aon_o</td>
<td>O</td>
<td>1</td>
<td>aon</td>
<td>200 KHz clock for always-on domain.</td>
</tr>
<tr class="odd">
<td>clk_src_aon_val_o</td>
<td>O</td>
<td>1</td>
<td>async</td>
<td>aon clock valid</td>
</tr>
<tr class="odd">
<td>clk_src_io_o</td>
<td>O</td>
<td>1</td>
<td>io</td>
<td>96 MHz clock with +/-3% frequency accuracy. Used for peripherals
that require a fixed frequency, for example SPI and UART</td>
</tr>
<tr class="even">
<td>clk_src_io_val_o</td>
<td>O</td>
<td>1</td>
<td>async</td>
<td>I/O and timer clock valid. Used as "ack" signals for the power
manager.</td>
</tr>
<tr class="odd">
<td>clk_src_io_en_i</td>
<td>I</td>
<td>1</td>
<td>aon</td>
<td>I/O and timer clock enable</td>
</tr>
<tr class="odd">
<td colspan="5"><strong>Clock &amp; Reset Inputs</strong></td>
</tr>
<tr class="odd">
<td>clk_ast_rng_i</td>
<td>I</td>
<td>1</td>
<td>rng</td>
<td>RNG interface clock input</td>
</tr>
<tr class="odd">
<td>clk_ast_es_i</td>
<td>I</td>
<td>1</td>
<td>es</td>
<td>Entropy source interface clock input</td>
</tr>
<tr class="even">
<td>clk_ast_alert_i</td>
<td>I</td>
<td>1</td>
<td>alert</td>
<td>Alert interface clock input</td>
</tr>
<tr class="odd">
<td>clk_ast_tlul_i</td>
<td>I</td>
<td>1</td>
<td>tlul</td>
<td>TLUL bus interface clock input</td>
</tr>
<tr class="odd">
<td>rst_ast_rng_ni</td>
<td>I</td>
<td>1</td>
<td>rng</td>
<td>RNG interface reset (active low)</td>
</tr>
<tr class="odd">
<td>rst_ast_es_ni</td>
<td>I</td>
<td>1</td>
<td>es</td>
<td>Entropy source interface reset (active low)</td>
</tr>
<tr class="even">
<td>rst_ast_alert_ni</td>
<td>I</td>
<td>1</td>
<td>alert</td>
<td>Alert interface interface reset (active low)</td>
</tr>
<tr class="odd">
<td>rst_ast_tlul_ni</td>
<td>I</td>
<td>1</td>
<td>tlul</td>
<td>TLUL bus reference interface reset (active low)</td>
</tr>
<tr class="even">
<td colspan="5"><strong>Register Access Interface</strong></td>
</tr>
<tr class="odd">
<td>tlul</td>
<td>I/O</td>
<td>tl_*</td>
<td>tlul</td>
<td>TLUL bus interface. Mainly used for configuration, calibration and
trimming. At boot time, data is copied from non-volatile storage into
AST registers by the SW boot entity. This interface has no further use
beyond this point. Runtime interaction with AST is performed by other
signals as described in this document.</td>
</tr>
<tr class="even">
<td colspan="5"><strong>Analog modules</strong></td>
</tr>
<tr class="odd">
<td>adc_a0_ai</td>
<td>I</td>
<td>awire</td>
<td>async</td>
<td>ADC analog input channels 0 to be measured.<br />
Signal type is awire (see ana_pkg.sv)</td>
</tr>
<tr class="even">
<td>adc_a1_ai</td>
<td>I</td>
<td>awire</td>
<td>async</td>
<td>ADC analog input channels 1 to be measured.<br />
Signal type is awire (see ana_pkg.sv)</td>
</tr>
<tr class="odd">
<td>adc_d_o</td>
<td>O</td>
<td>10</td>
<td>adc</td>
<td>ADC digital data</td>
</tr>
<tr class="even">
<td>adc_chnsel_i</td>
<td>I</td>
<td>2</td>
<td>adc</td>
<td>ADC input channel select (one hot). No more than one channel should
be selected at a time. Any change in 'adc_chnsel_i' value must go
through all '0'. Changing 'adc_chnsel_i' from '0' value to non-'0' value
starts an ADC conversion.</td>
</tr>
<tr class="odd">
<td>adc_d_val_o</td>
<td>O</td>
<td>1</td>
<td>adc</td>
<td>ADC digital data valid</td>
</tr>
<tr class="even">
<td>adc_pd_i</td>
<td>I</td>
<td>1</td>
<td>adc</td>
<td>ADC power down - for saving power during deep-sleep state between
measurements. When this signal is high, ADC module is in off state,
otherwise, it is in active state. For further description about adc_pd_i
usage, see ADC module description below.</td>
</tr>
<tr class="odd">
<td>entropy_req_o</td>
<td>O</td>
<td>edn_req</td>
<td>es</td>
<td>Request entropy from EDN</td>
</tr>
<tr class="even">
<td>entropy_rsp_i</td>
<td>I</td>
<td>edn_rsp</td>
<td>es</td>
<td>EDN entropy request acknowledgement and data.</td>
</tr>
<tr class="odd">
<td>rng_en_i</td>
<td>I</td>
<td>1</td>
<td>rng</td>
<td>Input from controller to enable RNG</td>
</tr>
<tr class="even">
<td>rng_fips_i</td>
<td>I</td>
<td>1</td>
<td>rng</td>
<td>Indicates that the AST RNG module is requested to output FIPS
SP-800-90B grade RNG bits. This may, but not necessarily affect
bit-rate. This bit is a placeholder. The use of this signal inside AST
is TBD.</td>
</tr>
<tr class="odd">
<td>rng_val_o</td>
<td>O</td>
<td>1</td>
<td>rng</td>
<td>RNG bit valid. This is a per-transaction valid. rng_b_o can be
sampled whenever this bit is high.</td>
</tr>
<tr class="even">
<td>rng_b_o</td>
<td>O</td>
<td>4</td>
<td>rng</td>
<td>RNG digital bit streams. The downstream controller of this signal
should sample the rng_b_o whenever rng_val_o is high.</td>
</tr>
<tr class="odd">
<td colspan="5"><strong>Countermeasures and Alerts</strong></td>
</tr>
<tr class="even">
<td>alert_req_o</td>
<td>O</td>
<td>ast_alert_req</td>
<td>alert</td>
<td>Alert events. There are 11 such events. The alerts are associated
with countermeasures like Active shield, clock glitch detector, voltage
glitch detector, temperature sensor, and others.</td>
</tr>
<tr class="odd">
<td>alert_rsp_i</td>
<td>I</td>
<td>ast_alert_rsp</td>
<td>alert</td>
<td>This structure contains acknowledge signals and force-trigger by
software signals for each alert event. The acknowledge signals are
assumed to be synchronous pulses.</td>
</tr>
<tr class="even">
<td colspan="4"><strong>Trimming Test and Debug</strong></td>
<td></td>
</tr>
<tr class="odd">
<td>dft_scan_md_o</td>
<td>O</td>
<td>mubi4</td>
<td></td>
<td>Scan mode indication signal. Controllable only when DFT features are
enabled (Test and RMA states). Otherwise, these signals are grounded to
0.</td>
</tr>
<tr class="even">
<td>scan_shift_en_o</td>
<td>O</td>
<td>1</td>
<td></td>
<td>Scan shift enable</td>
</tr>
<tr class="odd">
<td>scan_reset_no</td>
<td>O</td>
<td>1</td>
<td></td>
<td>Scan reset</td>
</tr>
<tr class="odd">
<td>dft_strap_test_i</td>
<td>I</td>
<td>dft_strap_test_req</td>
<td>async</td>
<td>Strap inputs for DFT selection</td>
</tr>
<tr class="odd">
<td>vcc_supp_i</td>
<td>I</td>
<td>1</td>
<td>async</td>
<td>VCC Supply Test. (supply indication for DV purposes). In FPGA
Verilog view, the respective POK signal follows this signal. In other
Verilog views this signal should be connected to constant '1' and will
be disconnected inside the AST.</td>
</tr>
<tr class="even">
<td>vcmain_supp_i</td>
<td>I</td>
<td>1</td>
<td>async</td>
<td>VCMAIN Supply Test. (supply indication for DV purposes). In FPGA
Verilog view, the respective POK signal follows this signal. In other
Verilog views this signal should be connected to constant '1' and will
be disconnected inside the AST.</td>
</tr>
<tr class="odd">
<td>vcaon_supp_i</td>
<td>I</td>
<td>1</td>
<td>async</td>
<td>VCAON Supply Test. (supply indication for DV purposes). In FPGA
Verilog view, the respective POK signal follows this signal. In other
Verilog views this signal should be connected to constant '1' and will
be disconnected inside the AST.</td>
</tr>
<tr class="even">
<td>vioa_supp_i</td>
<td>I</td>
<td>1</td>
<td>async</td>
<td>VIOA Supply Test. (supply indication for DV purposes). In FPGA
Verilog view, the respective POK signal follows this signal. In other
Verilog views this signal should be connected to constant '1' and will
be disconnected inside the AST.</td>
</tr>
<tr class="odd">
<td>viob_supp_i</td>
<td>I</td>
<td>1</td>
<td>async</td>
<td>VIOB Supply Test. (supply indication for DV purposes). In FPGA
Verilog view, the respective POK signal follows this signal. In other
Verilog views this signal should be connected to constant '1' and will
be disconnected inside the AST.</td>
</tr>
<tr class="even">
<td>ast2pad_t0_ao, ast2pad_t1_ao</td>
<td>I/O</td>
<td></td>
<td>async</td>
<td>Analog debug signals. These signals should be connected directly to
chip PADs. They can share PADs with functional signals but when they are
used for their analog debug function, the functional I/O must be in
tri-state.</td>
</tr>
<tr class="odd">
<td><p>dpram_rmf_o,</p>
<p>dpram_rml_o,</p>
<p>spram_rm_o,</p>
<p>sprgf_rm_o,</p>
<p>sprom_rm_o</p></td>
<td>O</td>
<td>dpm_rm</td>
<td>async</td>
<td>RAM/ROM Read-write Margin Trimming</td>
</tr>
<tr class="even">
<td>padmux2ast_i</td>
<td>I</td>
<td>6</td>
<td>async</td>
<td>Digital debug input signals (routed to pin mux). These signals are
controllable only when DFT features are enabled (Test and RMA states).
Otherwise, these signals are grounded to 0.</td>
</tr>
<tr class="odd">
<td>ast2padmux_o</td>
<td>O</td>
<td>9</td>
<td>async</td>
<td>Digital debug output signals (routed to pin mux). These signals are
only outputted when DFT features are enabled (Test and RMA states).
Otherwise, these signals are grounded to 0.</td>
</tr>
<tr class="even">
<td>lc_dft_en_i</td>
<td>I</td>
<td>lc_tx</td>
<td>async</td>
<td><p>DFT enable</p></td>
</tr>
<tr class="even">
<td>otp_obs_i</td>
<td>I</td>
<td>8</td>
<td>async</td>
<td>OTP observe bus for debug</td>
</tr>
<tr class="even">
<td>otm_obs_i</td>
<td>I</td>
<td>8</td>
<td>async</td>
<td>Modules observe bus for debug (optional)</td>
</tr>
<tr class="odd">
<td>obs_ctrl_o</td>
<td>O</td>
<td>ast_obs_ctrl</td>
<td>async</td>
<td>Observability control structure. It contains observability module
selection, signal group selection and enable logic. Open source modules
may choose to use this infrastructure for selecting and gating
observability signals to be driven into otm_obs_i bus. Whether to
actually use this interface or not for open source modules observability
is a project decision.</td>
</tr>
<tr class="even">
<td>sns_clks_i</td>
<td>I</td>
<td>clkmgr_out</td>
<td>async</td>
<td>Clocks observability</td>
</tr>
<tr class="odd">
<td>sns_rst_i</td>
<td>I</td>
<td>rstmgr_out_t</td>
<td>async</td>
<td>Resets observability</td>
</tr>
<tr class="even">
<td>sns_spi_ext_clk_i</td>
<td>I</td>
<td>1</td>
<td>async</td>
<td>SPI external clock observability</td>
</tr>
</thead>
<tbody>
</tbody>
</table>
