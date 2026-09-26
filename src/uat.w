// Desktop acceptance/recording entry point, separate from the playable game.
// Only this fixture disables contact damage and supplies scripted controls.
use c_import("raylib.h")
use game
use presentation
use audio
use std.process.env
use metrics
use gamepads

fn pilot(g: &Game, frame: i32) -> Controls:
    let t = frame as f64 / 60.0
    let c = g.center()
    let goal = V2 { x: c.x + cos(t * 0.7) * 310.0, y: c.y + sin(t * 0.7) * 210.0 }
    var aim = V2 { x: cos(t * 2.3), y: sin(t * 2.3) }
    var nearest = 10000000.0
    for e in 0..g.enemy_count:
        let delta = sub(g.enemies[e].pos, g.player)
        if length2(delta) < nearest:
            nearest = length2(delta)
            aim = delta
    Controls { motion: scale(sub(goal, g.player), 1.0 / 70.0), aim }

fn main:
    SetTraceLogLevel(LOG_WARNING)
    SetConfigFlags(FLAG_MSAA_4X_HINT)
    InitWindow(WIDTH, HEIGHT, "WIPE: SURVIVAL | acceptance run")
    if not IsWindowReady(): return 1
    defer: CloseWindow()
    var pads = match Gamepads.open():
        Ok(controllers) => controllers
        Err(message) => { eprint(message); return 1 }
    let benchmark = env("WIPE_BENCH") == "1"
    let recording = env("WIPE_RECORD") == "1"
    let pace = if recording: 3 else: 1
    SetTargetFPS(if benchmark or recording: 0 else: 60)
    InitAudioDevice()
    defer: CloseAudioDevice()
    let sound = if IsAudioDeviceReady(): Some(Audio.open()) else: None
    let renderer = Renderer.open()
    if not renderer.valid(): return 1
    if let Some(bank) = &sound:
        if not bank.valid(): return 1
    var ordinary = Metric {}
    var stress = Metric {}
    var maximum = Metric {}
    var updates = Metric {}
    var renders = Metric {}
    var restarts = Metric {}
    var frame = 0
    var captured = false
    var capture_at = -1
    var last_capture = -10
    var g = Game.new()
    g.rules.contact_radius = 0.0
    var debug = false
    var frame_ms = 16.67
    var peak_particles = 0
    var peak_enemies = 0
    while not WindowShouldClose():
        // Include the production controller polling cost in frame measurements.
        let _ = pads.poll()
        let raw_dt = GetFrameTime() as f64
        frame_ms += (raw_dt * 1000.0 - frame_ms) * 0.05
        g.clear_events()
        if frame >= 30 * pace and frame < 360 * pace: g.stress(if recording: 90 else: 150)
        if frame == 360 * pace:
            g.reset()
            debug = true
        if frame >= 360 * pace and frame < 540 * pace: g.stress(350)
        if frame == 540 * pace:
            g.health = 1
            g.invulnerable = 0.0
            g.hurt(Kind.Dart, false, 5)
        if frame == 600 * pace:
            let started = GetTime()
            g.reset()
            restarts.add((GetTime() - started) * 1000.0)
            debug = false
        if frame >= 660 * pace:
            debug = true
            g.stress(1800)
            let tint: Tint = match frame % 3:
                0 => .Cyan
                1 => .Magenta
                _ => .Gold
            g.burst(g.player, g.aim, 50, tint, 1.0)
        let controls = pilot(g, frame)
        let update_start = GetTime()
        for _ in 0..2: g.tick(controls, 1.0 / 120.0)
        let update_ms = (GetTime() - update_start) * 1000.0
        // Boosts are taken at once; the harness measures the arena, not menus.
        while g.phase == .Boost: g.choose(0)
        if g.particle_count > peak_particles: peak_particles = g.particle_count
        if g.enemy_count > peak_enemies: peak_enemies = g.enemy_count
        let clock = if recording: frame as f64 / 60.0 else: GetTime()
        if not recording:
            if let Some(bank) = &sound: bank.play(g, false, false, clock)
        let cam = renderer.begin_world(g, clock, 1.0)
        let info = DebugInfo { frame_ms, metrics: Vec.new() }
        renderer.draw_run(g, cam, Hud {}, 0, clock, if debug and not recording: Some(&info) else: None)
        let render_ms = renderer.present()
        if not recording and frame > 60 and frame > last_capture + 2:
            updates.add(update_ms)
            renders.add(render_ms)
            // Readback/PNG writing extends the following frame's update;
            // GetFrameTime observes that interval one frame later.
            if frame < 360: ordinary.add(raw_dt * 1000.0)
            if frame > 380 and frame < 540: stress.add(raw_dt * 1000.0)
            if frame > 690: maximum.add(raw_dt * 1000.0)
        if not benchmark and not recording:
            if not captured and capture_at < 0 and frame > 140 and frame < 300 and g.kill_event:
                capture_at = frame + 5
            if frame == capture_at:
                TakeScreenshot("out/uat/gameplay.png")
                last_capture = frame
                captured = true
            if frame == 420:
                TakeScreenshot("out/uat/stress.png")
                last_capture = frame
            if frame == 544: TakeScreenshot("out/uat/death.png")
            if frame == 610: TakeScreenshot("out/uat/restart.png")
        if recording:
            if frame % 2 == 0: TakeScreenshot(f"out/uat/frames/frame_{frame / 2}.png")
            if g.shot_event or g.hit_event or g.kill_event or g.hurt_event or g.death_event:
                print(f"SFX {frame} {if g.shot_event: 1 else: 0} {if g.hit_event: 1 else: 0} {if g.kill_event: 1 else: 0} {if g.hurt_event: 1 else: 0} {if g.death_event: 1 else: 0}")
        frame += 1
        if frame >= (if recording: 660 * pace else: 1020): break
    if not recording:
        print(f"Observed peaks: enemies={peak_enemies} particles={peak_particles}")
        ordinary.report("150 enemies / frame")
        stress.report("350 enemies / frame")
        maximum.report("1800 enemies + sustained particles / frame")
        updates.report("simulation CPU")
        renders.report("render submission CPU (excludes EndDrawing)")
        restarts.report("restart CPU")
    0
