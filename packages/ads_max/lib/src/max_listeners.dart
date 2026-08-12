/// Builders for MAX's listener objects, translating every callback into an
/// [AdEvent] on [MaxAdProvider]'s stream. Every SDK type touched here is
/// unwrapped into ads_core types (or primitives passed to
/// [max_mappers.dart]'s pure functions) before it leaves this file.
library;

import 'package:ads_core/ads_core.dart';
import 'package:applovin_max/applovin_max.dart' as max;

import 'max_mappers.dart';

AdError _mapError(max.MaxError error, String providerName) => maxErrorToAdError(
      errorCodeName: error.code.name,
      message: error.message,
      providerName: providerName,
    );

AdRevenue _mapRevenue(max.MaxAd ad) => maxAdToAdRevenue(
      revenue: ad.revenue,
      networkName: ad.networkName,
      adUnitId: ad.adUnitId,
      revenuePrecision: ad.revenuePrecision,
    );

max.InterstitialListener buildInterstitialListener({
  required String providerName,
  required void Function(AdEvent event) emit,
  required void Function(AdShowResult result) onShowCompleted,
}) {
  return max.InterstitialListener(
    onAdLoadedCallback: (ad) => emit(AdEventLoaded(
      format: AdFormat.interstitial,
      providerName: providerName,
      placement: ad.placement,
    )),
    onAdLoadFailedCallback: (adUnitId, error) => emit(AdEventFailed(
      format: AdFormat.interstitial,
      providerName: providerName,
      error: _mapError(error, providerName),
    )),
    onAdDisplayedCallback: (ad) {
      emit(AdEventShown(
        format: AdFormat.interstitial,
        providerName: providerName,
        placement: ad.placement,
      ));
      onShowCompleted(AdShowResult.shown());
    },
    onAdDisplayFailedCallback: (ad, error) {
      final adError = _mapError(error, providerName);
      emit(AdEventFailed(
        format: AdFormat.interstitial,
        providerName: providerName,
        placement: ad.placement,
        error: adError,
      ));
      onShowCompleted(AdShowResult.failed(adError));
    },
    onAdClickedCallback: (ad) => emit(AdEventClicked(
      format: AdFormat.interstitial,
      providerName: providerName,
      placement: ad.placement,
    )),
    onAdHiddenCallback: (ad) => emit(AdEventDismissed(
      format: AdFormat.interstitial,
      providerName: providerName,
      placement: ad.placement,
    )),
    onAdRevenuePaidCallback: (ad) => emit(AdEventRevenuePaid(
      format: AdFormat.interstitial,
      providerName: providerName,
      placement: ad.placement,
      revenue: _mapRevenue(ad),
    )),
  );
}

max.RewardedAdListener buildRewardedListener({
  required String providerName,
  required void Function(AdEvent event) emit,
  required void Function(AdShowResult result) onShowCompleted,
}) {
  var rewardEarnedThisShow = false;

  return max.RewardedAdListener(
    onAdLoadedCallback: (ad) => emit(AdEventLoaded(
      format: AdFormat.rewarded,
      providerName: providerName,
      placement: ad.placement,
    )),
    onAdLoadFailedCallback: (adUnitId, error) => emit(AdEventFailed(
      format: AdFormat.rewarded,
      providerName: providerName,
      error: _mapError(error, providerName),
    )),
    onAdDisplayedCallback: (ad) {
      rewardEarnedThisShow = false;
      emit(AdEventShown(
        format: AdFormat.rewarded,
        providerName: providerName,
        placement: ad.placement,
      ));
    },
    onAdDisplayFailedCallback: (ad, error) {
      final adError = _mapError(error, providerName);
      emit(AdEventFailed(
        format: AdFormat.rewarded,
        providerName: providerName,
        placement: ad.placement,
        error: adError,
      ));
      onShowCompleted(AdShowResult.failed(adError));
    },
    onAdClickedCallback: (ad) => emit(AdEventClicked(
      format: AdFormat.rewarded,
      providerName: providerName,
      placement: ad.placement,
    )),
    onAdHiddenCallback: (ad) {
      emit(AdEventDismissed(
        format: AdFormat.rewarded,
        providerName: providerName,
        placement: ad.placement,
      ));
      onShowCompleted(AdShowResult.shown(rewardEarned: rewardEarnedThisShow));
    },
    onAdRevenuePaidCallback: (ad) => emit(AdEventRevenuePaid(
      format: AdFormat.rewarded,
      providerName: providerName,
      placement: ad.placement,
      revenue: _mapRevenue(ad),
    )),
    onAdReceivedRewardCallback: (ad, reward) {
      rewardEarnedThisShow = true;
      emit(maxRewardToAdEvent(
        format: AdFormat.rewarded,
        providerName: providerName,
        rewardLabel: reward.label,
        rewardAmount: reward.amount,
        placement: ad.placement,
      ));
    },
  );
}

max.AppOpenAdListener buildAppOpenListener({
  required String providerName,
  required void Function(AdEvent event) emit,
  required void Function(AdShowResult result) onShowCompleted,
}) {
  return max.AppOpenAdListener(
    onAdLoadedCallback: (ad) => emit(AdEventLoaded(
      format: AdFormat.appOpen,
      providerName: providerName,
      placement: ad.placement,
    )),
    onAdLoadFailedCallback: (adUnitId, error) => emit(AdEventFailed(
      format: AdFormat.appOpen,
      providerName: providerName,
      error: _mapError(error, providerName),
    )),
    onAdDisplayedCallback: (ad) {
      emit(AdEventShown(
        format: AdFormat.appOpen,
        providerName: providerName,
        placement: ad.placement,
      ));
      onShowCompleted(AdShowResult.shown());
    },
    onAdDisplayFailedCallback: (ad, error) {
      final adError = _mapError(error, providerName);
      emit(AdEventFailed(
        format: AdFormat.appOpen,
        providerName: providerName,
        placement: ad.placement,
        error: adError,
      ));
      onShowCompleted(AdShowResult.failed(adError));
    },
    onAdClickedCallback: (ad) => emit(AdEventClicked(
      format: AdFormat.appOpen,
      providerName: providerName,
      placement: ad.placement,
    )),
    onAdHiddenCallback: (ad) => emit(AdEventDismissed(
      format: AdFormat.appOpen,
      providerName: providerName,
      placement: ad.placement,
    )),
    onAdRevenuePaidCallback: (ad) => emit(AdEventRevenuePaid(
      format: AdFormat.appOpen,
      providerName: providerName,
      placement: ad.placement,
      revenue: _mapRevenue(ad),
    )),
  );
}

/// Banner/MREC widgets use `AdViewAdListener`, a narrower shape than the
/// fullscreen formats above — MAX doesn't report a display/hidden event
/// for ad-view widgets, only load, click, expand/collapse, and revenue.
/// [AdEventShown]/[AdEventDismissed] have no MAX signal to map from for
/// this format, so we don't emit them here — [AdEventLoaded] is the
/// closest equivalent to "on screen" for a banner.
max.AdViewAdListener buildAdViewListener({
  required AdFormat format,
  required String providerName,
  required void Function(AdEvent event) emit,
  String? placement,
}) {
  return max.AdViewAdListener(
    onAdLoadedCallback: (ad) => emit(AdEventLoaded(
      format: format,
      providerName: providerName,
      placement: placement,
    )),
    onAdLoadFailedCallback: (adUnitId, error) => emit(AdEventFailed(
      format: format,
      providerName: providerName,
      placement: placement,
      error: _mapError(error, providerName),
    )),
    onAdClickedCallback: (ad) => emit(AdEventClicked(
      format: format,
      providerName: providerName,
      placement: placement,
    )),
    onAdExpandedCallback: (ad) {},
    onAdCollapsedCallback: (ad) {},
    onAdRevenuePaidCallback: (ad) => emit(AdEventRevenuePaid(
      format: format,
      providerName: providerName,
      placement: placement,
      revenue: _mapRevenue(ad),
    )),
  );
}
