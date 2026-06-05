package uz.peachdev.eimzo_flutter

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import uz.eimzo.sdk.EImzoConfig
import uz.eimzo.sdk.EImzoSDK
import uz.eimzo.sdk.SignCallback
import uz.eimzo.sdk.fullui.EImzoActivity
import uz.eimzo.sdk.models.SignResult

class EimzoFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.NewIntentListener {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var activity: Activity? = null
    private var pendingInitialLink: String? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL_METHOD)
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, CHANNEL_LINKS)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
            }
            override fun onCancel(args: Any?) {
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> handleInit(call, result)
            "getInitialDeeplink" -> result.success(pendingInitialLink.also { pendingInitialLink = null })
            "launchDeeplink" -> handleLaunchDeeplink(call, result)
            "openSignUi" -> handleOpenSignUi(call, result)
            "signWithUsbToken" -> handleSignWithUsbToken(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * High-level USB token sign — wraps [EImzoSDK.signWithUsbToken] which
     * handles deeplink parsing, FT-reader session, PIN validation, OzDST 1092
     * signing, and the `m.e-imzo.uz` backend round-trip.
     *
     * Returns `{"state": ..., "message": ...}` to Dart. The SDK already
     * marshals the callback onto the main (platform) thread, so this method
     * can hand the result directly to [result] without a Handler hop.
     */
    private fun handleSignWithUsbToken(call: MethodCall, result: MethodChannel.Result) {
        requireActivity(result) ?: return
        val pin = call.argument<String>("pin")
            ?: return result.error("ARG", "pin is required", null)
        val deepLink = call.argument<String>("deepLink")
            ?: return result.error("ARG", "deepLink is required", null)

        // Capture the channel result so the anonymous SignCallback can use the
        // supertype's parameter names without shadowing this outer `result`.
        val channelResult = result
        EImzoSDK.get().signWithUsbToken(pin, deepLink, object : SignCallback {
            override fun onSuccess(result: SignResult.Success) {
                channelResult.success(mapOf("state" to result.state, "message" to result.message))
            }
            override fun onError(error: SignResult.Failure) {
                channelResult.error(error.code ?: "SIGN_ERROR", error.error, null)
            }
        })
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

    private fun handleLaunchDeeplink(call: MethodCall, result: MethodChannel.Result) {
        val act = requireActivity(result) ?: return
        val url = call.argument<String>("url")
            ?: return result.error("ARG", "url is required", null)
        try {
            act.startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            result.success(null)
        } catch (e: ActivityNotFoundException) {
            result.error("NO_HANDLER", "No activity handles $url", null)
        }
    }

    private fun handleInit(call: MethodCall, result: MethodChannel.Result) {
        val act = requireActivity(result) ?: return
        val isTestMode = call.argument<Boolean>("isTestMode") ?: false
        val prodUrl = call.argument<String>("productionApiUrl")
        val testUrl = call.argument<String>("testApiUrl")
        val config = EImzoConfig().let { defaults ->
            EImzoConfig(
                isTestMode,
                prodUrl ?: defaults.productionApiUrl,
                testUrl ?: defaults.testApiUrl,
            )
        }
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

    // ── Activity lifecycle / deep links ─────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener(this)
        binding.activity.intent?.data?.takeIf { it.scheme == DEEP_LINK_SCHEME }?.let {
            pendingInitialLink = it.toString()
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onNewIntent(intent: Intent): Boolean {
        val data = intent.data ?: return false
        if (data.scheme != DEEP_LINK_SCHEME) return false
        val link = data.toString()
        pendingInitialLink = link
        eventSink?.success(link)
        return true
    }

    private companion object {
        const val CHANNEL_METHOD = "uz.peachdev/eimzo_flutter"
        const val CHANNEL_LINKS = "uz.peachdev/eimzo_flutter/links"
        const val DEEP_LINK_SCHEME = "eimzo"
    }
}
