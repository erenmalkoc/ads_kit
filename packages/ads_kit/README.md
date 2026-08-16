# ads_kit

A mediation-platform-independent ad abstraction for Flutter apps. Your app
code depends only on `ads_kit` — never on a mediation SDK directly — so
swapping ad providers is a remote-config value, not a store release.

Provider implementations live in their own packages (e.g.
[`ads_kit_levelplay`](https://pub.dev/packages/ads_kit_levelplay) for Unity
LevelPlay, [`ads_kit_max`](https://pub.dev/packages/ads_kit_max) for AppLovin MAX)
and translate their SDK's types into this package's vocabulary. **No ad-SDK
type ever crosses into `ads_kit`'s public API.**

## What you get

- **`AdProvider`** — the contract every mediation package implements:
  init/dispose, preload, readiness, fullscreen shows, banner widget, and a
  single `AdEvent` stream.
- **`AdManager`** — the one entry point the app talks to. Reads Firebase
  Remote Config, resolves the active provider, falls back through
  `fallback_provider` down to a built-in no-op provider ("no ads" always
  beats "wrong ads"), preloads enabled formats, and recovers back to the
  configured provider on a cooldown after an automatic fallback.
- **`FrequencyGuard`** — mandatory interstitial pacing (cold-start grace,
  minimum interval, session cap, per-country disable) to keep policy risk
  down.
- **`HealthMonitor`** — consecutive-failure tracking that triggers the
  fallback chain. No-fill is treated as inventory, never as provider
  failure.
- **Typed events** — `AdEventLoaded/Shown/Dismissed/RewardEarned/...` and a
  normalized `AdRevenue` per impression, comparable across providers.
- **Consent plumbing** — `AdConsent` (GDPR/CCPA/COPPA/ATT) applied at init
  and updatable mid-session via `AdManager.updateConsent`.

## Usage

```dart
// main.dart — register whichever provider packages this app ships with.
AdManager.register('levelplay', () => LevelPlayAdProvider());

await AdManager.boot(
  consent: myResolvedConsent,
  providerExtras: {
    'levelplay': {
      'app_key_android': '...',
      'app_key_ios': '...',
      'rewarded_ad_unit_id_android': '...',
      'rewarded_ad_unit_id_ios': '...',
    },
  },
);

// Anywhere else in the app:
final result = await AdManager.I.showRewarded();
// Fullscreen show futures resolve when the ad is *dismissed* — safe to
// continue your flow (navigate, grant rewards) the moment they complete.
```

`_android`/`_ios` key suffixes resolve to the running platform, so one
shared config serves both.

## Remote config

One Firebase Remote Config string parameter, `ads_config`, holding JSON.
Every field is optional; missing or malformed input degrades to safe
defaults, and no config at all means no ads:

```json
{
  "active_provider": "levelplay",
  "fallback_provider": "noop",
  "formats_enabled": ["rewarded"],
  "interstitial_min_interval_sec": 60,
  "interstitial_max_per_session": 3,
  "cold_start_grace_sec": 30,
  "health_failure_threshold": 3,
  "recovery_cooldown_sec": 300,
  "recovery_max_attempts": 3,
  "providers": {
    "levelplay": {"app_key_android": "...", "app_key_ios": "..."}
  }
}
```

Flipping providers without a release: change `active_provider`, or call
`AdManager.switchProvider('max')` directly.

## Writing a provider package

Implement `AdProvider`, translate every SDK type at the boundary, and emit
`AdEventFailed` for every load/show failure — the health monitor counts
those events as its only signal. See the
[repository](https://github.com/erenmalkoc/ads_kit) for two complete
reference implementations and the full design notes.
