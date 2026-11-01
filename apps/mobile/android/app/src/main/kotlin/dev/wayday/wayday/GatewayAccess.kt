package dev.wayday.wayday

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.appcheck.recaptcha.RecaptchaAppCheckProviderFactory
import com.google.android.gms.tasks.Tasks
import java.net.URI
import java.util.concurrent.TimeUnit

/** Public settings are identifiers, never provider secrets. No debug-token fallback. */
object GatewayAccess {
    private var appCheck: FirebaseAppCheck? = null
    fun configured(): Boolean = BuildConfig.WAYDAY_PUBLIC_BUILD && runCatching {
        val uri = URI(BuildConfig.WAYDAY_GATEWAY_URL)
        uri.scheme == "https" && !uri.host.isNullOrBlank() && uri.userInfo == null &&
            uri.rawQuery == null && uri.rawFragment == null && uri.path in listOf("", "/") &&
            listOf(BuildConfig.WAYDAY_FIREBASE_APP_ID, BuildConfig.WAYDAY_FIREBASE_API_KEY,
                BuildConfig.WAYDAY_FIREBASE_PROJECT_ID, BuildConfig.WAYDAY_RECAPTCHA_SITE_KEY).all { it.isNotBlank() }
    }.getOrDefault(false)

    @Synchronized private fun instance(context: Context): FirebaseAppCheck {
        appCheck?.let { return it }
        check(configured())
        val app = FirebaseApp.getApps(context).firstOrNull { it.name == "wayday-public" }
            ?: FirebaseApp.initializeApp(context.applicationContext, FirebaseOptions.Builder()
                .setApplicationId(BuildConfig.WAYDAY_FIREBASE_APP_ID)
                .setApiKey(BuildConfig.WAYDAY_FIREBASE_API_KEY)
                .setProjectId(BuildConfig.WAYDAY_FIREBASE_PROJECT_ID).build(), "wayday-public")
        return FirebaseAppCheck.getInstance(app).also {
            it.installAppCheckProviderFactory(RecaptchaAppCheckProviderFactory.getInstance(BuildConfig.WAYDAY_RECAPTCHA_SITE_KEY))
            appCheck = it
        }
    }

    // Called only on a worker. The SDK caches expiring tokens; callers never
    // force refresh or automatically replay a paid request after a failure.
    fun token(context: Context): String = Tasks.await(instance(context).getAppCheckToken(false), 10, TimeUnit.SECONDS).token
    fun endpoint(path: String): String {
        check(configured() && path.startsWith("/v1/"))
        return BuildConfig.WAYDAY_GATEWAY_URL.trimEnd('/') + path
    }
}
