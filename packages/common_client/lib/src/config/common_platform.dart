import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    show EnvironmentReporter, ConcreteEnvReporter;

import '../persistence/persistence.dart';

final class CommonPlatform {
  final Persistence? persistence;
  final EnvironmentReporter platformEnvReporter;

  CommonPlatform(
      {this.persistence,
      EnvironmentReporter? platformEnvReporter,
      bool? autoEnvAttributes})
      : platformEnvReporter =
            platformEnvReporter ?? ConcreteEnvReporter.ofNulls();
}
