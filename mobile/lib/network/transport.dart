import 'dart:async';
import 'dart:convert';
import 'dart:io';

abstract class MarketTransport {
  Future<Stream<dynamic>> connect();
  Future<Map<String, dynamic>> get(String path);
  void send(Map<String, dynamic> message);
  void close();
}

class IoMarketTransport implements MarketTransport {
  final Uri base;
  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);
  WebSocket? _socket;
  bool _closed = false;
  IoMarketTransport(String url) : base = Uri.parse(url);
  @override
  Future<Stream<dynamic>> connect() async {
    final uri = base
        .resolve('/v1/stream')
        .replace(scheme: base.scheme == 'https' ? 'wss' : 'ws');
    final socket = await WebSocket.connect(
      uri.toString(),
    ).timeout(const Duration(seconds: 6));
    if (_closed) {
      await socket.close();
      throw StateError('Transport closed');
    }
    _socket = socket;
    return socket;
  }

  @override
  Future<Map<String, dynamic>> get(String path) async {
    final request = await _http
        .getUrl(base.resolve(path))
        .timeout(const Duration(seconds: 6));
    final response = await request.close().timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 6));
    if (body.length > 2000000) {
      throw const FormatException('Response too large');
    }
    return Map<String, dynamic>.from(jsonDecode(body) as Map);
  }

  @override
  void send(Map<String, dynamic> message) => _socket?.add(jsonEncode(message));
  @override
  void close() {
    _closed = true;
    _socket?.close();
    _http.close(force: true);
  }
}
