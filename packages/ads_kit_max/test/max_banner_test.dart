import 'package:ads_kit/ads_kit.dart';
import 'package:ads_kit_max/ads_kit_max.dart';
import 'package:applovin_max/applovin_max.dart' as max;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _sdkChannel = MethodChannel('applovin_max');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    // Stands in for the native plugin: the SDK is not initialized yet and
    // initializes with an empty configuration; every other call succeeds.
    messenger.setMockMethodCallHandler(_sdkChannel, (call) async {
      switch (call.method) {
        case 'isInitialized':
          return false;
        case 'initialize':
          return <String, Object?>{};
        default:
          return null;
      }
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(_sdkChannel, null));

  test('banner and MREC views carry the placement for MAX reporting', () async {
    final provider = MaxAdProvider();
    addTearDown(provider.dispose);
    await provider.init(
      const AdConfig(
        consent: AdConsent(),
        formatsEnabled: {AdFormat.banner},
        extras: {
          'sdk_key': 'test_sdk_key',
          'banner_ad_unit_id': 'banner_1',
          'mrec_ad_unit_id': 'mrec_1',
        },
      ),
    );

    for (final size in AdBannerSize.values) {
      expect(
        provider.banner(size: size, placement: 'home_screen'),
        isA<max.MaxAdView>().having(
          (view) => view.placement,
          'placement',
          'home_screen',
        ),
        reason: size.name,
      );
    }
  });
}
