import 'package:flutter/material.dart';
import '../state/market_controller.dart';
import 'chart.dart';

class MarketScreen extends StatefulWidget {
  final MarketController controller;
  const MarketScreen({super.key, required this.controller});
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen>
    with WidgetsBindingObserver {
  bool favorite = true;
  final watchlist = ['Bitcoin', 'Ethereum', 'Solana'];
  MarketController get market => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) market.setBackground(false);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      market.setBackground(true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: market,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final candles = market.series.values;
      final price = market.latestPrice;
      final reference = candles.isEmpty ? price : candles.first.open;
      final change = price == null || reference == null ? 0 : price - reference;
      final positive = change >= 0;
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Watchlist',
            icon: const Icon(Icons.format_list_bulleted_rounded),
            onPressed: _watchlist,
          ),
          title: const Text(
            'twospoon',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -.8),
          ),
          actions: [
            IconButton(
              tooltip: 'Connection controls',
              onPressed: _controls,
              icon: const Icon(Icons.tune_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7931A).withValues(alpha: .14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.currency_bitcoin,
                          color: Color(0xFFF7931A),
                          size: 29,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bitcoin',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text('BTC / USD', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: favorite
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                        onPressed: () => setState(() {
                          favorite = !favorite;
                          if (favorite) {
                            watchlist.insert(0, 'Bitcoin');
                          } else {
                            watchlist.remove('Bitcoin');
                          }
                        }),
                        icon: Icon(
                          favorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: favorite
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'SIMULATED SPOT MARKET',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      price == null ? '--' : '\$${money(price)}',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1.6,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        '${positive ? '+' : ''}${money(change)} (${reference == null || reference == 0 ? '0.00' : (change / reference * 100).toStringAsFixed(2)}%)',
                        style: TextStyle(
                          color: positive ? rise : fall,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'in loaded history',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: _controls,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(
                                market.live
                                    ? Icons.sensors
                                    : Icons.cloud_off_outlined,
                                size: 16,
                                color: market.live ? rise : colors.error,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                market.live
                                    ? 'Live'
                                    : '${market.connection} | Stale',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${market.tier[0].toUpperCase()}${market.tier.substring(1)} | ${market.rate} Hz',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '${market.latency.round()} ms',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!market.connected && !market.paused)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: market.reconnect,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reconnect now'),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Price',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: '1m', label: Text('1m')),
                          ButtonSegment(value: '5m', label: Text('5m')),
                        ],
                        selected: {market.interval},
                        onSelectionChanged: (v) =>
                            market.selectInterval(v.first),
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (market.loadingHistory && candles.isEmpty)
                    const SizedBox(
                      height: 320,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(height: 16),
                            Text('Loading market history...'),
                          ],
                        ),
                      ),
                    )
                  else
                    MarketChart(
                      key: ValueKey(market.interval),
                      candles: candles,
                      stale: !market.live,
                    ),
                  if (market.historyFailed)
                    TextButton.icon(
                      onPressed: market.retryHistory,
                      icon: const Icon(Icons.refresh),
                      label: const Text('History unavailable | Retry'),
                    ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final book = _book(context), trades = _trades(context);
                      if (constraints.maxWidth > 650) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: book),
                            const SizedBox(width: 32),
                            Expanded(child: trades),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          book,
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 20),
                          trades,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'A simulated market. No real orders or funds.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _book(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bids = market.book.top(true), asks = market.book.top(false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Order book',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              market.book.ready && market.connected
                  ? '10 levels'
                  : 'Stale | syncing',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _bookSide(context, bids, true)),
            const SizedBox(width: 16),
            Expanded(child: _bookSide(context, asks, false)),
          ],
        ),
        const SizedBox(height: 12),
        if (bids.isNotEmpty && asks.isNotEmpty)
          Center(
            child: Text(
              'Spread  \$${money(asks.first.key - bids.first.key)}',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  Widget _bookSide(
    BuildContext context,
    List<MapEntry<int, int>> entries,
    bool buy,
  ) {
    final color = buy ? rise : fall;
    final maxQty = entries.isEmpty
        ? 1
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          children: [
            Text(
              buy ? 'Bid (USD)' : 'Ask (USD)',
              style: TextStyle(color: color, fontSize: 11),
            ),
            const Text('BTC', style: TextStyle(fontSize: 11)),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < 10; i++)
          SizedBox(
            height: 29,
            child: Stack(
              children: [
                if (i < entries.length)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: entries[i].value / maxQty,
                      child: Container(
                        height: 27,
                        color: color.withValues(alpha: .09),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            i < entries.length ? money(entries[i].key) : '--',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        i < entries.length
                            ? (entries[i].value / 1000000).toStringAsFixed(4)
                            : '--',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _trades(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent trades',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              market.connected ? 'BTC / USD' : 'Cached',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Price (USD)',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: Text(
                'Amount (BTC)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: Text(
                'Time (UTC)',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (market.trades.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Waiting for the first trade...'),
          ),
        for (final t in market.trades.take(12))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${t.buy ? 'B' : 'S'} ${money(t.price)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: t.buy ? rise : fall,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    (t.quantity / 1000000).toStringAsFixed(6),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${clockTime(t.time)}:${DateTime.fromMillisecondsSinceEpoch(t.time, isUtc: true).second.toString().padLeft(2, '0')}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _controls() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: AnimatedBuilder(
          animation: market,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connection lab',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Explore how delivery adapts. Every trade still counts toward the candles.',
              ),
              const SizedBox(height: 24),
              Text(
                'Active: ${market.tier} | ${market.rate} chart updates / second',
              ),
              const SizedBox(height: 8),
              Text(
                'RTT ${market.latency.round()} ms   |   Jitter ${market.jitter.round()} ms',
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: market.forcedTier ?? 'auto',
                decoration: const InputDecoration(
                  labelText: 'Delivery mode',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('Automatic')),
                  DropdownMenuItem(
                    value: 'full',
                    child: Text('Force full | 10 Hz'),
                  ),
                  DropdownMenuItem(
                    value: 'degraded',
                    child: Text('Force degraded | 2 Hz'),
                  ),
                  DropdownMenuItem(
                    value: 'minimal',
                    child: Text('Force minimal | 0.5 Hz'),
                  ),
                ],
                onChanged: (v) => market.forceTier(v == 'auto' ? null : v),
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Simulate disconnection'),
                subtitle: const Text('Keep cached values visible as stale'),
                value: market.paused,
                onChanged: market.setPaused,
              ),
              const SizedBox(height: 8),
              Text(
                'Book recoveries: ${market.recoveries} | Invalid messages: ${market.malformed}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Received ${market.receivedHz.toStringAsFixed(1)} Hz over the last 5 seconds',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: market.connected ? market.simulateBookGap : null,
                icon: const Icon(Icons.sync_problem),
                label: const Text('Drop one book update'),
              ),
              if (market.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(market.error!),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  void _watchlist() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => SafeArea(
        child: Column(
          children: [
            const ListTile(
              title: Text(
                'Watchlist',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              subtitle: Text('Hold and drag to reorder'),
            ),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: watchlist.length,
                onReorder: (oldIndex, newIndex) => update(() {
                  if (newIndex > oldIndex) newIndex--;
                  watchlist.insert(newIndex, watchlist.removeAt(oldIndex));
                }),
                itemBuilder: (context, index) {
                  final name = watchlist[index], active = name == 'Bitcoin';
                  return ListTile(
                    key: ValueKey(name),
                    leading: Icon(
                      active ? Icons.currency_bitcoin : Icons.token_outlined,
                    ),
                    title: Text(name),
                    subtitle: Text(
                      active
                          ? 'BTC / USD | Simulated live market'
                          : 'Not available in this simulation',
                    ),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                    onTap: active ? () => Navigator.pop(context) : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
