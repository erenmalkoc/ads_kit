/// Thin adapters translating LevelPlay's listener callbacks into
/// [AdEvent]s on [LevelPlayAdProvider]'s stream. Every SDK type touched
/// here is unwrapped into ads_kit types (or primitives passed to
/// [level_play_mappers.dart]'s pure functions) before it leaves this file.
library;

import 'dart:async';

import 'package:ads_kit/ads_kit.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart' as lp;

import 'level_play_mappers.dart';

final class LevelPlayInitListenerAdapter implements lp.LevelPlayInitListener {
  LevelPlayInitListenerAdapter(this._completer);

  final Completer<void> _completer;

  @override
  void onInitSuccess(lp.LevelPlayConfiguration configuration) {
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  void onInitFailed(lp.LevelPlayInitError error) {
    if (!_completer.isCompleted) {
      _completer.completeError(
        StateError(
          'LevelPlay init failed: ${error.errorMessage} (${error.errorCode})',
        ),
      );
    }
  }
}

final class LevelPlayInterstitialListenerAdapter
    implements lp.LevelPlayInterstitialAdListener {
  LevelPlayInterstitialListenerAdapter({
    required this.providerName,
    required this.emit,
    required this.onDisplayStarted,
    required this.onShowCompleted,
  });

  final String providerName;
  final void Function(AdEvent event) emit;

  /// Fired at the SDK's "displayed" callback so the provider can cancel
  /// its display timeout; the show future itself resolves at close via
  /// [onShowCompleted].
  final void Function() onDisplayStarted;
  final void Function(AdShowResult result) onShowCompleted;

  @override
  void onAdLoaded(lp.LevelPlayAdInfo adInfo) => emit(AdEventLoaded(
        format: AdFormat.interstitial,
        providerName: providerName,
        placement: adInfo.placementName,
      ));

  @override
  void onAdLoadFailed(lp.LevelPlayAdError error) => emit(AdEventFailed(
        format: AdFormat.interstitial,
        providerName: providerName,
        error: levelPlayErrorToAdError(
          errorCode: error.errorCode,
          errorMessage: error.errorMessage,
          providerName: providerName,
        ),
      ));

  @override
  void onAdInfoChanged(lp.LevelPlayAdInfo adInfo) {}

  @override
  void onAdDisplayed(lp.LevelPlayAdInfo adInfo) {
    onDisplayStarted();
    emit(AdEventShown(
      format: AdFormat.interstitial,
      providerName: providerName,
      placement: adInfo.placementName,
    ));
  }

  @override
  void onAdDisplayFailed(lp.LevelPlayAdError error, lp.LevelPlayAdInfo adInfo) {
    final adError = levelPlayErrorToAdError(
      errorCode: error.errorCode,
      errorMessage: error.errorMessage,
      providerName: providerName,
    );
    emit(AdEventFailed(
      format: AdFormat.interstitial,
      providerName: providerName,
      placement: adInfo.placementName,
      error: adError,
    ));
    onShowCompleted(AdShowResult.failed(adError));
  }

  @override
  void onAdClicked(lp.LevelPlayAdInfo adInfo) => emit(AdEventClicked(
        format: AdFormat.interstitial,
        providerName: providerName,
        placement: adInfo.placementName,
      ));

  @override
  void onAdClosed(lp.LevelPlayAdInfo adInfo) {
    emit(AdEventDismissed(
      format: AdFormat.interstitial,
      providerName: providerName,
      placement: adInfo.placementName,
    ));
    onShowCompleted(AdShowResult.shown());
  }
}

final class LevelPlayRewardedListenerAdapter
    implements lp.LevelPlayRewardedAdListener {
  LevelPlayRewardedListenerAdapter({
    required this.providerName,
    required this.emit,
    required this.onDisplayStarted,
    required this.onShowCompleted,
  });

  final String providerName;
  final void Function(AdEvent event) emit;

  /// Fired at the SDK's "displayed" callback so the provider can cancel
  /// its display timeout; the show future itself resolves at close via
  /// [onShowCompleted].
  final void Function() onDisplayStarted;
  final void Function(AdShowResult result) onShowCompleted;

  bool _rewardEarnedThisShow = false;

  @override
  void onAdLoaded(lp.LevelPlayAdInfo adInfo) => emit(AdEventLoaded(
        format: AdFormat.rewarded,
        providerName: providerName,
        placement: adInfo.placementName,
      ));

  @override
  void onAdLoadFailed(lp.LevelPlayAdError error) => emit(AdEventFailed(
        format: AdFormat.rewarded,
        providerName: providerName,
        error: levelPlayErrorToAdError(
          errorCode: error.errorCode,
          errorMessage: error.errorMessage,
          providerName: providerName,
        ),
      ));

  @override
  void onAdInfoChanged(lp.LevelPlayAdInfo adInfo) {}

  @override
  void onAdDisplayed(lp.LevelPlayAdInfo adInfo) {
    _rewardEarnedThisShow = false;
    onDisplayStarted();
    emit(AdEventShown(
      format: AdFormat.rewarded,
      providerName: providerName,
      placement: adInfo.placementName,
    ));
  }

  @override
  void onAdDisplayFailed(lp.LevelPlayAdError error, lp.LevelPlayAdInfo adInfo) {
    final adError = levelPlayErrorToAdError(
      errorCode: error.errorCode,
      errorMessage: error.errorMessage,
      providerName: providerName,
    );
    emit(AdEventFailed(
      format: AdFormat.rewarded,
      providerName: providerName,
      placement: adInfo.placementName,
      error: adError,
    ));
    onShowCompleted(AdShowResult.failed(adError));
  }

  @override
  void onAdClicked(lp.LevelPlayAdInfo adInfo) => emit(AdEventClicked(
        format: AdFormat.rewarded,
        providerName: providerName,
        placement: adInfo.placementName,
      ));

  @override
  void onAdClosed(lp.LevelPlayAdInfo adInfo) {
    emit(AdEventDismissed(
      format: AdFormat.rewarded,
      providerName: providerName,
      placement: adInfo.placementName,
    ));
    onShowCompleted(AdShowResult.shown(rewardEarned: _rewardEarnedThisShow));
  }

  @override
  void onAdRewarded(lp.LevelPlayReward reward, lp.LevelPlayAdInfo adInfo) {
    _rewardEarnedThisShow = true;
    emit(levelPlayRewardToAdEvent(
      format: AdFormat.rewarded,
      providerName: providerName,
      rewardName: reward.name,
      rewardAmount: reward.amount,
      placement: adInfo.placementName,
    ));
  }
}

final class LevelPlayBannerListenerAdapter
    implements lp.LevelPlayBannerAdViewListener {
  LevelPlayBannerListenerAdapter({
    required this.providerName,
    required this.emit,
    this.placement,
  });

  final String providerName;
  final void Function(AdEvent event) emit;
  final String? placement;

  @override
  void onAdLoaded(lp.LevelPlayAdInfo adInfo) => emit(AdEventLoaded(
        format: AdFormat.banner,
        providerName: providerName,
        placement: placement,
      ));

  @override
  void onAdLoadFailed(lp.LevelPlayAdError error) => emit(AdEventFailed(
        format: AdFormat.banner,
        providerName: providerName,
        placement: placement,
        error: levelPlayErrorToAdError(
          errorCode: error.errorCode,
          errorMessage: error.errorMessage,
          providerName: providerName,
        ),
      ));

  @override
  void onAdDisplayed(lp.LevelPlayAdInfo adInfo) => emit(AdEventShown(
        format: AdFormat.banner,
        providerName: providerName,
        placement: placement,
      ));

  @override
  void onAdDisplayFailed(lp.LevelPlayAdInfo adInfo, lp.LevelPlayAdError error) =>
      emit(AdEventFailed(
        format: AdFormat.banner,
        providerName: providerName,
        placement: placement,
        error: levelPlayErrorToAdError(
          errorCode: error.errorCode,
          errorMessage: error.errorMessage,
          providerName: providerName,
        ),
      ));

  @override
  void onAdClicked(lp.LevelPlayAdInfo adInfo) => emit(AdEventClicked(
        format: AdFormat.banner,
        providerName: providerName,
        placement: placement,
      ));

  @override
  void onAdExpanded(lp.LevelPlayAdInfo adInfo) {}

  @override
  void onAdCollapsed(lp.LevelPlayAdInfo adInfo) {}

  @override
  void onAdLeftApplication(lp.LevelPlayAdInfo adInfo) {}
}

final class LevelPlayImpressionListenerAdapter
    implements lp.LevelPlayImpressionDataListener {
  LevelPlayImpressionListenerAdapter({
    required this.providerName,
    required this.emit,
  });

  final String providerName;
  final void Function(AdEvent event) emit;

  @override
  void onImpressionSuccess(lp.LevelPlayImpressionData impressionData) {
    final format = mapLevelPlayImpressionFormat(impressionData.adFormat);
    if (format == null) return;

    emit(AdEventRevenuePaid(
      format: format,
      providerName: providerName,
      placement: impressionData.placement,
      revenue: levelPlayImpressionToAdRevenue(
        revenue: impressionData.revenue,
        networkName: impressionData.adNetwork,
        adUnitId: impressionData.mediationAdUnitId,
        precision: impressionData.precision,
      ),
    ));
  }
}
