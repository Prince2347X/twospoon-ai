# TwoSpoon market implementation

## Objective and acceptance
Implement every requirement in ../assignment.md: a Flutter Android detail screen backed by a deterministic FastAPI market. Deliver source, Android APK, demo recording, comprehensive README, and public GitHub repository. Include deep linking and watchlist reordering; a single simulated instrument remains the only live market.

## Decisions
- BTC/USD, 1m and 5m intervals, UTC epoch milliseconds, monotonic trade/book identifiers scoped to a server epoch.
- Integer cents and quantity millionths end to end; doubles only for painting coordinates.
- One backend market engine owns all candles. Per-client delivery cannot change market computation.
- Full/degraded/minimal: 10/2/0.5 Hz maximum chart rates. Ordered book updates use a separate bounded queue. Slow clients reconnect and snapshot rather than silently drop deltas.
- Flutter ChangeNotifier application state, pure synchronization models, dart:io HTTP/WebSocket transport, CustomPainter chart. No embedded external charts.
- Restrained finance UI, system theme, clear connection and tier indicators, inspectable candle chart, depth visualization, recent prints, debug sheet.

## Structure and style
backend/market/ contains pure feed/tier models and the FastAPI boundary. backend/tests/ contains pytest tests. mobile/lib/ splits models, networking, state, and UI. docs/ records protocol and verification evidence.
Python snake_case, typed functions and dataclasses; Dart standard formatter and immutable wire models. Example: `price_cents: int` is exact; `price_cents / 100` is display-only.

## Commands
- Setup: `python -m venv .venv`, `.venv/Scripts/python -m pip install -r backend/requirements.txt`
- Backend: `.venv/Scripts/python -m uvicorn backend.market.app:app --host 0.0.0.0 --port 8000`
- Tests: `.venv/Scripts/python -m pytest backend/tests`
- Mobile (mobile/): `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --release`

## Implementation order
1. Pure deterministic feed and tier state machine; prove exact candles, hysteresis, missing-report fallback.
2. REST/WS contract and integration tests; independent clients, bounded queues, subscription races.
3. Flutter synchronization models and tests; snapshot buffering/recovery, candle merge/races.
4. Transport/controller, lifecycle/reconnect, latency measurement and debug controls.
5. Screen and gestures, deep link/watchlist, accessibility and device verification.
6. Android build, recording, README, requirement audit, public repository delivery.

## Boundaries and verification
Always validate wire input, keep bounded memory, test meaningful invariants, and document limitations. Never introduce real trading, exchange credentials, secrets, or claim unperformed verification. Public publishing must use an authorized destination. No database is needed for this in-memory simulated market.
Tests cover both pure state machines and real REST/WS integration, Flutter model/controller/widget tests, then Android runtime evidence. An APK alone is not proof of runtime behavior.
