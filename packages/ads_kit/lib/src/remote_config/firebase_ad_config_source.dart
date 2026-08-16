import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';

import 'ad_config_source.dart';

/// Reads the ads config JSON from a single Firebase Remote Config string
/// parameter (Remote Config has no native object type, so the schema is
/// stored as a JSON-encoded string).
final class FirebaseAdConfigSource implements AdConfigSource {
  FirebaseAdConfigSource({this.parameterKey = 'ads_config'});

  final String parameterKey;

  @override
  Future<Map<String, dynamic>?> fetchRawConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.fetchAndActivate();
      final raw = remoteConfig.getString(parameterKey);
      if (raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      // Any fetch/parse failure degrades to "no config" — AdManager.boot
      // falls back to AdRuntimeConfig.safeDefaults from there.
      return null;
    }
  }
}
