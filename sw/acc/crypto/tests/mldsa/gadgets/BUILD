# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@ot_python_deps//:requirements.bzl", "requirement")
load("@rules_python//python:defs.bzl", "py_binary")
load("//rules:acc.bzl", "acc_autogen_sim_test", "acc_library")

package(default_visibility = ["//visibility:public"])

# Provides gamma2_vec_const for gadget tests linking gadgets.o (secdecompose
# references it). A dep, not a src, so it is not concatenated into a test.
acc_library(
    name = "gadget_test_consts",
    srcs = ["gadget_test_consts.s"],
)

py_binary(
    name = "secunmask_modq_testgen",
    srcs = ["secunmask_modq_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secunmask_modq_test{}".format(
            str(i),
        ),
        srcs = ["secunmask_modq_test.s"],
        pqc = True,
        seed = i,
        testgen = ":secunmask_modq_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(3)
]

py_binary(
    name = "secleq_testgen",
    srcs = ["secleq_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secleq_test{}".format(
            str(i),
        ),
        srcs = ["secleq_test.s"],
        pqc = True,
        seed = i,
        testgen = ":secleq_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(3)
]

py_binary(
    name = "secboundcheck_testgen",
    srcs = ["secboundcheck_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secboundcheck_test{}".format(i),
        srcs = ["secboundcheck_test.s"],
        pqc = True,
        seed = i,
        testgen = ":secboundcheck_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(3)
]

py_binary(
    name = "secand_testgen",
    srcs = ["secand_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secand_test{}".format(
            str(i),
        ),
        srcs = ["secand_test.s"],
        pqc = True,
        seed = i,
        testgen = ":secand_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(10)
]

py_binary(
    name = "secfulladder_testgen",
    srcs = ["secfulladder_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secfulladder_test{}".format(
            str(i),
        ),
        srcs = ["secfulladder_test.s"],
        pqc = True,
        seed = i,
        testgen = ":secfulladder_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(10)
]

py_binary(
    name = "secadd_immd_d1_testgen",
    srcs = ["secadd_immd_d1_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secadd_immd_d1_test{}".format(
            str(i),
        ),
        srcs = ["secadd_immd_d1_test.s"],
        pqc = True,
        seed = i,
        testgen = ":secadd_immd_d1_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(10)
]

py_binary(
    name = "secadd_immd_d2_testgen",
    srcs = ["secadd_immd_d2_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secadd_immd_d2_test{}".format(
            str(i),
        ),
        srcs = ["secadd_immd_d2_test.s"],
        pqc = True,
        seed = i,
        testgen = ":secadd_immd_d2_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(10)
]

py_binary(
    name = "secadd_constant_bmsk_testgen",
    srcs = ["secadd_constant_bmsk_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secadd_constant_bmsk_test{}".format(
            str(i),
        ),
        srcs = ["secadd_constant_bmsk_test.s"],
        pqc = True,
        seed = i,
        testgen = ":secadd_constant_bmsk_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(10)
]

py_binary(
    name = "secadd_testgen",
    srcs = ["secadd_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secadd_test{}".format(
            str(i),
        ),
        srcs = ["secadd_test.s"],
        pqc = True,
        seed = i,
        testgen = ":secadd_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(10)
]

py_binary(
    name = "secaddmodq_testgen",
    srcs = ["secaddmodq_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secaddmodq_test{}".format(
            str(i),
        ),
        srcs = ["secaddmodq_test.s"],
        pqc = True,
        seed = i,
        testgen = ":secaddmodq_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(5)
]

py_binary(
    name = "seca2bmodq_testgen",
    srcs = ["seca2bmodq_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "seca2bmodq_test{}".format(
            str(i),
        ),
        srcs = ["seca2bmodq_test.s"],
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":seca2bmodq_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(5)
]

py_binary(
    name = "seccompress_testgen",
    srcs = ["seccompress_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("dilithium-py"),
    ],
)

[
    acc_autogen_sim_test(
        name = "seccompress_test{}".format(
            str(i),
        ),
        srcs = ["seccompress_test.s"],
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":seccompress_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(5)
]

py_binary(
    name = "bitslice_testgen",
    srcs = ["bitslice_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "bitslice_mldsa_test" + str(i),
        srcs = ["bitslice_test.s"],
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":bitslice_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(3)
]

py_binary(
    name = "unbitslice_testgen",
    srcs = ["unbitslice_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "unbitslice_mldsa_test" + str(i),
        srcs = ["unbitslice_test.s"],
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":unbitslice_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(3)
]

py_binary(
    name = "masked_poly_uniform_gamma1_testgen",
    srcs = ["masked_poly_uniform_gamma1_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "masked_poly_uniform_gamma1_test" + str(i),
        srcs = ["masked_poly_uniform_gamma1_test.s"],
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":masked_poly_uniform_gamma1_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:kmac_send_msg",
            "//sw/acc/crypto/mldsa:poly",
            "//sw/acc/crypto/mldsa:rounding",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(3)
]

py_binary(
    name = "masked_poly_uniform_eta_testgen",
    srcs = ["masked_poly_uniform_eta_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "masked_poly_uniform_eta_test{}".format(i),
        srcs = ["masked_poly_uniform_eta_test.s"],
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":masked_poly_uniform_eta_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(3)
]

py_binary(
    name = "secdecompose_testgen",
    srcs = ["secdecompose_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("dilithium-py"),
    ],
)

[
    acc_autogen_sim_test(
        name = "secdecompose_test{}".format(i),
        srcs = ["secdecompose_test.s"],
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":secdecompose_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:kmac_send_msg",
            "//sw/acc/crypto/mldsa:poly",
            "//sw/acc/crypto/mldsa:rounding",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(20)
]

py_binary(
    name = "poly_rej_samp_bitsliced_testgen",
    srcs = ["poly_rej_samp_bitsliced_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "poly_rej_samp_bitsliced_mldsa_test" + str(i),
        srcs = ["poly_rej_samp_bitsliced_test.s"],
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":poly_rej_samp_bitsliced_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets_test",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(5)
]

py_binary(
    name = "secb2amodq_testgen",
    srcs = ["secb2amodq_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secb2amodq_test{}".format(
            str(i),
        ),
        srcs = ["secb2amodq_test.s"],
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":secb2amodq_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(5)
]

py_binary(
    name = "secb2amodq_eta_testgen",
    srcs = ["secb2amodq_eta_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secb2amodq_eta_test{}".format(i),
        srcs = ["secb2amodq_eta_test.s"],
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":secb2amodq_eta_testgen",
        deps = [
            ":gadget_test_consts",
            "//sw/acc/crypto/mldsa:consts",
            "//sw/acc/crypto/mldsa:gadgets",
            "//sw/acc/crypto/mldsa:scratch",
        ],
    )
    for i in range(3)
]
