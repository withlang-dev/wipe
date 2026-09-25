use std.build
use std.sysinfo.os

fn native_target(kind: BuildKind, name: str, entry: str) -> Target:
    var target = target_new(kind, name, entry)
    // With's Conan reader currently omits SDL's option-guarded Apple frameworks.
    // These are SDK libraries required by the pinned static SDL package.
    if os() == "Macos":
        for framework in ["CoreVideo", "Foundation", "Cocoa", "Carbon", "CoreAudio", "AudioToolbox", "AVFoundation", "UniformTypeIdentifiers", "CoreMedia", "GameController", "CoreHaptics", "ForceFeedback", "IOKit", "Metal", "QuartzCore"]:
            target = (move target).link_system_lib("framework:" ++ framework)
    target

fn game_target(name: str, entry: str) -> Target:
    native_target(.Executable, name, entry).dep("audio").dep("shaders").input("src/game.w").input("src/input.w").input("src/gamepads.w").input("src/sdl.w").input("src/presentation.w").input("src/audio.w").input("src/metrics.w").input("src/tuning.w").input("src/shaders.w").input("src/paths.w")

pub fn build(ctx: BuildCtx) -> Build:
    ctx.new_build().add_target(
        target_new(.CopyTree, "shaders", "assets/shaders").output("out/bin/assets/shaders").input("grid.fs").input("bright.fs").input("blur.fs").input("composite.fs")
    ).add_target(
        target_new(.CopyTree, "audio", "assets/audio").output("out/bin/assets/audio").input("shot.wav").input("hit.wav").input("kill.wav").input("hurt.wav").input("death.wav").input("ambient_house.wav")
    ).add_target(game_target("wipe", "src/main.w")).add_target(
        game_target("uat", "src/uat.w")
    ).add_target(
        game_target("audio-uat", "src/audio_uat.w")
    ).add_target(
        native_target(.Executable, "controller-uat", "src/controller_uat.w").input("src/gamepads.w").input("src/input.w").input("src/sdl.w")
    ).add_target(native_target(.Test, "test", "test/*.w")).default("wipe")
