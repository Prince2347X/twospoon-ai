import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twospoon/state/market_controller.dart';
import 'package:twospoon/ui/market_screen.dart';
import 'package:twospoon/ui/chart.dart';
import 'controller_test.dart' show FakeTransport;

void main() {
  for (final width in [320.0, 430.0, 900.0]) {
    testWidgets('market screen fits width $width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = MarketController(transportFactory: FakeTransport.new);
      controller.series.merge(
        List.generate(
          30,
          (i) => {
            'time': i * 60000,
            'open': 6740000 + i * 100,
            'high': 6741000 + i * 100,
            'low': 6739000 + i * 100,
            'close': 6740500 + i * 100,
            'volume': 100,
            'revision': i,
          },
        ),
      );
      controller.book.install({
        'epoch': 'a',
        'sequence': 1,
        'bids': List.generate(10, (i) => [6740000 - i * 100, 123456]),
        'asks': List.generate(10, (i) => [6740100 + i * 100, 654321]),
      });
      controller.loadingHistory = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1000),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: MarketScreen(controller: controller),
          ),
        ),
      );
      expect(find.text('Bitcoin'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).first, const Offset(0, -650));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
  testWidgets('chart touch exposes inspecting candle and live reset', (
    tester,
  ) async {
    final controller = MarketController(transportFactory: FakeTransport.new);
    controller.series.merge([
      {
        'time': 0,
        'open': 100,
        'high': 120,
        'low': 90,
        'close': 110,
        'volume': 10,
        'revision': 1,
      },
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketChart(candles: controller.series.values, stale: false),
        ),
      ),
    );
    await tester.tap(find.byType(CustomPaint).last);
    await tester.pump();
    expect(find.textContaining('Inspecting'), findsOneWidget);
    await tester.tap(find.text('Live'));
    await tester.pump();
    expect(find.textContaining('Latest candle'), findsOneWidget);
    controller.dispose();
  });
}
