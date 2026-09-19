from fastapi.testclient import TestClient
from backend.market.app import create_app


def receive(ws, kind):
    for _ in range(100):
        message = ws.receive_json()
        if message['type'] == kind:
            return message
    raise AssertionError(f'No {kind} message')


def test_snapshot_history_and_subscription_contract():
    with TestClient(create_app(warmup=100)) as client:
        snap = client.get('/v1/book').json()
        assert len(snap['bids']) == 15
        history = client.get('/v1/candles?interval=1m').json()
        assert history['epoch'] == snap['epoch']
        assert history['candles']
        assert client.get('/v1/candles?interval=bad').status_code == 422
        with client.websocket_connect('/v1/stream') as ws:
            hello = receive(ws, 'hello')
            assert hello['epoch'] == snap['epoch']
            ws.send_json(dict(type='subscribe', interval='5m', requestId=7))
            ack = receive(ws, 'subscribed')
            assert ack['requestId'] == 7
            chart = receive(ws, 'chart')
            assert chart['interval'] == '5m' and chart['requestId'] == 7
            assert chart['candles']
            ws.send_json(dict(type='ping', id=19))
            assert receive(ws, 'pong')['id'] == 19


def test_forced_tiers_are_independent_and_malformed_input_is_recoverable():
    with TestClient(create_app(warmup=0)) as client:
        with client.websocket_connect('/v1/stream') as first, client.websocket_connect('/v1/stream') as second:
            receive(first, 'hello')
            receive(second, 'hello')
            receive(first, 'status')
            receive(second, 'status')
            first.send_json(dict(type='forceTier', tier='minimal'))
            assert receive(first, 'status')['tier'] == 'minimal'
            second.send_json(dict(type='forceTier', tier='full'))
            assert receive(second, 'status')['tier'] == 'full'
            first.send_text('{broken')
            assert receive(first, 'error')['code'] == 'invalid_message'
            first.send_json(dict(type='ping', id=3))
            assert receive(first, 'pong')['id'] == 3


def test_minimal_delivery_keeps_final_closed_candle_exact():
    app = create_app(warmup=0)
    with TestClient(app) as client:
        app.state.market.time = 59_000
        with client.websocket_connect('/v1/stream') as ws:
            receive(ws, 'hello')
            receive(ws, 'status')
            ws.send_json(dict(type='forceTier', tier='minimal'))
            assert receive(ws, 'status')['rate'] == 0.5
            ws.send_json(dict(type='subscribe', interval='1m', requestId=1))
            receive(ws, 'subscribed')
            first = receive(ws, 'chart')
            assert first['candles'][-1]['time'] == 0
            second = receive(ws, 'chart')
            closed = next(c for c in second['candles'] if c['time'] == 0)
            canonical = client.get('/v1/candles?interval=1m').json()['candles'][0]
            assert closed == canonical
            assert closed['revision'] == 9
            assert second['candles'][-1]['time'] == 60_000


def test_automatic_bad_reports_change_only_reporting_client():
    with TestClient(create_app(warmup=0)) as client:
        with client.websocket_connect('/v1/stream') as first, client.websocket_connect('/v1/stream') as second:
            for ws in (first, second):
                receive(ws, 'hello')
                receive(ws, 'status')
            first.send_json(dict(type='metrics', latency=1000, jitter=200))
            assert receive(first, 'status')['tier'] == 'full'
            first.send_json(dict(type='metrics', latency=1000, jitter=200))
            assert receive(first, 'status')['tier'] == 'minimal'
            second.send_json(dict(type='metrics', latency=30, jitter=2))
            assert receive(second, 'status')['tier'] == 'full'
