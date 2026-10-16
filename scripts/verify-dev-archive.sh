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
test -s "$package_dir/lib/ossl-modules/$module"
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
