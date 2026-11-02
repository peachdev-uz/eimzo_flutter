package uz.peachdev.eimzo_flutter

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import uz.eimzo.sdk.EImzoConfig
import uz.eimzo.sdk.EImzoEnvironment
import uz.eimzo.sdk.EImzoSDK
import uz.eimzo.sdk.EImzoTesting
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

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL_METHOD)
        methodChannel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> handleInit(call, result)
            "openSignUi" -> handleOpenSignUi(call, result)
            else -> result.notImplemented()
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
    }
}
