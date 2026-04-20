# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@ot_python_deps//:requirements.bzl", "requirement")
load("@rules_python//python:defs.bzl", "py_binary")
load("//rules:acc.bzl", "acc_autogen_sim_test")

package(default_visibility = ["//visibility:public"])

NSHARES = [
    2,
    3,
    4,
]

SCHEME = {
    0: "mlkem",
    1: "mldsa",
}

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
        name = "secunmask_modq_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["secunmask_modq_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        testgen = ":secunmask_modq_testgen",
        deps = [
            "//sw/acc/crypto/mldsa:mldsa65_consts",
            "//sw/acc/crypto/mldsa/gadgets:secunmask_modq",
        ],
    )
    for i in range(3)
    for nshares in [2]
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

SECLEQ_CASES = [
    (23, 1048182),
    (23, 523382),
]

[
    acc_autogen_sim_test(
        name = "secleq_test{}_{}shares_k{}_p{}".format(
            str(i),
            str(nshares),
            str(kbits),
            str(psi),
        ),
        srcs = ["secleq_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DKBITS=" + str(kbits),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        testgen = ":secleq_testgen",
        testgen_args = [
            "-k",
            str(kbits),
            "-p",
            str(psi),
        ],
        deps = [
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d2",
            "//sw/acc/crypto/mldsa/gadgets:secleq",
        ],
    )
    for i in range(3)
    for nshares in [2]
    for (kbits, psi) in SECLEQ_CASES
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

SECBOUNDCHECK_CASES = [
    (524091, 524091),
    (261691, 261691),
]

[
    acc_autogen_sim_test(
        name = "secboundcheck_test{}_{}shares_l0_{}_l1_{}".format(
            str(i),
            str(nshares),
            str(l0),
            str(l1),
        ),
        srcs = ["secboundcheck_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        testgen = ":secboundcheck_testgen",
        testgen_args = [
            "--lambda0",
            str(l0),
            "--lambda1",
            str(l1),
        ],
        deps = [
            "//sw/acc/crypto/mldsa:mldsa65_consts",
            "//sw/acc/crypto/mldsa/gadgets:bitslice_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:scratch",
            "//sw/acc/crypto/mldsa/gadgets:seca2bmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d1",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d2",
            "//sw/acc/crypto/mldsa/gadgets:secadd_constant_bmsk_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secaddmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20_d2",
            "//sw/acc/crypto/mldsa/gadgets:secboundcheck_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22",
            "//sw/acc/crypto/mldsa/gadgets:secleq",
        ],
    )
    for i in range(3)
    for nshares in [2]
    for (l0, l1) in SECBOUNDCHECK_CASES
]

py_binary(
    name = "secand_cs20_testgen",
    srcs = ["secand_cs20_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secand_cs20_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["secand_cs20_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        testgen = ":secand_cs20_testgen",
        deps = [
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22",
        ],
    )
    for i in range(10)
    for nshares in NSHARES
]

py_binary(
    name = "secfulladder_bc22_testgen",
    srcs = ["secfulladder_bc22_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secfulladder_bc22_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["secfulladder_bc22_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        testgen = ":secfulladder_bc22_testgen",
        deps = [
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22",
        ],
    )
    for i in range(10)
    for nshares in NSHARES
]

[
    acc_autogen_sim_test(
        name = "secfulladder_bc22_d2_test{}".format(str(i)),
        srcs = ["secfulladder_bc22_test.s"],
        copts = [
            "-DNSHARES=2",
        ],
        nshares = 2,
        pqc = True,
        seed = i,
        testgen = ":secfulladder_bc22_testgen",
        deps = [
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20_d2",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22_d2",
        ],
    )
    for i in range(5)
]

py_binary(
    name = "secadd_bc22_testgen",
    srcs = ["secadd_bc22_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secadd_bc22_test{}_{}shares_{}".format(
            str(i),
            str(nshares),
            name,
        ),
        srcs = ["secadd_bc22_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DSCHEME=" + str(scheme),
        ],
        nshares = nshares,
        pqc = True,
        scheme = scheme,
        seed = i,
        testgen = ":secadd_bc22_testgen",
        deps = [
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22",
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22",
        ],
    )
    for i in range(10)
    for scheme, name in SCHEME.items()
    for nshares in NSHARES
]

[
    acc_autogen_sim_test(
        name = "secadd_bc22_d2_test{}_{}".format(
            str(i),
            name,
        ),
        srcs = ["secadd_bc22_test.s"],
        copts = [
            "-DNSHARES=2",
            "-DSCHEME=" + str(scheme),
        ],
        nshares = 2,
        pqc = True,
        scheme = scheme,
        seed = i,
        testgen = ":secadd_bc22_testgen",
        deps = [
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22",
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20_d2",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22_d2",
        ],
    )
    for i in range(3)
    for scheme, name in SCHEME.items()
]

py_binary(
    name = "secaddmodq_bc22_testgen",
    srcs = ["secaddmodq_bc22_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secaddmodq_bc22_mldsa_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["secaddmodq_bc22_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        testgen = ":secaddmodq_bc22_testgen",
        deps = [
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d2",
            "//sw/acc/crypto/mldsa/gadgets:secadd_constant_bmsk_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secaddmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20_d2",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22",
        ],
    )
    for i in range(5)
    for nshares in [2]
]

py_binary(
    name = "seca2bmodq_bc22_testgen",
    srcs = ["seca2bmodq_bc22_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "seca2bmodq_bc22_mldsa_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["seca2bmodq_bc22_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":seca2bmodq_bc22_testgen",
        deps = [
            "//sw/acc/crypto/mldsa/gadgets:seca2bmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d1",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d2",
            "//sw/acc/crypto/mldsa/gadgets:secadd_constant_bmsk_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secaddmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20_d2",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22",
        ],
    )
    for i in range(5)
    for nshares in [2]
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
        name = "seccompress_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["seccompress_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":seccompress_testgen",
        deps = [
            "//sw/acc/crypto/mldsa/gadgets:bitslice_mldsa_k32",
            "//sw/acc/crypto/mldsa/gadgets:scratch",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d2",
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20_d2",
            "//sw/acc/crypto/mldsa/gadgets:seccompress",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22",
        ],
    )
    for i in range(5)
    for nshares in [2]
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
            "//sw/acc/crypto/mldsa/gadgets:bitslice_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:scratch",
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
            "//sw/acc/crypto/mldsa/gadgets:scratch",
            "//sw/acc/crypto/mldsa/gadgets:unbitslice_mldsa",
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
        name = "masked_poly_uniform_gamma1_mldsa65_test" + str(i),
        srcs = ["masked_poly_uniform_gamma1_test.s"],
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":masked_poly_uniform_gamma1_testgen",
        deps = [
            "//sw/acc/crypto/mldsa:kmac_send_msg",
            "//sw/acc/crypto/mldsa:mldsa65_consts",
            "//sw/acc/crypto/mldsa:mldsa65_poly",
            "//sw/acc/crypto/mldsa:mldsa65_rounding",
            "//sw/acc/crypto/mldsa/gadgets:bitslice_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:masked_poly_uniform_gamma1_mldsa65",
            "//sw/acc/crypto/mldsa/gadgets:poly_rej_samp_bitsliced_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:scratch",
            "//sw/acc/crypto/mldsa/gadgets:seca2bmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d1",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d2",
            "//sw/acc/crypto/mldsa/gadgets:secadd_constant_bmsk_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secaddmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20_d2",
            "//sw/acc/crypto/mldsa/gadgets:secb2amodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22",
            "//sw/acc/crypto/mldsa/gadgets:unbitslice_mldsa",
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
        name = "masked_poly_uniform_eta_mldsa87_test" + str(i),
        srcs = ["masked_poly_uniform_eta_test.s"],
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":masked_poly_uniform_eta_testgen",
        deps = [
            "//sw/acc/crypto/mldsa:mldsa87_consts",
            "//sw/acc/crypto/mldsa/gadgets:bitslice_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:masked_poly_uniform_eta_mldsa87",
            "//sw/acc/crypto/mldsa/gadgets:poly_rej_samp_bitsliced_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:scratch",
            "//sw/acc/crypto/mldsa/gadgets:seca2bmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d1",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d2",
            "//sw/acc/crypto/mldsa/gadgets:secadd_constant_bmsk_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secaddmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20_d2",
            "//sw/acc/crypto/mldsa/gadgets:secb2amodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secb2amodq_eta",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22",
            "//sw/acc/crypto/mldsa/gadgets:unbitslice_mldsa",
        ],
    )
    for i in range(3)
]

[
    acc_autogen_sim_test(
        name = "masked_poly_uniform_eta_mldsa65_test" + str(i),
        srcs = ["masked_poly_uniform_eta_test.s"],
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":masked_poly_uniform_eta_testgen",
        testgen_args = [
            "--eta",
            "4",
        ],
        deps = [
            "//sw/acc/crypto/mldsa:mldsa65_consts",
            "//sw/acc/crypto/mldsa/gadgets:bitslice_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:masked_poly_uniform_eta_mldsa65",
            "//sw/acc/crypto/mldsa/gadgets:poly_rej_samp_bitsliced_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:scratch",
            "//sw/acc/crypto/mldsa/gadgets:seca2bmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d1",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d2",
            "//sw/acc/crypto/mldsa/gadgets:secadd_constant_bmsk_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secaddmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20_d2",
            "//sw/acc/crypto/mldsa/gadgets:secb2amodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secb2amodq_eta",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22",
            "//sw/acc/crypto/mldsa/gadgets:unbitslice_mldsa",
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
        name = "secdecompose_mldsa65_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["secdecompose_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DDILITHIUM_MODE=3",
        ],
        nshares = nshares,
        pqc = True,
        scheme = 3,
        seed = i,
        stats = True,
        testgen = ":secdecompose_testgen",
        deps = [
            "//sw/acc/crypto/mldsa:mldsa65_consts",
            "//sw/acc/crypto/mldsa/gadgets:bitslice_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:poly_rej_samp_bitsliced_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:scratch",
            "//sw/acc/crypto/mldsa/gadgets:seca2bmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d1",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d2",
            "//sw/acc/crypto/mldsa/gadgets:secadd_constant_bmsk_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secaddmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20_d2",
            "//sw/acc/crypto/mldsa/gadgets:secb2amodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secdecompose_mldsa65",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22",
            "//sw/acc/crypto/mldsa/gadgets:unbitslice_mldsa",
        ],
    )
    for i in range(3)
    for nshares in [2]
]

[
    acc_autogen_sim_test(
        name = "secdecompose_mldsa44_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["secdecompose_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DDILITHIUM_MODE=2",
        ],
        nshares = nshares,
        pqc = True,
        scheme = 2,
        seed = i,
        stats = True,
        testgen = ":secdecompose_testgen",
        deps = [
            "//sw/acc/crypto/mldsa:kmac_send_msg",
            "//sw/acc/crypto/mldsa:mldsa44_consts",
            "//sw/acc/crypto/mldsa:mldsa44_poly",
            "//sw/acc/crypto/mldsa:mldsa44_rounding",
            "//sw/acc/crypto/mldsa/gadgets:bitslice_mldsa_k32",
            "//sw/acc/crypto/mldsa/gadgets:scratch",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d2",
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20_d2",
            "//sw/acc/crypto/mldsa/gadgets:seccompress",
            "//sw/acc/crypto/mldsa/gadgets:secdecompose_mldsa44",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22",
            "//sw/acc/crypto/mldsa/gadgets:unbitslice_mldsa",
        ],
    )
    for i in range(20)
    for nshares in [2]
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
            "//sw/acc/crypto/mldsa/gadgets:poly_rej_samp_bitsliced_mldsa_test",
        ],
    )
    for i in range(5)
]

py_binary(
    name = "secb2amodq_bc22_testgen",
    srcs = ["secb2amodq_bc22_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secb2amodq_bc22_mldsa_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["secb2amodq_bc22_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":secb2amodq_bc22_testgen",
        deps = [
            "//sw/acc/crypto/mldsa/gadgets:poly_rej_samp_bitsliced_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:scratch",
            "//sw/acc/crypto/mldsa/gadgets:seca2bmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d1",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d2",
            "//sw/acc/crypto/mldsa/gadgets:secadd_constant_bmsk_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secaddmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20_d2",
            "//sw/acc/crypto/mldsa/gadgets:secb2amodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22",
        ],
    )
    for i in range(5)
    for nshares in [2]
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
        name = "secb2amodq_eta_test{}_k{}".format(
            str(i),
            str(kbits),
        ),
        srcs = ["secb2amodq_eta_test.s"],
        copts = [
            "-DNSHARES=2",
            "-DKBITS=" + str(kbits),
        ],
        nshares = 2,
        pqc = True,
        seed = i,
        stats = True,
        testgen = ":secb2amodq_eta_testgen",
        testgen_args = [
            "-k",
            str(kbits),
        ],
        deps = [
            "//sw/acc/crypto/mldsa:mldsa44_consts",
            "//sw/acc/crypto/mldsa/gadgets:bitslice_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:poly_rej_samp_bitsliced_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:scratch",
            "//sw/acc/crypto/mldsa/gadgets:seca2bmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d1",
            "//sw/acc/crypto/mldsa/gadgets:secadd_bc22_immd_d2",
            "//sw/acc/crypto/mldsa/gadgets:secadd_constant_bmsk_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secaddmodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secand_cs20_d2",
            "//sw/acc/crypto/mldsa/gadgets:secb2amodq_bc22_mldsa",
            "//sw/acc/crypto/mldsa/gadgets:secb2amodq_eta",
            "//sw/acc/crypto/mldsa/gadgets:secfulladder_bc22",
            "//sw/acc/crypto/mldsa/gadgets:unbitslice_mldsa",
        ],
    )
    for i in range(3)
    for kbits in [
        3,
        4,
    ]
]
