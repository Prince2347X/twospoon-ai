from backend.market.feed import Market, Candle


def test_candle_uses_every_trade_with_exact_integer_volume():
    candle = Candle.from_trade(0, {'id': 1, 'price': 100, 'quantity': 3})
    for trade in [dict(id=2, price=150, quantity=7), dict(id=3, price=80, quantity=11)]:
        candle.add(trade)
    assert candle.wire() == dict(time=0, open=100, high=150, low=80, close=80, volume=21, revision=3)


def test_seed_reproduces_feed_and_book_is_uncrossed():
    first = Market(seed=7, start_ms=0, warmup=0)
    second = Market(seed=7, start_ms=0, warmup=0)
    for _ in range(1000):
        trade_a, delta_a = first.step()
        trade_b, delta_b = second.step()
        assert trade_a == trade_b
        assert {k: v for k, v in delta_a.items() if k != 'epoch'} == {
            k: v for k, v in delta_b.items() if k != 'epoch'}
        book = first.snapshot()
        assert len(book['bids']) >= 10 and len(book['asks']) >= 10
        assert max(p for p, _ in book['bids']) < min(p for p, _ in book['asks'])


def test_deltas_reconstruct_snapshot_and_remove_old_levels():
    market = Market(seed=7, start_ms=0, warmup=0)
    snap = market.snapshot()
    bids, asks = dict(snap['bids']), dict(snap['asks'])
    sequence = snap['sequence']
    for _ in range(200):
        _, delta = market.step()
        assert delta['previous'] == sequence
        sequence = delta['sequence']
        for side, values in [(bids, delta['bids']), (asks, delta['asks'])]:
            for price, quantity in values:
                if quantity == 0:
                    side.pop(price, None)
                else:
                    side[price] = quantity
    assert bids == dict(market.snapshot()['bids'])
    assert asks == dict(market.snapshot()['asks'])


def test_history_retains_closed_candles_across_slow_delivery_boundaries():
    market = Market(seed=12, start_ms=59_800, warmup=0)
    trades = [market.step()[0] for _ in range(30)]
    candles = market.history('1m')
    for candle in candles:
        bucket = [t for t in trades if t['time'] // 60_000 * 60_000 == candle['time']]
        assert candle['open'] == bucket[0]['price']
        assert candle['close'] == bucket[-1]['price']
        assert candle['high'] == max(t['price'] for t in bucket)
        assert candle['low'] == min(t['price'] for t in bucket)
        assert candle['volume'] == sum(t['quantity'] for t in bucket)
