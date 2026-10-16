# Состояние проекта

Текущий dev-релиз: `pkcs11-provider-dev-build-15`, обычный GitHub Release со
статусом Latest. GitHub Actions собрал пять архивов для Linux x86_64/ARM64,
macOS Intel/ARM64 и Windows UCRT64 x86_64. На каждой платформе прошли два
прямых unit-теста и загрузка готового модуля через OpenSSL. Скачанные архивы
прошли `SHA256SUMS`; Windows `BUILD-INFO.txt` содержит SHA выпуска.

В Meson остались два прямых unit-теста. Локальная сборка, Address Sanitizer,
actionlint и REUSE прошли; GitHub Actions подтвердил Address Sanitizer,
Shellcheck, REUSE и csbuild. `imported-softokn`, остальные сценарии с токенами
и сквозные тесты удалены по решению владельца.

Windows UCRT64 цель использует готовый пакет OpenSSL из MSYS2. Перед каждой
сборкой workflow сверяет версию пакета; кэш для версии 3.6.5-1 был
использован повторно. Windows DLL импортирует `libcrypto-3-x64.dll` и
`libwinpthread-1.dll`; они не входят в архив по решению владельца.
Точные цели задаёт `.github/workflows/dev-release.yml`.

Для следующих macOS сборок источник OpenSSL переключён на проверенные пакеты
conda-forge; GitHub Actions и новый Release для этого изменения пока не
проверены. Последний подтверждённый выпуск остаётся № 15.

Коммиты форка после `e5ff476` в `main` имеют автора и коммиттера
`code-agent-43824`. Предыдущие релизные теги сохраняют исходные SHA и
историческую атрибуцию, чтобы сведения о сборке в архивах оставались верными.
