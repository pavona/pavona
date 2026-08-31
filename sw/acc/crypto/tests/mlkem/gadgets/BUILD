# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@ot_python_deps//:requirements.bzl", "requirement")
load("@rules_python//python:defs.bzl", "py_binary")
load("//rules:acc.bzl", "acc_autogen_sim_test", "acc_sim_test")

package(default_visibility = ["//visibility:public"])

NTESTS = 10

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

# bitcopymask
py_binary(
    name = "bitcopymask_testgen",
    srcs = ["bitcopymask_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "bitcopymask_test{}".format(
            str(i),
        ),
        srcs = ["bitcopymask_test.s"],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":bitcopymask_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# to bitslice representation
py_binary(
    name = "poly_to_bitsliced_testgen",
    srcs = ["poly_to_bitsliced_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "poly_to_bitsliced_test" + str(i),
        srcs = ["poly_to_bitsliced_test.s"],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":poly_to_bitsliced_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# from bitslice representation
py_binary(
    name = "poly_from_bitsliced_testgen",
    srcs = ["poly_from_bitsliced_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "poly_from_bitsliced_test" + str(i),
        srcs = ["poly_from_bitsliced_test.s"],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":poly_from_bitsliced_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# poly_hocompress
py_binary(
    name = "poly_hocompress_testgen",
    srcs = ["poly_hocompress_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "poly_hocompress_test{}".format(
            str(i),
        ),
        srcs = ["poly_hocompress_test.s"],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":poly_hocompress_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# polyvec_hocompress
py_binary(
    name = "polyvec_hocompress_testgen",
    srcs = ["polyvec_hocompress_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "polyvec_hocompress_test{}".format(
            str(i),
        ),
        srcs = ["polyvec_hocompress_test.s"],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":polyvec_hocompress_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# refreshmodq
py_binary(
    name = "refreshmodq_testgen",
    srcs = ["refreshmodq_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "refreshmodq_test{}".format(
            str(i),
        ),
        srcs = ["refreshmodq_test.s"],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":refreshmodq_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# poly_rej_samp
py_binary(
    name = "poly_rej_samp_testgen",
    srcs = ["poly_rej_samp_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "poly_rej_samp_test{}".format(
            str(i),
        ),
        srcs = ["poly_rej_samp_test.s"],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":poly_rej_samp_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets_rej_sample_test",
        ],
    )
    for i in range(NTESTS)
]

# poly_masked_compare_dv
py_binary(
    name = "poly_masked_compare_dv_testgen",
    srcs = ["poly_masked_compare_dv_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "poly_masked_compare_dv_test{}".format(
            str(i),
        ),
        srcs = ["poly_masked_compare_dv_test.s"],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":poly_masked_compare_dv_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# poly_masked_compare_du
py_binary(
    name = "poly_masked_compare_du_testgen",
    srcs = ["poly_masked_compare_du_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "poly_masked_compare_du_test{}".format(
            str(i),
        ),
        srcs = ["poly_masked_compare_du_test.s"],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":poly_masked_compare_du_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# finalize_cmp
py_binary(
    name = "finalize_cmp_testgen",
    srcs = ["finalize_cmp_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "finalize_cmp_test{}".format(
            str(i),
        ),
        srcs = ["finalize_cmp_test.s"],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":finalize_cmp_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# masked_poly_getnoise
py_binary(
    name = "masked_poly_getnoise_testgen",
    srcs = ["masked_poly_getnoise_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
        requirement("pycryptodome"),
    ],
)

[
    acc_autogen_sim_test(
        name = "masked_poly_getnoise_test{}".format(
            str(i),
        ),
        srcs = ["masked_poly_getnoise_test.s"],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":masked_poly_getnoise_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# masked_poly_tomsg
py_binary(
    name = "masked_poly_tomsg_testgen",
    srcs = ["masked_poly_tomsg_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "masked_poly_tomsg_test{}".format(
            str(i),
        ),
        srcs = ["masked_poly_tomsg_test.s"],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":masked_poly_tomsg_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# masked_poly_frommsg
py_binary(
    name = "masked_poly_frommsg_testgen",
    srcs = ["masked_poly_frommsg_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "masked_poly_frommsg_test{}".format(
            str(i),
        ),
        srcs = ["masked_poly_frommsg_test.s"],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":masked_poly_frommsg_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# refreshios
py_binary(
    name = "refreshios_testgen",
    srcs = ["refreshios_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "refreshios_test{}".format(
            str(i),
        ),
        srcs = ["refreshios_test.s"],
        seed = i,
        stats = STATS,
        testgen = ":refreshios_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# seca2b
py_binary(
    name = "seca2b_testgen",
    srcs = ["seca2b_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "seca2b_test{}".format(
            str(i),
        ),
        srcs = ["seca2b_test.s"],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":seca2b_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# seca2bmodq
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
        stats = STATS,
        testgen = ":seca2bmodq_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# secb2amodq
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
        stats = STATS,
        testgen = ":secb2amodq_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# secadd
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
        stats = STATS,
        testgen = ":secadd_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# secand
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
        stats = STATS,
        testgen = ":secand_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# secfulladder
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
        stats = STATS,
        testgen = ":secfulladder_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]

# seconebitb2amodq
py_binary(
    name = "seconebitb2amodq_testgen",
    srcs = ["seconebitb2amodq_testgen.py"],
    imports = [
        "../../../../../../hw/ip/acc/util",
    ],
    deps = [
        "//hw/ip/acc/util/shared:testgen",
    ],
)

[
    acc_autogen_sim_test(
        name = "seconebitb2amodq_test{}".format(
            str(i),
        ),
        srcs = ["seconebitb2amodq_test.s"],
        pqc = True,
        seed = i,
        stats = STATS,
        testgen = ":seconebitb2amodq_testgen",
        deps = [
            "//sw/acc/crypto/mlkem:consts",
            "//sw/acc/crypto/mlkem:gadgets",
        ],
    )
    for i in range(NTESTS)
]
