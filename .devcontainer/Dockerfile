FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG FLUTTER_VERSION=3.47.7

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git libglu1-mesa unzip xz-utils zip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C /opt \
    && git config --system --add safe.directory /opt/flutter \
    && chown -R vscode:vscode /opt/flutter

ENV PATH="/opt/flutter/bin:${PATH}"

USER vscode

RUN flutter --version
