/// Where [AdManager.boot] gets the raw ads config JSON from.
///
/// Abstracted so tests (and [AdRuntimeConfig.fromJson]'s malformed-input
/// handling) never need a real Firebase Remote Config fetch — see
/// [FirebaseAdConfigSource] for the production implementation and any
/// in-memory fake for tests.
abstract class AdConfigSource {
  /// Returns the decoded JSON object, or `null` if unreachable/unset.
  /// Must never throw — swallow fetch errors and return `null` so
  /// [AdRuntimeConfig.fromJson] can fall back to safe defaults.
  Future<Map<String, dynamic>?> fetchRawConfig();
}
