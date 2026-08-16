# ads_max

AppLovin MAX implementation of the [`ads_core`](../ads_core) `AdProvider`
contract, wrapping [`applovin_max`](https://pub.dev/packages/applovin_max).

No MAX SDK type crosses out of this package — the app only ever talks to
`ads_core`'s `AdProvider`/`AdManager`/`AdEvent` types.

## App integration

```dart
AdManager.register('max', () => MaxAdProvider());
```

Ad unit IDs are per-app/per-environment values, not part of the
abstraction contract, so they're passed through `AdConfig.extras` —
supplied via `AdManager.boot(providerExtras: {'max': {...}})` merged with
remote config's `providers.max` block (remote wins per key). MAX ad unit
ids are per-platform — use the `_android`/`_ios` key suffixes (the SDK
key itself is account-wide, no suffix needed):

| Key | Required | Notes |
|---|---|---|
| `sdk_key` | yes | AppLovin MAX SDK key |
| `interstitial_ad_unit_id` | only if using interstitials | |
| `rewarded_ad_unit_id` | only if using rewarded ads | |
| `app_open_ad_unit_id` | only if using app open ads | |
| `banner_ad_unit_id` | only if using banner/large-banner/adaptive | one MAX "banner" ad unit serves all three |
| `mrec_ad_unit_id` | only if using `AdBannerSize.mediumRectangle` | MAX treats MREC as a distinct ad unit type from banner |

A format with no ad unit id configured is simply never loaded —
`preload`/`isReady`/`show*` behave as "not configured" (a failed
`AdShowResult`, never an exception).

**Child-directed users**: `MaxAdProvider.init` throws if
`AdConsent.isChildDirected` is `true`, refusing to initialize the SDK at
all. This isn't a bug — AppLovin's own policy is that MAX must not be used
in any way for a user classified as a child (their SDK removed the old
`setIsAgeRestrictedUser` age-gate flag in v4.0.0 for exactly this reason:
there's no compliant "child mode", only "don't use it"). `AdManager`
treats the throw as "provider unavailable" and falls back through
`fallback_provider` to `NoopAdProvider`.

### Banner sizing

MAX's Dart API only has two `AdFormat` values for ad-view widgets —
`banner` and `mrec` — plus an adaptive-height flag; it has no distinct
"large banner" concept (it auto-picks 320x50 on phones vs. a 728x90
"leader" size on tablets for `AdFormat.banner`). This provider maps our
four `AdBannerSize` values onto that:

| `AdBannerSize` | MAX format | Notes |
|---|---|---|
| `banner` | `AdFormat.banner` | fixed, non-adaptive |
| `largeBanner` | `AdFormat.banner` | fixed 90pt height override — an approximation, not a real distinct MAX ad unit type |
| `adaptive` | `AdFormat.banner` | `isAdaptiveBannerEnabled: true` |
| `mediumRectangle` | `AdFormat.mrec` | separate ad unit id (`mrec_ad_unit_id`) |

## Platform setup

Verified against `applovin_max` 4.6.4's own source, `pubspec.yaml`,
`build.gradle`/`applovin_max.podspec`, and example app.

### Android

No extra `build.gradle` dependencies, maven repo, or `AndroidManifest.xml`
meta-data are required — the plugin resolves the AppLovin SDK via
`google()`/`mavenCentral()` on its own, and the SDK key is passed
programmatically to `initialize()`, not read from the manifest.

### iOS

No `Podfile` entry needed — `applovin_max.podspec` declares the AppLovin
SDK pod dependency itself; standard `pod install` picks it up.

`Info.plist` — SKAdNetworkItems are required and must be added manually.
AppLovin publishes a machine-readable, always-current list (rather than a
static one worth pasting stale into this README):

- https://skadnetwork-ids.applovin.com/v1/skadnetworkids.json
- https://skadnetwork-ids.applovin.com/v1/skadnetworkids.xml

AppLovin also has an interactive Info.plist generator (filtered to only
the networks you've enabled) at
`support.applovin.com/en/max/ios/overview/skadnetwork`.

### ATT (App Tracking Transparency)

Not requested by this package — per `ads_core`'s design, the host app
requests ATT on its own timeline and passes the resolved `AttStatus` into
`AdConsent`. If your app requests it, add `NSUserTrackingUsageDescription`
to `Info.plist` — that call site belongs in app code, not here.

## Consent mapping

| `AdConsent` field | MAX call |
|---|---|
| `gdprConsent` | `AppLovinMAX.setHasUserConsent(bool)` |
| `ccpaOptOut` | `AppLovinMAX.setDoNotSell(bool)` |
| `isChildDirected` | `init()` refuses to initialize (see above) — no per-flag setter exists |

`null` values on `AdConsent` (unknown consent) resolve to the more
restrictive choice: no GDPR consent, and opted out of CCPA sale.

## Testing

`test/max_mappers_test.dart` covers every MAX -> `ads_core` type
conversion (`max_mappers.dart`) as pure functions over primitives — no
real SDK calls, no platform channels. The provider and listener builder
functions are thin glue over those pure functions and the SDK's
documented API and aren't independently unit tested here, consistent with
the rest of this monorepo's policy of not writing tests that require a
real ad SDK call.
