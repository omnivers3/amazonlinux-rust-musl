# ----------------------------------------------------------------------------------------------------
# OMNIVERS3 AWS LAMBDA BUILDER FOR RUST MUSL
#
# - https://github.com/omnivers3/amazonlinux-rust-musl
#
# - Baseline from amazonlinux:latest to ensure maximum environment compatibility with AWS cloud
# - Add and configure OPENSSL
# - Add and configure MUSL build tools and configuration
#
# * Configurable, via ARG, to target any rust toolchain
# * Configurable, via ENV, to specify pathing options which are used in volumes
#
# ARGS
# - TOOLCHAIN=stable
# - OPENSSL_VERSION=1.1.1
#
# VOLUMES
# - ENV: BUILD_DIR=/build
# - ENV: EXPORT_DIR=/export
#
# ----------------------------------------------------------------------------------------------------

FROM amazonlinux:latest AS builder

# Setup Rust, Rustup, etc

# The Rust toolchain to use when building our image.  Set by `hooks/build`.
ARG TOOLCHAIN=stable

ENV RUST_BACKTRACE=1 \
    RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    CARGO_BIN=/usr/local/cargo/bin \
    PATH=/usr/local/cargo/bin:$PATH \
    BUILD_TARGET=x86_64-unknown-linux-musl

RUN mkdir -p "${CARGO_BIN}" \
    && curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain ${TOOLCHAIN} -y \
    && rustup target add ${BUILD_TARGET}

# Setup MUSL tools and config

ENV PREFIX=/musl \
    MUSL_VERSION=1.1.22

RUN mkdir -p "${PREFIX}"

RUN yum -y groupinstall "Development Tools"

WORKDIR ${PREFIX}

# Any dependencies that aren't part of your project, e.g. thrift compiler, will have to be layered on

# Build Musl
ADD http://www.musl-libc.org/releases/musl-$MUSL_VERSION.tar.gz .

RUN tar -xvzf musl-$MUSL_VERSION.tar.gz \
    && cd musl-${MUSL_VERSION} \
    && ./configure --prefix=${PREFIX} \
    && make install \
    && cd ..

# Set environment for musl
ENV CC=${PREFIX}/bin/musl-gcc \
    C_INCLUDE_PATH=${PREFIX}/include/ \
    CPPFLAGS=-I${PREFIX}/include \
    LDFLAGS=-L${PREFIX}/lib

# Build OpenSSL

# The OpenSSL version to use. We parameterize this because many Rust
# projects will fail to build with 1.1.
ARG OPENSSL_VERSION=1.1.1
# ARG OPENSSL_VERSION=1.0.2r

ADD https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz .

# Fix for "linux/mman.h: No such file or directory"
# https://github.com/openssl/openssl/issues/7207
# Added "-DOPENSSL_NO_SECURE_MEMORY" flag to "./Configure" line
# Should be remove ASAP because it weakens the security

RUN echo "Building OpenSSL" \
    && tar -xzf "openssl-${OPENSSL_VERSION}.tar.gz" \
    && cd openssl-${OPENSSL_VERSION} \
    && ./Configure no-async no-afalgeng no-shared no-zlib -fPIC --prefix=${PREFIX} --openssldir=${PREFIX}/ssl linux-x86_64 -DOPENSSL_NO_SECURE_MEMORY \
    # This is the desired command parameter set
    # && ./Configure no-async no-afalgeng no-shared no-zlib -fPIC --prefix=${PREFIX} --openssldir=${PREFIX}/ssl linux-x86_64 \
    && make depend \
    && make install

ENV OPENSSL_DIR=${PREFIX} \
    OPENSSL_STATIC=true

# Prep build environment conventions

# Add tools to the PATH
ENV BUILD_DIR=/build \
    OUTPUT_DIR=/output \
    PATH=${PATH}:/usr/local/cargo/env:/usr/local/ssl/bin

VOLUME [${BUILD_DIR}]

WORKDIR ${BUILD_DIR}

RUN mkdir -p "${BUILD_DIR}" \
 && mkdir -p "${OUTPUT_DIR}" \
 && mkdir .cargo

ADD cargo-config.toml .cargo/config

ENTRYPOINT ["/bin/sh"]
