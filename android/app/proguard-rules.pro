# ============================================================
# SmartAttend — ProGuard Rules
# Prevent obfuscation of classes used by reflection / JNI
# ============================================================

# ─── Flutter & Dart ─────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# ─── Keep crash reporter classes ─────────────────────────────
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*

# ─── OkHttp / Dio HTTP client ─────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ─── Kotlin coroutines ───────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** { volatile <fields>; }

# ─── Camera / Image Picker ───────────────────────────────────
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# ─── BLE (flutter_blue_plus) ─────────────────────────────────
-keep class com.boskokg.flutter_blue_plus.** { *; }

# ─── Prevent stripping of reflection-dependent classes ──────
-keepattributes Signature
-keepattributes Exceptions

# ─── Don't warn about missing classes ───────────────────────
-dontwarn com.google.android.gms.**
-dontwarn javax.annotation.**
-dontwarn com.google.android.play.core.**

