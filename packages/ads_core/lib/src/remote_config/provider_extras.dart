/// Merges boot-time and remote-config extras for one provider and resolves
/// per-platform key suffixes, as a pure function so every precedence rule
/// is unit-testable without booting [AdManager].
///
/// Precedence: [remoteExtras] wins over [bootExtras] (remote config exists
/// to change values without a release), and a platform-suffixed key wins
/// over its unsuffixed base key. Suffixed keys for the *other* platform
/// are dropped entirely.
///
/// The suffix convention exists because the whole `ads_config` payload is
/// shared by both platforms while some values are per-platform (e.g.
/// LevelPlay app keys): `app_key_android` / `app_key_ios` resolve to
/// `app_key` on the matching platform.
library;

const _platformSuffixes = ['android', 'ios'];

Map<String, String> resolveProviderExtras({
  required Map<String, String> bootExtras,
  required Map<String, String> remoteExtras,
  required String platformSuffix,
}) {
  final merged = <String, String>{...bootExtras, ...remoteExtras};

  final resolved = <String, String>{};
  merged.forEach((key, value) {
    if (!_platformSuffixes.any((s) => key.endsWith('_$s'))) {
      resolved[key] = value;
    }
  });

  if (platformSuffix.isNotEmpty) {
    final marker = '_$platformSuffix';
    merged.forEach((key, value) {
      if (key.endsWith(marker)) {
        resolved[key.substring(0, key.length - marker.length)] = value;
      }
    });
  }

  return resolved;
}
