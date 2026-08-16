import 'dart:async';

import 'package:ads_kit/ads_kit.dart';
import 'package:applovin_max/applovin_max.dart' as max;
import 'package:flutter/widgets.dart';

import 'max_listeners.dart';

/// AppLovin MAX [AdProvider].
///
/// Ad unit IDs are supplied per format through [AdConfig.extras] rather
/// than hardcoded, since they're per-app/per-environment values, not part
/// of the abstraction contract:
/// - `extras['sdk_key']` (required)
/// - `extras['interstitial_ad_unit_id']`
/// - `extras['rewarded_ad_unit_id']`
/// - `extras['app_open_ad_unit_id']`
/// - `extras['banner_ad_unit_id']` (used for [AdBannerSize.banner],
///   [AdBannerSize.largeBanner] and [AdBannerSize.adaptive] — MAX serves
///   all three from the same "banner" ad unit type)
/// - `extras['mrec_ad_unit_id']` (used for [AdBannerSize.mediumRectangle]
///   — a distinct MAX ad unit type)
///
/// A format with no corresponding ad unit id is simply never loaded —
/// `preload`/`isReady`/`show*` for it behave like "not configured", not an
/// error.
final class MaxAdProvider implements AdProvider {
  final _events = StreamController<AdEvent>.broadcast();

  String? _interstitialAdUnitId;
  String? _rewardedAdUnitId;
  String? _appOpenAdUnitId;
  String? _bannerAdUnitId;
  String? _mrecAdUnitId;

  /// How long a `show*` call waits for the SDK's "displayed" callback
  /// before giving up. Once display is confirmed there is no timeout —
  /// the user controls how long the ad stays open.
  static const _displayTimeout = Duration(seconds: 15);

  /// How long [init] waits for the SDK to finish initializing — an SDK
  /// that never calls back would otherwise hang AdManager mid-activation
  /// instead of falling back.
  static const _initTimeout = Duration(seconds: 30);

  Completer<AdShowResult>? _interstitialShow;
  Completer<AdShowResult>? _rewardedShow;
  Completer<AdShowResult>? _appOpenShow;
  bool _interstitialDisplayed = false;
  bool _rewardedDisplayed = false;
  bool _appOpenDisplayed = false;

  @override
  String get name => 'max';

  @override
  Future<void> init(AdConfig config) async {
    final sdkKey = config.extras['sdk_key'];
    if (sdkKey == null || sdkKey.isEmpty) {
      throw StateError('MaxAdProvider.init requires AdConfig.extras["sdk_key"]');
    }

    // Consent must be set before initialize() to take effect for the very
    // first ad request MAX makes. Throws for a child-directed user before
    // the SDK is ever touched — AdManager treats that init() failure as
    // "this provider is unavailable" and falls back through
    // fallback_provider -> NoopAdProvider.
    await _applyConsent(config.consent);
    // ATT is requested by the app itself, never by this layer — MAX picks
    // up IDFA availability from the OS once the app has asked.

    final configuration =
        await max.AppLovinMAX.initialize(sdkKey).timeout(_initTimeout);
    if (configuration == null) {
      throw StateError('MaxAdProvider.init: AppLovinMAX.initialize returned null');
    }

    _interstitialAdUnitId = config.formatsEnabled.contains(AdFormat.interstitial)
        ? config.extras['interstitial_ad_unit_id']
        : null;
    _rewardedAdUnitId = config.formatsEnabled.contains(AdFormat.rewarded)
        ? config.extras['rewarded_ad_unit_id']
        : null;
    _appOpenAdUnitId = config.formatsEnabled.contains(AdFormat.appOpen)
        ? config.extras['app_open_ad_unit_id']
        : null;
    _bannerAdUnitId = config.formatsEnabled.contains(AdFormat.banner)
        ? config.extras['banner_ad_unit_id']
        : null;
    _mrecAdUnitId = config.formatsEnabled.contains(AdFormat.banner)
        ? config.extras['mrec_ad_unit_id']
        : null;

    if (_interstitialAdUnitId != null) {
      max.AppLovinMAX.setInterstitialListener(buildInterstitialListener(
        providerName: name,
        emit: _events.add,
        onDisplayStarted: () => _interstitialDisplayed = true,
        onShowCompleted: (result) => _resolve(_interstitialShow, result),
      ));
    }
    if (_rewardedAdUnitId != null) {
      max.AppLovinMAX.setRewardedAdListener(buildRewardedListener(
        providerName: name,
        emit: _events.add,
        onDisplayStarted: () => _rewardedDisplayed = true,
        onShowCompleted: (result) => _resolve(_rewardedShow, result),
      ));
    }
    if (_appOpenAdUnitId != null) {
      max.AppLovinMAX.setAppOpenAdListener(buildAppOpenListener(
        providerName: name,
        emit: _events.add,
        onDisplayStarted: () => _appOpenDisplayed = true,
        onShowCompleted: (result) => _resolve(_appOpenShow, result),
      ));
    }
  }

  void _resolve(Completer<AdShowResult>? completer, AdShowResult result) {
    if (completer != null && !completer.isCompleted) completer.complete(result);
  }

  @override
  Future<void> updateConsent(AdConsent consent) => _applyConsent(consent);

  /// AppLovin's policy is that the SDK must not be used at all for a user
  /// classified as a child — there's no "child mode" flag to set
  /// (setIsAgeRestrictedUser was removed in MAX SDK v4.0.0 for exactly
  /// this reason). Throwing is deliberate: AdManager treats it as "this
  /// provider is unavailable for this user" and switches away.
  Future<void> _applyConsent(AdConsent consent) async {
    if (consent.isChildDirected) {
      throw StateError(
        'MaxAdProvider refuses to serve a child-directed user — '
        'AppLovin MAX must not be used at all in that case.',
      );
    }
    max.AppLovinMAX.setHasUserConsent(consent.gdprConsent ?? false);
    max.AppLovinMAX.setDoNotSell(consent.ccpaOptOut ?? true);
  }

  @override
  Future<void> dispose() async {
    // The MAX SDK has no shutdown/de-init API — once initialized it stays
    // initialized for the process lifetime. We only tear down our own
    // stream; AdManager won't route further calls to this instance once
    // it has switched away.
    await _events.close();
  }

  @override
  Future<void> preload(AdFormat format) async {
    switch (format) {
      case AdFormat.interstitial:
        final id = _interstitialAdUnitId;
        if (id != null) max.AppLovinMAX.loadInterstitial(id);
      case AdFormat.rewarded:
        final id = _rewardedAdUnitId;
        if (id != null) max.AppLovinMAX.loadRewardedAd(id);
      case AdFormat.appOpen:
        final id = _appOpenAdUnitId;
        if (id != null) max.AppLovinMAX.loadAppOpenAd(id);
      case AdFormat.banner:
      case AdFormat.native:
        // MaxAdView loads itself once mounted in the widget tree; there
        // is no standalone preload for it.
        break;
    }
  }

  @override
  Future<bool> isReady(AdFormat format) async {
    switch (format) {
      case AdFormat.interstitial:
        final id = _interstitialAdUnitId;
        return id == null ? false : await max.AppLovinMAX.isInterstitialReady(id) ?? false;
      case AdFormat.rewarded:
        final id = _rewardedAdUnitId;
        return id == null ? false : await max.AppLovinMAX.isRewardedAdReady(id) ?? false;
      case AdFormat.appOpen:
        final id = _appOpenAdUnitId;
        return id == null ? false : await max.AppLovinMAX.isAppOpenAdReady(id) ?? false;
      case AdFormat.banner:
      case AdFormat.native:
        return false;
    }
  }

  @override
  Future<AdShowResult> showInterstitial({String? placement}) async {
    final id = _interstitialAdUnitId;
    if (id == null) return _notConfigured(AdFormat.interstitial);
    if (!(await max.AppLovinMAX.isInterstitialReady(id) ?? false)) {
      return _notReady(AdFormat.interstitial);
    }

    final completer = Completer<AdShowResult>();
    _interstitialShow = completer;
    _interstitialDisplayed = false;
    max.AppLovinMAX.showInterstitial(id, placement: placement);
    _failUnlessDisplayed(
      format: AdFormat.interstitial,
      completer: completer,
      isDisplayed: () => _interstitialDisplayed,
    );
    return completer.future;
  }

  @override
  Future<AdShowResult> showRewarded({String? placement}) async {
    final id = _rewardedAdUnitId;
    if (id == null) return _notConfigured(AdFormat.rewarded);
    if (!(await max.AppLovinMAX.isRewardedAdReady(id) ?? false)) {
      return _notReady(AdFormat.rewarded);
    }

    final completer = Completer<AdShowResult>();
    _rewardedShow = completer;
    _rewardedDisplayed = false;
    max.AppLovinMAX.showRewardedAd(id, placement: placement);
    _failUnlessDisplayed(
      format: AdFormat.rewarded,
      completer: completer,
      isDisplayed: () => _rewardedDisplayed,
    );
    return completer.future;
  }

  @override
  Future<AdShowResult> showAppOpen({String? placement}) async {
    final id = _appOpenAdUnitId;
    if (id == null) return _notConfigured(AdFormat.appOpen);
    if (!(await max.AppLovinMAX.isAppOpenAdReady(id) ?? false)) {
      return _notReady(AdFormat.appOpen);
    }

    final completer = Completer<AdShowResult>();
    _appOpenShow = completer;
    _appOpenDisplayed = false;
    max.AppLovinMAX.showAppOpenAd(id, placement: placement);
    _failUnlessDisplayed(
      format: AdFormat.appOpen,
      completer: completer,
      isDisplayed: () => _appOpenDisplayed,
    );
    return completer.future;
  }

  /// Backstop for the SDK never confirming display after a show call — the
  /// show future would otherwise hang forever. Emits [AdEventFailed] too so
  /// the health monitor counts it like any other show failure.
  void _failUnlessDisplayed({
    required AdFormat format,
    required Completer<AdShowResult> completer,
    required bool Function() isDisplayed,
  }) {
    Timer(_displayTimeout, () {
      if (completer.isCompleted || isDisplayed()) return;
      final error = AdError(
        code: 'display_timeout',
        message: 'no ${format.name} display callback within '
            '${_displayTimeout.inSeconds}s of show',
        providerName: name,
      );
      _events.add(AdEventFailed(
        format: format,
        providerName: name,
        error: error,
      ));
      completer.complete(AdShowResult.failed(error));
    });
  }

  AdShowResult _notConfigured(AdFormat format) => AdShowResult.failed(AdError(
        code: 'not_configured',
        message: 'No ${format.name} ad unit configured for MAX',
        providerName: name,
      ));

  AdShowResult _notReady(AdFormat format) => AdShowResult.failed(AdError(
        code: 'not_ready',
        message: '${format.name} ad not loaded',
        providerName: name,
      ));

  @override
  Widget banner({required AdBannerSize size, String? placement}) {
    final String? adUnitId;
    final max.AdFormat maxFormat;
    final bool isAdaptive;
    final double? heightOverride;

    switch (size) {
      case AdBannerSize.banner:
        adUnitId = _bannerAdUnitId;
        maxFormat = max.AdFormat.banner;
        isAdaptive = false;
        heightOverride = null;
      case AdBannerSize.largeBanner:
        // MAX's Dart API has no distinct "large banner" format — it
        // auto-picks a 728x90 "leader" size on tablets for AdFormat.banner
        // and 320x50 on phones. A fixed height override is the closest
        // approximation of a deliberately-320x90 "large" banner.
        adUnitId = _bannerAdUnitId;
        maxFormat = max.AdFormat.banner;
        isAdaptive = false;
        heightOverride = 90;
      case AdBannerSize.adaptive:
        adUnitId = _bannerAdUnitId;
        maxFormat = max.AdFormat.banner;
        isAdaptive = true;
        heightOverride = null;
      case AdBannerSize.mediumRectangle:
        adUnitId = _mrecAdUnitId;
        maxFormat = max.AdFormat.mrec;
        isAdaptive = false;
        heightOverride = null;
    }

    if (adUnitId == null) return const SizedBox.shrink();

    return max.MaxAdView(
      adUnitId: adUnitId,
      adFormat: maxFormat,
      isAdaptiveBannerEnabled: isAdaptive,
      height: heightOverride,
      listener: buildAdViewListener(
        format: AdFormat.banner,
        providerName: name,
        emit: _events.add,
        placement: placement,
      ),
    );
  }

  @override
  Stream<AdEvent> get events => _events.stream;
}
