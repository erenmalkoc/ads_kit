import 'package:flutter/widgets.dart';

import 'types/ad_banner_size.dart';
import 'types/ad_config.dart';
import 'types/ad_event.dart';
import 'types/ad_format.dart';
import 'types/ad_show_result.dart';

/// The contract every mediation provider package implements.
///
/// Implementations own all translation to/from their SDK's types — nothing
/// outside a provider package (including this interface) may reference an
/// ad-SDK type.
abstract class AdProvider {
  /// Stable identifier for this provider (e.g. `"levelplay"`, `"max"`,
  /// `"noop"`). Used as the registry/remote-config key.
  String get name;

  /// Initializes the underlying SDK. Must not throw — report failure by
  /// completing normally and leaving [isReady] false for every format, or
  /// by returning a failed future that [AdManager] can catch; either way
  /// [AdManager] treats a non-functional provider as "unavailable" and
  /// moves on to the fallback, so this must never let an SDK exception
  /// escape uncaught.
  Future<void> init(AdConfig config);

  /// Releases SDK resources. Called when switching away from this
  /// provider.
  Future<void> dispose();

  /// Requests the SDK start loading an ad for [format] ahead of when it's
  /// needed. A no-op for formats the SDK auto-loads (e.g. LevelPlay
  /// interstitials/rewarded ads load themselves once enabled).
  Future<void> preload(AdFormat format);

  /// Whether an ad for [format] is currently loaded and can be shown
  /// immediately.
  Future<bool> isReady(AdFormat format);

  /// Shows a loaded fullscreen ad. The returned future resolves once the
  /// ad has been *dismissed* (or immediately on suppression/failure) —
  /// never at display time — so a call site can `await` it and safely
  /// continue its flow (navigate, resume audio, grant a reward) the moment
  /// it completes. Implementations must also guard against an SDK that
  /// never confirms display, failing the future with `display_timeout`
  /// instead of hanging forever.
  Future<AdShowResult> showInterstitial({String? placement});

  /// See [showInterstitial] for the dismissal-completion contract.
  /// `AdShowResult.rewardEarned` reports whether the user earned the
  /// reward before dismissing.
  Future<AdShowResult> showRewarded({String? placement});

  /// See [showInterstitial] for the dismissal-completion contract.
  Future<AdShowResult> showAppOpen({String? placement});

  /// Returns this provider's own banner platform view. Each provider
  /// renders its native banner widget directly — this layer does not
  /// attempt a shared banner implementation, only a shared call signature.
  Widget banner({required AdBannerSize size, String? placement});

  /// Lifecycle events for every format this provider serves. A broadcast
  /// stream — safe for multiple listeners (app UI, analytics forwarding,
  /// [AdManager]'s health monitoring).
  ///
  /// [AdManager] counts consecutive [AdEventFailed] events on this stream
  /// (across every format — load failures and show failures alike) as the
  /// sole signal for [HealthMonitor]'s fallback decision. An implementation
  /// that fails silently without emitting [AdEventFailed] will never be
  /// detected as unhealthy — always emit one for every load/show failure,
  /// even ones already reflected in an `AdShowResult`.
  Stream<AdEvent> get events;
}
