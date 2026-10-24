// Talks to the fatsecret-proxy backend, the same server The Calorie Card uses.
// Ported from The Calorie Card (lib/services/proxy_client.dart).

import 'dart:convert';

import 'package:http/http.dart' as http;

/// The proxy said no because the request wasn't signed in.
class ProxyAuthException implements Exception {
  const ProxyAuthException(this.status);
  final int status;
  @override
  String toString() => 'The food engine needs a signed-in account ($status).';
}

class ProxyClient {
  ProxyClient._();

  /// Override at build time with:
  ///   flutter run -d chrome --dart-define=PROXY_BASE_URL=http://localhost:3000
  static const String baseUrl = String.fromEnvironment('PROXY_BASE_URL', defaultValue: 'https://fatsecret-proxy.onrender.com');

  /// Supplies the signed-in user's Firebase ID token, which the proxy uses to reject anonymous
  /// traffic and rate-limit per user. Set this once Firebase Auth is connected:
  ///   ProxyClient.tokenProvider = () async => FirebaseAuth.instance.currentUser?.getIdToken();
  /// While sign-in is mocked it is null and requests go without a token.
  static Future<String?> Function()? tokenProvider;

  static Future<Map<String, String>> _headers() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    try {
      final token = await tokenProvider?.call();
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    } catch (_) {
      // No token: the proxy decides.
    }
    return headers;
  }

  static http.Response _check(http.Response r) {
    if (r.statusCode == 401 || r.statusCode == 403) throw ProxyAuthException(r.statusCode);
    return r;
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body) async =>
      _check(await http.post(Uri.parse('$baseUrl$path'), headers: await _headers(), body: json.encode(body)));

  static Future<http.Response> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return _check(await http.get(uri, headers: await _headers()));
  }

  static DateTime? _lastWarmUp;

  /// Opens the connection ahead of a lookup. At most once every 4 minutes, errors ignored.
  static void warmUp() {
    final now = DateTime.now(), last = _lastWarmUp;
    if (last != null && now.difference(last) < const Duration(minutes: 4)) return;
    _lastWarmUp = now;
    http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 60)).then((_) {}, onError: (_) {});
  }
}
