/// How confident the reported [AdRevenue.value] is. Mediation SDKs report
/// this per-impression; naming differs per SDK, meaning is the same.
enum AdRevenuePrecision {
  /// Exact price from a real-time auction.
  exact,

  /// Estimated from historical eCPM data for the network/placement.
  estimated,

  /// A static value the publisher configured for that ad unit.
  publisherDefined,

  /// The provider didn't report a precision, or reported one we don't
  /// recognize yet.
  unknown,
}

/// A single ad impression's revenue, normalized so it can be compared across
/// mediation platforms regardless of which one produced it.
final class AdRevenue {
  const AdRevenue({
    required this.value,
    required this.currencyCode,
    required this.networkName,
    required this.adUnitId,
    required this.precision,
  });

  /// Revenue for this impression, in [currencyCode]'s major unit (e.g. USD
  /// dollars, not cents).
  final double value;

  /// ISO 4217 currency code, e.g. `"USD"`.
  final String currencyCode;

  /// The underlying ad network that filled this impression (e.g.
  /// `"admob_network"`, `"unity_ads"`, `"applovin"`) — not the mediation
  /// platform itself.
  final String networkName;

  /// The ad unit / placement identifier this impression was served for.
  final String adUnitId;

  final AdRevenuePrecision precision;

  @override
  String toString() =>
      'AdRevenue(value: $value $currencyCode, network: $networkName, '
      'adUnit: $adUnitId, precision: $precision)';
}
