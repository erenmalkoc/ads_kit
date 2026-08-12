import 'package:ads_core/ads_core.dart';
import 'package:ads_levelplay/src/level_play_mappers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapLevelPlayPrecision', () {
    test('maps every documented precision string', () {
      expect(mapLevelPlayPrecision('exact'), AdRevenuePrecision.exact);
      expect(mapLevelPlayPrecision('estimated'), AdRevenuePrecision.estimated);
      expect(
        mapLevelPlayPrecision('publisher_defined'),
        AdRevenuePrecision.publisherDefined,
      );
    });

    test('unknown, empty, or null precision maps to unknown rather than guessing', () {
      expect(mapLevelPlayPrecision(null), AdRevenuePrecision.unknown);
      expect(mapLevelPlayPrecision(''), AdRevenuePrecision.unknown);
      expect(mapLevelPlayPrecision('undisclosed'), AdRevenuePrecision.unknown);
    });
  });

  group('levelPlayImpressionToAdRevenue', () {
    test('maps a fully populated impression', () {
      final revenue = levelPlayImpressionToAdRevenue(
        revenue: 0.0123,
        networkName: 'admob_network',
        adUnitId: 'unit-1',
        precision: 'estimated',
      );

      expect(revenue.value, 0.0123);
      expect(revenue.currencyCode, 'USD');
      expect(revenue.networkName, 'admob_network');
      expect(revenue.adUnitId, 'unit-1');
      expect(revenue.precision, AdRevenuePrecision.estimated);
    });

    test('missing fields fall back to safe defaults, never null propagation', () {
      final revenue = levelPlayImpressionToAdRevenue(
        revenue: null,
        networkName: null,
        adUnitId: null,
        precision: null,
      );

      expect(revenue.value, 0);
      expect(revenue.networkName, 'unknown');
      expect(revenue.adUnitId, '');
      expect(revenue.precision, AdRevenuePrecision.unknown);
    });
  });

  group('levelPlayErrorToAdError', () {
    test('bucket-codes the numeric error and preserves the message and provider', () {
      final error = levelPlayErrorToAdError(
        errorCode: 509,
        errorMessage: 'no fill',
        providerName: 'levelplay',
      );

      expect(error.code, 'levelplay_509');
      expect(error.message, 'no fill');
      expect(error.providerName, 'levelplay');
    });
  });

  group('mapLevelPlayImpressionFormat', () {
    test('matches known formats case-insensitively', () {
      expect(mapLevelPlayImpressionFormat('interstitial'), AdFormat.interstitial);
      expect(mapLevelPlayImpressionFormat('INTERSTITIAL'), AdFormat.interstitial);
      expect(mapLevelPlayImpressionFormat('rewardedVideo'), AdFormat.rewarded);
      expect(mapLevelPlayImpressionFormat('REWARDED'), AdFormat.rewarded);
      expect(mapLevelPlayImpressionFormat('banner'), AdFormat.banner);
      expect(mapLevelPlayImpressionFormat('native_ad'), AdFormat.native);
    });

    test('unrecognized or null format is dropped, not guessed', () {
      expect(mapLevelPlayImpressionFormat(null), isNull);
      expect(mapLevelPlayImpressionFormat('unknown_thing'), isNull);
      expect(mapLevelPlayImpressionFormat(''), isNull);
    });
  });

  group('levelPlayRewardToAdEvent', () {
    test('carries reward name and amount through', () {
      final event = levelPlayRewardToAdEvent(
        format: AdFormat.rewarded,
        providerName: 'levelplay',
        rewardName: 'coins',
        rewardAmount: 10,
        placement: 'end_of_level',
      );

      expect(event.rewardType, 'coins');
      expect(event.rewardAmount, 10);
      expect(event.placement, 'end_of_level');
      expect(event.providerName, 'levelplay');
    });
  });
}
