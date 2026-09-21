# Private mobile app variants

The mobile project provides three installable flavors. Their Flutter code and
runtime configuration are shared; only the application name, icon, bundle or
package identifier, and iOS App Group differ.

| Flavor | App name | Android application ID | iOS bundle ID | Icon accent |
| --- | --- | --- | --- | --- |
| `personal` | Immich Personal | `com.astramunt.apps.immich.personal` | `com.astramunt.apps.immich.personal` | light blue |
| `private` | Immich Private | `com.astramunt.apps.immich.private` | `com.astramunt.apps.immich.private` | purple |
| `daem` | Immich Daem | `com.astramunt.apps.immich.daem` | `com.astramunt.apps.immich.daem` | red |

## Build or run a variant

From `mobile/`, select the variant with Flutter:

```bash
flutter run --flavor personal
flutter build apk --flavor private
flutter build ipa --flavor daem
```

In Xcode, select the shared `personal`, `private`, or `daem` scheme. The share
and widget extensions inherit the matching bundle prefix and App Group, so the
three installations do not share their local extension data.

The variants have distinct bundle identifiers. Register their App IDs and App
Groups in the Apple Developer account before producing a signed device build.
