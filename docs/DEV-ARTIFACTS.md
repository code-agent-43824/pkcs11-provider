# Dev-архивы для других проектов

Workflow `.github/workflows/dev-release.yml` проверяет код в отдельной
debug-сборке и собирает публикуемый модуль с `buildtype=release` из `main`.
Каждый архив содержит готовый модуль OpenSSL, заголовок
`include/pkcs11.h`, сведения о сборке и лицензии. Контрольные суммы опубликованы
рядом с архивами в `SHA256SUMS`. Архивы доступны на
[странице релизов](https://github.com/code-agent-43824/pkcs11-provider/releases).

`pkcs11-provider` создаётся Meson как `shared_module`. Он загружается OpenSSL
во время работы приложения и не предоставляет библиотеку для линковки.
Приложение линкуется с `libcrypto` из своей установки OpenSSL. Если приложению
нужны типы PKCS #11, оно может использовать `include/pkcs11.h` из архива;
заголовки OpenSSL берутся из той же установки, что и `libcrypto`.

После скачивания архива подходящей платформы и проверки `SHA256SUMS`:

```sh
tar -xzf pkcs11-provider-dev-<target>.tar.gz
export PKCS11_DEV="$PWD/pkcs11-provider-dev-<target>"
export OPENSSL_MODULES="$PKCS11_DEV/lib/ossl-modules"
openssl list -providers -provider default -provider pkcs11 -verbose
cc -I "$PKCS11_DEV/include" myapp.c $(pkg-config --cflags --libs libcrypto) -o myapp
```

В приложении вызовите `OSSL_PROVIDER_load(NULL, "pkcs11")`. Скрипт
`scripts/verify-dev-archive.sh` проверяет состав архива и загрузку
распакованного модуля через OpenSSL.

Для запуска нужен совместимый OpenSSL 3 и драйвер PKCS #11 для вашего токена.
Версия OpenSSL агента сборки записана в `BUILD-INFO.txt`. Linux-архивы
собираются под указанную в имени версию Ubuntu, поэтому для другого
дистрибутива проверьте зависимости и загрузку модуля на целевой машине.

Windows-архивы содержат `pkcs11.dll` и `pkcs11.h`, без DLL OpenSSL.

| Архив Windows | MSYS2 среда | Пакет OpenSSL |
| --- | --- | --- |
| `windows-x86_64-ucrt64` | UCRT64 | `mingw-w64-ucrt-x86_64-openssl` |
| `windows-x86-mingw32` | MINGW32 | `mingw-w64-i686-openssl` |
| `windows-arm64-clangarm64` | CLANGARM64 | `mingw-w64-clang-aarch64-openssl` |

При каждом запуске workflow проверяет доступную версию пакета в репозитории
MSYS2. Кэш GitHub Actions разделён по среде и версии пакета: при совпадении
используется сохранённый архив, при обновлении скачивается новый. Конкретный
пакет и версия указаны в `BUILD-INFO.txt`. На целевой машине приложению
нужна общая с провайдером DLL `libcrypto` из той же среды MSYS2 и той же
архитектуры, а также драйвер PKCS #11 для своего токена. Прямые импорты
MinGW pthread и GCC runtime у release-модуля не допускаются: pthread и
GCC runtime связаны статически, и в архив включена лицензия winpthreads.
Архив не содержит OpenSSL и поэтому не может работать без внешней DLL
`libcrypto`; если приложению нужен TLS, ему также нужна совместимая `libssl`.
MINGW32 помечен MSYS2 как
устаревающий; пока нужные пакеты доступны, сборка x86 использует его.
Приложение, собранное MSVC, должно использовать ту же DLL OpenSSL через
подходящий import library и загружать провайдер через OpenSSL; сам
`pkcs11.dll` напрямую не линкуется. Смешение модуля с другой сборкой
`libcrypto` может создать две несовместимые копии OpenSSL в одном процессе.

Для macOS workflow скачивает готовые пакеты OpenSSL 3 из conda-forge для
`osx-arm64` и `osx-64` и сверяет их SHA-256, закреплённые в
`scripts/install-conda-openssl.sh`. Источник конкретной сборки записан в
`BUILD-INFO.txt`. Суффикс `-15` в имени macOS архива обозначает runner
GitHub Actions; минимальную версию macOS для модуля указывает `BUILD-INFO.txt`.
Модуль ссылается на `@rpath/libcrypto.3.dylib`; пути
Homebrew в его зависимости быть не должно. Его собственный `LC_RPATH` указывает
на `@loader_path/..`: при размещении провайдера в `lib/ossl-modules` библиотеку
можно положить в соседний каталог `lib`. В архив входят только модуль и
заголовок, без OpenSSL. Для приложения без Homebrew поместите совместимые
`libcrypto.3.dylib` и при необходимости `libssl.3.dylib` той же архитектуры
в пакет приложения, настройте `@rpath`, затем подпишите приложение. Провайдер
и приложение должны использовать одну копию `libcrypto.3.dylib`.
