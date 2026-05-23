#!/usr/bin/env bash
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set -e

# Get the project directory from the location of this script
this_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
proj_root=$( realpath "${this_dir}/../.." )
build_dir="${proj_root}/build-site"

#######
# CLI #
#######
declare command="build"
# The following are only used for "command='serve-proxy'" ------------------------|
declare public_domain="" # (optional) The public-facing domain                  <-|
declare public_port=""   # (optional)The port added to the public-facing domain <-|
declare book_out

command="$1"
public_domain="${2}"
public_port="${3}"

case "$command" in
  "build"|"build-local"|"serve"|"serve-proxy")
    book_out="${build_dir}/book"
    ;;
  "help"|*)
    echo "USAGE: $0 <command> [public_domain] [public_port]"
    echo ""
    echo "commands:"
    echo "  help          prints this message."
    echo "  build         build the site and docs for prod"
    echo "  build-local   build the site and docs for a localhost server"
    echo "  serve         build and serve the site locally"
    echo "  serve-proxy   build and serve the site, with a public url"
    echo ""
    echo "Optional arguments [public_domain] and [public_port] are only used when command='serve-proxy'"
    exit 0
    ;;
esac

#################
# CONFIGURATION #
#################
declare base_url
declare serve_port # The port used by the local webserver (using "build-docs.sh serve/serve-proxy")

getURLs () {
    # Defaults here are for production ("build-docs.sh build")
    local scheme="https"
    local domain="pavona.org"
    local port=""

    # Use un-encrypted localhost URLs when building/serving locally
    # - serve on port 9000.
    if [ "$command" = "build-local" ] || \
       [ "$command" = "serve" ]; then
        scheme="http"
        domain="localhost"
        port=":9000"
        serve_port=":9000"
    fi
    # "serve-proxy" gives us some simple defaults for serving behind a proxy:
    # - set the public_domain/public_port appropriately (see $2/$3)
    # - serve on port 8000.
    if [ "$command" = "serve-proxy" ] ; then
        scheme="http"
        domain="${public_domain}"
        port=":${public_port}"
        serve_port=":8000"
    fi

    base_url="${scheme}://${domain}${port}"
}
getURLs

# Register the pre-processors
# Each book should only be passed the preprocessors it specifies inside the book.toml
# ./book.toml
book_env="env"
book_env+=" MDBOOK_PREPROCESSOR__TESTPLAN__COMMAND=${proj_root}/util/mdbook_testplan.py"
book_env+=" MDBOOK_PREPROCESSOR__TOOLVERSION__COMMAND=${proj_root}/util/mdbook_toolversion.py"
book_env+=" MDBOOK_PREPROCESSOR__ACC__COMMAND=${proj_root}/util/mdbook_acc.py"
book_env+=" MDBOOK_PREPROCESSOR__CODE_SNIPPET__COMMAND=${proj_root}/util/mdbook_code_snippet.py"
book_env+=" MDBOOK_PREPROCESSOR__DOXYGEN__COMMAND=${proj_root}/util/mdbook_doxygen.py"
book_env+=" MDBOOK_PREPROCESSOR__REGGEN__COMMAND=${proj_root}/util/mdbook_reggen.py"
book_env+=" MDBOOK_PREPROCESSOR__README2INDEX__COMMAND=${proj_root}/util/mdbook_readme2index.py"
book_env+=" MDBOOK_PREPROCESSOR__DASHBOARD__COMMAND=${proj_root}/util/mdbook_dashboard.py"
book_env+=" MDBOOK_PREPROCESSOR__TEMPLATE__COMMAND=${proj_root}/util/mdbook_template.py"
book_env+=" MDBOOK_OUTPUT__HTML__THEME=${proj_root}/util/site/book-theme/"
book_env+=" MDBOOK_OUTPUT__HTML__DEFAULT_THEME=light"
book_env+=" MDBOOK_OUTPUT__HTML__PREFERRED_DARK_THEME=dark"
book_args="build"
book_args+=" --dest-dir ${book_out}/"
book_args+=" ${proj_root}"

############
# BUILDING #
############

buildSite () {
    echo "Build Directory : ${build_dir}"
    mkdir -p "${build_dir}"
    mkdir -p "${build_dir}/gen/doxy"

    echo "Building doxygen..."
    # shellcheck disable=SC2086
    ./bazelisk.sh build --verbose_failures //doc:doxygen
    while read -r line; do
      cp -rf "$line" "${build_dir}/gen/"
    done < <(./bazelisk.sh cquery --output=files //doc:doxygen)
    # The files from bazel-out aren't writable. This ensures those that were copied are.
    chmod +w -R "${build_dir}/gen/"
    echo "Doxygen build complete."

    # shellcheck disable=SC2086
    ${book_env} ./bazelisk.sh run --experimental_convenience_symlinks=ignore @mdbook_index//:mdbook__mdbook -- ${book_args}

    # Build Rust Documentation
    local rustdoc_dir="${build_dir}/gen/rustdoc/"
    mkdir -p "${rustdoc_dir}"
    local bazel_out target_rustdoc target_rustdoc_output_path
    bazel_out="$(./bazelisk.sh info output_path 2>/dev/null)"
    for target_rustdoc in "sw/host/opentitanlib:opentitanlib_doc" "sw/host/hsmtool:hsmlib_doc" "sw/host/ot_certs:ot_certs_doc"
    do
      target_rustdoc_output_path="${bazel_out}/k8-fastbuild/bin/$(echo ${target_rustdoc} | tr ':' '/').rustdoc" #TODO : get the target's path using cquery
      ./bazelisk.sh build --experimental_convenience_symlinks=ignore "${target_rustdoc}"
      cp -rf "${target_rustdoc_output_path}"/* "${rustdoc_dir}"
      chown -R "$USER": "${rustdoc_dir}"
      chmod -R +w "${rustdoc_dir}"
    done
    # The files from bazel-out aren't writable. This ensures those that were copied are.
    chmod +w -R "${rustdoc_dir}"

    rm -rf "${build_dir}/gen/api-xml" # Remove the intermediate XML that doxygen uses to generate HTML.

    # Put landing page and dark mode highlighting in docs directory, fix links from book/ to gen/
    cp -f "$(dirname $0)/landing.html" "${build_dir}/index.html"
    cp -f "$(dirname $0)/book-theme/dark-highlight.css" "${build_dir}/book/dark-highlight.css"
    python3 "$(dirname $0)/link_headers.py"
    for doxy_ref_file in $(grep "#DOXYGEN" -lr ./build-site); do
      path_to_build_dir=$(realpath --relative-to=$doxy_ref_file $build_dir)
      path_to_doxy=$(realpath --relative-to=$book_out ${build_dir}/gen/doxy)
      sed -i "s:#DOXYGEN:${path_to_build_dir}/${path_to_doxy}:g" $doxy_ref_file
    done
    for rustdoc_ref_file in $(grep "#RUSTDOC" -lr ./build-site); do
      path_to_build_dir=$(realpath --relative-to=$rustdoc_ref_file $build_dir)
      path_to_rustdoc=$(realpath --relative-to=$book_out ${build_dir}/gen/rustdoc)
      sed -i "s:#RUSTDOC:${path_to_build_dir}/${path_to_rustdoc}:g" $rustdoc_ref_file
    done
    # -------
}
buildSite

###########
# SERVING #
###########

# If serving, run the python HTTP server
if [ "$command" = "serve" ] || [ "$command" = "serve-proxy" ]; then
  echo "--------------------------------------------"
  echo
  echo "Website being served at : ${base_url}"
  echo
  echo "--------------------------------------------"
  python3 -m http.server -d "$build_dir" "${serve_port:1}"
                                         # strip leading :
fi
