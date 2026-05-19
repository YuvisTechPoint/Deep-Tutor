# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Gson / JSON (dio, models)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }

# Secure storage & biometrics
-keep class androidx.security.crypto.** { *; }
-keep class androidx.biometric.** { *; }

# Razorpay (Phase 2)
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/*
-keepclasseswithmembers class * {
  public void onPayment*(...);
}
