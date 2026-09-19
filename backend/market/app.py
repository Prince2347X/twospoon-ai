"""REST snapshots and ordered, independently paced WebSocket connections."""
import asyncio
from contextlib import asynccontextmanager, suppress
import json
import logging
import math
import time
from typing import Literal

from fastapi import FastAPI, Query, WebSocket, WebSocketDisconnect

from .feed import Market
from .tiers import DeliveryTier

log = logging.getLogger('twospoon')


class Client:
    def __init__(self):
        self.queue: asyncio.Queue[dict] = asyncio.Queue(maxsize=128)
        self.overflow = asyncio.Event()
        self.policy = DeliveryTier(time.monotonic())
        self.interval: str | None = None
        self.request_id = 0
        self.last_revision = 0
        self.last_chart = 0.0
        self.last_status = 0.0

    def enqueue(self, message: dict) -> None:
        try:
            self.queue.put_nowait(message)
        except asyncio.QueueFull:
            self.overflow.set()

    def status(self) -> dict:
        return dict(type='status', tier=self.policy.name, rate=self.policy.rate,
                    override=self.policy.override)


def create_app(warmup: int = 36_000) -> FastAPI:
    clients: set[Client] = set()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.market = Market(warmup=warmup)

        async def generate():
            deadline = time.monotonic()
            while True:
                deadline += .1
                await asyncio.sleep(max(0, deadline - time.monotonic()))
                _, delta = app.state.market.step()
                for client in tuple(clients):
                    client.enqueue(delta)

        task = asyncio.create_task(generate())
        try:
            yield
        finally:
            task.cancel()
            with suppress(asyncio.CancelledError):
                await task

    app = FastAPI(title='TwoSpoon simulated market', version='1.0.0', lifespan=lifespan)

    @app.get('/health')
    async def health():
        return dict(status='ok', symbol='BTC-USD', epoch=app.state.market.epoch)

    @app.get('/v1/book')
    async def book():
        return app.state.market.snapshot()

    @app.get('/v1/candles')
    async def candles(interval: Literal['1m', '5m'] = '1m', limit: int = Query(120, ge=1, le=600)):
        market = app.state.market
        return dict(epoch=market.epoch, interval=interval, candles=market.history(interval, limit))

    @app.websocket('/v1/stream')
    async def stream(ws: WebSocket):
        await ws.accept()
        client = Client()
        market: Market = app.state.market
        clients.add(client)
        client.enqueue(dict(type='hello', epoch=market.epoch, symbol='BTC-USD',
                            priceScale=100, quantityScale=1_000_000))

        async def receive():
            while True:
                raw = await ws.receive_text()
                try:
                    if len(raw) > 4096:
                        raise ValueError('Message too large')
                    message = json.loads(raw)
                    if not isinstance(message, dict):
                        raise ValueError('Expected object')
                    kind = message.get('type')
                    if kind == 'ping':
                        ping_id = message['id']
                        if type(ping_id) is not int or not 0 <= ping_id <= 2**53:
                            raise ValueError('Invalid ping identifier')
                        client.enqueue(dict(type='pong', id=ping_id))
                    elif kind == 'subscribe':
                        interval, request_id = message['interval'], message['requestId']
                        if interval not in ('1m', '5m') or type(request_id) is not int:
                            raise ValueError('Invalid subscription')
                        client.interval, client.request_id = interval, request_id
                        client.last_revision = 0
                        client.last_chart = 0
                        client.enqueue(dict(type='subscribed', interval=interval,
                                            requestId=request_id, epoch=market.epoch))
                    elif kind == 'metrics':
                        latency, jitter = message['latency'], message['jitter']
                        if any(type(v) not in (int, float) or not math.isfinite(v)
                               or not 0 <= v <= 120_000 for v in (latency, jitter)):
                            raise ValueError('Invalid metrics')
                        client.policy.report(latency, jitter, time.monotonic())
                        client.enqueue(client.status())
                    elif kind == 'forceTier':
                        client.policy.force(message['tier'])
                        client.policy.tick(time.monotonic())
                        client.enqueue(client.status())
                    else:
                        raise ValueError('Unknown message type')
                except (ValueError, KeyError, TypeError):
                    client.enqueue(dict(type='error', code='invalid_message',
                                        message='Invalid message; connection remains available.'))

        async def send(message: dict):
            await asyncio.wait_for(ws.send_json(message), timeout=3)

        async def deliver():
            while True:
                if client.overflow.is_set():
                    await ws.close(code=1013, reason='Slow consumer; reconnect and snapshot')
                    return
                try:
                    message = await asyncio.wait_for(client.queue.get(), timeout=.025)
                except asyncio.TimeoutError:
                    message = None
                if message is not None:
                    await send(message)
                now = time.monotonic()
                before = client.policy.name
                client.policy.tick(now)
                if before != client.policy.name or now - client.last_status >= 2:
                    await send(client.status())
                    client.last_status = now
                if client.interval and now - client.last_chart >= 1 / client.policy.rate:
                    # Include every candle revised since the previous delivery, including
                    # a just-closed candle when a slow delivery spans a boundary.
                    changed = [c.wire() for c in market.candles[client.interval]
                               if c.revision > client.last_revision]
                    if client.last_revision == 0:
                        changed = changed[-2:]
                    if changed:
                        subscription = (client.interval, client.request_id)
                        await send(dict(type='chart', epoch=market.epoch,
                                        interval=client.interval, requestId=client.request_id,
                                        candles=changed, trades=list(market.trades)[-30:]))
                        if subscription == (client.interval, client.request_id):
                            client.last_revision = changed[-1]['revision']
                            client.last_chart = now

        tasks = [asyncio.create_task(receive()), asyncio.create_task(deliver())]
        try:
            done, _ = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
            for task in done:
                task.result()
        except (WebSocketDisconnect, RuntimeError, asyncio.TimeoutError):
            pass
        finally:
            clients.discard(client)
            for task in tasks:
                task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)
            with suppress(RuntimeError, WebSocketDisconnect):
                await ws.close()
            log.info('Client disconnected; remaining=%d', len(clients))

    return app


app = create_app()
