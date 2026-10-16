# Dev-архивы для других проектов

Workflow `.github/workflows/dev-release.yml` собирает dev-архивы
из `main`. Каждый архив содержит готовый модуль OpenSSL, заголовок
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

Windows-архив содержит `pkcs11.dll` и `pkcs11.h`, без DLL OpenSSL. Сборка
использует готовый пакет `mingw-w64-ucrt-x86_64-openssl` из MSYS2 UCRT64;
при каждом запуске workflow проверяет доступную версию в репозитории MSYS2.
Архив пакета сохраняется в кэше GitHub Actions по версии: при совпадении
используется сохранённый файл, при новой версии загружается новый пакет.
Конкретная версия указана в `BUILD-INFO.txt`. Для запуска приложению нужны
совместимые DLL OpenSSL 3 и `libwinpthread-1.dll` из MSYS2 UCRT64 в пути
загрузки DLL, а также драйвер PKCS #11. Приложение, собранное MSVC,
использует свой import library для OpenSSL, совместимый с выбранными DLL,
и загружает провайдер через OpenSSL; сам `pkcs11.dll` напрямую не линкуется.

На macOS сборка использует Homebrew `openssl@3`, а не системную
криптобиблиотеку. Для приложения и провайдера нужен OpenSSL 3 той же
архитектуры. Homebrew помещает `libcrypto.3.dylib` в свой каталог `opt`;
на целевой машине установите `openssl@3` либо обеспечьте совместимый путь
к этой библиотеке и загружайте провайдер из `OPENSSL_MODULES`.
