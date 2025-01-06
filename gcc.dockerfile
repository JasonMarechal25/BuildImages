FROM ubuntu:20.04

# Set environment variables to avoid tzdata interactive dialog
ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-c"]

ENV CLANG_VERSION=17.0.1
ENV GCC_VERSION=14.1.0
ENV CMAKE_VERSION=3.28.2
ENV NINJA_VERSION=v1.12.1

# Update the system and install necessary packages
RUN apt update
RUN apt update --fix-missing
RUN apt install -y --no-install-recommends --no-install-suggests \
    build-essential \
    wget \
    git \
    cmake \
    python3 \
    gdb \
    pkg-config \
    zip \
    libmpfr-dev libgmp3-dev libmpc-dev \
    libssl-dev \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Build gcc
RUN wget --no-check-certificate http://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz && \
    tar -xvf gcc-${GCC_VERSION}.tar.gz  && \
    pushd gcc-${GCC_VERSION} && \
    mkdir build && \
    pushd build && \
    ../configure -v \
      --build=x86_64-linux-gnu \
      --host=x86_64-linux-gnu \
      --target=x86_64-linux-gnu \
      --prefix=/usr/local/gcc-${GCC_VERSION} \
      --enable-checking=release \
      --enable-languages=c,c++ \
      --disable-multilib \
      --disable-bootstrap \
      --disable-nls \
      --disable-werror \
      --program-suffix=-${GCC_VERSION} && \
    make -s -j$(nproc) && \
    make -j$(nproc) install-strip && \
    popd && \
    popd && \
    rm gcc-${GCC_VERSION}.tar.gz && \
    rm -rf gcc-${GCC_VERSION}

RUN update-alternatives --install /usr/bin/gcov gcov /usr/local/gcc-${GCC_VERSION}/bin/gcov-${GCC_VERSION} 100 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/local/gcc-${GCC_VERSION}/bin/gcc-${GCC_VERSION} 10 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/local/gcc-${GCC_VERSION}/bin/g++-${GCC_VERSION} 10 && \
    update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 30 && \
    update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 30 && \
    update-alternatives --set cc /usr/bin/gcc && \
    update-alternatives --set c++ /usr/bin/g++

# Set the working directory
WORKDIR /root