# syntax=docker/dockerfile:1
FROM ubuntu:22.04 AS gdb-builder

ARG DEBIAN_FRONTEND=noninteractive
ARG GDB_VERSION=16.3
# Dépendances build GDB
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

# Étape finale
FROM ubuntu:22.04

LABEL org.opencontainers.image.title="Ubuntu 22.04 C++ Toolchain" \
      org.opencontainers.image.description="Toolchain Clang/CMake/Ninja/GDB optimisée" \
      org.opencontainers.image.vendor="Custom" \
      org.opencontainers.image.licenses="MIT"

SHELL ["/bin/bash","-o","pipefail","-c"]

ENV DEBIAN_FRONTEND=noninteractive
ARG CLANG_VERSION=20
ARG CMAKE_VERSION=3.31.6
ARG NINJA_VERSION=v1.12.1
ARG CCACHE_VERSION=4.10.2
ARG FIXUID_VERSION=0.6.0
ARG CMAKE_SHA256="" \
    NINJA_SHA256="" \
    CCACHE_SHA256="" \
    FIXUID_SHA256="" \
    LLVM_SH_SHA256=""

# Paquets de base (runtime + build général utilisateur)
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

# Utilisateur non-root
RUN addgroup --gid 1000 docker && \
    adduser --uid 1000 --ingroup docker --home /home/docker --shell /bin/sh --disabled-password --gecos "" docker

# Installer CMake binaire + vérif SHA optionnelle
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

# Clang / LLVM
RUN set -euo pipefail; \
    curl -fsSLo llvm.sh https://apt.llvm.org/llvm.sh; \
    if [ -n "${LLVM_SH_SHA256}" ]; then echo "${LLVM_SH_SHA256}  llvm.sh" | sha256sum -c -; fi; \
    chmod +x llvm.sh; \
    ./llvm.sh ${CLANG_VERSION}; \
    apt-get install -y clang-tools-${CLANG_VERSION} clang-format-${CLANG_VERSION} clangd-${CLANG_VERSION} clang-tidy-${CLANG_VERSION} && \
    rm -f llvm.sh && rm -rf /var/lib/apt/lists/*

# ccache
RUN set -euo pipefail; \
    curl -fsSLo ccache.tar.xz "https://github.com/ccache/ccache/releases/download/v${CCACHE_VERSION}/ccache-${CCACHE_VERSION}-linux-x86_64.tar.xz"; \
    if [ -n "${CCACHE_SHA256}" ]; then echo "${CCACHE_SHA256}  ccache.tar.xz" | sha256sum -c -; fi; \
    tar -xf ccache.tar.xz -C /usr/local/bin --strip-components=1; \
    rm ccache.tar.xz; \
    update-alternatives --install /usr/bin/ccache ccache /usr/local/bin/ccache 100

# GDB depuis l'étape builder
COPY --from=gdb-builder /usr/local/ /usr/local/
RUN update-alternatives --install /usr/bin/gdb gdb /usr/local/bin/gdb 100

# Alternatives Clang / outils
RUN update-alternatives --install /usr/local/bin/cc cc /usr/bin/clang-${CLANG_VERSION} 100 && \
    update-alternatives --install /usr/local/bin/c++ c++ /usr/bin/clang++-${CLANG_VERSION} 100 && \
    update-alternatives --install /usr/local/bin/clang clang /usr/bin/clang-${CLANG_VERSION} 100 && \
    update-alternatives --install /usr/local/bin/clang++ clang++ /usr/bin/clang++-${CLANG_VERSION} 100 && \
    update-alternatives --install /usr/local/bin/cpp cpp /usr/bin/clang-cpp-${CLANG_VERSION} 100 && \
    update-alternatives --install /usr/local/bin/clang-format clang-format /usr/bin/clang-format-${CLANG_VERSION} 100 && \
    update-alternatives --install /usr/local/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-${CLANG_VERSION} 100 && \
    update-alternatives --install /usr/local/bin/llvm-cov llvm-cov /usr/bin/llvm-cov-${CLANG_VERSION} 100 && \
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

# Python libs de base
RUN python3 -m pip install --no-cache-dir --upgrade pip && \
    python3 -m pip install --no-cache-dir numpy pytest

# Cache & workspace
RUN mkdir /work /.cache && chown -R docker:docker /.cache && chmod -R 777 /.cache
WORKDIR /work

USER docker

ENV PATH="/usr/local/bin:$PATH" \
    CC=clang CXX=clang++

# Image prête
