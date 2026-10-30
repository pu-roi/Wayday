package dev.wayday.wayday

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent

class MainActivity : FlutterFragmentActivity() {
    private var planning: PlanningBridge? = null
    private var recommendations: RecommendationBridge? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        planning = PlanningBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        recommendations = RecommendationBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "wayday/google_places", GooglePlacesFactory(this, flutterEngine.dartExecutor.binaryMessenger))
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra("wayday_refresh_credential", false)) planning?.refreshCredential()
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        planning?.dispose()
        planning = null
        recommendations?.dispose()
        recommendations = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
