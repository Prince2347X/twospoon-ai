Title: Software Engineer – App Assignment

URL Source: https://twospoon.notion.site/Software-Engineer-App-Assignment-3dc4ed449ba48091b3cfc3ec5fecb7d0

Published Time: Thu, 09 Jul 2026 17:43:03 GMT

Markdown Content:
Build a polished Android app for one simulated cryptocurrency market. Create the backend that generates the market data and serves it to the app. The central challenge is to adapt the rate of live chart updates to each client's connection while keeping the underlying market data correct.

Generate a continuous stream of trades for one symbol. Each trade should have a timestamp, price, quantity, and an unambiguous ordering identifier.

Maintain a plausible order book for that symbol with at least 10 bids and 10 asks. Provide a REST snapshot and incremental WebSocket updates that the app can use to keep its local book synchronized.

Provide historical OHLCV candles for at least two selectable intervals, along with a WebSocket feed for the active candle and recent trades.

Make the generated feed repeatable enough to demonstrate and test important cases. No exchange account or external market-data service should be needed to run the project.

Document one command that starts the backend and how an Android emulator or device connects to it.

You may choose the backend language, framework, message format, and data-generation approach.

Build one responsive screen showing:

The symbol's latest price and its movement.

A candlestick chart with at least two intervals. Fetch history from your backend, then update the active candle live. Let users touch or drag to inspect a candle's timestamp and OHLC values.

The top 10 bids and asks from the locally maintained order book.

Recent trades and the current connection status.

You may use a chart library to render data supplied by your own application. Fetching history, switching intervals, forming or updating candles, and handling late responses must be implemented in your code. Embedded charts, chart WebViews, and components that fetch or stream the data themselves are not allowed.

The app must periodically measure round-trip time over its WebSocket connection and report both latency and jitter to the backend. Document how these measurements are calculated.

The backend must maintain a delivery tier per client connection: full, degraded, or minimal. It owns the tier decision. Define your own thresholds and target chart-update rates, and explain your choices.

Use hysteresis so brief fluctuations do not repeatedly switch tiers. Define what happens when reports are missing or the connection drops.

The backend must continue processing the complete generated trade stream and computing correct OHLCV candles at every tier. A slower tier changes how frequently chart updates are delivered, not the candle's final open, high, low, close, or volume.

Expose the active tier and effective update rate in the app. Provide a documented debug control that can force a connection into any tier so all three states can be demonstrated without relying on poor Wi-Fi. The normal automatic behavior must also work when the override is off.

The target rates are a design choice, not a requirement to invent trades when no market event occurs. It is acceptable to combine multiple generated trades into one outgoing chart update if their candle values remain correct.

Build the app's order book from a REST snapshot plus ordered WebSocket deltas. Handle updates that arrive while the snapshot request is in flight. Detect a missing or out-of-order update, then request a fresh snapshot and resume.

Reconnect and resubscribe after a disconnection. Show cached values as stale while disconnected rather than presenting them as live.

Handle app foreground and background transitions, interval changes, malformed messages, empty history, duplicate candles, and requests that finish after the selected interval has changed.

Keep scrolling, chart gestures, and other interactions smooth during frequent updates. Dispose of connections and subscriptions when appropriate.

Mobile: Flutter with Dart is preferred; React Native with TypeScript is also accepted. An Android build is required. Explain how you would approach iOS support during the interview; an iOS build is not required.

Architecture: Keep UI, application state, networking, and backend feed logic distinct. Choose and explain a suitable state-management approach.

Precision: Handle prices and quantities with appropriate numeric precision, and use timestamps and update identifiers consistently.

Tests: Include at least two meaningful automated tests. In particular, we recommend a test for tier changes and hysteresis, and a test for order-book snapshot/delta synchronization and recovery.

Public Github Url

A short screen recording showing the live chart, interval change, order book, a forced tier change, and recovery from a disconnected state.

A README explaining the architecture and state-management choices; generated data and API protocol; chart and order-book synchronization; latency and jitter measurement; tier thresholds, hysteresis, and missing-report fallback; reconnect and app lifecycle behavior; debug controls; packages used; and known limitations.

Correctness of the adaptive delivery state machine and per-client behavior.

Accuracy of candles across tiers and correct order-book recovery after missed updates.

UI quality, chart interactions, responsiveness, and clear live/stale states.

Sound WebSocket and REST integration, lifecycle handling, and error recovery.

Code structure, meaningful tests, and ability to explain and modify the implementation in the interview.

Deep linking into the cryptocurrency detail screen.

Watchlist reordering.

You may use ChatGPT, Claude, Cursor, Copilot or other AI tools. During the technical interview, you should be able to explain, debug and answer questions regarding your implementation.

Good luck!

![Image 1](https://twospoon.notion.site/image/https%3A%2F%2Fprod-files-secure.s3.us-west-2.amazonaws.com%2Ffb80de85-e543-44f9-b9cb-9627930dcaf8%2F568d7374-febe-4b87-83a4-d00b094c193f%2FUntitled.png?table=block&id=3dc4ed44-9ba4-80c8-926f-e13175a2e1d0&spaceId=fb80de85-e543-44f9-b9cb-9627930dcaf8&width=1410&userId=&cache=v2&imgBuildSrc=requestProxiedImageUrl)
