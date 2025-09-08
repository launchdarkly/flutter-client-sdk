import 'package:launchdarkly_common_client/src/plugins/operations.dart';
import 'package:launchdarkly_common_client/src/plugins/plugin.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import 'package:launchdarkly_common_client/src/hooks/hook.dart';
import 'package:launchdarkly_common_client/src/config/defaults/credential_type.dart';

class MockLogAdapter extends Mock implements LDLogAdapter {}

final class TestHook extends Hook {
  final String hookName;
  final HookMetadata _metadata;

  TestHook(this.hookName) : _metadata = HookMetadata(name: hookName);

  @override
  HookMetadata get metadata => _metadata;
}

final class TestPlugin extends PluginBase<dynamic> {
  final String pluginName;
  final List<Hook> _hooks;
  final bool shouldThrowOnGetHooks;
  final bool shouldThrowOnRegister;
  final PluginMetadata _metadata;
  int registerCallCount = 0;
  dynamic lastClientReceived;
  PluginEnvironmentMetadata? lastEnvironmentMetadataReceived;

  TestPlugin(this.pluginName, this._hooks,
      {this.shouldThrowOnGetHooks = false, this.shouldThrowOnRegister = false})
      : _metadata = PluginMetadata(name: pluginName);

  @override
  PluginMetadata get metadata => _metadata;

  @override
  List<Hook> get hooks {
    if (shouldThrowOnGetHooks) {
      throw Exception('Test exception from plugin $pluginName');
    }
    return _hooks;
  }

  @override
  void register(dynamic client, PluginEnvironmentMetadata environmentMetadata) {
    registerCallCount++;
    lastClientReceived = client;
    lastEnvironmentMetadataReceived = environmentMetadata;

    if (shouldThrowOnRegister) {
      throw Exception(
          'Test exception during registration for plugin $pluginName');
    }
  }
}

void main() {
  late MockLogAdapter mockLogAdapter;
  late LDLogger logger;

  setUpAll(() {
    registerFallbackValue(LDLogRecord(
        level: LDLogLevel.debug,
        message: '',
        time: DateTime.now(),
        logTag: ''));
  });

  setUp(() {
    mockLogAdapter = MockLogAdapter();
    logger = LDLogger(adapter: mockLogAdapter);
  });

  group('safeGetHooks', () {
    test('returns null when plugins list is null', () {
      final result = safeGetHooks(null, logger);
      expect(result, isNull);
    });

    test('returns empty list when plugins list is empty', () {
      final result = safeGetHooks([], logger);
      expect(result, isEmpty);
    });

    test('returns hooks from single plugin with one hook', () {
      final hook = TestHook('test-hook');
      final plugin = TestPlugin('test-plugin', [hook]);

      final result = safeGetHooks([plugin], logger);

      expect(result, isNotNull);
      expect(result!.length, equals(1));
      expect(result.first, same(hook));
    });

    test('returns hooks from single plugin with multiple hooks', () {
      final hook1 = TestHook('test-hook-1');
      final hook2 = TestHook('test-hook-2');
      final hook3 = TestHook('test-hook-3');
      final plugin = TestPlugin('test-plugin', [hook1, hook2, hook3]);

      final result = safeGetHooks([plugin], logger);

      expect(result, isNotNull);
      expect(result!.length, equals(3));
      expect(result, containsAll([hook1, hook2, hook3]));
    });

    test('returns hooks from multiple plugins', () {
      final hook1 = TestHook('hook-1');
      final hook2 = TestHook('hook-2');
      final hook3 = TestHook('hook-3');

      final plugin1 = TestPlugin('plugin-1', [hook1]);
      final plugin2 = TestPlugin('plugin-2', [hook2, hook3]);

      final result = safeGetHooks([plugin1, plugin2], logger);

      expect(result, isNotNull);
      expect(result!.length, equals(3));
      expect(result, containsAll([hook1, hook2, hook3]));
    });

    test('handles plugin with no hooks', () {
      final plugin1 = TestPlugin('plugin-1', []);
      final hook2 = TestHook('hook-2');
      final plugin2 = TestPlugin('plugin-2', [hook2]);

      final result = safeGetHooks([plugin1, plugin2], logger);

      expect(result, isNotNull);
      expect(result!.length, equals(1));
      expect(result.first, same(hook2));
    });

    test('handles exception from plugin hooks getter and logs warning', () {
      final hook1 = TestHook('hook-1');
      final plugin1 = TestPlugin('plugin-1', [hook1]);
      final plugin2 = TestPlugin('plugin-2', [], shouldThrowOnGetHooks: true);
      final hook3 = TestHook('hook-3');
      final plugin3 = TestPlugin('plugin-3', [hook3]);

      final result = safeGetHooks([plugin1, plugin2, plugin3], logger);

      expect(result, isNotNull);
      expect(result!.length, equals(2));
      expect(result, containsAll([hook1, hook3]));

      // Verify warning was logged
      verify(() => mockLogAdapter.log(any(
              that: predicate<LDLogRecord>((record) =>
                  record.level == LDLogLevel.warn &&
                  record.message.contains(
                      'Exception thrown getting hooks for plugin plugin-2') &&
                  record.message.contains('Unable to get hooks for plugin')))))
          .called(1);
    });

    test('handles multiple plugins throwing exceptions', () {
      final hook1 = TestHook('hook-1');
      final plugin1 = TestPlugin('plugin-1', [hook1]);
      final plugin2 = TestPlugin('plugin-2', [], shouldThrowOnGetHooks: true);
      final plugin3 = TestPlugin('plugin-3', [], shouldThrowOnGetHooks: true);

      final result = safeGetHooks([plugin1, plugin2, plugin3], logger);

      expect(result, isNotNull);
      expect(result!.length, equals(1));
      expect(result.first, same(hook1));

      // Verify warnings were logged for both failing plugins
      verify(() => mockLogAdapter.log(any(
              that: predicate<LDLogRecord>((record) =>
                  record.level == LDLogLevel.warn &&
                  record.message.contains(
                      'Exception thrown getting hooks for plugin plugin-2')))))
          .called(1);
      verify(() => mockLogAdapter.log(any(
              that: predicate<LDLogRecord>((record) =>
                  record.level == LDLogLevel.warn &&
                  record.message.contains(
                      'Exception thrown getting hooks for plugin plugin-3')))))
          .called(1);
    });

    test('returns empty list when all plugins throw exceptions', () {
      final plugin1 = TestPlugin('plugin-1', [], shouldThrowOnGetHooks: true);
      final plugin2 = TestPlugin('plugin-2', [], shouldThrowOnGetHooks: true);

      final result = safeGetHooks([plugin1, plugin2], logger);

      expect(result, isNotNull);
      expect(result!, isEmpty);

      // Verify warnings were logged for both failing plugins
      verify(() => mockLogAdapter.log(any(
          that: predicate<LDLogRecord>((record) =>
              record.level == LDLogLevel.warn &&
              record.message.contains('plugin-1'))))).called(1);
      verify(() => mockLogAdapter.log(any(
          that: predicate<LDLogRecord>((record) =>
              record.level == LDLogLevel.warn &&
              record.message.contains('plugin-2'))))).called(1);
    });

    test('preserves order of hooks from plugins', () {
      final hook1 = TestHook('hook-1');
      final hook2 = TestHook('hook-2');
      final hook3 = TestHook('hook-3');
      final hook4 = TestHook('hook-4');

      final plugin1 = TestPlugin('plugin-1', [hook1, hook2]);
      final plugin2 = TestPlugin('plugin-2', [hook3, hook4]);

      final result = safeGetHooks([plugin1, plugin2], logger);

      expect(result, isNotNull);
      expect(result!.length, equals(4));
      expect(result[0], same(hook1));
      expect(result[1], same(hook2));
      expect(result[2], same(hook3));
      expect(result[3], same(hook4));
    });

    test('handles mixed scenario with empty hooks, valid hooks, and exceptions',
        () {
      final hook1 = TestHook('hook-1');
      final hook2 = TestHook('hook-2');

      final plugin1 = TestPlugin('plugin-1', []); // No hooks
      final plugin2 = TestPlugin('plugin-2', [hook1]); // One hook
      final plugin3 =
          TestPlugin('plugin-3', [], shouldThrowOnGetHooks: true); // Exception
      final plugin4 = TestPlugin('plugin-4', [hook2]); // One hook

      final result = safeGetHooks([plugin1, plugin2, plugin3, plugin4], logger);

      expect(result, isNotNull);
      expect(result!.length, equals(2));
      expect(result, containsAll([hook1, hook2]));

      // Verify warning was logged for the failing plugin
      verify(() => mockLogAdapter.log(any(
          that: predicate<LDLogRecord>((record) =>
              record.level == LDLogLevel.warn &&
              record.message.contains('plugin-3'))))).called(1);
    });
  });

  group('safeRegisterPlugins', () {
    late PluginEnvironmentMetadata testEnvironmentMetadata;
    late dynamic testClient;

    setUp(() {
      testClient = 'test-client';
      testEnvironmentMetadata = PluginEnvironmentMetadata(
        sdk: PluginSdkMetadata(
          name: 'test-sdk',
          version: '1.0.0',
        ),
        credential: PluginCredentialInfo(
          type: CredentialType.clientSideId,
          value: 'test-credential',
        ),
      );
    });

    test('does nothing when plugins list is null', () {
      safeRegisterPlugins(testClient, testEnvironmentMetadata, null, logger);
      // No exceptions should be thrown, function should complete silently
    });

    test('does nothing when plugins list is empty', () {
      safeRegisterPlugins(testClient, testEnvironmentMetadata, [], logger);
      // No exceptions should be thrown, function should complete silently
    });

    test('registers single plugin successfully', () {
      final plugin = TestPlugin('test-plugin', []);

      safeRegisterPlugins(
          testClient, testEnvironmentMetadata, [plugin], logger);

      expect(plugin.registerCallCount, equals(1));
      expect(plugin.lastClientReceived, same(testClient));
      expect(plugin.lastEnvironmentMetadataReceived,
          same(testEnvironmentMetadata));
    });

    test('registers multiple plugins successfully', () {
      final plugin1 = TestPlugin('plugin-1', []);
      final plugin2 = TestPlugin('plugin-2', []);
      final plugin3 = TestPlugin('plugin-3', []);

      safeRegisterPlugins(testClient, testEnvironmentMetadata,
          [plugin1, plugin2, plugin3], logger);

      expect(plugin1.registerCallCount, equals(1));
      expect(plugin1.lastClientReceived, same(testClient));
      expect(plugin1.lastEnvironmentMetadataReceived,
          same(testEnvironmentMetadata));

      expect(plugin2.registerCallCount, equals(1));
      expect(plugin2.lastClientReceived, same(testClient));
      expect(plugin2.lastEnvironmentMetadataReceived,
          same(testEnvironmentMetadata));

      expect(plugin3.registerCallCount, equals(1));
      expect(plugin3.lastClientReceived, same(testClient));
      expect(plugin3.lastEnvironmentMetadataReceived,
          same(testEnvironmentMetadata));
    });

    test('handles exception from single plugin registration and logs warning',
        () {
      final plugin1 = TestPlugin('plugin-1', []);
      final plugin2 = TestPlugin('plugin-2', [], shouldThrowOnRegister: true);
      final plugin3 = TestPlugin('plugin-3', []);

      safeRegisterPlugins(testClient, testEnvironmentMetadata,
          [plugin1, plugin2, plugin3], logger);

      // First and third plugins should be registered successfully
      expect(plugin1.registerCallCount, equals(1));
      expect(plugin3.registerCallCount, equals(1));

      // Second plugin should have attempted registration but failed
      expect(plugin2.registerCallCount, equals(1));

      // Verify warning was logged
      verify(() => mockLogAdapter.log(any(
              that: predicate<LDLogRecord>((record) =>
                  record.level == LDLogLevel.warn &&
                  record.message.contains(
                      'Exception thrown when registering plugin plugin-2')))))
          .called(1);
    });

    test('handles multiple plugins throwing exceptions', () {
      final plugin1 = TestPlugin('plugin-1', []);
      final plugin2 = TestPlugin('plugin-2', [], shouldThrowOnRegister: true);
      final plugin3 = TestPlugin('plugin-3', [], shouldThrowOnRegister: true);
      final plugin4 = TestPlugin('plugin-4', []);

      safeRegisterPlugins(testClient, testEnvironmentMetadata,
          [plugin1, plugin2, plugin3, plugin4], logger);

      // First and fourth plugins should be registered successfully
      expect(plugin1.registerCallCount, equals(1));
      expect(plugin4.registerCallCount, equals(1));

      // Second and third plugins should have attempted registration but failed
      expect(plugin2.registerCallCount, equals(1));
      expect(plugin3.registerCallCount, equals(1));

      // Verify warnings were logged for both failing plugins
      verify(() => mockLogAdapter.log(any(
              that: predicate<LDLogRecord>((record) =>
                  record.level == LDLogLevel.warn &&
                  record.message.contains(
                      'Exception thrown when registering plugin plugin-2')))))
          .called(1);
      verify(() => mockLogAdapter.log(any(
              that: predicate<LDLogRecord>((record) =>
                  record.level == LDLogLevel.warn &&
                  record.message.contains(
                      'Exception thrown when registering plugin plugin-3')))))
          .called(1);
    });

    test('handles all plugins throwing exceptions', () {
      final plugin1 = TestPlugin('plugin-1', [], shouldThrowOnRegister: true);
      final plugin2 = TestPlugin('plugin-2', [], shouldThrowOnRegister: true);

      safeRegisterPlugins(
          testClient, testEnvironmentMetadata, [plugin1, plugin2], logger);

      // All plugins should have attempted registration but failed
      expect(plugin1.registerCallCount, equals(1));
      expect(plugin2.registerCallCount, equals(1));

      // Verify warnings were logged for all failing plugins
      verify(() => mockLogAdapter.log(any(
          that: predicate<LDLogRecord>((record) =>
              record.level == LDLogLevel.warn &&
              record.message.contains('plugin-1'))))).called(1);
      verify(() => mockLogAdapter.log(any(
          that: predicate<LDLogRecord>((record) =>
              record.level == LDLogLevel.warn &&
              record.message.contains('plugin-2'))))).called(1);
    });

    test('continues registering remaining plugins after exception', () {
      final plugin1 = TestPlugin('plugin-1', []);
      final plugin2 = TestPlugin('plugin-2', [], shouldThrowOnRegister: true);
      final plugin3 = TestPlugin('plugin-3', []);
      final plugin4 = TestPlugin('plugin-4', [], shouldThrowOnRegister: true);
      final plugin5 = TestPlugin('plugin-5', []);

      safeRegisterPlugins(testClient, testEnvironmentMetadata,
          [plugin1, plugin2, plugin3, plugin4, plugin5], logger);

      // Successful plugins should be registered
      expect(plugin1.registerCallCount, equals(1));
      expect(plugin3.registerCallCount, equals(1));
      expect(plugin5.registerCallCount, equals(1));

      // Failed plugins should have attempted registration
      expect(plugin2.registerCallCount, equals(1));
      expect(plugin4.registerCallCount, equals(1));

      // Verify warnings were logged for failing plugins
      verify(() => mockLogAdapter.log(any(
          that: predicate<LDLogRecord>((record) =>
              record.level == LDLogLevel.warn &&
              record.message.contains('plugin-2'))))).called(1);
      verify(() => mockLogAdapter.log(any(
          that: predicate<LDLogRecord>((record) =>
              record.level == LDLogLevel.warn &&
              record.message.contains('plugin-4'))))).called(1);
    });

    test('passes correct client and environment metadata to each plugin', () {
      final plugin1 = TestPlugin('plugin-1', []);
      final plugin2 = TestPlugin('plugin-2', []);

      final customClient = 'custom-client';
      final customEnvironmentMetadata = PluginEnvironmentMetadata(
        sdk: PluginSdkMetadata(
          name: 'custom-sdk',
          version: '2.0.0',
        ),
        credential: PluginCredentialInfo(
          type: CredentialType.mobileKey,
          value: 'custom-credential',
        ),
      );

      safeRegisterPlugins(
          customClient, customEnvironmentMetadata, [plugin1, plugin2], logger);

      expect(plugin1.registerCallCount, equals(1));
      expect(plugin1.lastClientReceived, same(customClient));
      expect(plugin1.lastEnvironmentMetadataReceived,
          same(customEnvironmentMetadata));

      expect(plugin2.registerCallCount, equals(1));
      expect(plugin2.lastClientReceived, same(customClient));
      expect(plugin2.lastEnvironmentMetadataReceived,
          same(customEnvironmentMetadata));
    });
  });
}
