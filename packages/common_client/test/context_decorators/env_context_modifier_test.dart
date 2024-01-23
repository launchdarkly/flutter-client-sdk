import 'package:launchdarkly_common_client/src/context_modifiers/env_context_modifier.dart';
import 'package:launchdarkly_common_client/src/persistence/persistence.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

void main() {
  group('env reporter with various configurations', () {
    test('reporter has all attributes', () async {
      final mockPersistence = InMemoryPersistence();
      final logger = LDLogger();
      final envReporter = ConcreteEnvReporter(
          applicationInfo: Future.value(ApplicationInfo(
              applicationId: 'mockID',
              applicationName: 'mockName',
              applicationVersion: 'mockVersion',
              applicationVersionName: 'mockVersionName')),
          osInfo: Future.value(OsInfo(
              family: 'mockFamily',
              name: 'mockOsName',
              version: 'mockOsVersion')),
          deviceInfo: Future.value(
              DeviceInfo(model: 'mockModel', manufacturer: 'mockManufacturer')),
          locale: Future.value('mockLocale'));

      final context =
          LDContextBuilder().kind('user').name('Bob').anonymous(true).build();
      final decorator =
          AutoEnvContextModifier(envReporter, mockPersistence, logger);
      final decoratedContext = await decorator.decorate(context);

      expect(
          decoratedContext
              .get('user', AttributeReference('name'))
              .stringValue(),
          'Bob');
      expect(
          decoratedContext
              .get('user', AttributeReference('anonymous'))
              .booleanValue(),
          true);

      expect(
          decoratedContext
              .get('ld_application', AttributeReference('id'))
              .stringValue(),
          'mockID');
      expect(
          decoratedContext
              .get('ld_application', AttributeReference('name'))
              .stringValue(),
          'mockName');
      expect(
          decoratedContext
              .get('ld_application', AttributeReference('version'))
              .stringValue(),
          'mockVersion');
      expect(
          decoratedContext
              .get('ld_application', AttributeReference('versionName'))
              .stringValue(),
          'mockVersionName');
      expect(
          decoratedContext
              .get('ld_application', AttributeReference('locale'))
              .stringValue(),
          'mockLocale');
      expect(
          decoratedContext
              .get('ld_application', AttributeReference('envAttributesVersion'))
              .stringValue(),
          AutoEnvConsts.specVersion);

      expect(
          decoratedContext
              .get('ld_device', AttributeReference('/model'))
              .stringValue(),
          'mockModel');
      expect(
          decoratedContext
              .get('ld_device', AttributeReference('/manufacturer'))
              .stringValue(),
          'mockManufacturer');
      expect(
          decoratedContext
              .get('ld_device', AttributeReference('/os/family'))
              .stringValue(),
          'mockFamily');
      expect(
          decoratedContext
              .get('ld_device', AttributeReference('/os/name'))
              .stringValue(),
          'mockOsName');
      expect(
          decoratedContext
              .get('ld_device', AttributeReference('/os/version'))
              .stringValue(),
          'mockOsVersion');
      expect(
          decoratedContext
              .get('ld_device', AttributeReference('envAttributesVersion'))
              .stringValue(),
          AutoEnvConsts.specVersion);
    });

    test('reporter has no device attributes', () async {
      final mockPersistence = InMemoryPersistence();
      final logger = LDLogger();
      final envReporter = ConcreteEnvReporter(
          applicationInfo: Future.value(ApplicationInfo(
              applicationId: 'mockID',
              applicationName: 'mockName',
              applicationVersion: 'mockVersion',
              applicationVersionName: 'mockVersionName')),
          osInfo: Future.value(null),
          deviceInfo: Future.value(null),
          locale: Future.value('locale'));

      final context =
          LDContextBuilder().kind('user').name('Bob').anonymous(true).build();
      final decorator =
          AutoEnvContextModifier(envReporter, mockPersistence, logger);
      final decoratedContext = await decorator.decorate(context);

      expect(
          decoratedContext
              .get('user', AttributeReference('name'))
              .stringValue(),
          'Bob');
      expect(
          decoratedContext
              .get('user', AttributeReference('anonymous'))
              .booleanValue(),
          true);

      expect(
          decoratedContext
              .get('ld_application', AttributeReference('id'))
              .stringValue(),
          'mockID');
      expect(
          decoratedContext
              .get('ld_application', AttributeReference('name'))
              .stringValue(),
          'mockName');
      expect(
          decoratedContext
              .get('ld_application', AttributeReference('version'))
              .stringValue(),
          'mockVersion');
      expect(
          decoratedContext
              .get('ld_application', AttributeReference('versionName'))
              .stringValue(),
          'mockVersionName');
      expect(
          decoratedContext
              .get('ld_application', AttributeReference('envAttributesVersion'))
              .stringValue(),
          AutoEnvConsts.specVersion);

      expect(decoratedContext.keys.keys.contains('ld_device'), false);
      expect(decoratedContext.get('ld_device', AttributeReference('/model')),
          LDValue.ofNull());
      expect(
          decoratedContext.get(
              'ld_device', AttributeReference('/manufacturer')),
          LDValue.ofNull());
      expect(
          decoratedContext.get('ld_device', AttributeReference('/os/family')),
          LDValue.ofNull());
      expect(decoratedContext.get('ld_device', AttributeReference('/os/name')),
          LDValue.ofNull());
      expect(
          decoratedContext.get('ld_device', AttributeReference('/os/version')),
          LDValue.ofNull());
      expect(
          decoratedContext.get(
              'ld_device', AttributeReference('envAttributesVersion')),
          LDValue.ofNull());
    });

    test('reporter has no device model info but does have os info', () async {
      final mockPersistence = InMemoryPersistence();
      final logger = LDLogger();
      final envReporter = ConcreteEnvReporter(
          applicationInfo: Future.value(ApplicationInfo(
              applicationId: 'mockID',
              applicationName: 'mockName',
              applicationVersion: 'mockVersion',
              applicationVersionName: 'mockVersionName')),
          osInfo: Future.value(OsInfo(
              family: 'mockFamily',
              name: 'mockOsName',
              version: 'mockOsVersion')),
          deviceInfo: Future.value(null),
          locale: Future.value('locale'));

      final context =
          LDContextBuilder().kind('user').name('Bob').anonymous(true).build();
      final decorator =
          AutoEnvContextModifier(envReporter, mockPersistence, logger);
      final decoratedContext = await decorator.decorate(context);

      expect(
          decoratedContext
              .get('user', AttributeReference('name'))
              .stringValue(),
          'Bob');
      expect(
          decoratedContext
              .get('user', AttributeReference('anonymous'))
              .booleanValue(),
          true);

      expect(
          decoratedContext
              .get('ld_application', AttributeReference('id'))
              .stringValue(),
          'mockID');
      expect(
          decoratedContext
              .get('ld_application', AttributeReference('name'))
              .stringValue(),
          'mockName');
      expect(
          decoratedContext
              .get('ld_application', AttributeReference('version'))
              .stringValue(),
          'mockVersion');
      expect(
          decoratedContext
              .get('ld_application', AttributeReference('versionName'))
              .stringValue(),
          'mockVersionName');
      expect(
          decoratedContext
              .get('ld_application', AttributeReference('envAttributesVersion'))
              .stringValue(),
          AutoEnvConsts.specVersion);

      expect(decoratedContext.get('ld_device', AttributeReference('/model')),
          LDValue.ofNull());
      expect(
          decoratedContext.get(
              'ld_device', AttributeReference('/manufacturer')),
          LDValue.ofNull());
      expect(
          decoratedContext
              .get('ld_device', AttributeReference('/os/family'))
              .stringValue(),
          'mockFamily');
      expect(
          decoratedContext
              .get('ld_device', AttributeReference('/os/name'))
              .stringValue(),
          'mockOsName');
      expect(
          decoratedContext
              .get('ld_device', AttributeReference('/os/version'))
              .stringValue(),
          'mockOsVersion');
      expect(
          decoratedContext
              .get('ld_device', AttributeReference('envAttributesVersion'))
              .stringValue(),
          AutoEnvConsts.specVersion);
    });

    test('reporter has no attributes', () async {
      final mockPersistence = InMemoryPersistence();
      final logger = LDLogger();
      final envReporter = ConcreteEnvReporter.ofNulls();

      final context =
          LDContextBuilder().kind('user').name('Bob').anonymous(true).build();
      final decorator =
          AutoEnvContextModifier(envReporter, mockPersistence, logger);
      final decoratedContext = await decorator.decorate(context);

      expect(
          decoratedContext
              .get('user', AttributeReference('name'))
              .stringValue(),
          'Bob');
      expect(
          decoratedContext
              .get('user', AttributeReference('anonymous'))
              .booleanValue(),
          true);

      expect(decoratedContext.keys.keys.contains('ld_device'), false);
      expect(decoratedContext.keys.keys.contains('ld_application'), false);
    });
  });

  group('input context with various configurations', () {
    test('context has ld_application kind', () async {
      final mockPersistence = InMemoryPersistence();
      final logger = LDLogger();
      final envReporter = ConcreteEnvReporter(
          applicationInfo: Future.value(ApplicationInfo(
              applicationId: 'mockID',
              applicationName: 'mockName',
              applicationVersion: 'mockVersion',
              applicationVersionName: 'mockVersionName')),
          osInfo: Future.value(OsInfo(
              family: 'mockFamily',
              name: 'mockOsName',
              version: 'mockOsVersion')),
          deviceInfo: Future.value(
              DeviceInfo(model: 'mockModel', manufacturer: 'mockManufacturer')),
          locale: Future.value('mockLocale'));

      final contextBuilder = LDContextBuilder();
      contextBuilder.kind('user').name('Bob').anonymous(true);
      contextBuilder
          .kind('ld_application', 'fakeKey')
          .set('myCoolAttribute', LDValue.ofString('myCoolValue'));
      final context = contextBuilder.build();
      final decorator =
          AutoEnvContextModifier(envReporter, mockPersistence, logger);
      final decoratedContext = await decorator.decorate(context);

      expect(
          decoratedContext
              .get('user', AttributeReference('name'))
              .stringValue(),
          'Bob');
      expect(
          decoratedContext
              .get('user', AttributeReference('anonymous'))
              .booleanValue(),
          true);

      // ld_application already exists and should not be overwritten
      expect(
          decoratedContext
              .get('ld_application', AttributeReference('myCoolAttribute'))
              .stringValue(),
          'myCoolValue');
      expect(decoratedContext.get('ld_application', AttributeReference('id')),
          LDValue.ofNull());
      expect(decoratedContext.get('ld_application', AttributeReference('name')),
          LDValue.ofNull());
      expect(
          decoratedContext.get('ld_application', AttributeReference('version')),
          LDValue.ofNull());
      expect(
          decoratedContext.get(
              'ld_application', AttributeReference('versionName')),
          LDValue.ofNull());
      expect(
          decoratedContext.get('ld_application', AttributeReference('locale')),
          LDValue.ofNull());
      expect(
          decoratedContext.get(
              'ld_application', AttributeReference('envAttributesVersion')),
          LDValue.ofNull());

      // ld_device should be added because it doesn't already exist
      expect(
          decoratedContext
              .get('ld_device', AttributeReference('/model'))
              .stringValue(),
          'mockModel');
      expect(
          decoratedContext
              .get('ld_device', AttributeReference('/manufacturer'))
              .stringValue(),
          'mockManufacturer');
      expect(
          decoratedContext
              .get('ld_device', AttributeReference('/os/family'))
              .stringValue(),
          'mockFamily');
      expect(
          decoratedContext
              .get('ld_device', AttributeReference('/os/name'))
              .stringValue(),
          'mockOsName');
      expect(
          decoratedContext
              .get('ld_device', AttributeReference('/os/version'))
              .stringValue(),
          'mockOsVersion');
      expect(
          decoratedContext
              .get('ld_device', AttributeReference('envAttributesVersion'))
              .stringValue(),
          AutoEnvConsts.specVersion);
    });
  });

  group('persistence', () {
    test('back to back calls use same keys', () async {
      final mockPersistence = InMemoryPersistence();
      final logger = LDLogger();
      final envReporter = ConcreteEnvReporter(
          applicationInfo: Future.value(ApplicationInfo(
              applicationId: 'mockID',
              applicationName: 'mockName',
              applicationVersion: 'mockVersion',
              applicationVersionName: 'mockVersionName')),
          osInfo: Future.value(OsInfo(
              family: 'mockFamily',
              name: 'mockOsName',
              version: 'mockOsVersion')),
          deviceInfo: Future.value(
              DeviceInfo(model: 'mockModel', manufacturer: 'mockManufacturer')),
          locale: Future.value('mockLocale'));

      final contextBuilder = LDContextBuilder();
      contextBuilder.kind('user').name('Bob').anonymous(true);
      final context = contextBuilder.build();
      final decorator1 =
          AutoEnvContextModifier(envReporter, mockPersistence, logger);
      final decoratedContext1 = await decorator1.decorate(context);

      final decorator2 =
          AutoEnvContextModifier(envReporter, mockPersistence, logger);
      final decoratedContext2 = await decorator2.decorate(context);

      final key1 = decoratedContext1
          .get('ld_application', AttributeReference('key'))
          .stringValue();
      final key2 = decoratedContext2
          .get('ld_application', AttributeReference('key'))
          .stringValue();
      expect(key1, isNot(null));
      expect(key1, key2);
    });
  });
}
