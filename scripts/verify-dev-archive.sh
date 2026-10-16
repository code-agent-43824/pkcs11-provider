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
test -s "$package_dir/COPYING"
test -d "$package_dir/LICENSES"

case "$(uname -s)" in
    Linux) module=pkcs11.so ;;
    Darwin) module=pkcs11.dylib ;;
    *NT*) module=pkcs11.dll ;;
    *) echo "Unsupported host platform" >&2; exit 2 ;;
esac
test -s "$package_dir/lib/ossl-modules/$module"

OPENSSL_MODULES="$package_dir/lib/ossl-modules" \
    openssl list -providers -provider default -provider pkcs11 -verbose \
    | grep -F 'name: PKCS#11 Provider'
