// A minimal ads_kit integration: register providers, boot once, then show
// ads through AdManager.I without ever naming a mediation SDK.
//
// Real ads come from a provider package such as ads_kit_levelplay or
// ads_kit_max. The repository's example/ directory has a runnable demo app
// with two fake providers and a live event log.
import 'package:ads_kit/ads_kit.dart';
import 'package:flutter/material.dart';

/// Serves a fixed config so this example runs without a Firebase project.
/// A real app passes no `configSource` and lets [AdManager.boot] read the
/// `ads_config` Firebase Remote Config parameter instead.
final class InlineAdConfigSource implements AdConfigSource {
  const InlineAdConfigSource(this.config);

  final Map<String, dynamic> config;

  @override
  Future<Map<String, dynamic>?> fetchRawConfig() async => config;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register every provider package the app ships with, for example:
  // AdManager.register('levelplay', () => LevelPlayAdProvider());
  // AdManager.register('max', () => MaxAdProvider());

  // Never throws: an unknown provider or a failed init falls back to
  // `fallback_provider`, then to the built-in no-op provider (no ads).
  await AdManager.boot(
    configSource: const InlineAdConfigSource({
      'active_provider': 'levelplay',
      'fallback_provider': 'noop',
      'formats_enabled': ['interstitial', 'banner'],
      'interstitial_min_interval_sec': 60,
    }),
    consent: const AdConsent(gdprConsent: true),
  );

  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Ads by ${AdManager.activeProviderName}')),
        body: Center(
          child: FilledButton(
            onPressed: () async {
              // Resolves once the ad is dismissed, or right away when it is
              // suppressed by frequency capping or fails to show.
              final result = await AdManager.I.showInterstitial(
                placement: 'level_complete',
              );
              debugPrint('interstitial: $result');
            },
            child: const Text('Show interstitial'),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: AdManager.I.banner(
            size: AdBannerSize.banner,
            placement: 'home',
          ),
        ),
      ),
    );
  }
}
