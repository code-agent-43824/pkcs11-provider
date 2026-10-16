#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 TARGET PREFIX" >&2
    exit 2
fi

target=$1
prefix=$2
case "$target" in
    macos-arm64-15)
        arch=osx-arm64
        package=openssl-3.6.5-h55eecbc_0.conda
        checksum=44fbc526456571a9fb8fa18157f6f269d4d4bd40eef20183a93b9c9296f94497
        ;;
    macos-x86_64-15)
        arch=osx-64
        package=openssl-3.6.5-h332eb6d_0.conda
        checksum=d992d27aec2f1beac81f792c85b449546c030f06937b5b3ea7cf58431861dde4
        ;;
    *)
        echo "Unsupported macOS target: $target" >&2
        exit 2
        ;;
esac

stage_dir=$(mktemp -d)
trap 'rm -rf "$stage_dir"' EXIT
archive="$stage_dir/$package"
url="https://conda.anaconda.org/conda-forge/$arch/$package"
curl --fail --location --silent --show-error --retry 3 "$url" -o "$archive"
actual=$(shasum -a 256 "$archive" | cut -d ' ' -f 1)
if [ "$actual" != "$checksum" ]; then
    echo "SHA-256 mismatch for $url: $actual" >&2
    exit 1
fi

payload=$(unzip -Z1 "$archive" | sed -n '/^pkg-.*\.tar\.zst$/p')
test -n "$payload"
mkdir -p "$prefix"
unzip -p "$archive" "$payload" | zstd -dc | tar -xf - -C "$prefix"

# Conda normally replaces its build prefix during installation. Only the
# pkg-config prefix is needed for compiling this provider from the archive.
for pc in "$prefix"/lib/pkgconfig/*.pc; do
    sed "s|^prefix=.*|prefix=$prefix|" "$pc" > "$pc.tmp"
    mv "$pc.tmp" "$pc"
done

test -s "$prefix/lib/libcrypto.3.dylib"
test -s "$prefix/lib/libssl.3.dylib"
test -s "$prefix/bin/openssl"
cat > "$prefix/package-source.txt" <<EOF
Conda-forge OpenSSL package: $arch/$package
Conda-forge package SHA-256: $checksum
EOF
cat "$prefix/package-source.txt"
