# Maintaining the custom Immich fork

The current upstream baseline is the stable Immich **v3.3.6** release
(`587f549f46f1cd1822a06e16dcccecef04ea4565`). `origin` is the
`astramunt/immich` fork; `upstream` is `https://github.com/immich-app/immich.git`.

## Custom behavior to preserve

- The `personal`, `private`, and `daem` mobile variants, including their icons,
  bundle/package IDs, App Groups, and extension configuration. See
  [mobile/VARIANTS.md](mobile/VARIANTS.md).
- Configurable video hold speed and double-tap seeking at the edges of the viewport.
  By default, each edge occupies 25% of the width and splits halfway down the viewport.
  Top-left and bottom-right skip forward. Bottom-left and top-right skip back.
  A single tap in the central square (96 × 96 dp by default) toggles playback. Double taps
  in the free area toggle between zoom and the fitted video.
- The video timeline appears below the video and along both edges whenever playback
  controls are visible. The two side sliders advance from bottom to top.
  Video settings control the pause square size, edge width and split height,
  and the width and length of the touch targets for the side sliders. Sizes
  accept exact logical pixels (dp), including decimals. Empty values restore
  defaults. Enable the UI edit mode to preview sizes and outline active targets
  over the playing video.
- Free Up Space includes the full selected calendar day in the device's time zone.
- Backup settings can optionally request device trash after manual in-app photo and video uploads.
  Verify the current account's active remote original and the complete local original, including
  paired Live Photo video, before requesting removal. Automatic backups and shares use separate paths.
- Album selection by long press and drag, bulk album deletion, and optional
  trashing of owned album contents without deleting other users' assets.
- English and Spanish translations and regression tests for these features.

The v3.3.6 integration combines the custom video gesture wrapper with upstream's
20× maximum zoom and motion-photo dismissal fixes. It also retains upstream's
fallback to remote video playback when the local file is unavailable.

## Future updates

Start from the fork's current `main`, preserve any uncommitted work, and create
an update branch. Fetch the desired stable release from `upstream` and merge
its tag into that branch. Keep the upstream ancestry so future merges can
identify changes already integrated; do not replace the fork with the upstream
tree or squash away the imported history.

Review both textual conflicts and automatically merged custom files. Regenerate
the OpenAPI Dart client, Drift migrations/schema helpers, Dart models, Pigeon
bindings, and translations using the repository's Mise tasks before checking
the result:

```bash
mise //mobile:install:ci
mise //mobile:codegen
mise //mobile:analyze
mise //mobile:test
```

Check all three iOS schemes and Android flavors after changes to native project
configuration. A source update does not update a running server or publish a
mobile build; deployment and signed releases are separate operations.

## iOS simulator validation

With the local Xcode 27.2 setup, `flutter build ios --simulator` passes an
explicit `-sdk iphonesimulator` to Xcode. This builds `StructuredQueriesMacros`
for the simulator instead of the macOS host and fails with a malformed macro
response. The `personal` simulator build succeeds by selecting the destination
directly, without the SDK override. From `mobile/ios/`:

```bash
xcodebuild -workspace Runner.xcworkspace -scheme personal \
  -configuration Debug-personal \
  -destination 'generic/platform=iOS Simulator' \
  BUILD_DIR="$(pwd)/../build/ios" CODE_SIGNING_ALLOWED=NO
```
