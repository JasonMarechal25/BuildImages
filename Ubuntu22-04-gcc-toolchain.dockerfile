# syntax=docker/dockerfile:1
# Stage 0: bring in GDB files from a prebuilt image (use named stage to avoid ARG in COPY --from)
ARG GDB_IMAGE=gdb-builder:ubuntu22.04
FROM ${GDB_IMAGE} AS gdbstage

# Final stage
FROM ubuntu:22.04

LABEL org.opencontainers.image.title="Ubuntu 22.04 C++ Toolchain (GCC)" \
      org.opencontainers.image.description="Toolchain GCC/CMake/Ninja/GDB optimisée" \
      org.opencontainers.image.vendor="Custom" \
      org.opencontainers.image.licenses="MIT"

SHELL ["/bin/bash","-o","pipefail","-c"]

ENV DEBIAN_FRONTEND=noninteractive
ARG GCC_VERSION=15.2.0
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
    libmpfr-dev libgmp3-dev libmpc-dev libisl-dev zlib1g-dev \
    libssl-dev \
    unzip \
    ca-certificates \
    lsb-release software-properties-common gnupg \
    uuid-dev \
    xz-utils flex bison \
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

# Build GCC from source (apt repository not available)
RUN set -euo pipefail; \
    curl -fsSLo gcc.tar.xz "https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz"; \
    tar -xf gcc.tar.xz; \
    rm gcc.tar.xz; \
    pushd gcc-${GCC_VERSION}; \
    ./contrib/download_prerequisites || true; \
    mkdir build && cd build; \
    ../configure -v \
      --build=x86_64-linux-gnu \
      --host=x86_64-linux-gnu \
      --target=x86_64-linux-gnu \
      --prefix=/usr/local \
      --enable-checking=release \
      --enable-languages=c,c++ \
      --enable-linker-build-id \
      --disable-multilib \
      --disable-bootstrap \
      --disable-nls \
      --disable-werror; \
    make -j"$(nproc)"; \
    make install-strip; \
    popd; \
    rm -rf gcc-${GCC_VERSION}; \
    ldconfig

# ccache
RUN set -euo pipefail; \
    curl -fsSLo ccache.tar.xz "https://github.com/ccache/ccache/releases/download/v${CCACHE_VERSION}/ccache-${CCACHE_VERSION}-linux-x86_64.tar.xz"; \
    if [ -n "${CCACHE_SHA256}" ]; then echo "${CCACHE_SHA256}  ccache.tar.xz" | sha256sum -c -; fi; \
    tar -xf ccache.tar.xz -C /usr/local/bin --strip-components=1; \
    rm ccache.tar.xz; \
    update-alternatives --install /usr/bin/ccache ccache /usr/local/bin/ccache 100

# GDB from prebuilt image
COPY --from=gdbstage /usr/local/ /usr/local/
RUN update-alternatives --install /usr/bin/gdb gdb /usr/local/bin/gdb 100

# Alternatives for GCC and tools
RUN GCC_MAJOR_VERSION=${GCC_VERSION%%.*} && \
    ls -la /usr/local/bin/ && \
    /usr/local/bin/gcc --version && \
    update-alternatives --install /usr/bin/cc cc /usr/local/bin/gcc 100 && \
    update-alternatives --install /usr/bin/c++ c++ /usr/local/bin/g++ 100 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/local/bin/gcc 100 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/local/bin/g++ 100 && \
    update-alternatives --install /usr/bin/cpp cpp /usr/local/bin/cpp 100 && \
    update-alternatives --install /usr/bin/cmake cmake /usr/local/bin/cmake 100 && \
    update-alternatives --install /usr/bin/ninja ninja /usr/local/bin/ninja 100

RUN cc --version && \
    c++ --version && \
    gcc --version && \
    g++ --version && \
    cpp --version && \
    /usr/local/bin/gcc --version && \
    /usr/local/bin/g++ --version && \
    /usr/local/bin/cpp --version

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
