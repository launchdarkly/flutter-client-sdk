import 'defaults/default_config.dart';
import 'limits.dart';

final class EventsConfig {
  final int eventCapacity;
  final Duration flushInterval;
  final Duration diagnosticRecordingInterval;

  String getAnalyticEventsPath(String credential) {
    return DefaultConfig.eventPaths.getAnalyticEventsPath(credential);
  }

  String getDiagnosticEventsPath(String credential) {
    return DefaultConfig.eventPaths.getDiagnosticEventsPath(credential);
  }

  EventsConfig(
      {int? eventCapacity,
      Duration? flushInterval,
      Duration? diagnosticRecordingInterval})
      : eventCapacity =
            eventCapacity ?? DefaultConfig.eventConfig.defaultEventsCapacity,
        flushInterval =
            flushInterval ?? DefaultConfig.eventConfig.defaultFlushInterval,
        diagnosticRecordingInterval = durationWithMin(
            DefaultConfig.eventConfig.defaultDiagnosticRecordingInterval,
            diagnosticRecordingInterval,
            DefaultConfig.eventConfig.minDiagnosticRecordingInterval);
}
