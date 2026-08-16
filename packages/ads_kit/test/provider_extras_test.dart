import 'package:ads_kit/ads_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveProviderExtras', () {
    test('remote extras win over boot extras for the same key', () {
      final resolved = resolveProviderExtras(
        bootExtras: {'app_key': 'from_boot', 'kept': 'boot_only'},
        remoteExtras: {'app_key': 'from_remote'},
        platformSuffix: 'android',
      );

      expect(resolved, {'app_key': 'from_remote', 'kept': 'boot_only'});
    });

    test('a matching platform suffix overrides the unsuffixed base key', () {
      final resolved = resolveProviderExtras(
        bootExtras: {},
        remoteExtras: {'app_key': 'shared', 'app_key_ios': 'ios_specific'},
        platformSuffix: 'ios',
      );

      expect(resolved, {'app_key': 'ios_specific'});
    });

    test('suffixed keys for the other platform are dropped', () {
      final resolved = resolveProviderExtras(
        bootExtras: {'app_key_android': 'droid', 'app_key_ios': 'apple'},
        remoteExtras: {},
        platformSuffix: 'android',
      );

      expect(resolved, {'app_key': 'droid'});
    });

    test('an empty platform suffix drops every suffixed key', () {
      final resolved = resolveProviderExtras(
        bootExtras: {'app_key_android': 'droid', 'plain': 'v'},
        remoteExtras: {},
        platformSuffix: '',
      );

      expect(resolved, {'plain': 'v'});
    });

    test('a suffixed key wins even without a base key present', () {
      final resolved = resolveProviderExtras(
        bootExtras: {},
        remoteExtras: {'banner_ad_unit_id_android': 'b1'},
        platformSuffix: 'android',
      );

      expect(resolved, {'banner_ad_unit_id': 'b1'});
    });

    test('all-empty inputs resolve to an empty map', () {
      expect(
        resolveProviderExtras(
          bootExtras: {},
          remoteExtras: {},
          platformSuffix: 'android',
        ),
        isEmpty,
      );
    });
  });
}
