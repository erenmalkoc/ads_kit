import 'dart:async';

import 'package:ads_core/ads_core.dart';
import 'package:flutter/material.dart';

import 'demo_ad_provider.dart';
import 'static_ad_config_source.dart';

const _providers = <String, Color>{
  'noop': Colors.grey,
  'demo_a': Colors.indigo,
  'demo_b': Colors.teal,
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AdManager.register('demo_a', () => DemoAdProvider('demo_a', color: Colors.indigo));
  AdManager.register(
    'demo_b',
    () => DemoAdProvider('demo_b', color: Colors.teal, failureRate: 0.35),
  );

  // A real app passes no `configSource` here and lets AdManager.boot read
  // Firebase Remote Config. This example has no Firebase project wired up,
  // so it supplies a fixed config instead — short intervals, so the demo
  // doesn't make you wait through production-sized cooldowns.
  await AdManager.boot(
    configSource: const StaticAdConfigSource({
      'active_provider': 'demo_a',
      'fallback_provider': 'noop',
      'formats_enabled': ['banner', 'interstitial', 'rewarded', 'appOpen'],
      'interstitial_min_interval_sec': 8,
      'interstitial_max_per_session': 5,
      'cold_start_grace_sec': 2,
      'disabled_countries': <String>[],
      'health_failure_threshold': 3,
    }),
    consent: const AdConsent(gdprConsent: true, attStatus: AttStatus.authorized),
  );

  runApp(const AdsKitExampleApp());
}

class AdsKitExampleApp extends StatelessWidget {
  const AdsKitExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ads_kit example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class _LogEntry {
  _LogEntry(this.text, this.color, this.time);
  final String text;
  final Color color;
  final DateTime time;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _activeProvider = AdManager.activeProviderName;
  bool _showBanner = false;
  final _log = <_LogEntry>[];
  final _readiness = <AdFormat, bool>{};

  StreamSubscription<AdEvent>? _eventSub;
  StreamSubscription<AdHealthEvent>? _healthSub;

  @override
  void initState() {
    super.initState();
    _eventSub = AdManager.I.events.listen(_onAdEvent);
    _healthSub = AdManager.healthEvents.listen(_onHealthEvent);
    unawaited(_refreshReadiness());
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _healthSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshReadiness() async {
    for (final format in [AdFormat.interstitial, AdFormat.rewarded, AdFormat.appOpen]) {
      final ready = await AdManager.I.isReady(format);
      if (!mounted) return;
      setState(() => _readiness[format] = ready);
    }
  }

  void _pushLog(String text, Color color) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, _LogEntry(text, color, DateTime.now()));
      if (_log.length > 100) _log.removeLast();
    });
  }

  void _onAdEvent(AdEvent event) {
    final (text, color) = switch (event) {
      AdEventLoaded() => ('loaded: ${event.format.name}', Colors.green),
      AdEventFailed() => ('failed: ${event.format.name} (${event.error.code})', Colors.red),
      AdEventShown() => ('shown: ${event.format.name}', Colors.blue),
      AdEventClicked() => ('clicked: ${event.format.name}', Colors.purple),
      AdEventDismissed() => ('dismissed: ${event.format.name}', Colors.blueGrey),
      AdEventRewardEarned() =>
        ('reward earned: ${event.rewardAmount} ${event.rewardType}', Colors.amber.shade800),
      AdEventRevenuePaid() => (
          'revenue: \$${event.revenue.value.toStringAsFixed(4)} '
              '(${event.revenue.networkName}, ${event.revenue.precision.name})',
          Colors.teal,
        ),
    };
    _pushLog('[${event.providerName}] $text', color);
    unawaited(_refreshReadiness());
  }

  void _onHealthEvent(AdHealthEvent event) {
    if (event case AdProviderSwitched(:final fromProvider, :final toProvider, :final reason)) {
      _pushLog(
        'provider switch: $fromProvider -> $toProvider (${reason.name})',
        Colors.deepOrange,
      );
      setState(() => _activeProvider = toProvider);
    }
  }

  Future<void> _switchTo(String key) async {
    await AdManager.switchProvider(key);
    setState(() => _activeProvider = AdManager.activeProviderName);
    unawaited(_refreshReadiness());
  }

  Future<void> _preload(AdFormat format) async {
    await AdManager.I.preload(format);
  }

  Future<void> _show(AdFormat format) async {
    final AdShowResult result = switch (format) {
      AdFormat.interstitial => await AdManager.I.showInterstitial(),
      AdFormat.rewarded => await AdManager.I.showRewarded(),
      AdFormat.appOpen => await AdManager.I.showAppOpen(),
      _ => throw ArgumentError('unsupported format for show(): $format'),
    };

    if (result.suppressed) {
      _pushLog('${format.name}: suppressed by policy (frequency/consent)', Colors.orange);
    } else if (result.error != null) {
      _pushLog('${format.name}: show failed (${result.error!.code})', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ads_kit example')),
      body: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Active provider: $_activeProvider',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: _providers.keys
                              .map((key) => ButtonSegment(value: key, label: Text(key)))
                              .toList(),
                          selected: {_activeProvider},
                          onSelectionChanged: (selection) => _switchTo(selection.first),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final format in [AdFormat.interstitial, AdFormat.rewarded, AdFormat.appOpen])
                          _FormatCard(
                            format: format,
                            ready: _readiness[format] ?? false,
                            onPreload: () => _preload(format),
                            onShow: () => _show(format),
                          ),
                        FilledButton.tonal(
                          onPressed: () => setState(() => _showBanner = !_showBanner),
                          child: Text(_showBanner ? 'Hide banner' : 'Show banner'),
                        ),
                      ],
                    ),
                  ),
                  if (_showBanner)
                    AdManager.I.banner(size: AdBannerSize.banner, placement: 'example_banner'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Event stream', style: Theme.of(context).textTheme.titleSmall),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _log.length,
              itemBuilder: (context, index) {
                final entry = _log[index];
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.circle, size: 10, color: entry.color),
                  title: Text(entry.text, style: TextStyle(color: entry.color)),
                  trailing: Text(
                    '${entry.time.hour.toString().padLeft(2, '0')}:'
                    '${entry.time.minute.toString().padLeft(2, '0')}:'
                    '${entry.time.second.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.format,
    required this.ready,
    required this.onPreload,
    required this.onShow,
  });

  final AdFormat format;
  final bool ready;
  final VoidCallback onPreload;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(format.name, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 6),
                Icon(
                  ready ? Icons.check_circle : Icons.circle_outlined,
                  size: 14,
                  color: ready ? Colors.green : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(onPressed: onPreload, child: const Text('Preload')),
                const SizedBox(width: 6),
                FilledButton(onPressed: onShow, child: const Text('Show')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
