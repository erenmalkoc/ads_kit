import 'package:ads_core/ads_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdRuntimeConfig.fromJson', () {
    test('null config falls back to safe defaults', () {
      final config = AdRuntimeConfig.fromJson(null);
      expect(config.activeProvider, 'noop');
      expect(config.fallbackProvider, 'noop');
      expect(config.formatsEnabled, isEmpty);
    });

    test('empty map falls back to safe defaults', () {
      final config = AdRuntimeConfig.fromJson(const {});
      expect(config.activeProvider, AdRuntimeConfig.safeDefaults.activeProvider);
    });

    test('parses a fully valid schema', () {
      final config = AdRuntimeConfig.fromJson(const {
        'active_provider': 'levelplay',
        'fallback_provider': 'max',
        'formats_enabled': ['interstitial', 'rewarded', 'banner'],
        'interstitial_min_interval_sec': 45,
        'interstitial_max_per_session': 5,
        'cold_start_grace_sec': 20,
        'disabled_countries': ['tr', 'de'],
        'health_failure_threshold': 4,
      });

      expect(config.activeProvider, 'levelplay');
      expect(config.fallbackProvider, 'max');
      expect(
        config.formatsEnabled,
        {AdFormat.interstitial, AdFormat.rewarded, AdFormat.banner},
      );
      expect(config.interstitialMinInterval, const Duration(seconds: 45));
      expect(config.interstitialMaxPerSession, 5);
      expect(config.coldStartGrace, const Duration(seconds: 20));
      expect(config.disabledCountries, {'TR', 'DE'});
      expect(config.healthFailureThreshold, 4);
    });

    test('an unknown format string is dropped, not fatal', () {
      final config = AdRuntimeConfig.fromJson(const {
        'formats_enabled': ['interstitial', 'made_up_format'],
      });
      expect(config.formatsEnabled, {AdFormat.interstitial});
    });

    test('wrong-typed active_provider falls back to default for that field only', () {
      final config = AdRuntimeConfig.fromJson(const {
        'active_provider': 42,
        'fallback_provider': 'max',
      });
      expect(config.activeProvider, 'noop');
      expect(config.fallbackProvider, 'max');
    });

    test('wrong-typed numeric fields fall back to their defaults', () {
      final config = AdRuntimeConfig.fromJson(const {
        'interstitial_min_interval_sec': 'sixty',
        'health_failure_threshold': null,
      });
      expect(
        config.interstitialMinInterval,
        AdRuntimeConfig.safeDefaults.interstitialMinInterval,
      );
      expect(
        config.healthFailureThreshold,
        AdRuntimeConfig.safeDefaults.healthFailureThreshold,
      );
    });

    test('formats_enabled that is not a list falls back to default', () {
      final config = AdRuntimeConfig.fromJson(const {
        'formats_enabled': 'interstitial',
      });
      expect(config.formatsEnabled, isEmpty);
    });

    test('disabled_countries entries are uppercased', () {
      final config = AdRuntimeConfig.fromJson(const {
        'disabled_countries': ['us', 'Gb'],
      });
      expect(config.disabledCountries, {'US', 'GB'});
    });

    test('double values for integer/duration fields are coerced, not dropped', () {
      final config = AdRuntimeConfig.fromJson(const {
        'interstitial_max_per_session': 3.0,
        'cold_start_grace_sec': 30.0,
      });
      expect(config.interstitialMaxPerSession, 3);
      expect(config.coldStartGrace, const Duration(seconds: 30));
    });
  });
}
