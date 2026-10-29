package dev.wayday.wayday

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.accessibility.AccessibilityEvent
import android.widget.FrameLayout
import androidx.fragment.app.Fragment
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.maps.model.LatLng
import com.google.android.libraries.places.api.Places
import com.google.android.libraries.places.api.model.CircularBounds
import com.google.android.libraries.places.api.model.Place
import com.google.android.libraries.places.api.net.SearchByTextRequest
import com.google.android.libraries.places.api.net.SearchNearbyRequest
import com.google.android.libraries.places.api.net.PlacesStatusCodes
import com.google.android.libraries.places.widget.PlaceSearchFragment
import com.google.android.libraries.places.widget.PlaceSearchFragmentListener
import com.google.android.libraries.places.widget.PlaceDetailsCompactFragment
import com.google.android.libraries.places.widget.PlaceLoadListener
import com.google.android.libraries.places.widget.model.AttributionPosition
import com.google.android.libraries.places.widget.model.Orientation
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.Locale

class GooglePlacesFactory(private val activity: FlutterFragmentActivity, private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView = GooglePlacesView(activity, messenger, viewId)
}

private class GooglePlacesView(private val activity: FlutterFragmentActivity, messenger: BinaryMessenger, viewId: Int) : PlatformView {
    private val channel = MethodChannel(messenger, "wayday/google_places/$viewId")
    private val root = object : FrameLayout(activity) {
        override fun dispatchTouchEvent(event: MotionEvent): Boolean {
            if (event.actionMasked == MotionEvent.ACTION_DOWN) channel.invokeMethod("interaction", null)
            return super.dispatchTouchEvent(event)
        }
        override fun requestSendAccessibilityEvent(child: View, event: AccessibilityEvent): Boolean {
            if (event.eventType == AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUSED) channel.invokeMethod("interaction", null)
            return super.requestSendAccessibilityEvent(child, event)
        }
    }
    private data class Hosted(val frame: FrameLayout, val fragment: Fragment, var result: MethodChannel.Result?, var places: List<Place> = emptyList(), var retrievedAtMillis: Long = 0)
    private val hosted = mutableMapOf<Int, Hosted>()
    private var visibleRevision: Int? = null
    private var disposed = false
    init {
        root.setBackgroundColor(Color.rgb(251, 251, 248))
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "search", "details" -> {
                    val arguments = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    attached {
                        if (disposed) { result.error("temporary", "Search closed", null) }
                        else try { load(arguments, call.method == "details", result) }
                        catch (error: Exception) {
                            android.util.Log.i("WaydaySearch", "google_ui_kit binding_failure=${error.javaClass.simpleName}")
                            result.error("temporary", "Google search unavailable", null)
                        }
                    }
                }
                "show" -> {
                    val revision = (call.arguments as Number).toInt()
                    hosted[revision]?.frame?.visibility = View.VISIBLE
                    visibleRevision = revision
                    hosted.keys.filter { it != revision }.toList().forEach(::remove)
                    result.success(null)
                }
                "cancel" -> { hosted.keys.toList().forEach(::remove); visibleRevision = null; result.success(null) }
                "qualify" -> {
                    if (activity.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE == 0 || !activity.packageName.endsWith(".maptest")) { result.notImplemented(); return@setMethodCallHandler }
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    val entry = hosted[visibleRevision]
                    val places = entry?.places.orEmpty()
                    result.success(mapOf("count" to places.size,
                        "idPresent" to places.any { !it.id.isNullOrEmpty() },
                        "locationPresent" to places.any { it.location != null },
                        "addressPresent" to places.any { !it.formattedAddress.isNullOrEmpty() },
                        "namePresent" to places.any { !it.displayName.isNullOrEmpty() },
                        "countryMetadataPresent" to places.any { country(it) != null }))
                    if (args["select"] == true && places.isNotEmpty() && visibleRevision != null) selection(places.first(), visibleRevision!!, false)
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun attached(action: () -> Unit) {
        if (root.isAttachedToWindow) action() else root.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(view: View) { root.removeOnAttachStateChangeListener(this); action() }
            override fun onViewDetachedFromWindow(view: View) {}
        })
    }
    @Suppress("DEPRECATION")
    private fun initialize(): Boolean {
        val metadata = activity.packageManager.getApplicationInfo(activity.packageName, PackageManager.GET_META_DATA).metaData
        val key = metadata?.getString("com.google.android.geo.API_KEY").orEmpty()
        if (key.isEmpty()) return false
        if (!Places.isInitialized()) Places.initializeWithNewPlacesApiEnabled(activity.applicationContext, key, Locale.US)
        return true
    }
    private fun load(args: Map<*, *>, details: Boolean, result: MethodChannel.Result) {
        if (GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(activity) != ConnectionResult.SUCCESS) {
            android.util.Log.i("WaydaySearch", "google_ui_kit services_unavailable")
            result.error("services", "Google services unavailable", null); return
        }
        if (!initialize()) { result.error("access", "Google key unavailable", null); return }
        val revision = (args["revision"] as Number).toInt()
        hosted.keys.filter { it != visibleRevision }.toList().forEach(::remove)
        val frame = FrameLayout(activity).apply {
            id = View.generateViewId()
            visibility = View.INVISIBLE
            layoutParams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        }
        root.addView(frame)
        if (details) {
            val fragment = PlaceDetailsCompactFragment.newInstance(
                listOf(PlaceDetailsCompactFragment.Content.ADDRESS), Orientation.VERTICAL, R.style.WaydayPlacesTheme)
            hosted[revision] = Hosted(frame, fragment, result)
            fragment.setPlaceLoadListener(object : PlaceLoadListener {
                override fun onSuccess(place: Place) {
                    hosted[revision]?.places = listOf(place)
                    hosted[revision]?.retrievedAtMillis = System.currentTimeMillis()
                    complete(revision, mapOf("count" to 1))
                    selection(place, revision, true)
                }
                override fun onFailure(error: Exception) { failed(revision, error) }
            })
            activity.supportFragmentManager.beginTransaction().add(frame.id, fragment).commitNow()
            fragment.loadWithPlaceId(args["placeId"] as String)
        } else {
            val fragment = PlaceSearchFragment.newInstance(
                listOf(PlaceSearchFragment.Content.ADDRESS), Orientation.VERTICAL, R.style.WaydayPlacesTheme)
            fragment.selectable = true
            fragment.preferTruncation = false
            fragment.attributionPosition = AttributionPosition.BOTTOM
            hosted[revision] = Hosted(frame, fragment, result)
            fragment.registerListener(object : PlaceSearchFragmentListener {
                override fun onLoad(places: List<Place>) {
                    hosted[revision]?.places = places
                    hosted[revision]?.retrievedAtMillis = System.currentTimeMillis()
                    // Never expose an identified foreign-country batch. Country
                    // eligibility is checked again before selection/confirmation.
                    if (places.any { country(it) == false }) {
                        hosted[revision]?.result?.error("country", "Refine the search to Philippine places", null)
                        hosted[revision]?.result = null
                        remove(revision)
                    } else complete(revision, mapOf("count" to places.size,
                        "hasSelectableMetadata" to places.any { it.id != null && it.location != null && country(it) == true }))
                }
                override fun onRequestError(error: Exception) { failed(revision, error) }
                override fun onPlaceSelected(place: Place) { selection(place, revision, false) }
            })
            activity.supportFragmentManager.beginTransaction().add(frame.id, fragment).commitNow()
            val latitude = (args["latitude"] as? Number)?.toDouble()
            val longitude = (args["longitude"] as? Number)?.toDouble()
            val center = if (latitude != null && longitude != null) LatLng(latitude, longitude) else null
            val types = (args["types"] as? List<*>)?.filterIsInstance<String>().orEmpty()
            val fields = listOf(Place.Field.ID, Place.Field.LOCATION)
            if (types.isNotEmpty() && center != null) {
                fragment.configureFromSearchNearbyRequest(SearchNearbyRequest.builder(CircularBounds.newInstance(center, 5000.0), fields)
                    .setIncludedTypes(types).setMaxResultCount(10)
                    .setRankPreference(SearchNearbyRequest.RankPreference.DISTANCE).build())
            } else {
                val query = args["query"] as String
                val builder = SearchByTextRequest.builder(
                    if (query.contains("philippines", true)) query else "$query Philippines", fields)
                    .setMaxResultCount(10).setRegionCode("")
                if (center != null) builder.setLocationBias(CircularBounds.newInstance(center, 50000.0))
                if (center != null && args["brandOnly"] == true) builder.setRankPreference(SearchByTextRequest.RankPreference.DISTANCE)
                fragment.configureFromSearchByTextRequest(builder.build())
            }
        }
    }
    private fun complete(revision: Int, data: Map<String, Any>) {
        android.util.Log.i("WaydaySearch", "google_ui_kit complete")
        hosted[revision]?.result?.success(data)
        hosted[revision]?.result = null
    }
    private fun selection(place: Place, revision: Int, resolved: Boolean) {
        if (disposed || !hosted.containsKey(revision)) return
        val location = place.location
        channel.invokeMethod("selection", mapOf(
            "revision" to revision, "placeId" to place.id,
            "latitude" to location?.latitude, "longitude" to location?.longitude,
            "retrievedAtMillis" to hosted[revision]?.retrievedAtMillis,
            "countryStatus" to country(place),
            "countryVerified" to (country(place) == true), "resolved" to resolved))
    }
    private val countryNames = Locale.getISOCountries().map { Locale("", it).getDisplayCountry(Locale.US).lowercase(Locale.US) }.toSet()
    private fun country(place: Place): Boolean? {
        val component = place.addressComponents?.asList()?.firstOrNull { it.types.contains("country") }
        if (!component?.shortName.isNullOrEmpty()) return component!!.shortName.equals("PH", true)
        // Locale.US and an empty region code retain the country in formatted
        // addresses. Require an exact terminal country, never a substring/bias.
        val terminal = place.formattedAddress?.substringAfterLast(',')?.trim()?.lowercase(Locale.US) ?: return null
        if (terminal == "philippines") return true
        return if (countryNames.contains(terminal)) false else null
    }
    private fun failed(revision: Int, error: Exception) {
        val code = (error as? ApiException)?.statusCode
        val message = error.message.orEmpty().lowercase(Locale.US)
        val reason = when {
            message.contains("android") && (message.contains("blocked") || message.contains("not authorized")) -> "android_identity"
            message.contains("api_key_service_blocked") || message.contains("api restrictions") -> "api_restriction"
            message.contains("not enabled") || message.contains("disabled") || message.contains("has not been used") -> "service_disabled"
            message.contains("billing") -> "billing"
            message.contains("expired") -> "expired_key"
            else -> "unclassified"
        }
        android.util.Log.i("WaydaySearch", "google_ui_kit failure_status=$code reason=$reason")
        val kind = when (code) {
            PlacesStatusCodes.REQUEST_DENIED -> "access"
            PlacesStatusCodes.OVER_QUERY_LIMIT -> "rate"
            else -> "temporary"
        }
        hosted[revision]?.result?.error(kind, "Google search unavailable", null)
        hosted[revision]?.result = null
        remove(revision)
    }
    private fun remove(revision: Int) {
        val entry = hosted.remove(revision) ?: return
        entry.result?.error("cancelled", "Search superseded", null)
        activity.supportFragmentManager.beginTransaction().remove(entry.fragment).commitNowAllowingStateLoss()
        root.removeView(entry.frame)
    }
    override fun getView(): View = root
    override fun dispose() {
        disposed = true
        hosted.keys.toList().forEach(::remove)
        channel.setMethodCallHandler(null)
    }
}
