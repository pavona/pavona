
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

resiliator = module_extension(
    implementation = lambda _: _resiliator_repos(),
)

def _resiliator_repos():
    # Pin the Verilator fork providing --resiliator.
    RESILIATOR_VERILATOR_COMMIT = "a18d5f2b5a6e174c54920e3442886415c92c586a"
    http_archive(
        name = "verilator_resiliator",
        urls = [
            "https://github.com/kjnsen/verilator/archive/{}.tar.gz".format(RESILIATOR_VERILATOR_COMMIT),
        ],
        strip_prefix = "verilator-" + RESILIATOR_VERILATOR_COMMIT,
        build_file = "@pavona_pavona//third_party/resiliator:BUILD.resiliator.bazel",
        sha256 = "7e23ef809c95c7b87c438c748c4bf3852a0d436a5dad3c7d20d1ea302c78a454",
    )
