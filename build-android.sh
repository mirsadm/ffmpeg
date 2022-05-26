#!/bin/bash
set -euxo pipefail

ANDROID_ABI="arm64-v8a"

export TOOLCHAIN=${ANDROID_NDK}/toolchains/llvm/prebuilt/darwin-x86_64
export ARCH=aarch64
export TARGET=${ARCH}-linux-android

# Set this to your minSdkVersion.
export API=24

# Configure and build.

export AR=$TOOLCHAIN/bin/llvm-ar
export CC=$TOOLCHAIN/bin/$TARGET$API-clang
export AS=$CC
export CXX=$TOOLCHAIN/bin/$TARGET$API-clang++
export LD=$TOOLCHAIN/bin/ld
export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
export STRIP=$TOOLCHAIN/bin/llvm-strip

build_vpx() {
	VPX_TARGET=$1

	if [ ! -d "libvpx" ]; then
		git clone https://chromium.googlesource.com/webm/libvpx
	fi	

	pushd libvpx

	git pull

	rm -rf output

	mkdir -p output

	./configure --target=${VPX_TARGET} --prefix=output \
		--enable-pic --disable-docs --disable-tools --disable-examples --disable-unit-tests --enable-vp8 --enable-vp9 --enable-vp9-highbitdepth

	# make clean

	V=1 make -j10

	make install

	popd # libvpx
}

build_libopus() {
	LIBOPUS_ARCHIVE="opus-1.3.1.tar.gz"
	curl -L https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz --output ${LIBOPUS_ARCHIVE}

	tar -xvf ${LIBOPUS_ARCHIVE}

	pushd opus-1.3.1

	./configure --prefix=${PWD}/output --host=arm --disable-doc --disable-extra-programs

	V=1 make -j10

	make install

	popd # opus-1.3.1
}

build_ffmpeg() {
	rm -rf output

	mkdir -p output

	make clean || true

	./configure --target-os=android --prefix=output --enable-cross-compile \
		--enable-pic --enable-static --disable-shared --cc=${CC} --ar=${AR} --as=${AS} --cxx=${CXX} --ld=${LD} --ranlib=${RANLIB} --strip=${STRIP} \
		--disable-everything --disable-programs --disable-doc --disable-audiotoolbox --disable-videotoolbox --disable-outdevs --disable-indevs --disable-network --disable-asm --enable-libopus --enable-libvpx  \
		--enable-encoder=libvpx_vp9 --enable-encoder=libvpx_vp8 --enable-encoder=libopus --enable-muxer=mp4 --enable-muxer=matroska --enable-protocol=file --enable-encoder=aac \
		--extra-ldflags="-L${TOOLCHAIN}/sysroot/usr/lib/${TARGET}/${API} -L${TOOLCHAIN}/lib64/clang/14.0.1/lib/linux -Lthirdparty/libvpx/output/lib -Lthirdparty/opus-1.3.1/output/lib -lclang_rt.builtins-aarch64-android -lc" \
		--extra-cflags="-Ithirdparty/libvpx/output/include -Ithirdparty/opus-1.3.1/output/include/opus"

	V=1 make -j10

	make install
}

mkdir -p thirdparty

pushd thirdparty

build_vpx arm64-android-gcc

build_libopus

popd # thirdparty

build_ffmpeg
