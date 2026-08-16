import 'ad_error.dart';
import 'ad_format.dart';
import 'ad_revenue.dart';

/// Lifecycle events emitted by an [AdProvider] on its `events` stream.
///
/// Sealed, so consumers can exhaustively `switch` over it without a default
/// branch — the compiler flags a missing case the moment a new variant is
/// added here.
sealed class AdEvent {
  const AdEvent({
    required this.format,
    required this.providerName,
    this.placement,
  });

  /// Which ad format this event pertains to.
  final AdFormat format;

  /// The provider key that emitted this event (e.g. `"levelplay"`,
  /// `"max"`, `"noop"`).
  final String providerName;

  /// Publisher-defined placement name, if the call site provided one.
  final String? placement;
}

/// An ad finished loading and is ready to show.
final class AdEventLoaded extends AdEvent {
  const AdEventLoaded({
    required super.format,
    required super.providerName,
    super.placement,
  });
}

/// An ad failed to load or failed to display.
final class AdEventFailed extends AdEvent {
  const AdEventFailed({
    required super.format,
    required super.providerName,
    required this.error,
    super.placement,
  });

  final AdError error;
}

/// An ad was shown to the user.
final class AdEventShown extends AdEvent {
  const AdEventShown({
    required super.format,
    required super.providerName,
    super.placement,
  });
}

/// The user clicked/tapped an ad.
final class AdEventClicked extends AdEvent {
  const AdEventClicked({
    required super.format,
    required super.providerName,
    super.placement,
  });
}

/// The user dismissed/closed a full-screen ad.
final class AdEventDismissed extends AdEvent {
  const AdEventDismissed({
    required super.format,
    required super.providerName,
    super.placement,
  });
}

/// The user completed a rewarded ad and earned the reward.
final class AdEventRewardEarned extends AdEvent {
  const AdEventRewardEarned({
    required super.format,
    required super.providerName,
    super.placement,
    this.rewardType,
    this.rewardAmount,
  });

  /// SDK-reported reward label (e.g. `"coins"`), if any. Free text —
  /// never a provider SDK type.
  final String? rewardType;
  final num? rewardAmount;
}

/// An impression's revenue was reported, normalized across providers.
///
/// This is the one objective, cross-provider-comparable number the layer
/// produces — treat it as the source of truth when comparing LevelPlay vs.
/// MAX performance.
final class AdEventRevenuePaid extends AdEvent {
  const AdEventRevenuePaid({
    required super.format,
    required super.providerName,
    required this.revenue,
    super.placement,
  });

  final AdRevenue revenue;
}
