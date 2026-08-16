/// A provider-agnostic ad error.
///
/// [cause] carries the original SDK exception/object for logging only — code
/// must never branch on it, since its runtime type is provider-specific.
final class AdError {
  const AdError({
    required this.code,
    required this.message,
    required this.providerName,
    this.isNoFill = false,
    this.cause,
  });

  /// Stable, provider-agnostic error code (e.g. `"no_fill"`, `"timeout"`,
  /// `"network_error"`, `"not_ready"`, `"init_failed"`, `"unknown"`).
  final String code;

  /// Human-readable detail, safe to log.
  final String message;

  /// The provider key (e.g. `"levelplay"`, `"max"`, `"noop"`) that raised
  /// this error.
  final String providerName;

  /// Normalized "the auction returned no ad" flag, set by each provider's
  /// error mapper. No fill is an inventory condition, not a provider
  /// malfunction — [HealthMonitor] must not count it toward a fallback
  /// decision, or a freshly provisioned app with warming-up demand keeps
  /// bouncing to noop.
  final bool isNoFill;

  /// Original SDK error object, kept only so it can be logged upstream.
  /// Never inspect its runtime type outside a provider package.
  final dynamic cause;

  @override
  String toString() =>
      'AdError(code: $code, provider: $providerName, message: $message)';
}
