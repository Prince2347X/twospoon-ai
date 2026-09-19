"""Deterministic integer-unit simulation, independent of client delivery."""
from collections import deque
from dataclasses import asdict, dataclass
import math
import random
import time
import uuid

INTERVALS = {'1m': 60_000, '5m': 300_000}


@dataclass
class Candle:
    time: int
    open: int
    high: int
    low: int
    close: int
    volume: int
    revision: int

    @classmethod
    def from_trade(cls, timestamp: int, trade: dict) -> 'Candle':
        price = trade['price']
        return cls(timestamp, price, price, price, price, trade['quantity'], trade['id'])

    def add(self, trade: dict) -> None:
        self.high = max(self.high, trade['price'])
        self.low = min(self.low, trade['price'])
        self.close = trade['price']
        self.volume += trade['quantity']
        self.revision = trade['id']

    def wire(self) -> dict:
        return asdict(self)


class Market:
    def __init__(self, seed: int = 42, start_ms: int | None = None, warmup: int = 36_000):
        self.epoch = uuid.uuid4().hex
        self.random = random.Random(seed)
        end = int(time.time() * 1000) if start_ms is None else start_ms
        self.time = end - warmup * 100
        self.sequence = 0
        self.price = 6_742_000
        self.trades: deque[dict] = deque(maxlen=100)
        self.candles: dict[str, deque[Candle]] = {key: deque(maxlen=600) for key in INTERVALS}
        self.bids, self.asks = self._book()
        for _ in range(warmup):
            self.step()

    def _book(self) -> tuple[dict[int, int], dict[int, int]]:
        center = self.price // 100 * 100
        sides = []
        for direction in (-1, 1):
            sides.append({center + direction * (100 + level * 100):
                          self.random.randint(50_000, 900_000) for level in range(15)})
        return sides[0], sides[1]

    def step(self) -> tuple[dict, dict]:
        previous = self.sequence
        self.sequence += 1
        self.time += 100
        # Mean reversion plus slow waves keeps long demos plausible and bounded.
        target = 6_742_000 + int(18_000 * math.sin(self.sequence / 1200))
        self.price = max(100, self.price + self.random.randint(-180, 180)
                         + int((target - self.price) * 0.004))
        trade = dict(id=self.sequence, time=self.time, price=self.price,
                     quantity=self.random.randint(1000, 120_000),
                     side='buy' if self.random.random() > .5 else 'sell')
        self.trades.append(trade)
        for interval, duration in INTERVALS.items():
            bucket = self.time // duration * duration
            candles = self.candles[interval]
            if not candles or candles[-1].time != bucket:
                candles.append(Candle.from_trade(bucket, trade))
            else:
                candles[-1].add(trade)
        bids, asks = self._book()

        def changes(old: dict, new: dict) -> list:
            return [[p, new.get(p, 0)] for p in sorted(old.keys() | new.keys())
                    if old.get(p) != new.get(p)]

        delta = dict(type='book', epoch=self.epoch, previous=previous,
                     sequence=self.sequence, bids=changes(self.bids, bids),
                     asks=changes(self.asks, asks))
        self.bids, self.asks = bids, asks
        return trade, delta

    def snapshot(self) -> dict:
        return dict(epoch=self.epoch, sequence=self.sequence,
                    bids=sorted(self.bids.items(), reverse=True), asks=sorted(self.asks.items()))

    def history(self, interval: str, limit: int = 120) -> list[dict]:
        return [c.wire() for c in list(self.candles[interval])[-limit:]]
