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
      --prefix=/tmp/install \
      --enable-checking=release \
      --enable-languages=c,c++ \
      --enable-linker-build-id \
      --disable-multilib \
      --disable-bootstrap \
      --disable-nls \
      --disable-werror && \
    make -s -j$(nproc) && \
    make -j$(nproc) install-strip && \
    popd && \
    popd && \
    rm gcc-${GCC_VERSION}.tar.gz && \
    rm -rf gcc-${GCC_VERSION}

RUN rm -rf /usr/lib/gcc/x86_64-linux-gnu/* \
    && cp -a /tmp/install/lib/gcc/x86_64-linux-gnu/${GCC_VERSION} /usr/lib/gcc/x86_64-linux-gnu/ \
    && cp -a /tmp/install/include/* /usr/local/include/ \
    && cp -a /tmp/install/lib64/ /usr/local/ \
    && cp -a /tmp/install/libexec/ /usr/local/ \
    && cp -a /tmp/install/lib/* /usr/local/lib/ \
    && cp -a /tmp/install/bin/* /usr/local/bin/ \
    && rm -rf /tmp/install \
    && update-alternatives --install /usr/local/bin/cc cc /usr/local/bin/gcc 100 \
    && rm /etc/ld.so.cache \
    && ldconfig -C /etc/ld.so.cache

RUN echo "export LD_LIBRARY_PATH=/usr/local/lib64/:$LD_LIBRARY_PATH">> ~/.bashrc

# Set the working directory
WORKDIR /root