# ProGuard/R8 rules for release builds.
#
# The Flutter Gradle plugin already ships sensible defaults for the Flutter
# engine; the rules below only cover the third-party plugins we actually use.

# --- flutter_secure_storage ---------------------------------------------------
# The plugin resolves classes reflectively at runtime; without keep rules R8
# strips them and reads/writes crash with NoSuchMethodError.
-keep class io.flutter.plugins.securestorage.** { *; }

# --- print_bluetooth_thermal --------------------------------------------------
# Same story: the plugin invokes native Bluetooth classes via method channels.
-keep class app.web.groons.print_bluetooth_thermal.** { *; }
-keep class android.bluetooth.** { *; }

# --- mobile_scanner (barcode camera) -----------------------------------------
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn com.google.mlkit.**

# --- Kotlin / coroutines -----------------------------------------------------
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlin.Metadata { public <methods>; }
