#!/bin/bash

. ./common.sh

set -e
set -x

#x264的头文件地址
INC=""

#x264的静态库地址
LIB=""

X264_SOURCE="$WORKING_DIR/x264"
X264_OUTPUT="$WORKING_DIR/output/x264/linux$CPU"
X264_CACHE="$WORKING_DIR/cache/x264/linux$CPU"

FFMPEG_SOURCE="$WORKING_DIR/ffmpeg"
FFMPEG_OUTPUT="$WORKING_DIR/output/ffmpeg/linux$CPU"
FFMPEG_CACHE="$WORKING_DIR/cache/ffmpeg/linux$CPU"

FFMPEG_ARGS="--disable-doc --disable-ffplay --disable-ffprobe --disable-ffmpeg --disable-shared --enable-static --enable-optimizations"

TOOLCHAIN="/c/UnrealToolchains/v17_clang-10.0.1-centos7/x86_64-unknown-linux-gnu"
export PATH="$PATH:${TOOLCHAIN}/bin"

# export CROSS_PREFIX=${TOOLCHAIN}bin/
# export HOST=x86_64-linux
# export CC=${CROSS_PREFIX}clang.exe
# export CXX=${CROSS_PREFIX}clang++.exe


export CROSS_PREFIX=${TOOLCHAIN}/bin/x86_64-unknown-linux-gnu-
export HOST=x86_64-unknown-linux-gnu
# export CC=${CROSS_PREFIX}clang.exe
# export CXX=${CROSS_PREFIX}clang++.exe
# export CC=${TOOLCHAIN}bin/clang.exe
# export CXX=${TOOLCHAIN}bin/clang++.exe
# export AR=${TOOLCHAIN}bin/llvm-ar.exe
# export AS=${TOOLCHAIN}bin/x86_64-unknown-linux-gnu-as.exe
# export LD=${TOOLCHAIN}bin/ld.lld.exe
# export LLD=${TOOLCHAIN}bin/ld.lld.exe
export SYSROOT=${TOOLCHAIN}

if [ -r "$X264_SOURCE" ]; then
    mkdir -p $X264_CACHE
    cd $X264_CACHE

    rm -rf $X264_OUTPUT

    # LD=${TOOLCHAIN}bin/lld.exe \
    #     LLD=${TOOLCHAIN}bin/lld.exe \
    #     CC=${TOOLCHAIN}bin/clang.exe \
    #     CXX=${TOOLCHAIN}bin/clang++.exe \
    TMPDIR="${TMPDIR/%\//}" $X264_SOURCE/configure \
        --prefix=$X264_OUTPUT \
        --disable-asm \
        --enable-static \
        --enable-pic \
        --disable-cli \
        --host=$HOST \
        --cross-prefix=$CROSS_PREFIX \
        --sysroot=$SYSROOT

    make clean
    make -j16
    make install

    INC="$INC -I$X264_OUTPUT/include"
    LIB="$LIB -L$X264_OUTPUT/lib"

    FFMPEG_ARGS="$FFMPEG_ARGS --enable-gpl --enable-libx264"
    export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$$X264_OUTPUT/lib/pkgconfig"
    cd $WORKING_DIR
    echo ">>>>>>编译完成 x264!<<<<<<"
fi

if [ -r "$FFMPEG_SOURCE" ]; then
    # 先切分支
    # cd $FFMPEG_SOURCE
    # if [ $(git status -s | wc -l) -gt 0 ]; then
    #     git stash
    # fi
    # git checkout $BRANCH

    rm -rf $FFMPEG_OUTPUT

    # 开始编译
    mkdir -p $FFMPEG_CACHE
    cd $FFMPEG_CACHE
    TMPDIR="${TMPDIR/%\//}" $FFMPEG_SOURCE/configure $FFMPEG_ARGS \
        --prefix=$FFMPEG_OUTPUT \
        --enable-x86asm \
        --extra-cflags="$INC" \
        --extra-ldflags="$LIB" \
        --cross-prefix=$CROSS_PREFIX \
        --target-os=linux \
        --arch=x86_64 \
        --cpu=x86_64 \
        --enable-cross-compile \
        --sysroot=$SYSROOT

    make clean
    make -j4
    make install
    cd $WORKING_DIR
    echo ">>>>>>编译完成 ffmpeg !<<<<<<"
fi

FINAL_OUTPUT="$WORKING_DIR/output/dest/linux$CPU"

rm -rf $FINAL_OUTPUT
mkdir -p $FINAL_OUTPUT

if [ -r $FFMPEG_OUTPUT ]; then
    cp -r $FFMPEG_OUTPUT/* $FINAL_OUTPUT
fi

if [ -r $X264_OUTPUT ]; then
    cp -r $X264_OUTPUT/* $FINAL_OUTPUT
fi
