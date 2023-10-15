#!/bin/bash

. ./common.sh

set -e
set -x

# $1 ENABLE_DEBUG
function build_ffmpeg {
    # 启用 DEBUG ? 1 启用 空不启用
    ENABLE_DEBUG=1
    USE_STATIC=0
    # windows, linux, macos
    PLATFORM="$1"
    CPU="$2"
    # 编译线程数量，看 CPU 而定
    THREAD_COUNT=24

    # 参数 桌面端使用动态库
    X264_ARGS=""
    FDK_AAC_ARGS=""
    FFMPEG_ARGS="--arch=$CPU --disable-doc --disable-ffplay --disable-ffprobe --disable-ffmpeg"

    if [ $PLATFORM == "windows" ]; then
        FFMPEG_ARGS="$FFMPEG_ARGS --toolchain=msvc"
        CC=cl
        LD=link
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

    if [ $ENABLE_DEBUG ]; then
        X264_ARGS="$X264_ARGS --enable-debug"
        FDK_AAC_ARGS="$FDK_AAC_ARGS --enable-debug"
        FFMPEG_ARGS="$FFMPEG_ARGS --enable-debug --disable-optimizations --disable-asm --disable-stripping"
    else
        FFMPEG_ARGS="$FFMPEG_ARGS --enable-optimization"
    fi

    #x264的头文件地址
    FFMPEG_INC=""

    #x264的静态库地址，不能缩写成 LIB，Win 下有这个同名的环境变量，会覆盖系统环境变量
    FFMPEG_LIB=""

    X264_SOURCE="$WORKING_DIR/x264"
    X264_OUTPUT="$WORKING_DIR/output/x264/${PLATFORM}-$CPU"
    X264_CACHE="$WORKING_DIR/cache/x264/${PLATFORM}-$CPU"

    if [ -n $X264_SOURCE -a -r "$X264_SOURCE" ]; then
        mkdir -p $X264_CACHE
        cd $X264_CACHE
        echo "Building and installing libx264"

        rm -rf $X264_OUTPUT

        CC=$CC $X264_SOURCE/configure --prefix=$X264_OUTPUT $X264_ARGS --disable-cli
        # --disable-asm \
        # --enable-pic \
        make clean
        make -j${THREAD_COUNT}
        make install

        # 修正
        if [ -r "$X264_OUTPUT/lib/libx264.dll.lib" ]; then
            mv "$X264_OUTPUT/lib/libx264.dll.lib" "$X264_OUTPUT/lib/libx264.lib"
        fi

        FFMPEG_INC="$FFMPEG_INC -I$X264_OUTPUT/include"
        FFMPEG_LIB="$FFMPEG_LIB -L$X264_OUTPUT/lib"

        FFMPEG_ARGS="$FFMPEG_ARGS --enable-gpl --enable-libx264"
        export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$$X264_OUTPUT/lib/pkgconfig"
        cd $WORKING_DIR
        echo ">>>>>>编译完成 x264!<<<<<<"
    fi

    FDK_AAC_SOURCE="$WORKING_DIR/fdk-aac-2.0.2"
    FDK_AAC_OUTPUT="$WORKING_DIR/output/fdk-aac/${PLATFORM}-$CPU"
    FDK_AAC_CACHE="$WORKING_DIR/cache/fdk-aac/${PLATFORM}-$CPU"

    if [ -n $FDK_AAC_SOURCE -a -r $FDK_AAC_SOURCE ]; then
        echo "Compiling fdk-aac for $CPU"

        cd $FDK_AAC_SOURCE
        ./autogen.sh

        mkdir -p $FDK_AAC_CACHE
        cd $FDK_AAC_CACHE

        rm -rf $FDK_AAC_OUTPUT

        # CC="$CC" CXX="$CC" CPP="$CC -E" AS="$AS" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" CPPFLAGS="$CFLAGS"
        $FDK_AAC_SOURCE/configure --prefix="$FDK_AAC_OUTPUT" $FDK_AAC_ARGS --with-pic=yes

        # 交叉编译配置
        # --host=$HOST \
        # --cross-prefix=$CROSS_PREFIX \
        # --sysroot=$SYSROOT \

        make clean
        make -j${THREAD_COUNT} install

        # 修正 一般也就 windows 比较特殊
        if [ -r "$FDK_AAC_OUTPUT/lib/libfdk-aac.dll.a" ]; then
            mv "$FDK_AAC_OUTPUT/lib/libfdk-aac.dll.a" "$FDK_AAC_OUTPUT/lib/libfdk-aac.lib"
        fi

        echo ">>>>>>>> fdk-aac 编译完成"

        FFMPEG_ARGS="$FFMPEG_ARGS --enable-nonfree --enable-libfdk-aac"
        export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$$FDK_AAC_OUTPUT/lib/pkgconfig"
        FFMPEG_INC="$FFMPEG_INC -I$FDK_AAC_OUTPUT/include"
        FFMPEG_LIB="$FFMPEG_LIB -L$FDK_AAC_OUTPUT/lib"
    fi

    FFMPEG_SOURCE="$WORKING_DIR/ffmpeg"
    FFMPEG_OUTPUT="$WORKING_DIR/output/ffmpeg/${PLATFORM}-$CPU"
    FFMPEG_CACHE="$WORKING_DIR/cache/ffmpeg/${PLATFORM}-$CPU"

    if [ -n "$FFMPEG_SOURCE" -a -r "$FFMPEG_SOURCE" ]; then
        # 先切分支
        cd $FFMPEG_SOURCE
        # 有调试需要，会恢复代码修改
        # if [ $(git status -s | wc -l) -gt 0 ]; then
        #     git stash
        # fi
        git checkout $BRANCH

        echo "Building add installing ffmpeg"

        rm -rf $FFMPEG_OUTPUT

        # 开始编译
        mkdir -p $FFMPEG_CACHE
        cd $FFMPEG_CACHE
        $FFMPEG_SOURCE/configure $FFMPEG_ARGS --prefix=$FFMPEG_OUTPUT --enable-x86asm --extra-cflags="$FFMPEG_INC" --extra-ldflags="$FFMPEG_LIB"
        make clean
        make -j${THREAD_COUNT}
        make install
        cd $WORKING_DIR
        echo ">>>>>>编译完成 ffmpeg !<<<<<<"
    fi

    MERGED_LIB_OUTPUT="$WORKING_DIR/output/dist/${PLATFORM}-$CPU"

    if [ "$MERGED_LIB_OUTPUT" ]; then

        rm -rf $MERGED_LIB_OUTPUT
        mkdir -p $MERGED_LIB_OUTPUT
        cp -r "$FFMPEG_OUTPUT/*" "$MERGED_LIB_OUTPUT/"

        if [ -r $X264_OUTPUT ]; then
            cp -r "$X264_OUTPUT/*" "$MERGED_LIB_OUTPUT/"
        fi

        if [ -r $FDK_AAC_OUTPUT ]; then
            cp -r "$FDK_AAC_OUTPUT/*" "$MERGED_LIB_OUTPUT/"
        fi

    fi
}

if [ "${1}" == "windows" -o "$1" == "linux" -o "$1" == "macos" ]; then
    if [ "$2" == "x86_64" -o "$2" == "arm64" ]; then
        build_ffmpeg $1 $2
    else
        echo "unsupport cpu arch $2. Valid [ 'x86_64', 'arm64' ]"
    fi
else
    echo "unsupport operating system $1. Valid [ 'windows', 'linux', 'macos' ]"
fi
