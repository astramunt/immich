# Native video player

This package contains the runtime source of Immich's fork of
[native_video_player](https://github.com/immich-app/native_video_player/tree/cdf621bdb7edaf996e118a58a48f6441187d79c6),
at commit `cdf621bdb7edaf996e118a58a48f6441187d79c6`. The upstream license is in
[LICENSE](LICENSE).

The local change exposes AVFoundation frame stepping to the Flutter video
viewer on iOS. Android playback uses the upstream implementation.
