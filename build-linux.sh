#!/bin/bash

./build-desktop.sh linux x86_64

# . ./common.sh

# set -e
# set -x

# #x264的头文件地址
# INC=""

# #x264的静态库地址
# LIB=""

# X264_SOURCE="$WORKING_DIR/x264"
# X264_OUTPUT="$WORKING_DIR/output/x264/linux$CPU"
# X264_CACHE="$WORKING_DIR/cache/x264/linux$CPU"

# FFMPEG_SOURCE="$WORKING_DIR/ffmpeg"
# FFMPEG_OUTPUT="$WORKING_DIR/output/ffmpeg/linux$CPU"
# FFMPEG_CACHE="$WORKING_DIR/cache/ffmpeg/linux$CPU"

# # $1 ENABLE_DEBUG
# function build_ffmpeg {
#     ENABLE_DEBUG=$1

#     FFMPEG_ARGS="--disable-doc --disable-ffplay --disable-ffprobe --disable-ffmpeg --disable-shared --enable-static --enable-optimizations"

#     if [ -r "$X264_SOURCE" ]; then
#         mkdir -p $X264_CACHE
#         cd $X264_CACHE

#         rm -rf $X264_OUTPUT

#         $X264_SOURCE/configure \
#             --prefix=$X264_OUTPUT \
#             --disable-asm \
#             --enable-static \
#             --enable-pic \
#             --disable-cli

#         make clean
#         make -j4
#         make install

#         INC="$INC -I$X264_OUTPUT/include"
#         LIB="$LIB -L$X264_OUTPUT/lib"

#         FFMPEG_ARGS="$FFMPEG_ARGS --enable-gpl --enable-libx264"
#         export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$$X264_OUTPUT/lib/pkgconfig"
#         cd $WORKING_DIR
#         echo ">>>>>>编译完成 x264!<<<<<<"
#     fi

#     if [ -r "$FFMPEG_SOURCE" ]; then
#         # 先切分支
#         cd $FFMPEG_SOURCE
#         if [ $(git status -s | wc -l) -gt 0 ]; then
#             git stash
#         fi
#         git checkout $BRANCH

#         rm -rf $FFMPEG_OUTPUT

#         # 开始编译
#         mkdir -p $FFMPEG_CACHE
#         cd $FFMPEG_CACHE
#         $FFMPEG_SOURCE/configure $FFMPEG_ARGS \
#             --prefix=$FFMPEG_OUTPUT \
#             --enable-x86asm \
#             --extra-cflags="$INC" \
#             --extra-ldflags="$LIB"

#         make clean
#         make -j4
#         make install
#         cd $WORKING_DIR
#         echo ">>>>>>编译完成 ffmpeg !<<<<<<"
#     fi
# }

# build_ffmpeg 1
