#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 ARCHIVE TARGET" >&2
    exit 2
fi

archive=$1
target=$2
test -s "$archive"

stage_dir=$(mktemp -d)
trap 'rm -rf "$stage_dir"' EXIT
tar -C "$stage_dir" -xzf "$archive"
package_dir="$stage_dir/pkcs11-provider-dev-$target"
test -s "$package_dir/include/pkcs11.h"
test -s "$package_dir/BUILD-INFO.txt"
grep -Eq '^Git commit: [0-9a-f]{40}$' "$package_dir/BUILD-INFO.txt"
test -s "$package_dir/COPYING"
test -d "$package_dir/LICENSES"

case "$(uname -s)" in
    Linux) module=pkcs11.so ;;
    Darwin) module=pkcs11.dylib ;;
    *NT*) module=pkcs11.dll ;;
    *) echo "Unsupported host platform" >&2; exit 2 ;;
esac
module_path="$package_dir/lib/ossl-modules/$module"
test -s "$module_path"
if [ "$module" = pkcs11.dll ]; then
    case "$target" in
        windows-x86_64-ucrt64) expected_machine=6486 ;;
        windows-x86-mingw32) expected_machine=4c01 ;;
        windows-arm64-clangarm64) expected_machine=64aa ;;
        *) echo "Unknown Windows target: $target" >&2; exit 2 ;;
    esac
    pe_offset=$(od -An -tu4 -j 60 -N 4 "$module_path" | tr -d '[:space:]')
    signature=$(od -An -tx1 -j "$pe_offset" -N 4 "$module_path" \
        | tr -d '[:space:]')
    machine=$(od -An -tx1 -j "$((pe_offset + 4))" -N 2 "$module_path" \
        | tr -d '[:space:]')
    if [ "$signature" != 50450000 ] || [ "$machine" != "$expected_machine" ]; then
        echo "Unexpected PE architecture for $target: $machine" >&2
        exit 1
    fi
fi
if [ "$module" = pkcs11.dylib ]; then
    grep -q '^Conda-forge OpenSSL package: ' "$package_dir/BUILD-INFO.txt"
    grep -Fxq 'Minimum macOS: 11.0' "$package_dir/BUILD-INFO.txt"
    min_macos=$(otool -l "$package_dir/lib/ossl-modules/$module" | awk '
        $1 == "cmd" && $2 == "LC_BUILD_VERSION" { in_build_version = 1 }
        in_build_version && $1 == "minos" { print $2; exit }
    ')
    if [ "$min_macos" != 11.0 ]; then
        echo "Expected macOS 11.0 deployment target, found: $min_macos" >&2
        exit 1
    fi
    otool -L "$package_dir/lib/ossl-modules/$module" \
        | grep -F '@rpath/libcrypto.3.dylib'
    otool -l "$package_dir/lib/ossl-modules/$module" \
        | grep -F 'path @loader_path/.. (offset'
    codesign --verify "$package_dir/lib/ossl-modules/$module"
    if [ -n "${CONDA_OPENSSL_PREFIX:-}" ] && \
       otool -l "$package_dir/lib/ossl-modules/$module" \
           | grep -F "$CONDA_OPENSSL_PREFIX"; then
        echo "Build runner path remains in macOS module" >&2
        exit 1
    fi
fi

OPENSSL_MODULES="$package_dir/lib/ossl-modules" \
    openssl list -providers -provider default -provider pkcs11 -verbose \
    | grep -F 'name: PKCS#11 Provider'
