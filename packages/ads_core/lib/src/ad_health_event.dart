/// Why [AdManager] switched the active provider.
enum ProviderSwitchReason {
  /// `init()` failed or threw during boot/switchProvider.
  initFailed,

  /// [HealthMonitor]'s consecutive-failure threshold was exceeded.
  healthThresholdExceeded,

  /// The active provider rejected an updated consent state it cannot
  /// serve (e.g. MAX with a now-child-directed user).
  consentRejected,

  /// The app (or a caller) explicitly requested `AdManager.switchProvider`.
  manual,
}

/// Layer-lifecycle events, distinct from per-ad [AdEvent]s.
///
/// The app is never required to react to these — a provider switch must
/// stay transparent to ad-serving call sites — but they're exposed so the
/// app can forward them to its own analytics, per the "ads_core has no
/// analytics SDK dependency, it just opens a stream" rule.
sealed class AdHealthEvent {
  const AdHealthEvent();
}

final class AdProviderSwitched extends AdHealthEvent {
  const AdProviderSwitched({
    required this.fromProvider,
    required this.toProvider,
    required this.reason,
  });

  final String fromProvider;
  final String toProvider;
  final ProviderSwitchReason reason;

  @override
  String toString() => 'AdProviderSwitched($fromProvider -> $toProvider, '
      'reason: $reason)';
}
