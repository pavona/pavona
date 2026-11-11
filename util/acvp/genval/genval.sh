#!/bin/bash
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Runs the ACVP-Server gen/vals on a registration.
#
#   genval check <registration.json>
#   genval vectors <registration.json> <out-dir>

set -euo pipefail

if [ $# -lt 2 ]; then
    sed -n 's/^#   //p' "$0" >&2
    exit 2
fi

# The registration files leave out the fields only the gen/vals need.
jq '{vsId: 0, isSample: true, conformances: []} + .' "$2" > /tmp/registration.json

case "$1" in
    check)
        cd /opt/acvp/genval
        dotnet NIST.CVP.ACVTS.Generation.GenValApp.dll -c /tmp/registration.json > /dev/null
        ;;
    vectors)
        hash=$(sha256sum "$2" | cut -d ' ' -f 1)
        name=$(jq -r '[.algorithm, .mode, .revision] | map(select(. != null and . != "")) | join("-")' "$2")
        out="$3/$ACVP_SERVER_VERSION/$name/$hash"

        (cd /opt/acvp/orleans && dotnet NIST.CVP.ACVTS.Orleans.ServerHost.dll --console > /tmp/orleans.log 2>&1) &
        if ! timeout 120 bash -c 'until (echo > /dev/tcp/127.0.0.1/30000) 2> /dev/null; do sleep 1; done'; then
            cat /tmp/orleans.log >&2
            exit 1
        fi
        cd /opt/acvp/genval
        dotnet NIST.CVP.ACVTS.Generation.GenValApp.dll -g /tmp/registration.json > /dev/null

        mkdir -p "$out"
        cp "$2" "$out/registration.json"
        cp /tmp/{prompt,expectedResults,internalProjection}.json "$out"
        echo "$out"
        ;;
esac
