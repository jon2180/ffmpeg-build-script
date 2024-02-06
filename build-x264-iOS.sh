#!/bin/sh

. ./common.sh

set -e
set -x

CONFIGURE_FLAGS="--enable-static --enable-pic --disable-cli --enable-strip"

# ARCHS="arm64 x86_64 i386 armv7 armv7s"
ARCHS="arm64 x86_64"

# directories
SOURCE="x264"
X264_SOURCE="$WORKING_DIR/x264"

FAT="$X264_OUTPUT/"

PLATFORM=iOS
DEBUG_PATH_SUFFIX="release"

COMPILE="y"
LIPO="n"

DEPLOYMENT_TARGET="12.0"

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
	CWD=`pwd`
	for ARCH in $ARCHS
	do
		CFLAGS="-arch $ARCH"
		ASFLAGS=

		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    if [ "$ARCH" = "x86_64" ]
		    then
		    	CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
		    	HOST=
		    else
		    	CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
			HOST="--host=i386-apple-darwin"
		    fi
		else
		    PLATFORM="iPhoneOS"
		    if [ $ARCH = "arm64" ]
		    then
		        HOST="--host=aarch64-apple-darwin"
				XARCH="-arch aarch64"
		    else
		        HOST="--host=arm-apple-darwin"
				XARCH="-arch arm"
		    fi
			CFLAGS="$CFLAGS -fembed-bitcode -mios-version-min=$DEPLOYMENT_TARGET"
			ASFLAGS="$CFLAGS"
		fi

		X264_OUTPUT="$WORKING_DIR/output/x264/${PLATFORM}-$ARCH-${DEBUG_PATH_SUFFIX}"
		X264_CACHE="$WORKING_DIR/cache/x264/${PLATFORM}-$ARCH-${DEBUG_PATH_SUFFIX}"

		# SCRATCH="$WORKING_DIR/output/x264/${PLATFORM}-$ARCH-${DEBUG_PATH_SUFFIX}-scratch"
		# must be an absolute path
		# THIN="$WORKING_DIR/output/x264/${PLATFORM}-$ARCH-${DEBUG_PATH_SUFFIX}-thin"

		echo "building $ARCH..."
		# mkdir -p "$SCRATCH/$ARCH"
		# cd "$SCRATCH/$ARCH"
		mkdir -p "$X264_CACHE"
		cd "$X264_CACHE"

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"
		if [ $PLATFORM = "iPhoneOS" ]
		then
		    export AS="$CWD/$SOURCE/tools/gas-preprocessor.pl $XARCH -- $CC"
		else
		    export -n AS
		fi
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		# rm -f $CWD/$SOURCE/config.h
		# rm -f $CWD/$SOURCE/x264_config.h
		CC=$CC $X264_SOURCE/configure \
		    $CONFIGURE_FLAGS \
		    $HOST \
		    --extra-cflags="$CFLAGS" \
		    --extra-asflags="$ASFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    --prefix="$X264_OUTPUT" || exit 1

		make -j12 install || exit 1
		cd $CWD
	done
fi

# if [ "$LIPO" ]
# then
# 	echo "building fat binaries..."
# 	mkdir -p $FAT/lib
# 	set - $ARCHS
# 	CWD=`pwd`
# 	cd $THIN/$1/lib
# 	for LIB in *.a
# 	do
# 		cd $CWD
# 		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB
# 	done

# 	cd $CWD
# 	cp -rf $THIN/$1/include $FAT
# fi
