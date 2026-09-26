use c_import("raylib.h")
use game
use presentation
use gamepads
use audio
use app

fn main:
    SetTraceLogLevel(LOG_WARNING)
    SetConfigFlags(FLAG_MSAA_4X_HINT)
    InitWindow(WIDTH, HEIGHT, "WIPE: SURVIVAL | built with With")
    if not IsWindowReady():
        eprint("WIPE could not create a graphics context.")
        return 1
    defer: CloseWindow()
    // Escape is a game input (pause, back, quit on the title), never an exit key.
    SetExitKey(KEY_NULL)
    var pads = match Gamepads.open():
        Ok(controllers) => controllers
        Err(message) => { eprint(f"WIPE could not initialize controllers: {message}"); return 1 }
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
    // The save is read before the first frame; launching is loading.
    var wipe = App.open()
    while not WindowShouldClose() and not wipe.quit:
        let elapsed = GetFrameTime() as f64
        wipe.frame_ms += (elapsed * 1000.0 - wipe.frame_ms) * 0.05
        if IsKeyPressed(KEY_F3) and wipe.screen == .Run and wipe.game.phase == .Running:
            wipe.game.stress(1800)
            wipe.debug = true
        let pad = pads.poll()
        wipe.update(pad, elapsed)
        SetMasterVolume(wipe.save.volume as f32)
        if let Some(bank) = &sound: bank.play(&wipe.game, wipe.ui_move, wipe.ui_confirm or wipe.ui_buy, GetTime())
        let _ = wipe.draw(&renderer, GetTime())
    0
