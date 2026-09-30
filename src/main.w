use c_import("raylib.h")
use game
use presentation
use gamepads
use audio
use app
use record

fn main:
    SetTraceLogLevel(LOG_WARNING)
    // Hidden until it has the view's size: the screen is only known once the
    // window system is up.
    SetConfigFlags(FLAG_MSAA_4X_HINT | FLAG_WINDOW_HIDDEN)
    InitWindow(WIDTH, HEIGHT, "WIPE: SURVIVAL | built with With")
    if not IsWindowReady():
        eprint("WIPE could not create a graphics context.")
        return 1
    defer: CloseWindow()
    // The view takes the screen's aspect ratio (1280x800 on a Steam Deck,
    // 1422x800 on 16:9), so fullscreen fills the screen at one scale with
    // nothing stretched, squashed or barred. A window shows the view 1:1,
    // shrunk uniformly only when the screen cannot hold it.
    let monitor = GetCurrentMonitor()
    let (screen_w, screen_h) = (GetMonitorWidth(monitor), GetMonitorHeight(monitor))
    let (view_w, view_h) = view_size(screen_w, screen_h)
    let room_x = screen_w as f64 * 0.9 / view_w as f64
    let room_y = screen_h as f64 * 0.9 / view_h as f64
    let room = if room_x < room_y: room_x else: room_y
    let shrink = if room > 0.0 and room < 1.0: room else: 1.0
    let (window_w, window_h) = ((view_w as f64 * shrink) as i32, (view_h as f64 * shrink) as i32)
    SetWindowSize(window_w, window_h)
    let origin = GetMonitorPosition(monitor)
    SetWindowPosition(origin.x as i32 + (screen_w - window_w) / 2, origin.y as i32 + (screen_h - window_h) / 2)
    ClearWindowState(FLAG_WINDOW_HIDDEN)
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
    let renderer = Renderer.open(view_w, view_h)
    if not renderer.valid():
        eprint("WIPE could not allocate its presentation surfaces.")
        return 1
    // The save is read before the first frame; launching is loading.
    var wipe = App.open()
    wipe.set_view(view_w, view_h)
    while not WindowShouldClose() and not wipe.quit:
        if IsKeyPressed(KEY_F11): wipe.toggle_fullscreen()
        // Borderless at the desktop resolution; the renderer stretches the
        // 1280x800 scene over it. On a Steam Deck the window is the panel.
        if wipe.settings.fullscreen != IsWindowState(FLAG_BORDERLESS_WINDOWED_MODE): ToggleBorderlessWindowed()
        // One long frame (the first after the Deck wakes from sleep, a window
        // drag) must not jump the menus or the attract run: at most 0.1 s.
        let elapsed = limit(GetFrameTime() as f64, 0.0, 0.1)
        wipe.frame_ms += (elapsed * 1000.0 - wipe.frame_ms) * 0.05
        if IsKeyPressed(KEY_F3) and wipe.screen == .Run and wipe.game.phase == .Running:
            wipe.rec.event("x 1800")
            wipe.game.stress(1800)
            wipe.debug = true
        let pad = pads.poll()
        wipe.update(pad, elapsed)
        SetMasterVolume(wipe.settings.volume as f32)
        if let Some(bank) = &sound: bank.play(&wipe.game, wipe.ui_move, wipe.ui_confirm or wipe.ui_buy, GetTime())
        let _ = wipe.draw(&renderer, GetTime())
    0
