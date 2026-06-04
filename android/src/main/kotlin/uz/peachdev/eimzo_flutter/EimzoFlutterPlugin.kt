package uz.peachdev.eimzo_flutter

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import uz.eimzo.sdk.EImzoConfig
import uz.eimzo.sdk.EImzoSDK
import uz.eimzo.sdk.fullui.EImzoActivity

class EimzoFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.NewIntentListener {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var activity: Activity? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingInitialLink: String? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "uz.peachdev/eimzo_flutter")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "uz.peachdev/eimzo_flutter/links")
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
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> handleInit(call, result)
            "getInitialDeeplink" -> {
                val link = pendingInitialLink
                pendingInitialLink = null
                result.success(link)
            }
            "launchDeeplink" -> handleLaunchDeeplink(call, result)
            "openSignUi" -> handleOpenSignUi(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * Launches the full e-imzo SDK UI ([EImzoActivity]) on top of the host
     * Flutter activity. Optional `deepLink` argument pre-fills the sign flow.
     */
    private fun handleOpenSignUi(call: MethodCall, result: MethodChannel.Result) {
        val act = activity ?: return result.error("NO_ACTIVITY", "Activity not attached", null)
        val deepLink = call.argument<String>("deepLink")
        val intent = Intent(act, EImzoActivity::class.java).apply {
            if (deepLink != null) data = Uri.parse(deepLink)
        }
        act.startActivity(intent)
        result.success(null)
    }

    private fun handleLaunchDeeplink(call: MethodCall, result: MethodChannel.Result) {
        val act = activity ?: return result.error("NO_ACTIVITY", "Activity not attached", null)
        val url = call.argument<String>("url")
            ?: return result.error("ARG", "url is required", null)
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            act.startActivity(intent)
            result.success(null)
        } catch (e: ActivityNotFoundException) {
            result.error("NO_HANDLER", "No activity handles $url", null)
        }
    }

    private fun handleInit(call: MethodCall, result: MethodChannel.Result) {
        val act = activity ?: return result.error("NO_ACTIVITY", "Activity not attached", null)
        val isTestMode = call.argument<Boolean>("isTestMode") ?: false
        val prodUrl = call.argument<String>("productionApiUrl")
        val testUrl = call.argument<String>("testApiUrl")
        val defaults = EImzoConfig()
        val config = EImzoConfig(
            isTestMode,
            prodUrl ?: defaults.productionApiUrl,
            testUrl ?: defaults.testApiUrl,
        )
        EImzoSDK.checkLicenseAndInit(act, config) { allowed ->
            mainHandler.post { result.success(allowed) }
        }
    }

    // ── Activity lifecycle / deep links ─────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener(this)
        val link = binding.activity.intent?.data?.takeIf { it.scheme == "eimzo" }?.toString()
        if (link != null) pendingInitialLink = link
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
        if (data.scheme != "eimzo") return false
        val link = data.toString()
        pendingInitialLink = link
        eventSink?.success(link)
        return true
    }
}
