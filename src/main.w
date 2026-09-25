use c_import("raylib.h")
use game
use presentation
use input
use audio

fn main:
    SetTraceLogLevel(LOG_WARNING)
    SetConfigFlags(FLAG_MSAA_4X_HINT)
    InitWindow(WIDTH, HEIGHT, "WIPE: SURVIVAL | built with With")
    if not IsWindowReady():
        eprint("WIPE could not create a graphics context.")
        return 1
    defer: CloseWindow()
    SetTargetFPS(60)
    InitAudioDevice()
    defer: CloseAudioDevice()
    let sound = if IsAudioDeviceReady(): Some(Audio.open()) else: None
    if let Some(bank) = &sound:
        if not bank.valid():
            eprint("WIPE: missing audio assets; rebuild to restore out/bin/assets.")
            return 1
    let renderer = Renderer.open()
    if not renderer.valid():
        eprint("WIPE could not allocate its presentation surfaces.")
        return 1
    var game = Game.new()
    var input = Input {}
    var debug = false
    var best = 0.0
    var accumulator = 0.0
    var frame_ms = 16.67
    while not WindowShouldClose():
        let elapsed = GetFrameTime() as f64
        frame_ms += (elapsed * 1000.0 - frame_ms) * 0.05
        if IsKeyPressed(KEY_F1): debug = not debug
        if IsKeyPressed(KEY_F3) and game.health > 0:
            game.stress()
            debug = true
        let pad = active_pad()
        let retry = IsKeyPressed(KEY_SPACE) or (pad >= 0 and IsGamepadButtonPressed(pad, GAMEPAD_BUTTON_RIGHT_FACE_DOWN))
        if game.health <= 0 and retry:
            game.reset()
            accumulator = 0.0
        let controls = input.sample(game.player, game.aim)
        game.clear_events()
        // Bound catch-up after a stall; input is sampled before fixed steps.
        accumulator += limit(elapsed, 0.0, 0.1)
        while accumulator >= 1.0 / 120.0:
            game.tick(controls, 1.0 / 120.0)
            accumulator -= 1.0 / 120.0
        if game.elapsed > best: best = game.elapsed
        if let Some(bank) = &sound: bank.play(game, GetTime())
        let _ = renderer.draw(game, GetTime(), debug, frame_ms, best)
    0
