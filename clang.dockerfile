FROM ubuntu:20.04

# Set environment variables to avoid tzdata interactive dialog
ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-c"]

ENV CLANG_VERSION=19.1.7
ENV GCC_VERSION=14.1.0
ENV CMAKE_VERSION=3.28.6
ENV NINJA_VERSION=v1.12.1
ENV GDB_VERSION=16.2

# Update the system and install necessary packages
RUN apt update
RUN apt update --fix-missing
#install clang and lld-10 to speed up the build over default ld
RUN apt install -y --no-install-recommends --no-install-suggests \
    build-essential \
    wget \
    git \
    python3 \
    gdb \
    pkg-config \
    zip \
    libmpfr-dev libgmp3-dev libmpc-dev \
    libssl-dev \
    unzip \
    clang-10 lld-10 libc++-10-dev \
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
    pushd llvm-project-llvmorg-${CLANG_VERSION} && \
    mkdir build

RUN pushd llvm-project-llvmorg-${CLANG_VERSION}/build && \
    cmake ../llvm \
        -G Ninja \
        -DCMAKE_CXX_COMPILER=clang++-10 \
        -DCMAKE_C_COMPILER=clang-10 \
        -DLLVM_USE_LINKER=lld-10 \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_ENABLE_PROJECTS="clang;lld;compiler-rt;lldb" \
        -DLLVM_ENABLE_RUNTIMES=all \
        -DLLVM_TARGETS_TO_BUILD=X86 \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_INSTALL_PREFIX=/tmp/install \
        -DLLVM_ENABLE_ASSERTIONS=ON \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_GO_TESTS=OFF \
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
        -DCLANG_DEFAULT_RTLIB=libgcc \
        -DCLANG_DEFAULT_UNWINDLIB=libgcc \
        -DCOMPILER_RT_INCLUDE_TESTS=OFF \
        -DENABLE_LINKER_BUILD_ID=ON

RUN     pushd llvm-project-llvmorg-${CLANG_VERSION}/build && \
        ninja cxxabi \
        && ninja cxx \
        && ninja clang \
        && ninja lld \
        && ninja compiler-rt \
        && ninja llvm-cat \
                 llvm-cxxfilt \
                 llvm-dwp \
                 llvm-jitlink \
                 llvm-mc \
                 llvm-objdump \
                 llvm-readelf \
                 llvm-stress \
                 llvm-xray \
                 llvm-addr2line \
                 llvm-cfi-verify \
                 llvm-c-test \
                 llvm-cxxmap \
                 llvm-lib \
                 llvm-mca \
                 llvm-opt-report \
                 llvm-readobj \
                 llvm-strings \
                 llvm-ar \
                 llvm-config \
                 llvm-diff \
                 llvm-exegesis \
                 llvm-link \
                 llvm-modextract \
                 llvm-pdbutil \
                 llvm-reduce \
                 llvm-strip \
                 llvm-as \
                 llvm-cov \
                 llvm-dis \
                 llvm-extract \
                 llvm-lipo \
                 llvm-mt \
                 llvm-profdata \
                 llvm-rtdyld \
                 llvm-symbolizer \
                 llvm-bcanalyzer \
                 llvm-cvtres \
                 llvm-dlltool \
                 llvm-ifs \
                 llvm-lto \
                 llvm-nm \
                 llvm-ranlib \
                 llvm-size \
                 llvm-cxxdump \
                 llvm-dwarfdump \
                 llvm-install-name-tool \
                 llvm-lto2 \
                 llvm-objcopy \
                 llvm-rc \
                 llvm-split \
                 llvm-undname \
                 clang-scan-deps \
                 lldb lldb-server

RUN pushd llvm-project-llvmorg-${CLANG_VERSION}/build && \
    ninja install-cxxabi \
                 install-cxx \
                 install-clang \
                 install-lld \
                 install-compiler-rt \
                 install-llvm-cat \
                 install-llvm-cxxfilt \
                 install-llvm-dwp \
                 install-llvm-jitlink \
                 install-llvm-mc \
                 install-llvm-objdump \
                 install-llvm-readelf \
                 install-llvm-stress \
                 install-llvm-xray \
                 install-llvm-addr2line \
                 install-llvm-cfi-verify \
                 install-llvm-cxxmap \
                 install-llvm-lib \
                 install-llvm-mca \
                 install-llvm-opt-report \
                 install-llvm-readobj \
                 install-llvm-strings \
                 install-llvm-ar \
                 install-llvm-config \
                 install-llvm-diff \
                 install-llvm-exegesis \
                 install-llvm-link \
                 install-llvm-modextract \
                 install-llvm-pdbutil \
                 install-llvm-reduce \
                 install-llvm-strip \
                 install-llvm-as \
                 install-llvm-cov \
                 install-llvm-dis \
                 install-llvm-extract \
                 install-llvm-lipo \
                 install-llvm-mt \
                 install-llvm-profdata \
                 install-llvm-rtdyld \
                 install-llvm-symbolizer \
                 install-llvm-bcanalyzer \
                 install-llvm-cvtres \
                 install-llvm-dlltool \
                 install-llvm-ifs \
                 install-llvm-lto \
                 install-llvm-nm \
                 install-llvm-ranlib \
                 install-llvm-size \
                 install-llvm-cxxdump \
                 install-llvm-dwarfdump \
                 install-llvm-install-name-tool \
                 install-llvm-lto2 \
                 install-llvm-objcopy \
                 install-llvm-rc \
                 install-llvm-split \
                 install-llvm-undname \
                 install-clang-scan-deps \
                 install-lldb install-lldb-server

RUN pushd llvm-project-llvmorg-${CLANG_VERSION}/build \
    && ls -la lib/clang \
    && MAJOR_CLANG_VERSION=${CLANG_VERSION%%.*} \
    && cp -a lib/clang/${MAJOR_CLANG_VERSION}/include /tmp/install/lib/clang/${MAJOR_CLANG_VERSION}/include \
    && cp $(find lib -name "*.so*") /tmp/install/lib \
    && popd \
    && rm -rf llvm-project-llvmorg-${CLANG_VERSION} && rm llvmorg-${CLANG_VERSION}.tar.gz

RUN  wget "http://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.gz" && \
    tar -xvf gdb-${GDB_VERSION}.tar.gz && \
    pushd gdb-${GDB_VERSION} && \
    mkdir build && \
    pushd build && \
    ../configure --prefix=/tmp/install --with-python=python3 && \
    make -j$(nproc) && \
    make install-strip && \
    popd && \
    popd && \
    rm gdb-${GDB_VERSION}.tar.gz && \
    rm -rf gdb-${GDB_VERSION}

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
    && update-alternatives --install /usr/bin/ninja ninja /usr/local/bin/ninja 100 \
    && update-alternatives --install /usr/bin/gdb gdb /usr/local/bin/gdb 100


# Set the working directory
WORKDIR /root
