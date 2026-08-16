# ads_kit_levelplay

Unity LevelPlay (ironSource) implementation of the [`ads_kit`](../ads_kit)
`AdProvider` contract, wrapping
[`unity_levelplay_mediation`](https://pub.dev/packages/unity_levelplay_mediation).

No LevelPlay SDK type crosses out of this package — the app only ever talks
to `ads_kit`'s `AdProvider`/`AdManager`/`AdEvent` types.

## App integration

```dart
AdManager.register('levelplay', () => LevelPlayAdProvider());
```

Ad unit IDs are per-app/per-environment values, not part of the
abstraction contract, so they're passed through `AdConfig.extras` rather
than hardcoded in this package. `AdManager` builds that `AdConfig` from
`AdManager.boot(providerExtras: {'levelplay': {...}})` merged with remote
config's `providers.levelplay` block (remote wins per key). LevelPlay app
keys and ad unit ids are **per-platform** — use the `_android`/`_ios` key
suffixes so one shared config serves both platforms:

| Key | Required | Notes |
|---|---|---|
| `app_key` | yes | LevelPlay app key — in practice always supplied as `app_key_android` + `app_key_ios` |
| `interstitial_ad_unit_id` | only if using interstitials | per-platform suffixes apply |
| `rewarded_ad_unit_id` | only if using rewarded ads | per-platform suffixes apply |
| `banner_ad_unit_id` | only if using banners | per-platform suffixes apply |
| `user_id` | only for S2S reward callbacks | set as both init userId and dynamic user id, so the callback's USER_ID macro carries it |

A format with no ad unit id configured is simply never loaded —
`preload`/`isReady`/`show*` behave as "not configured" (a failed
`AdShowResult`, never an exception). **LevelPlay does not support app-open
ads** — `showAppOpen` always returns a failed result with code
`unsupported_format`.

## Platform setup

Verified against `unity_levelplay_mediation` 9.2.0's own README/example.

### Android

The LevelPlay SDK itself is bundled by the plugin. You only need to add
Play Services dependencies to `android/app/build.gradle`:

```groovy
dependencies {
  implementation 'com.google.android.gms:play-services-appset:16.0.2'
  implementation 'com.google.android.gms:play-services-ads-identifier:18.0.1'
  implementation 'com.google.android.gms:play-services-basement:18.3.0'
}
```

No `AndroidManifest.xml` changes are required for the base plugin. If you
add mediated network adapters (Meta, Unity Ads, etc.), follow each
network's own setup doc — see [LevelPlay's Android mediation
guide](https://developers.ironsrc.com/ironsource-mobile/android/mediation-networks-android/).

### iOS

The LevelPlay pod is bundled by the plugin — no `Podfile` entry needed for
the base SDK. If your `Podfile` uses `use_frameworks!`, switch it to static
linkage to avoid a transitive-dependency build error:

```ruby
use_frameworks! :linkage => :static
```

`Info.plist`:

```xml
<key>SKAdNetworkItems</key>
<array>
  <dict>
    <key>SKAdNetworkIdentifier</key>
    <string>su67r6k2v3.skadnetwork</string>
  </dict>
  <!-- Add one entry per mediated network you enable — see each network's
       own SKAdNetwork docs. LevelPlay does not bundle a master list. -->
</array>

<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

`NSAllowsArbitraryLoads` is required because some mediated networks still
make plain-HTTP calls (LevelPlay's own network calls are encrypted).
**Don't** also add `NSAllowsArbitraryLoadsInWebContent` — LevelPlay's docs
call that combination out as a conflict.

If you add mediated network adapters, also follow [LevelPlay's iOS
mediation guide](https://developers.ironsrc.com/ironsource-mobile/ios/mediation-networks-ios/)
for their Podfile/`Info.plist` additions.

### ATT (App Tracking Transparency)

Not requested by this package — per `ads_kit`'s design, the host app
requests ATT on its own timeline (after demonstrating value to the user)
and passes the resolved `AttStatus` into `AdConsent`. If you use
`unity_levelplay_mediation`'s own `ATTrackingManager` convenience wrapper
elsewhere in your app to request it, add `NSUserTrackingUsageDescription`
to `Info.plist` — but that call site belongs in app code, not here.

## Consent mapping

| `AdConsent` field | LevelPlay call |
|---|---|
| `gdprConsent` | `LevelPlay.setConsent(bool)` |
| `ccpaOptOut` | `LevelPlayPrivacySettings.setCCPA(bool)` |
| `isChildDirected` | `LevelPlayPrivacySettings.setCOPPA(bool)` |

`LevelPlay.setConsent` is deprecated in favor of
`LevelPlayPrivacySettings.setGDPRConsents(Map<network, bool>)`, which wants
per-network consent — a shape `AdConsent` doesn't model (it's a single
app-wide flag). We use the deprecated whole-SDK setter deliberately; see
the comment at the call site in `level_play_ad_provider.dart`.

`null` values on `AdConsent` (unknown consent) resolve to the more
restrictive choice: no GDPR consent, and opted out of CCPA sale.

## Testing

`test/level_play_mappers_test.dart` covers every LevelPlay -> `ads_kit`
type conversion (`level_play_mappers.dart`) as pure functions over
primitives — no real SDK calls, no platform channels. The provider and
listener adapter classes themselves are thin glue over those pure
functions and the SDK's documented API and aren't independently unit
tested here, consistent with the rest of this monorepo's policy of not
writing tests that require a real ad SDK call.
