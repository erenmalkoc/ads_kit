/// iOS App Tracking Transparency status, as already resolved by the app.
///
/// This layer never calls `AppTrackingTransparency.requestAuthorization`
/// itself — the app asks for ATT on its own timeline (typically after the
/// user has seen value), then hands the resulting status in here.
enum AttStatus {
  notDetermined,
  restricted,
  denied,
  authorized,

  /// Not iOS, or the platform plugin isn't present.
  unavailable,
}

/// Consent/privacy signals a provider's `init()` must translate into its own
/// SDK's consent API. Every field is nullable-safe by design: `null` means
/// "unknown / not applicable", which every provider must treat as the most
/// restrictive choice (e.g. non-personalized ads), never as `false`.
final class AdConsent {
  const AdConsent({
    this.gdprConsent,
    this.ccpaOptOut,
    this.isChildDirected = false,
    this.attStatus = AttStatus.unavailable,
  });

  /// `true` = user granted GDPR consent for personalized ads. `null` =
  /// GDPR not applicable or not yet determined for this user.
  final bool? gdprConsent;

  /// `true` = user opted out of sale/sharing under CCPA. `null` = not
  /// applicable or not yet determined.
  final bool? ccpaOptOut;

  /// COPPA: treat this user as a child. Forces non-personalized,
  /// contextual-only ads regardless of the other two flags.
  final bool isChildDirected;

  /// Resolved ATT status, supplied by the app after it — not this layer —
  /// requested tracking authorization.
  final AttStatus attStatus;
}
