package com.aniscroll.aniscroll

import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "aniscroll/pip"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterPip" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                            result.error("PIP_UNSUPPORTED", "Picture-in-picture requires Android 8.0 or newer.", null)
                            return@setMethodCallHandler
                        }

                        val width = (call.argument<Int>("width") ?: 16).coerceAtLeast(1)
                        val height = (call.argument<Int>("height") ?: 9).coerceAtLeast(1)
                        try {
                            val params = PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(width, height))
                                .build()
                            val entered = enterPictureInPictureMode(params)
                            if (entered) {
                                result.success(true)
                            } else {
                                result.error("PIP_NOT_ENTERED", "Android could not enter picture-in-picture mode.", null)
                            }
                        } catch (error: IllegalArgumentException) {
                            result.error("PIP_INVALID_RATIO", error.message, null)
                        } catch (error: Exception) {
                            result.error("PIP_FAILED", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
