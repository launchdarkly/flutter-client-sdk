import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';

final class MockEventProcessor implements EventProcessor {
  final customEvents = <CustomEvent>[];
  final evalEvents = <EvalEvent>[];
  final identifyEvents = <IdentifyEvent>[];

  @override
  Future<void> flush() async {
    // no-op in this mock
  }

  @override
  void processCustomEvent(CustomEvent event) {
    customEvents.add(event);
  }

  @override
  void processEvalEvent(EvalEvent event) {
    evalEvents.add(event);
  }

  @override
  void processIdentifyEvent(IdentifyEvent event) {
    identifyEvents.add(event);
  }

  @override
  void start() {
    // no-op in this mock
  }

  @override
  void stop() {
    // no-op in this mock
  }
}
