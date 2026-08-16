import 'dart:async';
import 'dart:math';

import 'package:ads_core/ads_core.dart';
import 'package:flutter/material.dart';

/// A fully self-contained fake provider, used only by this example app to
/// demonstrate `AdManager.switchProvider` without wiring a real mediation
/// SDK. Simulates network latency and occasional no-fill so the demo UI has
/// something realistic to react to. `ads_levelplay` and `ads_max` are real
/// wrappers over their SDKs — this is not a template for those.
final class DemoAdProvider implements AdProvider {
  DemoAdProvider(
    this.name, {
    this.color = Colors.indigo,
    double failureRate = 0.15,
    Duration loadDelay = const Duration(milliseconds: 500),
  })  : _failureRate = failureRate,
        _loadDelay = loadDelay;

  @override
  final String name;

  final Color color;
  final double _failureRate;
  final Duration _loadDelay;
  final _random = Random();

  final _events = StreamController<AdEvent>.broadcast();
  final _readyState = <AdFormat, bool>{};

  @override
  Future<void> init(AdConfig config) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  @override
  Future<void> updateConsent(AdConsent consent) async {}

  @override
  Future<void> dispose() async {
    await _events.close();
  }

  @override
  Future<void> preload(AdFormat format) async {
    await Future<void>.delayed(_loadDelay);
    if (_events.isClosed) return;

    final noFill = _random.nextDouble() < _failureRate;
    _readyState[format] = !noFill;
    if (noFill) {
      _events.add(AdEventFailed(
        format: format,
        providerName: name,
        error: AdError(
          code: 'no_fill',
          message: 'Simulated no fill',
          providerName: name,
        ),
      ));
    } else {
      _events.add(AdEventLoaded(format: format, providerName: name));
    }
  }

  @override
  Future<bool> isReady(AdFormat format) async => _readyState[format] ?? false;

  Future<AdShowResult> _show(AdFormat format, {String? placement}) async {
    if (_readyState[format] != true) {
      await preload(format);
    }
    if (_readyState[format] != true) {
      return AdShowResult.failed(AdError(
        code: 'not_ready',
        message: 'No ad loaded for ${format.name}',
        providerName: name,
      ));
    }

    _readyState[format] = false;
    _events.add(AdEventShown(format: format, providerName: name, placement: placement));

    if (_random.nextDouble() < 0.3) {
      _events.add(AdEventClicked(format: format, providerName: name, placement: placement));
    }

    _events.add(AdEventRevenuePaid(
      format: format,
      providerName: name,
      placement: placement,
      revenue: AdRevenue(
        value: 0.001 + _random.nextDouble() * 0.05,
        currencyCode: 'USD',
        networkName: '${name}_network',
        adUnitId: '${name}_${format.name}',
        precision: AdRevenuePrecision.estimated,
      ),
    ));

    var rewardEarned = false;
    if (format == AdFormat.rewarded) {
      rewardEarned = true;
      _events.add(AdEventRewardEarned(
        format: format,
        providerName: name,
        placement: placement,
        rewardType: 'coins',
        rewardAmount: 10,
      ));
    }

    _events.add(AdEventDismissed(format: format, providerName: name, placement: placement));
    unawaited(preload(format));

    return AdShowResult.shown(rewardEarned: rewardEarned);
  }

  @override
  Future<AdShowResult> showInterstitial({String? placement}) =>
      _show(AdFormat.interstitial, placement: placement);

  @override
  Future<AdShowResult> showRewarded({String? placement}) =>
      _show(AdFormat.rewarded, placement: placement);

  @override
  Future<AdShowResult> showAppOpen({String? placement}) =>
      _show(AdFormat.appOpen, placement: placement);

  @override
  Widget banner({required AdBannerSize size, String? placement}) => Container(
        height: switch (size) {
          AdBannerSize.banner => 50.0,
          AdBannerSize.largeBanner => 100.0,
          AdBannerSize.mediumRectangle => 250.0,
          AdBannerSize.adaptive => 60.0,
        },
        width: double.infinity,
        color: color.withValues(alpha: 0.2),
        alignment: Alignment.center,
        child: Text('$name banner (${size.name})', style: TextStyle(color: color)),
      );

  @override
  Stream<AdEvent> get events => _events.stream;
}
