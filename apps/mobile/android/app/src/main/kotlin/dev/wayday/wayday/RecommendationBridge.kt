package dev.wayday.wayday

import android.app.Activity
import android.content.pm.PackageManager
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.maps.model.LatLng
import com.google.android.libraries.places.api.Places
import com.google.android.libraries.places.api.model.CircularBounds
import com.google.android.libraries.places.api.model.EncodedPolyline
import com.google.android.libraries.places.api.model.SearchAlongRouteParameters
import com.google.android.libraries.places.api.model.Place
import com.google.android.libraries.places.api.net.FetchPlaceRequest
import com.google.android.libraries.places.api.net.SearchByTextRequest
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** Explicit app discovery, separate from the visible UI Kit picker. No response logging. */
class RecommendationBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "wayday/recommendations")
    private var disposed = false
    private val fields = listOf(Place.Field.ID, Place.Field.DISPLAY_NAME, Place.Field.LOCATION,
        Place.Field.FORMATTED_ADDRESS, Place.Field.ADDRESS_COMPONENTS, Place.Field.TYPES,
        Place.Field.PRIMARY_TYPE, Place.Field.BUSINESS_STATUS)
    init {
        channel.setMethodCallHandler { call, result ->
            if (disposed) { result.error("closed", "Place service closed", null); return@setMethodCallHandler }
            try {
                if (!initialize()) { result.error("configuration", "Google Places is not configured", null); return@setMethodCallHandler }
                val args = call.arguments as? Map<*, *> ?: throw IllegalArgumentException()
                val client = Places.createClient(activity)
                when (call.method) {
                    "search" -> {
                        val query = (args["query"] as? String)?.trim().orEmpty()
                        require(query.isNotEmpty() && query.length <= 200)
                        val builder = SearchByTextRequest.builder(query, fields).setMaxResultCount(10)
                            .setPureServiceAreaBusinessesIncluded(false)
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
                            .addOnSuccessListener { if (!disposed) result.success(it.places.map(::snapshot)) }
                            .addOnFailureListener { failure(result, it) }
                    }
                    "details" -> {
                        val id = args["id"] as? String ?: throw IllegalArgumentException()
                        require(id.isNotEmpty() && id.length <= 512)
                        client.fetchPlace(FetchPlaceRequest.newInstance(id, fields))
                            .addOnSuccessListener { if (!disposed) result.success(listOf(snapshot(it.place))) }
                            .addOnFailureListener { failure(result, it) }
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("invalid_request", "Place request is unavailable", null) }
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
    private fun snapshot(place: Place): Map<String, Any?> {
        val components = place.addressComponents?.asList().orEmpty()
        val country = components.firstOrNull { it.types.contains("country") }?.shortName
        val locality = listOf("sublocality_level_1", "sublocality", "locality")
            .mapNotNull { type -> components.firstOrNull { it.types.contains(type) }?.name }.distinct().joinToString(", ")
        return mapOf("id" to place.id, "name" to place.displayName,
            "latitude" to place.location?.latitude, "longitude" to place.location?.longitude,
            "address" to place.formattedAddress, "locality" to locality, "country" to country,
            "types" to place.placeTypes.orEmpty(), "status" to place.businessStatus?.name,
            "attributions" to place.attributions.orEmpty(), "at" to System.currentTimeMillis())
    }
    private fun failure(result: MethodChannel.Result, error: Exception) {
        if (!disposed) result.error(if ((error as? ApiException)?.statusCode == 9010) "quota" else "places_unavailable",
            "Google Places could not complete this request", null)
    }
    fun dispose() { disposed = true; channel.setMethodCallHandler(null) }
}
