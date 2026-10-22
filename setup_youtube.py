#!/usr/bin/env python3
"""
YouTube API Setup Script - One-time setup for YouTube authentication.

This script guides you through setting up YouTube API access:
1. Uses your client_secret.json to authenticate
2. Opens a browser for Google OAuth consent
3. Saves the refresh token for future headless use
4. Shows you the values to add as GitHub Secrets

Usage:
    python setup_youtube.py

Prerequisites:
    1. Go to https://console.cloud.google.com
    2. Create a new project (or select existing)
    3. Enable "YouTube Data API v3"
    4. Go to Credentials → Create Credentials → OAuth 2.0 Client ID
    5. Application type: "Desktop app"
    6. Download the JSON file and save as "client_secret.json" in this folder
"""

import os
import sys
import json
from pathlib import Path

# Fix Windows console encoding for Arabic & emojis
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).parent.resolve()
CLIENT_SECRET_FILE = SCRIPT_DIR / "client_secret.json"
TOKEN_FILE = SCRIPT_DIR / "token.json"

SCOPES = ["https://www.googleapis.com/auth/youtube.upload"]


def main():
    print("=" * 60)
    print("  🔑 YouTube API Setup - إعداد واجهة يوتيوب")
    print("=" * 60)
    print()

    # Check for client_secret.json
    if not CLIENT_SECRET_FILE.exists():
        print("💡 لم يتم العثور على ملف client_secret.json في المجلد.")
        print("يمكنك إدخال المفاتيح مباشرة الآن دون الحاجة لتحميل ملف:")
        print()
        input_id = input("  الرجاء إدخال Client ID (أو اضغط Enter للمساعدة): ").strip()
        if input_id and "apps.googleusercontent.com" in input_id:
            input_secret = input("  الرجاء إدخال Client Secret: ").strip()
            if input_secret:
                client_data = {
                    "installed": {
                        "client_id": input_id,
                        "client_secret": input_secret,
                        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                        "token_uri": "https://oauth2.googleapis.com/token",
                        "redirect_uris": ["http://localhost"]
                    }
                }
                with open(CLIENT_SECRET_FILE, 'w', encoding='utf-8') as f:
                    json.dump(client_data, f, indent=2)
                print(f"✅ تم حفظ المفاتيح بنجاح في ملف: {CLIENT_SECRET_FILE}")
                print()
            else:
                print("❌ لم يتم إدخال Client Secret!")
                sys.exit(1)
        else:
            print()
            print("📋 خطوات استخراج المفاتيح من Google Cloud:")
            print("  1. اذهب إلى: https://console.cloud.google.com")
            print("  2. أنشئ مشروع جديد (أو اختر مشروعك الحالي)")
            print("  3. فعّل 'YouTube Data API v3' من مكتبة الـ APIs.")
            print("  4. أنشئ بيانات اعتماد OAuth من نوع 'Desktop app' (تطبيق سطح مكتب).")
            print("  5. انسخ Client ID و Client Secret أو حمّل ملف client_secret.json.")
            print()
            sys.exit(1)

    # Load client secret
    with open(CLIENT_SECRET_FILE, 'r', encoding='utf-8') as f:
        client_data = json.load(f)

    # Handle both "installed" and "web" types
    if "installed" in client_data:
        client_info = client_data["installed"]
    elif "web" in client_data:
        client_info = client_data["web"]
    else:
        print("❌ ملف client_secret.json غير صحيح!")
        sys.exit(1)

    client_id = client_info.get("client_id", "").strip()
    client_secret = client_info.get("client_secret", "").strip()

    if not client_id or not client_secret or "هنا_ضع" in client_id or "placeholder" in client_id.lower():
        print("⚠️ تنبيه: ملف client_secret.json ما زال يحتوي على نصوص توضيحية افتراضية!")
        print("يرجى تحميل ملف بيانات الاعتماد (OAuth 2.0 Client ID) من Google Cloud Console")
        print("ووضعه باسم 'client_secret.json' داخل مجلد المشروع ثم تشغيل السكربت مجدداً.")
        print()
        sys.exit(1)

    print(f"✅ Found valid client_secret.json")
    print(f"   Client ID: {client_id[:25]}...{client_id[-10:] if len(client_id) > 35 else ''}")
    print()

    # Install required packages if needed
    try:
        from google_auth_oauthlib.flow import InstalledAppFlow
        from google.auth.transport.requests import Request
    except ImportError:
        print("📦 Installing required packages...")
        os.system(f"{sys.executable} -m pip install google-auth-oauthlib google-auth-httplib2 google-api-python-client")
        from google_auth_oauthlib.flow import InstalledAppFlow
        from google.auth.transport.requests import Request

    # Run OAuth flow
    print("🌐 Opening browser for Google authentication...")
    print("   (If browser doesn't open, copy the URL from the terminal)")
    print()

    flow = InstalledAppFlow.from_client_secrets_file(
        str(CLIENT_SECRET_FILE),
        scopes=SCOPES,
    )

    credentials = flow.run_local_server(
        port=8080,
        prompt="consent",
        access_type="offline",
    )

    # Save token
    token_data = {
        "token": credentials.token,
        "refresh_token": credentials.refresh_token,
        "token_uri": credentials.token_uri,
        "client_id": credentials.client_id,
        "client_secret": credentials.client_secret,
        "scopes": list(credentials.scopes),
    }

    with open(TOKEN_FILE, 'w', encoding='utf-8') as f:
        json.dump(token_data, f, indent=2)

    print()
    print("=" * 60)
    print("  ✅ تم الإعداد بنجاح! Authentication Successful!")
    print("=" * 60)
    print()
    print(f"💾 Token saved to: {TOKEN_FILE}")
    print()
    print("=" * 60)
    print("  📋 GitHub Actions Secrets")
    print("  أضف هذه القيم في GitHub Repository Settings:")
    print("  Settings → Secrets and variables → Actions → New repository secret")
    print("=" * 60)
    print()
    print(f"  YOUTUBE_CLIENT_ID = {client_id}")
    print(f"  YOUTUBE_CLIENT_SECRET = {client_secret}")
    print(f"  YOUTUBE_REFRESH_TOKEN = {credentials.refresh_token}")
    print()
    print("=" * 60)
    print()
    print("🧪 لاختبار الرفع على يوتيوب:")
    print("   python auto_generate.py --test")
    print()
    print("📌 ملاحظة مهمة:")
    print("   لا ترفع ملف token.json أو client_secret.json على GitHub!")
    print("   أضفهم في .gitignore")
    print()


if __name__ == "__main__":
    main()
