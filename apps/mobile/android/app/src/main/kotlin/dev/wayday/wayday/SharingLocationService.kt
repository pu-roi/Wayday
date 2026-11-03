package dev.wayday.wayday

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.libraries.navigation.NavigationApi
import com.google.android.libraries.navigation.RoadSnappedLocationProvider
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/** Latest raw device fix shared with navigation. No history and no extra navigator. */
object SharingLocationHub {
    @Volatile var source: String? = null
    @Volatile var lease: String? = null
    @Volatile var latest: Location? = null
    fun publish(location: Location) { latest = Location(location) }
}

class SharingLocationService : Service(), LocationListener {
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private var configuration: JSONObject? = null
    private var manager: LocationManager? = null
    private var fallback = false
    private var googleProvider: RoadSnappedLocationProvider? = null
    private var googleListener: RoadSnappedLocationProvider.LocationListener? = null
    @Volatile private var generation = 0
    private var sending = false
    private var lastDispatch = 0L
    private var lastRecorded = 0L
    private val heartbeat = object : Runnable {
        override fun run() {
            val config = configuration ?: return
            if (System.currentTimeMillis() / 1000 >= config.getLong("expiresAt")) { stopLocal(this@SharingLocationService); return }
            if (SharingLocationHub.source == "google" && googleProvider == null) attachGoogle()
            if (SharingLocationHub.source != "google") detachGoogle()
            val fix = SharingLocationHub.latest
            // A navigating provider owns GPS even during a lost-fix interval.
            // Standalone sharing acquires GPS only after guidance releases it.
            val navigating = SharingLocationHub.source != null
            if (navigating && fallback) stopFallback()
            if (!navigating && !fallback) startFallback()
            if (fix != null && fresh(fix, 15000) && fix.time > lastRecorded && !sending && SystemClock.elapsedRealtime() - lastDispatch >= 15000) send(config, fix)
            main.postDelayed(this, 5000)
        }
    }
    override fun onCreate() { super.onCreate(); instance = this; manager = getSystemService(LocationManager::class.java) }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == stopAction) {
            stopLocal(this)
            executor.execute { runCatching { revokePending(applicationContext) } }
            return START_NOT_STICKY
        }
        if (!BuildConfig.WAYDAY_SHARING || intent?.action != startAction || configuration != null) { stopSelf(); return START_NOT_STICKY }
        try {
            val config = JSONObject(intent.getStringExtra("configuration") ?: error("Missing configuration"))
            check(config.getLong("expiresAt") > System.currentTimeMillis() / 1000)
            configuration = config
            val notifications = getSystemService(NotificationManager::class.java)
            check(Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)
            if (Build.VERSION.SDK_INT >= 26) notifications.createNotificationChannel(NotificationChannel(channelId, "Live trip sharing", NotificationManager.IMPORTANCE_LOW))
            val stop = PendingIntent.getService(this, 0, Intent(this, SharingLocationService::class.java).setAction(stopAction), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val open = PendingIntent.getActivity(this, 1, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val notification = NotificationCompat.Builder(this, channelId)
                .setSmallIcon(android.R.drawable.ic_menu_mylocation).setContentTitle("Wayday is sharing your location")
                .setContentText("Tap Stop sharing to end your live broadcast.")
                .setOngoing(true).setContentIntent(open).addAction(0, "Stop sharing", stop).build()
            if (Build.VERSION.SDK_INT >= 29) startForeground(notificationId, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            else startForeground(notificationId, notification)
            active = true; main.post(heartbeat)
        } catch (_: Exception) { stopLocal(this) }
        return START_NOT_STICKY
    }
    private fun attachGoogle() {
        try {
            val provider = NavigationApi.getRoadSnappedLocationProvider(application) ?: return
            val listener = object : RoadSnappedLocationProvider.LocationListener {
                override fun onLocationChanged(location: Location) { /* Only raw device fixes are shared. */ }
                override fun onRawLocationUpdate(location: Location) { if (active && SharingLocationHub.source == "google") SharingLocationHub.publish(location) }
            }
            provider.addLocationListener(listener); googleProvider = provider; googleListener = listener
        } catch (_: Exception) { detachGoogle() }
    }
    private fun detachGoogle() { googleListener?.let { runCatching { googleProvider?.removeLocationListener(it) } }; googleListener = null; googleProvider = null }
    private fun fresh(fix: Location, maximumAge: Long): Boolean {
        val age = SystemClock.elapsedRealtimeNanos() - fix.elapsedRealtimeNanos
        val clockAge = System.currentTimeMillis() - fix.time
        return age in 0..maximumAge * 1000000 && clockAge in 0..maximumAge && fix.hasAccuracy() && fix.accuracy.isFinite()
    }
    private fun startFallback() {
        try {
            val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
            if (!fine && !coarse) { stopLocal(this); return }
            val provider = if (fine && manager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true) LocationManager.GPS_PROVIDER else LocationManager.NETWORK_PROVIDER
            manager?.requestLocationUpdates(provider, 15000L, 0f, this, Looper.getMainLooper()); fallback = true
        } catch (_: Exception) { stopFallback() }
    }
    private fun stopFallback() { runCatching { manager?.removeUpdates(this) }; fallback = false }
    override fun onLocationChanged(location: Location) { if (active) SharingLocationHub.publish(location) }
    override fun onProviderEnabled(provider: String) { }
    override fun onProviderDisabled(provider: String) { SharingLocationHub.latest = null }
    @Deprecated("Required for location callbacks on Android 24–29")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) { }
    private fun send(config: JSONObject, location: Location) {
        sending = true; lastDispatch = SystemClock.elapsedRealtime(); lastRecorded = location.time
        val revision = generation
        val body = JSONObject().put("kind", "position").put("broadcastRevision", config.getInt("broadcastRevision"))
            .put("latitude", location.latitude).put("longitude", location.longitude).put("accuracy", location.accuracy.toDouble())
            .put("recordedAt", location.time / 1000.0)
        executor.execute {
            if (active && generation == revision) runCatching {
                val response = request(this, config, "POST", "/events", body)
                val changed = response.first == 409 && runCatching {
                    JSONObject(response.second).getJSONObject("error").getString("code") == "broadcast_changed"
                }.getOrDefault(false)
                if (response.first == 404 || response.first == 403 || changed) main.post { stopLocal(this) }
            }
            main.post { lastDispatch = SystemClock.elapsedRealtime(); sending = false }
        }
    }
    private fun cancelLocal() {
        generation++; configuration = null; active = false
        main.removeCallbacks(heartbeat); stopFallback(); detachGoogle()
        SharingLocationHub.latest = null
        stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
    }
    override fun onDestroy() { cancelLocal(); if (instance === this) instance = null; executor.shutdown(); super.onDestroy() }
    companion object {
        const val startAction = "dev.wayday.sharing.START"
        const val stopAction = "dev.wayday.sharing.STOP"
        private const val channelId = "wayday-live-sharing"
        private const val notificationId = 4807
        @Volatile var active = false
            private set
        @Volatile private var instance: SharingLocationService? = null
        fun navigationSource(source: String?, lease: String) {
            if (source == null && SharingLocationHub.lease != lease) return
            SharingLocationHub.lease = if (source == null) null else lease
            if (SharingLocationHub.source != source) SharingLocationHub.latest = null
            SharingLocationHub.source = source
            val service = instance ?: return
            if (source != null) service.stopFallback()
            if (source != "google") service.detachGoogle()
            if (source == "google" && active && service.googleProvider == null) service.attachGoogle()
        }
        fun stopLocal(context: Context) {
            instance?.cancelLocal()
            active = false
            context.stopService(Intent(context, SharingLocationService::class.java))
        }
        @Synchronized fun revokePending(context: Context) {
            val config = JSONObject(SharingStorage.read(context, true))
            if (!config.has("token")) return
            if (config.getLong("expiresAt") <= System.currentTimeMillis() / 1000) { SharingStorage.write(context, "{}", true); return }
            repeat(2) {
                val state = request(context, config, "GET", "", null)
                if (state.first == 404) { SharingStorage.write(context, "{}", true); return }
                check(state.first == 200)
                val data = JSONObject(state.second)
                if (!data.getBoolean("broadcasting")) { SharingStorage.write(context, "{}", true); return }
                val stopped = request(context, config, "POST", "/events", JSONObject().put("kind", "broadcast").put("enabled", false).put("revision", data.getInt("revision")))
                if (stopped.first in listOf(200, 404)) { SharingStorage.write(context, "{}", true); return }
                check(stopped.first == 409)
            }
            error("Revocation pending")
        }
        private fun request(context: Context, config: JSONObject, method: String, suffix: String, body: JSONObject?): Pair<Int, String> {
            val url = URL(GatewayAccess.endpoint("/v1/shares/" + config.getString("shareId") + suffix))
            val connection = url.openConnection() as HttpURLConnection
            try {
                connection.instanceFollowRedirects = false; connection.requestMethod = method
                connection.connectTimeout = 10000; connection.readTimeout = 10000
                connection.setRequestProperty("Authorization", "Bearer " + config.getString("token"))
                if (method == "POST") {
                    connection.setRequestProperty("X-Firebase-AppCheck", GatewayAccess.token(context))
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.doOutput = true
                    connection.outputStream.use { it.write(body!!.toString().toByteArray()) }
                }
                val status = connection.responseCode
                val stream = if (status in 200..299) connection.inputStream else connection.errorStream
                val bytes = stream?.use { input ->
                    val output = java.io.ByteArrayOutputStream()
                    val buffer = ByteArray(4096)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        check(output.size() + count <= 65000)
                        output.write(buffer, 0, count)
                    }
                    output.toByteArray()
                } ?: byteArrayOf()
                check(bytes.size <= 65000)
                return status to bytes.toString(Charsets.UTF_8)
            } finally { connection.disconnect() }
        }
    }
}
