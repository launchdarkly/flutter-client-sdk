import 'package:launchdarkly_dart_common/ld_common.dart';
import 'package:test/test.dart';

void main() {
  test('no layers leads to nulls', () async {
    final envUnderTest = await PrioritizedEnvReporterBuilder().build();
    expect((await envUnderTest.applicationInfo), null);
    expect((await envUnderTest.deviceInfo), null);
    expect((await envUnderTest.osInfo), null);
  });

  test('config layer supersedes platform layer', () async {
    final configLayer = ConcreteEnvReporter(
        applicationInfo: Future.value(ApplicationInfo(
            applicationId: 'configID',
            applicationName: 'configName',
            applicationVersion: 'configVersion',
            applicationVersionName: 'configVersionName')),
        osInfo: Future.value(OsInfo(
            family: 'configFamily', name: 'configOsName', version: 'configOsVersion')),
        deviceInfo: Future.value(
            DeviceInfo(model: 'configModel', manufacturer: 'configManufacturer')),
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

    final envUnderTest = await PrioritizedEnvReporterBuilder()
        .setConfigLayer(configLayer)
        .setPlatformLayer(platformLayer)
        .build();

    expect((await envUnderTest.applicationInfo)!.applicationId, 'configID');
    expect((await envUnderTest.applicationInfo)!.applicationVersion,
        'configVersion');
    expect((await envUnderTest.deviceInfo)!.model, 'configModel');
    expect(
        (await envUnderTest.deviceInfo)!.manufacturer, 'configManufacturer');
    expect((await envUnderTest.osInfo)!.name, 'configOsName');
    expect((await envUnderTest.osInfo)!.family, 'configFamily');
  });

  test('missing device info in config falls through to platform', () async {
    final configLayer = ConcreteEnvReporter(
        applicationInfo: Future.value(ApplicationInfo(
            applicationId: 'configID',
            applicationName: 'configName',
            applicationVersion: 'configVersion',
            applicationVersionName: 'configVersionName')),
        osInfo: Future.value(OsInfo(
            family: 'configFamily', name: 'configOsName', version: 'configOsVersion')),
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

    final envUnderTest = await PrioritizedEnvReporterBuilder()
        .setConfigLayer(configLayer)
        .setPlatformLayer(platformLayer)
        .build();

    expect((await envUnderTest.applicationInfo)!.applicationId, 'configID');
    expect((await envUnderTest.applicationInfo)!.applicationVersion,
        'configVersion');
    expect((await envUnderTest.deviceInfo)!.model, 'platformModel');
    expect((await envUnderTest.deviceInfo)!.manufacturer, 'platformManufacturer');
    expect((await envUnderTest.osInfo)!.name, 'configOsName');
    expect((await envUnderTest.osInfo)!.family, 'configFamily');
  });
}
