#!/bin/bash

echo "Building libogg-ios 🔨"
sh ./build-libogg-ios.sh

echo "Building libogg-macos 🔨"
sh ./build-libogg-macos.sh

echo "Building libogg-watchos 🔨"
sh ./build-libogg-watchos.sh

echo "Building libopus-ios 🔨"
sh ./build-libopus-ios.sh

echo "Building libopus-macos 🔨"
sh ./build-libopus-macos.sh

echo "Building libopus-watchos 🔨"
sh ./build-libopus-watchos.sh

echo "Cleaning up 🧹"

REPOROOT=$(pwd)
BUILDDIR="${REPOROOT}/build"
if [ -d "${BUILDDIR}" ]; then
	rm -fr ${BUILDDIR}
fi

LIBRARY_DIR="${REPOROOT}/Library"
LIBRARY_DEST_DIR="${REPOROOT}/../OpusSwift/Library"
if [ ! -d "${LIBRARY_DIR}" ]; then
	echo "⛔️⛔️⛔️ Library directory was not correctly built ⛔️⛔️⛔️"
	exit 1
fi

if [ -d "${LIBRARY_DEST_DIR}" ]; then
	NOW=$(date)
	mv "${LIBRARY_DEST_DIR}" "${LIBRARY_DEST_DIR}_archive_${NOW}"
fi

mv "${LIBRARY_DIR}" "${LIBRARY_DEST_DIR}"

echo "TADAA 🏠"