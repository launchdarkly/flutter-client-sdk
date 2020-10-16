package com.launchdarkly.launchdarkly_flutter_client_sdk

import android.app.Application
import android.net.Uri

import androidx.annotation.NonNull
import com.google.gson.*

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar

import com.launchdarkly.android.LDAllFlagsListener
import com.launchdarkly.android.ConnectionInformation
import com.launchdarkly.android.FeatureFlagChangeListener
import com.launchdarkly.android.LDClient
import com.launchdarkly.android.LDConfig
import com.launchdarkly.android.LDFailure
import com.launchdarkly.android.LDStatusListener
import com.launchdarkly.android.LDUser

public class LaunchdarklyFlutterClientSdkPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel
  private lateinit var application: Application

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    application = flutterPluginBinding.getApplicationContext() as Application
    channel = MethodChannel(flutterPluginBinding.flutterEngine.dartExecutor, "launchdarkly_flutter_client_sdk")
    channel.setMethodCallHandler(this)
  }

  companion object {
    // This static function is optional and equivalent to onAttachedToEngine. It supports the old
    // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
    // plugin registration via this function while apps migrate to use the new Android APIs
    // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "launchdarkly_flutter_client_sdk")
      val plugin = LaunchdarklyFlutterClientSdkPlugin()
      plugin.application = registrar.context() as Application
      channel.setMethodCallHandler(plugin)
    }

    fun configFromMap(map: Map<String, Any>): LDConfig {
      val configBuilder = LDConfig.Builder()
      if (map["mobileKey"] != null) {
        configBuilder.setMobileKey(map["mobileKey"] as String)
      }
      if (map["baseUri"] != null) {
        configBuilder.setBaseUri(Uri.parse(map["baseUri"] as String))
      }
      if (map["eventsUri"] != null) {
        configBuilder.setEventsUri(Uri.parse(map["eventsUri"] as String))
      }
      if (map["streamUri"] != null) {
        configBuilder.setStreamUri(Uri.parse(map["streamUri"] as String))
      }
      if (map["eventsCapacity"] != null) {
        configBuilder.setEventsCapacity(map["eventsCapacity"] as Int)
      }
      if (map["eventsFlushIntervalMillis"] != null) {
        configBuilder.setEventsFlushIntervalMillis(map["eventsFlushIntervalMillis"] as Int)
      }
      if (map["connectionTimeoutMillis"] != null) {
        configBuilder.setConnectionTimeoutMillis(map["connectionTimeoutMillis"] as Int)
      }
      if (map["pollingIntervalMillis"] != null) {
        configBuilder.setPollingIntervalMillis(map["pollingIntervalMillis"] as Int)
      }
      if (map["backgroundPollingIntervalMillis"] != null) {
        configBuilder.setBackgroundPollingIntervalMillis(map["backgroundPollingIntervalMillis"] as Int)
      }
      if (map["diagnosticRecordingIntervalMillis"] != null) {
        configBuilder.setDiagnosticRecordingIntervalMillis(map["diagnosticRecordingIntervalMillis"] as Int)
      }
      if (map["stream"] != null) {
        configBuilder.setStream(map["stream"] as Boolean)
      }
      if (map["offline"] != null) {
        configBuilder.setOffline(map["offline"] as Boolean)
      }
      if (map["disableBackgroundUpdating"] != null) {
        configBuilder.setDisableBackgroundUpdating(map["disableBackgroundUpdating"] as Boolean)
      }
      if (map["useReport"] != null) {
        configBuilder.setUseReport(map["useReport"] as Boolean)
      }
      if (map["inlineUsersInEvents"] != null) {
        configBuilder.setInlineUsersInEvents(map["inlineUsersInEvents"] as Boolean)
      }
      if (map["evaluationReasons"] != null) {
        configBuilder.setEvaluationReasons(map["evaluationReasons"] as Boolean)
      }
      if (map["diagnosticOptOut"] != null) {
        configBuilder.setDiagnosticOptOut(map["diagnosticOptOut"] as Boolean)
      }
      if (map["allAttributesPrivate"] != null && map["allAttributesPrivate"] as Boolean) {
        configBuilder.allAttributesPrivate()
      }
      if (map["privateAttributeNames"] != null) {
        val privateAttributeNames = mutableSetOf<String>()
        for (name in map["privateAttributeNames"] as List<*>) {
          privateAttributeNames.add(name as String)
        }
        configBuilder.setPrivateAttributeNames(privateAttributeNames)
      }
      configBuilder.setWrapperName("FlutterClientSdk")
      // TODO wrapper version
      return configBuilder.build()
    }

    private val optionalFields: Map<String, Pair<(LDUser.Builder, String) -> Unit, (LDUser.Builder, String) -> Unit>> = mapOf(
            "secondary" to Pair({u, s -> u.secondary(s)}, {u, s -> u.privateSecondary(s)}),
            "ip" to Pair({u, s -> u.ip(s)}, {u, s -> u.privateIp(s)}),
            "email" to Pair({u, s -> u.email(s)}, {u ,s -> u.privateEmail(s)}),
            "name" to Pair({u, s -> u.name(s)}, {u, s -> u.privateName(s)}),
            "firstName" to Pair({u, s -> u.firstName(s)}, {u, s -> u.privateFirstName(s)}),
            "lastName" to Pair({u, s -> u.lastName(s)}, {u, s -> u.privateLastName(s)}),
            "avatar" to Pair({u, s -> u.avatar(s)}, {u, s -> u.privateAvatar(s)}),
            "country" to Pair({u, s -> u.country(s)}, {u, s -> u.privateCountry(s)}))

    fun userFromMap(map: Map<String, Any>): LDUser {
      val userBuilder = LDUser.Builder(map["key"] as String)
      val anonymous = map["anonymous"] as? Boolean
      if (anonymous is Boolean) userBuilder.anonymous(anonymous)
      @Suppress("UNCHECKED_CAST")
      val privateAttrs = (map["privateAttributeNames"] as? ArrayList<String>) ?: ArrayList()
      for (field in optionalFields.keys) {
        if (map[field] != null) {
          (if (privateAttrs.contains(field)) optionalFields[field]!!.second else optionalFields[field]!!.first)(userBuilder, map[field] as String)
        }
      }
      if (map["custom"] != null) {
//        for (entry in (map["custom"] as Map<String, Any>)) {
//        }
      }
      return userBuilder.build()
    }

    fun jsonElementFromBridge(dyn: Any?): JsonElement {
      when (dyn) {
        null -> {
          return JsonNull.INSTANCE
        }
        is Boolean -> {
          return JsonPrimitive(dyn)
        }
        is Int -> {
          return JsonPrimitive(dyn)
        }
        is Long -> {
          return JsonPrimitive(dyn)
        }
        is Double -> {
          return JsonPrimitive(dyn)
        }
        is String -> {
          return JsonPrimitive(dyn)
        }
        is ArrayList<*> -> {
          val jsonArr = JsonArray()
          dyn.forEach {
            jsonArr.add(jsonElementFromBridge(it))
          }
          return jsonArr
        }
        else -> {
          val jsonObj = JsonObject()
          (dyn as HashMap<*, *>).forEach {
            jsonObj.add(it.key as String, jsonElementFromBridge(it.value))
          }
          return jsonObj
        }
      }
    }

    fun jsonElementToBridge(jsonElement: JsonElement?): Any? {
      when {
        jsonElement == null || jsonElement.isJsonNull -> {
          return null;
        }
        jsonElement is JsonPrimitive && jsonElement.isBoolean -> {
          return jsonElement.asBoolean
        }
        jsonElement is JsonPrimitive && jsonElement.isNumber -> {
          return jsonElement.asDouble
        }
        jsonElement is JsonPrimitive -> {
          return jsonElement.asString
        }
        jsonElement is JsonArray -> {
          val res = ArrayList<Any?>()
          jsonElement.forEach {
            res.add(jsonElementToBridge(it))
          }
          return res
        }
        else -> {
          val res = HashMap<String, Any?>()
          jsonElement.asJsonObject.entrySet().forEach {
            res[it.key] = jsonElementToBridge(it.value)
          }
          return res
        }
      }
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "start" -> {
        val ldConfig: LDConfig = configFromMap(call.argument("config")!!)
        val ldUser: LDUser = userFromMap(call.argument("user")!!)
        val ldClient: LDClient = LDClient.init(application, ldConfig, ldUser, 5)
        result.success(null)
      }
      "identify" -> {
        val ldUser: LDUser = userFromMap(call.argument("user")!!)
        LDClient.get().identify(ldUser).get()
        result.success(null)
      }
      "track" -> {
        LDClient.get().track(call.argument("eventName"))
        result.success(null)
      }
      "boolVariation" -> {
        val evalResult = LDClient.get().boolVariation(call.argument("flagKey"), call.argument("defaultValue"))
        result.success(evalResult)
      }
      "intVariation" -> {
        // TODO: bridge can provide Long rather than int if number is larger than MAXINT
        val evalResult = LDClient.get().intVariation(call.argument("flagKey"), call.argument("defaultValue"))
        result.success(evalResult)
      }
      "doubleVariation" -> {
        val defaultValue: Double? = call.argument("defaultValue")
        val evalResult = LDClient.get().floatVariation(call.argument("flagKey"), defaultValue?.toFloat())
        result.success(evalResult)
      }
      "stringVariation" -> {
        val evalResult = LDClient.get().stringVariation(call.argument("flagKey"), call.argument("defaultValue"))
        result.success(evalResult)
      }
      "jsonVariation" -> {
        val evalResult = LDClient.get().jsonVariation(call.argument("flagKey"), jsonElementFromBridge(call.argument("defaultValue")))
        result.success(jsonElementToBridge(evalResult))
      }
      "allFlags" -> {
        result.success(LDClient.get().allFlags())
      }
      "setOnline" -> {
        val online: Boolean? = call.argument("online")
        if (online == true) {
          LDClient.get().setOnline()
        } else if (online == false) {
          LDClient.get().setOffline()
        }
      }
      "flush" -> {
        LDClient.get().flush()
        result.success(null)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
