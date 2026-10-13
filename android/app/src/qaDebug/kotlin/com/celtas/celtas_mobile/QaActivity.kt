package com.celtas.celtas_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin
import io.flutter.plugins.urllauncher.UrlLauncherPlugin
import com.github.dart_lang.jni.JniPlugin
import com.github.dart_lang.jni_flutter.JniFlutterPlugin

/** QA never attaches the generated registrant's production plugins. */
class QaActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Initialize JVM/class loader before Dart FFI looks up any Java class.
        flutterEngine.plugins.add(JniPlugin())
        // Provide application context/activity for the shared Dart JNI bindings.
        flutterEngine.plugins.add(JniFlutterPlugin())
        flutterEngine.plugins.add(PackageInfoPlugin())
        flutterEngine.plugins.add(UrlLauncherPlugin())
    }
}
