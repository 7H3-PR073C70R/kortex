# ==============================================================================
# KORTEX ANDROID R8 / PROGUARD RULES
# ==============================================================================

# 1. ML Kit Text Recognition keep & dontwarn rules
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.**

# 2. Flutter Engine & Plugin Embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# 3. Native JNI Bindings Safety
-keepclasseswithmembernames class * {
    native <methods>;
}

# 4. Drift & SQLite3 Native Bindings Safety
-keep class com.simonoid.sqlite3.** { *; }
-keep class org.sqlite.** { *; }
-keep class io.requery.android.database.sqlite.** { *; }
-dontwarn com.simonoid.sqlite3.**

# 5. LiveKit & WebRTC Reflection Safety
-keep class livekit.** { *; }
-keep class io.livekit.** { *; }
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
-dontwarn io.livekit.**
-dontwarn com.cloudwebrtc.webrtc.**

# 6. RevenueCat / Purchases Flutter SDK Reflection
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# 7. Firebase, Crashlytics & Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# 8. Kotlin Coroutines & Attributes
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn kotlin.coroutines.**
