# syntax=docker/dockerfile:1
FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
# 15.2 for CLion compatibility
ARG GDB_VERSION=16.1
ARG GDB_SHA256=""

SHELL ["/bin/bash","-o","pipefail","-c"]

# Build dependencies for GDB
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    ca-certificates \
    python3 \
    pkg-config \
    libmpfr-dev libgmp3-dev libmpc-dev \
    libssl-dev \
    texinfo \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Build and install GDB
RUN set -euo pipefail; \
    curl -fsSLo gdb.tar.gz "http://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.gz"; \
    if [ -n "${GDB_SHA256}" ]; then echo "${GDB_SHA256}  gdb.tar.gz" | sha256sum -c -; fi; \
    tar -xf gdb.tar.gz && rm gdb.tar.gz && \
    cd gdb-${GDB_VERSION} && mkdir build && cd build && \
    ../configure --prefix=/usr/local --disable-werror --with-python && \
    make -j"$(nproc)" && make install-strip

# This image provides /usr/local with GDB installed.
# Build example:
#   docker build -f gdb-builder-ubuntu22.04.dockerfile -t gdb-builder:ubuntu22.04-15.2 .
