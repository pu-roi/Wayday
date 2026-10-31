package dev.wayday.wayday

import android.app.Activity
import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo
import android.os.Handler
import android.os.Looper
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.maps.model.LatLng
import com.google.android.libraries.places.api.Places
import com.google.android.libraries.places.api.model.CircularBounds
import com.google.android.libraries.places.api.model.EncodedPolyline
import com.google.android.libraries.places.api.model.SearchAlongRouteParameters
import com.google.android.libraries.places.api.model.Place
import com.google.android.libraries.places.api.model.OpeningHours
import com.google.android.libraries.places.api.model.TimeOfWeek
import java.time.Instant
import java.time.ZoneOffset
import com.google.android.libraries.places.api.net.FetchPlaceRequest
import com.google.android.libraries.places.api.net.SearchByTextRequest
import com.google.android.libraries.places.api.net.PlacesStatusCodes
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** Explicit app discovery, separate from the visible UI Kit picker. No response logging. */
class RecommendationBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "wayday/recommendations")
    private var disposed = false
    private val handler = Handler(Looper.getMainLooper())
    private val active = mutableSetOf<Reply>()
    private val fields = listOf(Place.Field.ID, Place.Field.DISPLAY_NAME, Place.Field.LOCATION,
        Place.Field.FORMATTED_ADDRESS, Place.Field.ADDRESS_COMPONENTS, Place.Field.TYPES,
        Place.Field.PRIMARY_TYPE, Place.Field.BUSINESS_STATUS,
        Place.Field.OPENING_HOURS, Place.Field.CURRENT_OPENING_HOURS, Place.Field.UTC_OFFSET,
        Place.Field.RATING, Place.Field.USER_RATING_COUNT)
    init {
        channel.setMethodCallHandler { call, result ->
            if (disposed) { result.error("closed", "Place service closed", null); return@setMethodCallHandler }
            if (call.method == "status") {
                result.success(mapOf("configured" to keyConfigured(), "bridgeVersion" to 3, "metadataVersion" to 2))
                return@setMethodCallHandler
            }
            if (call.method !in listOf("search", "details")) { result.notImplemented(); return@setMethodCallHandler }
            val args = call.arguments as? Map<*, *>
            val operation = if (call.method == "details") "refresh" else if (args?.get("polyline") != null) "corridor" else "anchor"
            val reply = Reply(result, operation)
            try {
                if (!initialize()) { reply.fail("configuration", null); return@setMethodCallHandler }
                require(args != null)
                val client = Places.createClient(activity)
                when (call.method) {
                    "search" -> {
                        val query = (args["query"] as? String)?.trim().orEmpty()
                        require(query.isNotEmpty() && query.length <= 200)
                        val builder = SearchByTextRequest.builder(query, fields).setMaxResultCount(10)
                            .setPureServiceAreaBusinessesIncluded(false)
                            .setRegionCode("PH")
                            .setRankPreference(SearchByTextRequest.RankPreference.RELEVANCE)
                            .setCancellationToken(reply.cancellation.token)
                        (args["type"] as? String)?.let {
                            require(it.length <= 80 && it.matches(Regex("[a-z_]+")))
                            builder.setIncludedType(it).setStrictTypeFiltering(true)
                        }
                        val polyline = args["polyline"] as? String
                        if (polyline != null) {
                            require(polyline.isNotEmpty() && polyline.length <= 200000)
                            builder.setSearchAlongRouteParameters(SearchAlongRouteParameters.newInstance(EncodedPolyline.newInstance(polyline)))
                        } else {
                            val latitude = (args["latitude"] as? Number)?.toDouble() ?: throw IllegalArgumentException()
                            val longitude = (args["longitude"] as? Number)?.toDouble() ?: throw IllegalArgumentException()
                            require(latitude.isFinite() && longitude.isFinite() && latitude in -90.0..90.0 && longitude in -180.0..180.0)
                            builder.setLocationBias(CircularBounds.newInstance(LatLng(latitude, longitude), 5000.0))
                        }
                        client.searchByText(builder.build())
                            .addOnSuccessListener {
                                try { reply.success(it.places.mapIndexed { index, place -> snapshot(place) + ("rank" to index) }) }
                                catch (_: Exception) { reply.fail("unexpected_response", null) }
                            }
                            .addOnFailureListener { reply.failure(it) }
                    }
                    "details" -> {
                        val id = args["id"] as? String ?: throw IllegalArgumentException()
                        require(id.isNotEmpty() && id.length <= 512)
                        client.fetchPlace(FetchPlaceRequest.builder(id, fields).setCancellationToken(reply.cancellation.token).build())
                            .addOnSuccessListener {
                                try { reply.success(listOf(snapshot(it.place))) }
                                catch (_: Exception) { reply.fail("unexpected_response", null) }
                            }
                            .addOnFailureListener { reply.failure(it) }
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) { reply.failure(error) }
        }
    }
    @Suppress("DEPRECATION")
    private fun initialize(): Boolean {
        val key = activity.packageManager.getApplicationInfo(activity.packageName, PackageManager.GET_META_DATA)
            .metaData?.getString("com.google.android.geo.API_KEY").orEmpty()
        if (key.isEmpty()) return false
        if (!Places.isInitialized()) Places.initializeWithNewPlacesApiEnabled(activity.applicationContext, key, Locale.US)
        return true
    }
    @Suppress("DEPRECATION")
    private fun keyConfigured(): Boolean = try {
        !activity.packageManager.getApplicationInfo(activity.packageName, PackageManager.GET_META_DATA)
            .metaData?.getString("com.google.android.geo.API_KEY").isNullOrEmpty()
    } catch (_: Exception) { false }
    private fun snapshot(place: Place): Map<String, Any?> {
        val at = System.currentTimeMillis()
        fun date(value: com.google.android.libraries.places.api.model.LocalDate) =
            String.format(Locale.US, "%04d-%02d-%02d", value.year, value.month, value.day)
        fun point(value: TimeOfWeek): Map<String, Any?> = mapOf(
            "day" to value.day.ordinal, "hour" to value.time.hours,
            "minute" to value.time.minutes, "date" to value.date?.let(::date),
            "truncated" to value.isTruncated)
        fun hours(value: OpeningHours?): Map<String, Any?>? = value?.let {
            mapOf("periods" to it.periods.map { period ->
                mapOf("open" to period.open?.let(::point), "close" to period.close?.let(::point))
            }, "weekdays" to it.weekdayText,
                "specialDays" to it.specialDays.map { day ->
                    mapOf("date" to date(day.date), "exceptional" to day.isExceptional)
                })
        }
        val components = place.addressComponents?.asList().orEmpty()
        val country = components.firstOrNull { it.types.contains("country") }?.shortName
        val locality = listOf("sublocality_level_1", "sublocality", "locality")
            .mapNotNull { type -> components.firstOrNull { it.types.contains(type) }?.name }.distinct().joinToString(", ")
        return mapOf("id" to place.id, "name" to place.displayName,
            "latitude" to place.location?.latitude, "longitude" to place.location?.longitude,
            "address" to place.formattedAddress, "locality" to locality, "country" to country,
            "types" to place.placeTypes.orEmpty(), "status" to place.businessStatus?.name,
            "metadataVersion" to 2, "primaryType" to place.primaryType, "rating" to place.rating,
            "ratingCount" to place.userRatingCount,
            "attributions" to place.attributions.orEmpty(), "at" to at,
            "hoursVersion" to 1, "utcOffset" to place.utcOffsetMinutes,
            "hoursDate" to place.utcOffsetMinutes?.let {
                Instant.ofEpochMilli(at).atOffset(ZoneOffset.ofTotalSeconds(it * 60)).toLocalDate().toString()
            }, "regularHours" to hours(place.openingHours),
            "currentHours" to hours(place.currentOpeningHours))
    }
    private inner class Reply(val result: MethodChannel.Result, val operation: String) {
        val cancellation = CancellationTokenSource()
        private var finished = false
        private val timeout = Runnable {
            cancellation.cancel() // Best effort; this does not reverse charges.
            fail("timeout", 15)
        }
        init { active.add(this); handler.postDelayed(timeout, 45000) }
        private fun take(): Boolean {
            if (finished || disposed) return false
            finished = true
            handler.removeCallbacks(timeout)
            active.remove(this)
            return true
        }
        fun success(value: Any) { if (take()) result.success(value) }
        fun fail(kind: String, status: Int?, reason: String = "unclassified") {
            if (!take()) return
            if (activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) android.util.Log.i("WaydayRecommendations", "operation=$operation kind=$kind status=$status reason=$reason")
            result.error(kind, "Place request failed", mapOf("status" to status, "operation" to operation, "reason" to reason))
        }
        fun failure(error: Exception) {
            val status = (error as? ApiException)?.statusCode
            val kind = when {
                error is IllegalArgumentException -> "invalid_request"
                status == PlacesStatusCodes.REQUEST_DENIED -> "access"
                status == PlacesStatusCodes.OVER_QUERY_LIMIT || status == 23 -> "quota"
                status == PlacesStatusCodes.INVALID_REQUEST -> "invalid_request"
                status == PlacesStatusCodes.NOT_FOUND -> "not_found"
                status == 7 -> "network"
                status == 15 || status == 22 -> "timeout"
                status == 16 -> "cancelled"
                status == 10 -> "configuration"
                else -> "unavailable"
            }
            val message = error.message.orEmpty().lowercase(Locale.US)
            val reason = when {
                message.contains("android") && (message.contains("blocked") || message.contains("not authorized")) -> "android_identity"
                message.contains("api_key_service_blocked") || message.contains("api restrictions") -> "api_restriction"
                message.contains("not enabled") || message.contains("disabled") || message.contains("has not been used") -> "service_disabled"
                message.contains("billing") -> "billing"
                message.contains("expired") -> "expired_key"
                else -> "unclassified"
            }
            fail(kind, status, reason)
        }
        fun cancel() { cancellation.cancel(); fail("cancelled", 16) }
    }
    fun dispose() {
        active.toList().forEach { it.cancel() }
        disposed = true
        channel.setMethodCallHandler(null)
    }
}
