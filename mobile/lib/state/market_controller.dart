import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/market.dart';
import '../network/transport.dart';

class MarketController extends ChangeNotifier {
  final MarketTransport Function() transportFactory;
  final OrderBook book = OrderBook();
  final CandleSeries series = CandleSeries();
  List<Trade> trades = [];
  String interval = '1m', connection = 'Connecting', tier = 'full';
  String? epoch, error, forcedTier;
  double rate = 10, latency = 0, jitter = 0;
  bool connected = false, loadingHistory = true, historyFailed = false;
  bool paused = false, background = false;
  int malformed = 0, recoveries = 0;
  bool _skipNextBook = false;
  final List<int> _chartArrivals = [];
  double get receivedHz =>
      _chartArrivals
          .where((time) => _clock.elapsedMilliseconds - time <= 5000)
          .length /
      5;
  void simulateBookGap() {
    if (connected) _skipNextBook = true;
  }

  int _generation = 0, _request = 0, _pingId = 0, _attempt = 0;
  bool _disposed = false, _syncing = false;
  MarketTransport? _transport;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry, _heartbeat, _notification, _bookRetry;
  final Stopwatch _clock = Stopwatch()..start();
  final Map<int, int> _pings = {};
  final List<double> _samples = [];
  int _lastMessage = 0;
  MarketController({required this.transportFactory});
  bool get live => connected && book.ready && !loadingHistory && !historyFailed;
  int? get latestPrice =>
      trades.isNotEmpty ? trades.first.price : series.values.lastOrNull?.close;

  void _changed() {
    if (_disposed || _notification != null) return;
    _notification = Timer(const Duration(milliseconds: 100), () {
      _notification = null;
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> start() async {
    if (_disposed || paused || background) return;
    _stop();
    final generation = _generation;
    connection = 'Connecting';
    error = null;
    _changed();
    final transport = transportFactory();
    _transport = transport;
    try {
      final stream = await transport.connect();
      if (generation != _generation || _disposed) {
        transport.close();
        return;
      }
      _lastMessage = _clock.elapsedMilliseconds;
      _subscription = stream.listen(
        (raw) => _message(raw, generation),
        onError: (Object _) => _disconnected(generation),
        onDone: () => _disconnected(generation),
        cancelOnError: true,
      );
      _heartbeat = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _ping(generation),
      );
    } catch (_) {
      _disconnected(generation);
    }
  }

  void _stop() {
    _generation++;
    _retry?.cancel();
    _heartbeat?.cancel();
    _bookRetry?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _transport?.close();
    _transport = null;
    _skipNextBook = false;
    _chartArrivals.clear();
    _pings.clear();
    _samples.clear();
    connected = false;
    _syncing = false;
    book.markStale();
  }

  void _disconnected(int generation) {
    if (generation != _generation || _disposed) return;
    _stop();
    connection = 'Disconnected';
    _changed();
    if (!paused && !background) {
      final seconds = min(16, 1 << min(_attempt++, 4));
      _retry = Timer(
        Duration(milliseconds: seconds * 1000 + Random().nextInt(250)),
        start,
      );
    }
  }

  void reconnect() {
    _attempt = 0;
    unawaited(start());
  }

  void setPaused(bool value) {
    paused = value;
    if (value) {
      _stop();
      connection = 'Paused';
      _changed();
    } else {
      reconnect();
    }
  }

  void setBackground(bool value) {
    if (background == value) return;
    background = value;
    if (value) {
      _stop();
      connection = 'Background';
      _changed();
    } else if (!paused) {
      reconnect();
    }
  }

  void selectInterval(String value) {
    if (!['1m', '5m'].contains(value) || value == interval) return;
    interval = value;
    _request++;
    series.clear();
    loadingHistory = true;
    historyFailed = false;
    if (connected) _subscribe();
    _changed();
  }

  void _subscribe() {
    _request++;
    loadingHistory = true;
    historyFailed = false;
    _transport?.send({
      'type': 'subscribe',
      'interval': interval,
      'requestId': _request,
    });
  }

  void retryHistory() {
    if (connected) _subscribe();
  }

  void forceTier(String? value) {
    forcedTier = value;
    _transport?.send({'type': 'forceTier', 'tier': value});
    _changed();
  }

  void _message(dynamic raw, int generation) {
    if (generation != _generation || _disposed) return;
    try {
      if (raw is! String || raw.length > 2000000) {
        throw const FormatException('Invalid frame');
      }
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _lastMessage = _clock.elapsedMilliseconds;
      switch (m['type']) {
        case 'hello':
          final nextEpoch = epochOf(m);
          if (epoch != nextEpoch) {
            series.clear();
            trades = [];
          }
          epoch = nextEpoch;
          connected = true;
          connection = 'Connected';
          _attempt = 0;
          _subscribe();
          unawaited(_snapshot(generation));
          _transport?.send({'type': 'forceTier', 'tier': forcedTier});
          _ping(generation);
        case 'subscribed':
          if (m['requestId'] == _request && m['interval'] == interval) {
            unawaited(_history(generation, _request, interval));
          }
        case 'book':
          if (_skipNextBook) {
            _skipNextBook = false;
            return;
          }
          final wasReady = book.ready;
          if (!book.receive(m) && wasReady) {
            recoveries++;
            unawaited(_snapshot(generation));
          }
        case 'chart':
          if (m['epoch'] != epoch ||
              m['requestId'] != _request ||
              m['interval'] != interval) {
            return;
          }
          final parsed = (m['trades'] as List)
              .map((t) => Trade.fromJson(Map<String, dynamic>.from(t as Map)))
              .toList();
          series.merge(m['candles'] as List);
          final arrival = _clock.elapsedMilliseconds;
          _chartArrivals.removeWhere((time) => arrival - time > 5000);
          _chartArrivals.add(arrival);
          final unique = {
            for (final t in [...trades, ...parsed]) t.id: t,
          }.values.toList()..sort((a, b) => b.id.compareTo(a.id));
          trades = unique.take(30).toList();
        case 'status':
          if (!['full', 'degraded', 'minimal'].contains(m['tier']) ||
              m['rate'] is! num) {
            throw const FormatException('Invalid tier');
          }
          tier = m['tier'] as String;
          rate = (m['rate'] as num).toDouble();
        case 'pong':
          final sent = _pings.remove(m['id']);
          if (sent != null) {
            final rtt = (_clock.elapsedMilliseconds - sent).toDouble();
            _samples.add(rtt);
            if (_samples.length > 10) _samples.removeAt(0);
            latency = _samples.reduce((a, b) => a + b) / _samples.length;
            jitter = 0;
            for (var i = 1; i < _samples.length; i++) {
              jitter += (_samples[i] - _samples[i - 1]).abs();
            }
            if (_samples.length > 1) jitter /= _samples.length - 1;
            _transport?.send({
              'type': 'metrics',
              'latency': latency,
              'jitter': jitter,
            });
          }
        case 'error':
          error = 'Server rejected a message';
        default:
          throw const FormatException('Unknown message');
      }
    } catch (_) {
      malformed++;
      error = 'Invalid update received; resynchronizing';
      if (connected) {
        unawaited(_snapshot(generation));
        retryHistory();
      }
    }
    _changed();
  }

  void _ping(int generation) {
    if (generation != _generation) return;
    final now = _clock.elapsedMilliseconds;
    if (now - _lastMessage > 10000 ||
        _pings.values.any((sent) => now - sent > 10000)) {
      _disconnected(generation);
      return;
    }
    final id = ++_pingId;
    _pings[id] = now;
    _transport?.send({'type': 'ping', 'id': id});
  }

  Future<void> _history(
    int generation,
    int request,
    String requestedInterval,
  ) async {
    try {
      final data = await _transport!.get(
        '/v1/candles?interval=$requestedInterval',
      );
      if (generation != _generation || request != _request || _disposed) return;
      if (data['epoch'] != epoch || data['interval'] != interval) {
        throw const FormatException('History mismatch');
      }
      series.merge(data['candles'] as List);
      loadingHistory = false;
      historyFailed = false;
    } catch (_) {
      if (generation != _generation || request != _request || _disposed) return;
      loadingHistory = false;
      historyFailed = true;
      error = 'History unavailable. Tap retry.';
    }
    _changed();
  }

  Future<void> _snapshot(int generation) async {
    if (_syncing || generation != _generation || !connected) return;
    _syncing = true;
    book.beginSync();
    _changed();
    try {
      final data = await _transport!.get('/v1/book');
      if (generation != _generation || _disposed) return;
      if (data['epoch'] != epoch || !book.install(data)) {
        throw const FormatException('Book mismatch');
      }
      error = null;
    } catch (_) {
      if (generation != _generation || _disposed) return;
      book.markStale();
      error = 'Synchronizing order book';
      _bookRetry?.cancel();
      _bookRetry = Timer(
        const Duration(milliseconds: 500),
        () => _snapshot(generation),
      );
    } finally {
      if (generation == _generation && !_disposed) {
        _syncing = false;
        _changed();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stop();
    _notification?.cancel();
    _clock.stop();
    super.dispose();
  }
}
