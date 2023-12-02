import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../config/http_properties.dart';

http.Client createClient(HttpProperties properties) {
  final innerClient = HttpClient();
  innerClient.connectionTimeout = properties.connectTimeout;
  return IOClient(innerClient);
}
