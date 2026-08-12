import 'dart:async';

import 'package:flutter/widgets.dart';

import '../ad_provider.dart';
import '../types/ad_banner_size.dart';
import '../types/ad_config.dart';
import '../types/ad_event.dart';
import '../types/ad_format.dart';
import '../types/ad_show_result.dart';

/// A provider that shows nothing and never fails.
///
/// This is the safe-default provider: whenever remote config is missing,
/// malformed, or every real provider's health check has tripped,
/// [AdManager] lands here. "No ad" beats "wrong ad" or "crash".
final class NoopAdProvider implements AdProvider {
  final _events = StreamController<AdEvent>.broadcast();

  @override
  String get name => 'noop';

  @override
  Future<void> init(AdConfig config) async {}

  @override
  Future<void> dispose() async {
    await _events.close();
  }

  @override
  Future<void> preload(AdFormat format) async {}

  @override
  Future<bool> isReady(AdFormat format) async => false;

  @override
  Future<AdShowResult> showInterstitial({String? placement}) async =>
      AdShowResult.suppressed();

  @override
  Future<AdShowResult> showRewarded({String? placement}) async =>
      AdShowResult.suppressed();

  @override
  Future<AdShowResult> showAppOpen({String? placement}) async =>
      AdShowResult.suppressed();

  @override
  Widget banner({required AdBannerSize size, String? placement}) =>
      const SizedBox.shrink();

  @override
  Stream<AdEvent> get events => _events.stream;
}
