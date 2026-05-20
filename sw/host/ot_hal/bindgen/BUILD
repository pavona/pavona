# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@rules_rust//rust:defs.bzl", "rust_library_group")
load("@rules_rust_bindgen//:defs.bzl", "rust_bindgen", "rust_bindgen_library")

package(default_visibility = ["//visibility:public"])

# NOTE: This variable is modified during scafi_deprecated SW build from prepare_sw.py.
_TOPLEVEL = "egret"

_SCAFI_DEPRECATED_DEPS = [
    "//sw/device/lib/dif:aon_timer",
    "//sw/device/lib/dif:clkmgr",
    "//sw/device/lib/dif:lc_ctrl",
    "//sw/device/lib/dif:otp_ctrl",
    "//sw/device/lib/dif:rstmgr",
    "//sw/device/lib/dif:sram_ctrl",
    "//sw/device/lib/dif:uart",
]

_EGRET_DEPS = [
    "//sw/device/lib/dif:adc_ctrl",
    "//sw/device/lib/dif:aes",
    "//sw/device/lib/dif:alert_handler",
    "//sw/device/lib/dif:aon_timer",
    "//sw/device/lib/dif:clkmgr",
    "//sw/device/lib/dif:csrng",
    "//sw/device/lib/dif:edn",
    "//sw/device/lib/dif:entropy_src",
    "//sw/device/lib/dif:flash_ctrl",
    "//sw/device/lib/dif:gpio",
    "//sw/device/lib/dif:hmac",
    "//sw/device/lib/dif:i2c",
    "//sw/device/lib/dif:keymgr",
    "//sw/device/lib/dif:kmac",
    "//sw/device/lib/dif:lc_ctrl",
    "//sw/device/lib/dif:acc",
    "//sw/device/lib/dif:otp_ctrl",
    "//sw/device/lib/dif:pattgen",
    "//sw/device/lib/dif:pinmux",
    "//sw/device/lib/dif:pwm",
    "//sw/device/lib/dif:pwrmgr",
    "//sw/device/lib/dif:rstmgr",
    "//sw/device/lib/dif:rv_timer",
    "//sw/device/lib/dif:sensor_ctrl",
    "//sw/device/lib/dif:spi_device",
    "//sw/device/lib/dif:spi_host",
    "//sw/device/lib/dif:sram_ctrl",
    "//sw/device/lib/dif:sysrst_ctrl",
    "//sw/device/lib/dif:uart",
    "//sw/device/lib/dif:usbdev",
]

_DRAGONFLY_DEPS = [
    "//sw/device/lib/dif:acc",
    "//sw/device/lib/dif:aes",
    "//sw/device/lib/dif:alert_handler",
    "//sw/device/lib/dif:aon_timer",
    "//sw/device/lib/dif:clkmgr",
    "//sw/device/lib/dif:csrng",
    "//sw/device/lib/dif:edn",
    "//sw/device/lib/dif:entropy_src",
    "//sw/device/lib/dif:gpio",
    "//sw/device/lib/dif:hmac",
    "//sw/device/lib/dif:i2c",
    "//sw/device/lib/dif:keymgr_dpe",
    "//sw/device/lib/dif:kmac",
    "//sw/device/lib/dif:lc_ctrl",
    "//sw/device/lib/dif:otp_ctrl",
    "//sw/device/lib/dif:pinmux",
    "//sw/device/lib/dif:pwrmgr",
    "//sw/device/lib/dif:rstmgr",
    "//sw/device/lib/dif:rv_timer",
    "//sw/device/lib/dif:spi_device",
    "//sw/device/lib/dif:spi_host",
    "//sw/device/lib/dif:sram_ctrl",
    "//sw/device/lib/dif:uart",
]

_DEPS = _SCAFI_DEPRECATED_DEPS if _TOPLEVEL == "scafi_deprecated" else select({
    "//hw/top:egret": _EGRET_DEPS,
    "//hw/top:dragonfly": _DRAGONFLY_DEPS,
})

cc_library(
    name = "difs",
    hdrs = ["difs.h"],
    deps = _DEPS,
)

rust_bindgen_library(
    name = "alert",
    bindgen_flags = [
        "--allowlist-type=AlertClass",
        "--allowlist-type=AlertEnable",
        "--allowlist-type=AlertEscalate",
    ],
    cc_lib = "//sw/device/silicon_creator/lib/drivers:alert",
    crate_name = "ot_bindgen_alert",
    header = "//sw/device/silicon_creator/lib/drivers:alert.h",
    rustc_flags = [
        "--allow=non_snake_case",
        "--allow=non_upper_case_globals",
    ],
)

rust_bindgen_library(
    name = "dif",
    bindgen_flags = [
        "--allowlist-var=ADC_CTRL_.*_REG_OFFSET",
        "--allowlist-var=AES_.*_REG_OFFSET",
        "--allowlist-var=ALERT_HANDLER_.*_REG_OFFSET",
        "--allowlist-var=AON_TIMER_.*_OFFSET",
        "--allowlist-var=CLKMGR_.*_BIT",
        "--allowlist-var=CLKMGR_.*_REG_OFFSET",
        "--allowlist-var=CLKMGR_.*_MASK",
        "--allowlist-var=CLKMGR_.*_OFFSET",
        "--allowlist-var=CSRNG_.*_REG_OFFSET",
        "--allowlist-type=dif_lc_ctrl_state",
        "--allowlist-type=dif_lc_ctrl_token",
        "--allowlist-var=EDN_.*_REG_OFFSET",
        "--allowlist-var=ENTROPY_SRC_.*_REG_OFFSET",
        "--allowlist-var=FLASH_CTRL_.*_REG_OFFSET",
        "--allowlist-var=GPIO_.*_REG_OFFSET",
        "--allowlist-var=HMAC_.*_REG_OFFSET",
        "--allowlist-var=I2C_.*_REG_OFFSET",
        "--allowlist-var=KEYMGR_.*_REG_OFFSET",
        "--allowlist-var=KMAC_.*_REG_OFFSET",
        "--allowlist-var=LC_CTRL_.*_BIT",
        "--allowlist-var=LC_CTRL_.*_REG_OFFSET",
        "--allowlist-var=ACC_.*_REG_OFFSET",
        "--allowlist-var=ACC_.*_SIZE_BYTES",
        "--allowlist-var=OTP_CTRL_.*_BIT",
        "--allowlist-var=OTP_CTRL_.*_OFFSET",
        "--allowlist-var=OTP_CTRL_.*_SIZE",
        "--allowlist-var=PATTGEN_.*_REG_OFFSET",
        "--allowlist-var=PINMUX_.*_REG_OFFSET",
        "--allowlist-var=PINMUX_.*_BIT",
        "--allowlist-var=PWM_.*_REG_OFFSET",
        "--allowlist-var=PWRMGR_.*_REG_OFFSET",
        "--allowlist-type=dif_rstmgr_reset_info",
        "--allowlist-var=RSTMGR_.*_OFFSET",
        "--allowlist-var=RSTMGR_.*_BIT",
        "--allowlist-var=RSTMGR_.*_MASK",
        "--allowlist-var=RV_TIMER_.*_REG_OFFSET",
        "--allowlist-var=SENSOR_CTRL_.*_REG_OFFSET",
        "--allowlist-var=SPI_DEVICE_.*_REG_OFFSET",
        "--allowlist-var=SPI_HOST_.*_REG_OFFSET",
        "--allowlist-var=SRAM_CTRL_.*_REG_OFFSET",
        "--allowlist-var=SYSRST_CTRL_.*_REG_OFFSET",
        "--allowlist-var=UART_.*_OFFSET",
        "--allowlist-var=USBDEV_.*_REG_OFFSET",
    ],
    cc_lib = ":difs",
    clang_flags = [
        "-DOT_IS_SCAFI_DEPRECATED_REDUCED_SUPPORT_FOR_INTERNAL_USE_ONLY_",
    ] if _TOPLEVEL == "scafi_deprecated" else [
    ],
    crate_name = "ot_bindgen_dif",
    header = "difs.h",
    rustc_flags = [
        "--allow=non_snake_case",
        "--allow=non_upper_case_globals",
        "--allow=non_camel_case_types",
    ],
)

rust_bindgen_library(
    name = "egret",
    bindgen_flags = [
        "--allowlist-type=top_egret_alert_peripheral",
        "--allowlist-type=top_egret_alert_id",
        "--allowlist-type=top_egret_pinmux_peripheral_in",
        "--allowlist-type=top_egret_pinmux_insel",
        "--allowlist-type=top_egret_pinmux_mio_out",
        "--allowlist-type=top_egret_pinmux_outsel",
        "--allowlist-type=top_egret_direct_pads",
        "--allowlist-type=top_egret_muxed_pads",
        "--allowlist-type=top_egret_power_manager_wake_ups",
        "--allowlist-type=top_egret_reset_manager_sw_resets",
        "--allowlist-type=top_egret_power_manager_reset_requests",
        "--allowlist-type=top_egret_gateable_clocks",
        "--allowlist-type=top_egret_hintable_clocks",
    ],
    cc_lib = "//hw/top_egret/sw/autogen:top_egret",
    crate_name = "ot_bindgen_egret",
    header = "//hw/top_egret/sw/autogen:top_egret.h",
    rustc_flags = [
        "--allow=non_snake_case",
        "--allow=non_upper_case_globals",
        "--allow=non_camel_case_types",
    ],
)

rust_bindgen_library(
    name = "dragonfly",
    bindgen_flags = [
        "--allowlist-type=top_dragonfly_alert_peripheral",
        "--allowlist-type=top_dragonfly_alert_id",
        "--allowlist-type=top_dragonfly_pinmux_peripheral_in",
        "--allowlist-type=top_dragonfly_pinmux_insel",
        "--allowlist-type=top_dragonfly_pinmux_mio_out",
        "--allowlist-type=top_dragonfly_pinmux_outsel",
        "--allowlist-type=top_dragonfly_direct_pads",
        "--allowlist-type=top_dragonfly_muxed_pads",
        "--allowlist-type=top_dragonfly_power_manager_wake_ups",
        "--allowlist-type=top_dragonfly_reset_manager_sw_resets",
        "--allowlist-type=top_dragonfly_power_manager_reset_requests",
        "--allowlist-type=top_dragonfly_gateable_clocks",
        "--allowlist-type=top_dragonfly_hintable_clocks",
    ],
    cc_lib = "//hw/top_dragonfly/sw/autogen:top_dragonfly",
    crate_name = "ot_bindgen_dragonfly",
    header = "//hw/top_dragonfly/sw/autogen:top_dragonfly.h",
    rustc_flags = [
        "--allow=non_snake_case",
        "--allow=non_upper_case_globals",
        "--allow=non_camel_case_types",
    ],
)

rust_bindgen_library(
    name = "multibits",
    bindgen_flags = [
        "--allowlist-type=multi_bit_bool",
    ],
    cc_lib = "//sw/device/lib/base:multibits",
    crate_name = "ot_bindgen_multibits",
    header = "//sw/device/lib/base:multibits.h",
    rustc_flags = [
        "--allow=non_snake_case",
        "--allow=non_upper_case_globals",
        "--allow=non_camel_case_types",
    ],
)

rust_library_group(
    name = "bindgen",
    deps = [
        ":alert",
        ":dif",
        ":multibits",
    ] + select({
        "//hw/top:egret": [":egret"],
        "//hw/top:dragonfly": [":dragonfly"],
    }),
)
