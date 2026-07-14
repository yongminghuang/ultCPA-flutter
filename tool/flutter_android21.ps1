$sdkRoot = if ($env:ULTCPA_FLUTTER_SDK) {
    $env:ULTCPA_FLUTTER_SDK
} else {
    'E:\soft\flutter\flutter_3.32.8_sdk\flutter'
}
$flutter = Join-Path $sdkRoot 'bin\flutter.bat'

if (-not (Test-Path -LiteralPath $flutter)) {
    throw "Flutter 3.32.8 SDK not found at $flutter. Set ULTCPA_FLUTTER_SDK to override."
}

$env:FLUTTER_NO_VERSION_CHECK = 'true'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.googleapis.com'
$env:PUB_HOSTED_URL = 'https://pub.dev'
& $flutter @args
exit $LASTEXITCODE
