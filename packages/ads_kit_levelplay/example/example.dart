// Unity LevelPlay behind ads_kit: register the provider once, supply its
// keys, then show ads through AdManager.I — app code never touches the
// LevelPlay SDK directly.
import 'package:ads_kit/ads_kit.dart';
import 'package:ads_kit_levelplay/ads_kit_levelplay.dart';
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

  AdManager.register('levelplay', () => LevelPlayAdProvider());

  await AdManager.boot(
    configSource: const InlineAdConfigSource({
      'active_provider': 'levelplay',
      'fallback_provider': 'noop',
      'formats_enabled': ['rewarded', 'banner'],
    }),
    consent: const AdConsent(gdprConsent: true),
    // Placeholders: use your own LevelPlay app keys and ad unit ids.
    // `_android`/`_ios` suffixes resolve to the running platform, and the
    // remote config's `providers.levelplay` block can override any of them.
    providerExtras: {
      'levelplay': {
        'app_key_android': 'YOUR_ANDROID_APP_KEY',
        'app_key_ios': 'YOUR_IOS_APP_KEY',
        'rewarded_ad_unit_id_android': 'YOUR_ANDROID_REWARDED_AD_UNIT_ID',
        'rewarded_ad_unit_id_ios': 'YOUR_IOS_REWARDED_AD_UNIT_ID',
        'banner_ad_unit_id_android': 'YOUR_ANDROID_BANNER_AD_UNIT_ID',
        'banner_ad_unit_id_ios': 'YOUR_IOS_BANNER_AD_UNIT_ID',
      },
    },
  );

  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('ads_kit_levelplay')),
        body: Center(
          child: FilledButton(
            onPressed: () async {
              // Resolves once the ad is dismissed, so the reward can be
              // granted right here.
              final result = await AdManager.I.showRewarded(
                placement: 'extra_life',
              );
              if (result.rewardEarned) debugPrint('grant the extra life');
            },
            child: const Text('Watch an ad for an extra life'),
          ),
        ),
        // Loads once its platform view is created.
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
