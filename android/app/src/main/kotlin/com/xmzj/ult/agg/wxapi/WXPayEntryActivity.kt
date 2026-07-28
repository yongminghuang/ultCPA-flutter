package com.xmzj.ult.agg.wxapi

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.tencent.mm.opensdk.modelbase.BaseReq
import com.tencent.mm.opensdk.modelbase.BaseResp
import com.tencent.mm.opensdk.openapi.IWXAPI
import com.tencent.mm.opensdk.openapi.IWXAPIEventHandler
import com.tencent.mm.opensdk.openapi.WXAPIFactory
import com.xmzj.ult.agg.VipPaymentBridge

class WXPayEntryActivity : Activity(), IWXAPIEventHandler {
    private lateinit var api: IWXAPI

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        api = WXAPIFactory.createWXAPI(this, WECHAT_APP_ID)
        api.handleIntent(intent, this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        api.handleIntent(intent, this)
    }

    override fun onReq(req: BaseReq) = Unit

    override fun onResp(resp: BaseResp) {
        when (resp.errCode) {
            BaseResp.ErrCode.ERR_OK ->
                VipPaymentBridge.completeWechatPayment("success")
            BaseResp.ErrCode.ERR_USER_CANCEL ->
                VipPaymentBridge.completeWechatPayment("cancelled")
            else -> VipPaymentBridge.completeWechatPayment(
                "failed",
                resp.errStr?.takeIf { it.isNotBlank() } ?: "支付失败",
            )
        }
        finish()
    }

    companion object {
        private const val WECHAT_APP_ID = "wx8d51616821867104"
    }
}
