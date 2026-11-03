package dev.wayday.wayday

import android.app.Activity
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class GatewayBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "wayday/gateway")
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var disposed = false
    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "buildInfo" -> {
                    val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
                    result.success(mapOf(
                        "version" to info.versionName,
                        "versionCode" to if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode.toString() else info.versionCode.toString(),
                        "channel" to if (activity.packageName.endsWith(".publictest")) "Wayday Test" else "Wayday"
                    ))
                }
                "token" -> executor.execute {
                    try {
                        val token = GatewayAccess.token(activity)
                        main.post { if (!disposed) result.success(token) }
                    } catch (_: Exception) {
                        main.post { if (!disposed) result.error("access", "App verification is unavailable", null) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    fun dispose() { disposed = true; channel.setMethodCallHandler(null); executor.shutdown() }
}
