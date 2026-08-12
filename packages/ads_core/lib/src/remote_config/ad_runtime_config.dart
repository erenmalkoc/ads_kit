import '../types/ad_format.dart';

/// Parsed, typed form of the ads remote-config schema. Every field has a
/// safe default so a missing or malformed remote payload degrades to
/// [safeDefaults] instead of crashing boot.
final class AdRuntimeConfig {
  const AdRuntimeConfig({
    required this.activeProvider,
    required this.fallbackProvider,
    required this.formatsEnabled,
    required this.interstitialMinInterval,
    required this.interstitialMaxPerSession,
    required this.coldStartGrace,
    required this.disabledCountries,
    required this.healthFailureThreshold,
  });

  /// No remote config reachable, or it's unparseable: show nothing.
  /// "Reklam göstermemek, yanlış göstermekten iyidir."
  static const safeDefaults = AdRuntimeConfig(
    activeProvider: 'noop',
    fallbackProvider: 'noop',
    formatsEnabled: {},
    interstitialMinInterval: Duration(seconds: 60),
    interstitialMaxPerSession: 3,
    coldStartGrace: Duration(seconds: 30),
    disabledCountries: {},
    healthFailureThreshold: 3,
  );

  final String activeProvider;
  final String fallbackProvider;
  final Set<AdFormat> formatsEnabled;
  final Duration interstitialMinInterval;
  final int interstitialMaxPerSession;
  final Duration coldStartGrace;

  /// Uppercase ISO 3166-1 alpha-2 codes.
  final Set<String> disabledCountries;
  final int healthFailureThreshold;

  /// Parses a raw JSON map field-by-field: a missing or wrong-typed key
  /// falls back to [safeDefaults]'s value for just that field, rather than
  /// discarding the whole config. `null` or an empty map returns
  /// [safeDefaults] outright.
  factory AdRuntimeConfig.fromJson(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return safeDefaults;

    return AdRuntimeConfig(
      activeProvider:
          _readString(raw, 'active_provider') ?? safeDefaults.activeProvider,
      fallbackProvider: _readString(raw, 'fallback_provider') ??
          safeDefaults.fallbackProvider,
      formatsEnabled:
          _readFormats(raw['formats_enabled']) ?? safeDefaults.formatsEnabled,
      interstitialMinInterval:
          _readSeconds(raw['interstitial_min_interval_sec']) ??
              safeDefaults.interstitialMinInterval,
      interstitialMaxPerSession:
          _readInt(raw, 'interstitial_max_per_session') ??
              safeDefaults.interstitialMaxPerSession,
      coldStartGrace: _readSeconds(raw['cold_start_grace_sec']) ??
          safeDefaults.coldStartGrace,
      disabledCountries: _readCountries(raw['disabled_countries']) ??
          safeDefaults.disabledCountries,
      healthFailureThreshold: _readInt(raw, 'health_failure_threshold') ??
          safeDefaults.healthFailureThreshold,
    );
  }

  static String? _readString(Map<String, dynamic> raw, String key) {
    final value = raw[key];
    return (value is String && value.isNotEmpty) ? value : null;
  }

  static int? _readInt(Map<String, dynamic> raw, String key) {
    final value = raw[key];
    if (value is int) return value;
    if (value is double) return value.toInt();
    return null;
  }

  static Duration? _readSeconds(dynamic value) {
    if (value is int) return Duration(seconds: value);
    if (value is double) {
      return Duration(milliseconds: (value * 1000).round());
    }
    return null;
  }

  static Set<AdFormat>? _readFormats(dynamic value) {
    if (value is! List) return null;
    final formats = <AdFormat>{};
    for (final entry in value) {
      if (entry is String) {
        final format = AdFormat.tryParse(entry);
        if (format != null) formats.add(format);
      }
    }
    return formats;
  }

  static Set<String>? _readCountries(dynamic value) {
    if (value is! List) return null;
    final countries = <String>{};
    for (final entry in value) {
      if (entry is String && entry.isNotEmpty) {
        countries.add(entry.toUpperCase());
      }
    }
    return countries;
  }
}
