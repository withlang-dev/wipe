use std.build
use std.sysinfo.{os, arch}
use steam_config

fn native_target(kind: BuildKind, name: str, entry: str) -> Target:
    var target = target_new(kind, name, entry)
    // With's Conan reader currently omits SDL's option-guarded Apple frameworks.
    // These are SDK libraries required by the pinned static SDL package.
    if os() == "Macos":
        for framework in ["CoreVideo", "Foundation", "Cocoa", "Carbon", "CoreAudio", "AudioToolbox", "AVFoundation", "UniformTypeIdentifiers", "CoreMedia", "GameController", "CoreHaptics", "ForceFeedback", "IOKit", "Metal", "QuartzCore"]:
            target = (move target).link_system_lib("framework:" ++ framework)
    // Likewise its Windows system libraries: input methods (imm32) and
    // controller device discovery (setupapi, cfgmgr32).
    if os() == "Windows":
        for system_lib in ["imm32", "setupapi", "cfgmgr32"]:
            target = (move target).link_system_lib(system_lib.clone())
    target

fn game_target(name: str, entry: str) -> Target:
    native_target(.Executable, name, entry).dep("audio").dep("shaders").input("src/game.w").input("src/input.w").input("src/gamepads.w").input("src/sdl.w").input("src/presentation.w").input("src/audio.w").input("src/devices.w").input("src/metrics.w").input("src/tuning.w").input("src/loadout.w").input("src/ships.w").input("src/save.w").input("src/settings.w").input("src/achievements.w").input("src/platform.w").input("src/platform_session.w").input("src/run.w").input("src/account.w").input("src/pilots.w").input("src/record.w").input("src/app.w").input("src/shaders.w").input("src/paths.w")

fn steam_library_dir() -> str:
    let root = "vendor/steamworks/redistributable_bin/"
    if os() == "Macos": root ++ "osx"
    else if os() == "Windows": root ++ "win64"
    else if arch() == "aarch64": root ++ "linuxarm64"
    else: root ++ "linux64"

fn steam_library_name() -> str:
    if os() == "Macos": "libsteam_api.dylib"
    else if os() == "Windows": "steam_api64.dll"
    else: "libsteam_api.so"

fn check_steam_sdk(ctx: ActionCtx) -> i32:
    if not ctx.fs().exists("vendor/steamworks/public/steam/steam_api_flat.h"):
        eprint("The optional Steam build needs SDK 1.65 headers. See vendor/steamworks/README.md; the plain wipe target does not need them.")
        return 1
    if os() != "Macos" and os() != "Linux" and os() != "Windows":
        eprint("No Steam redistributable is configured for this host.")
        return 1
    if ctx.fs().mkdir_all("out") != 0: return 1
    ctx.fs().write_text(ctx.output(), "Steamworks SDK headers available\n")

fn steam_target(name: str, entry: str) -> Target:
    var target = game_target(name, entry).dep("steam-sdk").dep("steam-library")
    target = (move target).include_path("vendor/steamworks/public").library_path(steam_library_dir())
    target = (move target).input("src/steam.w").input("src/steam_config.w").input("src/achievement_sync.w").input("vendor/steamworks/public/steam/steam_api_flat.h")
    if os() == "Linux": target = (move target).rpath("$ORIGIN")
    if os() == "Macos": target = (move target).rpath("@executable_path")
    // The SDK's Windows import library is named steam_api64, while the
    // source import uses the same link name on every platform.
    if os() == "Windows": target = (move target).dep("steam-import-library").library_path("out/steam-link")
    target

fn package_game(ctx: ActionCtx, steam: bool) -> i32:
    if steam and (STEAM_APP_ID == 0 or STEAM_APP_ID == 480):
        eprint("Set WIPE's assigned App ID in src/steam_config.w before packaging a Steam release. Spacewar and development App IDs cannot ship.")
        return 1
    let flavor = if steam: "steam" else: "plain"
    let directory = "out/package/" ++ flavor
    let executable = (if steam: "wipe-steam" else: "wipe") ++ (if os() == "Windows": ".exe" else: "")
    // Package from an explicit allowlist, never all of out/bin (which may
    // also contain Steam's library, test tools, or steam_appid.txt).
    if ctx.fs().exists(directory) and ctx.fs().remove_tree(directory) != 0: return 1
    if ctx.fs().mkdir_all(directory) != 0: return 1
    if ctx.fs().copy_file("out/bin/" ++ executable, directory ++ "/" ++ executable) != 0: return 1
    if os() != "Windows" and ctx.fs().chmod(directory ++ "/" ++ executable, 493) != 0: return 1
    // Stage the current source assets, not leftovers from older output layouts.
    if ctx.fs().mkdir_all(directory ++ "/assets") != 0: return 1
    for asset_dir in ["audio", "shaders"]:
        if ctx.fs().copy_tree("assets/" ++ asset_dir, directory ++ "/assets/" ++ asset_dir) != 0: return 1
    if steam and ctx.fs().copy_file("out/bin/" ++ steam_library_name(), directory ++ "/" ++ steam_library_name()) != 0: return 1
    print("Packaged " ++ flavor ++ " game in " ++ directory)
    0

fn package_plain(ctx: ActionCtx) -> i32: package_game(ctx, false)
fn package_steam(ctx: ActionCtx) -> i32: package_game(ctx, true)

pub fn build(ctx: BuildCtx) -> Build:
    var sdk = target_new(.Action, "steam-sdk", "").output("out/steam-sdk.checked")
    sdk.action = check_steam_sdk
    var plain_package = target_new(.Action, "package", "").dep("wipe").input("assets/audio").input("assets/shaders").output("out/package/plain")
    plain_package.action = package_plain
    var steam_package = target_new(.Action, "package-steam", "").dep("wipe-steam").input("src/steam_config.w").input("assets/audio").input("assets/shaders").input(steam_library_dir() ++ "/" ++ steam_library_name()).output("out/package/steam")
    steam_package.action = package_steam
    ctx.new_build().add_target(sdk).add_target(plain_package).add_target(steam_package).add_target(
        target_new(.CopyFile, "steam-library", steam_library_dir() ++ "/" ++ steam_library_name()).output("out/bin/" ++ steam_library_name())
    ).add_target(
        target_new(.CopyFile, "steam-import-library", "vendor/steamworks/redistributable_bin/win64/steam_api64.lib").output("out/steam-link/steam_api.lib")
    ).add_target(steam_target("wipe-steam", "src/main_steam.w")).add_target(
        steam_target("steam-uat", "src/steam_uat.w")
    ).add_target(
        target_new(.CopyTree, "shaders", "assets/shaders").output("out/bin/assets/shaders").input("grid.fs").input("bright.fs").input("blur.fs").input("composite.fs")
    ).add_target(
        target_new(.CopyTree, "audio", "assets/audio").output("out/bin/assets/audio").input("shot.wav").input("hit.wav").input("kill.wav").input("hurt.wav").input("death.wav").input("ambient_house.wav").input("core.wav").input("pickup.wav").input("zap.wav")
    ).add_target(game_target("wipe", "src/main.w")).add_target(
        game_target("uat", "src/uat.w")
    ).add_target(
        game_target("tour", "src/tour.w")
    ).add_target(
        game_target("gallery", "src/gallery.w")
    ).add_target(
        game_target("play", "src/play.w")
    ).add_target(
        game_target("balance", "src/balance.w")
    ).add_target(
        game_target("odds", "src/odds.w")
    ).add_target(
        game_target("bosses", "src/bosses.w")
    ).add_target(
        game_target("runs", "src/runs.w")
    ).add_target(
        game_target("audio-uat", "src/audio_uat.w")
    ).add_target(
        native_target(.Executable, "controller-uat", "src/controller_uat.w").input("src/devices.w").input("src/gamepads.w").input("src/input.w").input("src/sdl.w")
    ).add_target(native_target(.Test, "test", "test/*.w")).default("wipe")
