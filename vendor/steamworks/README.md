# Steamworks SDK 1.65 (vendored redistributables)

`redistributable_bin/` holds Valve's `libsteam_api` for every platform,
from Steamworks SDK 1.65 (released 2026-07-23). Copyright Valve
Corporation. The Steamworks SDK terms permit redistributing these
libraries with the game. They permit nothing else from the SDK, so the
rest of the SDK is not in this repository.

| Platform | Library |
|---|---|
| Linux x86_64 (Steam Deck, desktop Linux) | `redistributable_bin/linux64/libsteam_api.so` |
| Linux arm64 | `redistributable_bin/linuxarm64/libsteam_api.so` |
| Linux x86 | `redistributable_bin/linux32/libsteam_api.so` |
| macOS (x86_64 and arm64) | `redistributable_bin/osx/libsteam_api.dylib` |
| Windows x64 | `redistributable_bin/win64/steam_api64.dll`, `steam_api64.lib` |
| Windows x86 | `redistributable_bin/steam_api.dll`, `steam_api.lib` |
| Android arm64 | `redistributable_bin/androidarm64/libsteam_api.so` |

## The headers are local to each build machine

The `wipe-steam` target also needs the SDK headers. They are not
redistributable, so each machine that builds `wipe-steam` supplies its own
copy:

1. Download `steamworks_sdk_165.zip` from the Steamworks partner site
   (SDK Releases). This needs a Steamworks account with access to the SDK.
2. Extract `sdk/public/steam/` to `vendor/steamworks/public/steam/`:

   ```sh
   unzip steamworks_sdk_165.zip 'sdk/public/steam/*' -x 'sdk/public/steam/lib/*' -d /tmp/sdk165
   mkdir -p vendor/steamworks/public
   cp -R /tmp/sdk165/sdk/public/steam vendor/steamworks/public/
   ```

`.gitignore` excludes `vendor/steamworks/public/`, so the headers are
never committed. Nothing derived from them is committed either.

The plain `wipe` target uses neither the headers nor the libraries. It
builds on every platform from a plain clone.

## Loading

The macOS library's install name is `@loader_path/libsteam_api.dylib`, so
it is found beside the executable. On Linux the executable needs an
`$ORIGIN` rpath (see `docs/steam-and-steam-deck-support.md`).

## Updating

Replace `redistributable_bin/` from the new SDK zip, change the version
above and in step 1, and refresh the local headers on every build machine.
