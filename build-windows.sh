#!/bin/bash

SOURCE=ffmpeg
BRANCH=release/4.4
WORKING_DIR=$(pwd)

echo "Current work directory $WORKING_DIR"

function install_deps {
    # $1 1 执行安装 0 跳过
    if [ $1 -gt 0 ]; then
        pacman -S diffutils make pkg-config automake autoconf libtool yasm nasm gcc
    fi
}

function prepare_build {
    X264_PREFIX="/usr/local/x264"
    cd $WORKING_DIR/x264 &&
        CC=cl ./configure --prefix=$X264_PREFIX --enable-shared &&
        make clean &&
        make -j 4 &&
        make install
    export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$X264_PREFIX/lib/pkgconfig"
    cd $WORKING_DIR
}

function build_windows {
    PREFIX="--prefix=/usr/local/ffmpeg"
    COMMON_ARGS="--enable-asm --enable-yasm --disable-doc --disable-ffplay --disable-ffprobe --disable-ffmpeg --enable-shared --disable-static --disable-bzlib --disable-libopenjpeg --disable-iconv --disable-zlib --enable-libx264 --enable-gpl --enable-optimizations"
    ARCH_ARGS="--arch=x86_64"
    TOOLCHAIN_ARGS="--toolchain=msvc"
    EXTRA_ARGS="--extra-cflags=-l/usr/local/x264/include --extra-ldflags=-L/usr/loca/x264/lib"
    echo "Compiling ffmpeg for windows_$CPU"
    echo "pkgconfig $PKG_CONFIG_PATH"
    # 调用同级目录下的configure文件
    # 指定输出目录
    # 各种配置项，想详细了解的可以打开configure文件找到Help options:查看
    cd $WORKING_DIR/$SOURCE &&
        git stash &&
        git checkout $BRANCH &&
        ./configure $COMMON_ARGS $PREFIX $TOOLCHAIN_ARGS $ARCH_ARGS $EXTRA_ARGS &&
        make clean &&
        make -j 4 &&
        make install &&
        echo "The compilation of ffmpeg for windows_$CPU is completed"
    cd $WORKING_DIR
}

install_deps 0
# prepare_build
build_windows
