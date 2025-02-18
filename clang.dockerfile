FROM ubuntu:20.04

# Set environment variables to avoid tzdata interactive dialog
ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-c"]

ENV CLANG_VERSION=19.1.7
#Max supported version of CMake by CLion
ENV CMAKE_VERSION=3.28.6
ENV NINJA_VERSION=v1.12.1
#Max supported version of gdb by CLion
ENV GDB_VERSION=14.1

RUN addgroup --gid 1000 docker && \
    adduser --uid 1000 --ingroup docker --home /home/docker --shell /bin/sh --disabled-password --gecos "" docker

# Update the system and install necessary packages
RUN apt update
RUN apt update --fix-missing
#install clang and lld-10 to speed up the build over default ld
#curl and ca-certificates to be able to use vcpkg
#texinfo required for GDB 14 (not anymore for 16.x I think)
RUN apt install -y --no-install-recommends --no-install-suggests \
    build-essential \
    wget \
    git \
    python3 \
    pkg-config \
    zip \
    curl \
    libmpfr-dev libgmp3-dev libmpc-dev \
    libssl-dev \
    unzip \
    ca-certificates \
    texinfo \
    lld \
    && rm -rf /var/lib/apt/lists/*

#Cmake
RUN wget --no-check-certificate https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz \
    && tar xvf cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz -C /usr/local --strip-components=1\
    && rm cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz

RUN wget --no-check-certificate https://github.com/ninja-build/ninja/releases/download/${NINJA_VERSION}/ninja-linux.zip && \
    unzip ninja-linux.zip -d /usr/local/bin/ && \
    rm ninja-linux.zip

# Build Clang
RUN wget -q --no-check-certificate https://github.com/llvm/llvm-project/archive/llvmorg-${CLANG_VERSION}.tar.gz && \
    tar zxf llvmorg-${CLANG_VERSION}.tar.gz && \
    rm llvmorg-${CLANG_VERSION}.tar.gz && \
    pushd llvm-project-llvmorg-${CLANG_VERSION} && \
    mkdir build

RUN  pushd llvm-project-llvmorg-${CLANG_VERSION} \
        && cmake -G Ninja \
        -S llvm \
        -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_ENABLE_PROJECTS="clang;lld;lldb" \
        -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind;compiler-rt" \
        -DLLVM_TARGETS_TO_BUILD=host \
        -DLLVM_ENABLE_LLD=ON \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_INSTALL_PREFIX=/tmp/install \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_DOCS=OFF \
        -DLLVM_INCLUDE_TOOLS=ON \
        -DLLVM_INCLUDE_UTILS=OFF \
        -DLLVM_INCLUDE_BENCHMARKS=OFF \
        -DLLVM_ENABLE_OCAMLDOC=OFF \
        -DLLVM_ENABLE_BACKTRACES=OFF \
        -DLLVM_ENABLE_WARNINGS=OFF \
        -DLLVM_ENABLE_PEDANTIC=OFF \
        -DLLVM_ENABLE_ASSERTIONS=OFF \
        -DLLVM_BUILD_DOCS=OFF \
        -DLLVM_BUILD_TESTS=OFF \
        -DLLVM_BUILD_32_BITS=OFF \
        -DLLVM_BUILD_TOOLS=ON \
        -DLLVM_BUILD_UTILS=OFF \
        -DLLVM_BUILD_EXAMPLES=OFF \
        -DLLVM_BUILD_BENCHMARKS=OFF \
        -DLLVM_BUILD_STATIC=OFF \
        -DLLVM_USE_SANITIZER=OFF \
        -DLLVM_OPTIMIZED_TABLEGEN=ON \
        -DCLANG_INCLUDE_TESTS=OFF \
        -DCLANG_ENABLE_ARCMT=OFF \
        -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
        -DCLANG_INCLUDE_DOCS=OFF \
        -DCLANG_BUILD_EXAMPLES=OFF \
        -DCLANG_ENABLE_BOOTSTRAP=OFF \
        -DCLANG_DEFAULT_RTLIB=compiler-rt \
        -DCLANG_DEFAULT_UNWINDLIB="libunwind" \
        -DCOMPILER_RT_INCLUDE_TESTS=OFF \
        -DENABLE_LINKER_BUILD_ID=ON \
        -DCLANG_DEFAULT_CXX_STDLIB=libc++

RUN     pushd llvm-project-llvmorg-${CLANG_VERSION} \
        && ninja -C build all

RUN pushd llvm-project-llvmorg-${CLANG_VERSION}/build && \
    ninja install

RUN pushd llvm-project-llvmorg-${CLANG_VERSION}/build \
    && ls -la lib/clang \
    && MAJOR_CLANG_VERSION=${CLANG_VERSION%%.*} \
    && cp -a lib/clang/${MAJOR_CLANG_VERSION}/include /tmp/install/lib/clang/${MAJOR_CLANG_VERSION}/include \
    && cp $(find lib -name "*.so*") /tmp/install/lib \
    && popd
#    && rm -rf llvm-project-llvmorg-${CLANG_VERSION}

RUN cp -a /tmp/install/bin/* /usr/local/bin/ \
    && cp -a /tmp/install/lib/* /usr/local/lib/ \
    && cp -a /tmp/install/include/* /usr/local/include/ \
    && rm -rf /tmp/install \
    && update-alternatives --install /usr/local/bin/cc cc /usr/local/bin/clang 100 \
    && update-alternatives --install /usr/local/bin/cpp ccp /usr/local/bin/clang++ 100 \
    && update-alternatives --install /usr/local/bin/c++ c++ /usr/local/bin/clang++ 100 \
    && update-alternatives --install /usr/local/bin/ld ld /usr/local/bin/ld.lld 100 \
    && rm /etc/ld.so.cache \
    && ldconfig -C /etc/ld.so.cache \
    && update-alternatives --install /usr/bin/cmake cmake /usr/local/bin/cmake 100 \
    && update-alternatives --install /usr/bin/ninja ninja /usr/local/bin/ninja 100

RUN CXX=/usr/bin/clang && CC=/usr/bin/clang && \
    wget "http://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.gz" && \
    tar -xvf gdb-${GDB_VERSION}.tar.gz && \
    pushd gdb-${GDB_VERSION} && \
    mkdir build && \
    pushd build && \
    ../configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install-strip && \
    popd && \
    popd && \
    rm gdb-${GDB_VERSION}.tar.gz && \
    rm -rf gdb-${GDB_VERSION} && \
    update-alternatives --install /usr/bin/gdb gdb /usr/local/bin/gdb 100 \
    && apt remove texinfo -y

RUN chmod 777 /usr/bin/gdb /usr/local/bin/gdb

#https://github.com/boxboat/fixuid
RUN USER=docker && \
    GROUP=docker && \
    curl -SsL https://github.com/boxboat/fixuid/releases/download/v0.6.0/fixuid-0.6.0-linux-amd64.tar.gz | tar -C /usr/local/bin -xzf - && \
    chown root:root /usr/local/bin/fixuid && \
    chmod 4755 /usr/local/bin/fixuid && \
    mkdir -p /etc/fixuid && \
    printf "user: $USER\ngroup: $GROUP\n" > /etc/fixuid/config.yml

# Set the working directory
WORKDIR /root

USER root
