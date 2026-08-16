import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'ad_health_event.dart';
import 'ad_provider.dart';
import 'frequency_guard.dart';
import 'health_monitor.dart';
import 'providers/noop_ad_provider.dart';
import 'remote_config/ad_config_source.dart';
import 'remote_config/ad_runtime_config.dart';
import 'remote_config/firebase_ad_config_source.dart';
import 'remote_config/provider_extras.dart';
import 'types/ad_banner_size.dart';
import 'types/ad_config.dart';
import 'types/ad_consent.dart';
import 'types/ad_error.dart';
import 'types/ad_event.dart';
import 'types/ad_format.dart';
import 'types/ad_show_result.dart';

/// Builds a fresh [AdProvider] instance. Registered per provider key via
/// [AdManager.register] — ads_kit never names a concrete provider class.
typedef AdProviderFactory = AdProvider Function();

/// The single entry point the host app talks to. Everything else in this
/// package — [FrequencyGuard], [HealthMonitor], remote config parsing — is
/// wired together here so app code never has to know which provider is
/// active, or that a fallback even happened.
final class AdManager {
  AdManager._();

  static final Map<String, AdProviderFactory> _factories = {
    'noop': NoopAdProvider.new,
  };

  static AdProvider _active = NoopAdProvider();
  static String _activeKey = 'noop';
  static AdRuntimeConfig _config = AdRuntimeConfig.safeDefaults;
  static AdConsent _consent = const AdConsent();
  static String? _countryCode;
  static Map<String, Map<String, String>> _bootProviderExtras = const {};

  static FrequencyGuard _frequencyGuard = _guardFrom(AdRuntimeConfig.safeDefaults);
  static HealthMonitor _healthMonitor =
      HealthMonitor(failureThreshold: AdRuntimeConfig.safeDefaults.healthFailureThreshold);

  static final _healthEvents = StreamController<AdHealthEvent>.broadcast();
  static final _managed = _ManagedAdProvider();

  static Timer? _recoveryTimer;
  static int _recoveryAttempts = 0;

  /// The provider the app talks to. Stable across `boot`/`switchProvider`
  /// calls and automatic health-triggered fallbacks — it's always this same
  /// object, forwarding to whichever real provider is currently active.
  static AdProvider get I => _managed;

  /// Key of the provider currently backing [I] (e.g. `"levelplay"`,
  /// `"max"`, `"noop"`). Useful for a debug menu; not required for normal
  /// ad-serving call sites.
  static String get activeProviderName => _activeKey;

  /// Layer-lifecycle events (currently: provider switches). Distinct from
  /// [AdProvider.events] — the app is not required to listen to this, but
  /// may forward it to its own analytics.
  static Stream<AdHealthEvent> get healthEvents => _healthEvents.stream;

  /// Registers a factory for [key] so [boot]/[switchProvider] can construct
  /// that provider on demand. Call this once per provider package before
  /// [boot] (e.g. in `main()`):
  /// ```dart
  /// AdManager.register('levelplay', () => LevelPlayAdProvider());
  /// AdManager.register('max', () => MaxAdProvider());
  /// ```
  static void register(String key, AdProviderFactory factory) {
    _factories[key] = factory;
  }

  /// Reads remote config, resolves the active provider, and initializes it.
  ///
  /// Resolution order: configured `active_provider` -> configured
  /// `fallback_provider` -> [NoopAdProvider]. Never throws — any failure
  /// anywhere in this chain lands on noop.
  ///
  /// [providerExtras] carries each provider's `AdConfig.extras` (app/SDK
  /// keys, ad unit ids), keyed by provider name. Remote config's
  /// `providers` object is merged on top of it, so a value can start
  /// hardcoded here and later be overridden without a release. Keys may
  /// use `_android`/`_ios` suffixes for per-platform values — see
  /// [resolveProviderExtras].
  static Future<void> boot({
    AdConfigSource? configSource,
    AdConsent consent = const AdConsent(),
    String? countryCode,
    Map<String, Map<String, String>> providerExtras = const {},
  }) async {
    _consent = consent;
    _countryCode = countryCode;
    _bootProviderExtras = providerExtras;

    final source = configSource ?? FirebaseAdConfigSource();
    Map<String, dynamic>? raw;
    try {
      raw = await source.fetchRawConfig();
    } catch (_) {
      raw = null;
    }
    _config = AdRuntimeConfig.fromJson(raw);
    _frequencyGuard = _guardFrom(_config);
    _healthMonitor = HealthMonitor(failureThreshold: _config.healthFailureThreshold);

    await _activate(
      _config.activeProvider,
      reason: ProviderSwitchReason.initFailed,
      emitOnDirectSuccess: false,
    );
  }

  /// Marks the start of a fresh user session for frequency capping —
  /// resets the interstitial per-session counter and min-interval clock.
  /// [FrequencyGuard] can't know what the app considers a session (e.g.
  /// resuming from background after 30+ minutes), so the app calls this
  /// from its own lifecycle handling; a cold start needs no call since
  /// [boot] builds a fresh guard anyway.
  static void startNewSession() => _frequencyGuard.resetSession();

  /// Explicitly switches the active provider at runtime — no store update
  /// needed, since this can be driven by the same remote config that
  /// changed `active_provider`, or called directly for a manual override.
  ///
  /// Falls back exactly like [boot] does if [key] fails to init.
  static Future<void> switchProvider(String key) => _activate(
        key,
        reason: ProviderSwitchReason.manual,
        emitOnDirectSuccess: true,
      );

  /// Re-applies changed consent to the active provider mid-session — call
  /// this after the user completes a consent flow, instead of re-booting.
  /// If the active provider cannot serve the new consent state at all
  /// (e.g. MAX for a now-child-directed user), it is switched away from,
  /// falling back exactly like a failed init. That consent-driven fallback
  /// is *not* auto-recovered — only a new consent state can change the
  /// situation, so call [switchProvider] once consent allows the primary
  /// again.
  static Future<void> updateConsent(AdConsent consent) async {
    _consent = consent;
    try {
      await _active.updateConsent(consent);
    } catch (_) {
      final nextKey =
          _activeKey == _config.fallbackProvider ? 'noop' : _config.fallbackProvider;
      await _activate(
        nextKey,
        reason: ProviderSwitchReason.consentRejected,
        emitOnDirectSuccess: true,
      );
    }
  }

  /// Resets all static state to its pre-boot defaults. Only meant for
  /// tests — production code boots once per process.
  @visibleForTesting
  static Future<void> resetForTesting() async {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _recoveryAttempts = 0;
    await _safeDispose(_active);
    _factories
      ..clear()
      ..['noop'] = NoopAdProvider.new;
    _active = NoopAdProvider();
    _activeKey = 'noop';
    _config = AdRuntimeConfig.safeDefaults;
    _consent = const AdConsent();
    _countryCode = null;
    _bootProviderExtras = const {};
    _frequencyGuard = _guardFrom(AdRuntimeConfig.safeDefaults);
    _healthMonitor =
        HealthMonitor(failureThreshold: AdRuntimeConfig.safeDefaults.healthFailureThreshold);
    _managed._bindTo(_active, _activeKey);
  }

  static FrequencyGuard _guardFrom(AdRuntimeConfig config) => FrequencyGuard(
        config: FrequencyGuardConfig(
          coldStartGrace: config.coldStartGrace,
          minInterval: config.interstitialMinInterval,
          maxPerSession: config.interstitialMaxPerSession,
          disabledCountries: config.disabledCountries,
        ),
      );

  static AdConfig _currentAdConfig(String providerKey) => AdConfig(
        consent: _consent,
        formatsEnabled: _config.formatsEnabled,
        countryCode: _countryCode,
        extras: resolveProviderExtras(
          bootExtras: _bootProviderExtras[providerKey] ?? const {},
          remoteExtras: _config.providerExtras[providerKey] ?? const {},
          platformSuffix: _platformSuffix,
        ),
      );

  static String get _platformSuffix {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return '';
    }
  }

  static Future<AdProvider?> _tryCreateAndInit(String key) async {
    final factory = _factories[key];
    if (factory == null) return null;

    final AdProvider provider;
    try {
      provider = factory();
    } catch (_) {
      return null;
    }

    try {
      await provider.init(_currentAdConfig(key));
      return provider;
    } catch (_) {
      unawaited(_safeDispose(provider));
      return null;
    }
  }

  static Future<void> _activate(
    String requestedKey, {
    required ProviderSwitchReason reason,
    required bool emitOnDirectSuccess,
  }) async {
    final previous = _active;
    final previousKey = _activeKey;

    var provider = await _tryCreateAndInit(requestedKey);
    var resolvedKey = requestedKey;
    var resolvedReason = reason;
    var didFallBack = false;

    if (provider == null && requestedKey != _config.fallbackProvider) {
      provider = await _tryCreateAndInit(_config.fallbackProvider);
      resolvedKey = _config.fallbackProvider;
      resolvedReason = ProviderSwitchReason.initFailed;
      didFallBack = true;
    }

    if (provider == null && resolvedKey != 'noop') {
      final noop = NoopAdProvider();
      await noop.init(_currentAdConfig('noop'));
      provider = noop;
      resolvedKey = 'noop';
      resolvedReason = ProviderSwitchReason.initFailed;
      didFallBack = true;
    }

    provider ??= previous;

    _bindActive(provider, resolvedKey);

    final shouldEmit = resolvedKey != previousKey && (didFallBack || emitOnDirectSuccess);
    if (shouldEmit) {
      _healthEvents.add(AdProviderSwitched(
        fromProvider: previousKey,
        toProvider: resolvedKey,
        reason: resolvedReason,
      ));
    }

    if (!identical(previous, provider)) {
      unawaited(_safeDispose(previous));
    }

    _maybeScheduleRecovery(resolvedReason);
  }

  static void _bindActive(AdProvider provider, String key) {
    _active = provider;
    _activeKey = key;
    _healthMonitor.reset(key);
    _managed._bindTo(provider, key);

    // Kick off loading for every enabled fullscreen format so the first
    // show attempt isn't a guaranteed not_ready. Banner is excluded — its
    // platform view loads itself once mounted. Fire-and-forget: failures
    // surface as AdEventFailed on the events stream, not here.
    for (final format in _config.formatsEnabled) {
      switch (format) {
        case AdFormat.interstitial:
        case AdFormat.rewarded:
        case AdFormat.appOpen:
          unawaited(_managed.preload(format));
        case AdFormat.banner:
        case AdFormat.native:
          break;
      }
    }
  }

  /// After any provider change, decides whether a timer should try the
  /// configured `active_provider` again. Runs on every [_activate] so a
  /// successful (re)activation of the configured provider also cancels
  /// pending attempts and resets the per-episode attempt budget.
  static void _maybeScheduleRecovery(ProviderSwitchReason reason) {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;

    if (_activeKey == _config.activeProvider) {
      _recoveryAttempts = 0;
      return;
    }
    // A manual switch is an explicit choice — don't fight it. A consent
    // rejection won't heal with time — only a new consent state can.
    if (reason == ProviderSwitchReason.manual ||
        reason == ProviderSwitchReason.consentRejected) {
      return;
    }
    if (_config.recoveryCooldown <= Duration.zero) return;
    if (_recoveryAttempts >= _config.recoveryMaxAttempts) return;
    if (!_factories.containsKey(_config.activeProvider)) return;

    _recoveryTimer = Timer(_config.recoveryCooldown, _attemptRecovery);
  }

  /// Tries the configured provider without touching the current one first
  /// — the working fallback keeps serving unless the recovery init
  /// actually succeeds, so a still-broken primary costs nothing but the
  /// attempt itself.
  static Future<void> _attemptRecovery() async {
    _recoveryAttempts++;
    final provider = await _tryCreateAndInit(_config.activeProvider);
    if (provider == null) {
      _maybeScheduleRecovery(ProviderSwitchReason.initFailed);
      return;
    }

    final previous = _active;
    final previousKey = _activeKey;
    _bindActive(provider, _config.activeProvider);
    _recoveryAttempts = 0;
    _healthEvents.add(AdProviderSwitched(
      fromProvider: previousKey,
      toProvider: _activeKey,
      reason: ProviderSwitchReason.recovered,
    ));
    if (!identical(previous, provider)) {
      unawaited(_safeDispose(previous));
    }
  }

  static Future<void> _safeDispose(AdProvider provider) async {
    try {
      await provider.dispose();
    } catch (_) {
      // Disposal errors must never propagate — we're already tearing this
      // provider down.
    }
  }
}

/// The object behind [AdManager.I]. Forwards every call to whichever real
/// provider is currently active, applying [FrequencyGuard] to interstitials
/// and feeding [HealthMonitor] from the delegate's event stream so a
/// provider swap underneath is invisible to call sites.
final class _ManagedAdProvider implements AdProvider {
  AdProvider _delegate = NoopAdProvider();
  String _delegateKey = 'noop';
  StreamSubscription<AdEvent>? _delegateSub;
  final _events = StreamController<AdEvent>.broadcast();

  void _bindTo(AdProvider provider, String key) {
    unawaited(_delegateSub?.cancel());
    _delegate = provider;
    _delegateKey = key;
    _delegateSub = provider.events.listen((event) {
      _events.add(event);
      _trackHealth(event, key);
    });
  }

  void _trackHealth(AdEvent event, String key) {
    switch (event) {
      case AdEventFailed():
        // No fill means the provider is healthy but had nothing to serve —
        // counting it would demote a working provider on slow inventory.
        if (event.error.isNoFill) return;
        final tripped = AdManager._healthMonitor.recordFailure(key);
        if (tripped) _escalateAfterHealthTrip(key);
      case AdEventLoaded():
      case AdEventShown():
      case AdEventRevenuePaid():
        AdManager._healthMonitor.recordSuccess(key);
      case AdEventClicked():
      case AdEventDismissed():
      case AdEventRewardEarned():
        break;
    }
  }

  void _escalateAfterHealthTrip(String unhealthyKey) {
    final nextKey =
        unhealthyKey == AdManager._config.fallbackProvider ? 'noop' : AdManager._config.fallbackProvider;
    unawaited(AdManager._activate(
      nextKey,
      reason: ProviderSwitchReason.healthThresholdExceeded,
      emitOnDirectSuccess: true,
    ));
  }

  @override
  String get name => _delegate.name;

  @override
  Future<void> init(AdConfig config) => throw UnsupportedError(
        'AdManager.I owns provider lifecycle — call AdManager.boot() or '
        'AdManager.switchProvider() instead of init() directly.',
      );

  @override
  Future<void> dispose() => throw UnsupportedError(
        'AdManager.I owns provider lifecycle — providers are disposed '
        'automatically when AdManager switches away from them.',
      );

  @override
  Future<void> updateConsent(AdConsent consent) => throw UnsupportedError(
        'Call AdManager.updateConsent() instead — it also handles a '
        'provider that cannot serve the new consent state.',
      );

  @override
  Future<void> preload(AdFormat format) async {
    try {
      await _delegate.preload(format);
    } catch (_) {
      // preload is fire-and-forget from the app's perspective; a real
      // failure will surface as AdEventFailed on the events stream.
    }
  }

  @override
  Future<bool> isReady(AdFormat format) async {
    try {
      return await _delegate.isReady(format);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AdShowResult> showInterstitial({String? placement}) async {
    final decision = AdManager._frequencyGuard.evaluate(countryCode: AdManager._countryCode);
    if (!decision.allowed) return AdShowResult.suppressed();

    final key = _delegateKey;
    final result = await _safeShow(
      () => _delegate.showInterstitial(placement: placement),
      key,
    );
    if (result.shown) AdManager._frequencyGuard.recordShown();
    return result;
  }

  @override
  Future<AdShowResult> showRewarded({String? placement}) => _safeShow(
        () => _delegate.showRewarded(placement: placement),
        _delegateKey,
      );

  @override
  Future<AdShowResult> showAppOpen({String? placement}) => _safeShow(
        () => _delegate.showAppOpen(placement: placement),
        _delegateKey,
      );

  /// Runs a provider `show*` call, converting an uncaught exception into a
  /// failed [AdShowResult] and counting it toward [HealthMonitor] — this is
  /// the safety net for a provider that throws instead of following the
  /// "always emit [AdEventFailed]" contract on [AdProvider.events].
  Future<AdShowResult> _safeShow(
    Future<AdShowResult> Function() call,
    String key,
  ) async {
    try {
      return await call();
    } catch (error) {
      final tripped = AdManager._healthMonitor.recordFailure(key);
      if (tripped) _escalateAfterHealthTrip(key);
      return AdShowResult.failed(AdError(
        code: 'uncaught_exception',
        message: error.toString(),
        providerName: key,
        cause: error,
      ));
    }
  }

  @override
  Widget banner({required AdBannerSize size, String? placement}) =>
      _delegate.banner(size: size, placement: placement);

  @override
  Stream<AdEvent> get events => _events.stream;
}
