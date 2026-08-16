import 'package:ads_kit/ads_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoopAdProvider', () {
    late NoopAdProvider provider;

    setUp(() => provider = NoopAdProvider());

    test('name is "noop"', () {
      expect(provider.name, 'noop');
    });

    test('init and dispose never throw', () async {
      await expectLater(
        provider.init(const AdConfig(consent: AdConsent(), formatsEnabled: {})),
        completes,
      );
      await expectLater(provider.dispose(), completes);
    });

    test('isReady is always false', () async {
      for (final format in AdFormat.values) {
        expect(await provider.isReady(format), isFalse);
      }
    });

    test('every show call is suppressed, not an error', () async {
      expect((await provider.showInterstitial()).suppressed, isTrue);
      expect((await provider.showRewarded()).suppressed, isTrue);
      expect((await provider.showAppOpen()).suppressed, isTrue);
    });

    test('banner is an empty SizedBox', () {
      expect(provider.banner(size: AdBannerSize.banner), isA<SizedBox>());
    });

    test('events stream never emits', () async {
      final received = <AdEvent>[];
      provider.events.listen(received.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(received, isEmpty);
    });
  });
}
