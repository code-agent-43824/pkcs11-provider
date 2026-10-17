#!/usr/bin/env python3
# Copyright (C) 2026 code-agent-43824
# SPDX-License-Identifier: Apache-2.0

"""Package a verified release-mode MSVC provider without copying OpenSSL DLLs."""

import argparse
import os
import shutil
import struct
import tarfile
import tempfile
from pathlib import Path


MACHINES = {"x86": 0x14C, "x64": 0x8664, "arm64": 0xAA64}


def check_machine(module: Path, arch: str) -> None:
    data = module.read_bytes()
    if data[:2] != b"MZ":
        raise ValueError(f"{module}: missing DOS header")
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe : pe + 4] != b"PE\0\0":
        raise ValueError(f"{module}: missing PE signature")
    machine = struct.unpack_from("<H", data, pe + 4)[0]
    if machine != MACHINES[arch]:
        raise ValueError(f"{module}: PE machine {machine:#x}, expected {MACHINES[arch]:#x}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--arch", choices=MACHINES, required=True)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--openssl-release", required=True)
    parser.add_argument("--openssl-archive-sha256", required=True)
    args = parser.parse_args()

    module = args.build / "src" / "pkcs11.dll"
    if not module.is_file():
        raise FileNotFoundError(module)
    check_machine(module, args.arch)
    commit = os.environ.get("GITHUB_SHA", "")
    if len(commit) != 40 or any(c not in "0123456789abcdef" for c in commit):
        raise ValueError("GITHUB_SHA must be a 40-character lowercase commit hash")
    target = f"windows-{args.arch}-msvc"
    package = f"pkcs11-provider-dev-{target}"
    args.output.mkdir(parents=True, exist_ok=True)
    archive = args.output / f"{package}.tar.gz"
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / package
        (root / "lib" / "ossl-modules").mkdir(parents=True)
        (root / "include").mkdir()
        shutil.copy2(module, root / "lib" / "ossl-modules" / "pkcs11.dll")
        shutil.copy2("src/pkcs11.h", root / "include" / "pkcs11.h")
        shutil.copy2("COPYING", root / "COPYING")
        shutil.copytree("LICENSES", root / "LICENSES")
        (root / "BUILD-INFO.txt").write_text(
            f"Git commit: {commit}\n"
            f"Target: {target}\n"
            "OpenSSL: OpenSSL 3.6.5\n"
            "Build type: release\n"
            f"OpenSSL release: {args.openssl_release}\n"
            f"OpenSSL archive SHA-256: {args.openssl_archive_sha256}\n",
            encoding="utf-8",
        )
        (root / "README.md").write_text(
            "# Dev-архив pkcs11-provider для MSVC\n\n"
            "Готовый модуль `lib/ossl-modules/pkcs11.dll` загружается через "
            "OpenSSL 3 по имени `pkcs11`; укажите его каталог в `OPENSSL_MODULES`.\n"
            "Это модуль провайдера, а не библиотека для прямой линковки. "
            "`include/pkcs11.h` описывает интерфейс драйвера токена.\n\n"
            "Приложение должно использовать `libcrypto-3*.dll` той же архитектуры "
            "из указанного в `BUILD-INFO.txt` выпуска openssl-vcpkg. "
            "DLL OpenSSL в этот архив не входят. Для TLS приложению нужен "
            "также соответствующий `libssl-3*.dll`. Не смешивайте Debug и Release "
            "DLL OpenSSL: они имеют одинаковые имена.\n",
            encoding="utf-8",
        )
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(root, arcname=package)
    print(archive)


if __name__ == "__main__":
    main()
