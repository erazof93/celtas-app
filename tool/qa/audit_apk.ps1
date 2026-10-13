param(
    [Parameter(Mandatory=$true)][string]$Apk,
    [Parameter(Mandatory=$true)][string]$AndroidSdk,
    [Parameter(Mandatory=$true)][string]$ExpectedDebugCertificateSha256
)
$ErrorActionPreference = 'Stop'
$Apk = (Resolve-Path -LiteralPath $Apk).Path
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$analyzer = Join-Path $AndroidSdk 'cmdline-tools/latest/bin/apkanalyzer.bat'
$signer = Join-Path $AndroidSdk 'build-tools/37.0.0/apksigner.bat'
$manifestText = & $analyzer manifest print $Apk
if ($LASTEXITCODE -ne 0) { throw 'Cannot read APK manifest' }
[xml]$manifest = $manifestText -join "`n"
$ns = 'http://schemas.android.com/apk/res/android'
$app = $manifest.manifest.application
$packageId = $manifest.manifest.GetAttribute('package')
if ($packageId -ne 'com.celtas.celtas_mobile.qa') { throw 'Unexpected package ID' }
if ($app.GetAttribute('debuggable', $ns) -ne 'true') { throw 'Not a debug APK' }
$permissions = @($manifest.manifest.'uses-permission' | ForEach-Object { $_.GetAttribute('name', $ns) })
if (@($permissions | Where-Object { $_ -ne "$packageId.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" }).Count) {
    throw 'Unexpected QA permission'
}
$components = @($app.ChildNodes | Where-Object { $_.LocalName -in @('activity', 'activity-alias', 'service', 'receiver', 'provider') })
if ($components.Count -ne 1 -or $components[0].GetAttribute('name', $ns) -ne 'com.celtas.celtas_mobile.QaActivity') {
    throw 'Unexpected Android components'
}
$qaCode = (& $analyzer dex code --class com.celtas.celtas_mobile.QaActivity $Apk) -join "`n"
if ($LASTEXITCODE -ne 0 -or $qaCode -match 'GeneratedPluginRegistrant|invoke-super' -or
    $qaCode -notmatch 'PackageInfoPlugin' -or $qaCode -notmatch 'UrlLauncherPlugin') {
    throw 'Unexpected QA native plugin initialization'
}
$expectedPlugins = @(
    'com/github/dart_lang/jni/JniPlugin',
    'com/github/dart_lang/jni_flutter/JniFlutterPlugin',
    'dev/fluttercommunity/plus/packageinfo/PackageInfoPlugin',
    'io/flutter/plugins/urllauncher/UrlLauncherPlugin'
)
$actualPlugins = @([regex]::Matches($qaCode, 'new-instance\s+\w+,\s+L([^;]+);') | ForEach-Object { $_.Groups[1].Value })
if (($actualPlugins -join ',') -ne ($expectedPlugins -join ',')) {
    throw 'Unexpected QA plugin set or JNI initialization order'
}
$signature = & $signer verify --verbose --print-certs $Apk
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed' }
$certLine = @($signature | Where-Object { $_ -match 'certificate SHA-256 digest:' })
if ($certLine.Count -ne 1 -or ($certLine[0] -replace '^.*certificate SHA-256 digest:\s*', '').Trim() -ne $ExpectedDebugCertificateSha256.ToLowerInvariant()) {
    throw 'Unexpected signing certificate'
}
# Compare original environment values in memory. Never print values or matching content.
$values = @{}
foreach ($line in [IO.File]::ReadAllLines((Join-Path $repoRoot '.env'))) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
        $value = $Matches[2].Trim().Trim('"', "'")
        if ($value.Length -ge 8) { $values[$Matches[1]] = $value }
    }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($Apk)
$matchesByKey = @{}
$suspiciousAssets = @()
try {
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -match '(^|/)\.env($|\.)|(^|/)(key\.properties|google-services\.json)|\.(jks|keystore|pem|p12)$') {
            throw 'Forbidden configuration or signing asset in APK'
        }
        if ($entry.FullName -match '^assets/.*\.(json|ya?ml|properties|ini|toml|txt)$') {
            $suspiciousAssets += $entry.FullName
        }
        if (!$entry.Length) { continue }
        $stream = $entry.Open()
        $buffer = [IO.MemoryStream]::new()
        try { $stream.CopyTo($buffer); $bytes = $buffer.ToArray() }
        finally { $stream.Dispose(); $buffer.Dispose() }
        $utf8 = [Text.Encoding]::UTF8.GetString($bytes)
        $utf16 = [Text.Encoding]::Unicode.GetString($bytes)
        foreach ($key in $values.Keys) {
            if ($utf8.Contains($values[$key]) -or $utf16.Contains($values[$key])) {
                $matchesByKey[$key] = @($matchesByKey[$key] | Where-Object { $_ }) + $entry.FullName
            }
        }
        if ($entry.FullName -eq 'assets/flutter_assets/kernel_blob.bin') {
            $hasher = [Security.Cryptography.SHA256]::Create()
            try { $kernelHash = ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
            finally { $hasher.Dispose() }
        }
    }
} finally { $zip.Dispose() }
$sensitiveKeys = @($matchesByKey.Keys | Where-Object { $_ -match 'KEY|TOKEN|SECRET|PASSWORD|CLIENT_ID' })
if ($sensitiveKeys.Count) { throw "Sensitive environment values found for keys: $($sensitiveKeys -join ', ')" }
$buildId = [IO.File]::ReadAllText((Join-Path $repoRoot 'build/app/intermediates/flutter/qaDebug/.last_build_id')).Trim()
$buildDir = Join-Path $repoRoot ".dart_tool/flutter_build/$buildId"
if ($kernelHash -ne (Get-FileHash -LiteralPath (Join-Path $buildDir 'app.dill') -Algorithm SHA256).Hash.ToLowerInvariant()) {
    throw 'APK kernel does not match the QA build output'
}
$inputs = (Get-Content -LiteralPath (Join-Path $buildDir 'kernel_snapshot_program.stamp') -Raw | ConvertFrom-Json).inputs
if (!@($inputs | Where-Object { $_ -match '[/\\]lib[/\\]main_qa\.dart$' }).Count -or
    @($inputs | Where-Object { $_ -match '[/\\]lib[/\\]main\.dart$' }).Count) {
    throw 'Unexpected Dart entrypoint inputs'
}
[pscustomobject]@{
    apk = $Apk
    bytes = (Get-Item -LiteralPath $Apk).Length
    sha256 = (Get-FileHash -LiteralPath $Apk -Algorithm SHA256).Hash.ToLowerInvariant()
    packageId = $packageId
    versionCode = $manifest.manifest.GetAttribute('versionCode', $ns)
    versionName = $manifest.manifest.GetAttribute('versionName', $ns)
    debug = $true
    certificateSha256 = $ExpectedDebugCertificateSha256
    permissions = $permissions
    components = @($components | ForEach-Object { $_.GetAttribute('name', $ns) })
    nativePlugins = @('JniPlugin', 'JniFlutterPlugin', 'PackageInfoPlugin', 'UrlLauncherPlugin')
    qaKernelSha256 = $kernelHash
    qaEntrypointVerified = $true
    environmentValueMatches = $matchesByKey
    configurationAssetsForReview = $suspiciousAssets
} | ConvertTo-Json -Depth 6
