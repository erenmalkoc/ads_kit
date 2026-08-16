import 'dart:async';

import 'package:ads_core/ads_core.dart';
import 'package:flutter/widgets.dart';

/// A controllable [AdProvider] test double — no real ad SDK involved.
class FakeAdProvider implements AdProvider {
  FakeAdProvider(this.name, {this.failInit = false, this.failUpdateConsent = false});

  @override
  final String name;

  /// When true, [init] throws instead of succeeding.
  final bool failInit;

  /// When true, [updateConsent] throws — like MAX refusing a
  /// child-directed user.
  final bool failUpdateConsent;

  bool initialized = false;
  bool disposed = false;
  int initCallCount = 0;

  /// The [AdConfig] the last [init] call received, for asserting what
  /// AdManager actually hands to a provider.
  AdConfig? lastInitConfig;

  /// The [AdConsent] the last [updateConsent] call received.
  AdConsent? lastUpdatedConsent;

  AdShowResult interstitialResult = AdShowResult.shown();
  AdShowResult rewardedResult = AdShowResult.shown();
  AdShowResult appOpenResult = AdShowResult.shown();
  bool ready = true;

  final _events = StreamController<AdEvent>.broadcast();

  @override
  Future<void> init(AdConfig config) async {
    initCallCount++;
    lastInitConfig = config;
    if (failInit) throw Exception('$name: init failed');
    initialized = true;
  }

  @override
  Future<void> updateConsent(AdConsent consent) async {
    if (failUpdateConsent) throw Exception('$name: cannot serve this consent');
    lastUpdatedConsent = consent;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _events.close();
  }

  @override
  Future<void> preload(AdFormat format) async {}

  @override
  Future<bool> isReady(AdFormat format) async => ready;

  @override
  Future<AdShowResult> showInterstitial({String? placement}) async =>
      interstitialResult;

  @override
  Future<AdShowResult> showRewarded({String? placement}) async =>
      rewardedResult;

  @override
  Future<AdShowResult> showAppOpen({String? placement}) async =>
      appOpenResult;

  @override
  Widget banner({required AdBannerSize size, String? placement}) =>
      const SizedBox.shrink();

  @override
  Stream<AdEvent> get events => _events.stream;

  /// Test hook: push an event as if the (fake) SDK emitted it.
  void emit(AdEvent event) => _events.add(event);
}

/// An [AdConfigSource] test double that returns a fixed map (or `null`)
/// without touching Firebase.
class FakeAdConfigSource implements AdConfigSource {
  FakeAdConfigSource(this.raw);

  final Map<String, dynamic>? raw;

  @override
  Future<Map<String, dynamic>?> fetchRawConfig() async => raw;
}
