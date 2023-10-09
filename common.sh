#!/bin/bash

SOURCE=ffmpeg
BRANCH=release/4.4
WORKING_DIR=$(pwd)

# directories
FF_VERSION="4.4.1"
#FF_VERSION="snapshot-git"
if [[ $FFMPEG_VERSION != "" ]]; then
  FF_VERSION=$FFMPEG_VERSION
fi

COMMON_ARGS="--disable-doc --disable-ffplay --disable-ffprobe --disable-ffmpeg --enable-shared --disable-static --enable-avresample --enable-gpl --enable-libx264 --enable-optimizations"
