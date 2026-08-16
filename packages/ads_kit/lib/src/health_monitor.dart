/// Pure consecutive-failure counter, keyed by provider name.
///
/// [HealthMonitor] only counts — it decides nothing about what to do once
/// a provider trips its threshold. [AdManager] owns that orchestration
/// (switch to fallback, then to noop, emit [AdProviderSwitched]) so this
/// class stays trivially unit-testable without any provider or event-bus
/// wiring.
final class HealthMonitor {
  HealthMonitor({required this.failureThreshold})
      : assert(failureThreshold > 0, 'failureThreshold must be positive');

  final int failureThreshold;

  final _consecutiveFailures = <String, int>{};

  /// Records a failure for [providerKey]. Returns `true` once the
  /// consecutive-failure count reaches [failureThreshold] — the caller
  /// should treat that as "this provider is unhealthy, fail over now".
  bool recordFailure(String providerKey) {
    final count = (_consecutiveFailures[providerKey] ?? 0) + 1;
    _consecutiveFailures[providerKey] = count;
    return count >= failureThreshold;
  }

  /// Clears [providerKey]'s streak — call this on any successful load/show.
  void recordSuccess(String providerKey) {
    _consecutiveFailures[providerKey] = 0;
  }

  int failureCountFor(String providerKey) =>
      _consecutiveFailures[providerKey] ?? 0;

  void reset(String providerKey) => _consecutiveFailures.remove(providerKey);

  void resetAll() => _consecutiveFailures.clear();
}
