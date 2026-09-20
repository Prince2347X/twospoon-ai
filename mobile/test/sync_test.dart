import 'package:flutter_test/flutter_test.dart';
import 'package:twospoon/models/market.dart';

Map<String, dynamic> delta(
  int previous,
  int sequence, {
  int price = 100,
  int quantity = 5,
}) => {
  'epoch': 'a',
  'previous': previous,
  'sequence': sequence,
  'bids': [
    [price, quantity],
  ],
  'asks': <List<int>>[],
};
Map<String, dynamic> snapshot(int sequence) => {
  'epoch': 'a',
  'sequence': sequence,
  'bids': [
    [100, 2],
  ],
  'asks': [
    [110, 3],
  ],
};
Map<String, dynamic> candle(int time, int revision, int close) => {
  'time': time,
  'revision': revision,
  'open': 100,
  'high': 120,
  'low': 90,
  'close': close,
  'volume': 10,
};
void main() {
  test('buffers in-flight updates and applies only deltas after snapshot', () {
    final book = OrderBook();
    book.beginSync();
    book.receive(delta(8, 9));
    book.receive(delta(9, 10));
    book.receive(delta(10, 11, quantity: 7));
    expect(book.install(snapshot(10)), isTrue);
    expect(book.sequence, 11);
    expect(book.bids[100], 7);
    expect(book.ready, isTrue);
  });
  test(
    'gap and out-of-order updates require a new snapshot; deletion works',
    () {
      final book = OrderBook();
      book.install(snapshot(10));
      expect(book.receive(delta(11, 12)), isFalse);
      expect(book.ready, isFalse);
      book.beginSync();
      expect(book.install(snapshot(12)), isTrue);
      expect(book.receive(delta(12, 13, quantity: 0)), isTrue);
      expect(book.bids.containsKey(100), isFalse);
      expect(book.receive(delta(11, 12)), isFalse);
    },
  );
  test(
    'epoch change and a gap in buffered updates cannot appear synchronized',
    () {
      final book = OrderBook();
      book.beginSync();
      book.receive(delta(12, 13));
      expect(book.install(snapshot(10)), isFalse);
      book.beginSync();
      book.install(snapshot(13));
      expect(book.receive({...delta(13, 14), 'epoch': 'b'}), isFalse);
    },
  );
  test(
    'late history cannot overwrite newer live candles or duplicate timestamps',
    () {
      final series = CandleSeries();
      series.merge([candle(60000, 12, 115)]);
      series.merge([candle(0, 5, 100), candle(60000, 10, 105)]);
      expect(series.values.length, 2);
      expect(series.values.last.close, 115);
      series.merge([]);
      expect(series.values.length, 2);
    },
  );
  test('malformed candles and crossed snapshots are rejected atomically', () {
    final series = CandleSeries();
    expect(
      () => series.merge([
        candle(0, 1, 100),
        {...candle(1, 2, 100), 'high': 80},
      ]),
      throwsFormatException,
    );
    expect(series.values, isEmpty);
    final book = OrderBook();
    expect(
      () => book.install({
        ...snapshot(10),
        'asks': [
          [99, 2],
        ],
      }),
      throwsFormatException,
    );
    expect(book.ready, isFalse);
  });
}
