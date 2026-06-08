# Proguard/R8 rules for IQ-Market

# 1. Flutter base preservation rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.iqmarket.app.** { *; }

# 2. Preserve essential attributes for reflection/serialization
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# 3. Firebase & Firestore specific rules
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.android.gms.internal.** { *; }

# 4. Suppress warnings from common libraries
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animalsniffer.**
-dontwarn com.google.android.play.core.**

# 5. Keep custom model classes if reflection is used
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.PropertyName <methods>;
}
