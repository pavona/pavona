# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

ARG ACVP_SERVER_VERSION=1.1.0.43

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG ACVP_SERVER_VERSION
ARG ACVP_SERVER_SHA256=394c1b549364e5ee76e249a9ca40c59a38342d2826579d8e4b4c478e5d05485a
WORKDIR /src
ADD --checksum=sha256:${ACVP_SERVER_SHA256} \
    https://github.com/usnistgov/ACVP-Server/archive/refs/tags/v${ACVP_SERVER_VERSION}.tar.gz \
    /acvp.tar.gz
RUN tar xzf /acvp.tar.gz --strip-components=1 --exclude='*/gen-val/json-files' \
    && ln -s _config/Directory.Build.props Directory.Build.props \
    && ln -s _config/Directory.Packages.props Directory.Packages.props
RUN dotnet publish gen-val/samples/GenValAppRunner/src/NIST.CVP.ACVTS.Generation.GenValApp.csproj \
        -c Release -o /opt/acvp/genval \
    && dotnet publish gen-val/samples/NIST.CVP.ACVTS.Orleans.ServerHost/NIST.CVP.ACVTS.Orleans.ServerHost.csproj \
        -c Release -o /opt/acvp/orleans

FROM mcr.microsoft.com/dotnet/aspnet:8.0
ARG ACVP_SERVER_VERSION
ENV ACVP_SERVER_VERSION=${ACVP_SERVER_VERSION}
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /opt/acvp /opt/acvp
ENV DOTNET_CLI_HOME=/tmp
COPY genval.sh /usr/local/bin/genval
ENTRYPOINT ["genval"]
