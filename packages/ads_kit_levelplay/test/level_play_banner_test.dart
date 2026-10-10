import 'dart:async';

import 'package:ads_kit/ads_kit.dart';
import 'package:ads_kit_levelplay/ads_kit_levelplay.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart' as lp;

const _sdkChannel = MethodChannel('unity_levelplay_mediation');

/// Stands in for the native plugin: every SDK call succeeds, and `init` is
/// answered with the SDK's `onInitSuccess` callback like on a device.
void _mockSdkChannel(WidgetTester tester) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_sdkChannel, (call) async {
    if (call.method == 'init') {
      unawaited(
        messenger.handlePlatformMessage(
          _sdkChannel.name,
          _sdkChannel.codec.encodeMethodCall(
            const MethodCall('onInitSuccess', {'isAdQualityEnabled': false}),
          ),
          (_) {},
        ),
      );
    }
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_sdkChannel, null));
}

void main() {
  testWidgets(
    'banner keeps its platform view across parent rebuilds and loads it '
    'once the view is created',
    (tester) async {
      _mockSdkChannel(tester);

      final provider = LevelPlayAdProvider();
      addTearDown(provider.dispose);
      await provider.init(
        const AdConfig(
          consent: AdConsent(),
          formatsEnabled: {AdFormat.banner},
          extras: {'app_key': 'test_app_key', 'banner_ad_unit_id': 'banner_1'},
        ),
      );

      late StateSetter rebuildParent;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, setState) {
              rebuildParent = setState;
              return provider.banner(size: AdBannerSize.banner);
            },
          ),
        ),
      );
      await tester.pump(); // let the banner size resolve

      final bannerFinder = find.byType(lp.LevelPlayBannerAdView);
      expect(bannerFinder, findsOneWidget);
      final firstView = tester.widget<lp.LevelPlayBannerAdView>(bannerFinder);
      final viewState = tester.state<lp.LevelPlayBannerAdViewState>(
        bannerFinder,
      );

      rebuildParent(() {});
      await tester.pump();

      final rebuiltView = tester.widget<lp.LevelPlayBannerAdView>(bannerFinder);
      expect(rebuiltView, isNot(same(firstView)), reason: 'parent rebuilt');
      expect(
        rebuiltView.key,
        same(firstView.key),
        reason: 'a new key would tear down and recreate the platform view',
      );
      expect(tester.state(bannerFinder), same(viewState));

      // Do what the plugin does once the host OS has created the platform
      // view: wire the view's own channel, then fire onPlatformViewCreated.
      const viewChannel = MethodChannel('LevelPlayBannerAdView_0');
      final viewCalls = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(viewChannel, (call) async {
        viewCalls.add(call.method);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(viewChannel, null));
      viewState.channel = viewChannel;

      expect(
        rebuiltView.onPlatformViewCreated,
        isNotNull,
        reason: 'the native banner view never loads on its own',
      );
      rebuiltView.onPlatformViewCreated!();
      await tester.pump();

      expect(viewCalls, ['loadAd']);
    },
  );
}
