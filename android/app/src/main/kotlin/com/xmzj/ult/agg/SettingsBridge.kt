package com.xmzj.ult.agg

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.webkit.WebStorage
import android.webkit.WebView
import com.tencent.mmkv.MMKV
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class SettingsBridge(private val context: Context) {
    private val userKv = requireNotNull(MMKV.mmkvWithID("User"))
    private val adKv = requireNotNull(MMKV.mmkvWithID("ad"))

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "readSettings" -> result.success(
                        mapOf(
                            "notificationEnabled" to userKv.decodeBool(
                                "NotificationEnabled",
                                true,
                            ),
                            "personalizedRecommendations" to adKv.decodeBool(
                                "setIndividuation",
                                true,
                            ),
                        ),
                    )
                    "setNotificationEnabled" -> {
                        userKv.encode("NotificationEnabled", requiredEnabled(call.argument("enabled")))
                        result.success(null)
                    }
                    "setPersonalizedRecommendations" -> {
                        adKv.encode("setIndividuation", requiredEnabled(call.argument("enabled")))
                        result.success(null)
                    }
                    "clearCaches" -> {
                        clearCaches()
                        result.success(null)
                    }
                    "openStoreRating" -> {
                        openStoreRating()
                        result.success(null)
                    }
                    "openExternalUrl" -> {
                        openExternalUrl(call.argument<String>("url").orEmpty())
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: IllegalArgumentException) {
                result.error("invalid_argument", error.message, null)
            } catch (error: Throwable) {
                result.error("settings_error", error.message ?: "Settings action failed", null)
            }
        }
    }

    private fun requiredEnabled(value: Boolean?): Boolean {
        return requireNotNull(value) { "enabled must be a boolean" }
    }

    private fun clearCaches() {
        File(context.cacheDir, "ACache").deleteRecursively()
        WebStorage.getInstance().deleteAllData()
        val webView = WebView(context)
        try {
            webView.clearCache(true)
            webView.clearHistory()
        } finally {
            webView.destroy()
        }
    }

    private fun openStoreRating() {
        val packageName = context.packageName
        val marketIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("market://details?id=$packageName"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(marketIntent)
        } catch (_: Throwable) {
            context.startActivity(
                Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("https://play.google.com/store/apps/details?id=$packageName"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    private fun openExternalUrl(rawUrl: String) {
        val uri = Uri.parse(rawUrl)
        val scheme = uri.scheme?.lowercase().orEmpty()
        require((scheme == "http" || scheme == "https") && !uri.host.isNullOrBlank()) {
            "Only HTTP(S) URLs are supported"
        }
        context.startActivity(
            Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    companion object {
        private const val CHANNEL = "com.xmzj.ult.agg/settings"
    }
}
