package com.xmzj.ult.agg.wxapi

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.tencent.mm.opensdk.modelbase.BaseReq
import com.tencent.mm.opensdk.modelbase.BaseResp
import com.tencent.mm.opensdk.openapi.IWXAPI
import com.tencent.mm.opensdk.openapi.IWXAPIEventHandler
import com.tencent.mm.opensdk.openapi.WXAPIFactory

/** Receives WeChat callbacks for friend and timeline shares. */
class WXEntryActivity : Activity(), IWXAPIEventHandler {
    private lateinit var api: IWXAPI

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        api = WXAPIFactory.createWXAPI(this, WECHAT_APP_ID)
        if (!api.handleIntent(intent, this)) {
            finish()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (!api.handleIntent(intent, this)) {
            finish()
        }
    }

    override fun onReq(req: BaseReq) {
        finish()
    }

    override fun onResp(resp: BaseResp) {
        finish()
    }

    companion object {
        private const val WECHAT_APP_ID = "wx8d51616821867104"
    }
}
