package com.xmzj.ult.agg

import android.app.Activity
import com.alipay.sdk.app.PayTask
import com.tencent.mm.opensdk.modelpay.PayReq
import com.tencent.mm.opensdk.openapi.IWXAPI
import com.tencent.mm.opensdk.openapi.WXAPIFactory
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import java.util.concurrent.Executors

class VipPaymentBridge(private val activity: Activity) {
    private val executor = Executors.newSingleThreadExecutor()
    private var pendingWechatResult: MethodChannel.Result? = null
    private var alipayInFlight = false
    private var wechatApi: IWXAPI? = null

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isWechatInstalled" -> result.success(wechatApi().isWXAppInstalled)
                "payWechat" -> payWechat(call, result)
                "payAlipay" -> payAlipay(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun payWechat(call: MethodCall, result: MethodChannel.Result) {
        if (pendingWechatResult != null || alipayInFlight) {
            result.success(paymentResult("failed", "支付处理中"))
            return
        }
        val api = wechatApi()
        if (!api.isWXAppInstalled) {
            result.success(paymentResult("unavailable", "您没有安装微信"))
            return
        }
        val request = PayReq()
        try {
            request.appId = requiredString(call, "appId")
            request.partnerId = requiredString(call, "partnerId")
            request.prepayId = requiredString(call, "prepayId")
            request.nonceStr = requiredString(call, "nonceStr")
            request.timeStamp = requiredString(call, "timeStamp")
            request.packageValue = requiredString(call, "packageValue")
            request.sign = requiredString(call, "sign")
        } catch (error: IllegalArgumentException) {
            result.success(paymentResult("failed", error.message ?: "支付失败"))
            return
        }
        pendingWechatResult = result
        activeBridge = WeakReference(this)
        if (!api.sendReq(request)) {
            pendingWechatResult = null
            activeBridge = null
            result.success(paymentResult("failed", "微信支付调起失败"))
        }
    }

    private fun payAlipay(call: MethodCall, result: MethodChannel.Result) {
        if (pendingWechatResult != null || alipayInFlight) {
            result.success(paymentResult("failed", "支付处理中"))
            return
        }
        val orderInfo = call.argument<String>("orderInfo").orEmpty()
        if (orderInfo.isBlank()) {
            result.success(paymentResult("failed", "支付宝支付凭证为空"))
            return
        }
        alipayInFlight = true
        executor.execute {
            val response = try {
                val payResult = PayTask(activity).payV2(orderInfo.trim(), true)
                alipayResult(payResult["resultStatus"].orEmpty())
            } catch (error: Throwable) {
                paymentResult("failed", error.message?.takeIf { it.isNotBlank() } ?: "支付失败")
            }
            activity.runOnUiThread {
                alipayInFlight = false
                result.success(response)
            }
        }
    }

    private fun wechatApi(): IWXAPI {
        return wechatApi ?: WXAPIFactory.createWXAPI(
            activity.applicationContext,
            WECHAT_APP_ID,
        ).also {
            it.registerApp(WECHAT_APP_ID)
            wechatApi = it
        }
    }

    private fun finishWechatPayment(status: String, message: String?) {
        activity.runOnUiThread {
            val result = pendingWechatResult ?: return@runOnUiThread
            pendingWechatResult = null
            activeBridge = null
            result.success(paymentResult(status, message.orEmpty()))
        }
    }

    private fun requiredString(call: MethodCall, name: String): String {
        val value = call.argument<String>(name).orEmpty()
        require(value.isNotBlank()) { "$name is empty" }
        return value
    }

    private fun alipayResult(resultStatus: String): Map<String, String> {
        return when (resultStatus) {
            "9000" -> paymentResult("success")
            "6001" -> paymentResult("cancelled")
            "4000" -> paymentResult("failed", "支付失败，请检查是否安装支付宝4000")
            else -> paymentResult("failed", "支付失败$resultStatus")
        }
    }

    companion object {
        private const val CHANNEL = "com.xmzj.ult.agg/vip_payment"
        private const val WECHAT_APP_ID = "wx8d51616821867104"

        @Volatile
        private var activeBridge: WeakReference<VipPaymentBridge>? = null

        fun completeWechatPayment(status: String, message: String? = null) {
            activeBridge?.get()?.finishWechatPayment(status, message)
        }

        private fun paymentResult(
            status: String,
            message: String = "",
        ): Map<String, String> {
            return if (message.isBlank()) {
                mapOf("status" to status)
            } else {
                mapOf("status" to status, "message" to message)
            }
        }
    }
}
