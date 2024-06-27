#!/usr/bin/env bash

git clone https://github.com/Itz-Kanasama/llvmTC $(pwd)/llvmTC -b llvm-tc
cd $(pwd)/llvmTC

bash ci.sh deps

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;41m$*\e[0m"
}

GITHUB_TOKEN=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
LLVM_NAME=Paradise

# Set a directory
DIR="$(pwd ...)"

# Build Info
rel_date="$(date "+%Y%m%d")" # ISO 8601 format
rel_friendly_date="$(date "+%B %-d, %Y")" # "Month day, year" format
builder_commit="$(git rev-parse HEAD)"

# Building LLVM's
msg "Building LLVM's ..."
chmod +x build-llvm.py
./build-llvm.py \
    --defines LLVM_PARALLEL_COMPILE_JOBS="$(nproc)" LLVM_PARALLEL_LINK_JOBS="$(nproc)" CMAKE_C_FLAGS=-O3 CMAKE_CXX_FLAGS=-O3 \
    --assertions \
	--build-stage1-only \
	--check-targets clang lld llvm \
	--projects "clang;lld" \
	--no-ccache \
    --shallow-clone \
    --targets "ARM;AArch64;X86" \
	--branch "release/13.x" \
    --clang-vendor "$LLVM_NAME" 2>&1 | tee build.log

# Check if the final clang binary exists or not.
[ ! -f install/bin/clang-1* ] && {
	err "Building LLVM failed ! Kindly check errors !!"
	err "build.log" "Error Log"
	exit 1
}

# Build binutils
msg "$LLVM_NAME: Building binutils..."
./build-binutils.py --targets arm aarch64

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
git clone "https://shenprjkt:$GITHUB_TOKEN@github.com/Redmi-S2-Y2-Resources/Paradise_Clang.git" rel_repo
pushd rel_repo || exit
rm -fr ./*
cp -r ../install/* .
git checkout README.md # keep this as it's not part of the toolchain itself
git add .
git commit -asm "Paradise: Update to $rel_date build
LLVM commit: $llvm_commit_url
Clang Version: $clang_version
Binutils version: $binutils_ver
Builder commit: https://github.com/Itz-Kanasama/llvmTC/commit/$builder_commit"
git push -f
popd || exit
