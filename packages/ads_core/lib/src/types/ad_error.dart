/// A provider-agnostic ad error.
///
/// [cause] carries the original SDK exception/object for logging only — code
/// must never branch on it, since its runtime type is provider-specific.
final class AdError {
  const AdError({
    required this.code,
    required this.message,
    required this.providerName,
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

  /// Original SDK error object, kept only so it can be logged upstream.
  /// Never inspect its runtime type outside a provider package.
  final dynamic cause;

  @override
  String toString() =>
      'AdError(code: $code, provider: $providerName, message: $message)';
}
