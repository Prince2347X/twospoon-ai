import 'package:flutter/material.dart';
import 'network/transport.dart';
import 'state/market_controller.dart';
import 'ui/market_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TwoSpoonApp());
}

class TwoSpoonApp extends StatefulWidget {
  const TwoSpoonApp({super.key});
  @override
  State<TwoSpoonApp> createState() => _TwoSpoonAppState();
}

class _TwoSpoonAppState extends State<TwoSpoonApp> {
  late final MarketController market;
  @override
  void initState() {
    super.initState();
    market = MarketController(
      transportFactory: () => IoMarketTransport(
        const String.fromEnvironment(
          'API_URL',
          defaultValue: 'http://10.0.2.2:8000',
        ),
      ),
    )..start();
  }

  @override
  void dispose() {
    market.dispose();
    super.dispose();
  }

  ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF159B75),
      brightness: brightness,
      surface: dark ? const Color(0xFF101718) : const Color(0xFFFAFCFB),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .5),
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TwoSpoon',
    debugShowCheckedModeBanner: false,
    theme: theme(Brightness.light),
    darkTheme: theme(Brightness.dark),
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => MarketScreen(controller: market),
    ),
  );
}
