package dev.wayday.wayday

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.net.URI
import java.util.concurrent.Executors

class SharingBridge(private val activity: FlutterFragmentActivity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "wayday/sharing")
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pendingStart: Pair<JSONObject, MethodChannel.Result>? = null
    private var disposed = false
    private var initialLink: String? = acceptedLink(activity.intent)
    init {
        channel.setMethodCallHandler { call, result ->
            if (!BuildConfig.WAYDAY_SHARING) { result.error("unavailable", "Sharing is unavailable.", null); return@setMethodCallHandler }
            when (call.method) {
                "initialLink" -> { result.success(initialLink); initialLink = null }
                "navigationSource" -> {
                    val values = call.arguments as? Map<*, *>
                    val lease = values?.get("session") as? String
                    if (lease != null) SharingLocationService.navigationSource(values["source"] as? String, lease)
                    result.success(null)
                }
                "broadcastStatus" -> worker(result) {
                    val saved = JSONObject(SharingStorage.read(activity, true))
                    mapOf("active" to SharingLocationService.active,
                        "shareId" to saved.optString("shareId").takeIf { it.isNotEmpty() },
                        "role" to saved.optString("role").takeIf { it.isNotEmpty() },
                        "revocationPending" to (!SharingLocationService.active && saved.has("token")))
                }
                "readStorage" -> worker(result) { SharingStorage.read(activity) }
                "writeStorage" -> worker(result) {
                    val text = call.arguments as? String ?: error("Invalid storage")
                    JSONObject(text)
                    SharingStorage.write(activity, text)
                    null
                }
                "share" -> {
                    val url = call.arguments as? String
                    if (url == null || !validLink(url)) result.error("invalid_link", "This link is unavailable.", null)
                    else {
                        val send = Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_TEXT, url) }
                        activity.startActivity(Intent.createChooser(send, null)); result.success(null)
                    }
                }
                "startBroadcast" -> {
                    try {
                        check(pendingStart == null && !activity.isFinishing)
                        val values = call.arguments as? Map<*, *> ?: error("Invalid broadcast")
                        val config = JSONObject(values)
                        check(config.getString("shareId").matches(Regex("[a-f0-9-]{36}")))
                        check(config.getString("token").matches(Regex("[A-Za-z0-9_-]{43}")))
                        check(config.getLong("expiresAt") > System.currentTimeMillis() / 1000)
                        check(config.getInt("broadcastRevision") > 0)
                        check(config.getString("role") in listOf("owner", "recipient"))
                        val fine = ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                        val coarse = ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                        check(fine || coarse)
                        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            pendingStart = config to result
                            ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS), permissionCode)
                        } else start(config, result)
                    } catch (_: Exception) { result.error("location", "Allow location and notifications to start sharing.", null) }
                }
                "stopBroadcast" -> {
                    SharingLocationService.stopLocal(activity)
                    worker(result) { SharingLocationService.revokePending(activity); null }
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun start(config: JSONObject, result: MethodChannel.Result) {
        try {
            check(activity.lifecycle.currentState.isAtLeast(androidx.lifecycle.Lifecycle.State.RESUMED))
            check(GatewayAccess.configured())
            check(!SharingLocationService.active)
            check(!JSONObject(SharingStorage.read(activity, true)).has("token"))
            // Persist before dispatch: interruption requires revocation, never automatic restart.
            SharingStorage.write(activity, config.toString(), true)
            ContextCompat.startForegroundService(activity, Intent(activity, SharingLocationService::class.java)
                .setAction(SharingLocationService.startAction).putExtra("configuration", config.toString()))
            result.success(null)
        } catch (_: Exception) { result.error("location", "Live sharing could not start. Stop sharing before retrying.", null) }
    }
    fun permissions(code: Int, grants: IntArray) {
        if (code != permissionCode) return
        val pending = pendingStart ?: return
        pendingStart = null
        if (grants.firstOrNull() == PackageManager.PERMISSION_GRANTED) start(pending.first, pending.second)
        else pending.second.error("notification", "Allow notifications so Stop sharing stays available.", null)
    }
    fun onIntent(intent: Intent) { acceptedLink(intent)?.let { channel.invokeMethod("openLink", it) } }
    private fun acceptedLink(intent: Intent?): String? = intent?.dataString?.takeIf(::validLink)
    private fun validLink(value: String): Boolean = runCatching {
        val uri = URI(value); val origin = URI(BuildConfig.WAYDAY_GATEWAY_URL)
        uri.scheme == "https" && uri.host == origin.host && uri.port == origin.port && uri.userInfo == null && uri.rawQuery == null &&
            uri.path in listOf("/share/", "/pair/") && uri.fragment?.matches(Regex("[a-f0-9-]{36}\\.[A-Za-z0-9_-]{43}")) == true
    }.getOrDefault(false)
    private fun worker(result: MethodChannel.Result, task: () -> Any?) {
        executor.execute { try { val value = task(); main.post { if (!disposed) result.success(value) } }
            catch (_: Exception) { main.post { if (!disposed) result.error("sharing", "Sharing could not be updated. Please retry.", null) } } }
    }
    fun dispose() { disposed = true; pendingStart?.second?.error("closed", "Sharing was interrupted.", null); pendingStart = null; channel.setMethodCallHandler(null); executor.shutdown() }
    companion object { const val permissionCode = 7601 }
}
