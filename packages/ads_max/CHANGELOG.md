# Changelog

## 0.1.0

Initial release.

- `MaxAdProvider` implementing the `ads_core` `AdProvider` contract over `applovin_max` — no MAX SDK type leaks out of the package.
- Interstitial, rewarded, app open, banner and MREC formats; per-platform ad unit ids supplied through `AdConfig.extras` (`_android`/`_ios` suffixes).
- Init timeout: a never-answering SDK falls back instead of hanging activation.
