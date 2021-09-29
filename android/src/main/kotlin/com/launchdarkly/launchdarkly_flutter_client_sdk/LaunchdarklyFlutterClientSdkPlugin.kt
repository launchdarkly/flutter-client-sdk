package com.launchdarkly.launchdarkly_flutter_client_sdk

import android.app.Application
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull

import com.launchdarkly.sdk.*
import com.launchdarkly.sdk.android.*

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
        configBuilder.mobileKey(map["mobileKey"] as String)
      }
      if (map["pollUri"] is String) {
        configBuilder.pollUri(Uri.parse(map["pollUri"] as String))
      }
      if (map["eventsUri"] is String) {
        configBuilder.eventsUri(Uri.parse((map["eventsUri"] as String)))
      }
      if (map["streamUri"] is String) {
        configBuilder.streamUri(Uri.parse(map["streamUri"] as String))
      }
      if (map["eventsCapacity"] is Int) {
        configBuilder.eventsCapacity(map["eventsCapacity"] as Int)
      }
      if (map["eventsFlushIntervalMillis"] is Int) {
        configBuilder.eventsFlushIntervalMillis(map["eventsFlushIntervalMillis"] as Int)
      }
      if (map["connectionTimeoutMillis"] is Int) {
        configBuilder.connectionTimeoutMillis(map["connectionTimeoutMillis"] as Int)
      }
      if (map["pollingIntervalMillis"] is Int) {
        configBuilder.pollingIntervalMillis(map["pollingIntervalMillis"] as Int)
      }
      if (map["backgroundPollingIntervalMillis"] is Int) {
        configBuilder.backgroundPollingIntervalMillis(map["backgroundPollingIntervalMillis"] as Int)
      }
      if (map["diagnosticRecordingIntervalMillis"] is Int) {
        configBuilder.diagnosticRecordingIntervalMillis(map["diagnosticRecordingIntervalMillis"] as Int)
      }
      if (map["maxCachedUsers"] is Int) {
        configBuilder.maxCachedUsers(map["maxCachedUsers"] as Int)
      }
      if (map["stream"] is Boolean) {
        configBuilder.stream(map["stream"] as Boolean)
      }
      if (map["offline"] is Boolean) {
        configBuilder.offline(map["offline"] as Boolean)
      }
      if (map["disableBackgroundUpdating"] is Boolean) {
        configBuilder.disableBackgroundUpdating(map["disableBackgroundUpdating"] as Boolean)
      }
      if (map["useReport"] is Boolean) {
        configBuilder.useReport(map["useReport"] as Boolean)
      }
      if (map["inlineUsersInEvents"] is Boolean) {
        configBuilder.inlineUsersInEvents(map["inlineUsersInEvents"] as Boolean)
      }
      if (map["evaluationReasons"] is Boolean) {
        configBuilder.evaluationReasons(map["evaluationReasons"] as Boolean)
      }
      if (map["diagnosticOptOut"] is Boolean) {
        configBuilder.diagnosticOptOut(map["diagnosticOptOut"] as Boolean)
      }
      if (map["autoAliasingOptOut"] is Boolean) {
        configBuilder.autoAliasingOptOut(map["autoAliasingOptOut"] as Boolean)
      }
      if (map["allAttributesPrivate"] is Boolean && map["allAttributesPrivate"] as Boolean) {
        configBuilder.allAttributesPrivate()
      }
      if (map["privateAttributeNames"] is List<*>) {
        val privateAttrs = ArrayList<UserAttribute>()
        for (name in map["privateAttributeNames"] as List<*>) {
          if (name is String) {
            privateAttrs.add(UserAttribute.forName(name))
          }
        }
        configBuilder.privateAttributes(*privateAttrs.toTypedArray())
      }
      if (map["wrapperName"] is String) {
        configBuilder.wrapperName(map["wrapperName"] as String)
      }
      if (map["wrapperVersion"] is String) {
        configBuilder.wrapperVersion(map["wrapperVersion"] as String)
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
          if (privateAttrs.contains(entry.key)) {
            userBuilder.privateCustom(entry.key, valueFromBridge(entry.value))
          } else {
            userBuilder.custom(entry.key, valueFromBridge(entry.value))
          }
        }
      }
      return userBuilder.build()
    }

    fun valueFromBridge(dyn: Any?): LDValue {
      when (dyn) {
        null -> return LDValue.ofNull()
        is Boolean -> return LDValue.of(dyn)
        is Number -> return LDValue.of(dyn.toDouble())
        is String -> return LDValue.of(dyn)
        is ArrayList<*> -> {
          val arrBuilder = LDValue.buildArray()
          dyn.forEach {
            arrBuilder.add(valueFromBridge(it))
          }
          return arrBuilder.build()
        }
        else -> {
          val objBuilder = LDValue.buildObject()
          (dyn as HashMap<*, *>).forEach {
            objBuilder.put(it.key as String, valueFromBridge(it.value))
          }
          return objBuilder.build()
        }
      }
    }

    fun valueToBridge(ldValue: LDValue): Any? {
      when (ldValue.type) {
        null, LDValueType.NULL -> return null
        LDValueType.BOOLEAN -> return ldValue.booleanValue()
        LDValueType.NUMBER -> return ldValue.doubleValue()
        LDValueType.STRING -> return ldValue.stringValue()
        LDValueType.ARRAY -> {
          val res = ArrayList<Any?>()
          ldValue.values().forEach {
            res.add(valueToBridge(it))
          }
          return res
        }
        LDValueType.OBJECT -> {
          val res = HashMap<String, Any?>()
          ldValue.keys().forEach {
            res[it] = valueToBridge(ldValue.get(it))
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
      when (reason?.kind) {
        EvaluationReason.Kind.RULE_MATCH -> {
          reasonRes["ruleIndex"] = reason.ruleIndex
          reasonRes["ruleId"] = reason.ruleId
          reasonRes["inExperiment"] = reason.isInExperiment
        }
        EvaluationReason.Kind.PREREQUISITE_FAILED -> {
          reasonRes["prerequisiteKey"] = reason.prerequisiteKey
        }
        EvaluationReason.Kind.FALLTHROUGH -> {
          reasonRes["inExperiment"] = reason.isInExperiment
        }
        EvaluationReason.Kind.ERROR -> {
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
      "alias" -> {
        val user: LDUser = userFromMap(call.argument("user")!!)
        val previousUser: LDUser = userFromMap(call.argument("previousUser")!!)
        LDClient.get().alias(user, previousUser)
        result.success(null)
      }
      "track" -> {
        val data = valueFromBridge(call.argument("data"))
        val metric: Double? = call.argument("metricValue")
        if (metric == null) {
          LDClient.get().trackData(call.argument("eventName"), data)
        } else {
          LDClient.get().trackMetric(call.argument("eventName"), data, metric)
        }
        result.success(null)
      }
      "boolVariation" -> {
        val evalResult = LDClient.get().boolVariation(call.argument("flagKey")!!, call.argument("defaultValue")!!)
        result.success(evalResult)
      }
      "boolVariationDetail" -> {
        val evalResult = LDClient.get().boolVariationDetail(call.argument("flagKey")!!, call.argument("defaultValue")!!)
        result.success(detailToBridge(evalResult.value, evalResult.variationIndex, evalResult.reason))
      }
      "intVariation" -> {
        val evalResult: Int = LDClient.get().intVariation(call.argument("flagKey")!!, call.argument("defaultValue")!!)
        result.success(evalResult)
      }
      "intVariationDetail" -> {
        val evalResult = LDClient.get().intVariationDetail(call.argument("flagKey")!!, call.argument("defaultValue")!!)
        result.success(detailToBridge(evalResult.value, evalResult.variationIndex, evalResult.reason))
      }
      "doubleVariation" -> {
        val evalResult = LDClient.get().doubleVariation(call.argument("flagKey")!!, call.argument("defaultValue")!!)
        result.success(evalResult)
      }
      "doubleVariationDetail" -> {
        val evalResult = LDClient.get().doubleVariationDetail(call.argument("flagKey")!!, call.argument("defaultValue")!!)
        result.success(detailToBridge(evalResult.value, evalResult.variationIndex, evalResult.reason))
      }
      "stringVariation" -> {
        val evalResult = LDClient.get().stringVariation(call.argument("flagKey")!!, call.argument("defaultValue"))
        result.success(evalResult)
      }
      "stringVariationDetail" -> {
        val evalResult = LDClient.get().stringVariationDetail(call.argument("flagKey")!!, call.argument("defaultValue"))
        result.success(detailToBridge(evalResult.value, evalResult.variationIndex, evalResult.reason))
      }
      "jsonVariation" -> {
        val defaultValue = valueFromBridge(call.argument("defaultValue"))
        val evalResult = LDClient.get().jsonValueVariation(call.argument("flagKey")!!, defaultValue)
        result.success(valueToBridge(evalResult))
      }
      "jsonVariationDetail" -> {
        val defaultValue = valueFromBridge(call.argument("defaultValue"))
        val evalResult = LDClient.get().jsonValueVariationDetail(call.argument("flagKey")!!, defaultValue)
        result.success(detailToBridge(valueToBridge(evalResult.value), evalResult.variationIndex, evalResult.reason))
      }
      "allFlags" -> {
        var allFlagsBridge = HashMap<String, Any?>()
        val allFlags = LDClient.get().allFlags()
        allFlags.forEach {
          allFlagsBridge[it.key] = valueToBridge(it.value);
        }
        result.success(allFlagsBridge);
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
