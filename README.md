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
  ads_levelplay/    # LevelPlayAdProvider — wraps ironsource_mediation.
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

await AdManager.boot(consent: myResolvedConsent);

// Anywhere else in the app:
await AdManager.I.showInterstitial();
AdManager.I.banner(size: AdBannerSize.banner);
```

`AdManager.boot` reads Firebase Remote Config, resolves `active_provider`,
and falls back to `fallback_provider` and then to `NoopAdProvider` if
anything fails to initialize. No config, or a malformed one, means no ads —
never the wrong ads.

To flip providers without a release: change `active_provider` in Remote
Config, or call `AdManager.switchProvider('max')` directly.

## Getting started

```bash
dart pub global activate melos   # once
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
- [ ] `ads_levelplay`
- [ ] `ads_max`
