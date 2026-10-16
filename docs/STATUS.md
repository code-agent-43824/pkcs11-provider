# Состояние проекта

Текущий dev-релиз: `pkcs11-provider-dev-build-14`, обычный GitHub Release со
статусом Latest. GitHub Actions собрал пять архивов для Linux x86_64/ARM64,
macOS Intel/ARM64 и Windows UCRT64 x86_64. На каждой платформе прошли два
прямых unit-теста и загрузка готового модуля через OpenSSL. Скачанные архивы
прошли `SHA256SUMS`; в Windows архиве выявлен дефект метаданных ниже.

В Meson остались два прямых unit-теста. Локальная сборка, Address Sanitizer,
actionlint и REUSE прошли; GitHub Actions подтвердил Address Sanitizer,
Shellcheck, REUSE и csbuild. `imported-softokn`, остальные сценарии с токенами
и сквозные тесты удалены по решению владельца.

Windows UCRT64 цель использует пакетный OpenSSL из MSYS2. GitHub Actions
подтвердил сборку, два прямых unit-теста и загрузку DLL; кэш OpenSSL
3.6.5-1 был использован повторно. Выпуск № 14 содержит пять архивов с
верными SHA256SUMS, но в Windows `BUILD-INFO.txt` пустое поле `Git commit`.
Исправление внесено, новый выпуск ещё не проверен. Точные цели задаёт
`.github/workflows/dev-release.yml`.

Коммиты форка после `e5ff476` в `main` имеют автора и коммиттера
`code-agent-43824`. Предыдущие релизные теги сохраняют исходные SHA и
историческую атрибуцию, чтобы сведения о сборке в архивах оставались верными.
