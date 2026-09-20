import 'dart:collection';

int integer(dynamic value, {int minimum = 0}) {
  if (value is! int || value < minimum || value > 9007199254740991) {
    throw const FormatException('Invalid integer');
  }
  return value;
}

String epochOf(Map<String, dynamic> json) {
  final epoch = json['epoch'];
  if (epoch is! String || epoch.isEmpty) {
    throw const FormatException('Invalid epoch');
  }
  return epoch;
}

class Candle {
  final int time, open, high, low, close, volume, revision;
  const Candle(
    this.time,
    this.open,
    this.high,
    this.low,
    this.close,
    this.volume,
    this.revision,
  );
  factory Candle.fromJson(Map<String, dynamic> json) {
    final c = Candle(
      integer(json['time']),
      integer(json['open'], minimum: 1),
      integer(json['high'], minimum: 1),
      integer(json['low'], minimum: 1),
      integer(json['close'], minimum: 1),
      integer(json['volume']),
      integer(json['revision']),
    );
    if (c.low > c.open ||
        c.low > c.close ||
        c.high < c.open ||
        c.high < c.close ||
        c.low > c.high) {
      throw const FormatException('Invalid OHLC');
    }
    return c;
  }
}

class CandleSeries {
  final _candles = SplayTreeMap<int, Candle>();
  List<Candle> get values => List.unmodifiable(_candles.values);
  void clear() => _candles.clear();
  void merge(List<dynamic> items) {
    final parsed = items
        .map((e) => Candle.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    for (final candle in parsed) {
      if (candle.revision >= (_candles[candle.time]?.revision ?? -1)) {
        _candles[candle.time] = candle;
      }
    }
    while (_candles.length > 120) {
      _candles.remove(_candles.firstKey());
    }
  }
}

class Trade {
  final int id, time, price, quantity;
  final bool buy;
  const Trade(this.id, this.time, this.price, this.quantity, this.buy);
  factory Trade.fromJson(Map<String, dynamic> json) {
    if (json['side'] != 'buy' && json['side'] != 'sell') {
      throw const FormatException('Invalid side');
    }
    return Trade(
      integer(json['id']),
      integer(json['time']),
      integer(json['price'], minimum: 1),
      integer(json['quantity'], minimum: 1),
      json['side'] == 'buy',
    );
  }
}

class BookDelta {
  final String epoch;
  final int previous, sequence;
  final Map<int, int> bids, asks;
  BookDelta(Map<String, dynamic> json)
    : epoch = epochOf(json),
      previous = integer(json['previous']),
      sequence = integer(json['sequence']),
      bids = levels(json['bids']),
      asks = levels(json['asks']) {
    if (sequence != previous + 1) {
      throw const FormatException('Invalid sequence');
    }
  }
}

Map<int, int> levels(dynamic value) {
  if (value is! List || value.length > 1000) {
    throw const FormatException('Invalid levels');
  }
  final result = <int, int>{};
  for (final row in value) {
    if (row is! List || row.length != 2) {
      throw const FormatException('Invalid level');
    }
    result[integer(row[0], minimum: 1)] = integer(row[1]);
  }
  return result;
}

class OrderBook {
  Map<int, int> bids = {}, asks = {};
  final List<BookDelta> _pending = [];
  String? epoch;
  int sequence = 0;
  bool ready = false;
  bool _overflow = false;
  void beginSync() {
    ready = false;
    _pending.clear();
    _overflow = false;
  }

  void markStale() {
    ready = false;
    _pending.clear();
  }

  bool receive(Map<String, dynamic> json) {
    final delta = BookDelta(json);
    if (!ready) {
      if (_pending.length < 256) {
        _pending.add(delta);
      } else {
        _overflow = true;
      }
      return false;
    }
    if (delta.epoch != epoch || delta.previous != sequence) {
      ready = false;
      return false;
    }
    _apply(delta);
    return true;
  }

  bool install(Map<String, dynamic> json) {
    final nextEpoch = epochOf(json), nextSequence = integer(json['sequence']);
    final nextBids = levels(json['bids']), nextAsks = levels(json['asks']);
    nextBids.removeWhere((_, q) => q == 0);
    nextAsks.removeWhere((_, q) => q == 0);
    if (nextBids.isEmpty ||
        nextAsks.isEmpty ||
        nextBids.keys.reduce((a, b) => a > b ? a : b) >=
            nextAsks.keys.reduce((a, b) => a < b ? a : b)) {
      throw const FormatException('Crossed or empty book');
    }
    epoch = nextEpoch;
    sequence = nextSequence;
    bids = nextBids;
    asks = nextAsks;
    if (_overflow) {
      ready = false;
      return false;
    }
    for (final delta in _pending) {
      if (delta.epoch != epoch) {
        ready = false;
        return false;
      }
      if (delta.sequence <= nextSequence) continue;
      if (delta.previous != sequence) {
        ready = false;
        return false;
      }
      _apply(delta);
    }
    _pending.clear();
    ready = true;
    return true;
  }

  void _apply(BookDelta delta) {
    for (final pair in [(bids, delta.bids), (asks, delta.asks)]) {
      for (final entry in pair.$2.entries) {
        if (entry.value == 0) {
          pair.$1.remove(entry.key);
        } else {
          pair.$1[entry.key] = entry.value;
        }
      }
    }
    sequence = delta.sequence;
  }

  List<MapEntry<int, int>> top(bool buy) {
    final items = (buy ? bids : asks).entries.toList()
      ..sort((a, b) => buy ? b.key.compareTo(a.key) : a.key.compareTo(b.key));
    return items.take(10).toList();
  }
}
