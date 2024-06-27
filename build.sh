#!/usr/bin/env bash

git clone https://github.com/Itz-Kanasama/tc-build $(pwd)/llvmTC -b main
cd $(pwd)/llvmTC

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;41m$*\e[0m"
}

# Set a directory
DIR="$(pwd ...)"

# Build Info
rel_date="$(date "+%Y%m%d")" # ISO 8601 format
rel_friendly_date="$(date "+%B %-d, %Y")" # "Month day, year" format
builder_commit="$(git rev-parse HEAD)"

# Build LLVM
msg "Building LLVM..."
./build-llvm.py \
	--clang-vendor "Paradise" \
	--projects "clang;lld;polly" \
	--targets "ARM;AArch64" \
	--shallow-clone \
	--incremental \
    --pgo \
	--lto full \
	--build-type "Release" 2>&1 | tee build.log

# Check if the final clang binary exists or not.
[ ! -f install/bin/clang-1* ] && {
	err "Building LLVM failed ! Kindly check errors !!"
}

# Build binutils
msg "Building binutils..."
./build-binutils.py --targets arm aarch64

# build gcc
PREFIX=install/
msg "Downloading GCC source code"
git clone https://git.linaro.org/toolchain/gcc.git -b master gcc --depth=1

build_gcc () {
    msg "Building GCC"
    cd gcc
    ./contrib/download_prerequisites
    cd ../
    mkdir build-gcc
    cd build-gcc
    ../gcc/configure --target=arm64 \
                     --prefix="$PREFIX" \
                     --disable-decimal-float \
                     --disable-libffi \
                     --disable-libgomp \
                     --disable-libmudflap \
                     --disable-libquadmath \
                     --disable-libstdcxx-pch \
                     --disable-nls \
                     --disable-shared \
                     --disable-docs \
                     --enable-default-ssp \
                     --enable-languages=c,c++ \
                     --with-pkgversion="Paradise GCC" \
                     --with-newlib \
                     --with-gnu-as \
                     --with-gnu-ld \
                     --with-sysroot
    make CFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" CXXFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" all-gcc -j$(nproc --all)
    make CFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" CXXFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" all-target-libgcc -j$(nproc --all)
    make install-gcc -j$(nproc --all)
    make install-target-libgcc -j$(nproc --all)
}

# Remove unused products
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
	strip -s "${f: : -1}"
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
	# Remove last character from file output (':')
	bin="${bin: : -1}"

	echo "$bin"
	patchelf --set-rpath "$DIR/install/lib" "$bin"
done

# Release Info
pushd llvm-project || exit
llvm_commit="$(git rev-parse HEAD)"
short_llvm_commit="$(cut -c-8 <<< "$llvm_commit")"
popd || exit

llvm_commit_url="https://github.com/llvm/llvm-project/commit/$short_llvm_commit"
binutils_ver="$(ls | grep "^binutils-" | sed "s/binutils-//g")"
clang_version="$(install/bin/clang --version | head -n1 | cut -d' ' -f4)"

# Push to GitHub
# Update Git repository
git config --global user.name "shenprjkt"
git config --global user.email "shenprjktplayground@gmail.com"
git clone "https://Itz-Kanasama:$GITHUB_TOKEN@github.com/Redmi-S2-Y2-Resources/Paradise_Clang.git" rel_repo
pushd rel_repo || exit
rm -fr ./*
cp -r ../install/* .
git checkout README.md # keep this as it's not part of the toolchain itself
git add .
git commit -asm "Update to $rel_date build
LLVM commit: $llvm_commit_url
Clang Version: $clang_version
Binutils version: $binutils_ver
Builder commit: https://github.com/Itz-Kanasama/tc-build/commit/$builder_commit"
git push -f
popd || exit