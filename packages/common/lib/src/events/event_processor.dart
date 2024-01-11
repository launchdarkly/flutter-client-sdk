import 'events.dart';

abstract interface class EventProcessor {
  void processEvalEvent(EvalEvent event);

  void processCustomEvent(CustomEvent event);

  void processIdentifyEvent(IdentifyEvent event);

  /// Start the event processor. An event processor may be stopped and started
  /// multiple times.
  ///
  /// An event processor which has encountered a permanent error does not need
  /// to take any action on starting.
  void start();

  /// Stop the event processor. The event processor may be started again, so
  /// stop should not take any actions which prevents the event processor from
  /// being started.
  void stop();

  /// Flush the analytic events. The returned future should resolve once the
  /// events have been flushed, or event flushing has exhausted all retries
  /// and failed.
  Future<void> flush();
}
