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
#install clang and lld-10 to speed up the build over default ld
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
    clang-10 lld-10 libc++-10-dev \
    && rm -rf /var/lib/apt/lists/*

#Cmake
RUN wget --no-check-certificate https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz && \
    tar -xvf cmake-${CMAKE_VERSION}.tar.gz && \
    pushd cmake-${CMAKE_VERSION} && \
    ./bootstrap && \
    make -j$(nproc) && \
    make install && \
    popd && \
    rm -rf cmake-${CMAKE_VERSION} && \
    rm cmake-${CMAKE_VERSION}.tar.gz

RUN wget --no-check-certificate https://github.com/ninja-build/ninja/releases/download/${NINJA_VERSION}/ninja-linux.zip && \
    unzip ninja-linux.zip -d /usr/local/bin/ && \
    rm ninja-linux.zip

# Build Clang
RUN wget -q --no-check-certificate https://github.com/llvm/llvm-project/archive/llvmorg-${CLANG_VERSION}.tar.gz && \
    tar zxf llvmorg-${CLANG_VERSION}.tar.gz && \
    pushd llvm-project-llvmorg-${CLANG_VERSION} && \
    mkdir build && \
    pushd build && \
    cmake ../llvm \
        -G Ninja \
        -DCMAKE_CXX_COMPILER=clang++-10 \
        -DCMAKE_C_COMPILER=clang-10 \
        -DLLVM_USE_LINKER=lld-10 \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_ENABLE_PROJECTS=clang \
        -DLLVM_ENABLE_RUNTIMES=all \
        -DLLVM_TARGETS_TO_BUILD=X86 \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_INSTALL_PREFIX=/usr/local/clang \
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
        -DLLVM_ENABLE_PROJECTS="clang;libc;lld;compiler-rt" \
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
        -DLIBCXX_INCLUDE_TESTS=OFF \
        -DLIBCXX_ENABLE_SHARED=YES \
        -DLIBCXX_ENABLE_STATIC=OFF \
        -DLIBCXX_INCLUDE_BENCHMARKS=OFF \
        -DLIBCXX_INCLUDE_DOCS=OFF \
        -DLIBCXX_GENERATE_COVERAGE=OFF \
        -DLIBCXX_BUILD_32_BITS=OFF \
        -DLIBCXX_CXX_ABI=libcxxabi \
        -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
        -DLIBCXX_USE_COMPILER_RT=OFF \
        -DLIBCXX_DEBUG_BUILD=OFF \
        -DLIBCXX_CXX_ABI=libcxxabi \
        -DLIBCXX_CXX_ABI_INCLUDE_PATHS=../libcxxabi/include/ \
        -DLIBCXXABI_ENABLE_ASSERTIONS=OFF \
        -DLIBCXXABI_ENABLE_PEDANTIC=OFF \
        -DLIBCXXABI_BUILD_32_BITS=OFF \
        -DLIBCXXABI_INCLUDE_TESTS=OFF \
        -DLIBCXXABI_ENABLE_SHARED=ON \
        -DLIBCXXABI_ENABLE_STATIC=ON \
        -DLIBCXXABI_USE_COMPILER_RT=OFF \
        -DLIBCXXABI_USE_LLVM_UNWINDER=OFF \
        -DLIBCXXABI_ENABLE_STATIC_UNWINDER=OFF \
        -DLIBCXXABI_STATICALLY_LINK_UNWINDER_IN_SHARED_LIBRARY=OFF \
        -DLIBCXXABI_LIBUNWIND_INCLUDES_INTERNAL=OFF \
        -DCOMPILER_RT_INCLUDE_TESTS=OFF \
        -DCOMPILER_RT_USE_LIBCXX=ON \
        -DENABLE_LINKER_BUILD_ID=ON \
        && ninja cxxabi \
        && cp lib/libc++abi* /usr/lib/ \
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
        && ninja install-cxxabi \
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
    && cp -a lib/clang/${CLANG_VERSION}/include /usr/local/lib/clang/${CLANG_VERSION}/include \
    && cp $(find lib -name "*.so*") /usr/local/lib \
    popd && \
    popd && \
    rm -rf llvm-project-llvmorg-${CLANG_VERSION} && rm llvmorg-${CLANG_VERSION}.tar.gz

# Set the working directory
WORKDIR /root