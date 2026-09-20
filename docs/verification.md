# Verification ledger

## Automated evidence (2026-09-19)
- Backend: 11 pytest tests pass on Python 3.12.6, including actual FastAPI WebSocket sessions.
- Minimal-tier boundary test proves a closed candle equals canonical REST OHLCV.
- Automatic-tier integration test proves one client cannot change another client's tier.
- Flutter models: 5 tests pass (buffering, gaps, duplicates/out-of-order, epoch, malformed input, candle revision merge).
- Flutter controller: 3 tests pass (late interval responses, disposed/stale cache, deliberate book gap with snapshot recovery).
- Flutter widgets: 4 tests pass (320/430/900 widths at 1.5x text with populated book, chart touch inspection/reset).
- Flutter analysis: no issues.
- Android release APK built successfully, 46,952,554 bytes. Includes the recovery control.
- APK SHA-256: `ca2fdb233b704d327e8aed4ac9a6b5b297dd76fe81a1ac0b44b29919019db467`.

## Physical-device evidence (2026-09-20)
Tested the existing debug app on a Samsung Galaxy Tab A9 (SM-X110), 800 x 1340 capture, connected through wireless ADB, against the user's running Python backend. No emulator was launched for this verification. The existing app and backend were not reinstalled or restarted.

| Check | Observed result |
| --- | --- |
| Live price, chart and intervals | Price/candles update; 1m/5m history switches; drag selects timestamp/OHLC and Live resets inspection |
| Local book and trades | Ten bids and asks, positive spread and changing recent trades visible |
| Forced full | Server reports 10 Hz target; observed 8.2 Hz in a five-second window |
| Forced degraded | Server reports 2 Hz target; observed 2.0 Hz |
| Forced minimal | Server reports 0.5 Hz target; observed 0.6 Hz (discrete five-second count) |
| Missing book delta | Drop-one-update control increased recovery count from 3 to 4 and live book resumed; invalid-message count stayed zero |
| Disconnect / reconnect | Closing socket showed Paused/Stale with dimmed cached candles and stale book; resuming restored live price and synchronized book |
| Background / foreground | Home then deep-link activation returned to the live market with a new connection |
| Deep link | Android VIEW intent for twospoon://market/BTC-USD resolved successfully to MainActivity |
| Watchlist | Drag moved Bitcoin from third to first; screenshot confirms new order |
| Theme / layout | Physical dark theme and scrolling inspected; narrow/wide and large-text layouts covered by widget tests |

The recording repeats the book-gap recovery (count 4 to 5), disconnection and recovery. The device was left live with automatic delivery enabled. Measured message rates are not FPS. This is functional evidence from a debug build, not a release performance benchmark or a claim that the release APK was installed on this device.

## Recording and screenshots
[One-minute physical-device recording](media/twospoon-demo.mp4)

Approximate recording timeline:
- 00:00 Live 1m chart.
- 00:04 Drag to inspect a candle; return to latest.
- 00:11 Switch to 5m.
- 00:15 Scroll through ten-level book and recent trades.
- 00:24 Force degraded tier.
- 00:30 Force minimal tier.
- 00:38 Drop a book update and recover.
- 00:41 Disconnect; cached data becomes stale.
- 00:46 Reconnect and restore automatic policy.
- 00:54 Live market recovered.

Sampled recording frames were visually reviewed. Screenshots: [live market](media/live-market.png), [book/trades](media/book-trades.png), [minimal/recovery](media/minimal-recovery.png), [stale cache](media/stale-market.png), [reordered watchlist](media/watchlist.png).

## Review and scope
Code-review-and-quality checklist applied to domain boundaries, request generations, bounded queues, numeric precision, per-client policies and cleanup. Fixed a send-timeout catch that could have swallowed delivery failures; fixed a subscription change during an awaited chart send; fixed large-text layout overflows and cached status labels. Public client inputs are validated. No external market dependency or secrets are required.

Automatic hysteresis, missing-report fallback and cross-tier candle exactness are established by automated tests, not by deliberately degrading the user's Wi-Fi. Physical runtime checks cover the manual overrides and actual connection recovery. iOS is an implementation approach in the README, not a tested target.
