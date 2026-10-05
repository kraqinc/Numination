package com.wren.ide.numination

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "numination/gmail"
        const val GMAIL_PACKAGE = "com.google.android.gm"
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "openGmail" -> {
                    try {
                        val launchIntent =
                            packageManager.getLaunchIntentForPackage(
                                GMAIL_PACKAGE
                            )

                        if (launchIntent == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }

                        launchIntent.addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK
                        )

                        startActivity(launchIntent)

                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
