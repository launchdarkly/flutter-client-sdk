import 'dart:math';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

import 'defaults/default_config.dart';

/// Configuration for event processing and sending.
final class EventsConfig {
  final bool disabled;
  final bool diagnosticOptOut;
  final int eventCapacity;
  final Duration flushInterval;
  final Duration diagnosticRecordingInterval;

  /// Configure the event processing/sending behavior of the SDK.
  ///
  /// Configuring the SDK to be offline will supersede this configuration.
  ///
  /// If [disabled] is set to true, then the SDK will send no events.
  ///
  /// Ff [diagnosticOptOut] is set to true, then the SDK will not send
  /// periodic diagnostic events.
  ///
  /// The [eventCapacity] represents the number of events that will be buffered.
  /// Events are periodically flushed and events that are accumulated beyond
  /// the capacity withing the flush interval will be discarded. In some
  /// situations the SDK may not be able to send events, such as a lack of
  /// network connectivity, so events will accumulate in those conditions.
  ///
  /// The [flushInterval] controls how often the SDK will flush events.
  ///
  /// The [diagnosticRecordingInterval] controls the frequency the SDK will
  /// send periodic diagnostic information.
  EventsConfig(
      {this.disabled = false,
      this.diagnosticOptOut = false,
      int? eventCapacity,
      Duration? flushInterval,
      Duration? diagnosticRecordingInterval})
      : eventCapacity = max(0,
            eventCapacity ?? DefaultConfig.eventConfig.defaultEventsCapacity),
        flushInterval = durationGreaterThanZeroWithDefault(
            flushInterval, DefaultConfig.eventConfig.defaultFlushInterval),
        diagnosticRecordingInterval = durationWithMin(
            DefaultConfig.eventConfig.defaultDiagnosticRecordingInterval,
            diagnosticRecordingInterval,
            DefaultConfig.eventConfig.minDiagnosticRecordingInterval);
}
