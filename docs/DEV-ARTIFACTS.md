# Dev-архивы для других проектов

Workflow `.github/workflows/dev-release.yml` собирает предварительные архивы
из `main`. Каждый архив содержит готовый модуль OpenSSL, заголовок
`include/pkcs11.h`, сведения о сборке и лицензии. Контрольные суммы опубликованы
рядом с архивами в `SHA256SUMS`.

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

В приложении вызовите `OSSL_PROVIDER_load(NULL, "pkcs11")`. Пример компиляции
и загрузки из распакованного архива выполняется в
`scripts/verify-dev-archive.sh` с исходником `tests/dev-consumer.c`.

Для запуска нужен совместимый OpenSSL 3 и драйвер PKCS #11 для вашего токена.
Версия OpenSSL агента сборки записана в `BUILD-INFO.txt`. Linux-архивы
собираются под указанную в имени версию Ubuntu, поэтому для другого
дистрибутива проверьте зависимости и загрузку модуля на целевой машине.
