#!/bin/bash

set -x
set -e

. ./common.sh

# 以下路径需要修改成自己的NDK目录
TOOLCHAIN=/Users/feishu/Library/Android/sdk/ndk/21.4.7075529/toolchains/llvm/prebuilt/darwin-x86_64
# 最低支持的android sdk版本
API=23

export ANDROID_NDK=/Users/feishu/Library/Android/sdk/ndk/21.4.7075529
export NDK=$ANDROID_NDK

function build_android {
    #x264的头文件地址
    INC=""

    #x264的静态库地址
    LIB=""

    X264_SOURCE="$WORKING_DIR/x264"
    X264_OUTPUT="$WORKING_DIR/output/x264/android-$CPU"
    X264_CACHE="$WORKING_DIR/cache/x264/android-$CPU"

    if [ -r $X264_SOURCE ]; then
        echo ">>>>>>>>x264 开始编译<<<<<<<<<<"

        mkdir -p $X264_CACHE
        cd $X264_CACHE

        rm -rf $X264_OUTPUT

        $X264_SOURCE/configure \
            --prefix=$X264_OUTPUT \
            --disable-asm \
            --enable-shared \
            --enable-pic \
            --disable-cli \
            --host=$HOST \
            --cross-prefix=$CROSS_PREFIX \
            --sysroot=$SYSROOT
        make clean
        make
        make install
        echo ">>>>>>x264 编译完成!<<<<<<"

        # 导入库
        COMMON_ARGS="$COMMON_ARGS --enable-gpl --enable-libx264"
        INC="$INC -I$X264_OUTPUT/include"
        LIB="$LIB -L$X264_OUTPUT/lib"
    fi

    FFMPEG_SOURCE="$WORKING_DIR/ffmpeg"
    FFMPEG_OUTPUT="$WORKING_DIR/output/ffmpeg/android-$CPU"
    FFMPEG_CACHE="$WORKING_DIR/cache/ffmpeg/android-$CPU"

    if [ -r "$FFMPEG_SOURCE" ]; then
        # 打印
        echo "Compiling FFmpeg for $CPU"

        cd $FFMPEG_SOURCE
        if [ $(git status -s | wc -l) -gt 0 ]; then
            git stash
        fi
        git checkout $BRANCH

        # 开始编译
        mkdir -p $FFMPEG_CACHE
        cd $FFMPEG_CACHE

        rm -rf $FFMPEG_OUTPUT

        $FFMPEG_SOURCE/configure $COMMON_ARGS \
            --prefix=$FFMPEG_OUTPUT \
            --enable-jni \
            --cross-prefix=$CROSS_PREFIX \
            --target-os=android \
            --arch=$ARCH \
            --cpu=$CPU \
            --cc=$CC \
            --cxx=$CXX \
            --enable-cross-compile \
            --sysroot=$SYSROOT \
            --extra-cflags="-Os -fpic $OPTIMIZE_CFLAGS $INC" \
            --extra-ldflags="$ADDI_LDFLAGS $LIB" \
            $ADDITIONAL_CONFIGURE_FLAGs
        make clean
        make
        make install
        echo "The Compilation of FFmpeg for $CPU is completed"
    fi

    cd $WORKING_DIR
}

# 交叉编译工具目录,对应关系如下
# armv8a -> arm64 -> aarch64-linux-android-
# armv7a -> arm -> arm-linux-androideabi-
# x86 -> x86 -> i686-linux-android-
# x86_64 -> x86_64 -> x86_64-linux-android-

#armv8-a
ARCH=arm64
CPU=armv8-a
# # r21版本的ndk中所有的编译器都在/ndk/21.3.6528147/toolchains/llvm/prebuilt/darwin-x86_64/目录下（clang）
export HOST=aarch64-linux-android
export CC=$TOOLCHAIN/bin/aarch64-linux-android$API-clang
export CXX=$TOOLCHAIN/bin/aarch64-linux-android$API-clang++

echo Current C compiler: $CC
echo Current C++ compiler: $CXX

# NDK头文件环境
SYSROOT=$TOOLCHAIN/sysroot
CROSS_PREFIX=$TOOLCHAIN/bin/aarch64-linux-android-
# so输出路径
PREFIX=$WORKING_DIR/output/android/$CPU
OPTIMIZE_CFLAGS="-march=$CPU"
build_android

# CPU架构
#armv7-a
ARCH=arm
CPU=armv7-a
export HOST=armv7a-linux-androideabi
export CC=$TOOLCHAIN/bin/armv7a-linux-androideabi$API-clang
export CXX=$TOOLCHAIN/bin/armv7a-linux-androideabi$API-clang++

echo Current C compiler: $CC
echo Current C++ compiler: $CXX

SYSROOT=$TOOLCHAIN/sysroot
CROSS_PREFIX=$TOOLCHAIN/bin/arm-linux-androideabi-
PREFIX=$WORKING_DIR/output/android/$CPU
OPTIMIZE_CFLAGS="-mfloat-abi=softfp -mfpu=vfp -marm -march=$CPU "
build_android

#x86
# ARCH=x86
# CPU=x86
# CC=$TOOLCHAIN/bin/i686-linux-android$API-clang
# CXX=$TOOLCHAIN/bin/i686-linux-android$API-clang++
# SYSROOT=$TOOLCHAIN/sysroot
# CROSS_PREFIX=$TOOLCHAIN/bin/i686-linux-android-
# PREFIX=$(pwd)/android/$CPU
# OPTIMIZE_CFLAGS="-march=i686 -mtune=intel -mssse3 -mfpmath=sse -m32"
# build_android

#x86_64
# ARCH=x86_64
# CPU=x86-64
# CC=$TOOLCHAIN/bin/x86_64-linux-android$API-clang
# CXX=$TOOLCHAIN/bin/x86_64-linux-android$API-clang++
# SYSROOT=$TOOLCHAIN/sysroot
# CROSS_PREFIX=$TOOLCHAIN/bin/x86_64-linux-android-
# PREFIX=$(pwd)/android/$CPU
# OPTIMIZE_CFLAGS="-march=$CPU -msse4.2 -mpopcnt -m64 -mtune=intel"
# # 方法调用
# build_android
