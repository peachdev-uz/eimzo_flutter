package uz.peachdev.eimzo_flutter

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterAssets
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean
import uz.eimzo.sdk.EImzoAppearance
import uz.eimzo.sdk.EImzoConfig
import uz.eimzo.sdk.EImzoEnvironment
import uz.eimzo.sdk.EImzoFont
import uz.eimzo.sdk.EImzoHashDisplay
import uz.eimzo.sdk.EImzoLanguage
import uz.eimzo.sdk.EImzoPalette
import uz.eimzo.sdk.EImzoResultCallback
import uz.eimzo.sdk.EImzoSDK
import uz.eimzo.sdk.EImzoTesting
import uz.eimzo.sdk.EImzoThemeMode
import uz.eimzo.sdk.fullui.EImzoActivity

/**
 * The plugin opens the SDK; it does not listen for links. `eimzo://` is the
 * E-IMZO app's scheme, and a host that takes it from outside would open its
 * SDK for any page or app that sends one. A sign request reaches the SDK only
 * as `openSignUi`'s `deepLink`, which the app makes itself (Dart
 * `EimzoSignLink.create`).
 */
class EimzoFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private lateinit var methodChannel: MethodChannel
    private var activity: Activity? = null

    /** Where the app's Flutter assets sit in its APK — for the appearance's font. */
    private var flutterAssets: FlutterAssets? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL_METHOD)
        methodChannel.setMethodCallHandler(this)
        flutterAssets = binding.flutterAssets
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        flutterAssets = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> handleInit(call, result)
            "openSignUi" -> handleOpenSignUi(call, result)
            "getKeys" -> EImzoSDK.getKeys(answerOnce(result))
            "sign" -> handleSign(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * «Kalitlar API» (2.4): signs `deepLink` with the key `keyId` in the SDK's
     * own sheet, opened over the host activity. The SDK keeps the call across
     * the activity's recreation and answers it once, when the sheet closes.
     *
     * No activity is `NO_ACTIVITY`, which Dart turns into the API's own
     * `sign_failed` / `no_activity` JSON.
     */
    private fun handleSign(call: MethodCall, result: MethodChannel.Result) {
        val act = requireActivity(result) ?: return
        EImzoSDK.sign(
            act,
            call.argument<String>("keyId").orEmpty(),
            call.argument<String>("deepLink").orEmpty(),
            answerOnce(result),
        )
    }

    /**
     * Hands the SDK's JSON to Dart as it is. The SDK answers each Keys API
     * call once, on the main thread; this keeps [result] to a single reply
     * even if it did not, since a second one would throw in the app.
     */
    private fun answerOnce(result: MethodChannel.Result): EImzoResultCallback {
        val answered = AtomicBoolean(false)
        return EImzoResultCallback { json ->
            if (answered.compareAndSet(false, true)) result.success(json)
        }
    }

    /**
     * Launches the full e-imzo SDK UI ([EImzoActivity]) on top of the host
     * Flutter activity. Optional `deepLink` argument pre-fills the sign flow.
     */
    private fun handleOpenSignUi(call: MethodCall, result: MethodChannel.Result) {
        val act = requireActivity(result) ?: return
        val deepLink = call.argument<String>("deepLink")
        val intent = Intent(act, EImzoActivity::class.java).apply {
            if (deepLink != null) data = Uri.parse(deepLink)
        }
        act.startActivity(intent)
        result.success(null)
    }

    @OptIn(EImzoTesting::class)
    private fun handleInit(call: MethodCall, result: MethodChannel.Result) {
        val act = requireActivity(result) ?: return
        val environment =
            if (call.argument<String>("environment") == "dev") EImzoEnvironment.DEV else EImzoEnvironment.PROD
        val prodUrl = call.argument<String>("productionApiUrl")
        val testUrl = call.argument<String>("testApiUrl")
        val license = call.argument<String>("license")
        val debugLogging = call.argument<Boolean>("debugLogging") ?: false
        val config = EImzoConfig().let { defaults ->
            EImzoConfig(
                environment = environment,
                productionApiUrl = prodUrl ?: defaults.productionApiUrl,
                testApiUrl = testUrl ?: defaults.testApiUrl,
                debugLogging = debugLogging,
                license = license,
                appearance = call.argument<Map<String, Any?>>("appearance")?.let(::appearanceOf),
                language = call.argument<String>("language")?.let { enumOf<EImzoLanguage>(it) },
                showLanguagePicker = call.argument<Boolean>("showLanguagePicker") ?: true,
                hashDisplay = call.argument<String>("hashDisplay")?.let { enumOf<EImzoHashDisplay>(it) }
                    ?: EImzoHashDisplay.VISIBLE,
            )
        }
            // YT's own testing: --dart-define=EIMZO_GATEWAY_URL=…, which the
            // SDK takes in a debuggable build only.
            .withGatewayOverride(act, call.argument<String>("gatewayOverride"))
        // checkLicenseAndInit invokes its callback on Dispatchers.Main, so the
        // MethodChannel result can be completed directly.
        EImzoSDK.checkLicenseAndInit(act, config) { allowed -> result.success(allowed) }
    }

    /**
     * The appearance Dart sent (2.5.0): colours as `0xAARRGGBB` — over
     * 2^31, so they come as Long and are narrowed back to the same 32 bits —
     * and the font as the app's own asset files, which the SDK loads from
     * the APK by the path Flutter gives them.
     */
    private fun appearanceOf(map: Map<String, Any?>): EImzoAppearance {
        fun color(value: Any?): Int? = (value as? Number)?.toInt()
        fun palette(value: Any?): EImzoPalette? = (value as? Map<*, *>)?.let {
            EImzoPalette(
                primary = color(it["primary"]),
                background = color(it["background"]),
                surface = color(it["surface"]),
                text = color(it["text"]),
                textSecondary = color(it["textSecondary"]),
                divider = color(it["divider"]),
            )
        }
        val fonts = map["fonts"] as? Map<*, *>
        if (fonts == null) (map["fontFamily"] as? String)?.let { family ->
            // Dart found no files for it in the app's FontManifest.json — a
            // google_fonts download, say. Android needs the files.
            Log.w(TAG, "fontFamily \"$family\": ilova asset'larida shrift fayli yo'q — SDK o'z shriftida qoladi")
        }
        val path = { asset: Any? -> (asset as? String)?.let { a -> flutterAssets?.getAssetFilePathByName(a) } }
        return EImzoAppearance(
            light = palette(map["light"]),
            dark = palette(map["dark"]),
            themeMode = (map["themeMode"] as? String)?.let { enumOf<EImzoThemeMode>(it) } ?: EImzoThemeMode.SYSTEM,
            font = path(fonts?.get("regular"))?.let { regular ->
                EImzoFont.assets(
                    regular = regular,
                    medium = path(fonts?.get("medium")),
                    semibold = path(fonts?.get("semibold")),
                )
            },
            cornerRadius = (map["cornerRadius"] as? Number)?.toFloat(),
        )
    }

    /** Dart's enum name (`dark`, `ru`, `hidden`) as the SDK's constant, or null. */
    private inline fun <reified T : Enum<T>> enumOf(name: String): T? =
        enumValues<T>().firstOrNull { it.name.equals(name, ignoreCase = true) }

    /**
     * Returns the bound activity or completes [result] with `NO_ACTIVITY` and
     * returns null. Lets handlers fail fast with a single line:
     *   val act = requireActivity(result) ?: return
     */
    private fun requireActivity(result: MethodChannel.Result): Activity? {
        val act = activity
        if (act == null) result.error("NO_ACTIVITY", "Activity not attached", null)
        return act
    }

    // ── Activity lifecycle ──────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    private companion object {
        const val CHANNEL_METHOD = "uz.peachdev/eimzo_flutter"
        const val TAG = "EimzoFlutter"
    }
}
