import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:meta/meta.dart';

import 'defaults/default_config.dart';

sealed class DataSourceConfigBase {
  /// Include evaluation reasons.
  final bool withReasons;

  /// The data source will attempt to use the reporting method if possible.
  ///
  /// For streaming requests on the web platform report is not supported.
  final bool useReport;

  DataSourceConfigBase({required this.withReasons, required this.useReport});
}

final class PollingDataSourceConfig extends DataSourceConfigBase {
  /// The path to use for doing GET requests.
  String pollingGetPath(String credential, String context) {
    return DefaultConfig.pollingPaths.pollingGetPath(credential, context);
  }

  /// The path to use for doing REPORT requests.
  String pollingReportPath(String credential, String context) {
    return DefaultConfig.pollingPaths.pollingReportPath(credential, context);
  }

  /// The current polling interval, if less than min, then the min will be used.
  final Duration pollingInterval;

  /// When true, the polling interval has no minimum. Only the contract test
  /// service sets this, so that tests can poll every few seconds. It has an
  /// effect only when asserts are enabled, as in debug builds and tests. A
  /// release build always applies the minimum.
  @visibleForTesting
  static bool ignorePollingMinimum = false;

  PollingDataSourceConfig(
      {Duration? pollingInterval, bool? withReasons, bool? useReport})
      : pollingInterval = _resolvePollingInterval(pollingInterval),
        super(
            withReasons: withReasons ??
                DefaultConfig.dataSourceConfig.defaultWithReasons,
            useReport:
                useReport ?? DefaultConfig.dataSourceConfig.defaultUseReport);

  static Duration _resolvePollingInterval(Duration? requested) {
    var ignoreMinimum = false;
    assert(() {
      ignoreMinimum = ignorePollingMinimum;
      return true;
    }());
    return ignoreMinimum
        ? durationGreaterThanZeroWithDefault(
            requested, DefaultConfig.pollingConfig.defaultPollingInterval)
        : durationWithMin(DefaultConfig.pollingConfig.defaultPollingInterval,
            requested, DefaultConfig.pollingConfig.minPollingInterval);
  }
}

final class StreamingDataSourceConfig extends DataSourceConfigBase {
  /// The path to use for doing GET requests.
  String streamingGetPath(String credential, String context) {
    return DefaultConfig.streamingPaths.streamingGetPath(credential, context);
  }

  /// The path to use for doing REPORT requests.
  String streamingReportPath(String credential, String context) {
    return DefaultConfig.streamingPaths
        .streamingReportPath(credential, context);
  }

  StreamingDataSourceConfig({bool? withReasons, bool? useReport})
      : super(
            withReasons: withReasons ??
                DefaultConfig.dataSourceConfig.defaultWithReasons,
            useReport:
                useReport ?? DefaultConfig.dataSourceConfig.defaultUseReport);
}
