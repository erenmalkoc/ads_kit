import 'dart:async';

import 'package:ads_core/ads_core.dart';
import 'package:flutter/widgets.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart' as lp;

import 'level_play_listeners.dart';

/// Unity LevelPlay (ironSource) [AdProvider].
///
/// Ad unit IDs are supplied per format through [AdConfig.extras] rather
/// than hardcoded, since they're per-app/per-environment values, not part
/// of the abstraction contract:
/// - `extras['app_key']` (required)
/// - `extras['interstitial_ad_unit_id']`
/// - `extras['rewarded_ad_unit_id']`
/// - `extras['banner_ad_unit_id']`
///
/// A format with no corresponding ad unit id is simply never loaded —
/// `preload`/`isReady`/`show*` for it behave like "not configured", not an
/// error. LevelPlay does not support app-open ads; [showAppOpen] always
/// returns a failed result.
final class LevelPlayAdProvider implements AdProvider {
  final _events = StreamController<AdEvent>.broadcast();

  /// How long a `show*` call waits for the SDK's "displayed" callback
  /// before giving up. Once display is confirmed there is no timeout —
  /// the user controls how long the ad stays open.
  static const _displayTimeout = Duration(seconds: 15);

  lp.LevelPlayInterstitialAd? _interstitial;
  lp.LevelPlayRewardedAd? _rewarded;
  String? _bannerAdUnitId;

  Completer<AdShowResult>? _interstitialShow;
  Completer<AdShowResult>? _rewardedShow;
  bool _interstitialDisplayed = false;
  bool _rewardedDisplayed = false;

  @override
  String get name => 'levelplay';

  @override
  Future<void> init(AdConfig config) async {
    final appKey = config.extras['app_key'];
    if (appKey == null || appKey.isEmpty) {
      throw StateError(
        'LevelPlayAdProvider.init requires AdConfig.extras["app_key"]',
      );
    }

    // Consent must be set before init to take effect for the very first
    // ad request LevelPlay makes.
    await _applyConsent(config.consent);
    // ATT is requested by the app itself, never by this layer — LevelPlay
    // picks up IDFA availability from the OS once the app has asked.

    var initBuilder = lp.LevelPlayInitRequest.builder(appKey);
    final userId = config.extras['user_id'];
    if (userId != null && userId.isNotEmpty) {
      initBuilder = initBuilder.withUserId(userId);
      // Rewarded server-to-server callbacks report the *dynamic* user id in
      // their USER_ID macro — set both so S2S crediting reaches the right
      // account regardless of which one LevelPlay reads.
      await lp.LevelPlay.setDynamicUserId(userId);
    }

    final initCompleter = Completer<void>();
    await lp.LevelPlay.init(
      initRequest: initBuilder.build(),
      initListener: LevelPlayInitListenerAdapter(initCompleter),
    );
    await initCompleter.future;

    lp.LevelPlay.addImpressionDataListener(
      LevelPlayImpressionListenerAdapter(providerName: name, emit: _events.add),
    );

    if (config.formatsEnabled.contains(AdFormat.interstitial)) {
      final adUnitId = config.extras['interstitial_ad_unit_id'];
      if (adUnitId != null && adUnitId.isNotEmpty) {
        _interstitial = lp.LevelPlayInterstitialAd(adUnitId: adUnitId)
          ..setListener(LevelPlayInterstitialListenerAdapter(
            providerName: name,
            emit: _events.add,
            onDisplayStarted: () => _interstitialDisplayed = true,
            onShowCompleted: (result) {
              final completer = _interstitialShow;
              _interstitialShow = null;
              if (completer != null && !completer.isCompleted) {
                completer.complete(result);
              }
            },
          ));
      }
    }

    if (config.formatsEnabled.contains(AdFormat.rewarded)) {
      final adUnitId = config.extras['rewarded_ad_unit_id'];
      if (adUnitId != null && adUnitId.isNotEmpty) {
        _rewarded = lp.LevelPlayRewardedAd(adUnitId: adUnitId)
          ..setListener(LevelPlayRewardedListenerAdapter(
            providerName: name,
            emit: _events.add,
            onDisplayStarted: () => _rewardedDisplayed = true,
            onShowCompleted: (result) {
              final completer = _rewardedShow;
              _rewardedShow = null;
              if (completer != null && !completer.isCompleted) {
                completer.complete(result);
              }
            },
          ));
      }
    }

    if (config.formatsEnabled.contains(AdFormat.banner)) {
      final adUnitId = config.extras['banner_ad_unit_id'];
      if (adUnitId != null && adUnitId.isNotEmpty) _bannerAdUnitId = adUnitId;
    }
  }

  @override
  Future<void> updateConsent(AdConsent consent) => _applyConsent(consent);

  /// LevelPlay.setConsent is deprecated in favor of
  /// LevelPlayPrivacySettings.setGDPRConsents(Map<network, bool>) — but
  /// that API wants per-network consent, which AdConsent doesn't model
  /// (it's a single app-wide GDPR flag). Using the deprecated whole-SDK
  /// setter is the correct fit until ads_core grows per-network consent,
  /// which nothing in this monorepo needs yet.
  Future<void> _applyConsent(AdConsent consent) async {
    // ignore: deprecated_member_use
    await lp.LevelPlay.setConsent(consent.gdprConsent ?? false);
    await lp.LevelPlayPrivacySettings.setCCPA(consent.ccpaOptOut ?? true);
    await lp.LevelPlayPrivacySettings.setCOPPA(consent.isChildDirected);
  }

  @override
  Future<void> dispose() async {
    await _interstitial?.dispose();
    await _rewarded?.dispose();
    await _events.close();
  }

  @override
  Future<void> preload(AdFormat format) async {
    switch (format) {
      case AdFormat.interstitial:
        await _interstitial?.loadAd();
      case AdFormat.rewarded:
        await _rewarded?.loadAd();
      case AdFormat.banner:
        // LevelPlayBannerAdView loads itself once mounted in the widget
        // tree; there is no standalone preload for it.
        break;
      case AdFormat.appOpen:
      case AdFormat.native:
        break;
    }
  }

  @override
  Future<bool> isReady(AdFormat format) async {
    switch (format) {
      case AdFormat.interstitial:
        return await _interstitial?.isAdReady() ?? false;
      case AdFormat.rewarded:
        return await _rewarded?.isAdReady() ?? false;
      case AdFormat.banner:
      case AdFormat.appOpen:
      case AdFormat.native:
        return false;
    }
  }

  @override
  Future<AdShowResult> showInterstitial({String? placement}) async {
    final ad = _interstitial;
    if (ad == null) return _notConfigured(AdFormat.interstitial);
    if (!await ad.isAdReady()) return _notReady(AdFormat.interstitial);

    final completer = Completer<AdShowResult>();
    _interstitialShow = completer;
    _interstitialDisplayed = false;
    await ad.showAd(placementName: placement);
    _failUnlessDisplayed(
      format: AdFormat.interstitial,
      completer: completer,
      isDisplayed: () => _interstitialDisplayed,
    );
    return completer.future;
  }

  @override
  Future<AdShowResult> showRewarded({String? placement}) async {
    final ad = _rewarded;
    if (ad == null) return _notConfigured(AdFormat.rewarded);
    if (!await ad.isAdReady()) return _notReady(AdFormat.rewarded);

    final completer = Completer<AdShowResult>();
    _rewardedShow = completer;
    _rewardedDisplayed = false;
    await ad.showAd(placementName: placement);
    _failUnlessDisplayed(
      format: AdFormat.rewarded,
      completer: completer,
      isDisplayed: () => _rewardedDisplayed,
    );
    return completer.future;
  }

  /// Backstop for the SDK never confirming display after `showAd` — the
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
            '${_displayTimeout.inSeconds}s of showAd',
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

  @override
  Future<AdShowResult> showAppOpen({String? placement}) async =>
      AdShowResult.failed(AdError(
        code: 'unsupported_format',
        message: 'LevelPlay does not support app open ads',
        providerName: name,
      ));

  AdShowResult _notConfigured(AdFormat format) => AdShowResult.failed(AdError(
        code: 'not_configured',
        message: 'No ${format.name} ad unit configured for LevelPlay',
        providerName: name,
      ));

  AdShowResult _notReady(AdFormat format) => AdShowResult.failed(AdError(
        code: 'not_ready',
        message: '${format.name} ad not loaded',
        providerName: name,
      ));

  @override
  Widget banner({required AdBannerSize size, String? placement}) {
    final adUnitId = _bannerAdUnitId;
    if (adUnitId == null) return const SizedBox.shrink();
    return _LevelPlayBannerHost(
      adUnitId: adUnitId,
      size: size,
      placement: placement,
      providerName: name,
      emit: _events.add,
    );
  }

  @override
  Stream<AdEvent> get events => _events.stream;
}

/// `LevelPlayAdSize.createAdaptiveAdSize` is async, but [AdProvider.banner]
/// must return a [Widget] synchronously — this resolves the size first and
/// renders [lp.LevelPlayBannerAdView] once it's known, matching the
/// underlying platform view's actual behavior instead of faking sync
/// adaptive sizing.
final class _LevelPlayBannerHost extends StatefulWidget {
  const _LevelPlayBannerHost({
    required this.adUnitId,
    required this.size,
    required this.providerName,
    required this.emit,
    this.placement,
  });

  final String adUnitId;
  final AdBannerSize size;
  final String? placement;
  final String providerName;
  final void Function(AdEvent event) emit;

  @override
  State<_LevelPlayBannerHost> createState() => _LevelPlayBannerHostState();
}

class _LevelPlayBannerHostState extends State<_LevelPlayBannerHost> {
  late final Future<lp.LevelPlayAdSize> _adSize = _resolveAdSize(widget.size);

  static Future<lp.LevelPlayAdSize> _resolveAdSize(AdBannerSize size) async {
    switch (size) {
      case AdBannerSize.banner:
        return lp.LevelPlayAdSize.BANNER;
      case AdBannerSize.largeBanner:
        return lp.LevelPlayAdSize.LARGE;
      case AdBannerSize.mediumRectangle:
        return lp.LevelPlayAdSize.MEDIUM_RECTANGLE;
      case AdBannerSize.adaptive:
        return await lp.LevelPlayAdSize.createAdaptiveAdSize() ??
            lp.LevelPlayAdSize.BANNER;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<lp.LevelPlayAdSize>(
      future: _adSize,
      builder: (context, snapshot) {
        final adSize = snapshot.data;
        if (adSize == null) return const SizedBox.shrink();
        return lp.LevelPlayBannerAdView(
          key: GlobalKey<lp.LevelPlayBannerAdViewState>(),
          adUnitId: widget.adUnitId,
          adSize: adSize,
          placementName: widget.placement,
          listener: LevelPlayBannerListenerAdapter(
            providerName: widget.providerName,
            emit: widget.emit,
            placement: widget.placement,
          ),
        );
      },
    );
  }
}
