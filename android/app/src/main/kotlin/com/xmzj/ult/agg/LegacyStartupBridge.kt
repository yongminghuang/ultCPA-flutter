package com.xmzj.ult.agg

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.preference.PreferenceManager
import android.provider.Settings
import android.util.Base64
import android.webkit.WebSettings
import androidx.core.content.FileProvider
import com.tencent.mmkv.MMKV
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.charset.StandardCharsets
import java.security.KeyFactory
import java.security.SecureRandom
import java.security.Signature
import java.security.spec.PKCS8EncodedKeySpec
import java.security.spec.X509EncodedKeySpec
import java.security.interfaces.RSAPublicKey
import java.util.TreeMap
import java.util.concurrent.atomic.AtomicLong
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import org.json.JSONObject

class LegacyStartupBridge(private val context: Context) {
    private val appKv = requireNotNull(MMKV.mmkvWithID("App"))
    private val dataKv = requireNotNull(MMKV.mmkvWithID("mmkvLazy"))

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getApiBaseUrl" -> result.success(apiBaseUrl())
                    "buildRequestHeaders" -> result.success(buildRequestHeaders())
                    "buildDeviceLoginBody" -> result.success(buildDeviceLoginBody())
                    "persistSession" -> {
                        persistSession(
                            call.argument<String>("accessToken").orEmpty(),
                            call.argument<String>("userId").orEmpty(),
                        )
                        result.success(null)
                    }
                    "persistPhoneSession" -> {
                        persistPhoneSession(
                            call.argument<String>("accessToken").orEmpty(),
                            call.argument<Map<*, *>>("user") ?: emptyMap<Any, Any>(),
                        )
                        result.success(null)
                    }
                    "persistStaticConfiguration" -> {
                        persistStaticConfiguration(
                            call.argument<Map<*, *>>("values") ?: emptyMap<Any, Any>(),
                        )
                        result.success(null)
                    }
                    "persistMineReferralProfile" -> {
                        persistMineReferralProfile(
                            call.argument<String>("userRole").orEmpty(),
                            call.argument<String>("commissionRate").orEmpty(),
                        )
                        result.success(null)
                    }
                    "persistAppUpdateCheckTimestamp" -> {
                        val millis = call.argument<Number>("millis")?.toLong()
                            ?: throw IllegalArgumentException("App update timestamp is missing")
                        require(millis > 0L) { "App update timestamp must be positive" }
                        appKv.encode(LAST_PROACTIVE_VERSION_CHECK_AT, millis)
                        result.success(null)
                    }
                    "readAppSnapshot" -> result.success(readAppSnapshot())
                    "getChapterPracticeExpandedCatalog" -> {
                        val moduleId = requiredPositiveArgument(call.argument<Int>("moduleId"), "moduleId")
                        result.success(appKv.decodeInt(chapterExpandedCatalogKey(moduleId), -1))
                    }
                    "setChapterPracticeExpandedCatalog" -> {
                        val moduleId = requiredPositiveArgument(call.argument<Int>("moduleId"), "moduleId")
                        val catalogIndex = requiredNonNegativeArgument(
                            call.argument<Int>("catalogIndex"),
                            "catalogIndex",
                        )
                        appKv.encode(chapterExpandedCatalogKey(moduleId), catalogIndex)
                        result.success(null)
                    }
                    "getChapterPracticeQuestionPosition" -> {
                        val moduleId = requiredPositiveArgument(call.argument<Int>("moduleId"), "moduleId")
                        val catalogIndex = requiredNonNegativeArgument(
                            call.argument<Int>("catalogIndex"),
                            "catalogIndex",
                        )
                        val chapterIndex = requiredNonNegativeArgument(
                            call.argument<Int>("chapterIndex"),
                            "chapterIndex",
                        )
                        result.success(
                            appKv.decodeInt(
                                chapterQuestionPositionKey(moduleId, catalogIndex, chapterIndex),
                                0,
                            ),
                        )
                    }
                    "setChapterPracticeQuestionPosition" -> {
                        val moduleId = requiredPositiveArgument(call.argument<Int>("moduleId"), "moduleId")
                        val catalogIndex = requiredNonNegativeArgument(
                            call.argument<Int>("catalogIndex"),
                            "catalogIndex",
                        )
                        val chapterIndex = requiredNonNegativeArgument(
                            call.argument<Int>("chapterIndex"),
                            "chapterIndex",
                        )
                        val position = requiredNonNegativeArgument(
                            call.argument<Int>("position"),
                            "position",
                        )
                        appKv.encode(
                            chapterQuestionPositionKey(moduleId, catalogIndex, chapterIndex),
                            position,
                        )
                        result.success(null)
                    }
                    "getFlatPracticeQuestionPosition" -> {
                        val shelfId = requiredPositiveArgument(
                            call.argument<Int>("shelfId"),
                            "shelfId",
                        )
                        result.success(appKv.decodeInt(flatQuestionPositionKey(shelfId), 0))
                    }
                    "setFlatPracticeQuestionPosition" -> {
                        val shelfId = requiredPositiveArgument(
                            call.argument<Int>("shelfId"),
                            "shelfId",
                        )
                        val position = requiredNonNegativeArgument(
                            call.argument<Int>("position"),
                            "position",
                        )
                        appKv.encode(flatQuestionPositionKey(shelfId), position)
                        result.success(null)
                    }
                    "readTeacherCourseIndex" -> {
                        val subject = call.argument<String>("subject").orEmpty().trim()
                        require(subject.isNotEmpty()) { "Teacher course subject is missing" }
                        result.success(appKv.decodeInt("teacher_course_play_index_$subject", 0))
                    }
                    "writeTeacherCourseIndex" -> {
                        val subject = call.argument<String>("subject").orEmpty().trim()
                        require(subject.isNotEmpty()) { "Teacher course subject is missing" }
                        val index = requiredNonNegativeArgument(
                            call.argument<Int>("index"),
                            "index",
                        )
                        appKv.encode("teacher_course_play_index_$subject", index)
                        result.success(null)
                    }
                    "readTeacherCoursePosition" -> {
                        val mediaId = requiredPositiveArgument(
                            call.argument<Int>("mediaId"),
                            "mediaId",
                        )
                        result.success(appKv.decodeLong("seekbarnow$mediaId", 0L))
                    }
                    "writeTeacherCoursePosition" -> {
                        val mediaId = requiredPositiveArgument(
                            call.argument<Int>("mediaId"),
                            "mediaId",
                        )
                        val milliseconds = call.argument<Number>("milliseconds")?.toLong()
                            ?: throw IllegalArgumentException("Teacher course position is missing")
                        require(milliseconds >= 0L) { "Teacher course position must not be negative" }
                        appKv.encode("seekbarnow$mediaId", milliseconds)
                        result.success(null)
                    }
                    "readDailySkillProgressJson" ->
                        result.success(appKv.decodeString(dailySkillProgressKey(), "").orEmpty())
                    "writeDailySkillProgressJson" -> {
                        val json = call.argument<String>("json")
                            ?: throw IllegalArgumentException("Daily skill progress JSON is missing")
                        appKv.encode(dailySkillProgressKey(), json)
                        result.success(null)
                    }
                    "readDailySkillCheckInJson" ->
                        result.success(appKv.decodeString(dailySkillCheckInKey(), "").orEmpty())
                    "writeDailySkillCheckInJson" -> {
                        val json = call.argument<String>("json")
                            ?: throw IllegalArgumentException("Daily skill check-in JSON is missing")
                        appKv.encode(dailySkillCheckInKey(), json)
                        result.success(null)
                    }
                    "createPreExamSixPaperDownloadPath" -> {
                        val fileName = call.argument<String>("fileName")
                            ?: throw IllegalArgumentException("Download file name is missing")
                        result.success(createPreExamSixPaperDownloadPath(fileName))
                    }
                    "sharePreExamSixPaperFile" -> {
                        val path = call.argument<String>("path")
                            ?: throw IllegalArgumentException("Share file path is missing")
                        val mimeType = call.argument<String>("mimeType").orEmpty()
                        sharePreExamSixPaperFile(path, mimeType)
                        result.success(null)
                    }
                    "getWrongRemovalThreshold" ->
                        result.success(learnPreferences().getInt(REMOVE_ERROR_NUMBER, -1))
                    "setWrongRemovalThreshold" -> {
                        val threshold = call.argument<Int>("threshold")
                            ?: throw IllegalArgumentException("Wrong removal threshold is missing")
                        require(threshold == -1 || threshold in 1..7) {
                            "Wrong removal threshold must be -1 or between 1 and 7"
                        }
                        learnPreferences().edit()
                            .putInt(REMOVE_ERROR_NUMBER, threshold)
                            .commit()
                        result.success(null)
                    }
                    "recordWrongQuestionCorrect" -> {
                        val questionId = call.argument<String>("questionId").orEmpty()
                        result.success(recordWrongQuestionCorrect(questionId))
                    }
                    "getPracticeSettings" -> {
                        val preferences = learnPreferences()
                        result.success(
                            mapOf(
                                "autoNext" to preferences.getBoolean(PRACTICE_AUTO_NEXT, true),
                                "playCorrectSound" to preferences.getBoolean(PRACTICE_PLAY_VOICE, true),
                                "explainWrongAutomatically" to preferences.getBoolean(PRACTICE_WRONG_AUDIO, true),
                                "fontSize" to preferences.getInt(PRACTICE_FONT_SIZE, 1),
                                "themeMode" to preferences.getInt(PRACTICE_THEME, 0),
                            ),
                        )
                    }
                    "setPracticeSettings" -> {
                        val fontSize = call.argument<Int>("fontSize") ?: 1
                        val themeMode = call.argument<Int>("themeMode") ?: 0
                        require(fontSize in -1..2) { "Practice font size must be between -1 and 2" }
                        require(themeMode in 0..2) { "Practice theme must be between 0 and 2" }
                        check(
                            learnPreferences().edit()
                                .putBoolean(PRACTICE_AUTO_NEXT, call.argument<Boolean>("autoNext") ?: true)
                                .putBoolean(PRACTICE_PLAY_VOICE, call.argument<Boolean>("playCorrectSound") ?: true)
                                .putBoolean(PRACTICE_WRONG_AUDIO, call.argument<Boolean>("explainWrongAutomatically") ?: true)
                                .putInt(PRACTICE_FONT_SIZE, fontSize)
                                .putInt(PRACTICE_THEME, themeMode)
                                .commit(),
                        ) { "Could not persist practice settings" }
                        result.success(null)
                    }
                    "persistCategorySelection" -> {
                        persistCategorySelection(
                            call.argument<String>("categoryBodyJson").orEmpty(),
                            call.argument<String>("category").orEmpty(),
                            call.argument<Map<*, *>>("selectedCategory")
                                ?: emptyMap<Any, Any>(),
                            call.argument<String>("selectedCategoryKey").orEmpty(),
                            call.argument<Int>("marketId") ?: -1,
                            call.argument<String>("subject").orEmpty(),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error("request_context", error.message, null)
            }
        }
    }

    private fun createPreExamSixPaperDownloadPath(fileName: String): String {
        require(fileName.isNotBlank()) { "Download file name is empty" }
        val leaf = File(fileName)
        require(!leaf.isAbsolute && leaf.name == fileName) {
            "Download file name must be a leaf name"
        }
        val directory = preExamSixPaperDownloadDirectory()
        val file = File(directory, fileName).canonicalFile
        require(file.parentFile == directory) { "Download path escapes the cache directory" }
        return file.absolutePath
    }

    private fun preExamSixPaperDownloadDirectory(): File {
        val cacheRoot = (context.externalCacheDir ?: context.cacheDir).canonicalFile
        val directory = File(cacheRoot, PRE_EXAM_SIX_PAPER_DIRECTORY).canonicalFile
        require(directory.toPath().startsWith(cacheRoot.toPath())) {
            "Download directory escapes the cache root"
        }
        check(directory.exists() || directory.mkdirs()) {
            "Could not create the download directory"
        }
        return directory
    }

    private fun sharePreExamSixPaperFile(path: String, mimeType: String) {
        require(path.isNotBlank()) { "Share file path is empty" }
        val file = File(path).canonicalFile
        require(file.exists() && file.isFile) { "Share file does not exist" }
        val cacheRoots = listOfNotNull(context.externalCacheDir, context.cacheDir)
            .map { it.canonicalFile }
        require(cacheRoots.any { root -> file.toPath().startsWith(root.toPath()) }) {
            "Share file is outside the app cache"
        }
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )
        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType.ifBlank { "*/*" }
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(shareIntent, null))
    }

    private fun apiBaseUrl(): String =
        if (BuildConfig.FLAVOR == "dev") TEST_API_BASE_URL else PROD_API_BASE_URL

    private fun buildRequestHeaders(): Map<String, String> {
        check(appKv.decodeBool("setAgreeRule", false)) {
            "Privacy consent is required before building request headers"
        }
        val timestamp = nextRequestTimestamp().toString()
        val common = TreeMap<String, String>().apply {
            put("X-Device-Brand", Build.BRAND.orEmpty())
            put("X-Device-ID", encryptedAndroidId())
            put("X-Market-Source", BuildConfig.ULTCPA_CHANNEL)
            put("X-App-OS", "Android")
            put("timestamp", timestamp)
            put("X-App-Version", BuildConfig.VERSION_NAME)
        }
        val signatureInput = common.entries.joinToString("&") { "${it.key}=${it.value}" }
        return LinkedHashMap(common).apply {
            put("X-sign", sign(signatureInput))
            put("X-Timestamp", timestamp)
            put("X-category", appKv.decodeString("category", "social-work").orEmpty())
            put("X-Platform-App-ID", "f4773dbe93c8")
            dataKv.decodeString("key_sp_authorization", "")
                ?.takeIf { it.isNotBlank() }
                ?.let { put("Authorization", it) }
        }
    }

    private fun buildDeviceLoginBody(): Map<String, String> {
        check(appKv.decodeBool("setAgreeRule", false)) {
            "Privacy consent is required before hardware login"
        }
        val payload = linkedMapOf<String, String>(
            "deviceId" to androidId(),
            "adTrackingId" to "",
            "brand" to Build.BRAND.orEmpty(),
            "model" to Build.MODEL.orEmpty(),
            "modelNumber" to Build.MODEL.orEmpty(),
            "os" to "Android",
            "systemVersion" to Build.VERSION.RELEASE.orEmpty(),
            "appVersion" to BuildConfig.VERSION_NAME,
            "platformAppId" to "f4773dbe93c8",
            "marketSource" to BuildConfig.ULTCPA_CHANNEL,
            "ua" to WebSettings.getDefaultUserAgent(context).orEmpty(),
            "ip" to "",
        )
        val publicKey = KeyFactory.getInstance("RSA").generatePublic(
            X509EncodedKeySpec(Base64.decode(HARDWARE_PUBLIC_KEY, Base64.DEFAULT)),
        )
        val encrypted = encryptRsaPkcs1(
            JSONObject(payload as Map<*, *>).toString().toByteArray(StandardCharsets.UTF_8),
            publicKey as RSAPublicKey,
        )
        return mapOf(
            "params" to Base64.encodeToString(encrypted, Base64.NO_WRAP),
            "timestamp" to System.currentTimeMillis().toString(),
        )
    }

    private fun encryptRsaPkcs1(input: ByteArray, publicKey: RSAPublicKey): ByteArray {
        val maxPlaintextBlock = (publicKey.modulus.bitLength() + 7) / 8 - 11
        val output = ByteArrayOutputStream()
        var offset = 0
        while (offset < input.size) {
            val blockSize = minOf(maxPlaintextBlock, input.size - offset)
            val cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding")
            cipher.init(Cipher.ENCRYPT_MODE, publicKey)
            output.write(cipher.doFinal(input, offset, blockSize))
            offset += blockSize
        }
        return output.toByteArray()
    }

    private fun persistSession(accessToken: String, userId: String) {
        require(accessToken.isNotBlank()) { "Access token is empty" }
        require(userId.isNotBlank()) { "User ID is empty" }
        dataKv.encode("key_sp_authorization", accessToken)
        PreferenceManager.getDefaultSharedPreferences(context)
            .edit()
            .putString("userIdString", userId)
            .commit()
    }

    private fun persistPhoneSession(accessToken: String, user: Map<*, *>) {
        val userId = user["id"]?.toString().orEmpty()
        persistSession(accessToken, userId)
        dataKv.encode("key_sp_mobile", user["phone"]?.toString().orEmpty())
        dataKv.encode("key_sp_user_role", user["userRole"]?.toString().orEmpty())
        dataKv.encode("key_sp_nickname", user["nickName"]?.toString().orEmpty())
        dataKv.encode("key_sp_facepath", user["avatar"]?.toString().orEmpty())
        dataKv.encode("key_sp_islogin", true)
        dataKv.encode("key_sp_last_login_type", "last_login_dx")
        val tempStatus = (user["tempStatus"] as? Number)?.toInt()
            ?: user["tempStatus"]?.toString()?.toIntOrNull()
            ?: 0
        PreferenceManager.getDefaultSharedPreferences(context)
            .edit()
            .putInt("isTemp", tempStatus)
            .commit()
    }

    private fun persistStaticConfiguration(values: Map<*, *>) {
        val textValues = values.entries.associate { entry ->
            entry.key.toString() to entry.value?.toString().orEmpty()
        }
        fun text(key: String): String = textValues[key].orEmpty()
        appKv.encode("oss_domain", text("oss_domain"))
        appKv.encode("add_teacher_h5_url", text("add_teacher_h5_url"))
        appKv.encode("collect_book_h5_url", text("collect_book_h5_url"))
        appKv.encode("floating_window_url", text("floating_window_url"))
        appKv.encode(
            "skill_question_free_count",
            text("skill_question_free_count").toIntOrNull() ?: 0,
        )
        appKv.encode(
            "skill_formula_free_question_count",
            text("skill_formula_free_question_count").toIntOrNull() ?: 3,
        )
        appKv.encode(
            "chapter_question_free_count",
            (text("chapter_question_free_count").toIntOrNull() ?: 2).coerceAtLeast(0),
        )
        appKv.encode("static_default_category", text("default_category"))
        appKv.encode("static_exam_time_json", text("exam_time"))
        appKv.encode("app_category_name_mapping", text("app_category_name_mapping"))
        appKv.encode(
            "invite_fission_activity",
            text("invite_fission_activity").toIntOrNull() ?: 0,
        )
        persistHomeTopBanner(text("home_top_banner"))
    }

    private fun persistMineReferralProfile(userRole: String, commissionRate: String) {
        dataKv.encode("key_sp_user_role", userRole)
        dataKv.encode("key_sp_commission_rate", commissionRate)
    }

    private fun persistHomeTopBanner(rawJson: String) {
        appKv.encode("home_top_banner_json", rawJson)
        appKv.allKeys()?.forEach { key ->
            if (key.startsWith("home_top_banner_") &&
                key != "home_top_banner_fetched" &&
                key != "home_top_banner_json" &&
                !key.startsWith("home_top_banner_last_displayed_")) {
                appKv.removeValueForKey(key)
            }
        }
        if (rawJson.isBlank()) {
            appKv.encode("home_top_banner_fetched", true)
            return
        }
        val root = JSONObject(rawJson)
        val appTypes = root.keys()
        while (appTypes.hasNext()) {
            val appType = appTypes.next()
            val groups = root.optJSONArray(appType) ?: continue
            for (index in 0 until groups.length()) {
                val group = groups.optJSONObject(index) ?: continue
                val levels = group.keys()
                while (levels.hasNext()) {
                    val level = levels.next()
                    appKv.encode(
                        "home_top_banner_${appType}_$level",
                        group.optString(level, ""),
                    )
                }
            }
        }
        appKv.encode("home_top_banner_fetched", true)
    }

    private fun readAppSnapshot(): Map<String, Any> {
        val preferences = PreferenceManager.getDefaultSharedPreferences(context)
        val selectedCategoryJson = appKv.decodeString("selected_category_dto", "").orEmpty()
        val selectedLevel = try {
            JSONObject(selectedCategoryJson).optString("level", "")
        } catch (_: Throwable) {
            ""
        }
        val category = appKv.decodeString("category", "social-work").orEmpty()
        return linkedMapOf(
            "category" to category,
            "appChannel" to BuildConfig.ULTCPA_CHANNEL,
            "lastProactiveVersionCheckAt" to appKv.decodeLong(LAST_PROACTIVE_VERSION_CHECK_AT, 0L),
            "selectedCategoryJson" to selectedCategoryJson,
            "selectedCategoryKey" to appKv.decodeString("selected_category_key", "").orEmpty(),
            "selectedLevel" to selectedLevel,
            "selectedMarketId" to appKv.decodeInt("accounting_selected_market_id", -1),
            "selectedSubject" to appKv.decodeString(
                "accounting_selected_km_subject_temp_media",
                "",
            ).orEmpty(),
            "categoryBodyJson" to appKv.decodeString(
                "accounting_category_body_json",
                "",
            ).orEmpty(),
            "showWxPay" to appKv.decodeBool("showWxPay", true),
            "defaultPayType" to preferences.getInt(
                "module_loginandpay_default_pay",
                1,
            ),
            "userBenefitsJson" to dataKv.decodeString(
                "key_mmkv_user_benefits_json",
                "",
            ).orEmpty(),
            "staticDefaultCategory" to appKv.decodeString(
                "static_default_category",
                "",
            ).orEmpty(),
            "appCategoryNameMappingJson" to appKv.decodeString(
                "app_category_name_mapping",
                "",
            ).orEmpty(),
            "ossDomain" to appKv.decodeString("oss_domain", "").orEmpty(),
            "homeTopBannerJson" to appKv.decodeString("home_top_banner_json", "").orEmpty(),
            "homeTopBannerUrl" to appKv.decodeString(
                "home_top_banner_${category}_$selectedLevel",
                "",
            ).orEmpty(),
            "examTimeJson" to appKv.decodeString("static_exam_time_json", "").orEmpty(),
            "collectBookH5Url" to appKv.decodeString("collect_book_h5_url", "").orEmpty(),
            "inviteFissionActivity" to appKv.decodeInt("invite_fission_activity", 0),
            "skillFormulaFreeCount" to appKv.decodeInt("skill_formula_free_question_count", 3),
            "skillQuestionFreeCount" to appKv.decodeInt("skill_question_free_count", 5),
            "chapterQuestionFreeCount" to appKv.decodeInt("chapter_question_free_count", 2),
            "accessToken" to dataKv.decodeString("key_sp_authorization", "").orEmpty(),
            "userId" to preferences.getString("userIdString", "").orEmpty(),
            "phone" to dataKv.decodeString("key_sp_mobile", "").orEmpty(),
            "nickname" to dataKv.decodeString("key_sp_nickname", "").orEmpty(),
            "avatar" to dataKv.decodeString("key_sp_facepath", "").orEmpty(),
            "userRole" to dataKv.decodeString("key_sp_user_role", "").orEmpty(),
            "commissionRate" to dataKv.decodeString("key_sp_commission_rate", "").orEmpty(),
            "isTestEnvironment" to (BuildConfig.FLAVOR == "dev"),
            "isLoggedIn" to dataKv.decodeBool("key_sp_islogin", false),
        )
    }

    private fun persistCategorySelection(
        categoryBodyJson: String,
        category: String,
        selectedCategory: Map<*, *>,
        selectedCategoryKey: String,
        marketId: Int,
        subject: String,
    ) {
        require(category.isNotBlank()) { "Category is empty" }
        appKv.encode("accounting_category_body_json", categoryBodyJson)
        appKv.encode("accounting_category_body_update_time", System.currentTimeMillis())
        appKv.encode("category", category)
        appKv.encode("selected_category_dto", JSONObject(selectedCategory).toString())
        appKv.encode("selected_category_key", selectedCategoryKey)
        appKv.encode("accounting_selected_market_id", marketId)
        appKv.encode("accounting_selected_km_subject_temp_media", subject)
    }

    private fun learnPreferences() = context.getSharedPreferences(
        "learn_bank_${legacyUserId()}",
        Context.MODE_PRIVATE,
    )

    private fun legacyUserId(): String {
        val preferences = PreferenceManager.getDefaultSharedPreferences(context)
        val numericId = preferences.getInt("userId", 0)
        return if (numericId > 0) {
            numericId.toString()
        } else {
            preferences.getString("userIdString", "").orEmpty()
        }
    }

    private fun currentCategory(): String =
        appKv.decodeString("category", "social-work").orEmpty()

    private fun chapterExpandedCatalogKey(moduleId: Int): String =
        "${legacyUserId()}_${currentCategory()}_${moduleId}_chapter_practice_list_expanded_catalog"

    private fun chapterQuestionPositionKey(
        moduleId: Int,
        catalogIndex: Int,
        chapterIndex: Int,
    ): String =
        "${legacyUserId()}_${currentCategory()}_${moduleId}_${catalogIndex}_${chapterIndex}_learnQPos"

    private fun flatQuestionPositionKey(shelfId: Int): String =
        "${legacyUserId()}_${currentCategory()}_${shelfId}_flatLearnQPos"

    private fun legacyDailySkillUserId(): String = legacyUserId().ifBlank { "0" }

    private fun dailySkillProgressKey(): String =
        "daily_skill_progress_${legacyDailySkillUserId()}_${currentCategory()}"

    private fun dailySkillCheckInKey(): String =
        "daily_skill_checkin_${legacyDailySkillUserId()}_${currentCategory()}"

    private fun requiredPositiveArgument(value: Int?, name: String): Int {
        require(value != null && value > 0) { "$name must be positive" }
        return value
    }

    private fun requiredNonNegativeArgument(value: Int?, name: String): Int {
        require(value != null && value >= 0) { "$name must not be negative" }
        return value
    }

    private fun recordWrongQuestionCorrect(rawQuestionId: String): Boolean {
        val questionId = rawQuestionId.toLongOrNull()
            ?: throw IllegalArgumentException("Wrong question ID is invalid")
        require(questionId > 0) { "Wrong question ID must be positive" }
        val threshold = learnPreferences().getInt(REMOVE_ERROR_NUMBER, -1)
        if (threshold < 1) return false

        val databaseFile = context.getDatabasePath(LEARN_RECORD_DATABASE)
        if (databaseFile.exists()) {
            SQLiteDatabase.openDatabase(
                databaseFile.absolutePath,
                null,
                SQLiteDatabase.OPEN_READWRITE,
            ).use { database ->
                if (hasQuestionCountTable(database)) {
                    return recordWrongQuestionCorrect(database, questionId, threshold)
                }
            }
        }
        return recordWrongQuestionCorrectInPreferences(questionId, threshold)
    }

    private fun hasQuestionCountTable(database: SQLiteDatabase): Boolean {
        database.rawQuery(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
            arrayOf(QUESTION_COUNT_TABLE),
        ).use { cursor ->
            return cursor.moveToFirst()
        }
    }

    private fun recordWrongQuestionCorrect(
        database: SQLiteDatabase,
        questionId: Long,
        threshold: Int,
    ): Boolean {
        database.beginTransaction()
        try {
            val current = database.query(
                QUESTION_COUNT_TABLE,
                arrayOf(QUESTION_COUNT_COLUMN),
                "$QUESTION_ID_COLUMN = ?",
                arrayOf(questionId.toString()),
                null,
                null,
                null,
            ).use { cursor ->
                if (cursor.moveToFirst()) cursor.getInt(0) else 0
            }
            val next = current + 1
            val reached = next >= threshold
            if (reached) {
                database.delete(
                    QUESTION_COUNT_TABLE,
                    "$QUESTION_ID_COLUMN = ?",
                    arrayOf(questionId.toString()),
                )
            } else {
                val values = ContentValues().apply {
                    put(QUESTION_ID_COLUMN, questionId)
                    put(QUESTION_COUNT_COLUMN, next)
                }
                database.insertWithOnConflict(
                    QUESTION_COUNT_TABLE,
                    null,
                    values,
                    SQLiteDatabase.CONFLICT_REPLACE,
                )
            }
            database.setTransactionSuccessful()
            return reached
        } finally {
            database.endTransaction()
        }
    }

    private fun recordWrongQuestionCorrectInPreferences(
        questionId: Long,
        threshold: Int,
    ): Boolean {
        val preferences = learnPreferences()
        val key = "$FALLBACK_COUNT_PREFIX$questionId"
        val next = preferences.getInt(key, 0) + 1
        val reached = next >= threshold
        val editor = preferences.edit()
        if (reached) editor.remove(key) else editor.putInt(key, next)
        check(editor.commit()) { "Could not persist wrong-question count" }
        return reached
    }

    private fun androidId(): String {
        dataKv.decodeString(ANDROID_ID_KEY, "")
            ?.takeIf { it.isNotBlank() }
            ?.let { return it }
        val id = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ANDROID_ID,
        ).orEmpty()
        if (id.isNotBlank()) dataKv.encode(ANDROID_ID_KEY, id)
        return id
    }

    private fun encryptedAndroidId(): String {
        dataKv.decodeString(ENCRYPTED_ANDROID_ID_KEY, "")
            ?.takeIf { it.isNotBlank() }
            ?.let { return it }
        val nonce = ByteArray(12).also(SecureRandom()::nextBytes)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val key = SecretKeySpec(Base64.decode(DEVICE_AES_KEY, Base64.DEFAULT), "AES")
        cipher.init(Cipher.ENCRYPT_MODE, key, GCMParameterSpec(128, nonce))
        val encrypted = cipher.doFinal(androidId().toByteArray(StandardCharsets.UTF_8))
        val encoded = "v2:" + Base64.encodeToString(nonce + encrypted, Base64.NO_WRAP)
        dataKv.encode(ENCRYPTED_ANDROID_ID_KEY, encoded)
        return encoded
    }

    private fun sign(value: String): String {
        val keyBytes = Base64.decode(REQUEST_PRIVATE_KEY, Base64.NO_WRAP)
        val privateKey = KeyFactory.getInstance("RSA").generatePrivate(
            PKCS8EncodedKeySpec(keyBytes),
        )
        return Base64.encodeToString(
            Signature.getInstance("SHA256withRSA").run {
                initSign(privateKey)
                update(value.toByteArray(StandardCharsets.UTF_8))
                sign()
            },
            Base64.NO_WRAP,
        )
    }

    private fun nextRequestTimestamp(): Long {
        val millis = System.currentTimeMillis()
        val offset = REQUEST_COUNTER.getAndIncrement() % 1_000_000L
        return millis * 1_000_000L + offset
    }

    companion object {
        private const val REMOVE_ERROR_NUMBER = "removeErrorNumber"
        private const val PRACTICE_AUTO_NEXT = "autoNext"
        private const val PRACTICE_PLAY_VOICE = "PlayVoice"
        private const val PRACTICE_WRONG_AUDIO = "answerErrPushAudio"
        private const val PRACTICE_FONT_SIZE = "fontSize"
        private const val PRACTICE_THEME = "learnTheme"
        private const val LEARN_RECORD_DATABASE = "learnRecord"
        private const val QUESTION_COUNT_TABLE = "questionCount"
        private const val QUESTION_ID_COLUMN = "questionId"
        private const val QUESTION_COUNT_COLUMN = "countNum"
        private const val FALLBACK_COUNT_PREFIX = "flutter_question_count_"
        private const val PRE_EXAM_SIX_PAPER_DIRECTORY = "pre_exam_six_paper"
        private const val CHANNEL = "com.xmzj.ult.agg/request_context"
        private const val TEST_API_BASE_URL = "https://ult-test.xmzhujing.com"
        private const val PROD_API_BASE_URL = "https://ult.xmzhujing.com"
        private const val ANDROID_ID_KEY = "key_mmkv_system_android_id"
        private const val ENCRYPTED_ANDROID_ID_KEY = "key_mmkv_encrypted_android_id"
        private const val LAST_PROACTIVE_VERSION_CHECK_AT = "key_mmkv_last_proactive_version_check_at"
        private const val DEVICE_AES_KEY = "LI5YabR2bHYe3KCOCr881g=="
        private const val HARDWARE_PUBLIC_KEY =
            "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCIAo+zeoGoUOVqU/YySofFJLcefHsgYWJs3SZeV2D/pG6kuAlgI68CEptr1g1ch6nIf3D/qJM9DE3xOXqu1NHhU8I4JmmqN53lAgOknJZRQoGgthQV20DLy1bhAm3O1SPNU1pSJGwqXUKcovIeVYijS3kT9CrN/esSGi3zxWZCYwIDAQAB"
        private const val REQUEST_PRIVATE_KEY =
            "MIIBUwIBADANBgkqhkiG9w0BAQEFAASCAT0wggE5AgEAAkEAgzbixJfdG97o2o7HuynK6MW1fGf7ZiBqUHyA59hjna42VPMo0DomsS1WJNBBfghW3IhwA8sl9YMu8xxsn3ye4wIDAQABAkADG/zZrcOWknywGSwQelgNlgnL7ebeL6x1Rc4EMHOD3AFKKbsLTsGzDkBjqlcRYKMSFJ9rSSZkOM5WpAOaaRBJAiEAsCWnaEfRfIsnf4CARJl/uHmDQictOlFZDqu+96GlWB0CIQC+sqv8XUDFixRFbfWIj4YSe3epgjCEt+m+yIsT/o4i/wIgIoV+paVNnQb4mrhoawlaSqEl5FUhPAitV365UnbPnNECIBLXPkzJvduGmTMe4RJj88AhuLnjpf2G2i5CTBNmpA5rAiANUbD/1RqhDg5cs+GIcfQtvK/OobZIdRYRaly0mN3y7w=="
        private val REQUEST_COUNTER = AtomicLong(0)
    }
}
