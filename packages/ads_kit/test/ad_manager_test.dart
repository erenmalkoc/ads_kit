import 'package:ads_kit/ads_kit.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_doubles.dart';

Future<void> pumpEventLoop() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  setUp(() async {
    await AdManager.resetForTesting();
  });

  group('AdManager lifecycle via NoopAdProvider', () {
    test('boots to noop when no config source is supplied any provider', () async {
      await AdManager.boot(configSource: FakeAdConfigSource(null));

      expect(AdManager.activeProviderName, 'noop');
      expect(AdManager.I.name, 'noop');
    });

    test('noop never shows anything and never throws', () async {
      await AdManager.boot(configSource: FakeAdConfigSource(null));

      expect(await AdManager.I.isReady(AdFormat.interstitial), isFalse);
      expect((await AdManager.I.showInterstitial()).shown, isFalse);
      expect((await AdManager.I.showRewarded()).shown, isFalse);
      expect((await AdManager.I.showAppOpen()).shown, isFalse);
      expect(
        AdManager.I.banner(size: AdBannerSize.banner),
        isA<SizedBox>(),
      );
    });

    test('direct init()/dispose() on AdManager.I is not supported', () async {
      await AdManager.boot(configSource: FakeAdConfigSource(null));

      expect(
        () => AdManager.I.init(
          const AdConfig(consent: AdConsent(), formatsEnabled: {}),
        ),
        throwsUnsupportedError,
      );
      expect(() => AdManager.I.dispose(), throwsUnsupportedError);
    });
  });

  group('AdManager provider resolution', () {
    test('boot activates the registered provider named by active_provider', () async {
      AdManager.register('fake', () => FakeAdProvider('fake'));

      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'fake',
          'fallback_provider': 'noop',
        }),
      );

      expect(AdManager.activeProviderName, 'fake');
      expect(AdManager.I.name, 'fake');
    });

    test('falls back to fallback_provider when the primary fails to init', () async {
      AdManager.register('bad', () => FakeAdProvider('bad', failInit: true));
      AdManager.register('backup', () => FakeAdProvider('backup'));

      final events = <AdHealthEvent>[];
      AdManager.healthEvents.listen(events.add);

      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'bad',
          'fallback_provider': 'backup',
        }),
      );
      await pumpEventLoop();

      expect(AdManager.activeProviderName, 'backup');
      expect(events, hasLength(1));
      final event = events.single as AdProviderSwitched;
      expect(event.toProvider, 'backup');
      expect(event.reason, ProviderSwitchReason.initFailed);
    });

    test('falls all the way back to noop when both primary and fallback fail', () async {
      AdManager.register('bad', () => FakeAdProvider('bad', failInit: true));
      AdManager.register(
        'alsoBad',
        () => FakeAdProvider('alsoBad', failInit: true),
      );

      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'bad',
          'fallback_provider': 'alsoBad',
        }),
      );

      expect(AdManager.activeProviderName, 'noop');
    });

    test('an unregistered active_provider key falls back cleanly', () async {
      AdManager.register('backup', () => FakeAdProvider('backup'));

      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'never_registered',
          'fallback_provider': 'backup',
        }),
      );

      expect(AdManager.activeProviderName, 'backup');
    });
  });

  group('AdManager provider extras plumbing', () {
    test('boot merges boot-time and remote-config extras into init', () async {
      final fake = FakeAdProvider('fake');
      AdManager.register('fake', () => fake);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'fake',
          'fallback_provider': 'noop',
          'providers': {
            'fake': {
              'app_key_android': 'remote_droid_key',
              'interstitial_ad_unit_id': 'remote_inter',
            },
          },
        }),
        providerExtras: {
          'fake': {
            'app_key_android': 'boot_droid_key',
            'banner_ad_unit_id': 'boot_banner',
          },
        },
      );

      expect(AdManager.activeProviderName, 'fake');
      expect(fake.lastInitConfig?.extras, {
        'app_key': 'remote_droid_key',
        'interstitial_ad_unit_id': 'remote_inter',
        'banner_ad_unit_id': 'boot_banner',
      });
    });

    test('a provider with no extras configured receives an empty map', () async {
      final fake = FakeAdProvider('fake');
      AdManager.register('fake', () => fake);

      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'fake',
          'fallback_provider': 'noop',
        }),
      );

      expect(fake.lastInitConfig?.extras, isEmpty);
    });
  });

  group('AdManager.startNewSession', () {
    test('resets the interstitial session cap', () async {
      AdManager.register('fake', () => FakeAdProvider('fake'));
      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'fake',
          'fallback_provider': 'noop',
          'cold_start_grace_sec': 0,
          'interstitial_min_interval_sec': 0,
          'interstitial_max_per_session': 1,
        }),
      );

      expect((await AdManager.I.showInterstitial()).shown, isTrue);
      expect((await AdManager.I.showInterstitial()).suppressed, isTrue,
          reason: 'session cap of 1 is spent');

      AdManager.startNewSession();

      expect((await AdManager.I.showInterstitial()).shown, isTrue);
    });
  });

  group('AdManager auto-preload', () {
    test('boot preloads enabled fullscreen formats, not banner', () async {
      final fake = FakeAdProvider('fake');
      AdManager.register('fake', () => fake);

      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'fake',
          'fallback_provider': 'noop',
          'formats_enabled': ['interstitial', 'rewarded', 'banner'],
        }),
      );
      await pumpEventLoop();

      expect(
        fake.preloadedFormats,
        unorderedEquals([AdFormat.interstitial, AdFormat.rewarded]),
      );
    });

    test('no enabled formats means nothing is preloaded', () async {
      final fake = FakeAdProvider('fake');
      AdManager.register('fake', () => fake);

      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'fake',
          'fallback_provider': 'noop',
        }),
      );
      await pumpEventLoop();

      expect(fake.preloadedFormats, isEmpty);
    });
  });

  group('AdManager.updateConsent', () {
    test('reaches the active provider without a reboot', () async {
      final fake = FakeAdProvider('fake');
      AdManager.register('fake', () => fake);
      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'fake',
          'fallback_provider': 'noop',
        }),
      );

      await AdManager.updateConsent(const AdConsent(gdprConsent: true));

      expect(AdManager.activeProviderName, 'fake');
      expect(fake.lastUpdatedConsent?.gdprConsent, isTrue);
    });

    test('switches away when the provider rejects the new consent', () async {
      AdManager.register('picky', () => FakeAdProvider('picky', failUpdateConsent: true));
      final backup = FakeAdProvider('backup');
      AdManager.register('backup', () => backup);
      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'picky',
          'fallback_provider': 'backup',
        }),
      );

      final events = <AdHealthEvent>[];
      AdManager.healthEvents.listen(events.add);

      const consent = AdConsent(isChildDirected: true);
      await AdManager.updateConsent(consent);
      await pumpEventLoop();

      expect(AdManager.activeProviderName, 'backup');
      expect(backup.lastInitConfig?.consent, consent,
          reason: 'the fallback must init with the consent that was rejected');
      final event = events.single as AdProviderSwitched;
      expect(event.reason, ProviderSwitchReason.consentRejected);
    });

    test('direct updateConsent on AdManager.I is not supported', () async {
      await AdManager.boot(configSource: FakeAdConfigSource(null));
      expect(
        () => AdManager.I.updateConsent(const AdConsent()),
        throwsUnsupportedError,
      );
    });
  });

  group('AdManager.switchProvider', () {
    test('switches the live provider and disposes the old one', () async {
      final first = FakeAdProvider('first');
      final second = FakeAdProvider('second');
      AdManager.register('first', () => first);
      AdManager.register('second', () => second);

      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'first',
          'fallback_provider': 'noop',
        }),
      );
      expect(AdManager.activeProviderName, 'first');

      await AdManager.switchProvider('second');

      expect(AdManager.activeProviderName, 'second');
      expect(second.initialized, isTrue);
      expect(first.disposed, isTrue);
    });

    test('reports a manual switch on healthEvents', () async {
      AdManager.register('first', () => FakeAdProvider('first'));
      AdManager.register('second', () => FakeAdProvider('second'));
      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'first',
          'fallback_provider': 'noop',
        }),
      );

      final events = <AdHealthEvent>[];
      AdManager.healthEvents.listen(events.add);

      await AdManager.switchProvider('second');
      await pumpEventLoop();

      expect(events, hasLength(1));
      final event = events.single as AdProviderSwitched;
      expect(event.fromProvider, 'first');
      expect(event.toProvider, 'second');
      expect(event.reason, ProviderSwitchReason.manual);
    });
  });

  group('AdManager health-triggered auto-fallback', () {
    test('consecutive AdEventFailed on the active provider trips a fallback', () async {
      final primary = FakeAdProvider('primary');
      final backup = FakeAdProvider('backup');
      AdManager.register('primary', () => primary);
      AdManager.register('backup', () => backup);

      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'primary',
          'fallback_provider': 'backup',
          'health_failure_threshold': 2,
        }),
      );
      expect(AdManager.activeProviderName, 'primary');

      AdError error(String provider) => AdError(
            code: 'no_fill',
            message: 'no fill',
            providerName: provider,
          );

      primary.emit(AdEventFailed(
        format: AdFormat.interstitial,
        providerName: 'primary',
        error: error('primary'),
      ));
      await pumpEventLoop();
      expect(AdManager.activeProviderName, 'primary', reason: 'one failure is below threshold');

      primary.emit(AdEventFailed(
        format: AdFormat.interstitial,
        providerName: 'primary',
        error: error('primary'),
      ));
      await pumpEventLoop();

      expect(AdManager.activeProviderName, 'backup');
    });

    test('no-fill failures never count toward the health threshold', () async {
      final primary = FakeAdProvider('primary');
      AdManager.register('primary', () => primary);
      AdManager.register('backup', () => FakeAdProvider('backup'));

      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'primary',
          'fallback_provider': 'backup',
          'health_failure_threshold': 2,
        }),
      );

      for (var i = 0; i < 5; i++) {
        primary.emit(AdEventFailed(
          format: AdFormat.rewarded,
          providerName: 'primary',
          error: AdError(
            code: 'levelplay_509',
            message: 'Mediation No fill',
            providerName: 'primary',
            isNoFill: true,
          ),
        ));
        await pumpEventLoop();
      }

      expect(AdManager.activeProviderName, 'primary',
          reason: 'no fill is inventory, not provider health');
    });

    test('a success in between resets the failure streak', () async {
      final primary = FakeAdProvider('primary');
      AdManager.register('primary', () => primary);
      AdManager.register('backup', () => FakeAdProvider('backup'));

      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'primary',
          'fallback_provider': 'backup',
          'health_failure_threshold': 2,
        }),
      );

      AdError error() => AdError(code: 'no_fill', message: 'x', providerName: 'primary');

      primary.emit(AdEventFailed(format: AdFormat.interstitial, providerName: 'primary', error: error()));
      await pumpEventLoop();
      primary.emit(AdEventLoaded(format: AdFormat.interstitial, providerName: 'primary'));
      await pumpEventLoop();
      primary.emit(AdEventFailed(format: AdFormat.interstitial, providerName: 'primary', error: error()));
      await pumpEventLoop();

      expect(AdManager.activeProviderName, 'primary');
    });

    test('retries the configured provider after the cooldown and recovers', () {
      fakeAsync((async) {
        var primaryHealthy = false;
        AdManager.register(
          'primary',
          () => FakeAdProvider('primary', failInit: !primaryHealthy),
        );
        AdManager.register('backup', () => FakeAdProvider('backup'));

        final events = <AdHealthEvent>[];
        AdManager.healthEvents.listen(events.add);

        AdManager.boot(
          configSource: FakeAdConfigSource({
            'active_provider': 'primary',
            'fallback_provider': 'backup',
            'recovery_cooldown_sec': 60,
          }),
        );
        async.flushMicrotasks();
        expect(AdManager.activeProviderName, 'backup');

        primaryHealthy = true;
        async.elapse(const Duration(seconds: 61));
        async.flushMicrotasks();

        expect(AdManager.activeProviderName, 'primary');
        final last = events.whereType<AdProviderSwitched>().last;
        expect(last.reason, ProviderSwitchReason.recovered);
        expect(last.fromProvider, 'backup');
      });
    });

    test('stops retrying after recovery_max_attempts', () {
      fakeAsync((async) {
        var primaryBuilds = 0;
        AdManager.register('primary', () {
          primaryBuilds++;
          return FakeAdProvider('primary', failInit: true);
        });
        AdManager.register('backup', () => FakeAdProvider('backup'));

        AdManager.boot(
          configSource: FakeAdConfigSource({
            'active_provider': 'primary',
            'fallback_provider': 'backup',
            'recovery_cooldown_sec': 60,
            'recovery_max_attempts': 2,
          }),
        );
        async.flushMicrotasks();
        expect(AdManager.activeProviderName, 'backup');
        final buildsAfterBoot = primaryBuilds;

        async.elapse(const Duration(minutes: 30));
        async.flushMicrotasks();

        expect(AdManager.activeProviderName, 'backup');
        expect(primaryBuilds, buildsAfterBoot + 2,
            reason: 'exactly recovery_max_attempts retries, then silence');
      });
    });

    test('a manual switch cancels pending recovery', () {
      fakeAsync((async) {
        AdManager.register('primary', () => FakeAdProvider('primary', failInit: true));
        AdManager.register('backup', () => FakeAdProvider('backup'));
        AdManager.register('manualPick', () => FakeAdProvider('manualPick'));

        AdManager.boot(
          configSource: FakeAdConfigSource({
            'active_provider': 'primary',
            'fallback_provider': 'backup',
            'recovery_cooldown_sec': 60,
          }),
        );
        async.flushMicrotasks();
        expect(AdManager.activeProviderName, 'backup');

        AdManager.switchProvider('manualPick');
        async.flushMicrotasks();
        expect(AdManager.activeProviderName, 'manualPick');

        async.elapse(const Duration(minutes: 30));
        async.flushMicrotasks();
        expect(AdManager.activeProviderName, 'manualPick',
            reason: 'recovery must not fight an explicit manual choice');
      });
    });

    test('the app never sees an exception when the delegate throws mid-show', () async {
      final flaky = _ThrowingAdProvider('flaky');
      AdManager.register('flaky', () => flaky);
      AdManager.register('backup', () => FakeAdProvider('backup'));

      await AdManager.boot(
        configSource: FakeAdConfigSource({
          'active_provider': 'flaky',
          'fallback_provider': 'backup',
          'health_failure_threshold': 1,
          'cold_start_grace_sec': 0,
        }),
      );

      final result = await AdManager.I.showInterstitial();
      expect(result.shown, isFalse);
      expect(result.error, isNotNull);

      await pumpEventLoop();
      expect(AdManager.activeProviderName, 'backup');
    });
  });
}

/// A provider whose show* calls throw synchronously instead of returning a
/// failed [AdShowResult] — exercises AdManager's last-resort safety net.
class _ThrowingAdProvider extends FakeAdProvider {
  _ThrowingAdProvider(super.name);

  @override
  Future<AdShowResult> showInterstitial({String? placement}) {
    throw StateError('$name: boom');
  }
}
