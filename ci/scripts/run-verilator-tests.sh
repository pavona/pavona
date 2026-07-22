#!/bin/bash
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set -e

suffix="sim_verilator"
defines=()
slow=false

for arg in "$@"; do
    case "${arg}" in
        --pqc)
            suffix="sim_verilator_pqc"
            defines=(--define=acc_has_pqc=true)
            ;;
        --slow)
            slow=true
            ;;
        *)
            echo "Unknown argument: ${arg}" >&2
            exit 1
            ;;
    esac
done

if [[ "${slow}" == "true" ]]; then
    targets=(
        "//sw/device/tests/crypto:mlkem_functest_${suffix}"
        "//sw/device/tests/crypto:mldsa_functest_${suffix}"
    )
else
    targets=(
        "//sw/device/tests:aes_smoketest_${suffix}"
        "//sw/device/tests:uart_smoketest_${suffix}"
        "//sw/device/tests:crt_test_${suffix}"
        "//sw/device/tests:acc_randomness_test_${suffix}"
        "//sw/device/tests:acc_irq_test_${suffix}"
        "//sw/device/tests:kmac_mode_cshake_test_${suffix}"
        "//sw/device/tests:kmac_mode_kmac_test_${suffix}"
        "//sw/device/tests:flash_ctrl_test_${suffix}"
        "//sw/device/tests:usbdev_test_${suffix}"
        "//sw/device/silicon_creator/lib/drivers:hmac_functest_${suffix}"
        "//sw/device/silicon_creator/lib/drivers:uart_functest_${suffix}"
        "//sw/device/silicon_creator/lib/drivers:retention_sram_functest_${suffix}"
        "//sw/device/silicon_creator/lib/drivers:alert_functest_${suffix}"
        "//sw/device/silicon_creator/lib/drivers:watchdog_functest_${suffix}"
        "//sw/device/silicon_creator/lib:irq_asm_functest_${suffix}"
        "//sw/device/silicon_creator/rom:rom_epmp_test_${suffix}"
    )
fi

./bazelisk.sh test \
    --build_tests_only=true \
    --test_timeout=2400,2400,4000,-1 \
    --local_test_jobs=8 \
    --local_resources=cpu=8 \
    --test_tag_filters=verilator,-broken \
    --test_output=errors \
    --//hw:make_options=-j,8 \
    "${defines[@]}" \
    "${targets[@]}"
