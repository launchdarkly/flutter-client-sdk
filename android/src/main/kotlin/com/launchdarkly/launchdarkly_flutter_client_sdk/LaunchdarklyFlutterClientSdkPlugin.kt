package com.launchdarkly.launchdarkly_flutter_client_sdk

import android.app.Application
import android.net.Uri
import android.os.Handler
import android.os.Looper

import androidx.annotation.NonNull
import com.google.gson.*
import com.launchdarkly.android.*

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar

public class LaunchdarklyFlutterClientSdkPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel
  private lateinit var application: Application
  private lateinit var flagChangeListener: FeatureFlagChangeListener
  private lateinit var allFlagsListener: LDAllFlagsListener

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    application = flutterPluginBinding.applicationContext as Application
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "launchdarkly_flutter_client_sdk")
    setupListeners()
    channel.setMethodCallHandler(this)
  }

  private fun setupListeners() {
    flagChangeListener = FeatureFlagChangeListener { channel.invokeMethod("handleFlagUpdate", it) }
    allFlagsListener = LDAllFlagsListener { flagKeys: MutableList<String>? ->
      // invokeMethod must be called on main thread
      if (Looper.myLooper() == Looper.getMainLooper()) {
        channel.invokeMethod("handleFlagsReceived", flagKeys)
      } else {
        // Call ourselves on the main thread
        Handler(Looper.getMainLooper()).post { allFlagsListener.onChange(flagKeys) }
      }
    }
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
      plugin.channel = channel
      plugin.setupListeners()
      channel.setMethodCallHandler(plugin)
    }

    fun configFromMap(map: Map<String, Any>): LDConfig {
      val configBuilder = LDConfig.Builder()
      if (map["mobileKey"] is String) {
        configBuilder.setMobileKey(map["mobileKey"] as String)
      }
      if (map["pollUri"] is String) {
        configBuilder.setBaseUri(Uri.parse(map["pollUri"] as String))
      }
      if (map["eventsUri"] is String) {
        configBuilder.setEventsUri(Uri.parse((map["eventsUri"] as String) + "/mobile"))
      }
      if (map["streamUri"] is String) {
        configBuilder.setStreamUri(Uri.parse(map["streamUri"] as String))
      }
      if (map["eventsCapacity"] is Int) {
        configBuilder.setEventsCapacity(map["eventsCapacity"] as Int)
      }
      if (map["eventsFlushIntervalMillis"] is Int) {
        configBuilder.setEventsFlushIntervalMillis(map["eventsFlushIntervalMillis"] as Int)
      }
      if (map["connectionTimeoutMillis"] is Int) {
        configBuilder.setConnectionTimeoutMillis(map["connectionTimeoutMillis"] as Int)
      }
      if (map["pollingIntervalMillis"] is Int) {
        configBuilder.setPollingIntervalMillis(map["pollingIntervalMillis"] as Int)
      }
      if (map["backgroundPollingIntervalMillis"] is Int) {
        configBuilder.setBackgroundPollingIntervalMillis(map["backgroundPollingIntervalMillis"] as Int)
      }
      if (map["diagnosticRecordingIntervalMillis"] is Int) {
        configBuilder.setDiagnosticRecordingIntervalMillis(map["diagnosticRecordingIntervalMillis"] as Int)
      }
      if (map["stream"] is Boolean) {
        configBuilder.setStream(map["stream"] as Boolean)
      }
      if (map["offline"] is Boolean) {
        configBuilder.setOffline(map["offline"] as Boolean)
      }
      if (map["disableBackgroundUpdating"] is Boolean) {
        configBuilder.setDisableBackgroundUpdating(map["disableBackgroundUpdating"] as Boolean)
      }
      if (map["useReport"] is Boolean) {
        configBuilder.setUseReport(map["useReport"] as Boolean)
      }
      if (map["inlineUsersInEvents"] is Boolean) {
        configBuilder.setInlineUsersInEvents(map["inlineUsersInEvents"] as Boolean)
      }
      if (map["evaluationReasons"] is Boolean) {
        configBuilder.setEvaluationReasons(map["evaluationReasons"] as Boolean)
      }
      if (map["diagnosticOptOut"] is Boolean) {
        configBuilder.setDiagnosticOptOut(map["diagnosticOptOut"] as Boolean)
      }
      if (map["allAttributesPrivate"] is Boolean && map["allAttributesPrivate"] as Boolean) {
        configBuilder.allAttributesPrivate()
      }
      if (map["privateAttributeNames"] != null) {
        val privateAttributeNames = mutableSetOf<String>()
        for (name in map["privateAttributeNames"] as List<*>) {
          privateAttributeNames.add(name as String)
        }
        configBuilder.setPrivateAttributeNames(privateAttributeNames)
      }
      if (map["wrapperName"] is String) {
        configBuilder.setWrapperName(map["wrapperName"] as String)
      }
      if (map["wrapperVersion"] is String) {
        configBuilder.setWrapperVersion(map["wrapperVersion"] as String)
      }
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

    @Suppress("UNCHECKED_CAST")
    fun userFromMap(map: Map<String, Any>): LDUser {
      val userBuilder = LDUser.Builder(map["key"] as String)
      val anonymous = map["anonymous"] as? Boolean
      if (anonymous is Boolean) userBuilder.anonymous(anonymous)
      val privateAttrs = (map["privateAttributeNames"] as? ArrayList<String>) ?: ArrayList()
      for (field in optionalFields.keys) {
        if (map[field] is String) {
          (if (privateAttrs.contains(field)) optionalFields[field]!!.second else optionalFields[field]!!.first)(userBuilder, map[field] as String)
        }
      }
      if (map["custom"] != null) {
        for (entry in (map["custom"] as Map<String, Any>)) {
          val value = entry.value
          if (value is Boolean) {
            if (privateAttrs.contains(entry.key)) {
              userBuilder.privateCustom(entry.key, value)
            } else {
              userBuilder.custom(entry.key, value)
            }
          }
          else if (value is Number) {
            if (privateAttrs.contains(entry.key)) {
              userBuilder.privateCustom(entry.key, value)
            } else {
              userBuilder.custom(entry.key, value)
            }
          }
          else if (value is String) {
            if (privateAttrs.contains(entry.key)) {
              userBuilder.privateCustom(entry.key, value)
            } else {
              userBuilder.custom(entry.key, value)
            }
          }
          else if (value is List<*>) {
            if (value.isEmpty()) {
              if (privateAttrs.contains(entry.key)) {
                userBuilder.privateCustomNumber(entry.key, ArrayList())
              } else {
                userBuilder.customNumber(entry.key, ArrayList())
              }
            }
            else if (value[0] is Number) {
              if (privateAttrs.contains(entry.key)) {
                userBuilder.privateCustomNumber(entry.key, value as List<Number>)
              } else {
                userBuilder.customNumber(entry.key, value as List<Number>)
              }
            }
            else if (value[0] is String) {
              if (privateAttrs.contains(entry.key)) {
                userBuilder.privateCustomString(entry.key, value as List<String>)
              } else {
                userBuilder.customString(entry.key, value as List<String>)
              }
            }
          }
        }
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
        is Number -> {
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
          return null
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

    fun detailToBridge(value: Any?, variationIndex: Int?, reason: EvaluationReason?): Any? {
      val res = HashMap<String, Any?>()
      res["value"] = value
      res["variationIndex"] = variationIndex
      val reasonRes = HashMap<String, Any?>()
      reasonRes["kind"] = reason?.kind?.name
      when (reason) {
        is EvaluationReason.RuleMatch -> {
          reasonRes["ruleIndex"] = reason.ruleIndex
          reasonRes["ruleId"] = reason.ruleId
        }
        is EvaluationReason.PrerequisiteFailed -> {
          reasonRes["prerequisiteKey"] = reason.prerequisiteKey
        }
        is EvaluationReason.Error -> {
          reasonRes["errorKind"] = reason.errorKind.name
        }
      }
      res["reason"] = reasonRes
      return res
    }

    fun ldFailureToBridge(failure: LDFailure?): Any? {
      if (failure == null) return null
      val res = HashMap<String, Any?>()
      res["message"] = failure.message
      res["failureType"] = failure.failureType.name
      return res
    }

    fun connectionInformationToBridge(connectionInformation: ConnectionInformation?): Any? {
      if (connectionInformation == null) return null
      val res = HashMap<String, Any?>()
      res["connectionState"] = connectionInformation.connectionMode.name
      res["lastFailure"] = ldFailureToBridge(connectionInformation.lastFailure)
      res["lastSuccessfulConnection"] = connectionInformation.lastSuccessfulConnection
      res["lastFailedConnection"] = connectionInformation.lastFailedConnection
      return res
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "start" -> {
        val ldConfig: LDConfig = configFromMap(call.argument("config")!!)
        val ldUser: LDUser = userFromMap(call.argument("user")!!)
        val ldClient: LDClient = LDClient.init(application, ldConfig, ldUser, 5)
        ldClient.registerAllFlagsListener(allFlagsListener)
        result.success(null)
      }
      "identify" -> {
        val ldUser: LDUser = userFromMap(call.argument("user")!!)
        LDClient.get().identify(ldUser).get()
        result.success(null)
      }
      "track" -> {
        val data = jsonElementFromBridge(call.argument("data"))
        LDClient.get().track(call.argument("eventName"), data, call.argument("metricValue"))
        result.success(null)
      }
      "boolVariation" -> {
        val evalResult = LDClient.get().boolVariation(call.argument("flagKey"), call.argument("defaultValue"))
        result.success(evalResult)
      }
      "boolVariationDetail" -> {
        val evalResult = LDClient.get().boolVariationDetail(call.argument("flagKey"), call.argument("defaultValue"))
        result.success(detailToBridge(evalResult.value, evalResult.variationIndex, evalResult.reason))
      }
      "intVariation" -> {
        val evalResult = LDClient.get().intVariation(call.argument("flagKey"), call.argument("defaultValue"))
        result.success(evalResult)
      }
      "intVariationDetail" -> {
        val evalResult = LDClient.get().intVariationDetail(call.argument("flagKey"), call.argument("defaultValue"))
        result.success(detailToBridge(evalResult.value, evalResult.variationIndex, evalResult.reason))
      }
      "doubleVariation" -> {
        val defaultValue: Double? = call.argument("defaultValue")
        val evalResult = LDClient.get().floatVariation(call.argument("flagKey"), defaultValue?.toFloat())
        result.success(evalResult)
      }
      "doubleVariationDetail" -> {
        val defaultValue: Double? = call.argument("defaultValue")
        val evalResult = LDClient.get().floatVariationDetail(call.argument("flagKey"), defaultValue?.toFloat())
        result.success(detailToBridge(evalResult.value, evalResult.variationIndex, evalResult.reason))
      }
      "stringVariation" -> {
        val evalResult = LDClient.get().stringVariation(call.argument("flagKey"), call.argument("defaultValue"))
        result.success(evalResult)
      }
      "stringVariationDetail" -> {
        val evalResult = LDClient.get().stringVariationDetail(call.argument("flagKey"), call.argument("defaultValue"))
        result.success(detailToBridge(evalResult.value, evalResult.variationIndex, evalResult.reason))
      }
      "jsonVariation" -> {
        val defaultValue = jsonElementFromBridge(call.argument("defaultValue"))
        val evalResult = LDClient.get().jsonVariation(call.argument("flagKey"), defaultValue)
        result.success(jsonElementToBridge(evalResult))
      }
      "jsonVariationDetail" -> {
        val defaultValue = jsonElementFromBridge(call.argument("defaultValue"))
        val evalResult = LDClient.get().jsonVariationDetail(call.argument("flagKey"), defaultValue)
        result.success(detailToBridge(jsonElementToBridge(evalResult.value), evalResult.variationIndex, evalResult.reason))
      }
      "allFlags" -> {
        result.success(LDClient.get().allFlags())
      }
      "flush" -> {
        LDClient.get().flush()
        result.success(null)
      }
      "setOnline" -> {
        val online: Boolean? = call.argument("online")
        if (online == true) {
          LDClient.get().setOnline()
        } else if (online == false) {
          LDClient.get().setOffline()
        }
      }
      "isOnline" -> {
        result.success(!LDClient.get().isOffline)
      }
      "getConnectionInformation" -> {
        result.success(connectionInformationToBridge(LDClient.get().connectionInformation))
      }
      "startFlagListening" -> {
        LDClient.get().registerFeatureFlagListener(call.arguments as String, flagChangeListener)
        result.success(null)
      }
      "stopFlagListening" -> {
        LDClient.get().unregisterFeatureFlagListener(call.arguments as String, flagChangeListener)
        result.success(null)
      }
      "close" -> {
        LDClient.get().close()
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
