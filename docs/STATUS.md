# Состояние проекта

Текущий dev-релиз: `pkcs11-provider-dev-build-6`, обычный GitHub Release со
статусом Latest. GitHub Actions собрал четыре архива для Linux x86_64/ARM64 и
macOS Intel/ARM64. На каждой платформе
прошли два прямых unit-теста и загрузка готового модуля через OpenSSL.
Скачанные архивы прошли `SHA256SUMS`, их состав и архитектуры проверены;
Linux x86_64 архив повторно загружен локально из Releases.

В Meson остались два прямых unit-теста. Локальная сборка, Address Sanitizer,
actionlint и REUSE прошли; GitHub Actions подтвердил Address Sanitizer,
Shellcheck, REUSE и csbuild. `imported-softokn`, остальные сценарии с токенами
и сквозные тесты удалены по решению владельца.

Нативная сборка Windows не заявлена: загрузчик драйвера в `src/interface.c`
использует POSIX `dlopen`/`dlsym`. Точные цели задаёт
`.github/workflows/dev-release.yml`.
