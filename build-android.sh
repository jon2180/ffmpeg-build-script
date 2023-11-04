#!/bin/bash

set -x
set -e

. ./common.sh

# 以下路径需要修改成自己的NDK目录
TOOLCHAIN=/Users/feishu/Library/Android/sdk/ndk/21.4.7075529/toolchains/llvm/prebuilt/darwin-x86_64
# 最低支持的android sdk版本
API=21

export ANDROID_NDK=/Users/feishu/Library/Android/sdk/ndk/21.4.7075529
export NDK=$ANDROID_NDK

function build_android {
    # 启用 DEBUG ? 1 启用 空不启用
    ENABLE_DEBUG=0
    USE_STATIC=1
    # windows, linux, macos
    PLATFORM="$1"
    CPU="$2"
    # 编译线程数量，看 CPU 而定
    THREAD_COUNT=12

    # 参数 桌面端使用动态库
    X264_ARGS=""
    FDK_AAC_ARGS=""
    FFMPEG_ARGS="--disable-doc --disable-ffplay --disable-ffprobe --disable-ffmpeg"
    # minimize
    FFMPEG_ARGS="$FFMPEG_ARGS --disable-avdevice --disable-postproc --disable-everything --enable-encoder=aac --enable-encoder=libx264 --enable-muxer=h264 --enable-muxer=mp4 --enable-protocol=file --enable-protocol=rtmp --enable-filter=scale"
    # --disable-demuxers --disable-parsers --disable-decoders
    #  --disable-everything --enable-encoder=aac --enable-encoder=libx264 --enable-muxer=aac

    if [ $PLATFORM == "windows" ]; then
        FFMPEG_ARGS="$FFMPEG_ARGS --toolchain=msvc"
        CC=cl
        CXX=cl
        LD=link
    # else
    #     # CC=gcc
    #     # CXX=g++
    fi

    if [ $USE_STATIC -eq 1 ]; then
        X264_ARGS="$X264_ARGS --enable-static"
        FDK_AAC_ARGS="$FDK_AAC_ARGS --enable-static --disable-shared"
        FFMPEG_ARGS="$FFMPEG_ARGS --enable-static --disable-shared"
    else
        X264_ARGS="$X264_ARGS --enable-shared"
        FDK_AAC_ARGS="$FDK_AAC_ARGS --enable-shared --disable-static"
        FFMPEG_ARGS="$FFMPEG_ARGS --enable-shared --disable-static"
    fi

    if [ $ENABLE_DEBUG -eq 1 ]; then
        X264_ARGS="$X264_ARGS --enable-debug"
        FDK_AAC_ARGS="$FDK_AAC_ARGS --enable-debug"
        FFMPEG_ARGS="$FFMPEG_ARGS --enable-debug --disable-optimizations --disable-asm --disable-stripping"
        DEBUG_PATH_SUFFIX="debug"
    else
        X264_ARGS="$X264_ARGS --enable-strip"
        # --enable-lto
        FFMPEG_ARGS="$FFMPEG_ARGS --disable-debug --enable-optimizations"
        DEBUG_PATH_SUFFIX="release"
    fi

    #x264的头文件地址
    FFMPEG_INC=""

    #x264的静态库地址，不能缩写成 LIB，Win 下有这个同名的环境变量，会覆盖系统环境变量
    FFMPEG_LIB=""

    X264_SOURCE="$WORKING_DIR/x264"
    X264_OUTPUT="$WORKING_DIR/output/x264/${PLATFORM}-$CPU-${DEBUG_PATH_SUFFIX}"
    X264_CACHE="$WORKING_DIR/cache/x264/${PLATFORM}-$CPU"

    # COMMON_ARGS="--disable-doc --disable-ffplay --disable-ffprobe --disable-ffmpeg --disable-shared --enable-static"

    # #x264的头文件地址
    # INC=""

    # #x264的静态库地址
    # LIB=""

    # X264_SOURCE="$WORKING_DIR/x264"
    # X264_OUTPUT="$WORKING_DIR/output/x264/android-$CPU"
    # X264_CACHE="$WORKING_DIR/cache/x264/android-$CPU"

    if [ -n $X264_SOURCE -a -r "$X264_SOURCE" ]; then
        echo ">>>>>>>>x264 开始编译<<<<<<<<<<"

        mkdir -p $X264_CACHE
        cd $X264_CACHE

        rm -rf $X264_OUTPUT

        # $X264_SOURCE/configure \
        #     --prefix=$X264_OUTPUT \
        #     --disable-asm \
        #     --enable-debug \
        #     --enable-static \
        #     --disable-shared \
        #     --enable-pic \
        #     --disable-cli \
        #     --host=$HOST \
        #     --cross-prefix=$CROSS_PREFIX \
        #     --sysroot=$SYSROOT

        $X264_SOURCE/configure \
            --prefix=$X264_OUTPUT \
            --enable-asm \
            $X264_ARGS \
            --enable-pic \
            --disable-cli \
            --host=$HOST \
            --cross-prefix=$CROSS_PREFIX \
            --sysroot=$SYSROOT
        make clean
        make -j${THREAD_COUNT} # CPU 核心线程数，自己调一下
        make install
        echo ">>>>>>x264 编译完成!<<<<<<"

        # 导入库
        # COMMON_ARGS="$COMMON_ARGS --enable-gpl --enable-libx264"

        FFMPEG_INC="$FFMPEG_INC -I$X264_OUTPUT/include"
        FFMPEG_LIB="$FFMPEG_LIB -L$X264_OUTPUT/lib"

        FFMPEG_ARGS="$FFMPEG_ARGS --enable-gpl --enable-libx264"
        export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$$X264_OUTPUT/lib/pkgconfig"
    fi

    # FDK_AAC_SOURCE="$WORKING_DIR/fdk-aac-2.0.2"
    # FDK_AAC_OUTPUT="$WORKING_DIR/output/fdk-aac/android-$CPU"
    # FDK_AAC_CACHE="$WORKING_DIR/cache/fdk-aac/android-$CPU"

    # if [ -r $FDK_AAC_SOURCE ]; then
    #     echo "Compiling fdk-aac for $CPU"

    #     mkdir -p $FDK_AAC_CACHE
    #     cd $FDK_AAC_CACHE

    #     rm -rf $FDK_AAC_OUTPUT

    #     $FDK_AAC_SOURCE/configure \
    #         --enable-shared --disable-static --with-pic=yes \
    #         --prefix="$FDK_AAC_OUTPUT" \
    #         --host=$HOST \
    #         --with-sysroot="$SYSROOT" \
    #         --target=android --disable-asm \
    #         CC=$CC \
    #         CXX=$CXX

    #     make clean
    #     make -j8 install

    #     echo ">>>>>>>> fdk-aac 编译完成"

    #     COMMON_ARGS="$COMMON_ARGS --enable-nonfree --enable-libfdk-aac"
    #     INC="$INC -I$FDK_AAC_OUTPUT/include"
    #     LIB="$LIB -L$FDK_AAC_OUTPUT/lib"
    # fi

    FFMPEG_SOURCE="$WORKING_DIR/ffmpeg"
    FFMPEG_OUTPUT="$WORKING_DIR/output/ffmpeg/${PLATFORM}-$CPU-${DEBUG_PATH_SUFFIX}"
    FFMPEG_CACHE="$WORKING_DIR/cache/ffmpeg/${PLATFORM}-$CPU"

    if [ -n "$FFMPEG_SOURCE" -a -r "$FFMPEG_SOURCE" ]; then
        # 打印
        echo "Compiling FFmpeg for $CPU"

        # cd $FFMPEG_SOURCE
        # if [ $(git status -s | wc -l) -gt 0 ]; then
        #     git stash
        # fi
        # git checkout $BRANCH

        # 开始编译
        mkdir -p $FFMPEG_CACHE
        cd $FFMPEG_CACHE

        rm -rf $FFMPEG_OUTPUT

        # $FFMPEG_SOURCE/configure $COMMON_ARGS \
        #     --enable-debug --disable-optimizations --disable-asm --disable-stripping \
        #     --prefix=$FFMPEG_OUTPUT \
        #     --enable-jni \
        #     --cross-prefix=$CROSS_PREFIX \
        #     --target-os=android \
        #     --arch=$ARCH \
        #     --cpu=$CPU \
        #     --cc=$CC \
        #     --cxx=$CXX \
        #     --enable-cross-compile \
        #     --sysroot=$SYSROOT \
        #     --extra-cflags="-Os -fpic $OPTIMIZE_CFLAGS $INC" \
        #     --extra-ldflags="$ADDI_LDFLAGS $LIB" \
        #     $ADDITIONAL_CONFIGURE_FLAGs

        $FFMPEG_SOURCE/configure $FFMPEG_ARGS --prefix=$FFMPEG_OUTPUT \
            --enable-jni \
            --cross-prefix=$CROSS_PREFIX \
            --target-os=android \
            --arch=$ARCH \
            --cpu=$CPU \
            --cc=$CC \
            --cxx=$CXX \
            --enable-cross-compile \
            --sysroot=$SYSROOT \
            --extra-cflags="-Os -fpic $OPTIMIZE_CFLAGS $FFMPEG_INC" \
            --extra-ldflags="$ADDI_LDFLAGS $FFMPEG_LIB" \
            $ADDITIONAL_CONFIGURE_FLAGs
        make clean
        make -j${THREAD_COUNT} # CPU 核心线程数，自己调一下
        make install
        echo "The Compilation of FFmpeg for $CPU is completed"
    fi

    # MERGED_LIB_OUTPUT="$WORKING_DIR/output/dist/android-$CPU"

    # if [ "$MERGED_LIB_OUTPUT" ]; then

    #     rm -rf $MERGED_LIB_OUTPUT
    #     mkdir -p $MERGED_LIB_OUTPUT
    #     cp -r $FFMPEG_OUTPUT/* $MERGED_LIB_OUTPUT/

    #     if [ -r $X264_OUTPUT ]; then
    #         cp -r $X264_OUTPUT/* $MERGED_LIB_OUTPUT/
    #     fi

    #     # if [ -r $FDK_AAC_OUTPUT ]; then
    #     #     cp -r $FDK_AAC_OUTPUT/* $MERGED_LIB_OUTPUT/
    #     # fi

    # fi

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

export HOST=aarch64-linux-android
export CC="$TOOLCHAIN/bin/aarch64-linux-android$API-clang"
export CXX="$TOOLCHAIN/bin/aarch64-linux-android$API-clang++"

echo Current C compiler: $CC
echo Current C++ compiler: $CXX

# NDK头文件环境
SYSROOT=$TOOLCHAIN/sysroot
CROSS_PREFIX=$TOOLCHAIN/bin/aarch64-linux-android-
# so输出路径
PREFIX=$WORKING_DIR/output/android/$CPU
OPTIMIZE_CFLAGS="-march=$CPU"

# export AR="$TOOLCHAIN/bin/aarch64-linux-android$API-ar"
# export LD="$TOOLCHAIN/bin/aarch64-linux-android$API-ld"
# export AS="${CROSS_COMPILE}gcc"
build_android "android" $CPU

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
build_android "android" $CPU

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
