# ads_kit_example

A runnable demo of `ads_kit`. It registers two fake providers behind
`AdManager` so you can try every format, switch providers at runtime and
watch the live `AdEvent` stream, without a Firebase project or any ad SDK
keys.

- `demo_a` (`DemoAdProvider`, 15% no-fill rate) is the active provider.
- `demo_b` (`DemoAdProvider`, 35% no-fill rate) is the alternative to
  switch to.
- `noop` is the built-in fallback.

`StaticAdConfigSource` stands in for Firebase Remote Config and serves a
fixed config with short frequency caps, so the demo doesn't make you wait
through production-sized cooldowns.

## Run

```bash
flutter pub get   # at the repo root; resolves the whole workspace
cd example
flutter run
```

`flutter test` runs the widget tests in `test/`.
