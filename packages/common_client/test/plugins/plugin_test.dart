import 'package:launchdarkly_common_client/src/config/defaults/credential_type.dart';
import 'package:launchdarkly_common_client/src/plugins/plugin.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    show ApplicationInfo;
import 'package:test/test.dart';

void main() {
  group('PluginMetadata', () {
    test('toString returns correct format', () {
      final metadata = PluginMetadata(name: 'TestPlugin');
      expect(metadata.toString(), equals('PluginMetadata{name: TestPlugin}'));
    });

    test('toString handles special characters in name', () {
      final metadata =
          PluginMetadata(name: 'Test Plugin With Spaces & Special!');
      expect(metadata.toString(),
          equals('PluginMetadata{name: Test Plugin With Spaces & Special!}'));
    });
  });

  group('PluginSdkMetadata', () {
    test('toString returns correct format with all fields', () {
      final metadata = PluginSdkMetadata(
        name: 'Flutter SDK',
        version: '1.0.0',
        wrapperName: 'React Native',
        wrapperVersion: '2.0.0',
      );

      final result = metadata.toString();
      expect(result, contains('PluginSdkMetadata{'));
      expect(result, contains('name: Flutter SDK'));
      expect(result, contains('version: 1.0.0'));
      expect(result, contains('wrapperName: React Native'));
      expect(result, contains('wrapperVersion: 2.0.0'));
    });

    test('toString handles null wrapper fields', () {
      final metadata = PluginSdkMetadata(
        name: 'Dart SDK',
        version: '2.0.0',
        wrapperName: null,
        wrapperVersion: null,
      );

      final result = metadata.toString();
      expect(result, contains('name: Dart SDK'));
      expect(result, contains('version: 2.0.0'));
      expect(result, contains('wrapperName: null'));
      expect(result, contains('wrapperVersion: null'));
    });
  });

  group('PluginCredentialInfo', () {
    test('toString returns correct format with mobile key', () {
      final credentialInfo = PluginCredentialInfo(
        type: CredentialType.mobileKey,
        value: 'mob-12345-abcdef',
      );

      expect(
          credentialInfo.toString(),
          equals(
              'PluginCredentialInfo{type: CredentialType.mobileKey, value: mob-12345-abcdef}'));
    });

    test('toString returns correct format with client side ID', () {
      final credentialInfo = PluginCredentialInfo(
        type: CredentialType.clientSideId,
        value: '12345abcdef',
      );

      expect(
          credentialInfo.toString(),
          equals(
              'PluginCredentialInfo{type: CredentialType.clientSideId, value: 12345abcdef}'));
    });
  });

  group('PluginEnvironmentMetadata', () {
    test('toString returns correct format with all fields', () {
      final sdkMetadata = PluginSdkMetadata(
        name: 'Test SDK',
        version: '1.0.0',
      );

      final credentialInfo = PluginCredentialInfo(
        type: CredentialType.mobileKey,
        value: 'test-key',
      );

      final applicationInfo = ApplicationInfo(
        applicationId: 'com.example.app',
        applicationName: 'Test App',
        applicationVersion: '1.2.3',
        applicationVersionName: 'v1.2.3',
      );

      final environmentMetadata = PluginEnvironmentMetadata(
        sdk: sdkMetadata,
        credential: credentialInfo,
        application: applicationInfo,
      );

      final result = environmentMetadata.toString();
      expect(result, contains('PluginEnvironmentMetadata{'));
      expect(result, contains('sdk: $sdkMetadata'));
      expect(result, contains('credential: $credentialInfo'));
      expect(result, contains('application: $applicationInfo'));
    });

    test('toString handles null application', () {
      final sdkMetadata = PluginSdkMetadata(
        name: 'Test SDK',
        version: '1.0.0',
      );

      final credentialInfo = PluginCredentialInfo(
        type: CredentialType.clientSideId,
        value: 'test-id',
      );

      final environmentMetadata = PluginEnvironmentMetadata(
        sdk: sdkMetadata,
        credential: credentialInfo,
        application: null,
      );

      final result = environmentMetadata.toString();
      expect(result, contains('application: null'));
    });
  });
}
