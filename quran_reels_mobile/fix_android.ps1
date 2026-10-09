# =====================================================================
# fix_android.ps1
# Quran Reels Mobile Orchestrator - Phase 0 bootstrap script
#
# يعيد تكميل ملفات الـ Gradle Wrapper الثنائية الناقصة من قالب Flutter
# المثبت على جهازك (gradle-wrapper.jar + gradlew + gradlew.bat).
#
# التشغيل:  شغّل PowerShell داخل مجلد quran_reels_mobile ثم نفّذ:
#           .\fix_android.ps1
# =====================================================================

$ErrorActionPreference = 'Stop'
$ProjectRoot = $PSScriptRoot
$AndroidDir = Join-Path $ProjectRoot 'android'

function Write-Step($msg) { Write-Host "[fix_android] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[fix_android] ✓ $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "[fix_android] ✗ $msg" -ForegroundColor Red }

if (-not (Test-Path (Join-Path $AndroidDir 'app\src\main\AndroidManifest.xml'))) {
    Write-Err 'لم يتم العثور على مجلد android الخاص بالمشروع. تأكد من تشغيل هذا السكربت من داخل مجلد quran_reels_mobile.'
    exit 1
}

# ------------------------------------------------------------------
# 1) Locate the Flutter SDK from the flutter executable on PATH
# ------------------------------------------------------------------
Write-Step 'البحث عن Flutter SDK...'
$flutterCmd = $null
try {
    $flutterCmd = (Get-Command flutter -ErrorAction Stop).Source
} catch {
    Write-Err 'أمر flutter غير موجود على PATH. ثبّت Flutter وأعد المحاولة: https://docs.flutter.dev/get-started/install'
    exit 1
}

$binDir = Split-Path $flutterCmd -Parent
$flutterRoot = Split-Path $binDir -Parent
if (-not (Test-Path (Join-Path $flutterRoot 'bin\flutter'))) {
    # بعض التثبيتات تكون بنفس عمق إضافي
    $flutterRoot = Split-Path $flutterRoot -Parent
}
if (-not (Test-Path (Join-Path $flutterRoot 'bin\flutter'))) {
    Write-Err "تعذّر تحديد جذر Flutter SDK من: $flutterCmd"
    exit 1
}
Write-Ok "جذر Flutter SDK: $flutterRoot"

# ------------------------------------------------------------------
# 2) Find the wrapper jar inside Flutter's bundled app templates
# ------------------------------------------------------------------
Write-Step 'البحث عن gradle-wrapper.jar داخل قوالب Flutter...'
$templatesRoot = Join-Path $flutterRoot 'packages\flutter_tools\templates'
$jar = $null
if (Test-Path $templatesRoot) {
    $jar = Get-ChildItem -Path $templatesRoot -Recurse -Filter 'gradle-wrapper.jar' -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
}
if (-not $jar) {
    Write-Err "لم يتم العثور على gradle-wrapper.jar تحت: $templatesRoot"
    Write-Err 'إصدار Flutter لديك قد يكون قديماً جداً أو مكسوراً. أعد تثبيت Flutter.'
    exit 1
}

# android template root = gradle/wrapper -> gradle -> <android-*.tmpl>
$templateAndroidDir = $jar.Directory.Parent.Parent
Write-Ok "القالب المستخدم: $templateAndroidDir"

# ------------------------------------------------------------------
# 3) Restore wrapper files into the project
# ------------------------------------------------------------------
$destWrapperDir = Join-Path $AndroidDir 'gradle\wrapper'
New-Item -ItemType Directory -Force -Path $destWrapperDir | Out-Null

foreach ($f in Get-ChildItem -Path $jar.Directory -File) {
    Copy-Item -Path $f.FullName -Destination (Join-Path $destWrapperDir $f.Name) -Force
    Write-Ok "تم نسخ gradle/wrapper/$($f.Name)"
}

foreach ($scriptName in @('gradlew', 'gradlew.bat')) {
    $src = Join-Path $templateAndroidDir $scriptName
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination (Join-Path $AndroidDir $scriptName) -Force
        Write-Ok "تم نسخ $scriptName"
    } else {
        Write-Host "[fix_android] ! $scriptName غير موجود في القالب (سيستخدم Flutter المسار البديل تلقائياً)" -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------------
# 4) Report the pinned Gradle version
# ------------------------------------------------------------------
$props = Join-Path $destWrapperDir 'gradle-wrapper.properties'
if (Test-Path $props) {
    $url = (Select-String -Path $props -Pattern '^distributionUrl=' | Select-Object -First 1).Line
    Write-Step "إصدار Gradle المعتمد: $url"
}

# ------------------------------------------------------------------
# 5) Sanity check the pieces Phase 0 created
# ------------------------------------------------------------------
Write-Step 'فحص اكتمال ملفات أندرويد الأساسية...'
$required = @(
    'settings.gradle',
    'gradle.properties',
    'build.gradle',
    'app\build.gradle',
    'gradle\wrapper\gradle-wrapper.jar',
    'app\src\main\AndroidManifest.xml',
    'app\src\main\kotlin\com\quran\reels\orchestrator\MainActivity.kt',
    'app\src\main\res\values\styles.xml',
    'app\src\main\res\values\colors.xml',
    'app\src\main\res\drawable\launch_background.xml',
    'app\src\main\res\drawable\ic_launcher_foreground.xml',
    'app\src\main\res\mipmap-anydpi-v26\ic_launcher.xml'
)
$missing = @()
foreach ($r in $required) {
    if (-not (Test-Path (Join-Path $AndroidDir $r))) { $missing += $r }
}
if ($missing.Count -gt 0) {
    Write-Err 'ما زالت الملفات التالية مفقودة:'
    $missing | ForEach-Object { Write-Host "         - $_" -ForegroundColor Red }
    exit 1
}
Write-Ok 'جميع الملفات الأساسية موجودة. المشروع جاهز للبناء.'

Write-Host ''
Write-Host '======================================================' -ForegroundColor White
Write-Host 'الخطوات التالية (نفّذها في نفس المجلد):' -ForegroundColor White
Write-Host '  flutter pub get' -ForegroundColor White
Write-Host '  flutter build apk --release' -ForegroundColor White
Write-Host ''
Write-Host 'ملف الـ APK النهائي:' -ForegroundColor White
Write-Host '  build\app\outputs\flutter-apk\app-release.apk' -ForegroundColor White
Write-Host '======================================================' -ForegroundColor White
