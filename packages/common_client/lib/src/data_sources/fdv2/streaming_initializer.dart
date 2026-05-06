import 'dart:async';

import 'source.dart';
import 'source_result.dart';
import 'streaming_base.dart';

/// One-shot streaming initializer.
///
/// Subscribes to the underlying [FDv2StreamingBase], returns the first
/// emitted [FDv2SourceResult], and tears the connection down. Used at
/// SDK init time to bring the SDK to a usable state from the streaming
/// path before handing off to the long-lived synchronizer.
///
/// Calling [close] before the first emission resolves the pending
/// [run] future with a [SourceState.shutdown] result.
final class FDv2StreamingInitializer implements Initializer {
  final FDv2StreamingBase _base;
  final Completer<FDv2SourceResult> _completer = Completer<FDv2SourceResult>();
  StreamSubscription<FDv2SourceResult>? _subscription;
  bool _closed = false;

  FDv2StreamingInitializer({required FDv2StreamingBase base}) : _base = base;

  @override
  Future<FDv2SourceResult> run() {
    if (_closed) {
      return Future.value(_shutdownResult());
    }
    _subscription = _base.results.listen((result) {
      if (_completer.isCompleted) return;
      _completer.complete(result);
      // First emission received; tear down.
      _subscription?.cancel();
      _subscription = null;
      _base.close();
    }, onDone: () {
      if (_completer.isCompleted) return;
      // The base closed before producing a result. Surface as shutdown.
      _completer.complete(_shutdownResult());
    });
    return _completer.future;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _subscription?.cancel();
    _subscription = null;
    _base.close();
    if (!_completer.isCompleted) {
      _completer.complete(_shutdownResult());
    }
  }

  StatusResult _shutdownResult() => FDv2SourceResults.shutdown(
        message: 'Streaming initializer closed before first emission',
      );
}
