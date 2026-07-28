package com.xmzj.ult.agg

import android.content.Context
import android.preference.PreferenceManager
import com.tencent.mmkv.MMKV
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class AccountSafetyBridge(private val context: Context) {
    private val dataKv = requireNotNull(MMKV.mmkvWithID("mmkvLazy"))
    private val userKv = requireNotNull(MMKV.mmkvWithID("User"))
    private val preferences = PreferenceManager.getDefaultSharedPreferences(context)

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "readAccountSafety" -> result.success(
                        mapOf(
                            "isLoggedIn" to dataKv.decodeBool("key_sp_islogin", false),
                            "phone" to dataKv.decodeString("key_sp_mobile", "").orEmpty(),
                        ),
                    )
                    "readAccountProfile" -> result.success(
                        mapOf(
                            "isLoggedIn" to dataKv.decodeBool("key_sp_islogin", false),
                            "userId" to preferences.getString("userIdString", "").orEmpty(),
                            "nickname" to dataKv.decodeString("key_sp_nickname", "").orEmpty(),
                            "avatar" to dataKv.decodeString("key_sp_facepath", "").orEmpty(),
                        ),
                    )
                    "clearDeactivatedSession" -> {
                        clearDeactivatedSession()
                        result.success(null)
                    }
                    "clearSignedOutSession" -> {
                        clearSignedOutSession()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error(
                    "account_safety_error",
                    error.message ?: "Account safety action failed",
                    null,
                )
            }
        }
    }

    private fun clearDeactivatedSession() {
        clearLegacyAccountSession()
    }

    private fun clearSignedOutSession() {
        clearLegacyAccountSession()
    }

    private fun clearLegacyAccountSession() {
        listOf(
            "key_sp_authorization",
            "key_sp_mobile",
            "key_sp_nickname",
            "key_sp_facepath",
            "key_sp_islogin",
            "key_sp_is_vip",
            "key_mmkv_user_benefits_json",
            "key_mmkv_static_ad_vip_close",
            "key_mmkv_static_login_history_info",
        ).forEach(dataKv::removeValueForKey)
        dataKv.encode("key_sp_last_login_type", "")
        userKv.encode("LogOut", true)

        check(
            preferences.edit()
                .putString("userIdString", "")
                .putInt("isTemp", 1)
                .commit(),
        ) { "Could not clear legacy account preferences" }
    }

    companion object {
        private const val CHANNEL = "com.xmzj.ult.agg/account_safety"
    }
}
