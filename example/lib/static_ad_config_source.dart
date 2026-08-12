import 'package:ads_core/ads_core.dart';

/// An [AdConfigSource] that returns a fixed map instead of calling Firebase
/// — this example has no Firebase project wired up, and doesn't need one to
/// demonstrate the layer. A real app supplies nothing here and lets
/// `AdManager.boot` default to [FirebaseAdConfigSource].
final class StaticAdConfigSource implements AdConfigSource {
  const StaticAdConfigSource(this._raw);

  final Map<String, dynamic> _raw;

  @override
  Future<Map<String, dynamic>?> fetchRawConfig() async => _raw;
}
