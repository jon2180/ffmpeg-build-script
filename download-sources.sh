#!/bin/bash

CWD=$(pwd)

mkdir -p ${CWD}/sources

# download x264
echo "start to download x264 from https://code.videolan.org/videolan/x264.git to ${CWD}/sources/x264"
git clone --depth 1 -b stable https://code.videolan.org/videolan/x264.git ${CWD}/sources/x264

# download ffmpeg
echo "start to download ffmpeg from https://ffmpeg.org/releases/ffmpeg-6.1.2.tar.gz to ${CWD}/sources/ffmpeg-6.1.2"
wget -P ${CWD}/sources/ https://ffmpeg.org/releases/ffmpeg-6.1.2.tar.gz &&
    tar -xzvf ${CWD}/sources/ffmpeg-6.1.2.tar.gz -C ${CWD}/sources/ &&
    rm -f ${CWD}/sources/ffmpeg-6.1.2.tar.gz

# download fdk-aac
echo "start to download fdk-aac to ${CWD}/sources/fdk-aac-2.0.3"
wget -P ${CWD}/sources/ https://downloads.sourceforge.net/opencore-amr/fdk-aac-2.0.3.tar.gz &&
    tar -xzvf ${CWD}/sources/fdk-aac-2.0.3.tar.gz -C ${CWD}/sources/ &&
    rm -f ${CWD}/sources/fdk-aac-2.0.3.tar.gz
