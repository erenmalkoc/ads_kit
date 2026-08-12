import 'package:ads_core/ads_core.dart';
import 'package:ads_kit_example/demo_ad_provider.dart';
import 'package:ads_kit_example/main.dart';
import 'package:ads_kit_example/static_ad_config_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _boot() async {
  // failureRate: 0 — deterministic for these tests. The real (randomized)
  // demo behavior is exercised interactively when running the app.
  AdManager.register('demo_a', () => DemoAdProvider('demo_a', failureRate: 0));
  AdManager.register('demo_b', () => DemoAdProvider('demo_b', failureRate: 0));
  await AdManager.boot(
    configSource: const StaticAdConfigSource({
      'active_provider': 'demo_a',
      'fallback_provider': 'noop',
      'formats_enabled': ['banner', 'interstitial', 'rewarded', 'appOpen'],
      'interstitial_min_interval_sec': 0,
      'interstitial_max_per_session': 5,
      'cold_start_grace_sec': 0,
      'disabled_countries': <String>[],
      'health_failure_threshold': 3,
    }),
  );
}

/// DemoAdProvider forwards events through two chained broadcast streams
/// (delegate -> AdManager's managed wrapper -> this app's listener) using
/// real `Future.delayed` timers. `WidgetTester`'s fake-time `pump()` only
/// reliably drains a single microtask hop per call, so a multi-hop
/// broadcast chain can outlast even many `pump()` calls. `runAsync` steps
/// out of fake time entirely for the tap and its fallout, exactly like a
/// real device would run it — then a couple of plain `pump()`s flush the
/// now-settled state into the widget tree.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await Future<void>.delayed(const Duration(seconds: 1));
  });
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() async {
    await AdManager.resetForTesting();
    await _boot();
  });

  tearDown(() async {
    await AdManager.resetForTesting();
  });

  testWidgets('shows the active provider and switches on tap', (tester) async {
    await tester.pumpWidget(const AdsKitExampleApp());
    await tester.pump();

    expect(find.text('Active provider: demo_a'), findsOneWidget);

    await _tap(tester, find.text('demo_b'));

    expect(find.text('Active provider: demo_b'), findsOneWidget);
  });

  testWidgets('preloading then showing an interstitial logs a shown event', (tester) async {
    await tester.pumpWidget(const AdsKitExampleApp());
    await tester.pump();

    await _tap(tester, find.widgetWithText(OutlinedButton, 'Preload').first);
    await _tap(tester, find.widgetWithText(FilledButton, 'Show').first);

    expect(find.textContaining('shown: interstitial'), findsWidgets);
    expect(find.textContaining('revenue:'), findsWidgets);
  });

  testWidgets('showing a rewarded ad logs a reward-earned event', (tester) async {
    await tester.pumpWidget(const AdsKitExampleApp());
    await tester.pump();

    await _tap(tester, find.widgetWithText(OutlinedButton, 'Preload').at(1));
    await _tap(tester, find.widgetWithText(FilledButton, 'Show').at(1));

    expect(find.textContaining('reward earned'), findsWidgets);
  });

  testWidgets('toggling the banner renders the active provider banner widget', (tester) async {
    await tester.pumpWidget(const AdsKitExampleApp());
    await tester.pump();

    expect(find.textContaining('demo_a banner'), findsNothing);

    final bannerToggle = find.text('Show banner');
    await tester.ensureVisible(bannerToggle);
    await tester.pump();
    await _tap(tester, bannerToggle);

    expect(find.textContaining('demo_a banner'), findsOneWidget);
  });
}
