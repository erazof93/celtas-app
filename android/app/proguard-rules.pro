# ─── Google Play Services Auth ────────────────────────────────────────────────
# Evita que R8/ProGuard ofusque o elimine clases que Google Sign-In necesita
# en runtime. Sin estas reglas, el login con Google CRASHA en builds de
# release/AAB porque la SDK usa reflexión internamente.
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.identity.** { *; }

# ─── Flutter engine + plugins ────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ─── Flutter Play Core / Deferred Components (evita errores de R8 al compilar AAB) ───
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
