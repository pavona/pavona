# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0


load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])

otbn_library(
    name = "poly_add_dilithium",
    srcs = [
        "poly_add_dilithium.s",
    ],
)

otbn_library(
    name = "poly_base_dilithium",
    srcs = [
        "poly_base_dilithium.s",
    ],
)

otbn_library(
    name = "poly_pointwise_dilithium",
    srcs = [
        "poly_pointwise_dilithium.s",
    ],
)
