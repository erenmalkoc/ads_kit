import 'ad_error.dart';

/// Outcome of an `AdProvider.show*` call.
///
/// Exactly one of three states holds: shown successfully (optionally with a
/// reward), suppressed before the SDK was ever asked to show, or failed with
/// an [error]. Suppression is not an error — it's [FrequencyGuard] or
/// disabled-country policy quietly doing its job.
final class AdShowResult {
  const AdShowResult._({
    required this.shown,
    required this.rewardEarned,
    required this.suppressed,
    this.error,
  });

  /// The ad was displayed to the user.
  factory AdShowResult.shown({bool rewardEarned = false}) => AdShowResult._(
        shown: true,
        rewardEarned: rewardEarned,
        suppressed: false,
      );

  /// The show attempt was blocked by policy (frequency cap, cold-start
  /// grace, disabled country, format disabled) before reaching the SDK.
  factory AdShowResult.suppressed() => const AdShowResult._(
        shown: false,
        rewardEarned: false,
        suppressed: true,
      );

  /// The SDK attempted to show and failed (not ready, no fill, display
  /// error, ...).
  factory AdShowResult.failed(AdError error) => AdShowResult._(
        shown: false,
        rewardEarned: false,
        suppressed: false,
        error: error,
      );

  final bool shown;
  final bool rewardEarned;
  final bool suppressed;
  final AdError? error;

  @override
  String toString() => 'AdShowResult(shown: $shown, '
      'rewardEarned: $rewardEarned, suppressed: $suppressed, error: $error)';
}
