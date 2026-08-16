/// All LevelPlay -> ads_kit type translation lives here as pure functions
/// over primitives (not the SDK's model types) — that keeps this file the
/// single place reviewers check for "no SDK type leaks past this package",
/// and lets tests exercise every mapping without constructing real SDK
/// objects.
library;

import 'package:ads_kit/ads_kit.dart';

/// LevelPlay's `precision` string on impression data isn't a published
/// enum in the Dart plugin — these four values are the documented
/// convention. Anything else (including `null` or empty-string, e.g. in
/// test-suite mode) maps to [AdRevenuePrecision.unknown] rather than
/// guessing.
AdRevenuePrecision mapLevelPlayPrecision(String? precision) {
  switch (precision) {
    case 'exact':
      return AdRevenuePrecision.exact;
    case 'estimated':
      return AdRevenuePrecision.estimated;
    case 'publisher_defined':
      return AdRevenuePrecision.publisherDefined;
    default:
      return AdRevenuePrecision.unknown;
  }
}

/// ironSource/LevelPlay revenue is always reported in USD by SDK
/// convention — there is no currency field on the impression data payload.
AdRevenue levelPlayImpressionToAdRevenue({
  required double? revenue,
  required String? networkName,
  required String? adUnitId,
  required String? precision,
}) =>
    AdRevenue(
      value: revenue ?? 0,
      currencyCode: 'USD',
      networkName: networkName ?? 'unknown',
      adUnitId: adUnitId ?? '',
      precision: mapLevelPlayPrecision(precision),
    );

/// LevelPlay's Dart plugin does not publish a stable error-code -> reason
/// enum (unlike AppLovin MAX's `ErrorCode`), so [AdError.code] here is a
/// deliberately opaque `levelplay_<code>` bucket rather than a guessed
/// mapping to values like "no_fill" — do not branch application logic on
/// it beyond logging.
AdError levelPlayErrorToAdError({
  required int errorCode,
  required String errorMessage,
  required String providerName,
}) =>
    AdError(
      code: 'levelplay_$errorCode',
      message: errorMessage,
      providerName: providerName,
      // 509 is ironSource's documented "no ads to show"; the message match
      // is a defensive net since the int codes aren't a published enum
      // (observed live: 509 "Mediation No fill").
      isNoFill: errorCode == 509 ||
          errorMessage.toLowerCase().contains('no fill'),
    );

/// The global impression-data listener fires for every ad format at once,
/// and LevelPlay's Dart plugin exposes the format only as a free-text
/// string (`LevelPlayImpressionData.adFormat`), not its own `AdFormat`
/// enum — the exact casing/values aren't documented, so this matches
/// defensively by substring rather than an exact set. Returns `null` when
/// nothing matches, which the provider treats as "drop this impression"
/// rather than guess — misattributing revenue to the wrong format would be
/// worse than dropping the one data point.
AdFormat? mapLevelPlayImpressionFormat(String? raw) {
  if (raw == null) return null;
  final normalized = raw.toLowerCase();
  if (normalized.contains('banner')) return AdFormat.banner;
  if (normalized.contains('interstitial')) return AdFormat.interstitial;
  if (normalized.contains('reward')) return AdFormat.rewarded;
  if (normalized.contains('native')) return AdFormat.native;
  return null;
}

AdEventRewardEarned levelPlayRewardToAdEvent({
  required AdFormat format,
  required String providerName,
  required String rewardName,
  required int rewardAmount,
  String? placement,
}) =>
    AdEventRewardEarned(
      format: format,
      providerName: providerName,
      placement: placement,
      rewardType: rewardName,
      rewardAmount: rewardAmount,
    );
