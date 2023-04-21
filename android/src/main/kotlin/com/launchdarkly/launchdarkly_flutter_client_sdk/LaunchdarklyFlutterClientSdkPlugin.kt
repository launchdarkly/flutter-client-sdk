package com.launchdarkly.launchdarkly_flutter_client_sdk

import android.app.Application
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import com.launchdarkly.sdk.EvaluationReason
import com.launchdarkly.sdk.LDContext
import com.launchdarkly.sdk.LDUser
import com.launchdarkly.sdk.LDValue
import com.launchdarkly.sdk.LDValueType
import com.launchdarkly.sdk.android.Components
import com.launchdarkly.sdk.android.ConnectionInformation
import com.launchdarkly.sdk.android.FeatureFlagChangeListener
import com.launchdarkly.sdk.android.LDAllFlagsListener
import com.launchdarkly.sdk.android.LDClient
import com.launchdarkly.sdk.android.LDConfig
import com.launchdarkly.sdk.android.LDFailure
import com.launchdarkly.sdk.android.LaunchDarklyException
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import kotlinx.coroutines.*
import java.util.concurrent.Future
import kotlin.concurrent.thread

public class LaunchdarklyFlutterClientSdkPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel
  private lateinit var application: Application
  private lateinit var flagChangeListener: FeatureFlagChangeListener
  private lateinit var allFlagsListener: LDAllFlagsListener
  private val defaultScope = CoroutineScope(Dispatchers.Default)

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    application = flutterPluginBinding.applicationContext as Application
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "launchdarkly_flutter_client_sdk")
    setupListeners()
    channel.setMethodCallHandler(this)
  }

  private fun callFlutter(method: String, arguments: Any?) {
      // invokeMethod must be called on main thread
      if (Looper.myLooper() == Looper.getMainLooper()) {
        channel.invokeMethod(method, arguments)
      } else {
        // Call ourselves on the main thread
        Handler(Looper.getMainLooper()).post { callFlutter(method, arguments) }
      }
  }

  private fun setupListeners() {
    flagChangeListener = FeatureFlagChangeListener { channel.invokeMethod("handleFlagUpdate", it) }
    allFlagsListener = LDAllFlagsListener {
      callFlutter("handleFlagsReceived", it)
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

    private inline fun <reified T> whenIs(value: Any?, call: (value: T) -> Unit) {
      if (value is T) {
        call(value as T)
      }
    }

    fun configFromMap(map: Map<String, Any>, configBuilder: LDConfig.Builder): LDConfig {
      whenIs<String>(map["mobileKey"]) { configBuilder.mobileKey(it) }
      whenIs<Int>(map["maxCachedContexts"]) { configBuilder.maxCachedContexts(it) }
      whenIs<Boolean>(map["offline"]) { configBuilder.offline(it) }
      whenIs<Boolean>(map["disableBackgroundUpdating"]) { configBuilder.disableBackgroundUpdating(it) }
      whenIs<Boolean>(map["evaluationReasons"]) { configBuilder.evaluationReasons(it) }
      whenIs<Boolean>(map["diagnosticOptOut"]) { configBuilder.diagnosticOptOut(it) }

      configBuilder.applicationInfo(
              Components.applicationInfo().apply {
                whenIs<String>(map["applicationId"]) { this.applicationId(it) }
                whenIs<String>(map["applicationVersion"]) { this.applicationVersion(it) }
              }
      )

      configBuilder.serviceEndpoints(
              Components.serviceEndpoints().apply {
                whenIs<String>(map["pollUri"]) { this.polling(it) }
                whenIs<String>(map["eventsUri"]) { this.events(it) }
                whenIs<String>(map["streamUri"]) { this.streaming(it) }
              }
      )

      configBuilder.dataSource(
              if (map["stream"] is Boolean && !(map["stream"] as Boolean)) {
                // use polling data source if stream is false
                Components.pollingDataSource().apply {
                  whenIs<Int>(map["pollingIntervalMillis"]) { this.pollIntervalMillis(it) }
                  whenIs<Int>(map["backgroundPollingIntervalMillis"]) { this.backgroundPollIntervalMillis(it) }
                }
              } else {
                // use streaming data source by default (including if stream is absent)
                Components.streamingDataSource().apply {
                  whenIs<Int>(map["backgroundPollingIntervalMillis"]) { this.backgroundPollIntervalMillis(it) }
                }
              }
      )

      configBuilder.events(
              Components.sendEvents().apply {
                whenIs<Int>(map["eventsCapacity"]) { this.capacity(it) }
                whenIs<Int>(map["eventsFlushIntervalMillis"]) { this.flushIntervalMillis(it) }
                whenIs<Int>(map["diagnosticRecordingIntervalMillis"]) { this.diagnosticRecordingIntervalMillis(it) }

                if (map["allAttributesPrivate"] is Boolean) {
                  this.allAttributesPrivate(map["allAttributesPrivate"] as Boolean)
                }
                whenIs<List<*>>(map["privateAttributeNames"]) {
                  val privateAttrs = ArrayList<String>()
                  for (name in it) {
                    if (name is String) {
                      privateAttrs.add(name)
                    }
                  }
                  this.privateAttributes(*privateAttrs.toTypedArray())
                }
              }
      )

      configBuilder.http(
              Components.httpConfiguration().apply {
                whenIs<Int>(map["connectionTimeoutMillis"]) { this.connectTimeoutMillis(it) }
                whenIs<Boolean>(map["useReport"]) { this.useReport(it) }
                if (map["wrapperName"] is String && map["wrapperName"] is String) {
                  this.wrapper(map["wrapperName"] as String, map["wrapperName"] as String)
                }
              }
      )

      return configBuilder.build()
    }

    private val optionalFields: Map<String, Pair<(LDUser.Builder, String) -> Unit, (LDUser.Builder, String) -> Unit>> = mapOf(
            "ip" to Pair({u, s -> u.ip(s)}, {u, s -> u.privateIp(s)}),
            "email" to Pair({u, s -> u.email(s)}, {u ,s -> u.privateEmail(s)}),
            "name" to Pair({u, s -> u.name(s)}, {u, s -> u.privateName(s)}),
            "firstName" to Pair({u, s -> u.firstName(s)}, {u, s -> u.privateFirstName(s)}),
            "lastName" to Pair({u, s -> u.lastName(s)}, {u, s -> u.privateLastName(s)}),
            "avatar" to Pair({u, s -> u.avatar(s)}, {u, s -> u.privateAvatar(s)}),
            "country" to Pair({u, s -> u.country(s)}, {u, s -> u.privateCountry(s)}))

    @Suppress("UNCHECKED_CAST")
    fun userFrom(map: Map<String, Any>): LDUser {
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

    /**
     * Creates a [LDContext] from the provided list of contexts provided, each in map form.
     *
     * @param list - the list of dictionaries of serialized contexts.  Note that the format
     * of this dict is unique to the Flutter MethodChannel because it has kind and key as neighbors
     * at the same level in the dict.
     */
    @Suppress("UNCHECKED_CAST")
    fun contextFrom(list: List<Map<String, Any>>): LDContext {
      val multiBuilder = LDContext.multiBuilder()
      list.forEach {
        val contextBuilder = LDContext.builder(it["key"] as? String);
        for (entry in it) {
          // ignore _meta
          if (entry.key == "_meta") {
            continue
          }

          contextBuilder.set(entry.key, valueFromBridge(entry.value))
        }

        // grab private attributes out of _meta field if they are there
        val metaMap = (it["_meta"] as? Map<String, Any>) ?: emptyMap()
        val privateAttrs = (metaMap["privateAttributes"] as? ArrayList<String>) ?: ArrayList()
        contextBuilder.privateAttributes(*privateAttrs.toTypedArray()) // * is spread operator

        multiBuilder.add(contextBuilder.build());
      }

      return multiBuilder.build();
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
        else -> {}
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
        defaultScope.launch {
          withContext(Dispatchers.IO) {
            val ldConfig: LDConfig = configFromMap(call.argument("config")!!, LDConfig.Builder())

            // Set up initialization lambdas for each type of context.  This is just easier to read
            // down below when we go to make the actual calls.
            var initClient: () -> Future<*>;
            var identClient: (c: LDClient) -> Future<*>;
            if (call.hasArgument("user")) {
              // try user first
              val ldUser: LDUser = userFrom(call.argument("user")!!)
              initClient = { LDClient.init(application, ldConfig, ldUser)}
              identClient = { c : LDClient -> c.identify(ldUser)}
            } else {
              // fallback is context since that is the more general case
              val ldContext: LDContext = contextFrom(call.argument("context")!!)
              initClient = { LDClient.init(application, ldConfig, ldContext)}
              identClient = { c : LDClient -> c.identify(ldContext)}
            }

            var completion: Future<*>
            try {
              val instance = LDClient.get()
              // We've already initialized the native SDK so just switch to the new user.
              completion = identClient(instance)
            } catch (ignored: LaunchDarklyException) {
              // We have not already initialized the native SDK.
              completion = initClient()
              LDClient.get().registerAllFlagsListener(allFlagsListener)
            }
            try {
              completion.get()
            } finally {
              callFlutter("completeStart", null)
            }
          }
        }

        result.success(null)
      }
      "identify" -> {
        defaultScope.launch {
          withContext(Dispatchers.IO) {
            var completion: Future<*>
            completion = if (call.hasArgument("user")) {
              val ldUser: LDUser = userFrom(call.argument("user")!!)
              LDClient.get().identify(ldUser)
            } else {
              val ldContext: LDContext = contextFrom(call.argument("context")!!)
              LDClient.get().identify(ldContext)
            }
            try {
              completion.get()
            } finally {
              result.success(null)
            }
          }
        }
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
          allFlagsBridge[it.key] = valueToBridge(it.value)
        }
        result.success(allFlagsBridge)
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
      "isOffline" -> {
        result.success(LDClient.get().isOffline)
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
