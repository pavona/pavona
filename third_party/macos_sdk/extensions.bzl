# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Pins the macOS SDK the host toolchain builds against."""

_SDK_PATH = "expanded/Payload/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"

# The SDK is Apple's. It is downloaded from Apple, subject to the Xcode and
# Apple SDKs Agreement, and not covered by this repository's Apache-2.0 license.
_SDK_URLS = [
    "https://swcdn.apple.com/content/downloads/09/08/047-91568-A_Y1CFZWQCD4/4xekpyz43i26dbp4enxfro8eb1q7wiujh5/CLTools_macOSNMOS_SDK.pkg",
    "https://web.archive.org/web/20260512015547/https://swcdn.apple.com/content/downloads/09/08/047-91568-A_Y1CFZWQCD4/4xekpyz43i26dbp4enxfro8eb1q7wiujh5/CLTools_macOSNMOS_SDK.pkg",
]
_SDK_SHA256 = "5f044578cd78a3a9b9c965a42d56bad609ee5d252e1d4e6aa7c42fc3f35fee7b"

_BUILD = """
filegroup(
    name = "sysroot",
    srcs = glob(["**"], allow_empty = True),
    visibility = ["//visibility:public"],
)
"""

def _macos_sdk_impl(rctx):
    rctx.file("BUILD.bazel", _BUILD)

    # Empty on other hosts.
    if rctx.os.name != "mac os x":
        return

    rctx.download(url = _SDK_URLS, output = "sdk.pkg", sha256 = _SDK_SHA256)
    result = rctx.execute(["/usr/sbin/pkgutil", "--expand-full", "sdk.pkg", "expanded"])
    if result.return_code:
        fail("Failed to unpack the macOS SDK:\n" + result.stderr)
    for entry in rctx.path(_SDK_PATH).readdir():
        rctx.rename(entry, entry.basename)

    # Remove files that are not needed.
    for path in ["expanded", "sdk.pkg", "System/Library/Frameworks/Ruby.framework", "usr/share"]:
        rctx.delete(path)

_macos_sdk = repository_rule(implementation = _macos_sdk_impl)

macos_sdk = module_extension(
    implementation = lambda _: _macos_sdk(name = "macos_sdk"),
)
