import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

/// An [LDLogAdapter] that captures every log record into a list, for
/// assertions about what does or does not appear in log output.
class CapturingLogAdapter implements LDLogAdapter {
  final List<LDLogRecord> records = [];

  /// Convenience: just the message strings.
  List<String> get messages => records.map((r) => r.message).toList();

  @override
  void log(LDLogRecord record) {
    records.add(record);
  }
}
