#!/bin/bash

set -e
set -x

# . "$(dirname $0)/basic-conf.sh"
. "./basic-conf.sh"

function build_x264_windows {
    local CPU="$1"

    X264_PREFIX="${BASIC_PREFIX}/x264"

    if [ -n $X264_SOURCE -a -r "$X264_SOURCE" ]; then
        echo "Building and installing libx264"

        local x264_cache="${BAISC_CACHE}/x264"
        rm -rf $x264_cache
        mkdir -p $x264_cache
        cd $x264_cache

        local x264_args=$X264_BASIC_ARGS

        rm -rf $X264_PREFIX
        mkdir -p $X264_PREFIX
        CC=$CC $X264_SOURCE/configure --prefix=$X264_PREFIX $x264_args --disable-cli | tee $X264_PREFIX/configuration.txt || exit 1
        # --disable-asm \
        # --enable-pic \
        make clean
        make -j${CORE_COUNT}
        make install

        echo "start to copying license files..."
        find ${X264_SOURCE}/ -name "COPYING*" -o -name "LICENSE*" -o -name "LISENSE*" | while read file_name; do
            echo "INSTALL copying file $file_name to $X264_PREFIX/"
            cp $file_name $X264_PREFIX/
        done
        echo "copying license files done"

        # 修正
        if [ -r "$X264_PREFIX/lib/libx264.dll.lib" ]; then
            mv "$X264_PREFIX/lib/libx264.dll.lib" "$X264_PREFIX/lib/libx264.lib"
        fi

        cd $CWD
        echo ">>>>>>编译完成 x264!<<<<<<"
        return 0
    fi
    return 1
}

function build_fdkaac_windows {
    echo "Skip build ffd-aac"
    local CPU="$1"

    FDKAAC_PREFIX="${BASIC_PREFIX}/fdk-aac"

    return 1
    if [ -n "$FDKAAC_SOURCE" ] && [ -r "$FDKAAC_SOURCE" ]; then
        echo "Compiling fdk-aac for $CPU"

        local FDKAAC_CACHE="${BAISC_CACHE}/fdk-aac"
        mkdir -p $FDKAAC_CACHE
        cd $FDKAAC_CACHE

        cd $FDKAAC_SOURCE
        ./autogen.sh

        rm -rf $FDKAAC_PREFIX
        mkdir -p $FDKAAC_PREFIX
        CC=$CC CXX=$CXX $FDKAAC_SOURCE/configure --prefix="$FDKAAC_PREFIX" $FDK_AAC_BASIC_ARGS --with-pic=yes | tee $FDKAAC_PREFIX/configuration.txt || exit 1

        make clean
        make -j${CORE_COUNT} install

        echo "start to copying license files..."
        find ${FDKAAC_SOURCE}/ -name "COPYING*" -o -name "LICENSE*" -o -name "LISENSE*" | while read file_name; do
            echo "INSTALL copying file $file_name to $FDKAAC_PREFIX/"
            cp $file_name $FDKAAC_PREFIX/
        done
        echo "copying license files done"

        # 修正 一般也就 windows 比较特殊
        if [ -r "$FDKAAC_PREFIX/lib/libfdk-aac.dll.a" ]; then
            mv "$FDKAAC_PREFIX/lib/libfdk-aac.dll.a" "$FDKAAC_PREFIX/lib/libfdk-aac.lib"
        fi

        echo ">>>>>>>> fdk-aac 编译完成"
        return 1
    fi
    return 1
}

function build_openssl_windows {
    # openssl_inc="$CWD/OpenSSL/1.1.1/Include/Win64/VS2015"
    # openssl_lib="$CWD/OpenSSL/1.1.1/Lib/Win64/VS2015/Release"

    # ffmpeg_inc="$ffmpeg_inc -I$openssl_inc"
    # ffmpeg_lib="$ffmpeg_lib -L$openssl_lib"
    # ffmpeg_args="$ffmpeg_args --enable-nonfree --enable-openssl --enable-protocol=https"
    return 1
}

# $1 ENABLE_DEBUG
function build_ffmpeg {
    # windows
    # local PLATFORM="$1"
    local CPU="$1"

    CC=cl
    CXX=cl
    LD=link

    BASIC_PREFIX="${DIR_DIST_BASE}windows/$CPU"
    BAISC_CACHE="${DIR_CACHE_BASE}/windows-$CPU"

    # 头文件地址
    local ffmpeg_inc=""
    # 库地址，不能缩写成 LIB，Win 下有这个同名的环境变量，会覆盖系统环境变量
    local ffmpeg_lib=""
    # 第三方库的配置
    local ffmpeg_thirdparty_args=""

    if build_x264_windows $@; then
        ffmpeg_inc="$ffmpeg_inc -I$X264_PREFIX/include"
        ffmpeg_lib="$ffmpeg_lib -L$X264_PREFIX/lib"
        ffmpeg_thirdparty_args="$ffmpeg_thirdparty_args --enable-gpl --enable-libx264"
        export PKG_CONFIG_PATH="$X264_PREFIX/lib/pkgconfig/:$PKG_CONFIG_PATH"
    fi

    if build_fdkaac_windows $@; then
        ffmpeg_inc="$ffmpeg_inc -I$FDKAAC_PREFIX/include"
        ffmpeg_lib="$ffmpeg_lib -L$FDKAAC_PREFIX/lib"
        ffmpeg_thirdparty_args="$ffmpeg_thirdparty_args --enable-nonfree --enable-libfdk-aac"
        export PKG_CONFIG_PATH="$FDKAAC_PREFIX/lib/pkgconfig/:$PKG_CONFIG_PATH"
    fi

    if build_openssl_windows $@; then
        echo "using openssl to support https"
        ffmpeg_thirdparty_args="$ffmpeg_thirdparty_args --enable-https"
    fi

    FFMPEG_PREFIX="${BASIC_PREFIX}/ffmpeg"

    if [ -n "$FFMPEG_SOURCE" -a -r "$FFMPEG_SOURCE" ]; then
        echo "Building add installing ffmpeg"

        # 开始编译
        local ffmpeg_cache="${BAISC_CACHE}/ffmpeg"
        rm -rf $ffmpeg_cache
        mkdir -p $ffmpeg_cache
        cd $ffmpeg_cache

        # local ffmpeg_args="--arch=$CPU --toolchain=msvc --enable-cross-compile --target-os=win64"
        local ffmpeg_args="--arch=$CPU --toolchain=msvc --target-os=win64 --enable-asm --enable-x86asm"

        # 启用 x86asm 后会生成 ff_tx_codelet_list_float_x86 会生成失败
        rm -rf $FFMPEG_PREFIX
        mkdir -p $FFMPEG_PREFIX
        CC=$CC $FFMPEG_SOURCE/configure \
            $FFMPEG_BASIC_ARGS \
            $FFMPEG_MODULE_ARGS \
            $ffmpeg_thirdparty_args \
            $ffmpeg_args \
            --cc=$CC \
            --cxx=$CXX \
            --ld=$LD \
            --prefix=$FFMPEG_PREFIX \
            --extra-cflags="$ffmpeg_inc" \
            --extra-ldflags="$ffmpeg_lib" | tee $FFMPEG_PREFIX/configuration.txt || exit 1 # 最后通过 tee 命令复制了配置到文件中

        make clean
        make -j${CORE_COUNT}
        make install

        echo "start to copying license files..."
        find ${FFMPEG_SOURCE}/ -name "COPYING*" -o -name "LICENSE*" -o -name "LISENSE*" | while read file_name; do
            echo "INSTALL copying file $file_name to $FFMPEG_PREFIX/"
            cp $file_name $FFMPEG_PREFIX/
        done
        echo "copying license files done"

        if (($STATIC_ENABLE == 1)); then
            echo "start to rename library files"
            # 静态输出的是 .a 文件，直接重命名为 .lib
            find ${FFMPEG_PREFIX:?}/bin/ -name "*.a" | while read file_name; do
                new_name=${file_name%.a}.lib
                echo "rename $file_name to $new_name"
                mv $file_name $new_name
            done
            echo "rename library files done"
        fi

        cd $CWD
        echo ">>>>>>编译完成 ffmpeg !<<<<<<"
    fi

    # 暂时不合并

    # local merged_prefix="$BASIC_PREFIX/dist"

    # if [ -n "$merged_prefix" ]; then
    #     rm -rf $merged_prefix
    #     mkdir -p $merged_prefix

    #     if [ -n $FFMPEG_PREFIX -a -r $FFMPEG_PREFIX ]; then
    #         cp -r ${FFMPEG_PREFIX}/* "$merged_prefix/"
    #     fi

    #     if [ -n $X264_PREFIX -a -r $X264_PREFIX ]; then
    #         cp -r ${X264_PREFIX}/* "$merged_prefix/"
    #     fi

    #     if [ -n $FDKAAC_PREFIX -a -r $FDKAAC_PREFIX ]; then
    #         cp -r ${FDKAAC_PREFIX}/* "$merged_prefix/"
    #     fi

    #     libs=$(find $merged_prefix/bin/ -name "*.lib")
    #     for n in $libs; do
    #         mv $n $merged_prefix/lib/
    #     done
    # fi
}

if [ "$1" == "x86_64" -o "$1" == "arm64" ]; then
    # windows 打包动态库，不然会输出 .a 文件
    STATIC_ENABLE=0
    update_basic_args

    build_ffmpeg $@
else
    echo "unsupport cpu arch $1. Valid [ 'x86_64', 'arm64' ]"
fi
