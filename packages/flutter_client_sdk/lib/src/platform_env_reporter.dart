import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// [EnvironmentReporter] that can retrieve info from various platforms.  Makes
/// best effort to be performant, but performance may vary by platform.
class PlatformEnvReporter implements EnvironmentReporter {
  @override
  Future<ApplicationInfo?> get applicationInfo async {
    final info = await PackageInfo.fromPlatform();
    return ApplicationInfo(
        applicationId: info.packageName,
        applicationName: info.appName,
        applicationVersion: info.buildNumber,
        applicationVersionName: info.version);
  }

  @override
  Future<OsInfo?> get osInfo async {
    if (kIsWeb) {
      // TODO: implement web auto env
      return null;
    } else {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        return OsInfo(
          family: 'Android',
          name:
              'Android', // excluding API version int here to be consistent with MAUI
          version: info.version
              .release, // This is the 9 in 'Android 9 (SDK 28)' and agrees with our Android and MAUI SDKs
        );
      } else if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        return OsInfo(
          family: 'Apple',
          name: 'iOS',
          version: info.systemVersion,
        );
      } else if (Platform.isMacOS) {
        final info = await DeviceInfoPlugin().macOsInfo;
        return OsInfo(
          family: 'Apple',
          name: 'macOS',
          version:
              '${info.majorVersion}.${info.minorVersion}.${info.patchVersion}',
        );
      } else if (Platform.isWindows) {
        final info = await DeviceInfoPlugin().windowsInfo;
        return OsInfo(
          family: 'Windows',
          name: info.productName,
          version: info.buildLab,
        );
      } else if (Platform.isLinux) {
        final info = await DeviceInfoPlugin().linuxInfo;
        return OsInfo(
          family: 'Linux',
          name: info.name,
          version: info.version,
        );
      } else if (Platform.isLinux) {
        final info = await DeviceInfoPlugin().linuxInfo;
        return OsInfo(
          family: 'Linux',
          name: info.name,
          version: info.version,
        );
      } else if (Platform.isFuchsia) {
        // current platform library does not support Fuchsia, best we can do is
        // provide the family.
        return OsInfo(
          family: 'Fuchsia',
        );
      } else {
        // There is no reliable way to get device info for these platforms.
        // At the time of writing this, windows, linux, and fuchsia fall into
        // this category.
        return null;
      }
    }
  }

  @override
  Future<DeviceInfo?> get deviceInfo async {
    if (kIsWeb) {
      // TODO: implement web auto env
      return null;
    } else {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        return DeviceInfo(
          model: info.model,
          manufacturer: info.manufacturer,
        );
      } else if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        return DeviceInfo(model: info.model, manufacturer: 'Apple');
      } else if (Platform.isMacOS) {
        final info = await DeviceInfoPlugin().macOsInfo;
        return DeviceInfo(model: info.model, manufacturer: 'Apple');
      } else {
        // There is no reliable way to get device info for these platforms.
        // At the time of writing this, Windows, Linux, and Fuchsia fall into
        // this category.
        return null;
      }
    }
  }

  @override
  Future<String?> get locale async {
    if (kIsWeb) {
      final info = await DeviceInfoPlugin().webBrowserInfo;
      return info.language;
    } else {
      return Platform.localeName;
    }
  }
}
