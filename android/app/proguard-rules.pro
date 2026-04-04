-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class dev.flutter.plugins.** { *; }
-keep class dev.flutter.pigeon.** { *; }

# Keep specific plugins
-keep class com.tekartik.sqflite.** { *; }
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.work.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class vn.hunghd.flutterdownloader.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }

-dontwarn com.arthenica.ffmpegkit.**
-dontwarn io.flutter.**
-dontwarn dev.flutter.**
