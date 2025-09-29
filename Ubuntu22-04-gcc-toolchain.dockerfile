# syntax=docker/dockerfile:1
FROM ubuntu:22.04 AS gdb-builder

ARG DEBIAN_FRONTEND=noninteractive
# 15.2 for CLion compatibility
ARG GDB_VERSION=15.2
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

ARG GDB_SHA256=""
RUN set -euo pipefail; \
    curl -fsSLo gdb.tar.gz "http://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.gz"; \
    if [ -n "${GDB_SHA256}" ]; then echo "${GDB_SHA256}  gdb.tar.gz" | sha256sum -c -; fi; \
    tar -xf gdb.tar.gz && rm gdb.tar.gz && \
    cd gdb-${GDB_VERSION} && mkdir build && cd build && \
    ../configure --prefix=/usr/local --disable-werror && \
    make -j"$(nproc)" && make install-strip

# Final stage
FROM ubuntu:22.04

LABEL org.opencontainers.image.title="Ubuntu 22.04 C++ Toolchain (GCC)" \
      org.opencontainers.image.description="Toolchain GCC/CMake/Ninja/GDB optimisée" \
      org.opencontainers.image.vendor="Custom" \
      org.opencontainers.image.licenses="MIT"

SHELL ["/bin/bash","-o","pipefail","-c"]

ENV DEBIAN_FRONTEND=noninteractive
ARG GCC_VERSION=11
ARG CMAKE_VERSION=3.31.6
ARG NINJA_VERSION=v1.12.1
ARG CCACHE_VERSION=4.10.2
ARG FIXUID_VERSION=0.6.0
ARG CMAKE_SHA256=""
ARG NINJA_SHA256=""
ARG CCACHE_SHA256=""
ARG FIXUID_SHA256=""

# Base packages (runtime + general build)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    git \
    python3 \
    python3-distutils \
    pkg-config \
    zip \
    curl \
    libmpfr-dev libgmp3-dev libmpc-dev \
    libssl-dev \
    unzip \
    ca-certificates \
    lsb-release software-properties-common gnupg \
    uuid-dev \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN addgroup --gid 1000 docker && \
    adduser --uid 1000 --ingroup docker --home /home/docker --shell /bin/sh --disabled-password --gecos "" docker

# Install CMake binary + optional SHA check
RUN set -euo pipefail; \
    curl -fsSLo cmake.tar.gz "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz"; \
    if [ -n "${CMAKE_SHA256}" ]; then echo "${CMAKE_SHA256}  cmake.tar.gz" | sha256sum -c -; fi; \
    tar -xzf cmake.tar.gz -C /usr/local --strip-components=1; \
    rm cmake.tar.gz

# Ninja
RUN set -euo pipefail; \
    curl -fsSLo ninja-linux.zip "https://github.com/ninja-build/ninja/releases/download/${NINJA_VERSION}/ninja-linux.zip"; \
    if [ -n "${NINJA_SHA256}" ]; then echo "${NINJA_SHA256}  ninja-linux.zip" | sha256sum -c -; fi; \
    unzip ninja-linux.zip -d /usr/local/bin/; \
    rm ninja-linux.zip

# GCC via Toolchain PPA (for newer versions on 22.04)
RUN set -euo pipefail; \
    add-apt-repository -y ppa:ubuntu-toolchain-r/test; \
    apt-get update; \
    apt-get install -y gcc-${GCC_VERSION} g++-${GCC_VERSION} cpp-${GCC_VERSION}; \
    rm -rf /var/lib/apt/lists/*

# ccache
RUN set -euo pipefail; \
    curl -fsSLo ccache.tar.xz "https://github.com/ccache/ccache/releases/download/v${CCACHE_VERSION}/ccache-${CCACHE_VERSION}-linux-x86_64.tar.xz"; \
    if [ -n "${CCACHE_SHA256}" ]; then echo "${CCACHE_SHA256}  ccache.tar.xz" | sha256sum -c -; fi; \
    tar -xf ccache.tar.xz -C /usr/local/bin --strip-components=1; \
    rm ccache.tar.xz; \
    update-alternatives --install /usr/bin/ccache ccache /usr/local/bin/ccache 100

# GDB from builder stage
COPY --from=gdb-builder /usr/local/ /usr/local/
RUN update-alternatives --install /usr/bin/gdb gdb /usr/local/bin/gdb 100

# Alternatives for GCC and tools
RUN update-alternatives --install /usr/local/bin/cc cc /usr/bin/gcc-${GCC_VERSION} 100 && \
    update-alternatives --install /usr/local/bin/c++ c++ /usr/bin/g++-${GCC_VERSION} 100 && \
    update-alternatives --install /usr/local/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 100 && \
    update-alternatives --install /usr/local/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} 100 && \
    update-alternatives --install /usr/local/bin/cpp cpp /usr/bin/cpp-${GCC_VERSION} 100 && \
    update-alternatives --install /usr/bin/cmake cmake /usr/local/bin/cmake 100 && \
    update-alternatives --install /usr/bin/ninja ninja /usr/local/bin/ninja 100

# fixuid
RUN set -euo pipefail; \
    curl -fsSLo fixuid.tar.gz https://github.com/boxboat/fixuid/releases/download/v${FIXUID_VERSION}/fixuid-${FIXUID_VERSION}-linux-amd64.tar.gz; \
    if [ -n "${FIXUID_SHA256}" ]; then echo "${FIXUID_SHA256}  fixuid.tar.gz" | sha256sum -c -; fi; \
    tar -C /usr/local/bin -xzf fixuid.tar.gz; \
    rm fixuid.tar.gz; \
    chown root:root /usr/local/bin/fixuid; \
    chmod 4755 /usr/local/bin/fixuid; \
    mkdir -p /etc/fixuid; \
    printf "user: docker\ngroup: docker\n" > /etc/fixuid/config.yml

# pip
RUN curl -fsSLo get-pip.py https://bootstrap.pypa.io/get-pip.py && python3 get-pip.py && rm get-pip.py

# Basic Python libs
RUN python3 -m pip install --no-cache-dir --upgrade pip && \
    python3 -m pip install --no-cache-dir numpy pytest && \
    python3 -m pip install --no-cache-dir gcovr

# Cache & workspace
RUN mkdir /work /.cache && chown -R docker:docker /.cache && chmod -R 777 /.cache
WORKDIR /work

USER docker

ENV PATH="/usr/local/bin:$PATH" \
    CC=gcc CXX=g++

# Image ready
