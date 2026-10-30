package dev.wayday.wayday

import android.app.Activity
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import java.security.MessageDigest
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Private-installation bridge. Never exposes credentials to Dart or logs bodies. */
class PlanningBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "wayday/planning")
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var disposed = false
    private val journal = InterpretationJournal(File(activity.noBackupFilesDir, "gemini-interpretations.bin"))
    private val clarificationJournal = InterpretationJournal(File(activity.noBackupFilesDir, "gemini-clarifications.bin"), 32)
    private companion object { val requestLock = Any() }
    private val alias = "wayday.gemini.private-installation.v1"
    fun refreshCredential() {
        executor.execute { try { credential() } catch (_: Exception) { /* No credential output. */ } }
    }
    fun dispose() {
        disposed = true
        channel.setMethodCallHandler(null)
        // Finish an already dispatched bounded request and save its answer even
        // when its Flutter screen/engine has gone away. Never restart it here.
        executor.shutdown()
    }
    init {
        executor.execute { try { credential() } catch (_: Exception) { /* Configuration stays unavailable. */ } }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "seedInterpretationFixture" -> {
                    if (!activity.packageName.endsWith(".maptest") ||
                        activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) {
                        result.notImplemented()
                    } else executor.execute {
                        synchronized(requestLock) {
                            try {
                                val args = call.arguments as Map<*, *>
                                val key = fingerprint(args["body"] as String)
                                val state = args["state"] as String
                                require(state in setOf("pending", "completed"))
                                val response = args["response"] as? String
                                val purpose = args["purpose"] as? String ?: "interpretation"
                                require(purpose in setOf("interpretation", "clarification"))
                                val fixtureJournal = if (purpose == "clarification") clarificationJournal else journal
                                fixtureJournal.put(InterpretationJournal.Entry(key, state, response))
                                main.post { if (!disposed) result.success(null) }
                            } catch (_: Exception) { main.post { if (!disposed) result.error("fixture", "Cache fixture unavailable", null) } }
                        }
                    }
                }
                "checkInterpretationJournal" -> {
                    if (!activity.packageName.endsWith(".maptest") ||
                        activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) {
                        result.notImplemented()
                    } else executor.execute {
                        try {
                            val directory = File(activity.cacheDir, "interpretation-journal-check").apply { mkdirs() }
                            val file = File(directory, "fixture.bin")
                            try {
                                file.delete()
                                val key = "a".repeat(64)
                                val first = InterpretationJournal(file)
                                first.put(InterpretationJournal.Entry(key, "pending"))
                                check(InterpretationJournal(file).find(key)?.state == "pending")
                                first.put(InterpretationJournal.Entry(key, "completed", response = "{\"fixture\":true}"))
                                check(InterpretationJournal(file).find(key)?.response == "{\"fixture\":true}")
                                repeat(9) { index -> first.put(InterpretationJournal.Entry(index.toString(16).padStart(64, '0'), "failed")) }
                                check(InterpretationJournal(file).find(key) == null)
                                check(InterpretationJournal(file).find("8".padStart(64, '0'))?.state == "failed")
                                file.writeText("corrupt fixture")
                                check(runCatching { InterpretationJournal(file).find(key) }.isFailure)
                                first.put(InterpretationJournal.Entry(key, "pending"), recoverCorrupt = true)
                                check(InterpretationJournal(file).find(key)?.state == "pending")
                                main.post { if (!disposed) result.success(true) }
                            } finally {
                                file.delete()
                                File(directory, "fixture.bin.pending").delete()
                                directory.delete()
                            }
                        } catch (_: Exception) { main.post { if (!disposed) result.error("fixture", "Journal fixture failed", null) } }
                    }
                }
                "identity" -> try { result.success(identity()) }
                    catch (_: Exception) { result.error("identity", "Signing identity unavailable", null) }
                "geminiStatus", "interpretationStatus", "invalidateInterpretation", "interpret" -> executor.execute {
                    synchronized(requestLock) {
                        var attemptKey: String? = null
                        var requestJournal = journal
                        var providerResponseReceived = false
                        try {
                            if (call.method == "geminiStatus") {
                                val key = credential()
                                main.post { if (!disposed) result.success(mapOf("configured" to !key.isNullOrEmpty(), "model" to "gemini-3.1-flash-lite")) }
                                return@synchronized
                            }
                            val args = call.arguments as? Map<*, *> ?: throw IllegalArgumentException()
                            val purpose = args["purpose"] as? String ?: "interpretation"
                            require(purpose in setOf("interpretation", "clarification"))
                            requestJournal = if (purpose == "clarification") clarificationJournal else journal
                            val body = args["body"] as? String ?: throw IllegalArgumentException()
                            val cacheKey = fingerprint(body)
                            if (call.method == "invalidateInterpretation") {
                                if (requestJournal.find(cacheKey) != null) {
                                    requestJournal.put(InterpretationJournal.Entry(cacheKey, "failed", failure = "invalid_response"))
                                }
                                main.post { if (!disposed) result.success(null) }
                                return@synchronized
                            }
                            val retry = args["retry"] == true
                            val saved = try { requestJournal.find(cacheKey) } catch (error: IOException) {
                                if (!retry || call.method != "interpret") throw error
                                null
                            }
                            // A recovered installation may have its original task database
                            // but no understanding requestJournal. Never silently spend to replace it.
                            val recovery = File(activity.noBackupFilesDir, "interpretation-recovery-retry-required")
                            val recoveryMissing = purpose == "interpretation" && saved == null && recovery.exists()
                            if (call.method == "interpretationStatus") {
                                main.post { if (!disposed) result.success(mapOf("state" to (saved?.state ?: if (recoveryMissing) "recovery" else "missing"), "response" to saved?.response)) }
                                return@synchronized
                            }
                            if (saved?.state == "completed") {
                                main.post { if (!disposed) result.success(saved.response) }
                                return@synchronized
                            }
                            if ((saved != null || recoveryMissing) && !retry) {
                                val code = if (saved?.state == "pending") "interrupted" else "previous_failure"
                                main.post { if (!disposed) result.error(code, "An explicit retry is required", null) }
                                return@synchronized
                            }
                            val key = credential()
                            if (key.isNullOrEmpty()) {
                                main.post { if (!disposed) result.error("configuration", "Gemini is not configured on this device", null) }
                                return@synchronized
                            }
                            // Fail closed if durable pending state or accounting cannot be saved.
                            requestJournal.put(InterpretationJournal.Entry(cacheKey, "pending"), recoverCorrupt = retry)
                            attemptKey = cacheKey
                            val connection = URL("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent").openConnection() as HttpURLConnection
                            try {
                                connection.requestMethod = "POST"
                                connection.connectTimeout = 10000
                                connection.readTimeout = 20000
                                connection.setRequestProperty("Content-Type", "application/json")
                                connection.setRequestProperty("x-goog-api-key", key)
                                connection.doOutput = true
                                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
                                val status = connection.responseCode
                                if (status == 200) {
                                    // Bounded read: never accumulate an unbounded provider response.
                                    val bytes = connection.inputStream.use { it.readBytesBounded(150000) }
                                    val data = String(bytes, Charsets.UTF_8)
                                    providerResponseReceived = true
                                    requestJournal.put(InterpretationJournal.Entry(cacheKey, "completed", response = data))
                                    if (purpose == "interpretation") recovery.delete()
                                    main.post { if (!disposed) result.success(data) }
                                } else {
                                    providerResponseReceived = true
                                    val kind = when (status) { 401,403 -> "access";429 -> "quota";else -> "unavailable" }
                                    requestJournal.put(InterpretationJournal.Entry(cacheKey, "failed", failure = kind))
                                    main.post { if (!disposed) result.error(kind, "Gemini could not interpret these errands", null) }
                                }
                            } finally { connection.disconnect() }
                        } catch (_: IOException) {
                            // Pending stays durable if completion could not be saved. Do not resend.
                            val code = if (attemptKey != null && !providerResponseReceived) "connection" else "cache"
                            main.post { if (!disposed) result.error(code, "Understanding is unavailable; no automatic retry was sent", null) }
                        } catch (_: Exception) {
                            if (attemptKey != null) {
                                try { requestJournal.put(InterpretationJournal.Entry(attemptKey, "failed", failure = "unavailable")) } catch (_: Exception) { }
                            }
                            main.post { if (!disposed) result.error("unavailable", "Gemini interpretation is unavailable", null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun fingerprint(body: String): String {
        require(body.toByteArray(Charsets.UTF_8).size <= 50000)
        val request = JSONObject(body)
        val config = request.getJSONObject("generationConfig")
        require(config.getInt("maxOutputTokens") in 1..4096)
        require(config.optInt("candidateCount", 1) == 1)
        require(!request.has("tools") && !request.has("cachedContent"))
        return MessageDigest.getInstance("SHA-256")
            .digest(("wayday-interpretation-v2|gemini-3.1-flash-lite|" + body).toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
    }
    private fun java.io.InputStream.readBytesBounded(limit: Int): ByteArray {
        val output = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(4096)
        while (true) {
            val count = read(buffer)
            if (count == -1) break
            require(output.size() + count <= limit)
            output.write(buffer, 0, count)
        }
        return output.toByteArray()
    }
    @Suppress("DEPRECATION")
    private fun identity(): Map<String,String> {
        val signatures = if (Build.VERSION.SDK_INT >= 28) {
            activity.packageManager.getPackageInfo(activity.packageName, PackageManager.GET_SIGNING_CERTIFICATES).signingInfo!!.apkContentsSigners
        } else {
            activity.packageManager.getPackageInfo(activity.packageName, PackageManager.GET_SIGNATURES).signatures!!
        }
        val sha1 = MessageDigest.getInstance("SHA-1").digest(signatures.first().toByteArray()).joinToString("") { "%02X".format(it) }
        return mapOf("package" to activity.packageName, "certificate" to sha1)
    }
    private fun secretKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (store.containsAlias(alias)) return store.getKey(alias, null) as SecretKey
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        return generator.generateKey()
    }
    private fun credential(): String? {
        val encrypted = File(activity.noBackupFilesDir, "gemini-credential.json")
        val provision = File(activity.filesDir, "wayday-private-gemini.json")
        val debug = activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        if (debug && provision.exists()) {
            try {
                require(provision.length() in 1..4096)
                val value = JSONObject(provision.readText()).getString("key")
                require(value.length in 20..300 && !value.any { it.isWhitespace() })
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(Cipher.ENCRYPT_MODE, secretKey())
                val payload = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
                encrypted.parentFile?.mkdirs()
                val pending = File(encrypted.parentFile, encrypted.name + ".pending")
                pending.writeText(JSONObject().put("iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
                    .put("data", Base64.encodeToString(payload, Base64.NO_WRAP))
                    .toString())
                check(pending.renameTo(encrypted))
            } finally { provision.delete() }
        }
        // This credential path is intentionally restricted to the private debug pilot.
        // Public/release builds require a separately qualified managed service boundary.
        if (!debug || !encrypted.exists()) return null
        val value = JSONObject(encrypted.readText())
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, Base64.decode(value.getString("iv"), Base64.NO_WRAP)))
        return String(cipher.doFinal(Base64.decode(value.getString("data"), Base64.NO_WRAP)), Charsets.UTF_8)
    }
}
