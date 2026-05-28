import 'source.dart';
import 'source_result.dart';
import 'streaming_base.dart';

/// Long-lived streaming synchronizer.
///
/// A thin adapter that exposes [FDv2StreamingBase.results] as a
/// [Synchronizer]. The base class already implements all of the
/// connection lifecycle, protocol parsing, and error handling; this
/// wrapper exists only to satisfy the [Synchronizer] interface so the
/// orchestrator can treat polling and streaming uniformly.
final class FDv2StreamingSynchronizer implements Synchronizer {
  final FDv2StreamingBase _base;

  FDv2StreamingSynchronizer({required FDv2StreamingBase base}) : _base = base;

  @override
  Stream<FDv2SourceResult> get results => _base.results;

  @override
  void close() => _base.close();
}
