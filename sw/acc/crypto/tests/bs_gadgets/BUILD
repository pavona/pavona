# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@ot_python_deps//:requirements.bzl", "requirement")
load("@rules_python//python:defs.bzl", "py_binary")
load("//rules:acc.bzl", "acc_autogen_sim_test", "acc_sim_test")

package(default_visibility = ["//visibility:public"])

NTESTS = 10

NSHARES = [
    2,
    3,
    4,
]

SCHEME = {
    0: "mlkem",
    1: "mldsa",
}

NAME_BY_SEC_LEVEL = {
    2: "mlkem512",
    3: "mlkem768",
    4: "mlkem1024",
}

STATS = True

# bitcopymask_bc22_mlkem
py_binary(
    name = "bitcopymask_bc22_mlkem_testgen",
    srcs = ["bitcopymask_bc22_mlkem_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "bitcopymask_bc22_mlkem_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["bitcopymask_bc22_mlkem_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":bitcopymask_bc22_mlkem_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:bitcopymask_bc22_mlkem",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
]

# to and from bitslice representation
py_binary(
    name = "bs_mlkem_testgen",
    srcs = ["bs_mlkem_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "bs_mlkem_test" + str(i),
        srcs = ["bs_mlkem_test.s"],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":bs_mlkem_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:bs_mlkem",
        ],
    )
    for i in range(NTESTS)
]

# hocompress_cgmz21b
py_binary(
    name = "hocompress_cgmz21b_testgen",
    srcs = ["hocompress_cgmz21b_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "hocompress_cgmz21b_test{}_{}shares_{}".format(
            str(i),
            str(nshares),
            name,
        ),
        srcs = ["hocompress_cgmz21b_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DKYBER_K=" + str(sec_level),
        ],
        nshares = nshares,
        pqc = True,
        scheme = sec_level,
        seed = i,
        stats = STATS,
        testgen = ":hocompress_cgmz21b_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:hocompress_cgmz21b_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:secadd_bc22",
            "//sw/acc/crypto/bs_gadgets:secand_cs20_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:seca2b_bc22_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:secfulladder_bc22_" + str(nshares) + "shares",
        ],
    )
    for i in range(NTESTS)
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
    for nshares in NSHARES
]

# linearrefreshmodq_rp10_mlkem
py_binary(
    name = "linearrefreshmodq_rp10_mlkem_testgen",
    srcs = ["linearrefreshmodq_rp10_mlkem_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "linearrefreshmodq_rp10_mlkem_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["linearrefreshmodq_rp10_mlkem_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":linearrefreshmodq_rp10_mlkem_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:linearrefreshmodq_rp10_mlkem_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:poly_rej_samp",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
]

# masked_compare_bc22
py_binary(
    name = "masked_compare_bc22_testgen",
    srcs = ["masked_compare_bc22_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("pycryptodome"),
    ],
)

[
    acc_autogen_sim_test(
        name = "masked_compare_bc22_test{}_{}shares_{}".format(
            str(i),
            str(nshares),
            name,
        ),
        srcs = ["masked_compare_bc22_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DKYBER_K=" + str(sec_level),
        ],
        nshares = nshares,
        pqc = True,
        scheme = sec_level,
        seed = i,
        stats = STATS,
        testgen = ":masked_compare_bc22_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:hocompress_cgmz21b_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:masked_compare_bc22",
            "//sw/acc/crypto/bs_gadgets:secadd_bc22",
            "//sw/acc/crypto/bs_gadgets:secand_cs20_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:seca2b_bc22_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:secfulladder_bc22_" + str(nshares) + "shares",
        ],
    )
    for i in range(NTESTS)
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
    for nshares in NSHARES
]

# masked_poly_getnoise
py_binary(
    name = "masked_poly_getnoise_testgen",
    srcs = ["masked_poly_getnoise_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("pycryptodome"),
    ],
)

[
    acc_autogen_sim_test(
        name = "masked_poly_getnoise_test{}_{}shares_{}".format(
            str(i),
            str(nshares),
            name,
        ),
        srcs = ["masked_poly_getnoise_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DKYBER_K=" + str(sec_level),
        ],
        nshares = nshares,
        pqc = True,
        scheme = sec_level,
        seed = i,
        stats = STATS,
        testgen = ":masked_poly_getnoise_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:bitcopymask_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:bs_mlkem",
            "//sw/acc/crypto/bs_gadgets:masked_cbd_bc22",
            "//sw/acc/crypto/bs_gadgets:masked_poly_getnoise_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:refreshios_bc22",
            "//sw/acc/crypto/bs_gadgets:seca2bmodq_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secadd_bc22",
            "//sw/acc/crypto/bs_gadgets:secaddmodq_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secand_cs20_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:secb2amodq_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secfulladder_bc22_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:poly_rej_samp",
        ],
    )
    for i in range(NTESTS)
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
    for nshares in NSHARES
]

# masked_poly_tomsg
py_binary(
    name = "masked_poly_tomsg_testgen",
    srcs = ["masked_poly_tomsg_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "masked_poly_tomsg_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["masked_poly_tomsg_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":masked_poly_tomsg_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:masked_poly_tomsg",
            "//sw/acc/crypto/bs_gadgets:secadd_bc22",
            "//sw/acc/crypto/bs_gadgets:secand_cs20_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:seca2b_bc22_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:secfulladder_bc22_" + str(nshares) + "shares",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
]

# onebitdecompress_bgr21
py_binary(
    name = "onebitdecompress_bgr21_testgen",
    srcs = ["onebitdecompress_bgr21_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "onebitdecompress_bgr21_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["onebitdecompress_bgr21_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":onebitdecompress_bgr21_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:linearrefreshmodq_rp10_mlkem_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:onebitdecompress_bgr21",
            "//sw/acc/crypto/bs_gadgets:poly_rej_samp",
            "//sw/acc/crypto/bs_gadgets:seconebitb2amodq_spog19_mlkem",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
]

# refreshios_bc22
py_binary(
    name = "refreshios_bc22_testgen",
    srcs = ["refreshios_bc22_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "refreshios_bc22_test{}_{}shares_{}".format(
            str(i),
            str(nshares),
            name,
        ),
        srcs = ["refreshios_bc22_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DSCHEME=" + str(scheme),
        ],
        nshares = nshares,
        scheme = scheme,
        seed = i,
        stats = STATS,
        testgen = ":refreshios_bc22_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:refreshios_bc22",
        ],
    )
    for i in range(NTESTS)
    for scheme, name in SCHEME.items()
    for nshares in NSHARES
]

# seca2b_bc22
py_binary(
    name = "seca2b_bc22_testgen",
    srcs = ["seca2b_bc22_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "seca2b_bc22_test{}_{}shares_{}".format(
            str(i),
            str(nshares),
            name,
        ),
        srcs = ["seca2b_bc22_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DSCHEME=" + str(scheme),
        ],
        nshares = nshares,
        pqc = True,
        scheme = scheme,
        seed = i,
        stats = STATS,
        testgen = ":seca2b_bc22_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:secadd_bc22",
            "//sw/acc/crypto/bs_gadgets:secand_cs20_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:seca2b_bc22_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:secfulladder_bc22_" + str(nshares) + "shares",
        ],
    )
    for i in range(NTESTS)
    for scheme, name in SCHEME.items()
    for nshares in NSHARES
]

# seca2bmodq_bc22_mlkem
py_binary(
    name = "seca2bmodq_bc22_mlkem_testgen",
    srcs = ["seca2bmodq_bc22_mlkem_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "seca2bmodq_bc22_mlkem_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["seca2bmodq_bc22_mlkem_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":seca2bmodq_bc22_mlkem_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:bitcopymask_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secadd_bc22",
            "//sw/acc/crypto/bs_gadgets:secand_cs20_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:seca2bmodq_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secfulladder_bc22_" + str(nshares) + "shares",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
]

# secb2amodq_bc22_mlkem
py_binary(
    name = "secb2amodq_bc22_mlkem_testgen",
    srcs = ["secb2amodq_bc22_mlkem_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secb2amodq_bc22_mlkem_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["secb2amodq_bc22_mlkem_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":secb2amodq_bc22_mlkem_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:bitcopymask_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:bs_mlkem",
            "//sw/acc/crypto/bs_gadgets:refreshios_bc22",
            "//sw/acc/crypto/bs_gadgets:seca2bmodq_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secadd_bc22",
            "//sw/acc/crypto/bs_gadgets:secand_cs20_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:secb2amodq_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secfulladder_bc22_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:poly_rej_samp",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
]

# secadd_bc22
py_binary(
    name = "secadd_bc22_testgen",
    srcs = ["secadd_bc22_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
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
        stats = STATS,
        testgen = ":secadd_bc22_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:secadd_bc22",
            "//sw/acc/crypto/bs_gadgets:secand_cs20_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:secfulladder_bc22_" + str(nshares) + "shares",
        ],
    )
    for i in range(NTESTS)
    for scheme, name in SCHEME.items()
    for nshares in NSHARES
]

# secaddmodq_bc22_mlkem
py_binary(
    name = "secaddmodq_bc22_mlkem_testgen",
    srcs = ["secaddmodq_bc22_mlkem_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secaddmodq_bc22_mlkem_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["secaddmodq_bc22_mlkem_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":secaddmodq_bc22_mlkem_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:bitcopymask_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secadd_bc22",
            "//sw/acc/crypto/bs_gadgets:secaddmodq_bc22_mlkem",
            "//sw/acc/crypto/bs_gadgets:secand_cs20_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:secfulladder_bc22_" + str(nshares) + "shares",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
]

# secand_cs20
py_binary(
    name = "secand_cs20_testgen",
    srcs = ["secand_cs20_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
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
        stats = STATS,
        testgen = ":secand_cs20_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:secand_cs20_" + str(nshares) + "shares",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
]

# secfulladder_bc22
py_binary(
    name = "secfulladder_bc22_testgen",
    srcs = ["secfulladder_bc22_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
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
        stats = STATS,
        testgen = ":secfulladder_bc22_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:secand_cs20_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:secfulladder_bc22_" + str(nshares) + "shares",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
]

# seconebitb2amodq_spog19_mlkem
py_binary(
    name = "seconebitb2amodq_spog19_mlkem_testgen",
    srcs = ["seconebitb2amodq_spog19_mlkem_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "seconebitb2amodq_spog19_mlkem_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["seconebitb2amodq_spog19_mlkem_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":seconebitb2amodq_spog19_mlkem_testgen",
        deps = [
            "//sw/acc/crypto/bs_gadgets:linearrefreshmodq_rp10_mlkem_" + str(nshares) + "shares",
            "//sw/acc/crypto/bs_gadgets:poly_rej_samp",
            "//sw/acc/crypto/bs_gadgets:seconebitb2amodq_spog19_mlkem",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
]
