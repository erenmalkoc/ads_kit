# Changelog

## 0.1.0

Initial release.

- `AdProvider` contract and `AdManager` entry point — register providers, `boot`, `switchProvider`, zero dependencies on any ad network SDK.
- Remote-config-driven provider selection via Firebase Remote Config (`ads_config` JSON), with fallback chain ending in `NoopAdProvider` (no config means no ads, never the wrong ads).
- `FrequencyGuard`: interstitial min interval, per-session cap, cold-start grace; `startNewSession()` to reset caps on the app's own session boundary.
- `HealthMonitor` with automatic fallback on repeated failures (no-fill excluded) and cooldown recovery back to the primary provider without an app restart.
- Per-provider extras merged from boot-time `providerExtras` and remote config, with `_android`/`_ios` platform key resolution.
- `updateConsent()` to reapply consent mid-session; provider init timeout; preload of enabled fullscreen formats on activation; fullscreen shows complete at dismiss with a display timeout.
