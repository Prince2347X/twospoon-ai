import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:twospoon/network/transport.dart';
import 'package:twospoon/state/market_controller.dart';

class FakeTransport implements MarketTransport {
  final stream = StreamController<dynamic>();
  final sent = <Map<String, dynamic>>[];
  int bookSequence = 0;
  final histories = <Completer<Map<String, dynamic>>>[];
  @override
  Future<Stream<dynamic>> connect() async => stream.stream;
  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (path.contains('book')) {
      return {
        'epoch': 'a',
        'sequence': bookSequence,
        'bids': [
          [100, 1],
        ],
        'asks': [
          [110, 1],
        ],
      };
    }
    final completer = Completer<Map<String, dynamic>>();
    histories.add(completer);
    return completer.future;
  }

  void emit(Map<String, dynamic> value) => stream.add(jsonEncode(value));
  @override
  void send(Map<String, dynamic> message) => sent.add(message);
  @override
  void close() {}
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));
Map<String, dynamic> history(String interval, int price) => {
  'epoch': 'a',
  'interval': interval,
  'candles': [
    {
      'time': 0,
      'open': price,
      'high': price,
      'low': price,
      'close': price,
      'volume': 1,
      'revision': 1,
    },
  ],
};
void main() {
  test(
    'old interval responses cannot replace selected interval history',
    () async {
      final transport = FakeTransport();
      final controller = MarketController(transportFactory: () => transport);
      await controller.start();
      transport.emit({'type': 'hello', 'epoch': 'a'});
      await settle();
      final first = transport.sent.firstWhere((m) => m['type'] == 'subscribe');
      transport.emit({
        'type': 'subscribed',
        'interval': '1m',
        'requestId': first['requestId'],
      });
      await settle();
      controller.selectInterval('5m');
      final second = transport.sent.lastWhere((m) => m['type'] == 'subscribe');
      transport.emit({
        'type': 'subscribed',
        'interval': '5m',
        'requestId': second['requestId'],
      });
      await settle();
      transport.histories[1].complete(history('5m', 200));
      await settle();
      transport.histories[0].complete(history('1m', 100));
      await settle();
      expect(controller.series.values.single.close, 200);
      expect(controller.interval, '5m');
      controller.dispose();
      await transport.stream.close();
    },
  );
  test(
    'disconnect retains cached prices as stale and pending history cannot mutate disposed state',
    () async {
      final transport = FakeTransport();
      final controller = MarketController(transportFactory: () => transport);
      await controller.start();
      transport.emit({'type': 'hello', 'epoch': 'a'});
      await settle();
      final sub = transport.sent.firstWhere((m) => m['type'] == 'subscribe');
      transport.emit({
        'type': 'subscribed',
        'interval': '1m',
        'requestId': sub['requestId'],
      });
      await settle();
      transport.emit({
        'type': 'chart',
        'epoch': 'a',
        'interval': '1m',
        'requestId': sub['requestId'],
        'candles': history('1m', 123)['candles'],
        'trades': [],
      });
      await settle();
      controller.setPaused(true);
      expect(controller.latestPrice, 123);
      expect(controller.live, isFalse);
      controller.dispose();
      transport.histories.single.complete(history('1m', 999));
      await settle();
      expect(controller.latestPrice, 123);
      await transport.stream.close();
    },
  );
  test('a deliberately missed delta triggers snapshot recovery', () async {
    final transport = FakeTransport();
    final controller = MarketController(transportFactory: () => transport);
    await controller.start();
    transport.emit({'type': 'hello', 'epoch': 'a'});
    await settle();
    expect(controller.book.ready, isTrue);
    controller.simulateBookGap();
    transport.emit({
      'type': 'book',
      'epoch': 'a',
      'previous': 0,
      'sequence': 1,
      'bids': [],
      'asks': [],
    });
    await settle();
    transport.bookSequence = 2;
    transport.emit({
      'type': 'book',
      'epoch': 'a',
      'previous': 1,
      'sequence': 2,
      'bids': [],
      'asks': [],
    });
    await settle();
    expect(controller.recoveries, 1);
    expect(controller.book.ready, isTrue);
    expect(controller.book.sequence, 2);
    controller.dispose();
    await transport.stream.close();
  });
}
