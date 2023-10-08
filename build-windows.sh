#!/bin/bash

# 安装好 msys2 后，把 /usr/bin/link.exe 改名，避免和 msvc 冲突，我们使用 msvc 编译工具链

. ./common.sh

echo "Current work directory $WORKING_DIR"

X264_PREFIX="/usr/local/x264"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$X264_PREFIX/lib/pkgconfig"

function install_deps {
    # $1 1 执行安装 0 跳过
    echo "Installing dependencies"
    if [ $1 -gt 0 ]; then
        sed -i "s#https\?://mirror.msys2.org/#https://mirrors.tuna.tsinghua.edu.cn/msys2/#g" /etc/pacman.d/mirrorlist*
        pacman -Sy
        pacman -S --needed filesystem msys2-runtime bash libreadline libiconv libarchive libgpgme libcurl pacman ncurses libintl
        pacman -S -y diffutils make pkg-config automake autoconf libtool yasm nasm
        # pacman -S diffutils make pkg-config automake autoconf libtool yasm nasm gcc
    fi
    echo "Finished installing dependencies"
}

function prepare_build {
    echo "Building add installing libx264"

    # 会编译前 clean
    cd $WORKING_DIR/x264 &&
        CC=cl ./configure --prefix=$X264_PREFIX --enable-shared &&
        make clean &&
        make -j 4 &&
        make install

    # 修正
    if [ -r $X264_PREFIX/lib/libx264.dll.lib ]; then
        echo "mv $X264_PREFIX/lib/libx264.dll.lib $X264_PREFIX/lib/libx264.lib"
        mv $X264_PREFIX/lib/libx264.dll.lib $X264_PREFIX/lib/libx264.lib
    fi

    cd $WORKING_DIR

    echo "Finished building add installing libx264"
}

function build_windows {
    PREFIX="--prefix=/usr/local/ffmpeg"

    COMMON_ARGS="--enable-x86asm --disable-doc --disable-ffplay --disable-ffprobe --disable-ffmpeg --enable-shared --disable-static --enable-avresample --enable-gpl --enable-libx264 --enable-optimizations"
    ARCH_ARGS="--arch=x86_64"
    TOOLCHAIN_ARGS="--toolchain=msvc"

    # 其他参数：
    #  --disable-bzlib --disable-libopenjpeg --disable-iconv --disable-zlib
    # EXTRA_ARGS="--extra-cflags=-l/usr/local/x264/include --extra-ldflags=-L/usr/loca/x264/lib"

    echo "Compiling ffmpeg for windows_$CPU"
    echo "pkgconfig $PKG_CONFIG_PATH"
    # 调用同级目录下的configure文件
    # 指定输出目录
    # 各种配置项，想详细了解的可以打开configure文件找到Help options:查看
    cd $WORKING_DIR/$SOURCE &&
        git stash &&
        git checkout $BRANCH &&
        CC="cl.exe -wd4828;4101;4028;4267;492" CXX="cl.exe -wd4828;4101;4028;4267;492" ./configure $COMMON_ARGS $PREFIX $TOOLCHAIN_ARGS $ARCH_ARGS $EXTRA_ARGS &&
        make clean &&
        make -j 4 &&
        make install &&
        echo "The compilation of ffmpeg for windows_$CPU is completed"
    cd $WORKING_DIR
}

# install_deps 0
# exit 0
# prepare_build
# exit 0
build_windows
