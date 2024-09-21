#!/bin/bash

set -e
set -x

. "./basic-conf.sh"

# 交叉编译工具目录,对应关系如下
# armv8a -> arm64 -> aarch64-linux-android-
# armv7a -> arm -> arm-linux-androideabi-
# x86 -> x86 -> i686-linux-android-
# x86_64 -> x86_64 -> x86_64-linux-android-
archs="arm64 arm"

function build_x264_android {
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
        CC=$CC CXX=$CXX $X264_SOURCE/configure \
            $x264_args \
            --prefix=$X264_PREFIX \
            --disable-cli \
            --host=$HOST \
            --cross-prefix=$CROSS_PREFIX \
            --sysroot=$SYSROOT | tee $X264_PREFIX/configuration.txt || exit 1

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

        cd $CWD
        echo ">>>>>>编译完成 x264!<<<<<<"
        return 0
    fi
    return 1
}

function build_fdkaac_android {
    echo "Skip build ffd-aac"
    return 1

    local CPU="$1"

    FDKAAC_PREFIX="${BASIC_PREFIX}/fdk-aac"

    if [ -n "$FDKAAC_SOURCE" ] && [ -r "$FDKAAC_SOURCE" ]; then
        echo "Compiling fdk-aac for $CPU"

        local fdkaac_cache="${BAISC_CACHE}/fdk-aac"
        mkdir -p $fdkaac_cache
        cd $fdkaac_cache

        cd $FDKAAC_SOURCE
        ./autogen.sh

        rm -rf $FDKAAC_PREFIX
        mkdir -p $FDKAAC_PREFIX
        CC=$CC CXX=$CXX $FDKAAC_SOURCE/configure \
            $FDK_AAC_BASIC_ARGS \
            --prefix="$FDKAAC_PREFIX" \
            --with-pic=yes \
            --host=$HOST \
            --with-sysroot="$SYSROOT" \
            --target=android | tee $FDKAAC_PREFIX/configuration.txt || exit 1

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

function build_openssl_android {
    # openssl_inc="$CWD/OpenSSL/1.1.1/Include/Win64/VS2015"
    # openssl_lib="$CWD/OpenSSL/1.1.1/Lib/Win64/VS2015/Release"

    # ffmpeg_inc="$ffmpeg_inc -I$openssl_inc"
    # ffmpeg_lib="$ffmpeg_lib -L$openssl_lib"
    # ffmpeg_args="$ffmpeg_args --enable-nonfree --enable-openssl --enable-protocol=https"
    return 1
}

function build_ffmpeg_android {
    CPU="$1"

    #x264的头文件地址
    local ffmpeg_inc=""
    #x264的静态库地址，不能缩写成 LIB，Win 下有这个同名的环境变量，会覆盖系统环境变量
    local ffmpeg_lib=""
    local ffmpeg_thirdparty_args=""

    if build_x264_android $2; then
        ffmpeg_inc="$ffmpeg_inc -I$X264_PREFIX/include"
        ffmpeg_lib="$ffmpeg_lib -L$X264_PREFIX/lib"
        ffmpeg_thirdparty_args="$ffmpeg_thirdparty_args --enable-gpl --enable-libx264"
        export PKG_CONFIG_PATH="$X264_PREFIX/lib/pkgconfig/:$PKG_CONFIG_PATH"
    fi

    if build_fdkaac_android $2; then
        ffmpeg_inc="$ffmpeg_inc -I$FDKAAC_PREFIX/include"
        ffmpeg_lib="$ffmpeg_lib -L$FDKAAC_PREFIX/lib"
        ffmpeg_thirdparty_args="$ffmpeg_thirdparty_args --enable-nonfree --enable-libfdk-aac"
        export PKG_CONFIG_PATH="$FDKAAC_PREFIX/lib/pkgconfig/:$PKG_CONFIG_PATH"
    fi

    if build_openssl_android $2; then
        ffmpeg_inc="${ffmpeg_inc} -I$OPENSSL_ROOT_INC"
        ffmpeg_lib="${ffmpeg_lib} -L$OPENSSL_ROOT_LIB"
        ffmpeg_thirdparty_args="$ffmpeg_thirdparty_args --enable-nonfree --enable-openssl --enable-protocol=https"
    fi

    FFMPEG_PREFIX="${BASIC_PREFIX}/ffmpeg"

    if [ -n "$FFMPEG_SOURCE" -a -r "$FFMPEG_SOURCE" ]; then
        # 打印
        echo "Compiling FFmpeg for $CPU"

        # 开始编译
        local ffmpeg_cache="${BAISC_CACHE}/ffmpeg"
        rm -rf $ffmpeg_cache
        mkdir -p $ffmpeg_cache
        cd $ffmpeg_cache

        local ffmpeg_args="--enable-asm --enable-x86asm"

        rm -rf $FFMPEG_PREFIX
        mkdir -p $FFMPEG_PREFIX
        $FFMPEG_SOURCE/configure \
            $FFMPEG_BASIC_ARGS \
            $FFMPEG_MODULE_ARGS \
            $ffmpeg_thirdparty_args \
            $ffmpeg_args \
            --prefix=$FFMPEG_PREFIX \
            --enable-jni \
            --enable-cross-compile \
            --cross-prefix=$CROSS_PREFIX \
            --target-os=android \
            --arch=$ARCH \
            --cpu=$CPU \
            --cc=$CC \
            --cxx=$CXX \
            --sysroot=$SYSROOT \
            --extra-cflags="-Os -fpic $OPTIMIZE_CFLAGS $ffmpeg_inc" \
            --extra-ldflags="$ADDI_LDFLAGS $ffmpeg_lib" \
            --pkg-config="pkg-config --static" \
            $ADDITIONAL_CONFIGURE_FLAGs | tee $FFMPEG_PREFIX/configuration.txt || exit 1 # 最后通过 tee 命令复制了配置到文件中

        make clean
        make -j${CORE_COUNT} # CPU 核心线程数，自己调一下
        make install

        echo "start to copying license files..."
        find ${FFMPEG_SOURCE}/ -name "COPYING*" -o -name "LICENSE*" -o -name "LISENSE*" | while read file_name; do
            echo "INSTALL copying file $file_name to $FFMPEG_PREFIX/"
            cp $file_name $FFMPEG_PREFIX/
        done
        echo "copying license files done"

        echo "The Compilation of FFmpeg for $CPU is completed"
    fi

    # MERGED_LIB_OUTPUT="$WORKING_DIR/output/dist/android-$CPU"

    # if [ "$MERGED_LIB_OUTPUT" ]; then

    #     rm -rf $MERGED_LIB_OUTPUT
    #     mkdir -p $MERGED_LIB_OUTPUT
    #     cp -r $FFMPEG_PREFIX/* $MERGED_LIB_OUTPUT/

    #     if [ -r $X264_OUTPUT ]; then
    #         cp -r $X264_OUTPUT/* $MERGED_LIB_OUTPUT/
    #     fi

    #     # if [ -r $FDK_AAC_OUTPUT ]; then
    #     #     cp -r $FDK_AAC_OUTPUT/* $MERGED_LIB_OUTPUT/
    #     # fi

    # fi

    cd $WORKING_DIR
}

for ARCH in $archs; do
    ARCH=$ARCH

    if [ "$ARCH" == "arm64" ]; then
        CPU=armv8-a
        HOST=aarch64-linux-android

        CROSS_PREFIX=$ANDROID_NDK_TOOLCHAIN/bin/aarch64-linux-android-
        OPTIMIZE_CFLAGS="-march=$CPU"

        OPENSSL_ROOT_INC="/Users/feishu/Documents/OpenSSL/1_0_2h/include/Android/ARM64"
        OPENSSL_ROOT_LIB="/Users/feishu/Documents/OpenSSL/1_0_2h/lib/Android/ARM64"
    elif [ "$ARCH" == "arm" ]; then
        CPU=armv7-a
        HOST=armv7a-linux-androideabi

        CROSS_PREFIX=$ANDROID_NDK_TOOLCHAIN/bin/arm-linux-androideabi-
        OPTIMIZE_CFLAGS="-mfloat-abi=softfp -mfpu=vfp -marm -march=$CPU "

        OPENSSL_ROOT_INC="/Users/feishu/Documents/OpenSSL/1_0_2h/include/Android/ARMv7"
        OPENSSL_ROOT_LIB="/Users/feishu/Documents/OpenSSL/1_0_2h/lib/Android/ARMv7"
    elif [ "$ARCH" == "x86" ]; then
        CPU=x86
        HOST=i686-linux-android

        CROSS_PREFIX=$ANDROID_NDK_TOOLCHAIN/bin/i686-linux-android-
        OPTIMIZE_CFLAGS="-march=i686 -mtune=intel -mssse3 -mfpmath=sse -m32"
    elif [ "$ARCH" == "x86_64" ]; then
        CPU=x86-64

        HOST=x86_64-linux-android

        CROSS_PREFIX=$ANDROID_NDK_TOOLCHAIN/bin/x86_64-linux-android-
        OPTIMIZE_CFLAGS="-march=$CPU -msse4.2 -mpopcnt -m64 -mtune=intel"
    fi

    BASIC_PREFIX="${DIR_DIST_BASE}android/$CPU"
    BAISC_CACHE="${DIR_CACHE_BASE}/android-$CPU"

    # NDK头文件环境
    SYSROOT=$ANDROID_NDK_TOOLCHAIN/sysroot
    CC="$ANDROID_NDK_TOOLCHAIN/bin/${HOST}$ANDROID_TARGET_API-clang"
    CXX="$ANDROID_NDK_TOOLCHAIN/bin/${HOST}$ANDROID_TARGET_API-clang++"

    echo Current C compiler: $CC
    echo Current C++ compiler: $CXX

    build_ffmpeg_android $CPU
done
