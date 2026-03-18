# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@ot_python_deps//:requirements.bzl", "requirement")
load("@rules_python//python:defs.bzl", "py_binary")
load("//rules:acc.bzl", "acc_autogen_sim_test", "acc_sim_test")

package(default_visibility = ["//visibility:public"])

NSHARES = [2]

SCHEME = {
    0: "mlkem",
    1: "mldsa",
}

NAME_BY_SEC_LEVEL = {
    2: "mlkem512",
    3: "mlkem768",
    4: "mlkem1024",
}

NTESTS = 10

STATS = True

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
            "//sw/acc/crypto/gadgets:linearrefreshmodq_rp10_mlkem",
            "//sw/acc/crypto/gadgets:poly_rej_samp",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
]

# masked_poly_getnoise_eta
py_binary(
    name = "masked_poly_getnoise_eta_testgen",
    srcs = ["masked_poly_getnoise_eta_testgen.py"],
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
        name = "masked_poly_getnoise_eta_test{}_{}shares_{}".format(
            str(i),
            str(nshares),
            name,
        ),
        srcs = ["masked_poly_getnoise_eta_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DSCHEME=" + str(sec_level),
            "-DKYBER_K=" + str(sec_level),
        ],
        nshares = nshares,
        pqc = True,
        scheme = sec_level,
        seed = i,
        testgen = ":masked_poly_getnoise_eta_testgen",
        deps = [
            "//sw/acc/crypto/gadgets:masked_poly_getnoise_" + str(nshares) + "shares",
            "//sw/acc/crypto/gadgets:linearrefreshmodq_rp10_mlkem",
            "//sw/acc/crypto/gadgets:poly_rej_samp",
            "//sw/acc/crypto/gadgets:seconebitb2amodq_spog19_mlkem",
            "//sw/acc/crypto/gadgets:secsampler1_spog19",
        ],
    )
    for i in range(NTESTS)
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
    for nshares in NSHARES
]

# mdecode_ospg18
py_binary(
    name = "mdecode_ospg18_testgen",
    srcs = ["mdecode_ospg18_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "mdecode_ospg18_test{}_{}shares_mlkem".format(
            str(i),
            str(nshares),
        ),
        srcs = ["mdecode_ospg18_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DSCHEME=0",
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":mdecode_ospg18_testgen",
        deps = [
            "//sw/acc/crypto/gadgets:mdecode_ospg18",
            "//sw/acc/crypto/gadgets:refresh_bbd16_mlkem",
            "//sw/acc/crypto/gadgets:seca2bmodq_spog19_mlkem",
            "//sw/acc/crypto/gadgets:secadd_cgtv15_mlkem",
            "//sw/acc/crypto/gadgets:secaddmodq_bbe18_mlkem",
            "//sw/acc/crypto/gadgets:secand_isw03_mlkem",
            "//sw/acc/crypto/gadgets:sharewise_mlkem",
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
            "//sw/acc/crypto/gadgets:linearrefreshmodq_rp10_mlkem",
            "//sw/acc/crypto/gadgets:poly_rej_samp",
            "//sw/acc/crypto/gadgets:seconebitb2amodq_spog19_mlkem",
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
        name = "onebitdecompress_bgr21_test{}_{}shares_mlkem".format(
            str(i),
            str(nshares),
        ),
        srcs = ["onebitdecompress_bgr21_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DSCHEME=0",
        ],
        nshares = nshares,
        pqc = True,
        scheme = 0,
        seed = i,
        testgen = ":onebitdecompress_bgr21_testgen",
        deps = [
            "//sw/acc/crypto/gadgets:linearrefreshmodq_rp10_mlkem",
            "//sw/acc/crypto/gadgets:onebitdecompress_bgr21",
            "//sw/acc/crypto/gadgets:poly_rej_samp",
            "//sw/acc/crypto/gadgets:seconebitb2amodq_spog19_mlkem",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
]

# poly_compare_bgr21
py_binary(
    name = "poly_compare_bgr21_testgen",
    srcs = ["poly_compare_bgr21_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "poly_compare_bgr21_test{}_{}shares_{}".format(
            str(i),
            str(nshares),
            name,
        ),
        srcs = ["poly_compare_bgr21_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DSCHEME=0",
            "-DKYBER_K=" + str(sec_level),
        ],
        nshares = nshares,
        pqc = True,
        scheme = sec_level,  # use scheme as sec_level for testing with different ML-KEM.
        seed = i,
        testgen = ":poly_compare_bgr21_testgen",
        deps = [
            "//sw/acc/crypto/gadgets:compare_consts",
            "//sw/acc/crypto/gadgets:poly_compare_bgr21",
            "//sw/acc/crypto/gadgets:refresh_bbd16_mlkem",
            "//sw/acc/crypto/gadgets:seca2bmodq_spog19_mlkem",
            "//sw/acc/crypto/gadgets:secadd_cgtv15_mlkem",
            "//sw/acc/crypto/gadgets:secaddmodq_bbe18_mlkem",
            "//sw/acc/crypto/gadgets:secand_isw03_mlkem",
            "//sw/acc/crypto/gadgets:sharewise_mlkem",
        ],
    )
    for i in range(NTESTS)
    for sec_level, name in NAME_BY_SEC_LEVEL.items()
    for nshares in NSHARES
]

# refresh_bbd16
py_binary(
    name = "refresh_bbd16_testgen",
    srcs = ["refresh_bbd16_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "refresh_bbd16_test{}_{}shares_{}".format(
            str(i),
            str(nshares),
            name,
        ),
        srcs = ["refresh_bbd16_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DSCHEME=" + str(scheme),
        ],
        nshares = nshares,
        scheme = scheme,
        seed = i,
        testgen = ":refresh_bbd16_testgen",
        deps = [
            "//sw/acc/crypto/gadgets:refresh_bbd16_" + name,
        ],
    )
    for i in range(NTESTS)
    for scheme, name in SCHEME.items()
    for nshares in NSHARES
]

# seca2bmodq_spog19
py_binary(
    name = "seca2bmodq_spog19_testgen",
    srcs = ["seca2bmodq_spog19_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "seca2bmodq_spog19_test{}_{}shares_{}".format(
            str(i),
            str(nshares),
            name,
        ),
        srcs = ["seca2bmodq_spog19_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DSCHEME=" + str(scheme),
        ],
        nshares = nshares,
        pqc = True,
        scheme = scheme,
        seed = i,
        testgen = ":seca2bmodq_spog19_testgen",
        deps = [
            "//sw/acc/crypto/gadgets:refresh_bbd16_" + name,
            "//sw/acc/crypto/gadgets:secadd_cgtv15_" + name,
            "//sw/acc/crypto/gadgets:seca2bmodq_spog19_" + name,
            "//sw/acc/crypto/gadgets:secaddmodq_bbe18_" + name,
            "//sw/acc/crypto/gadgets:secand_isw03_" + name,
            "//sw/acc/crypto/gadgets:sharewise_" + name,
        ],
    )
    for i in range(NTESTS)
    for scheme, name in SCHEME.items()
    for nshares in NSHARES
]

# secb2amodq_spog19
py_binary(
    name = "secb2amodq_spog19_mlkem_testgen",
    srcs = ["secb2amodq_spog19_mlkem_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secb2amodq_spog19_mlkem_test{}_{}shares".format(
            str(i),
            str(nshares),
        ),
        srcs = ["secb2amodq_spog19_mlkem_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
        ],
        nshares = nshares,
        pqc = True,
        seed = i,
        testgen = ":secb2amodq_spog19_mlkem_testgen",
        deps = [
            "//sw/acc/crypto/gadgets:linearrefreshmodq_rp10_mlkem",
            "//sw/acc/crypto/gadgets:poly_rej_samp",
            "//sw/acc/crypto/gadgets:secb2amodq_spog19_mlkem",
            "//sw/acc/crypto/gadgets:seconebitb2amodq_spog19_mlkem",
        ],
    )
    for i in range(NTESTS)
    for nshares in NSHARES
]

# secadd_cgtv15
py_binary(
    name = "secadd_cgtv15_testgen",
    srcs = ["secadd_cgtv15_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secadd_cgtv15_test{}_{}shares_{}".format(
            str(i),
            str(nshares),
            name,
        ),
        srcs = ["secadd_cgtv15_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DSCHEME=" + str(scheme),
        ],
        nshares = nshares,
        pqc = True,
        scheme = scheme,
        seed = i,
        testgen = ":secadd_cgtv15_testgen",
        deps = [
            "//sw/acc/crypto/gadgets:refresh_bbd16_" + name,
            "//sw/acc/crypto/gadgets:secadd_cgtv15_" + name,
            "//sw/acc/crypto/gadgets:secand_isw03_" + name,
            "//sw/acc/crypto/gadgets:sharewise_" + name,
        ],
    )
    for i in range(NTESTS)
    for scheme, name in SCHEME.items()
    for nshares in NSHARES
]

# secaddmodq_bbe18
py_binary(
    name = "secaddmodq_bbe18_testgen",
    srcs = ["secaddmodq_bbe18_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secaddmodq_bbe18_test{}_{}shares_{}".format(
            str(i),
            str(nshares),
            name,
        ),
        srcs = ["secaddmodq_bbe18_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DSCHEME=" + str(scheme),
        ],
        nshares = nshares,
        pqc = True,
        scheme = scheme,
        seed = i,
        testgen = ":secaddmodq_bbe18_testgen",
        deps = [
            "//sw/acc/crypto/gadgets:refresh_bbd16_" + name,
            "//sw/acc/crypto/gadgets:secadd_cgtv15_" + name,
            "//sw/acc/crypto/gadgets:secaddmodq_bbe18_" + name,
            "//sw/acc/crypto/gadgets:secand_isw03_" + name,
            "//sw/acc/crypto/gadgets:sharewise_" + name,
        ],
    )
    for i in range(NTESTS)
    for scheme, name in SCHEME.items()
    for nshares in NSHARES
]

# secand_isw03
py_binary(
    name = "secand_isw03_testgen",
    srcs = ["secand_isw03_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "secand_isw03_test{}_{}shares_{}".format(
            str(i),
            str(nshares),
            name,
        ),
        srcs = ["secand_isw03_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DSCHEME=" + str(scheme),
        ],
        nshares = nshares,
        pqc = True,
        scheme = scheme,
        seed = i,
        testgen = ":secand_isw03_testgen",
        deps = [
            "//sw/acc/crypto/gadgets:secand_isw03_" + name,
        ],
    )
    for i in range(NTESTS)
    for scheme, name in SCHEME.items()
    for nshares in NSHARES
]

# sharewise
py_binary(
    name = "sharewise_testgen",
    srcs = ["sharewise_testgen.py"],
    imports = [
        "../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "sharewise_test{}_{}shares_{}".format(
            str(i),
            str(nshares),
            name,
        ),
        srcs = ["sharewise_test.s"],
        copts = [
            "-DNSHARES=" + str(nshares),
            "-DSCHEME=" + str(scheme),
        ],
        nshares = nshares,
        pqc = True,
        scheme = scheme,
        seed = i,
        testgen = ":sharewise_testgen",
        deps = [
            "//sw/acc/crypto/gadgets:sharewise_" + name,
        ],
    )
    for i in range(NTESTS)
    for scheme, name in SCHEME.items()
    for nshares in NSHARES
]
