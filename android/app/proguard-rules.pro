# Preserve Google Mobile Ads SDK classes
-keep public class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.measurement.** { *; }
-keep class com.google.android.gms.ads.identifier.** { *; }

# Preserve Firebase analytics/remote config integration
-keep class com.google.firebase.** { *; }
-keep interface com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.core.** { *; }
-keep class io.flutter.plugins.firebase.analytics.** { *; }

# Preserve audioplayers plugin bindings
-keep class xyz.luan.audioplayers.** { *; }

# Keep services with onTaskRemoved callbacks invoked via reflection
-keepclassmembers class * extends android.app.Service {
    public void onTaskRemoved(android.content.Intent);
}
