import 'dart:convert';

import '../config/service_endpoints.dart';
import '../ld_logging.dart';
import '../network/http_client.dart';
import '../network/utils.dart';
import '../serialization/diagnostic_event_serialization.dart';
import '../serialization/event_serialization.dart';
import 'diagnostics_manager.dart';
import 'event_processor.dart';
import 'event_summarizer.dart';
import 'dart:async';
import 'package:http_parser/http_parser.dart';

import 'package:uuid/uuid.dart';

import 'events.dart';

const _eventSchema = '4';

// Currently the event processor only supports client-side events. If server
// support is added, then conditional _index event support should be added
// along with the corresponding context de-duplication.

final class DefaultEventProcessor implements EventProcessor {
  final _eventSummarizer = EventSummarizer();
  final LDLogger _logger;
  final int _eventCapacity;
  final Duration _flushInterval;
  final Duration _diagnosticRecordingInterval;
  final HttpClient _client;
  final Uuid _uuidSource = Uuid();
  late final Uri _eventsUri;
  late final Uri _diagnosticEventsUri;
  late final DiagnosticsManager? _diagnosticsManager;

  int _droppedEvents = 0;
  int _eventsInLastBatch = 0;
  DateTime? _lastKnownServerTime;
  List<dynamic> _eventBuffer = [];
  bool _shutdown = false;
  Timer? _analyticEventsTimer;
  Timer? _diagnosticEventsTimer;

  /// Returns true if the event processor has been shutdown due to an error.
  bool get shutdown => _shutdown;

  DefaultEventProcessor(
      {required LDLogger logger,
      bool indexEvents = false,
      required int eventCapacity,
      required Duration flushInterval,
      required HttpClient client,
      required String analyticsEventsPath,
      required String diagnosticEventsPath,
      required ServiceEndpoints endpoints,
      required Duration diagnosticRecordingInterval,
      DiagnosticsManager? diagnosticsManager})
      : _logger = logger.subLogger('EventProcessor'),
        _eventCapacity = eventCapacity,
        _flushInterval = flushInterval,
        _client = client,
        _diagnosticsManager = diagnosticsManager,
        _diagnosticRecordingInterval = diagnosticRecordingInterval {
    _eventsUri = Uri.parse(appendPath(endpoints.events, analyticsEventsPath));

    _diagnosticEventsUri =
        Uri.parse(appendPath(endpoints.events, diagnosticEventsPath));
  }

  @override
  void processEvalEvent(EvalEvent event) {
    _eventSummarizer.summarize(event);

    if (event.trackEvent) {
      _enqueue(EvalEventSerialization.toJson(event));
    }

    if (_shouldDebugEvent(event)) {
      _enqueue(EvalEventSerialization.toJson(event, isDebug: true));
    }
  }

  @override
  void processCustomEvent(CustomEvent event) {
    _enqueue(CustomEventSerialization.toJson(event));
  }

  @override
  void processIdentifyEvent(IdentifyEvent event) {
    _enqueue(IdentifyEventSerialization.toJson(event));
  }

  @override
  void start() {
    if (_shutdown) {
      return;
    }
    // Init event will only be produced by the diagnostics manager once.
    final initEvent = _diagnosticsManager?.getInitEvent();
    if (initEvent != null) {
      _postDiagnosticEvent(DiagnosticInitEventSerialization.toJson(initEvent));
    }

    if (_diagnosticsManager != null) {
      _diagnosticEventsTimer ??=
          Timer.periodic(_diagnosticRecordingInterval, (_) {
        _reportDiagnosticStats();
      });
    }

    _analyticEventsTimer ??= Timer.periodic(_flushInterval, (_) {
      _doFlush();
    });
  }

  void _reportDiagnosticStats() {
    final statsEvent = _diagnosticsManager?.createStatsEventAndReset(
        _droppedEvents, _eventsInLastBatch);
    if (statsEvent != null) {
      _postDiagnosticEvent(
          DiagnosticStatsEventSerialization.toJson(statsEvent));
    }
  }

  @override
  void stop() {
    _analyticEventsTimer?.cancel();
    _analyticEventsTimer = null;
    _diagnosticEventsTimer?.cancel();
    _diagnosticEventsTimer = null;
  }

  @override
  Future<void> flush() async {
    await _doFlush();
  }

  Future<void> _doFlush() async {
    if (_shutdown) {
      return;
    }

    final eventsToFlush = _eventBuffer;
    _eventBuffer = [];

    final summaryEvent = _eventSummarizer.createEventAndReset();

    if (summaryEvent != null) {
      eventsToFlush.add(SummaryEventSerialization.toJson(summaryEvent));
    }
    if (eventsToFlush.isEmpty) {
      return;
    }

    _eventsInLastBatch = eventsToFlush.length;

    _logger.debug('Flushing $_eventsInLastBatch events');
    await _postAnalyticEvents(eventsToFlush);
  }

  Future<void> _postAnalyticEvents(dynamic payload) async {
    await _tryPosting(payload, _eventsUri, true, payloadId: _uuidSource.v4());
  }

  Future<void> _postDiagnosticEvent(dynamic payload) async {
    await _tryPosting(payload, _diagnosticEventsUri, true);
  }

  /// Try posting an event payload. If `canRetry` is true, then a second
  /// attempt will be made if posting fails.
  Future<void> _tryPosting(dynamic payload, Uri uri, bool canRetry,
      {String? payloadId}) async {
    final additionalHeaders = <String, String>{
      'x-launchdarkly-event-schema': _eventSchema,
      'content-type': 'application/json'
    };
    if (payloadId != null) {
      additionalHeaders['x-launchdarkly-payload-id'] = payloadId;
    }

    try {
      final response = await _client.request(RequestMethod.post, _eventsUri,
          body: jsonEncode(payload), additionalHeaders: additionalHeaders);

      if (response.headers.containsKey('date')) {
        try {
          _lastKnownServerTime = parseHttpDate(response.headers['date']!);
        } catch (err) {
          _logger.debug('could not parse server time from event response');
        }
      }

      if (response.statusCode <= 204) {
        return;
      }

      if (!isHttpLocallyRecoverable(response.statusCode)) {
        _logger.error(
            'Encountered unrecoverable status while sending events ${response.statusCode}.');
        _shutdown = true;
        return;
      } else {
        if (!canRetry) {
          _logger.warn(
              'Received an unexpected response ${response.statusCode} delivering events and some events were dropped.');
        }
      }
    } catch (err) {
      if (!canRetry) {
        _logger.warn(
            'Received an unexpected error: {$err} delivering events and some events were dropped.');
      }
    }

    if (canRetry) {
      _logger.debug('Encountered a problem sending events, will retry.');
      // This will retry once after 1 second.
      await Future.delayed(Duration(seconds: 1));
      await _tryPosting(payload, uri, false, payloadId: payloadId);
    }
  }

  void _enqueue(dynamic json) {
    if (_shutdown) {
      return;
    }
    if (_eventBuffer.length == _eventCapacity - 1) {
      _logger.warn(
          'Event queue at capacity. Increase capacity to avoid dropping events.');
    }
    if (_eventBuffer.length < _eventCapacity) {
      _eventBuffer.add(json);
    } else {
      _droppedEvents += 1;
    }
  }

  bool _shouldDebugEvent(EvalEvent event) {
    return event.debugEventsUntilDate != null &&
        (event.debugEventsUntilDate?.millisecondsSinceEpoch ?? 0) >
            DateTime.now().millisecondsSinceEpoch &&
        (event.debugEventsUntilDate?.millisecondsSinceEpoch ?? 0) >
            (_lastKnownServerTime?.millisecondsSinceEpoch ?? 0);
  }
}
