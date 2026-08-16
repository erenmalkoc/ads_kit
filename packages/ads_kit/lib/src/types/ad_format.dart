/// The kinds of ad placements a provider can serve.
enum AdFormat {
  banner,
  interstitial,
  rewarded,
  appOpen,
  native;

  /// Parses a remote-config format key (e.g. `"interstitial"`) into an
  /// [AdFormat]. Returns `null` for unknown or malformed keys instead of
  /// throwing, so callers can drop bad entries rather than crash boot.
  static AdFormat? tryParse(String value) {
    for (final format in AdFormat.values) {
      if (format.name == value) return format;
    }
    return null;
  }
}
