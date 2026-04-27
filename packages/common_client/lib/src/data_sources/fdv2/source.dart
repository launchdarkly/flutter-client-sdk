import 'selector.dart';
import 'source_result.dart';

/// A function that returns the current selector for a data source.
///
/// The orchestrator owns the SDK's current selector. Sources read it
/// lazily on each request or reconnect via this getter, so they always
/// see the latest value across mode switches and recoveries.
typedef SelectorGetter = Selector Function();

/// A function that performs a single FDv2 poll and returns the result.
///
/// Used by streaming sources to handle legacy `ping` events: when a ping
/// is received, the streaming source invokes the ping handler to fetch
/// the current payload via polling.
typedef PingHandler = Future<FDv2SourceResult> Function();

/// A one-shot data source that produces a single result.
///
/// Used during initialization to bring the SDK into a usable state from
/// cache, polling, or a streaming connection's first payload.
abstract interface class Initializer {
  /// Runs the initializer, producing a single result. If [close] is called
  /// before a result is produced, the returned future completes with a
  /// shutdown [StatusResult].
  Future<FDv2SourceResult> run();

  /// Cancels in-progress work. Idempotent.
  void close();
}

/// A long-lived data source that produces a stream of results.
///
/// Used during steady-state operation to keep the SDK current via polling
/// or streaming.
abstract interface class Synchronizer {
  /// Single-subscription stream of results. Cancelling the subscription
  /// stops the synchronizer; starting a new subscription is not supported.
  Stream<FDv2SourceResult> get results;

  /// Cancels active work. Idempotent. A shutdown [StatusResult] is
  /// emitted to any active subscriber before the stream closes.
  void close();
}
