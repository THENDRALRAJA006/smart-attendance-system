package com.smartattend.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register Android Keystore MethodChannel (EC P-256 signing for device binding)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            KeystorePlugin.CHANNEL,
        ).setMethodCallHandler(KeystorePlugin())
    }
}
