package com.xmzj.ult.agg

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.tencent.mm.opensdk.modelmsg.SendMessageToWX
import com.tencent.mm.opensdk.modelmsg.WXImageObject
import com.tencent.mm.opensdk.modelmsg.WXMediaMessage
import com.tencent.mm.opensdk.modelmsg.WXWebpageObject
import com.tencent.mm.opensdk.openapi.IWXAPI
import com.tencent.mm.opensdk.openapi.WXAPIFactory
import com.tencent.mmkv.MMKV
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.EnumMap

class PromotionSharingBridge(private val activity: Activity) {
    private var pendingSave: PendingSave? = null
    private var wechatApi: IWXAPI? = null

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "readPromotionProfile" -> readProfile(call, result)
                    "savePromotionProfile" -> saveProfile(call, result)
                    "createPromotionQrCode" -> createQrCode(call, result)
                    "shareWechatImage" -> shareWechatImage(call, result)
                    "shareWechatWebpage" -> shareWechatWebpage(call, result)
                    "savePromotionImage" -> saveImage(call, result)
                    else -> result.notImplemented()
                }
            } catch (error: IllegalArgumentException) {
                result.error("invalid_argument", error.message, null)
            } catch (error: Throwable) {
                result.error(
                    "promotion_sharing_failed",
                    error.message ?: "操作失败",
                    null,
                )
            }
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != STORAGE_PERMISSION_REQUEST) return false
        val pending = pendingSave ?: return true
        pendingSave = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            try {
                saveImageBytes(pending.bytes)
                pending.result.success(null)
            } catch (error: Throwable) {
                pending.result.error(
                    "save_image_failed",
                    error.message ?: "保存图片失败",
                    null,
                )
            }
        } else {
            pending.result.error("permission_denied", "保存图片需要存储权限", null)
        }
        return true
    }

    private fun readProfile(call: MethodCall, result: MethodChannel.Result) {
        val appKv = requireNotNull(MMKV.mmkvWithID("App"))
        val fallbackName = call.argument<String>("fallbackName").orEmpty()
        val fallbackPhone = call.argument<String>("fallbackPhone").orEmpty()
        result.success(
            mapOf(
                "name" to appKv.decodeString(PROFILE_NAME_KEY, fallbackName).orEmpty(),
                "phone" to appKv.decodeString(PROFILE_PHONE_KEY, fallbackPhone).orEmpty(),
            ),
        )
    }

    private fun saveProfile(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name").orEmpty().trim().take(10)
        val phone = call.argument<String>("phone").orEmpty().trim().take(11)
        val appKv = requireNotNull(MMKV.mmkvWithID("App"))
        check(appKv.encode(PROFILE_NAME_KEY, name)) { "姓名保存失败" }
        check(appKv.encode(PROFILE_PHONE_KEY, phone)) { "联系电话保存失败" }
        result.success(null)
    }

    private fun createQrCode(call: MethodCall, result: MethodChannel.Result) {
        val content = call.argument<String>("content").orEmpty().trim()
        require(content.isNotEmpty()) { "二维码内容为空" }
        val size = (call.argument<Int>("size") ?: 360).coerceIn(120, 1200)
        val hints = EnumMap<EncodeHintType, Any>(EncodeHintType::class.java).apply {
            put(EncodeHintType.CHARACTER_SET, "UTF-8")
            put(EncodeHintType.ERROR_CORRECTION, ErrorCorrectionLevel.M)
            put(EncodeHintType.MARGIN, 1)
        }
        val matrix = QRCodeWriter().encode(
            content,
            BarcodeFormat.QR_CODE,
            size,
            size,
            hints,
        )
        val pixels = IntArray(size * size)
        for (y in 0 until size) {
            for (x in 0 until size) {
                pixels[y * size + x] = if (matrix[x, y]) Color.BLACK else Color.WHITE
            }
        }
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        bitmap.setPixels(pixels, 0, size, 0, 0, size, size)
        result.success(bitmap.toPngBytes())
        bitmap.recycle()
    }

    private fun shareWechatImage(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        require(bytes != null && bytes.isNotEmpty()) { "海报图片为空" }
        val api = requireWechat(result) ?: return
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw IllegalArgumentException("海报图片无效")
        val message = WXMediaMessage(WXImageObject(bytes)).apply {
            thumbData = createThumbnail(bitmap)
        }
        bitmap.recycle()
        sendWechat(
            api,
            message,
            timeline = call.argument<Boolean>("timeline") == true,
            result = result,
        )
    }

    private fun shareWechatWebpage(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url").orEmpty().trim()
        require(url.startsWith("https://") || url.startsWith("http://")) {
            "分享链接无效"
        }
        val api = requireWechat(result) ?: return
        val message = WXMediaMessage(WXWebpageObject().apply {
            webpageUrl = url
        }).apply {
            title = call.argument<String>("title").orEmpty().take(512)
            description = call.argument<String>("description").orEmpty().take(1024)
            thumbData = defaultWebpageThumbnail()
        }
        sendWechat(
            api,
            message,
            timeline = call.argument<Boolean>("timeline") == true,
            result = result,
        )
    }

    private fun sendWechat(
        api: IWXAPI,
        mediaMessage: WXMediaMessage,
        timeline: Boolean,
        result: MethodChannel.Result,
    ) {
        val request = SendMessageToWX.Req().apply {
            transaction = "promotion_${System.currentTimeMillis()}"
            message = mediaMessage
            scene = if (timeline) {
                SendMessageToWX.Req.WXSceneTimeline
            } else {
                SendMessageToWX.Req.WXSceneSession
            }
        }
        if (!api.sendReq(request)) {
            result.error("wechat_share_failed", "微信分享调起失败", null)
            return
        }
        result.success(null)
    }

    private fun saveImage(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        require(bytes != null && bytes.isNotEmpty()) { "海报图片为空" }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            check(pendingSave == null) { "已有保存任务正在处理" }
            pendingSave = PendingSave(bytes, result)
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                STORAGE_PERMISSION_REQUEST,
            )
            return
        }
        saveImageBytes(bytes)
        result.success(null)
    }

    private fun saveImageBytes(bytes: ByteArray) {
        val resolver = activity.contentResolver
        val values = ContentValues().apply {
            put(
                MediaStore.Images.Media.DISPLAY_NAME,
                "ultcpa_promotion_${System.currentTimeMillis()}.png",
            )
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_PICTURES + "/ultCPA",
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: error("无法创建相册图片")
        try {
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: error("无法写入相册图片")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                resolver.update(
                    uri,
                    ContentValues().apply {
                        put(MediaStore.Images.Media.IS_PENDING, 0)
                    },
                    null,
                    null,
                )
            }
        } catch (error: Throwable) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    private fun requireWechat(result: MethodChannel.Result): IWXAPI? {
        val api = wechatApi ?: WXAPIFactory.createWXAPI(
            activity.applicationContext,
            WECHAT_APP_ID,
        ).also {
            it.registerApp(WECHAT_APP_ID)
            wechatApi = it
        }
        if (!api.isWXAppInstalled) {
            result.error("wechat_not_installed", "您没有安装微信", null)
            return null
        }
        return api
    }

    private fun createThumbnail(source: Bitmap): ByteArray {
        val ratio = minOf(THUMB_SIZE.toFloat() / source.width, THUMB_SIZE.toFloat() / source.height, 1f)
        val width = (source.width * ratio).toInt().coerceAtLeast(1)
        val height = (source.height * ratio).toInt().coerceAtLeast(1)
        val scaled = Bitmap.createScaledBitmap(source, width, height, true)
        var quality = 90
        var bytes: ByteArray
        do {
            val output = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, quality, output)
            bytes = output.toByteArray()
            quality -= 10
        } while (bytes.size > MAX_THUMB_BYTES && quality >= 30)
        if (scaled !== source) scaled.recycle()
        return bytes
    }

    private fun defaultWebpageThumbnail(): ByteArray {
        val bitmap = Bitmap.createBitmap(120, 120, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.rgb(255, 138, 0))
        val bytes = bitmap.toPngBytes()
        bitmap.recycle()
        return bytes
    }

    private fun Bitmap.toPngBytes(): ByteArray {
        return ByteArrayOutputStream().use { output ->
            check(compress(Bitmap.CompressFormat.PNG, 100, output)) {
                "图片编码失败"
            }
            output.toByteArray()
        }
    }

    private data class PendingSave(
        val bytes: ByteArray,
        val result: MethodChannel.Result,
    )

    companion object {
        private const val CHANNEL = "com.xmzj.ult.agg/promotion_sharing"
        private const val WECHAT_APP_ID = "wx8d51616821867104"
        private const val PROFILE_NAME_KEY = "flutterPromotionName"
        private const val PROFILE_PHONE_KEY = "flutterPromotionPhone"
        private const val STORAGE_PERMISSION_REQUEST = 9301
        private const val THUMB_SIZE = 150
        private const val MAX_THUMB_BYTES = 32 * 1024
    }
}
