import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:flutter_web_contract_test_service/src/protocol.dart';

const String _appPath = 'app';
const Duration _browserTimeout = Duration(seconds: 90);

/// The contract test harness speaks REST. The SDK runs in a browser, which
/// cannot listen for HTTP requests. This adapter listens for the harness,
/// starts a headless browser, and relays each request to the browser over a
/// websocket.
final class Adapter {
  final HttpServer _server;
  final String _name;
  Process? _browser;
  Directory? _profile;
  WebSocketChannel? _channel;
  List<String>? _capabilities;
  final Completer<void> _ready = Completer<void>();
  final Completer<void> _stopped = Completer<void>();
  bool _stopping = false;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  int _nextRequestId = 0;

  Adapter._(this._server, this._name);

  static Future<Adapter> start(
      {required int port, required String webDir, required String name}) async {
    final adapter = Adapter._(
        await HttpServer.bind(InternetAddress.loopbackIPv4, port), name);
    final staticHandler =
        createStaticHandler(webDir, defaultDocument: 'index.html');
    // Only the page that this adapter serves may drive the relay.
    final socketHandler = webSocketHandler(adapter._onConnect, allowedOrigins: [
      'http://localhost:${adapter.port}',
      'http://127.0.0.1:${adapter.port}',
    ]);
    FutureOr<Response> handler(Request request) {
      final segments = request.url.pathSegments;
      if (request.url.path == websocketPath.substring(1)) {
        return socketHandler(request);
      }
      if (segments.isNotEmpty && segments.first == _appPath) {
        return staticHandler(request.change(path: _appPath));
      }
      return adapter._rest(request);
    }

    shelf_io.serveRequests(adapter._server, handler);
    return adapter;
  }

  int get port => _server.port;

  Future<void> get stopped => _stopped.future;

  /// Starts headless Chrome and waits for the page to send its hello message.
  ///
  /// Throws a [TimeoutException] if the page does not connect in time, and a
  /// [StateError] if the browser exits first.
  Future<void> launchBrowser(String executable) async {
    final profile =
        _profile = await Directory.systemTemp.createTemp('flutter-web-entity');
    final browser = _browser = await Process.start(executable, [
      '--headless=new',
      '--no-sandbox',
      '--disable-gpu',
      '--no-first-run',
      '--user-data-dir=${profile.path}',
      'http://localhost:$port/$_appPath/index.html',
    ]);
    unawaited(browser.exitCode.then((code) {
      if (_stopping) {
        return;
      }
      stderr.writeln('The browser exited with code $code.');
      if (!_ready.isCompleted) {
        _ready.completeError(StateError('The browser exited with code $code.'));
      }
      _failPending('The browser exited.');
    }));
    // Forward the browser output without binding the process sinks. A bound
    // sink rejects every other write to it, and shelf logs handler errors to
    // stderr.
    browser.stdout.listen(stdout.add);
    browser.stderr.listen(stderr.add);
    await _ready.future.timeout(_browserTimeout);
  }

  void _onConnect(WebSocketChannel channel, String? protocol) {
    _channel = channel;
    channel.stream.listen((data) {
      final Map<String, dynamic> message;
      try {
        message = jsonDecode(data as String) as Map<String, dynamic>;
      } catch (error) {
        stderr.writeln('Ignored a malformed websocket message: $error');
        return;
      }
      if (message['type'] == helloType) {
        _capabilities = (message['capabilities'] as List<dynamic>)
            .map((capability) => capability as String)
            .toList();
        if (!_ready.isCompleted) {
          _ready.complete();
        }
        return;
      }
      _pending.remove(message['id'])?.complete(message);
    }, onDone: () {
      // A newer connection may already own the relay.
      if (identical(_channel, channel)) {
        _channel = null;
        _failPending('The browser disconnected.');
      }
    });
  }

  void _failPending(String reason) {
    for (final pending in _pending.values) {
      pending.complete({'status': 500, 'error': reason});
    }
    _pending.clear();
  }

  Future<Map<String, dynamic>> _send(Map<String, dynamic> request) {
    final channel = _channel;
    if (channel == null) {
      return Future.value({'status': 503, 'error': 'No browser connected.'});
    }
    final id = _nextRequestId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    channel.sink.add(jsonEncode({...request, 'id': id}));
    return completer.future;
  }

  Future<Response> _rest(Request request) async {
    final segments = request.url.pathSegments;
    final method = request.method;

    if (segments.isEmpty) {
      switch (method) {
        case 'GET':
          if (_capabilities case final capabilities?) {
            return _json(200, {'name': _name, 'capabilities': capabilities});
          }
          return Response(503, body: 'The browser is not ready.');
        case 'POST':
          final reply = await _send({
            'op': createOp,
            'body': jsonDecode(await request.readAsString()),
          });
          if (reply['status'] == 201) {
            return Response(201, headers: {
              HttpHeaders.locationHeader: '/client/${reply['clientId']}'
            });
          }
          return _failure(reply);
        case 'DELETE':
          unawaited(Future(() async {
            await shutdown();
          }));
          return Response.ok('');
      }
    }

    if (segments.length == 2 && segments.first == 'client') {
      final clientId = int.tryParse(segments[1]);
      if (clientId == null) {
        return Response.notFound('');
      }
      switch (method) {
        case 'POST':
          final reply = await _send({
            'op': commandOp,
            'clientId': clientId,
            'body': jsonDecode(await request.readAsString()),
          });
          return reply['status'] == 200
              ? _json(200, reply['body'])
              : _failure(reply);
        case 'DELETE':
          final reply = await _send({'op': deleteOp, 'clientId': clientId});
          return reply['status'] == 200 ? Response.ok('') : _failure(reply);
      }
    }
    return Response.notFound('');
  }

  Response _failure(Map<String, dynamic> reply) =>
      Response(reply['status'] as int, body: reply['error']?.toString() ?? '');

  Response _json(int status, Object? body) => Response(status,
      body: jsonEncode(body),
      headers: {HttpHeaders.contentTypeHeader: 'application/json'});

  /// Stops the browser, deletes its profile, and closes the server. Safe to
  /// call more than once.
  Future<void> shutdown() async {
    if (_stopping) {
      return _stopped.future;
    }
    _stopping = true;
    final browser = _browser;
    if (browser != null) {
      browser.kill();
      await browser.exitCode
          .timeout(const Duration(seconds: 5), onTimeout: () => -1);
    }
    if (_profile case final profile?) {
      await profile.delete(recursive: true).catchError((_) => profile);
    }
    await _channel?.sink.close();
    await _server.close();
    _stopped.complete();
  }
}

const String _macChrome =
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

/// The Chrome to start when the `--chrome` option is not given. The
/// `CHROME_EXECUTABLE` variable wins, then the usual install for the platform.
String _defaultChrome() {
  if (Platform.environment['CHROME_EXECUTABLE'] case final path?
      when path.isNotEmpty) {
    return path;
  }
  if (Platform.isMacOS && File(_macChrome).existsSync()) {
    return _macChrome;
  }
  return 'google-chrome';
}

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('port', defaultsTo: '8080', help: 'The port for the harness.')
    ..addOption('web-dir',
        defaultsTo: 'build/web', help: 'The Flutter web build output.')
    ..addOption('chrome',
        defaultsTo: _defaultChrome(),
        help: 'The Chrome executable. The CHROME_EXECUTABLE variable also '
            'sets it.');
  final options = parser.parse(arguments);

  final adapter = await Adapter.start(
      port: int.parse(options['port'] as String),
      webDir: options['web-dir'] as String,
      name: 'flutter-web-client-sdk');
  print('Adapter listening on port ${adapter.port}');
  // The harness normally stops the adapter with DELETE. Stop the browser on
  // a signal too, so an interrupted run leaves no Chrome behind.
  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    signal.watch().listen((_) async {
      await adapter.shutdown();
      exit(1);
    });
  }

  final chrome = options['chrome'] as String;
  try {
    await adapter.launchBrowser(chrome);
  } on ProcessException catch (error) {
    stderr.writeln('Could not start Chrome ("$chrome"): ${error.message}. '
        'Set CHROME_EXECUTABLE or pass --chrome with the path to Chrome.');
    await adapter.shutdown();
    exit(1);
  } on TimeoutException {
    stderr.writeln('The page did not connect within $_browserTimeout. '
        'Check that the web app was built with --base-href /$_appPath/.');
    await adapter.shutdown();
    exit(1);
  } on StateError catch (error) {
    stderr.writeln(error.message);
    await adapter.shutdown();
    exit(1);
  }
  print('Browser connected');
  await adapter.stopped;
  exit(0);
}
