package com.xmzj.ult.agg

import android.content.Intent
import android.net.Uri
import com.tencent.mmkv.MMKV
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var promotionSharingBridge: PromotionSharingBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MMKV.initialize(applicationContext)
        LegacyStartupBridge(this).register(flutterEngine)
        SettingsBridge(this).register(flutterEngine)
        AccountSafetyBridge(this).register(flutterEngine)
        MineActionsBridge(this).register(flutterEngine)
        VipPaymentBridge(this).register(flutterEngine)
        promotionSharingBridge = PromotionSharingBridge(this).also {
            it.register(flutterEngine)
        }
        val appKv = requireNotNull(MMKV.mmkvWithID("App"))
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LEGACY_STARTUP_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAcceptedPrivacy" ->
                    result.success(appKv.decodeBool("setAgreeRule", false))
                "acceptPrivacy" -> {
                    appKv.encode("setAgreeRule", true)
                    result.success(null)
                }
                "openAgreement" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.error("invalid_url", "Agreement URL is empty", null)
                    } else {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (::promotionSharingBridge.isInitialized &&
            promotionSharingBridge.onRequestPermissionsResult(
                requestCode,
                permissions,
                grantResults,
            )
        ) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    companion object {
        private const val LEGACY_STARTUP_CHANNEL =
            "com.xmzj.ult.agg/legacy_startup"
    }
}
