#!/bin/bash

set -e
set -x

CWD=$(pwd)

# 编译线程数量，看 CPU 而定
# export CORE_COUNT=$(sysctl -n hw.ncpu)
# NUMBER_OF_PROCESSORS 来自系统
export CORE_COUNT=$NUMBER_OF_PROCESSORS
# 启用 DEBUG ? 1 启用 空不启用
export DEBUG_ENABLE=0
export SYM_ENABLE=0
export STATIC_ENABLE=1
export DIR_CACHE_BASE="${CWD}/build"
# 实际的基础路径 ${DIR_DIST_BASE}${PLATFORM}
export DIR_DIST_BASE="${CWD}/installed-"

###################### macos start
# iOS or macos
export IOS_DEPLOYMENT_TARGET=13.0
export MACOS_DEPLOYMENT_TARGET=10.14
###################### macos end

###################### android start
# ndk
# 以下路径需要修改成自己的NDK目录
ANDROID_NDK_ROOT="/Users/daydream/Library/Android/sdk/ndk/21.4.7075529"
export ANDROID_NDK_TOOLCHAIN="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/darwin-x86_64"
# 最低支持的android sdk版本
export ANDROID_TARGET_API=21
###################### android end

# 参数 桌面端使用动态库
# source
X264_SOURCE="$CWD/sources/x264"
FDK_AAC_SOURCE="$CWD/sources/fdk-aac-2.0.2"
FFMPEG_SOURCE="$CWD/sources/ffmpeg-6.1.2"

function update_basic_args() {
    X264_BASIC_ARGS=""
    # fdk-aac 关于 debug，动静态等方面的基础配置
    FDK_AAC_BASIC_ARGS=""
    # ffmpeg 关于 debug，动静态等方面的基础配置
    FFMPEG_BASIC_ARGS=""
    DEBUG_PATH_SUFFIX=""

    if [ $STATIC_ENABLE -eq 1 ]; then
        X264_BASIC_ARGS="$X264_BASIC_ARGS --enable-static"
        FDK_AAC_BASIC_ARGS="$FDK_AAC_BASIC_ARGS --enable-static --disable-shared"
        FFMPEG_BASIC_ARGS="$FFMPEG_BASIC_ARGS --enable-static --disable-shared"
    else
        X264_BASIC_ARGS="$X264_BASIC_ARGS --enable-shared"
        FDK_AAC_BASIC_ARGS="$FDK_AAC_BASIC_ARGS --enable-shared --disable-static"
        FFMPEG_BASIC_ARGS="$FFMPEG_BASIC_ARGS --enable-shared --disable-static"
    fi

    if [ $DEBUG_ENABLE -eq 1 ]; then
        X264_BASIC_ARGS="$X264_BASIC_ARGS --enable-debug"
        FDK_AAC_BASIC_ARGS="$FDK_AAC_BASIC_ARGS --enable-debug"
        FFMPEG_BASIC_ARGS="$FFMPEG_BASIC_ARGS --enable-debug --disable-optimizations --disable-asm --disable-stripping"
        DEBUG_PATH_SUFFIX="debug"
    else
        X264_BASIC_ARGS="$X264_BASIC_ARGS --enable-strip"
        # --enable-lto
        FFMPEG_BASIC_ARGS="$FFMPEG_BASIC_ARGS --disable-debug --enable-optimizations --enable-stripping"
        DEBUG_PATH_SUFFIX="release"
    fi
}

update_basic_args

FFMPEG_MODULE_ARGS="--disable-doc \
    --disable-programs \
    --disable-ffplay --disable-ffprobe --disable-ffmpeg"

FFMPEG_MODULE_ARGS="$FFMPEG_MODULE_ARGS \
    --disable-avdevice --disable-postproc \
    --disable-everything \
    --enable-encoder=aac \
    --enable-encoder=libx264 \
    --enable-decoder=aac \
    --enable-decoder=h264 \
    --enable-demuxer=aac \
    --enable-demuxer=h264 \
    --enable-demuxer=mov \
    --enable-demuxer=m4v \
    --enable-demuxer=flv \
    --enable-muxer=h264 \
    --enable-muxer=mp4 \
    --enable-parser=aac \
    --enable-parser=h264 \
    --enable-protocol=file \
    --enable-protocol=rtmp \
    --enable-protocol=http \
    --enable-protocol=https \
    --enable-filter=scale"
