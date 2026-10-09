# 📱 تطبيق أندرويد: منسق ريلز القرآن السحابي (Quran Reels Mobile Orchestrator)

> **صدقة جارية لوجه الله تعالى 🌿**  
> تطبيق الهاتف الذكي للتحكم السحابي في إنتاج ونشر ريلز القرآن الكريم تلقائياً 24/7.

---

## ✨ المميزات الرئيسية
1. **سهولة تامة (Easy 3-Step Setup):** إعداد القناة والأتمتة في أقل من دقيقتين دون الحاجة لحاسوب أو أوامر برمجية.
2. **أمان عالي (Zero-Leakage):** تشفير محلي للأسرار قبل إرسالها إلى GitHub باستخدام خوارزمية **Libsodium SealedBox** (`pinenacl`).
3. **أتمتة مجانية مدى الحياة:** يعمل البوت السحابي عبر **GitHub Actions** وينشر 4 مرات يومياً حتى لو أغلقت هاتفك أو حذفت التطبيق.
4. **لوحة تحكم تفاعلية (Dashboard):**
   - مؤشر تشغيل حي 🟢
   - عد تنازلي لموعد الفيديو القادم
   - زر "⚡ نشر ريل جديد الآن فوراً"
   - متابعة سجلات العمليات والفيديوهات المنشورة

---

## 🛠️ متطلبات البناء (Build Requirements)
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.10+)
- [Android SDK](https://developer.android.com/studio) (Android API 23+)
- بيئة Java (OpenJDK 17 أو 21)

---

## 🚀 طريقة تشغيل وبناء التطبيق (Commands)

```bash
# 1. الدخول لمجلد التطبيق
cd quran_reels_mobile

# 2. تحميل الحزم والمكتبات
flutter pub get

# 3. التشغيل في وضع التطوير (Debug / Emulator)
flutter run

# 4. بناء ملف الـ APK النهائي للنشر
flutter build apk --release
```

ملف الـ APK النهائي سينتج في:
`build/app/outputs/flutter-apk/app-release.apk`

> [!IMPORTANT]
> **إذا فشل البناء بسبب فقدان ملفات الـ Gradle Wrapper** (gradle-wrapper.jar)،
> شغّل سكربت الإصلاح مرة واحدة ثم أعد البناء:
> ```powershell
> .\fix_android.ps1
> ```

---

## 🛠️ ملاحظات المطور (Developer Notes)

- **التوقيع:** النسخة الحالية موقّعة بمفتاح الـ debug (يكفي للتثبيت الجانبي/sideload).
  للنشر على Google Play لاحقاً، أنشئ keystore حقيقي وأضف `key.properties` ومرره في
  `android/app/build.gradle` بدلاً من `signingConfigs.debug`.
- **الأيقونة:** مرسومة كـ Vector Drawable (كتاب مفتوح + هلال) في
  `android/app/src/main/res/`. للوصول لأيقونات PNG بكثافات متعددة وأيقونة 512×512
  الخاصة بـ Play Store، استخدم `flutter_launcher_icons`.
- **التشويش:** `minifyEnabled` معطّل حالياً. قواعد ProGuard جاهزة في
  `android/app/proguard-rules.pro` لتفعيله لاحقاً وتصغير حجم الـ APK.
