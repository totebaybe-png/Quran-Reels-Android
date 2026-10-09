# Flutter default ProGuard/R8 rules.
# Only applied once minifyEnabled/shrinkResources are turned on in
# app/build.gradle. Kept ready so the release build can be hardened later
# without hunting for the right keep rules.

# Keep the Flutter entry points and engine bridge intact.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Do not warn about the Vulkan/Gradle-native pieces we do not call directly.
-dontwarn io.flutter.embedding.**

# Preserve the application's own Kotlin/Java entry point.
-keep class com.quran.reels.orchestrator.** { *; }

# Keep Parcelable creators (referlected by the Android runtime).
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# Keep enum values used across the Flutter platform channel boundary.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
