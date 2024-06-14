FROM ubuntu:20.04

# Set environment variables to avoid tzdata interactive dialog
ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-c"]

ENV CLANG_VERSION=17.0.1
ENV GCC_VERSION=14.1.0
ENV CMAKE_VERSION=3.28.2
ENV NINJA_VERSION=v1.12.1

# Update the system and install necessary packages
RUN apt-get update
RUN apt-get update --fix-missing
RUN apt-get install -y \
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
    && rm -rf /var/lib/apt/lists/*

#Cmake
RUN wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz && \
    tar -xvf cmake-${CMAKE_VERSION}.tar.gz && \
    pushd cmake-${CMAKE_VERSION} && \
    ./bootstrap && \
    make -j$(nproc) && \
    make install && \
    popd && \
    rm -rf cmake-${CMAKE_VERSION} && \
    rm cmake-${CMAKE_VERSION}.tar.gz

# Build Clang
RUN git clone --depth=1 --branch llvmorg-${CLANG_VERSION} https://github.com/llvm/llvm-project.git && \
    pushd llvm-project && \
    mkdir build && \
    pushd build && \
    cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_PROJECTS=clang -DLLVM_ENABLE_RUNTIMES=all -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_ENABLE_ASSERTIONS=ON ../llvm && \
    make -j$(nproc) clang && \
    make -j$(nproc) install && \
    popd && \
    popd && \
    rm -rf llvm-project

# Build gcc
RUN wget http://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz && \
    tar -xvf gcc-${GCC_VERSION}.tar.gz  && \
    pushd gcc-${GCC_VERSION} && \
    ./contrib/download_prerequisites && \
    mkdir build && \
    pushd build && \
    ../configure -v --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu --prefix=/usr/local/gcc-${GCC_VERSION} --enable-checking=release --enable-languages=c,c++ --disable-multilib --program-suffix=-${GCC_VERSION} && \
    make -j$(nproc) && \
    make -j$(nproc) install && \
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

RUN wget https://github.com/ninja-build/ninja/releases/download/${NINJA_VERSION}/ninja-linux.zip && \
    unzip ninja-linux.zip -d /usr/local/bin/ && \
    rm ninja-linux.zip

# Set the working directory
WORKDIR /root