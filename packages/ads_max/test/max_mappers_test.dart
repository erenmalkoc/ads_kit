import 'package:ads_core/ads_core.dart';
import 'package:ads_max/src/max_mappers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapMaxRevenuePrecision', () {
    test('maps every documented precision string', () {
      expect(mapMaxRevenuePrecision('exact'), AdRevenuePrecision.exact);
      expect(mapMaxRevenuePrecision('estimated'), AdRevenuePrecision.estimated);
      expect(
        mapMaxRevenuePrecision('publisher_defined'),
        AdRevenuePrecision.publisherDefined,
      );
    });

    test('undefined, empty, or null precision maps to unknown', () {
      expect(mapMaxRevenuePrecision('undefined'), AdRevenuePrecision.unknown);
      expect(mapMaxRevenuePrecision(''), AdRevenuePrecision.unknown);
      expect(mapMaxRevenuePrecision(null), AdRevenuePrecision.unknown);
    });
  });

  group('maxAdToAdRevenue', () {
    test('maps every field and hardcodes USD', () {
      final revenue = maxAdToAdRevenue(
        revenue: 0.045,
        networkName: 'AdColony',
        adUnitId: 'unit-42',
        revenuePrecision: 'exact',
      );

      expect(revenue.value, 0.045);
      expect(revenue.currencyCode, 'USD');
      expect(revenue.networkName, 'AdColony');
      expect(revenue.adUnitId, 'unit-42');
      expect(revenue.precision, AdRevenuePrecision.exact);
    });
  });

  group('maxErrorToAdError', () {
    test('namespaces the ErrorCode enum name rather than inventing a bucket', () {
      final error = maxErrorToAdError(
        errorCodeName: 'noFill',
        message: 'No ad fill',
        providerName: 'max',
      );

      expect(error.code, 'max_noFill');
      expect(error.message, 'No ad fill');
      expect(error.providerName, 'max');
      expect(error.isNoFill, isTrue);
    });

    test('non-noFill codes stay unflagged', () {
      final error = maxErrorToAdError(
        errorCodeName: 'networkError',
        message: 'timeout',
        providerName: 'max',
      );
      expect(error.isNoFill, isFalse);
    });
  });

  group('maxRewardToAdEvent', () {
    test('carries reward label and amount through', () {
      final event = maxRewardToAdEvent(
        format: AdFormat.rewarded,
        providerName: 'max',
        rewardLabel: 'coins',
        rewardAmount: 25,
        placement: 'shop_screen',
      );

      expect(event.rewardType, 'coins');
      expect(event.rewardAmount, 25);
      expect(event.placement, 'shop_screen');
      expect(event.providerName, 'max');
    });
  });
}
