package dev.wayday.wayday

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.delay
import org.maplibre.navigation.core.location.Location
import org.maplibre.navigation.core.location.engine.LocationEngine
import org.maplibre.navigation.core.location.engine.MapLibreLocationEngine
import org.maplibre.navigation.core.models.DirectionsRoute
import org.maplibre.navigation.core.models.LegStep
import org.maplibre.navigation.core.models.RouteLeg
import org.maplibre.navigation.core.models.StepManeuver
import org.maplibre.navigation.core.models.StepIntersection
import org.maplibre.navigation.core.navigation.AndroidMapLibreNavigation
import org.maplibre.navigation.core.navigation.MapLibreNavigationOptions
import org.maplibre.spatialk.geojson.Position
import java.util.Locale
import kotlin.math.roundToLong
import kotlin.math.atan2
import kotlin.math.sin
import kotlin.math.cos

/** One foreground core/location/speech session, independently of Flutter's map. */
class AlternativeNavigationBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "wayday/alternative_navigation")
    private val main = Handler(Looper.getMainLooper())
    private var navigation: AndroidMapLibreNavigation? = null
    private var session: String? = null
    private var speech: TextToSpeech? = null
    private var voiceReady = false
    private var muted = false
    private var spokenStep = -1
    private var lastFix = 0L
    private var running = false
    private var coreRevision = 0L
    private val watchdog = object : Runnable {
        override fun run() {
            if (!running) return
            if (System.currentTimeMillis() - lastFix > 10000) emit("gpsLost")
            main.postDelayed(this, 5000)
        }
    }

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "initializeFixture" -> {
                        check(BuildConfig.DEBUG && activity.packageName.endsWith(".maptest"))
                        stop()
                        navigation = createCore("fixture")
                        stop()
                        result.success(mapOf("core" to "5.0.0", "renderer" to "opengl-13.7.1"))
                    }
                    "guidanceFixture" -> {
                        check(BuildConfig.DEBUG && activity.packageName.endsWith(".maptest"))
                        val leg = call.argument<Map<String, Any>>("leg") ?: error("leg")
                        val directions = route(leg)
                        stop()
                        val id = "synthetic-core-fixture"
                        session = id
                        val positions = leg["coordinates"] as List<*>
                        fun fix(index: Int): Location {
                            val p = positions[index] as List<*>
                            return Location((p[0] as Number).toDouble(), (p[1] as Number).toDouble(), accuracyMeters = 3f,
                                timeMilliseconds = System.currentTimeMillis(), speedMetersPerSeconds = 2f, bearing = 45f)
                        }
                        val source = object : LocationEngine {
                            override suspend fun getLastLocation() = fix(0)
                            override fun listenToLocation(request: LocationEngine.Request) = flow {
                                for (index in positions.indices) { delay(200); emit(fix(index)) }
                            }
                        }
                        var delivered = false
                        var firstDistance: Double? = null
                        var samples = 0
                        val core = createCore(id, source)
                        navigation = core
                        core.addProgressChangeListener { _, progress ->
                            main.post {
                                if (!delivered && session == id) {
                                    samples++
                                    if (firstDistance == null) firstDistance = progress.distanceRemaining
                                    if (progress.distanceRemaining > 25) return@post
                                    delivered = true
                                    result.success(mapOf("legs" to progress.directionsRoute.legs.size,
                                        "distance" to progress.distanceRemaining, "firstDistance" to firstDistance,
                                        "samples" to samples, "steps" to progress.directionsRoute.legs[0].steps.size))
                                    stop()
                                }
                            }
                        }
                        running = true
                        core.startNavigation(directions)
                        main.postDelayed({
                            if (!delivered && session == id) {
                                delivered = true
                                stop()
                                result.error("fixture_timeout", "Synthetic core progress did not arrive.", null)
                            }
                        }, 5000)
                    }
                    "initialize" -> {
                        val id = call.argument<String>("session") ?: error("session")
                        stop()
                        session = id
                        navigation = createCore(id)
                        speech = TextToSpeech(activity.applicationContext) { status ->
                            main.post {
                                if (session == id) {
                                    voiceReady = status == TextToSpeech.SUCCESS &&
                                        (speech?.setLanguage(Locale.ENGLISH) ?: -1) >= 0
                                    emit("voice", mapOf("available" to voiceReady))
                                }
                            }
                        }
                        result.success(null)
                    }
                    "startLeg" -> {
                        check(call.argument<String>("session") == session && navigation != null)
                        val leg = call.argument<Map<String, Any>>("leg") ?: error("leg")
                        val route = route(leg)
                        spokenStep = -1
                        speech?.stop()
                        // A new leg also replaces the core callback generation.
                        // Queued progress/deviation from the previous leg is obsolete.
                        navigation?.onDestroy()
                        navigation = createCore(session!!)
                        navigation!!.startNavigation(route)
                        running = true
                        lastFix = System.currentTimeMillis()
                        main.removeCallbacks(watchdog)
                        main.postDelayed(watchdog, 5000)
                        result.success(null)
                    }
                    "voice" -> {
                        check(call.argument<String>("session") == session)
                        muted = call.argument<Boolean>("muted") == true
                        if (muted) speech?.stop()
                        result.success(voiceReady)
                    }
                    "stop" -> {
                        if (call.argument<String>("session") == session) stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("navigation", "Alternative guidance is unavailable. Retry explicitly.", null)
            }
        }
    }

    private fun fresh(fix: Location): Boolean = fix.latitude.isFinite() && fix.longitude.isFinite() &&
        fix.latitude in -90.0..90.0 && fix.longitude in -180.0..180.0 &&
        fix.accuracyMeters != null && fix.accuracyMeters!! <= 100 &&
        fix.timeMilliseconds != null && System.currentTimeMillis() - fix.timeMilliseconds!! in 0..15000

    private fun createCore(id: String, fixtureSource: LocationEngine? = null): AndroidMapLibreNavigation {
        val revision = ++coreRevision
        val device = MapLibreLocationEngine(activity.applicationContext, Looper.getMainLooper())
        val source = object : LocationEngine {
            override suspend fun getLastLocation(): Location? =
                try { device.getLastLocation()?.takeIf(::fresh) } catch (_: Exception) { null }
            override fun listenToLocation(request: LocationEngine.Request): Flow<Location> =
                device.listenToLocation(request).onEach { fix ->
                    main.post {
                        if (session == id && running && coreRevision == revision) {
                            if (fresh(fix)) {
                                lastFix = System.currentTimeMillis()
                                emit("location", position(fix))
                                emit("gpsAvailable")
                            } else emit("gpsLost")
                        }
                    }
                }.filter(::fresh).catch {
                    main.post { if (session == id && coreRevision == revision) emit("failure") }
                }
        }
        val core = AndroidMapLibreNavigation(activity, MapLibreNavigationOptions(
            enableFasterRouteDetection = false,
            manuallyEndNavigationUponCompletion = true,
            defaultMilestonesEnabled = false,
            isDebugLoggingEnabled = false,
        ), locationEngine = fixtureSource ?: source)
        core.addProgressChangeListener { location, progress ->
            main.post {
                if (session == id && running && coreRevision == revision && fresh(location)) {
                    val step = progress.directionsRoute.legs[progress.legIndex].steps[progress.stepIndex]
                    val instruction = step.maneuver.instruction.orEmpty()
                    emit("progress", position(location) + mapOf(
                        "instruction" to instruction, "step" to progress.stepIndex,
                        "distance" to progress.distanceRemaining, "duration" to progress.durationRemaining,
                    ))
                    if (spokenStep != progress.stepIndex) {
                        spokenStep = progress.stepIndex
                        if (voiceReady && !muted && instruction.isNotBlank())
                            speech?.speak(instruction, TextToSpeech.QUEUE_FLUSH, null, "$id-$spokenStep")
                    }
                    if (progress.distanceRemaining <= 25 && progress.stepIndex == progress.directionsRoute.legs[0].steps.lastIndex)
                        emit("arrival")
                }
            }
        }
        core.addOffRouteListener { fix ->
            main.post { if (session == id && running && coreRevision == revision && fresh(fix)) emit("offRoute", position(fix)) }
        }
        return core
    }

    private fun position(fix: Location): Map<String, Any> = mapOf(
        "latitude" to fix.latitude, "longitude" to fix.longitude,
        "bearing" to (fix.bearing?.toDouble() ?: 0.0),
        "accuracy" to (fix.accuracyMeters?.toDouble() ?: 100.0),
    )
    private fun emit(kind: String, fields: Map<String, Any> = emptyMap()) {
        val id = session ?: return
        channel.invokeMethod("event", fields + mapOf("session" to id, "kind" to kind))
    }

    private fun route(data: Map<String, Any>): DirectionsRoute {
        val coordinates = (data["coordinates"] as List<*>).map {
            val pair = it as List<*>
            require(pair.size == 2)
            val lat = (pair[0] as Number).toDouble()
            val lon = (pair[1] as Number).toDouble()
            require(lat.isFinite() && lon.isFinite() && lat in -90.0..90.0 && lon in -180.0..180.0)
            Position(longitude = lon, latitude = lat)
        }
        require(coordinates.size in 2..30000)
        fun metric(value: Any?): Double = (value as Number).toDouble().also { require(it.isFinite() && it in 0.0..10000000.0) }
        var end = 0
        val steps = (data["steps"] as List<*>).mapIndexed { index, value ->
            val step = value as Map<*, *>
            val from = (step["from"] as Number).toInt()
            val to = (step["to"] as Number).toInt()
            require(from == end && to in from..coordinates.lastIndex)
            end = to
            val text = step["instruction"] as String
            require(text.isNotBlank() && text.length <= 1000)
            val before = bearing(coordinates[maxOf(0, from - 1)], coordinates[from])
            val after = bearing(coordinates[from], coordinates[minOf(coordinates.lastIndex, from + 1)])
            val maneuver = step["maneuver"] as? String ?: "None"
            val type = when {
                from == coordinates.lastIndex -> StepManeuver.Type.ARRIVE
                index == 0 -> StepManeuver.Type.DEPART
                maneuver.startsWith("Merge") -> StepManeuver.Type.MERGE
                maneuver.startsWith("Exit") -> StepManeuver.Type.OFF_RAMP
                maneuver.startsWith("Stay") -> StepManeuver.Type.FORK
                maneuver == "Roundabout" -> StepManeuver.Type.ROUNDABOUT
                maneuver == "Straight" -> StepManeuver.Type.CONTINUE
                else -> StepManeuver.Type.TURN
            }
            LegStep(geometry = encode(coordinates.subList(from, to + 1)),
                distance = metric(step["distance"]), duration = metric(step["duration"]),
                mode = data["mode"] as? String ?: "driving",
                maneuver = StepManeuver(coordinates[from], before, after, instruction = text, type = type),
                // Core requires a nonempty progress-anchor list. These are
                // provider maneuver points, without invented roads or lanes.
                intersections = listOf(StepIntersection(coordinates[from], geometryIndex = from)))
        }
        require(steps.size in 2..2000 && end == coordinates.lastIndex)
        val distance = metric(data["distance"])
        val duration = metric(data["duration"])
        return DirectionsRoute(encode(coordinates), listOf(RouteLeg(distance, duration, steps)), distance, duration)
    }

    private fun bearing(a: Position, b: Position): Double {
        val first = Math.toRadians(a.latitude)
        val second = Math.toRadians(b.latitude)
        val delta = Math.toRadians(b.longitude - a.longitude)
        return (Math.toDegrees(atan2(sin(delta) * cos(second), cos(first) * sin(second) - sin(first) * cos(second) * cos(delta))) + 360) % 360
    }

    private fun encode(points: List<Position>): String {
        val output = StringBuilder()
        var lat = 0L
        var lon = 0L
        fun append(delta: Long) {
            var value = if (delta < 0) (delta shl 1).inv() else delta shl 1
            while (value >= 32) { output.append(((value and 31 or 32) + 63).toInt().toChar()); value = value shr 5 }
            output.append((value + 63).toInt().toChar())
        }
        for (point in points) {
            val nextLat = (point.latitude * 1000000).roundToLong()
            val nextLon = (point.longitude * 1000000).roundToLong()
            append(nextLat - lat); append(nextLon - lon)
            lat = nextLat; lon = nextLon
        }
        return output.toString()
    }

    fun stop() {
        coreRevision++
        running = false
        session = null
        main.removeCallbacks(watchdog)
        navigation?.onDestroy()
        navigation = null
        speech?.stop()
        speech?.shutdown()
        speech = null
        voiceReady = false
        muted = false
    }
    fun dispose() { stop(); channel.setMethodCallHandler(null) }
}
