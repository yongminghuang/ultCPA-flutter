package com.xmzj.ult.agg

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import com.tencent.mm.opensdk.modelbiz.WXLaunchMiniProgram
import com.tencent.mm.opensdk.openapi.WXAPIFactory
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MineActionsBridge(private val activity: Activity) {
    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "openCustomerServiceMiniProgram" -> {
                        openCustomerServiceMiniProgram(
                            call.argument<String>("url").orEmpty(),
                            result,
                        )
                    }
                    "createAppUpdateDownloadPath" ->
                        result.success(createAppUpdateDownloadPath())
                    "installAppUpdateApk" -> {
                        installAppUpdateApk(call.argument<String>("path").orEmpty())
                        result.success(null)
                    }
                    "openAppUpdateUrl" -> {
                        openAppUpdateUrl(call.argument<String>("url").orEmpty())
                        result.success(null)
                    }
                    "openApplicationMarket" -> {
                        openApplicationMarket()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: IllegalArgumentException) {
                result.error("invalid_argument", error.message, null)
            } catch (error: Throwable) {
                result.error(
                    "mine_action_error",
                    error.message ?: "Mine action failed",
                    null,
                )
            }
        }
    }

    private fun openCustomerServiceMiniProgram(
        h5Url: String,
        result: MethodChannel.Result,
    ) {
        require(h5Url.isNotEmpty()) { "url must not be empty" }
        val api = WXAPIFactory.createWXAPI(activity, WECHAT_APP_ID)
        if (!api.isWXAppInstalled) {
            result.error("wechat_not_installed", "未安装微信", null)
            return
        }
        val request = WXLaunchMiniProgram.Req().apply {
            userName = "gh_61681409b61c"
            path = CUSTOMER_PATH_PREFIX + Uri.encode(h5Url)
            miniprogramType = if (BuildConfig.FLAVOR == "dev") {
                WXLaunchMiniProgram.Req.MINIPROGRAM_TYPE_PREVIEW
            } else {
                WXLaunchMiniProgram.Req.MINIPTOGRAM_TYPE_RELEASE
            }
        }
        if (!api.sendReq(request)) {
            result.error(
                "wechat_launch_failed",
                "暂时无法打开微信客服",
                null,
            )
            return
        }
        result.success(null)
    }

    private fun createAppUpdateDownloadPath(): String {
        val directory = appUpdateDirectory()
        val fileName =
            "${activity.packageName}_${BuildConfig.VERSION_NAME}_" +
                "${UUID.randomUUID().toString().take(4)}.apk"
        val file = File(directory, fileName).canonicalFile
        require(file.parentFile == directory) { "Update path escapes the update directory" }
        return file.absolutePath
    }

    private fun appUpdateDirectory(): File {
        val directory = requireNotNull(
            activity.getExternalFilesDir(APP_UPDATE_DIRECTORY),
        ) { "External update directory is unavailable" }.canonicalFile
        check(directory.exists() || directory.mkdirs()) {
            "Could not create the update directory"
        }
        return directory
    }

    private fun installAppUpdateApk(path: String) {
        require(path.isNotBlank()) { "Update APK path is empty" }
        val directory = appUpdateDirectory()
        val file = File(path).canonicalFile
        require(file.parentFile == directory) { "Update APK is outside the update directory" }
        require(file.exists() && file.isFile) { "Update APK does not exist" }
        require(file.extension.equals("apk", ignoreCase = true)) {
            "Update file is not an APK"
        }
        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, APK_MIME_TYPE)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(intent)
    }

    private fun openAppUpdateUrl(rawUrl: String) {
        require(rawUrl.isNotBlank()) { "Update URL is empty" }
        val uri = Uri.parse(rawUrl)
        require(uri.scheme == "http" || uri.scheme == "https") {
            "Update URL must use HTTP or HTTPS"
        }
        activity.startActivity(Intent(Intent.ACTION_VIEW, uri))
    }

    private fun openApplicationMarket() {
        try {
            val marketUrl = "market://details?id=" + activity.packageName
            activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(marketUrl)))
        } catch (_: ActivityNotFoundException) {
            val fallbackUrl =
                "http://a.app.qq.com/o/simple.jsp?pkgname=" + activity.packageName
            activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(fallbackUrl)))
        }
    }

    companion object {
        private const val CHANNEL = "com.xmzj.ult.agg/mine_actions"
        private const val APP_UPDATE_DIRECTORY = "update"
        private const val APK_MIME_TYPE = "application/vnd.android.package-archive"
        private const val WECHAT_APP_ID = "wx8d51616821867104"
        private const val CUSTOMER_PATH_PREFIX =
            "pages/mine/customer-qr-page?url="
    }
}
