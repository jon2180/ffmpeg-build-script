#!/bin/sh

. ./common.sh

ARCHS="arm64 x86_64"
# ARCHS="arm64 armv7 x86_64 i386"


# SOURCE="ffmpeg"
PLATFORM=iOS
DEBUG_PATH_SUFFIX="release"
CPU=$ARCHS

OUTPUT_DIR="$WORKING_DIR/output/ffmpeg/"

FAT="$OUTPUT_DIR/${PLATFORM}-$CPU-${DEBUG_PATH_SUFFIX}" 

SCRATCH="$OUTPUT_DIR/${PLATFORM}-$CPU-${DEBUG_PATH_SUFFIX}-scratch"
# must be an absolute path
THIN=$OUTPUT_DIR/${PLATFORM}-$CPU-${DEBUG_PATH_SUFFIX}-thin

# absolute path to x264 library
X264="$WORKING_DIR/output/x264/${PLATFORM}-$CPU-${DEBUG_PATH_SUFFIX}"
#FDK_AAC=`pwd`/../fdk-aac-build-script-for-iOS/fdk-aac-ios

CONFIGURE_FLAGS="--enable-cross-compile --disable-debug --disable-programs \
                 --disable-doc --enable-pic --disable-audiotoolbox"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-avdevice --disable-postproc --disable-everything --enable-encoder=aac --enable-encoder=libx264 --enable-muxer=h264 --enable-muxer=mp4 --enable-protocol=file --enable-protocol=rtmp --enable-filter=scale"

#  --enable-shared --disable-static
if [ "$X264" ]
then
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-gpl --enable-libx264"
fi

if [ "$FDK_AAC" ]
then
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-libfdk-aac --enable-nonfree"
fi

# avresample
#CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-avresample"


COMPILE="y"
LIPO="y"

DEPLOYMENT_TARGET="13.0"

if [ "$*" ]
then
	if [ "$*" = "lipo" ]
	then
		# skip compile
		COMPILE=
	else
		ARCHS="$*"
		if [ $# -eq 1 ]
		then
			# skip lipo
			LIPO=
		fi
	fi
fi

if [ "$COMPILE" ]
then
	if [ ! `which yasm` ]
	then
		echo 'Yasm not found'
		if [ ! `which brew` ]
		then
			echo 'Homebrew not found. Trying to install...'
                        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" \
				|| exit 1
		fi
		echo 'Trying to install Yasm...'
		brew install yasm || exit 1
	fi
	if [ ! `which gas-preprocessor.pl` ]
	then
		echo 'gas-preprocessor.pl not found. Trying to install...'
		(curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
			-o /usr/local/bin/gas-preprocessor.pl \
			&& chmod +x /usr/local/bin/gas-preprocessor.pl) \
			|| exit 1
	fi

	# if [ ! -r $SOURCE ]
	# then
	# 	echo 'FFmpeg source not found. Trying to download...'
	# 	curl http://www.ffmpeg.org/releases/$SOURCE.tar.bz2 | tar xj \
	# 		|| exit 1
	# fi
	if [ -r $WORKING_DIR/$SOURCE/.git ]
	then
		cd $WORKING_DIR/$SOURCE
		# git stash
		git checkout $BRANCH
		cd $WORKING_DIR
	fi

	# 修正
	if [ -r $WORKING_DIR/$SOURCE/config.h ]
	then
		rm -f $WORKING_DIR/$SOURCE/config.h
	fi

	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		CFLAGS="-arch $ARCH"
		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
		else
		    PLATFORM="iPhoneOS"
		    CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
		    if [ "$ARCH" = "arm64" ]
		    then
		        EXPORT="GASPP_FIX_XCODE5=1"
		    fi
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"

		# force "configure" to use "gas-preprocessor.pl" (FFmpeg 3.3)
		if [ "$ARCH" = "arm64" ]
		then
		    AS="gas-preprocessor.pl -arch aarch64 -- $CC"
		else
		    AS="gas-preprocessor.pl -- $CC"
		fi

		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"
		if [ "$X264" ]
		then
			CFLAGS="$CFLAGS -I$X264/include"
			LDFLAGS="$LDFLAGS -L$X264/lib"
		fi
		if [ "$FDK_AAC" ]
		then
			CFLAGS="$CFLAGS -I$FDK_AAC/include"
			LDFLAGS="$LDFLAGS -L$FDK_AAC/lib"
		fi

		if [ -r "$THIN/$ARCH" ]
		then
			rm -rf "$THIN/$ARCH"
		fi

		TMPDIR=${TMPDIR/%\/} $CWD/$SOURCE/configure \
		    --target-os=darwin \
		    --arch=$ARCH \
		    --cc="$CC" \
		    --as="$AS" \
		    $CONFIGURE_FLAGS \
		    --extra-cflags="$CFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    --prefix="$THIN/$ARCH" \
		|| exit 1

		make -j12 install $EXPORT || exit 1
		cd $CWD
	done
fi

if [ "$LIPO" ]
then
	echo "building fat binaries..."
	if [ -r "$FAT" ]
	then
		rm -rf "$FAT"
	fi
	mkdir -p $FAT/lib

	set - $ARCHS
	CWD=`pwd`
	cd $THIN/$1/lib
	for LIB in *.a
	do
		cd $CWD
		echo lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB 1>&2
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB || exit 1
	done

	cd $CWD
	cp -rf $THIN/$1/include $FAT
fi

echo Done
