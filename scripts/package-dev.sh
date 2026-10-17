#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 BUILD_DIR TARGET OUTPUT_DIR" >&2
    exit 2
fi

build_dir=$1
target=$2
output_dir=$3

case "$(uname -s)" in
    Linux) module=pkcs11.so ;;
    Darwin) module=pkcs11.dylib ;;
    *NT*) module=pkcs11.dll ;;
    *) echo "Unsupported host platform" >&2; exit 2 ;;
esac

if [[ ! $target =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "Invalid target name: $target" >&2
    exit 2
fi

module_path="$build_dir/src/$module"
test -s "$module_path"
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)

stage_dir=$(mktemp -d)
trap 'rm -rf "$stage_dir"' EXIT
git_commit=${GITHUB_SHA:-}
if [ -z "$git_commit" ]; then
    git_commit=$(git rev-parse HEAD)
fi
test -n "$git_commit"
package="pkcs11-provider-dev-$target"
package_dir="$stage_dir/$package"
mkdir -p "$package_dir/lib/ossl-modules" "$package_dir/include"
cp "$module_path" "$package_dir/lib/ossl-modules/"
if [ "$module" = pkcs11.dylib ] && [ -n "${CONDA_OPENSSL_PREFIX:-}" ]; then
    staged_module="$package_dir/lib/ossl-modules/$module"
    install_name_tool -delete_rpath "$CONDA_OPENSSL_PREFIX/lib" "$staged_module"
    install_name_tool -add_rpath '@loader_path/..' "$staged_module"
    codesign --force --sign - "$staged_module"
fi
cp src/pkcs11.h "$package_dir/include/"
cp COPYING "$package_dir/"
cp -R LICENSES "$package_dir/"

cat > "$package_dir/BUILD-INFO.txt" <<EOF
Git commit: $git_commit
Target: $target
OpenSSL: $(openssl version -v)
Build type: debug, unstripped
EOF

if [ -n "${MSYS2_OPENSSL_PACKAGE:-}" ]; then
    printf 'MSYS2 OpenSSL package: %s\n' "$MSYS2_OPENSSL_PACKAGE" \
        >> "$package_dir/BUILD-INFO.txt"
fi
if [ -n "${CONDA_OPENSSL_PREFIX:-}" ]; then
    cat "$CONDA_OPENSSL_PREFIX/package-source.txt" \
        >> "$package_dir/BUILD-INFO.txt"
fi
if [ "$module" = pkcs11.dylib ]; then
    printf 'Minimum macOS: %s\n' "${MACOSX_DEPLOYMENT_TARGET:?}" \
        >> "$package_dir/BUILD-INFO.txt"
fi

cat > "$package_dir/README.md" <<'EOF'
# Dev-архив pkcs11-provider

`lib/ossl-modules/pkcs11.so` (macOS: `pkcs11.dylib`, Windows: `pkcs11.dll`) — готовый модуль
провайдера для OpenSSL 3. Укажите каталог модуля в `OPENSSL_MODULES` и
загружайте провайдер по имени `pkcs11`. Отдельной библиотеки для линковки нет.

`include/pkcs11.h` описывает интерфейс PKCS #11 для драйверов токенов.
Это не API провайдера. Для разработки приложений с OpenSSL нужны заголовки
совместимой установки OpenSSL; они не входят в архив.

Версия OpenSSL сборочного агента указана в `BUILD-INFO.txt`. Бинарный модуль
зависит от совместимой библиотеки OpenSSL и драйвера PKCS #11 на целевой машине.
Windows DLL OpenSSL в архив не входят: установите OpenSSL 3 для той же
архитектуры и среды MSYS2 (UCRT64 x86_64, MINGW32 x86 или CLANGARM64 ARM64)
и сделайте его DLL и необходимые runtime DLL доступными приложению.
На macOS модуль собран с готовым OpenSSL 3 из conda-forge; библиотеки OpenSSL
не входят в архив. Для запуска предоставьте совместимые `libcrypto.3.dylib`
и, если приложению нужен TLS, `libssl.3.dylib` той же архитектуры через
`@rpath`. Модуль ищет их также на уровень выше `ossl-modules`, в каталоге
`lib` архива. Приложение и провайдер должны использовать одну копию libcrypto.
Минимальная версия macOS для модуля указана в `BUILD-INFO.txt`.
EOF

archive="$output_dir/$package.tar.gz"
tar -C "$stage_dir" -czf "$archive" "$package"
printf '%s\n' "$archive"
