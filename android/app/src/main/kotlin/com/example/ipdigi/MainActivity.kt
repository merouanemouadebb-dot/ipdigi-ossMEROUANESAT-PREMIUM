package com.example.ipdigi

import android.app.UiModeManager
import android.content.Context
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var isTv = false

    // Android TV (leanback): if the device is a TV, lock the activity to landscape.
    // Otherwise the app starts in portrait; in portrait the logical width is
    // <600, so the Flutter side mistakes the device for a "phone", applies the
    // portrait lock, and never uses the TV's wide screen (content stayed in a
    // narrow column in the middle). Phones/tablets are not affected by this.
    override fun onCreate(savedInstanceState: Bundle?) {
        val uiMode = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        isTv = uiMode.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
        if (isTv) {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        }
        super.onCreate(savedInstanceState)
    }

    // The Flutter side reads this info and skips the portrait lock and the
    // narrow layout breakpoint on TV (see main.dart / app_shell.dart).
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.ipdigi/platform",
        ).setMethodCallHandler { call, result ->
            if (call.method == "isTv") {
                result.success(isTv)
            } else {
                result.notImplemented()
            }
        }
    }
}
