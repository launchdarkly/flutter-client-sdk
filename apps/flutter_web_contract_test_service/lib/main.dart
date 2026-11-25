import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'src/entity.dart';
import 'src/protocol.dart';

/// The browser half of the contract test service. It connects to the adapter
/// and runs the requests that the adapter relays from the test harness.
Future<void> main() async {
  try {
    await _run();
  } catch (error, stack) {
    // The adapter waits for the hello message. Print the reason so a failed
    // start is visible in the browser console.
    debugPrint('Entity failed to start: $error\n$stack');
    rethrow;
  }
}

Future<void> _run() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());

  final uri = Uri(
      scheme: Uri.base.scheme == 'https' ? 'wss' : 'ws',
      host: Uri.base.host,
      port: Uri.base.port,
      path: websocketPath);
  final channel = WebSocketChannel.connect(uri);
  await channel.ready;

  final entity = Entity();
  channel.sink.add(
      jsonEncode({'type': helloType, 'capabilities': Entity.capabilities}));

  channel.stream.listen((data) async {
    final request = jsonDecode(data as String) as Map<String, dynamic>;
    final response = await entity.handle(request);
    channel.sink.add(jsonEncode({...response, 'id': request['id']}));
  });
}
