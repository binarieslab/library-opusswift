#!/bin/bash
###########################################################################
#  Choose your libogg version and your currently-installed iOS SDK version:
#
VERSION="1.3.5"
SDKVERSION="9.0"
MINIOSVERSION="6.0"

# by default, we won't build for debugging purposes
if [ "${DEBUG}" == "true" ]; then
    echo "Compiling for debugging ..."
    OPT_CFLAGS="-O0 -fno-inline -g"
    OPT_LDFLAGS=""
    OPT_CONFIG_ARGS="--enable-assertions --disable-asm"
else
    OPT_CFLAGS="-Ofast -flto -g"
    OPT_LDFLAGS="-flto"
    OPT_CONFIG_ARGS=""
fi

ARCHS="arm64 arm64e arm64_32 x86_64 i386 armv7k"

DEVELOPER=`xcode-select -print-path`
#DEVELOPER="/Applications/Xcode.app/Contents/Developer"

cd "`dirname \"$0\"`"
REPOROOT=$(pwd)

# Where we'll end up storing things in the end
OUTPUTDIR="${REPOROOT}/Library"
mkdir -p ${OUTPUTDIR}/include
mkdir -p ${OUTPUTDIR}/lib

BUILDDIR="${REPOROOT}/build"

# where we will keep our sources and build from.
SRCDIR="${BUILDDIR}/src"
mkdir -p $SRCDIR
# where we will store intermediary builds
INTERDIR="${BUILDDIR}/built"
mkdir -p $INTERDIR

########################################

cd $SRCDIR

# Exit the script if an error happens
set -e

if [ ! -e "${SRCDIR}/libogg-${VERSION}.tar.gz" ]; then
	echo "Downloading libogg-${VERSION}.tar.gz"
	curl -LO http://downloads.xiph.org/releases/ogg/libogg-${VERSION}.tar.gz
fi
echo "Using libogg-${VERSION}.tar.gz"

tar zxf libogg-${VERSION}.tar.gz -C $SRCDIR
cd "${SRCDIR}/libogg-${VERSION}"

set +e # don't bail out of bash script if ccache doesn't exist
CCACHE=`which ccache`
if [ $? == "0" ]; then
	echo "Building with ccache: $CCACHE"
	CCACHE="${CCACHE} "
else
	echo "Building without ccache"
	CCACHE=""
fi
set -e # back to regular "bail out on error" mode

export ORIGINALPATH=$PATH

for ARCH in ${ARCHS}
do
    if [ "${ARCH}" == "x86_64" ] || [ "${ARCH}" == "i386" ]; then
        PLATFORM="WatchSimulator"
        EXTRA_CFLAGS="-arch ${ARCH}"
        EXTRA_CONFIG="--host=x86_64-apple-darwin"
    else
        PLATFORM="WatchOS"
        EXTRA_CFLAGS="-arch ${ARCH}"
        EXTRA_CONFIG="--host=arm-apple-darwin"
    fi

	mkdir -p "${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"

	./configure --enable-float-approx --disable-shared --enable-static --with-pic --disable-extra-programs --disable-doc ${EXTRA_CONFIG} \
    --prefix="${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk" \
    LDFLAGS="$LDFLAGS ${OPT_LDFLAGS} -fPIE -mwatchos-version-min=${MINIOSVERSION} -L${OUTPUTDIR}/lib" \
    CFLAGS="$CFLAGS ${EXTRA_CFLAGS} ${OPT_CFLAGS} -fPIE -mwatchos-version-min=${MINIOSVERSION} -I${OUTPUTDIR}/include -isysroot ${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer/SDKs/${PLATFORM}${SDKVERSION}.sdk" \

    # Build the application and install it to the fake SDK intermediary dir
    # we have set up. Make sure to clean up afterward because we will re-use
    # this source tree to cross-compile other targets.
	make -j4
	make install
	make clean
done

########################################

echo "Build library..."

# These are the libs that comprise libogg.
OUTPUT_LIB="libogg.a"
INPUT_LIBS=""
for ARCH in ${ARCHS}; do
	if [ "${ARCH}" == "x86_64" ] || [ "${ARCH}" == "i386" ]; then
		PLATFORM="WatchSimulator"
	else
		PLATFORM="WatchOS"
	fi
	INPUT_ARCH_LIB="${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk/lib/${OUTPUT_LIB}"
	if [ -e $INPUT_ARCH_LIB ]; then
		INPUT_LIBS="${INPUT_LIBS} ${INPUT_ARCH_LIB}"
	fi
done

# Combine the three architectures into a universal library.
if [ -n "$INPUT_LIBS"  ]; then
	lipo -create $INPUT_LIBS \
	-output "${OUTPUTDIR}/lib/${OUTPUT_LIB}"
else
	echo "$OUTPUT_LIB does not exist, skipping (are the dependencies installed?)"
fi


for ARCH in ${ARCHS}; do
    if [ "${ARCH}" == "x86_64" ] || [ "${ARCH}" == "i386" ]; then
		PLATFORM="WatchSimulator"
	else
		PLATFORM="WatchOS"
	fi
	cp -R ${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk/include/* ${OUTPUTDIR}/include/
	if [ $? == "0" ]; then
		# We only need to copy the headers over once. (So break out of forloop
		# once we get first success.)
		break
	fi
done

mv "${OUTPUTDIR}/lib/${OUTPUT_LIB}" "${OUTPUTDIR}/lib/libogg-watchos.a"

####################

echo "Building done."
echo "Cleaning up..."
rm -fr ${INTERDIR}
rm -fr "${SRCDIR}/libogg-${VERSION}"
echo "Done."
