package dev.wayday.wayday

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent

class MainActivity : FlutterFragmentActivity() {
    private var planning: PlanningBridge? = null
    private var recommendations: RecommendationBridge? = null
    private var gateway: GatewayBridge? = null
    private var alternativeNavigation: AlternativeNavigationBridge? = null
    private var sharing: SharingBridge? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sharing = SharingBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        planning = PlanningBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        gateway = GatewayBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        alternativeNavigation = AlternativeNavigationBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        recommendations = RecommendationBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "wayday/google_places", GooglePlacesFactory(this, flutterEngine.dartExecutor.binaryMessenger))
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        sharing?.onIntent(intent)
        if (intent.getBooleanExtra("wayday_refresh_credential", false)) planning?.refreshCredential()
    }
    override fun onPause() {
        alternativeNavigation?.stop()
        super.onPause()
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        sharing?.dispose()
        sharing = null
        planning?.dispose()
        planning = null
        gateway?.dispose()
        gateway = null
        alternativeNavigation?.dispose()
        alternativeNavigation = null
        recommendations?.dispose()
        recommendations = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        sharing?.permissions(requestCode, grantResults)
    }
}
