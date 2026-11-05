// ignore_for_file: close_sinks
// ignore_for_file: depend_on_referenced_packages

// (close_sinks) Closing sinks ignored for Wifi connectivity mock.
// (depend_on_referenced_packages) We are using connectivity_plus_platform_interface as an indirect dependency
// for testing.

import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter_test/flutter_test.dart';
import 'package:launchdarkly_common_client/launchdarkly_common_client.dart'
    show Event, MessageEvent, OpenEvent;
import 'package:launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _WifiConnected extends ConnectivityPlatform {
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController();
  Stream<List<ConnectivityResult>>? _stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    _stream ??= _controller.stream.asBroadcastStream();
    return _stream!;
  }
}

/// An SSE client that sends one empty put when the SDK listens. The SDK can
/// then start without a network connection.
final class _FakeSseClient implements SSEClient {
  final SSEClientRequest request;
  int closeCount = 0;

  late final StreamController<Event> _controller =
      StreamController<Event>.broadcast(onListen: () {
    _controller.add(const OpenEvent());
    _controller.add(const MessageEvent('put', '{}', null));
  });

  _FakeSseClient(this.request);

  @override
  Stream<Event> get stream => _controller.stream;

  @override
  Future<void> close() async {
    closeCount++;
  }

  @override
  void restart() {}

  @override
  bool hasCapability(SSECapability capability) => true;
}

void main() {
  test('eventSourceFactory is not set by default', () {
    final config = LDConfig('credential', AutoEnvAttributes.disabled);

    expect(config.eventSourceFactory, isNull);
  });

  test('eventSourceFactory is stored in the configuration', () {
    SSEClient factory(SSEClientRequest request) => throw UnimplementedError();

    final config = LDConfig('credential', AutoEnvAttributes.disabled,
        eventSourceFactory: factory);

    expect(config.eventSourceFactory, same(factory));
  });

  group('with a started client', () {
    setUpAll(() {
      ConnectivityPlatform.instance = _WifiConnected();
      widgets.WidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('eventSourceFactory creates the streaming client', () async {
      final created = <_FakeSseClient>[];
      final config = LDConfig('mobile-key', AutoEnvAttributes.disabled,
          events: EventsConfig(disabled: true),
          applicationEvents: ApplicationEvents(
              backgrounding: false, networkAvailability: false),
          persistence: PersistenceConfig(maxCachedContexts: 0),
          eventSourceFactory: (request) {
        final client = _FakeSseClient(request);
        created.add(client);
        return client;
      });
      final client =
          LDClient(config, LDContextBuilder().kind('user', 'user-key').build());

      final started = await client
          .start()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      await client.close();

      expect(started, isTrue);
      expect(created, hasLength(1));
      expect(created.single.request.method, SseHttpMethod.get);
      expect(created.single.closeCount, 1);
    });
  });
}
