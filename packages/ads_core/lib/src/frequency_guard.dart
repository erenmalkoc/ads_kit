/// Static tuning for [FrequencyGuard], sourced from remote config.
final class FrequencyGuardConfig {
  const FrequencyGuardConfig({
    required this.coldStartGrace,
    required this.minInterval,
    required this.maxPerSession,
    required this.disabledCountries,
  });

  final Duration coldStartGrace;
  final Duration minInterval;
  final int maxPerSession;

  /// Uppercase ISO 3166-1 alpha-2 codes.
  final Set<String> disabledCountries;
}

/// Why [FrequencyGuard.evaluate] blocked a show attempt.
enum FrequencyBlockReason {
  coldStart,
  minInterval,
  sessionCap,
  disabledCountry,
}

final class FrequencyDecision {
  const FrequencyDecision._(this.allowed, this.reason);

  const FrequencyDecision.allow() : this._(true, null);

  const FrequencyDecision.block(FrequencyBlockReason reason)
      : this._(false, reason);

  final bool allowed;
  final FrequencyBlockReason? reason;
}

/// Provider-independent interstitial pacing.
///
/// This exists to reduce policy-violation risk (aggressive interstitial
/// spam is a common cause of mediation account suspensions), so every check
/// here is mandatory, not configurable away by a provider — a provider
/// package must call [evaluate] before its own `showInterstitial` reaches
/// the SDK, exactly like [AdManager]'s managed wrapper does.
final class FrequencyGuard {
  FrequencyGuard({
    required FrequencyGuardConfig config,
    DateTime Function() now = DateTime.now,
  })  : _config = config,
        _now = now,
        _appStart = now();

  final FrequencyGuardConfig _config;
  final DateTime Function() _now;
  final DateTime _appStart;

  DateTime? _lastShown;
  int _sessionCount = 0;

  /// Checks every rule without side effects. Call [recordShown] separately
  /// once the ad has actually been displayed.
  FrequencyDecision evaluate({String? countryCode}) {
    final nowTs = _now();

    if (nowTs.difference(_appStart) < _config.coldStartGrace) {
      return const FrequencyDecision.block(FrequencyBlockReason.coldStart);
    }

    final lastShown = _lastShown;
    if (lastShown != null &&
        nowTs.difference(lastShown) < _config.minInterval) {
      return const FrequencyDecision.block(FrequencyBlockReason.minInterval);
    }

    if (_sessionCount >= _config.maxPerSession) {
      return const FrequencyDecision.block(FrequencyBlockReason.sessionCap);
    }

    if (countryCode != null &&
        _config.disabledCountries.contains(countryCode.toUpperCase())) {
      return const FrequencyDecision.block(
        FrequencyBlockReason.disabledCountry,
      );
    }

    return const FrequencyDecision.allow();
  }

  /// Marks that an interstitial was just shown, starting the min-interval
  /// clock and counting it against the session cap.
  void recordShown() {
    _lastShown = _now();
    _sessionCount++;
  }

  /// Resets per-session counters (e.g. on a fresh app session/cold launch
  /// distinct from this guard's own construction).
  void resetSession() {
    _sessionCount = 0;
    _lastShown = null;
  }
}
