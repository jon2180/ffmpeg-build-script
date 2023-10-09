#!/bin/bash

. ./common.sh

# 以下路径需要修改成自己的NDK目录
TOOLCHAIN=/Users/feishu/Library/Android/sdk/ndk/21.4.7075529/toolchains/llvm/prebuilt/darwin-x86_64
# 最低支持的android sdk版本
API=23
export ANDROID_NDK=/Users/feishu/Library/Android/sdk/ndk/21.4.7075529
export NDK=$ANDROID_NDK

# export HOST_TAG=linux-x86_64
# export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/$HOST_TAG

#x264的头文件地址
INC=""

#x264的静态库地址
LIB=""

function build_x264 {
    #C、C++编译器
    # export CC=$TOOLCHAIN/bin/armv7a-linux-androideabi21-clang    # c compiler path
    # export CXX=$TOOLCHAIN/bin/armv7a-linux-androideabi21-clang++ # c++ compiler path
    echo Android ndk: $ANDROID_NDK
    echo Current C compiler: $CC
    echo Current C++ compiler: $CXX

    #编译结果存放目录
    PREFIX_x264=$WORKING_DIR/output/android/$CPU
    #如果你需要的是动态库，--enable-static 改为 --enable-shared
    # --enable-static \
    #     --disable-asm \
    # --disable-opencl \
    # --host=arm-linux \
    # --host=x86_64-darwin
    echo ">>>>>>>>开始编译<<<<<<<<<<"
    RET=0
    cd $WORKING_DIR/x264 &&
        ./configure \
            --prefix=$PREFIX_x264 \
            --disable-asm \
            --enable-shared \
            --enable-static \
            --enable-pic \
            --disable-cli \
            --host=$HOST \
            --cross-prefix=$CROSS_PREFIX \
            --sysroot=$SYSROOT &&
        make clean &&
        make &&
        make install &&
        echo ">>>>>>编译完成!<<<<<<" &&
        RET=$?
    cd $WORKING_DIR
    INC="$INC -I$PREFIX_x264/include"
    LIB="$LIB -L$PREFIX_x264/lib"
    return $RET

    # 调用同级目录下的configure文件
    # 指定输出目录
    # 各种配置项，想详细了解的可以打开configure文件找到Help options:查看
    # ./configure \
    #     --prefix=$PREFIX \
    #     --disable-neon \
    #     --disable-hwaccels \
    #     --disable-gpl \
    #     --disable-postproc \
    #     --enable-shared \
    #     --enable-jni \
    #     --disable-mediacodec \
    #     --disable-decoder=h264_mediacodec \
    #     --disable-static \
    #     --disable-doc \
    #     --disable-ffmpeg \
    #     --disable-ffplay \
    #     --disable-ffprobe \
    #     --disable-avdevice \
    #     --disable-doc \
    #     --disable-symver \
    #     --cross-prefix=$CROSS_PREFIX \
    #     --target-os=android \
    #     --arch=$ARCH \
    #     --cpu=$CPU \
    #     --cc=$CC \
    #     --cxx=$CXX \
    #     --enable-cross-compile \
    #     --sysroot=$SYSROOT \
    #     --extra-cflags="-Os -fpic $OPTIMIZE_CFLAGS" \
    #     --extra-ldflags="$ADDI_LDFLAGS" \
    #     $ADDITIONAL_CONFIGURE_FLAG
}

function build_android {
    # 打印
    echo "Compiling FFmpeg for $CPU"
    # 调用同级目录下的configure文件
    # 指定输出目录
    # 各种配置项，想详细了解的可以打开configure文件找到Help options:查看
    # 和 common 重复
    # --enable-shared \
    # --disable-static \
    # --disable-doc \
    # --disable-ffmpeg \
    # --disable-ffplay \
    # --disable-ffprobe \
    # --disable-doc \
    # --disable-gpl \

    # 临时禁用
    # --disable-neon \
    # --disable-hwaccels \
    # --disable-postproc \
    # --disable-mediacodec \
    # --disable-decoder=h264_mediacodec \
    # --disable-avdevice \
    # --disable-symver \

    echo Include directory: $INC
    echo Include library: $LIB

    cd $WORKING_DIR/ffmpeg &&
        git stash &&
        git checkout $BRANCH &&
        ./configure $COMMON_ARGS \
            --prefix=$PREFIX \
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
            $ADDITIONAL_CONFIGURE_FLAG &&
        make clean &&
        make &&
        make install &&
        echo "The Compilation of FFmpeg for $CPU is completed" &&
        cd $WORKING_DIR
    return $?
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
# NDK头文件环境
SYSROOT=$TOOLCHAIN/sysroot
CROSS_PREFIX=$TOOLCHAIN/bin/aarch64-linux-android-
# so输出路径
PREFIX=$WORKING_DIR/output/android/$CPU
OPTIMIZE_CFLAGS="-march=$CPU"
build_x264 && build_android

# CPU架构
#armv7-a
ARCH=arm
CPU=armv7-a
export HOST=armv7a-linux-androideabi
export CC=$TOOLCHAIN/bin/armv7a-linux-androideabi$API-clang
export CXX=$TOOLCHAIN/bin/armv7a-linux-androideabi$API-clang++
SYSROOT=$TOOLCHAIN/sysroot
CROSS_PREFIX=$TOOLCHAIN/bin/arm-linux-androideabi-
PREFIX=$WORKING_DIR/output/android/$CPU
OPTIMIZE_CFLAGS="-mfloat-abi=softfp -mfpu=vfp -marm -march=$CPU "
build_x264 && build_android

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
