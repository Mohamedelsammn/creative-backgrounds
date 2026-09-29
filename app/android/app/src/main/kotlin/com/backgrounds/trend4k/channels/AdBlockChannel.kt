package com.backgrounds.trend4k.channels

import android.content.Context
import com.backgrounds.trend4k.adblock.NetworkInterferenceProbe
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Exposes [NetworkInterferenceProbe] to Flutter.
 *
 * Returns raw signals only - `vpnActive`, `privateDnsHost`,
 * `privateDnsFiltering` - and never a verdict. Deciding what those signals mean
 * belongs in one place (the Dart service), not split across two languages.
 *
 * A probe failure resolves with an empty map rather than an error, so detection
 * degrades to "unknown" instead of surfacing a platform exception to the user.
 */
class AdBlockChannel(private val context: Context) :
    MethodChannel.MethodCallHandler {

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "inspectNetwork" -> {
                val signals = runCatching {
                    NetworkInterferenceProbe.inspect(context)
                }.getOrElse { emptyMap() }
                result.success(signals)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        private const val CHANNEL = "com.backgrounds.trend4k/adblock"
    }
}
