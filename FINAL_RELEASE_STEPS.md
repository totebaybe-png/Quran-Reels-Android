# 🚀 خطة الإصدار النهائية — Quran Reels Generator

> **الحالة:** الكود مُصلَّح ومُتحقَّق منه بالكامل محلياً (34/34 اختبار نجاح، `flutter analyze` نظيف).
> هذه هي الخطوات **اليدوية الأخيرة** التي تحتاج فيها للعمل على GitHub مباشرةً.

---

## ✅ ما تم إصلاحه (مُتحقَّق منه بالفعل)

| # | الإصلاح | الملف |
|---|---------|-------|
| 1 | **زر الإطلاق لم يعد يعتمد على `is_template`** — fallback كامل عبر Git Data API ينسخ كل الملفات ويُنشئ `state.json` نظيفاً | `lib/services/github_service.dart` |
| 2 | **التوقيع الدائم** — استثناء `release-keystore.jks` من `.gitignore` ليتم رفعه للـ CI + إبقاء `key.properties` سرياً محلياً + fallback آمن للـ debug | `android/app/build.gradle` + `.gitignore` |
| 3 | **بطارة الحالة الحقيقية** — تفحص آخر `workflow_run` بدلاً من الأخضر الثابت | `lib/screens/dashboard_screen.dart` |
| 4 | **حارس حصة يوتيوب** — عدّاد يومي + فحص `quotaExceeded` قبل الرفع | `auto_generate.py` |
| 5 | **`main.py` يعمل بدون binaries مفقودة** — حل ffmpeg/ImageMagick من النظام + fallback للخلفيات المُولّدة + PIL للنصوص | `main.py` |
| 6 | **توافق Dart 3 الحديث** — `pinenacl` 0.5.1→0.6.0، `intl` 0.19→0.20.3، `SealedBox` import، `BorderSide`→`Border.all`، `withOpacity`→`withValues` | `pubspec.yaml` + كل الشاشات |
| 7 | **صفحة الهبوط** — زر تحميل APK حقيقي + قسم **سياسة الخصوصية** الكامل | `landing/index.html` |
| 8 | **34 اختبار** (منها 22 لـ `GithubService` يغطون fast/fallback paths) + `analyze` نظيف | `test/` |
| 9 | **CI يبني ويوقّع** — `build_apk.yml` يفحص الكود، يشغل الاختبارات، يوقّع بالـ keystore، وينشر Release | `.github/workflows/build_apk.yml` |

---

## 🟡 خطوات يدوية مطلوبة منك (15 دقيقة)

### 1️⃣ أضف سرّ كلمة مرور الـ Keystore إلى GitHub (مطلوب للتوقيع الدائم)
1. انسخ كلمة المرور من `quran_reels_mobile/android/key.properties` (قيمة `storePassword`).
2. في المستودع: **Settings → Secrets and variables → Actions → New repository secret**.
3. الاسم: `KEYSTORE_PASSWORD` — القيمة: كلمة المرور المنسوخة.
4. **النتيجة:** كل APK يُبنى في CI سيكون موقّعاً توقيعاً دائماً قابلاً للتحديث.

> ⚠️ **بدون هذه الخطوة:** سيُبنى APK بالـ debug key مؤقتاً (يعمل، لكن لا يمكن تحديثه لاحقاً).

### 2️⃣ التزم وادفع الملفات الجديدة
```bash
git add -A
git commit -m "🌿 إصلاح شامل: زر الإطلاق fallback، توقيع دائم، توافق Dart 3، حارس الحصة، اختبارات"
git push origin main
```

### 3️⃣ شغّل البناء السحابي يدوياً
1. في GitHub: **Actions → "📱 Build Quran Reels Android APK" → Run workflow**.
2. فعّل `create_release` لإنشاء Release قابل للتحميل.
3. ستظهر APK موقّعة في **Releases** خلال ~10 دقائق.

### 4️⃣ (اختياري، يُنصح) فعّل Template Repository
هذه الخطوة تجعل زر "إطلاق القناة" فورياً (ثانية واحدة) بدلاً من الـ fallback (~30 ثانية):
1. المستودع `kpmbfi-sudo/Quran-Reels-Generator-open-source-` → **Settings → General**.
2. ☑ **Template repository** → Save.
3. التطبيق سيكتشف ذلك تلقائياً ويستخدم المسار السريع.

> ✅ **بدون هذه الخطوة يعمل كل شيء** عبر الـ fallback — لكن هذه أسرع.

---

## 🎯 ما تبقى (تحسينات غير حرجة)
- **حصة يوتيوب اليدوية:** عدّاد الزر اليدوي يعتمد على `state.json` فقط؛ لو ضغطت الزر 5+ مرات يدوياً في يوم واحد قد تتجاوز الحصة. الأتمتة المجدولة آمنة تماماً.
- **مجلد `vision/`:** فارغ بالتصميم (يتجاهله git)؛ الأتمتة تولّد خلفياتها الخاصة عند الحاجة.

---

## 📊 الأرقام النهائية
- **الاختبارات:** 34/34 ✅
- **التحليل الثابت:** No issues found ✅
- **المسار الأساسي للتطبيق:** يعمل في كلتا الحالتين (template + fallback) ✅
