# 📖 Quran Reels Generator | أداة ومولد ريلز القرآن الكريم تلقائياً 24/7

<div align="center">

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/kpmbfi-sudo/Quran-Reels-Generator-open-source-/daily_quran_reel.yml?branch=main&label=النشر%20التلقائي&style=for-the-badge)
![Python Version](https://img.shields.io/badge/Python-3.10%20%7C%203.11-blue?style=for-the-badge&logo=python)
![License](https://img.shields.io/badge/License-Apache--2.0-green?style=for-the-badge)
![Open Source](https://img.shields.io/badge/صدقة_جارية-لوجه_الله-gold?style=for-the-badge)

**نظام متكامل ومؤتمت بالكامل لإنتاج ونشر مقاطع ريلز وشورتس (Reels / Shorts) القرآن الكريم بجودة عالية تلقائياً 4 مرات يومياً عبر GitHub Actions مجاناً وبدون الحاجة لتشغيل جهازك!**

[📺 شاهد فيديو الشرح](https://youtu.be/ozgBWYtWNLA) | [🔴 اشترك بقناة المطور](https://www.youtube.com/@behairy10) | [🇸🇦 الدليل بالعربية](SETUP_GUIDE_AR.md) | [📱 تطبيق الأندرويد](quran_reels_mobile/) | [🇬🇧 English Guide](#-english)

</div>

---

## ✨ المميزات الرئيسية (Features)

- 🤖 **نشر تلقائي 24/7:** يعمل بدون تدخل بشري عبر **GitHub Actions** 4 مرات يومياً (ثلث الليل المتأخر، الصباح والضحى، الظهيرة، المساء).
- 🌿 **خلفيات طبيعية نقية 100%:** نظام فحص صارم يضمن اختيار مقاطع فيديو لعناصر الطبيعة فقط (سحب، أنهار، جبال، أمطار، فضاء) بدون ظهور أي بشر أو وجوه.
- 🎙️ **تنوع القراء:** دعم لأكثر من 10 قراء من عمالقة التلاوة (عبد الباسط عبد الصمد، المنشاوي، الحصري، مشاري العفاسي، وغيرهم).
- 📜 **الرسم العثماني المصحف:** معالجة دقيقة للتشكيل العربي والخط العثماني ومحاذاة النصوص لشاشات الهواتف الرأسية (9:16).
- 🎵 **مونتاج صوتي ذكي:** إزالة الصمت الزائد وتنعيم الدخول والخروج الصوتي (Fade In / Fade Out) وتزامن الآيات بدقة.
- 💻 **واجهة رسومية اختيارية:** إمكانية تشغيل الأداة محلياً عبر واجهة ويب سلسة لاختيار السور والآيات والمونتاج اليدوي.
- 🔒 **أمان كامل وخصوصية:** حماية تامة لبيانات الاعتماد والمفاتيح باستخدام GitHub Secrets وملفات `.env`.

---

## 🚀 طريقة الإعداد والربط السريع

> [!TIP]
> **لقراءة الشرح خطوة بخطوة بالصور والتفصيل الممل، راجع: [دليل الإعداد الكامل (SETUP_GUIDE_AR.md)](SETUP_GUIDE_AR.md)**

### 1. المتطلبات:
- تثبيت [Python 3.10+](https://www.python.org/downloads/)
- تثبيت [FFmpeg](https://ffmpeg.org/download.html)

### 2. تثبيت الحزم المطلوبة:
```bash
pip install -r requirements_auto.txt
```

### 3. ربط يوتيوب في دقيقة واحدة:
1. حمّل ملف بيانات الاعتماد (OAuth 2.0 Client ID) من منصة Google Cloud بصيغة JSON.
2. احفظ الملف داخل مجلد المشروع باسم `client_secret.json`.
3. شغّل سكربت الإعداد التفاعلي:
   ```bash
   python setup_youtube.py
   ```
4. سجّل الدخول بحساب قناتك وسيقوم السكربت بحفظ الرمز وطباعة مفاتيح الـ Secrets الثلاثة مباشرة!

### 4. إعداد النشر التلقائي عبر GitHub Actions:
أضف المتغيرات التالية في مستودعك على GitHub عبر (`Settings -> Secrets and variables -> Actions`):
- `YOUTUBE_CLIENT_ID`
- `YOUTUBE_CLIENT_SECRET`
- `YOUTUBE_REFRESH_TOKEN`
- `PEXELS_API_KEY` (مجاني من [Pexels API](https://www.pexels.com/api/))

ثم فعّل صلاحية الكتابة لـ Actions من:
`Settings -> Actions -> General -> Workflow permissions -> Read and write permissions`.

---

## 🛠️ التشغيل والتجربة محلياً

### تشغيل المولد الآلي (CLI):
```bash
# وضع الاختبار (توليد الفيديو فقط في outputs/video دون رفعه على يوتيوب):
python auto_generate.py --test

# تشغيل وتوليد ورفع فوري على قناتك:
python auto_generate.py
```

### تشغيل الواجهة الرسومية (Web UI):
```bash
python main.py
```
ثم افتح المتصفح على: `http://localhost:5000` أو افتح ملف `UI.html`.

---

## 📱 تطبيق الأندرويد (Mobile Orchestrator)

> [!IMPORTANT]
> **الطريقة الأساسية والأسهل لتشغيل القناة:** لا تحتاج لأي خبرة برمجية — التطبيق يهتم بكل شيء (إنشاء المستودع، حقن الأسرار المشفّرة، تشغيل الأتمتة) من هاتفك مباشرةً.

- 🏠 **الواجهة الكاملة + صفحة الهبوط:** [`landing/index.html`](landing/index.html) — صفحة هبوط احترافية بخلفية ليلية وذهبية، و[`mobile_orchestrator.html`](mobile_orchestrator.html) لنسخة المتصفح الكاملة.
- 🔒 **أمان Libsodium SealedBox:** كل سر (Client ID / Secret / Refresh Token / Pexels) يُشفَّر محلياً على الهاتف قبل إرساله إلى GitHub، ولا يمرّ بأي خادم وسيط.
- 🔄 **النسخ الاحتياطي الذكي:** لو لم يكن المستودع القالب مُفعّلاً كـ "Template Repository"، يتحوّل التطبيق تلقائياً لإنشاء المستودع ونسخ كل الملفات عبر Git Data API (الأتمتة لا تتوقف أبداً).
- ⏱️ **حارس حصة يوتيوب اليومية:** يمنع تجاوز الحصة (10,000 وحدة/يوم) تلقائياً.

### تحميل التطبيق:
1. حمّل أحدث APK من [صفحة الإصدارات (Releases)](https://github.com/kpmbfi-sudo/Quran-Reels-Generator-open-source-/releases).
2. ثبّته واتخذ معالج الإعداد (يدعم OAuth من جهازك بدون كمبيوتر).
3. اربط حساب GitHub واحصل على Personal Access Token بصلاحيات `repo` + `workflow`.

---

## 📁 هيكلية المشروع (Project Structure)

```text
├── .github/workflows/
│   └── daily_quran_reel.yml  # سيرفر النشر التلقائي المجدول عبر GitHub Actions
├── auto_generate.py          # المحرك الآلي الكامل لإنتاج الريلز ومعالجة النصوص
├── youtube_uploader.py       # وحدة رفع الفيديو والربط مع YouTube Data API v3
├── setup_youtube.py          # أداة الربط السريع واستخراج الـ Refresh Token
├── main.py                   # خادم Flask لتشغيل الواجهة الرسومية المحلية
├── UI.html                   # واجهة المستخدم الرسومية للتحكم اليدوي
├── state.json                # ملف تتبع السور والآيات لضمان عدم التكرار
├── fonts/                    # الخطوط العربية العثمانية المستخدمة في الفيديو
├── requirements_auto.txt     # متطلبات التشغيل والأتمتة
├── client_secret.json.example# نموذج ملف بيانات اعتماد Google Cloud
├── .env.example              # نموذج متغيرات البيئة
├── SETUP_GUIDE_AR.md         # الدليل الكامل لربط يوتيوب وجيت هب خطوة بخطوة
└── README.md                 # هذا الملف
```

---

<a name="english"></a>
## 🇬🇧 English

An open-source, fully automated 24/7 engine to generate and publish high-quality vertical Quran Reels and YouTube Shorts on schedule.

### 🌟 Key Highlights
- **100% Free 24/7 Automation:** Runs automatically 4 times per day via GitHub Actions cron triggers.
- **Pure Elemental Nature:** Multi-layered filters ensure pure nature visuals (clouds, waterfalls, rain, mountains, space) with strictly 0% humans.
- **Top World Reciters:** Over 10 world-renowned Quran reciters.
- **Auto Sync & Subtitles:** Audio silence trimming, Arabic tashkeel reshaping, and mobile-friendly vertical subtitle overlays.
- **Local GUI:** Optional local Flask server and web UI for manual reel production.

### Quick Start:
1. Clone the repository:
   ```bash
   git clone https://github.com/kpmbfi-sudo/Quran-Reels-Generator-open-source-.git
   cd Quran-Reels-Generator-open-source-
   ```
2. Install dependencies:
   ```bash
   pip install -r requirements_auto.txt
   ```
3. Set up YouTube authentication:
   - Place your Google Cloud OAuth desktop app credentials as `client_secret.json`.
   - Run `python setup_youtube.py` to obtain your tokens.
4. Add GitHub Secrets (`YOUTUBE_CLIENT_ID`, `YOUTUBE_CLIENT_SECRET`, `YOUTUBE_REFRESH_TOKEN`, `PEXELS_API_KEY`) and let GitHub Actions do the magic!

---

## 🤲 ترخيص وحقوق وصدقة جارية (License & Credits)
- **فكرة وتطوير:** **مصطفى بحيري** — صاحب **قناة البحيري :behiry**
- **🔴 قناة المطور (اشترك للتعرف على المطور والمزيد):** [https://www.youtube.com/@behairy10](https://www.youtube.com/@behairy10)
- **📺 فيديو الشرح العملي:** [شاهد الشرح على يوتيوب](https://youtu.be/ozgBWYtWNLA)
- هذا المشروع مفتوح المصدر ومتاح للجميع بنية الصدقة الجارية لوجه الله تعالى (ترخيص Apache-2.0). نسألكم الدعاء بظهر الغيب لنا ولوالدينا.
