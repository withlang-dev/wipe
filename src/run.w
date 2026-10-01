use c_import("raylib.h")
use game
use presentation
use gamepads
use audio
use app
use record
use platform
use settings
use devices
use platform_session

// The game, on any platform: the plain build passes NoPlatform (src/main.w),
// the Steam build SteamPlatform (src/main_steam.w). A platform is opened
// before the window, so a store overlay can hook the context it creates.
pub fn run[P: Platform](opened: P) -> i32:
    var session = PlatformSession { backend: opened }
    SetTraceLogLevel(LOG_WARNING)
    // Hidden until it has the view's size: the screen is only known once the
    // window system is up.
    SetConfigFlags((FLAG_MSAA_4X_HINT | FLAG_WINDOW_HIDDEN | FLAG_VSYNC_HINT | FLAG_WINDOW_HIGHDPI) as u32)
    InitWindow(WIDTH, HEIGHT, "WIPE: SURVIVAL | built with With")
    if not IsWindowReady():
        eprint("WIPE could not create a graphics context.")
        return 1
    let window_device = WindowDevice {}
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
    ClearWindowState(FLAG_WINDOW_HIDDEN as u32)
    // Escape is a game input (pause, back, quit on the title), never an exit key.
    SetExitKey(KEY_NULL)
    var pads = match Gamepads.open(platform_managed: session.backend.manages_controllers()):
        Ok(controllers) => controllers
        Err(message) => { eprint(f"WIPE could not initialize controllers: {message}"); return 1 }
    InitAudioDevice()
    let audio_device = AudioDevice {}
    let sound = if IsAudioDeviceReady(): Some(Audio.open()) else: None
    if let Some(bank) = &sound:
        if not bank.valid():
            eprint("WIPE: missing audio assets; rebuild to restore out/bin/assets.")
            return 1
    var renderer = Renderer.open(view_w, view_h)
    if not renderer.valid():
        eprint("WIPE could not allocate its presentation surfaces.")
        return 1
    // The save is read before the first frame; launching is loading.
    var wipe = App.open()
    wipe.set_view(view_w, view_h)
    wipe.platform_notice = session.backend.notice()
    if wipe.platform_notice.len() > 0: eprint(f"WIPE: {wipe.platform_notice}")
    var sync_timer = 0.0
    while not WindowShouldClose() and not wipe.quit:
        let events = session.backend.frame()
        if events.overlay_opened or events.overlay_active: wipe.pause_for_overlay()
        if not events.blocks_input() and IsKeyPressed(KEY_F11): wipe.toggle_fullscreen()
        // Borderless at the desktop resolution: the view has the screen's
        // aspect ratio, so it fills it at one scale. On a Deck it is the panel.
        if wipe.settings.fullscreen != IsWindowState(FLAG_BORDERLESS_WINDOWED_MODE as u32): ToggleBorderlessWindowed()
        if wipe.settings.vsync != IsWindowState(FLAG_VSYNC_HINT as u32):
            if wipe.settings.vsync: SetWindowState(FLAG_VSYNC_HINT as u32)
            else: ClearWindowState(FLAG_VSYNC_HINT as u32)
        SetTargetFPS(frame_target(&wipe.settings, GetMonitorRefreshRate(GetCurrentMonitor())))
        if not renderer.resize_output(GetRenderWidth(), GetRenderHeight()):
            eprint("WIPE could not resize its presentation surfaces.")
            return 1
        // One long frame (the first after the Deck wakes from sleep, a window
        // drag) must not jump the menus or the attract run: at most 0.1 s.
        let elapsed = limit(GetFrameTime() as f64, 0.0, 0.1)
        wipe.frame_ms += (elapsed * 1000.0 - wipe.frame_ms) * 0.05
        if not events.blocks_input() and IsKeyPressed(KEY_F3) and wipe.screen == .Run and wipe.game.phase == .Running:
            wipe.rec.event("x 1800")
            wipe.game.stress(1800)
            wipe.debug = true
        let pad = pads.poll()
        // Poll controllers even while covered so held/pressed edges are
        // consumed, but never let an overlay button resume the run.
        if not events.blocks_input(): wipe.update(pad, elapsed)
        else: wipe.clear_frame_events()
        // Achievements are facts of the save; the platform mirrors them about
        // once a second (a run's are judged as if it ended now).
        sync_timer -= elapsed
        if sync_timer <= 0.0:
            sync_timer = 1.0
            session.backend.sync_achievements(&wipe.achievements_now())
        SetMasterVolume(wipe.settings.volume as f32)
        if let Some(bank) = &sound: bank.play(&wipe.game, wipe.ui_move, wipe.ui_confirm or wipe.ui_buy, GetTime())
        let _ = wipe.draw(&renderer, GetTime())
    session.backend.sync_achievements(&wipe.achievements_now())
    0
