import 'package:http/http.dart' as http;
import '../../config/http_properties.dart';

http.Client createClient(HttpProperties properties) {
  return http.Client();
}
