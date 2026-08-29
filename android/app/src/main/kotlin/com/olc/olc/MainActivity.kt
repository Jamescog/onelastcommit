package com.olc.olc

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "olc/foreground")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bringToFront" -> {
                        // Custom Tabs have no dismiss API. Relaunching this
                        // singleTop activity with CLEAR_TOP finishes anything
                        // above it in its own task — the device-flow tab — and
                        // resumes the app. Permitted from the background because
                        // this activity sits in the foreground task's back stack.
                        startActivity(
                            Intent(this, MainActivity::class.java).addFlags(
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                            )
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
