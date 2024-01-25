import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';

void main() {
  test('no layers leads to nulls', () async {
    final envUnderTest = await PrioritizedEnvReportBuilder().build();
    expect((envUnderTest.applicationInfo), null);
    expect((envUnderTest.deviceInfo), null);
    expect((envUnderTest.osInfo), null);
  });

  test('config layer supersedes platform layer', () async {
    final configLayer = ConcreteEnvReporter(
        applicationInfo: Future.value(ApplicationInfo(
            applicationId: 'configID',
            applicationName: 'configName',
            applicationVersion: 'configVersion',
            applicationVersionName: 'configVersionName')),
        osInfo: Future.value(OsInfo(
            family: 'configFamily',
            name: 'configOsName',
            version: 'configOsVersion')),
        deviceInfo: Future.value(DeviceInfo(
            model: 'configModel', manufacturer: 'configManufacturer')),
        locale: Future.value('configLocale'));

    final platformLayer = ConcreteEnvReporter(
        applicationInfo: Future.value(ApplicationInfo(
            applicationId: 'platformID',
            applicationName: 'platformName',
            applicationVersion: 'platformVersion',
            applicationVersionName: 'platformVersionName')),
        osInfo: Future.value(OsInfo(
            family: 'platformFamily',
            name: 'platformOsName',
            version: 'platformOsVersion')),
        deviceInfo: Future.value(DeviceInfo(
            model: 'platformModel', manufacturer: 'platformManufacturer')),
        locale: Future.value('platformLocale'));

    final envUnderTest = await PrioritizedEnvReportBuilder()
        .setConfigLayer(configLayer)
        .setPlatformLayer(platformLayer)
        .build();

    expect(envUnderTest.applicationInfo!.applicationId, 'configID');
    expect(envUnderTest.applicationInfo!.applicationVersion, 'configVersion');
    expect(envUnderTest.deviceInfo!.model, 'configModel');
    expect(envUnderTest.deviceInfo!.manufacturer, 'configManufacturer');
    expect(envUnderTest.osInfo!.name, 'configOsName');
    expect(envUnderTest.osInfo!.family, 'configFamily');
  });

  test('missing device info in config falls through to platform', () async {
    final configLayer = ConcreteEnvReporter(
        applicationInfo: Future.value(ApplicationInfo(
            applicationId: 'configID',
            applicationName: 'configName',
            applicationVersion: 'configVersion',
            applicationVersionName: 'configVersionName')),
        osInfo: Future.value(OsInfo(
            family: 'configFamily',
            name: 'configOsName',
            version: 'configOsVersion')),
        deviceInfo: Future.value(null), // intentionally missing for this test
        locale: Future.value('configLocale'));

    final platformLayer = ConcreteEnvReporter(
        applicationInfo: Future.value(ApplicationInfo(
            applicationId: 'platformID',
            applicationName: 'platformName',
            applicationVersion: 'platformVersion',
            applicationVersionName: 'platformVersionName')),
        osInfo: Future.value(OsInfo(
            family: 'platformFamily',
            name: 'platformOsName',
            version: 'platformOsVersion')),
        deviceInfo: Future.value(DeviceInfo(
            model: 'platformModel', manufacturer: 'platformManufacturer')),
        locale: Future.value('platformLocale'));

    final envUnderTest = await PrioritizedEnvReportBuilder()
        .setConfigLayer(configLayer)
        .setPlatformLayer(platformLayer)
        .build();

    expect(envUnderTest.applicationInfo!.applicationId, 'configID');
    expect(envUnderTest.applicationInfo!.applicationVersion, 'configVersion');
    expect(envUnderTest.deviceInfo!.model, 'platformModel');
    expect(envUnderTest.deviceInfo!.manufacturer, 'platformManufacturer');
    expect(envUnderTest.osInfo!.name, 'configOsName');
    expect(envUnderTest.osInfo!.family, 'configFamily');
  });
}
