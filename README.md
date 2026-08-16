# ads_kit

A mediation-platform-independent ad abstraction for our Flutter apps. App code
depends only on `ads_core` — never on a mediation SDK directly — so swapping
providers is a remote-config value, not a store release.

## Why

Our AdMob account was suspended for a policy violation. Unity LevelPlay
(ironSource) is the primary target now, AppLovin MAX the secondary — and the
next forced migration should cost us a config change, not a rewrite.

## Structure

```
packages/
  ads_core/        # AdProvider contract, AdManager, FrequencyGuard,
                    # HealthMonitor, remote-config parsing, NoopAdProvider.
                    # Zero dependencies on any ad network SDK.
  ads_levelplay/    # LevelPlayAdProvider — wraps unity_levelplay_mediation.
  ads_max/          # MaxAdProvider — wraps applovin_max.
example/            # Runnable demo: switch providers, try every format,
                    # watch the live AdEvent stream.
```

Managed as a [Melos](https://melos.invertase.dev/) workspace on top of native
Dart/Flutter [pub workspaces](https://dart.dev/tools/pub/workspaces) — one
`dart pub get` at the repo root resolves every package.

## The one rule that matters

**No public API in `ads_core` may reference an ad-SDK type.** No `AdSize`,
`AdRequest`, `MaxAd`, `IronSourceAdInfo` — nothing from a mediation SDK
crosses into `ads_core`. Every provider package owns its own translation
to/from `ads_core`'s types (`AdFormat`, `AdBannerSize`, `AdEvent`, `AdError`,
`AdRevenue`, ...). This is the first thing to check in review — if it slips,
the abstraction is pointless.

## App integration

```dart
// main.dart — register whichever provider packages this app ships with.
AdManager.register('levelplay', () => LevelPlayAdProvider());
AdManager.register('max', () => MaxAdProvider());

await AdManager.boot(
  consent: myResolvedConsent,
  countryCode: myCountryCode,
  // Per-provider keys/ad unit ids. `_android`/`_ios` suffixes resolve to
  // the current platform; remote config's `providers` block overrides
  // these without a release.
  providerExtras: {
    'levelplay': {
      'app_key_android': '...',
      'app_key_ios': '...',
      'interstitial_ad_unit_id_android': '...',
      'interstitial_ad_unit_id_ios': '...',
    },
  },
);

// Anywhere else in the app:
final result = await AdManager.I.showInterstitial();
// ^ resolves when the ad is *dismissed* (or failed/suppressed) — safe to
//   navigate / resume audio / grant rewards the moment it completes.
AdManager.I.banner(size: AdBannerSize.banner);
```

`AdManager.boot` reads Firebase Remote Config, resolves `active_provider`,
and falls back to `fallback_provider` and then to `NoopAdProvider` if
anything fails to initialize. No config, or a malformed one, means no ads —
never the wrong ads. After activation the enabled fullscreen formats are
preloaded automatically, and after an automatic fallback the configured
provider is retried on a cooldown (`recovery_cooldown_sec`, max
`recovery_max_attempts` tries) so one bad stretch doesn't cost the rest of
the session's revenue.

Mid-session hooks the app is expected to call:

- `AdManager.updateConsent(newConsent)` after the user completes a consent
  flow — re-applies to the live SDK, no reboot.
- `AdManager.startNewSession()` on the app's own session boundary (e.g.
  resumed from background after 30+ minutes) — resets interstitial caps.

To flip providers without a release: change `active_provider` in Remote
Config, or call `AdManager.switchProvider('max')` directly.

## Remote config schema

One Firebase Remote Config string parameter, `ads_config`, holding JSON.
Every field is optional — a missing or malformed field degrades to its
safe default, and no config at all means noop (no ads):

```json
{
  "active_provider": "levelplay",
  "fallback_provider": "noop",
  "formats_enabled": ["interstitial", "rewarded", "banner"],
  "interstitial_min_interval_sec": 60,
  "interstitial_max_per_session": 3,
  "cold_start_grace_sec": 30,
  "disabled_countries": [],
  "health_failure_threshold": 3,
  "recovery_cooldown_sec": 300,
  "recovery_max_attempts": 3,
  "providers": {
    "levelplay": {
      "app_key_android": "...",
      "app_key_ios": "...",
      "interstitial_ad_unit_id_android": "..."
    }
  }
}
```

`providers.<name>` entries merge over the same provider's boot-time
`providerExtras` (remote wins per key), and a `_android`/`_ios`-suffixed
key beats its unsuffixed base on the matching platform.

## Getting started

```bash
dart pub global activate melos   # once (8.x — config lives in pubspec.yaml)
flutter pub get                  # resolves the whole workspace
melos run analyze
melos run test
```

Run the demo app:

```bash
cd example
flutter run
```

## Status

- [x] `ads_core` + `NoopAdProvider` + tests + example app
- [x] `ads_levelplay` (Unity LevelPlay, over `unity_levelplay_mediation`)
- [x] `ads_max` (AppLovin MAX, over `applovin_max`)
