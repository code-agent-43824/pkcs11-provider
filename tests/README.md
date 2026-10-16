# Прямые тесты кода провайдера

Meson запускает два unit-теста: декодирование точки EC и разбор URI PKCS #11.
Оба вызывают функции провайдера без программного токена и внешних сервисов.

```sh
meson test -C builddir --suite unittests --print-errorlogs
```
