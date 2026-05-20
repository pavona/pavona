# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# This enables downstream integrators to define external Egret OTP
# configurations to be used during provisioning for downstream SKUs. See the
# upstream Egret OTP configurations list defined in the `EGRET_OTP_CFGS`
# dict in `sw/device/silicon_creator/manuf/base/provisioning_inputs.bzl` for
# more details.
EXT_EGRET_OTP_CFGS = {
    # <OTP image name>: <//bazel/target/path:otp_image_consts>
}

# This enables downstream integrators to define external Egret SKU
# configurations to be used during provisioning. See the upstream Egret SKU
# configurations defined in the `EGRET_SKUS` dictionary in
# `sw/device/silicon_creator/manuf/base/provisioning_inputs.bzl` for more
# details.
EXT_EGRET_SKUS = {
    # <SKU name>: {
    #    "otp": <OTP image name above in EXT_EGRET_OTP_CFGS>,
    #    "dice_libs": [<which DICE certgen libs to use: X.509 or CWT>]
    #    "host_ext_libs": [<which host hooks extension libraries to use>]
    #    "device_ext_libs": [<which device hooks extension libraries to use>]
    # }
}

# This enables downstream integrators to define external Egret execution
# environments. See the upstream Silicon Owner execution environments defined
# in the `EGRET_SILICON_OWNER_ROM_EXT_ENVS` dictionary in
# `rules/pavona/defs.bzl` for more details.
EXT_EXEC_ENV_SILICON_ROM_EXT = {
    # "@provisioning_ex/bazel/target/exec_env:exec_env_name": None,
}
