# Changelog

## 0.1.1

- Fix: banners now request their ad once their platform view is created; in 0.1.0 they never loaded.
- Fix: banners keep their platform view across parent rebuilds instead of recreating it.
- Add `example/example.dart`.

## 0.1.0

Initial release.

- `LevelPlayAdProvider` implementing the `ads_kit` `AdProvider` contract over `unity_levelplay_mediation` — no LevelPlay SDK type leaks out of the package.
- Interstitial, rewarded and banner formats; per-platform app keys and ad unit ids supplied through `AdConfig.extras` (`_android`/`_ios` suffixes).
- `user_id` passed to LevelPlay init and dynamic user id, so S2S reward callbacks carry it.
- Init timeout: a never-answering SDK falls back instead of hanging activation.
