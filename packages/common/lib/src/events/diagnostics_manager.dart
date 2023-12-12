import 'diagnostic_events.dart';
import 'package:uuid/uuid.dart';

String _getSdkPrefix(String credential) {
  return credential.length > 6
      ? credential.substring(credential.length - 6)
      : credential;
}

final class DiagnosticsManager {
  final DateTime _startTime = DateTime.now();
  final List<StreamInitData> _streamInits = [];

  final DiagnosticId _id;

  late DateTime _dataSinceDate;

  // The diagnostic init event is created on init of the diagnostics manager
  // and then can be accessed once. Only one init event is needed for the
  // duration of the client.
  //
  // This approach allows us to create the event without retaining references
  // to the various data collected.
  DiagnosticInitEvent? _initEvent;

  DiagnosticsManager(
      {required String credential,
      required DiagnosticSdkData sdkData,
      required DiagnosticPlatformData platformData,
      required DiagnosticConfigData configData})
      : _id = DiagnosticId(
            diagnosticId: Uuid().v4(),
            sdkKeySuffix: _getSdkPrefix(credential)) {
    _initEvent = DiagnosticInitEvent(
        id: _id,
        creationDate: DateTime.now(),
        sdk: sdkData,
        configuration: configData,
        platform: platformData);
    _dataSinceDate = _startTime;
  }

  /// Gets the initial event that is sent by the event processor when the SDK
  /// starts up. This will not be repeated during the lifetime of the SDK client.
  ///
  /// If a subsequent call is made to this function, then it will return null.
  DiagnosticInitEvent? getInitEvent() {
    final tmp = _initEvent;
    _initEvent = null;
    return tmp;
  }

  /// Records a stream connection attempt (called by the stream processor).
  ///
  /// [duration] is the elapsed time between starting timestamp and when we
  /// either gave up/lost the connection or received a successful "put".
  void recordStreamInit(DateTime timestamp, bool failed, Duration duration) {
    _streamInits.add(StreamInitData(
        timestamp: timestamp,
        failed: failed,
        durationMillis: duration.inMilliseconds));
  }

  /// Creates a periodic event containing time-dependent stats, and resets the
  /// state of the manager with regard to those stats.
  DiagnosticStatsEvent createStatsEventAndReset(
      int droppedEvents, int eventsInLastBatch) {
    final event = DiagnosticStatsEvent(
        id: _id,
        creationDate: DateTime.now(),
        dataSinceDate: _dataSinceDate,
        droppedEvents: droppedEvents,
        eventsInLastBatch: eventsInLastBatch,
        streamInits: _streamInits);

    _streamInits.clear();
    _dataSinceDate = DateTime.now();

    return event;
  }
}
