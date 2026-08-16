/// Mediation-platform-independent ad abstraction.
///
/// Import this single library from app code and provider packages —
/// nothing under `src/` is meant to be imported directly from outside this
/// package.
library;

export 'src/ad_health_event.dart';
export 'src/ad_manager.dart';
export 'src/ad_provider.dart';
export 'src/frequency_guard.dart';
export 'src/health_monitor.dart';
export 'src/providers/noop_ad_provider.dart';
export 'src/remote_config/ad_config_source.dart';
export 'src/remote_config/ad_runtime_config.dart';
export 'src/remote_config/firebase_ad_config_source.dart';
export 'src/remote_config/provider_extras.dart';
export 'src/types/ad_banner_size.dart';
export 'src/types/ad_config.dart';
export 'src/types/ad_consent.dart';
export 'src/types/ad_error.dart';
export 'src/types/ad_event.dart';
export 'src/types/ad_format.dart';
export 'src/types/ad_revenue.dart';
export 'src/types/ad_show_result.dart';
