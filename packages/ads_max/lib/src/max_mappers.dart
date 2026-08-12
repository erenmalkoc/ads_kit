/// All MAX -> ads_core type translation lives here as pure functions over
/// primitives (not the SDK's model types) — that keeps this file the
/// single place reviewers check for "no SDK type leaks past this package",
/// and lets tests exercise every mapping without constructing real SDK
/// objects.
library;

import 'package:ads_core/ads_core.dart';

/// MAX's `revenuePrecision` string is documented with exactly these
/// values (including empty string in test mode) — anything else maps to
/// [AdRevenuePrecision.unknown] rather than guessing.
AdRevenuePrecision mapMaxRevenuePrecision(String? precision) {
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

/// MAX revenue is USD by SDK convention — `MaxAd.revenue` has no
/// accompanying currency field.
AdRevenue maxAdToAdRevenue({
  required double revenue,
  required String networkName,
  required String adUnitId,
  required String revenuePrecision,
}) =>
    AdRevenue(
      value: revenue,
      currencyCode: 'USD',
      networkName: networkName,
      adUnitId: adUnitId,
      precision: mapMaxRevenuePrecision(revenuePrecision),
    );

/// `MaxError.code` is a real Dart enum (`ErrorCode`) unlike LevelPlay's
/// bare int, so we namespace its `.name` rather than invent our own
/// bucket — pass the enum's name in, not the enum itself, so this stays a
/// primitive-only function.
AdError maxErrorToAdError({
  required String errorCodeName,
  required String message,
  required String providerName,
}) =>
    AdError(
      code: 'max_$errorCodeName',
      message: message,
      providerName: providerName,
    );

AdEventRewardEarned maxRewardToAdEvent({
  required AdFormat format,
  required String providerName,
  required String rewardLabel,
  required int rewardAmount,
  String? placement,
}) =>
    AdEventRewardEarned(
      format: format,
      providerName: providerName,
      placement: placement,
      rewardType: rewardLabel,
      rewardAmount: rewardAmount,
    );
