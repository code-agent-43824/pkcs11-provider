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
Конкретная версия указана в `BUILD-INFO.txt`. Windows модуль импортирует
`libcrypto-3-x64.dll` и `libwinpthread-1.dll` из MSYS2 UCRT64; эти DLL нужно
предоставить в пути загрузки, как и драйвер PKCS #11 для вашего токена.
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
