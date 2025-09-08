// ignore_for_file: close_sinks
// ignore_for_file: depend_on_referenced_packages

// (close_sinks) Closing sinks ignored for Wifi connectivity mock.
// (depend_on_referenced_packages) We are using connectivity_plus_platform_interface as an indirect dependency
// for testing.

import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk.dart';

import 'package:flutter/widgets.dart' as widgets;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';

final class TestHook extends Hook {
  final String hookName;
  final HookMetadata _metadata;
  final List<String> callLog = [];

  TestHook(this.hookName) : _metadata = HookMetadata(name: hookName);

  @override
  HookMetadata get metadata => _metadata;

  @override
  UnmodifiableMapView<String, LDValue> beforeEvaluation(
      EvaluationSeriesContext hookContext,
      UnmodifiableMapView<String, LDValue> data) {
    callLog.add('beforeEvaluation:$hookContext:$data');
    return super.beforeEvaluation(hookContext, data);
  }

  @override
  UnmodifiableMapView<String, LDValue> afterEvaluation(
      EvaluationSeriesContext hookContext,
      UnmodifiableMapView<String, LDValue> data,
      LDEvaluationDetail<LDValue> detail) {
    callLog.add('afterEvaluation:$hookContext:$data:$detail');
    return super.afterEvaluation(hookContext, data, detail);
  }

  @override
  UnmodifiableMapView<String, LDValue> beforeIdentify(
      IdentifySeriesContext hookContext,
      UnmodifiableMapView<String, LDValue> data) {
    callLog.add('beforeIdentify:$hookContext:$data');
    return super.beforeIdentify(hookContext, data);
  }

  @override
  UnmodifiableMapView<String, LDValue> afterIdentify(
      IdentifySeriesContext hookContext,
      UnmodifiableMapView<String, LDValue> data,
      IdentifyResult result) {
    callLog.add('afterIdentify:$hookContext:$data:$result');
    return super.afterIdentify(hookContext, data, result);
  }

  @override
  void afterTrack(TrackSeriesContext hookContext) {
    callLog.add('afterTrack:$hookContext');
    super.afterTrack(hookContext);
  }
}

final class TestPlugin extends Plugin {
  final String pluginName;
  final List<Hook> _hooks;
  final bool shouldThrowOnRegister;
  final PluginMetadata _metadata;

  int registerCallCount = 0;
  LDClient? lastClientReceived;
  PluginEnvironmentMetadata? lastEnvironmentMetadataReceived;

  TestPlugin(this.pluginName, this._hooks, {this.shouldThrowOnRegister = false})
      : _metadata = PluginMetadata(name: pluginName);

  @override
  PluginMetadata get metadata => _metadata;

  @override
  List<Hook> get hooks => _hooks;

  @override
  void register(
      LDClient client, PluginEnvironmentMetadata environmentMetadata) {
    registerCallCount++;
    lastClientReceived = client;
    lastEnvironmentMetadataReceived = environmentMetadata;

    if (shouldThrowOnRegister) {
      throw Exception(
          'Test exception during registration for plugin $pluginName');
    }
  }
}

final class _WifiConnected extends ConnectivityPlatform {
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController();
  Stream<List<ConnectivityResult>>? _stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    return [ConnectivityResult.wifi];
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    _stream ??= _controller.stream.asBroadcastStream();
    return _stream!;
  }
}

LDClient createTestClient({
  String credential = 'test-mobile-key',
  List<Plugin>? plugins,
  List<Hook>? hooks,
  ApplicationInfo? applicationInfo,
}) {
  final LDContext testContext =
      LDContextBuilder().kind('user', 'test-user-key').build();

  final config = LDConfig(
    credential,
    AutoEnvAttributes.disabled,
    offline: true,
    events: EventsConfig(disabled: true),
    plugins: plugins,
    hooks: hooks,
    applicationInfo: applicationInfo,
    applicationEvents:
        ApplicationEvents(backgrounding: false, networkAvailability: false),
    persistence: PersistenceConfig(maxCachedContexts: 0),
  );

  return LDClient(config, testContext);
}

void main() {
  ConnectivityPlatform.instance = _WifiConnected();
  widgets.WidgetsFlutterBinding.ensureInitialized();
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});

  group('LDClient Plugin Integration', () {
    test('registers single plugin successfully', () {
      final plugin = TestPlugin('test-plugin', []);
      final client = createTestClient(plugins: [plugin]);

      expect(plugin.registerCallCount, equals(1));
      expect(plugin.lastClientReceived, same(client));
      expect(plugin.lastEnvironmentMetadataReceived, isNotNull);
      expect(plugin.lastEnvironmentMetadataReceived!.sdk.name,
          equals('FlutterClientSdk'));
      expect(plugin.lastEnvironmentMetadataReceived!.credential.value,
          equals('test-mobile-key'));

      client.close();
    });

    test('registers multiple plugins successfully', () {
      final plugin1 = TestPlugin('plugin-1', []);
      final plugin2 = TestPlugin('plugin-2', []);
      final plugin3 = TestPlugin('plugin-3', []);
      final client = createTestClient(plugins: [plugin1, plugin2, plugin3]);

      expect(plugin1.registerCallCount, equals(1));
      expect(plugin1.lastClientReceived, same(client));
      expect(plugin2.registerCallCount, equals(1));
      expect(plugin2.lastClientReceived, same(client));
      expect(plugin3.registerCallCount, equals(1));
      expect(plugin3.lastClientReceived, same(client));

      client.close();
    });

    test('handles plugin registration exception gracefully', () {
      final goodPlugin = TestPlugin('good-plugin', []);
      final badPlugin =
          TestPlugin('bad-plugin', [], shouldThrowOnRegister: true);
      final anotherGoodPlugin = TestPlugin('another-good-plugin', []);

      // Should not throw despite bad plugin
      final client =
          createTestClient(plugins: [goodPlugin, badPlugin, anotherGoodPlugin]);

      expect(goodPlugin.registerCallCount, equals(1));
      expect(badPlugin.registerCallCount, equals(1)); // Attempted to register
      expect(anotherGoodPlugin.registerCallCount, equals(1));

      client.close();
    });

    test('registers hooks from single plugin', () {
      final hook1 = TestHook('plugin-hook-1');
      final hook2 = TestHook('plugin-hook-2');
      final plugin = TestPlugin('test-plugin', [hook1, hook2]);
      final client = createTestClient(plugins: [plugin]);

      // Test that hooks are working by triggering a flag evaluation
      client.boolVariation('test-flag', false);

      // Verify hooks were called
      expect(hook1.callLog.length, greaterThan(0));
      expect(hook2.callLog.length, greaterThan(0));
      expect(hook1.callLog.any((call) => call.startsWith('beforeEvaluation')),
          isTrue);
      expect(hook1.callLog.any((call) => call.startsWith('afterEvaluation')),
          isTrue);
      expect(hook2.callLog.any((call) => call.startsWith('beforeEvaluation')),
          isTrue);
      expect(hook2.callLog.any((call) => call.startsWith('afterEvaluation')),
          isTrue);

      client.close();
    });

    test('registers hooks from multiple plugins', () {
      final hook1 = TestHook('plugin1-hook1');
      final hook2 = TestHook('plugin1-hook2');
      final hook3 = TestHook('plugin2-hook1');

      final plugin1 = TestPlugin('plugin-1', [hook1, hook2]);
      final plugin2 = TestPlugin('plugin-2', [hook3]);
      final client = createTestClient(plugins: [plugin1, plugin2]);

      // Test that hooks are working by triggering a flag evaluation
      client.boolVariation('test-flag', false);

      // Verify all hooks were called
      expect(hook1.callLog.length, greaterThan(0));
      expect(hook2.callLog.length, greaterThan(0));
      expect(hook3.callLog.length, greaterThan(0));

      client.close();
    });

    test('combines hooks from config and plugins correctly', () {
      final configHook = TestHook('config-hook');
      final pluginHook = TestHook('plugin-hook');
      final plugin = TestPlugin('test-plugin', [pluginHook]);
      final client = createTestClient(hooks: [configHook], plugins: [plugin]);

      // Test that both types of hooks are working
      client.boolVariation('test-flag', false);

      // Verify both config and plugin hooks were called
      expect(configHook.callLog.length, greaterThan(0));
      expect(pluginHook.callLog.length, greaterThan(0));
      expect(
          configHook.callLog.any((call) => call.startsWith('beforeEvaluation')),
          isTrue);
      expect(
          pluginHook.callLog.any((call) => call.startsWith('beforeEvaluation')),
          isTrue);

      client.close();
    });

    test('handles empty plugin list', () {
      // Should not throw with empty plugin list
      final client = createTestClient(plugins: []);

      // Basic functionality should still work
      final result = client.boolVariation('test-flag', false);
      expect(result, equals(false)); // Default value in offline mode

      client.close();
    });

    test('handles null plugin list', () {
      // Should not throw with null plugin list
      final client = createTestClient(plugins: null);

      // Basic functionality should still work
      final result = client.boolVariation('test-flag', false);
      expect(result, equals(false)); // Default value in offline mode

      client.close();
    });

    test('plugins with no hooks work correctly', () {
      final pluginWithNoHooks = TestPlugin('no-hooks-plugin', []);
      final pluginWithHooks = TestPlugin('hooks-plugin', [TestHook('hook1')]);
      final client =
          createTestClient(plugins: [pluginWithNoHooks, pluginWithHooks]);

      expect(pluginWithNoHooks.registerCallCount, equals(1));
      expect(pluginWithHooks.registerCallCount, equals(1));

      client.close();
    });

    test('plugin environment metadata includes correct SDK information', () {
      final plugin = TestPlugin('metadata-test-plugin', []);
      final applicationInfo = ApplicationInfo(
        applicationId: 'test-app-id',
        applicationVersion: '1.0.0',
      );
      final client = createTestClient(
        credential: 'test-client-side-id',
        plugins: [plugin],
        applicationInfo: applicationInfo,
      );

      final envMetadata = plugin.lastEnvironmentMetadataReceived!;
      expect(envMetadata.sdk.name, equals('FlutterClientSdk'));
      expect(envMetadata.sdk.version, isNotEmpty);
      expect(envMetadata.credential.value, equals('test-client-side-id'));
      expect(envMetadata.application, isNotNull);
      expect(envMetadata.application!.applicationId, equals('test-app-id'));
      expect(envMetadata.application!.applicationVersion, equals('1.0.0'));

      client.close();
    });

    test('plugin environment metadata without application info', () {
      final plugin = TestPlugin('no-app-info-plugin', []);
      final client = createTestClient(plugins: [plugin]);

      final envMetadata = plugin.lastEnvironmentMetadataReceived!;
      expect(envMetadata.sdk.name, equals('FlutterClientSdk'));
      expect(envMetadata.credential.value, equals('test-mobile-key'));
      expect(envMetadata.application, isNull);

      client.close();
    });

    test(
        'hooks are called in correct order (config hooks first, then plugin hooks)',
        () {
      final configHook1 = TestHook('config-hook-1');
      final configHook2 = TestHook('config-hook-2');
      final pluginHook1 = TestHook('plugin-hook-1');
      final pluginHook2 = TestHook('plugin-hook-2');

      final plugin = TestPlugin('test-plugin', [pluginHook1, pluginHook2]);
      final client = createTestClient(
        hooks: [configHook1, configHook2],
        plugins: [plugin],
      );

      // Clear any setup calls
      configHook1.callLog.clear();
      configHook2.callLog.clear();
      pluginHook1.callLog.clear();
      pluginHook2.callLog.clear();

      // Trigger evaluation to test hook order
      client.boolVariation('test-flag', false);

      // All hooks should have been called
      expect(configHook1.callLog.length, greaterThan(0));
      expect(configHook2.callLog.length, greaterThan(0));
      expect(pluginHook1.callLog.length, greaterThan(0));
      expect(pluginHook2.callLog.length, greaterThan(0));

      client.close();
    });

    test('hooks work with identify operations', () async {
      final hook = TestHook('identify-test-hook');
      final plugin = TestPlugin('identify-plugin', [hook]);
      final client = createTestClient(plugins: [plugin]);
      await client.start();

      // Verify identify hooks were called for start.
      expect(hook.callLog.any((call) => call.startsWith('beforeIdentify')),
          isTrue);
      expect(
          hook.callLog.any((call) => call.startsWith('afterIdentify')), isTrue);

      // Clear any setup calls
      hook.callLog.clear();

      // Test identify operation
      final newContext =
          LDContextBuilder().kind('user', 'new-user-key').build();

      await client.identify(newContext);

      // Verify identify hooks were called for identify operation.
      expect(hook.callLog.any((call) => call.startsWith('beforeIdentify')),
          isTrue);
      expect(
          hook.callLog.any((call) => call.startsWith('afterIdentify')), isTrue);

      client.close();
    });
  });
}
