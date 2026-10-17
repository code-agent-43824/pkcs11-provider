# Copyright (C) 2026 code-agent-43824
# SPDX-License-Identifier: Apache-2.0

param(
    [Parameter(Mandatory)][ValidateSet('x86', 'x64', 'arm64')][string]$Arch
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$release = 'openssl-3.6.5-port2-r2'
$expected = @{
    x86 = '3d832a1d6af0b9421ed8ce1acd04fe66b87164ed807055f43fab24d0f61c93af'
    x64 = '0dbbc161b9ca0f567d0e14eb8df3f096e9c93f7d919deefbda96b66ccdc1b7bb'
    arm64 = '747b901ddc03c077cdf552526db2444e86999b784c6d36657941fde2b5ab76fd'
}
$archiveName = "openssl-3.6.5-$Arch-windows-dll-mt.zip"
$download = Join-Path $env:RUNNER_TEMP "openssl-vcpkg-$Arch"
$root = Join-Path $download 'openssl'
New-Item -ItemType Directory -Force $download | Out-Null
& gh release download $release --repo code-agent-43824/openssl-vcpkg `
    --pattern $archiveName --dir $download
if ($LASTEXITCODE -ne 0) { throw 'Could not download OpenSSL release asset' }
$actual = (Get-FileHash (Join-Path $download $archiveName) -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $expected[$Arch]) { throw "OpenSSL SHA-256 mismatch: $actual" }
Expand-Archive (Join-Path $download $archiveName) -DestinationPath $root
if (-not (Test-Path (Join-Path $root 'lib/libcrypto.lib'))) { throw 'Missing OpenSSL import library' }

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vs = & $vswhere -latest -products * -property installationPath
if (-not $vs) { throw 'Visual Studio not found' }
$hostArch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') { 'arm64' } else { 'amd64' }
$targetArch = @{ x86 = 'x86'; x64 = 'amd64'; arm64 = 'arm64' }[$Arch]
Import-Module (Join-Path $vs 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation `
    -DevCmdArguments "-arch=$targetArch -host_arch=$hostArch -no_logo"

python -m pip install --disable-pip-version-check meson ninja
if ($LASTEXITCODE -ne 0) { throw 'Could not install Meson and Ninja' }
$basePath = $env:PATH

$env:PATH = "$(Join-Path $root 'debug/bin');$basePath"
meson setup build-msvc-test -Dbuildtype=debug -Db_vscrt=mtd "-Dopenssl_root=$root"
if ($LASTEXITCODE -ne 0) { throw 'MSVC debug setup failed' }
meson compile -C build-msvc-test pkcs11
if ($LASTEXITCODE -ne 0) { throw 'MSVC debug build failed' }
meson test -C build-msvc-test --suite unittests --suite msvc --print-errorlogs
if ($LASTEXITCODE -ne 0) { throw 'MSVC direct tests failed' }

$env:PATH = "$(Join-Path $root 'bin');$basePath"
meson setup build-msvc-release -Dbuildtype=release -Db_vscrt=mt `
    "-Dopenssl_root=$root" '-Dbuild_info=Built with OpenSSL 3.6.5 from openssl-vcpkg'
if ($LASTEXITCODE -ne 0) { throw 'MSVC release setup failed' }
meson compile -C build-msvc-release pkcs11
if ($LASTEXITCODE -ne 0) { throw 'MSVC release build failed' }
meson test -C build-msvc-release --suite msvc --print-errorlogs
if ($LASTEXITCODE -ne 0) { throw 'MSVC release module did not load' }

$module = Join-Path (Get-Location) 'build-msvc-release/src/pkcs11.dll'
$imports = @(& dumpbin /nologo /dependents $module |
    ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[A-Za-z0-9_.-]+[.]dll$' })
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect provider PE imports' }
$cryptoName = @{ x86 = 'libcrypto-3.dll'; x64 = 'libcrypto-3-x64.dll'; arm64 = 'libcrypto-3-arm64.dll' }[$Arch]
$unexpected = @($imports | Where-Object {
    $_ -notin @($cryptoName, 'KERNEL32.dll', 'ADVAPI32.dll', 'BCRYPT.dll',
        'CRYPT32.dll', 'USER32.dll', 'WS2_32.dll', 'NTDLL.dll') -and
    $_ -notmatch '^(api-ms-win-|ext-ms-win-)'
})
$cryptoCount = @($imports | Where-Object { $_ -eq $cryptoName }).Count
if ($cryptoCount -ne 1 -or $unexpected.Count -ne 0) {
    throw "Unexpected provider imports: $($imports -join ', ')"
}
$exports = & dumpbin /nologo /exports $module | Out-String
if ($LASTEXITCODE -ne 0 -or $exports -notmatch '\bOSSL_provider_init\b') {
    throw 'Missing OSSL_provider_init export'
}
Write-Output "MSVC provider imports: $($imports -join ', ')"

python scripts/package-msvc.py --arch $Arch --build build-msvc-release `
    --output dist --openssl-release $release --openssl-archive-sha256 $actual
if ($LASTEXITCODE -ne 0) { throw 'Could not package MSVC provider' }
$target = "windows-$Arch-msvc"
$archive = Join-Path (Get-Location) "dist/pkcs11-provider-dev-$target.tar.gz"
$unpacked = Join-Path $env:RUNNER_TEMP "verify-provider-$Arch"
New-Item -ItemType Directory -Force $unpacked | Out-Null
tar -xzf $archive -C $unpacked
if ($LASTEXITCODE -ne 0) { throw 'Could not unpack MSVC provider archive' }
$env:OPENSSL_MODULES = Join-Path $unpacked "pkcs11-provider-dev-$target/lib/ossl-modules"
& (Join-Path (Get-Location) 'build-msvc-release/tests/tmsvc_load.exe')
if ($LASTEXITCODE -ne 0) { throw 'Published MSVC provider failed to load' }
