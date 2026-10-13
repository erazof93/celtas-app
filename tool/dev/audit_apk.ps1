param(
    [Parameter(Mandatory=$true)][string]$Apk,
    [Parameter(Mandatory=$true)][string]$AndroidSdk,
    [Parameter(Mandatory=$true)][string]$ExpectedDebugCertificateSha256,
    [Parameter(Mandatory=$true)][string]$DevDefinesFile
)
$ErrorActionPreference = 'Stop'
$defines = Get-Content -LiteralPath $DevDefinesFile -Raw | ConvertFrom-Json
if ($defines.CELTAS_DEV -ne 'true' -or !$defines.CELTAS_DEV_ENV) { throw 'Explicit DEV defines required' }
$values = @{}
foreach ($line in ([string]$defines.CELTAS_DEV_ENV -split "`n")) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
        $values[$Matches[1]] = $Matches[2].Trim().Trim('"', "'")
    }
}
foreach ($key in @('ENVIRONMENT', 'DEV_SERVICES_AUTHORIZED', 'API_BASE_URL', 'FIREBASE_PROJECT_ID', 'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_APP_ID', 'FIREBASE_API_KEY', 'GOOGLE_SERVER_CLIENT_ID')) {
    if (!$values[$key]) { throw 'Incomplete DEV configuration' }
}
if ($values.ENVIRONMENT -ne 'dev' -or $values.DEV_SERVICES_AUTHORIZED -ne 'true' -or $values.API_BASE_URL -match '(?i)backend-celtas\.onrender\.com' -or $values.FIREBASE_PROJECT_ID -eq 'celtas-b0bd5') { throw 'Unsafe DEV configuration' }
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$productionGoogle = Get-Content -LiteralPath (Join-Path $repoRoot 'android/app/google-services.json') -Raw | ConvertFrom-Json
$productionNativeValues = @($productionGoogle.project_info.project_id, $productionGoogle.project_info.project_number)
foreach ($client in $productionGoogle.client) {
    $productionNativeValues += $client.client_info.mobilesdk_app_id
    $productionNativeValues += @($client.api_key | ForEach-Object { $_.current_key })
    $productionNativeValues += @($client.oauth_client | ForEach-Object { $_.client_id })
}
foreach ($value in $productionNativeValues) {
    if ($value -and @($values.Values | Where-Object { $_ -eq $value }).Count) { throw 'Production service value selected' }
}
$analyzer = Join-Path $AndroidSdk 'cmdline-tools/latest/bin/apkanalyzer.bat'
$signer = Join-Path $AndroidSdk 'build-tools/37.0.0/apksigner.bat'
$output = & $analyzer manifest print $Apk
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect manifest' }
[xml]$manifest = $output -join "`n"
$ns = 'http://schemas.android.com/apk/res/android'
$app = $manifest.manifest.application
if ($manifest.manifest.GetAttribute('package') -ne 'com.celtas.celtas_mobile.dev') { throw 'Wrong package' }
if ($app.GetAttribute('label', $ns) -ne 'Celtas DEV') { throw 'Wrong label' }
if ($app.GetAttribute('debuggable', $ns) -ne 'true') { throw 'Not debug' }
if ($app.GetAttribute('allowBackup', $ns) -ne 'false') { throw 'Backup must be disabled' }
$activities = @($app.activity | ForEach-Object { $_.GetAttribute('name', $ns) })
if ($activities -notcontains 'com.celtas.celtas_mobile.MainActivity' -or $activities -contains 'com.celtas.celtas_mobile.QaActivity') { throw 'Wrong entry activity' }
if (@($app.provider | Where-Object { $_.GetAttribute('name', $ns) -eq 'com.google.firebase.provider.FirebaseInitProvider' }).Count) { throw 'Automatic Firebase initialization enabled' }
foreach ($name in @('firebase_messaging_auto_init_enabled', 'firebase_data_collection_default_enabled')) {
    $entry = @($app.'meta-data' | Where-Object { $_.GetAttribute('name', $ns) -eq $name })
    if ($entry.Count -ne 1 -or $entry[0].GetAttribute('value', $ns) -ne 'false') { throw 'Automatic Firebase collection enabled' }
}
$signature = & $signer verify --verbose --print-certs $Apk
if ($LASTEXITCODE -ne 0) { throw 'Signature verification failed' }
$cert = @($signature | Where-Object { $_ -match 'certificate SHA-256 digest:' })
if ($cert.Count -ne 1 -or ($cert[0] -replace '^.*certificate SHA-256 digest:\s*', '').Trim() -ne $ExpectedDebugCertificateSha256.ToLowerInvariant()) { throw 'Wrong debug certificate' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Apk).Path)
try {
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -match '(^|/)\.env($|\.)|(^|/)(google-services\.json|key\.properties)|\.(jks|keystore|pem|p12)$') { throw 'Forbidden environment/signing asset' }
    }
    $resources = $zip.GetEntry('resources.arsc')
    if (!$resources) { throw 'Native resources missing' }
    $stream = $resources.Open()
    $buffer = [IO.MemoryStream]::new()
    try { $stream.CopyTo($buffer); $bytes = $buffer.ToArray() }
    finally { $stream.Dispose(); $buffer.Dispose() }
    foreach ($encoding in @([Text.Encoding]::UTF8, [Text.Encoding]::Unicode)) {
        $nativeText = $encoding.GetString($bytes)
        foreach ($value in $productionNativeValues) {
            if ($value -and $nativeText.Contains([string]$value)) { throw 'Production Firebase/OAuth native resource found' }
        }
    }
    $kernel = $zip.GetEntry('assets/flutter_assets/kernel_blob.bin')
    if (!$kernel) { throw 'Debug kernel missing' }
    $stream = $kernel.Open()
    $buffer = [IO.MemoryStream]::new()
    try { $stream.CopyTo($buffer); $text = [Text.Encoding]::UTF8.GetString($buffer.ToArray()) }
    finally { $stream.Dispose(); $buffer.Dispose() }
    if (!$text.Contains([string]$defines.CELTAS_DEV_ENV)) { throw 'Selected DEV configuration not found in debug kernel' }
    # Shared production constants can remain inert in debug code. This check
    # verifies selected configuration, not absence of every literal in the APK.
} finally { $zip.Dispose() }
Write-Output 'DEV package, label, debug signature, native Firebase guards and selected configuration verified.'
Write-Output 'Permissions:'
$manifest.manifest.'uses-permission' | ForEach-Object { $_.GetAttribute('name', $ns) }
Write-Output 'Firebase components (FCM service attachment remains disabled in Dart):'
$app.ChildNodes | Where-Object { $_ -is [System.Xml.XmlElement] } | Where-Object { $_.GetAttribute('name', $ns) -match 'firebase' } | ForEach-Object { $_.GetAttribute('name', $ns) }
