// Uses the same native transport and input arbitration as the playable game.
use c_import("raylib.h")
use std.process.env
use gamepads
use input
use game

fn stick_view(center: Vector2, value: V2, tint: Color):
    DrawCircleLinesV(center, 76.0, Color { r: 48, g: 63, b: 92, a: 255 })
    DrawCircleLinesV(center, 15.2, Color { r: 30, g: 41, b: 62, a: 255 })
    let tip = Vector2 { x: center.x + value.x as f32 * 76.0, y: center.y + value.y as f32 * 76.0 }
    DrawLineEx(center, tip, 2.0, tint)
    DrawCircleV(tip, 7.0, tint)

fn main -> i32:
    SetTraceLogLevel(LOG_WARNING)
    SetConfigFlags(FLAG_MSAA_4X_HINT)
    InitWindow(720, 420, "WIPE | Native controller acceptance")
    if not IsWindowReady(): return 1
    defer: CloseWindow()
    var pads = match Gamepads.open():
        Ok(controllers) => controllers
        Err(message) => { eprint(message); return 1 }
    SetTargetFPS(60)
    let bounded = env("WIPE_CONTROLLER_CHECK") == "1"
    var frames = 0
    var samples = 0
    var total_us = 0.0
    var peak_us = 0.0
    var previous_id: u32 = 0
    var connected = false
    var moved = false
    var aimed = false
    var retried = false
    var previous = V2 { x: 1.0 }
    var input = Input { pad_aim: true }
    while not WindowShouldClose():
        let started = GetTime()
        let pad = pads.poll()
        let poll_us = (GetTime() - started) * 1000000.0
        // Exclude device discovery and initial warm-up from steady-state timing.
        if frames >= 60 and pad.id != 0 and pad.id == previous_id:
            samples += 1
            total_us += poll_us
            if poll_us > peak_us: peak_us = poll_us
        previous_id = pad.id
        if pad.id != 0: connected = true
        let controls = input.resolve(V2 {}, V2 {}, V2 {}, previous, pad)
        previous = controls.aim
        if not moved and length2(controls.motion) > 0.1:
            moved = true
            eprint("Controller UAT: left stick observed")
        if not aimed and length2(stick(pad.aim.x, pad.aim.y)) > 0.1:
            aimed = true
            eprint("Controller UAT: right stick observed")
        if not retried and pad.retry:
            retried = true
            eprint("Controller UAT: A / south press observed")
        BeginDrawing()
        ClearBackground(Color { r: 5, g: 9, b: 20, a: 255 })
        DrawText("NATIVE CONTROLLER", 36, 28, 28, RAYWHITE)
        DrawText(if pad.id != 0: "Connected through SDL3" else: "Waiting for a controller...", 36, 70, 18, if pad.id != 0: LIME else: GOLD)
        DrawText("MOVE", 168, 122, 18, SKYBLUE)
        DrawText("AIM", 511, 122, 18, MAGENTA)
        stick_view(Vector2 { x: 192.0, y: 230.0 }, controls.motion, SKYBLUE)
        stick_view(Vector2 { x: 528.0, y: 230.0 }, stick(pad.aim.x, pad.aim.y), MAGENTA)
        DrawText(if moved: "Left stick: checked" else: "Move the left stick", 100, 324, 18, if moved: LIME else: GRAY)
        DrawText(if aimed: "Right stick: checked" else: "Move the right stick", 436, 324, 18, if aimed: LIME else: GRAY)
        DrawText(if retried: "A / south: checked" else: "Press A / south to check retry", 36, 376, 18, if retried: LIME else: GRAY)
        DrawText("ESC TO CLOSE", 542, 378, 14, GRAY)
        EndDrawing()
        frames += 1
        if bounded and frames == 180:
            TakeScreenshot("out/uat/controller.png")
            break
    print(f"Controller UAT: connected={connected}, left={moved}, right={aimed}, retry={retried}")
    if samples > 0: print(f"Native input polling: samples={samples}, mean_us={total_us / samples as f64}, peak_us={peak_us}")
    if connected: 0 else: 1
