// Tests for the adapter process. They do not need Chrome. The adapter starts
// with `--chrome` pointing at a shell script that only sleeps, so the child
// holds the stdio pipes the same way a real browser does.
//
// Run from this directory with `flutter test test/adapter_test.dart`.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory scratch;
  late Process adapter;
  late int port;
  late File fakeChromePidFile;
  late StringBuffer stderrBuffer;

  int? fakeChromePid() {
    if (!fakeChromePidFile.existsSync()) {
      return null;
    }
    return int.tryParse(fakeChromePidFile.readAsStringSync().trim());
  }

  bool processExists(int pid) => Process.killPid(pid, ProcessSignal.sigcont);

  setUp(() async {
    stderrBuffer = StringBuffer();
    scratch = await Directory.systemTemp.createTemp('adapter-test-');
    // The static handler needs an existing directory with an index file.
    final webDir = Directory('${scratch.path}/web')..createSync();
    File('${webDir.path}/index.html').writeAsStringSync('<html></html>');

    // A stand-in for Chrome. It records its PID so the test can check for
    // it and kill it, then holds stdout and stderr open.
    fakeChromePidFile = File('${scratch.path}/chrome.pid');
    final fakeChrome = File('${scratch.path}/fake-chrome.sh')
      ..writeAsStringSync('#!/bin/sh\n'
          'echo \$\$ > "${fakeChromePidFile.path}"\n'
          'exec sleep 300\n');
    await Process.run('chmod', ['+x', fakeChrome.path]);

    port = await _freePort();
    adapter = await Process.start('dart', [
      'run',
      'bin/adapter.dart',
      '--port',
      '$port',
      '--web-dir',
      webDir.path,
      '--chrome',
      fakeChrome.path,
    ]);
    adapter.stderr
        .transform(const SystemEncoding().decoder)
        .listen(stderrBuffer.write);
    adapter.stdout.drain<void>();

    await _waitForPort(port);
  });

  tearDown(() async {
    // A termination signal lets the adapter delete its browser profile.
    adapter.kill(ProcessSignal.sigterm);
    await adapter.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
      adapter.kill(ProcessSignal.sigkill);
      return -1;
    });
    if (fakeChromePid() case final pid?) {
      Process.killPid(pid, ProcessSignal.sigkill);
    }
    await scratch.delete(recursive: true);
  });

  test('the adapter survives one POST with a non-JSON body', () async {
    final client = HttpClient();
    try {
      final request = await client.post('127.0.0.1', port, '/');
      request.headers.contentType = ContentType.json;
      request.write('this is not json');
      final response = await request.close();
      await response.drain<void>();
      expect(response.statusCode, 500);
    } finally {
      client.close(force: true);
    }

    final exitCode = await adapter.exitCode
        .timeout(const Duration(seconds: 3), onTimeout: () => -1);

    expect(exitCode, -1,
        reason: 'the adapter exited with code $exitCode after one malformed '
            'POST; stderr was: $stderrBuffer');
    expect(stderrBuffer.toString(),
        isNot(contains('StreamSink is bound to a stream')));
  });

  test('a termination signal stops the adapter and the browser', () async {
    // The adapter starts the browser after it opens its port.
    final pid = await _waitFor(fakeChromePid, 'the browser PID file');
    expect(processExists(pid), isTrue);

    adapter.kill(ProcessSignal.sigterm);

    final exitCode =
        await adapter.exitCode.timeout(const Duration(seconds: 10));
    expect(exitCode, 1);
    // The kill is asynchronous on the OS side; allow it a moment to land.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(processExists(pid), isFalse,
        reason: 'the browser process is still running after the adapter '
            'stopped');
  });
}

/// Polls [read] until it returns a value.
Future<T> _waitFor<T extends Object>(T? Function() read, String what) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (read() case final value?) {
      return value;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('$what did not appear within 10 seconds');
}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

/// Polls the adapter until it accepts a connection. The status GET answers
/// 503 until the page connects, which is enough to show the server is up.
Future<void> _waitForPort(int port) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    try {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
      await socket.close();
      return;
    } on SocketException {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
  fail('the adapter did not open port $port within 60 seconds');
}
