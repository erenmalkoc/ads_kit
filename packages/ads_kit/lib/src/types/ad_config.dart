import 'ad_consent.dart';
import 'ad_format.dart';

/// Everything an [AdProvider] needs to initialize itself, with zero
/// provider-specific types.
final class AdConfig {
  const AdConfig({
    required this.consent,
    required this.formatsEnabled,
    this.countryCode,
    this.extras = const {},
  });

  final AdConsent consent;

  /// Formats this provider is allowed to load/show, per remote config.
  final Set<AdFormat> formatsEnabled;

  /// ISO 3166-1 alpha-2 user country, if known. Providers may use this for
  /// their own regional logic; [FrequencyGuard]'s disabled-country check
  /// is independent of this and lives in ads_kit.
  final String? countryCode;

  /// Provider-specific passthrough (e.g. an app key the host app supplied
  /// to `AdManager.boot`). Keys are provider-defined; ads_kit never reads
  /// this map itself.
  final Map<String, String> extras;
}
