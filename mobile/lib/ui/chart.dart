import 'dart:math';
import 'package:flutter/material.dart';
import '../models/market.dart';

const rise = Color(0xFF159B75);
const fall = Color(0xFFD94B64);
String money(int cents) {
  final parts = (cents / 100).toStringAsFixed(2).split('.');
  return '${parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}.${parts[1]}';
}

String clockTime(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class MarketChart extends StatefulWidget {
  final List<Candle> candles;
  final bool stale;
  const MarketChart({super.key, required this.candles, required this.stale});
  @override
  State<MarketChart> createState() => _MarketChartState();
}

class _MarketChartState extends State<MarketChart> {
  int? selectedTime;
  @override
  Widget build(BuildContext context) {
    final candles = widget.candles.length > 48
        ? widget.candles.sublist(widget.candles.length - 48)
        : widget.candles;
    if (candles.isEmpty) {
      return const SizedBox(
        height: 280,
        child: Center(child: Text('No candles yet. Waiting for the market.')),
      );
    }
    final selected = candles.where((c) => c.time == selectedTime).firstOrNull;
    final c = selected ?? candles.last;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${clockTime(c.time)} UTC  ${selected == null ? ' / Latest candle' : ' / Inspecting'}',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
              ),
            ),
            if (selected != null)
              SizedBox(
                height: 36,
                child: TextButton(
                  onPressed: () => setState(() => selectedTime = null),
                  child: const Text('Live'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final pair in [
              ('O', c.open),
              ('H', c.high),
              ('L', c.low),
              ('C', c.close),
            ])
              Text(
                '${pair.$1} ${money(pair.$2)}',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            void inspect(double x) {
              final width = max(1.0, constraints.maxWidth - 66);
              final index = (x / width * candles.length).floor().clamp(
                0,
                candles.length - 1,
              );
              if (selectedTime != candles[index].time) {
                setState(() => selectedTime = candles[index].time);
              }
            }

            return Semantics(
              label:
                  'Candlestick chart. ${candles.length} candles. Latest open ${money(c.open)}, high ${money(c.high)}, low ${money(c.low)}, close ${money(c.close)}. Touch and drag to inspect.',
              child: GestureDetector(
                onTapDown: (d) => inspect(d.localPosition.dx),
                onHorizontalDragStart: (d) => inspect(d.localPosition.dx),
                onHorizontalDragUpdate: (d) => inspect(d.localPosition.dx),
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 245),
                    painter: CandlePainter(
                      candles,
                      selectedTime,
                      colors,
                      widget.stale,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text(
              clockTime(candles.first.time),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
            Text(
              'Drag to inspect | UTC',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 66),
              child: Text(
                clockTime(candles.last.time),
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class CandlePainter extends CustomPainter {
  final List<Candle> candles;
  final int? selected;
  final ColorScheme colors;
  final bool stale;
  CandlePainter(this.candles, this.selected, this.colors, this.stale);
  void label(
    Canvas canvas,
    String value,
    Offset offset,
    Color color, {
    double size = 10,
  }) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: color, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, offset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    final width = max(1.0, size.width - 66), height = size.height - 48;
    final low = candles.map((c) => c.low).reduce(min),
        high = candles.map((c) => c.high).reduce(max);
    final padding = max(100, (high - low) * .12);
    final floor = low - padding, ceiling = high + padding;
    double y(int price) => (ceiling - price) / (ceiling - floor) * height;
    final paint = Paint()..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final dy = height * i / 4;
      paint.color = colors.outlineVariant.withValues(alpha: .45);
      canvas.drawLine(Offset(0, dy), Offset(width, dy), paint);
      label(
        canvas,
        money((ceiling - (ceiling - floor) * i / 4).round()),
        Offset(width + 8, dy - 5),
        colors.onSurfaceVariant,
      );
    }
    final step = width / candles.length, body = max(2.0, min(10.0, step * .6));
    final maxVolume = candles.map((c) => c.volume).reduce(max);
    for (var i = 0; i < candles.length; i++) {
      final candle = candles[i], x = step * (i + .5);
      final color = candle.close >= candle.open ? rise : fall;
      paint.color = color.withValues(alpha: stale ? .4 : 1);
      canvas.drawLine(
        Offset(x, y(candle.high)),
        Offset(x, y(candle.low)),
        paint,
      );
      final top = min(y(candle.open), y(candle.close)),
          bottom = max(y(candle.open), y(candle.close));
      canvas.drawRect(
        Rect.fromLTWH(x - body / 2, top, body, max(1.5, bottom - top)),
        paint,
      );
      paint.color = color.withValues(alpha: .25);
      final volumeHeight = maxVolume == 0
          ? 0.0
          : 30 * candle.volume / maxVolume;
      canvas.drawRect(
        Rect.fromLTWH(
          x - body / 2,
          size.height - volumeHeight,
          body,
          volumeHeight,
        ),
        paint,
      );
      if (candle.time == selected) {
        paint.color = colors.onSurface.withValues(alpha: .55);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        canvas.drawCircle(Offset(x, y(candle.close)), 3, paint);
      }
    }
    final last = candles.last;
    paint.color = last.close >= last.open ? rise : fall;
    for (double x = 0; x < width; x += 7) {
      canvas.drawLine(
        Offset(x, y(last.close)),
        Offset(min(width, x + 3), y(last.close)),
        paint,
      );
    }
    label(
      canvas,
      'VOL',
      Offset(0, height + 12),
      colors.onSurfaceVariant,
      size: 9,
    );
  }

  @override
  bool shouldRepaint(CandlePainter oldDelegate) => true;
}
