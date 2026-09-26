// Screenshot tour: every screen of spec §11 against a scratch save, for
// review and for the verification record. Set WIPE_SAVE_DIR to a scratch path.
use c_import("raylib.h")
use game
use loadout
use ships
use save
use account
use presentation
use app
use std.process.env

fn frames(wipe: &App, renderer: &Renderer, count: i32, clock: f64) -> f64:
    var t = clock
    for _ in 0..count:
        let _ = wipe.draw(renderer, t)
        t += 1.0 / 60.0
    t

fn main:
    SetTraceLogLevel(LOG_WARNING)
    SetConfigFlags(FLAG_MSAA_4X_HINT)
    InitWindow(WIDTH, HEIGHT, "WIPE: SURVIVAL | tour")
    if not IsWindowReady(): return 1
    defer: CloseWindow()
    SetExitKey(KEY_NULL)
    SetTargetFPS(0)
    if env("WIPE_SAVE_DIR").len() == 0:
        eprint("tour: set WIPE_SAVE_DIR to a scratch directory")
        return 1
    let renderer = Renderer.open()
    if not renderer.valid(): return 1
    var wipe = App.open()
    // A seasoned account: some ships, ranks, and a registry.
    wipe.save.credits = 1988
    wipe.save.best_time[0] = 1152.0
    wipe.save.best_time[1] = 640.0
    wipe.save.runs = 23
    wipe.save.kills = 18230
    wipe.save.ranks[0] = 2
    wipe.save.ranks[5] = 3
    wipe.save.ranks[14] = 1
    wipe.save.spent = 1200
    wipe.save.best_hits_survived = 20
    wipe.save.cores = 3100
    wipe.save.best_combo = 44
    wipe.save.registry_kills = [9000, 1200, 5400, 800, 120, 0, 3, 0]
    wipe.save.registry_first = [0.1, 5.2, 2.0, 5.4, 8.1, -1.0, 5.0, -1.0]
    wipe.save.taken_weapons[8] = true
    wipe.save.cleared[0] = true
    wipe.save.clears = 1
    var clock = 10.0
    wipe.screen = .Title
    for _ in 0..240: wipe.update(PadFrame {}, 1.0 / 60.0)
    clock = frames(&wipe, &renderer, 3, clock)
    TakeScreenshot("out/tour/1-title.png")
    wipe.screen = .Select
    wipe.ship_cursor = 2
    clock = frames(&wipe, &renderer, 3, clock)
    TakeScreenshot("out/tour/2-select.png")
    wipe.ship_cursor = 5
    clock = frames(&wipe, &renderer, 3, clock)
    TakeScreenshot("out/tour/3-select-locked.png")
    // A run: a minute of scripted flight, then a boost.
    wipe.launch_as(.Claw)
    wipe.game.launch.best_time = 1152.0
    wipe.game.rules.contact_radius = 0.0
    for i in 0..(120 * 150):
        let t = i as f64 / 120.0
        let c = wipe.game.center()
        let goal = V2 { x: c.x + cos(t * 0.4) * 500.0, y: c.y + sin(t * 0.4) * 350.0 }
        let controls = Controls { motion: scale(sub(goal, wipe.game.player), 1.0 / 60.0), aim: V2 { x: cos(t * 1.7), y: sin(t * 1.7) } }
        wipe.game.clear_events()
        wipe.game.tick(controls, 1.0 / 120.0)
        if wipe.game.phase == .Boost: wipe.game.choose(0)
    clock = frames(&wipe, &renderer, 3, clock)
    TakeScreenshot("out/tour/4-run.png")
    wipe.game.gain_xp(wipe.game.xp_next)
    wipe.game.tick(Controls {}, 1.0 / 120.0)
    wipe.boost_cursor = 1
    clock = frames(&wipe, &renderer, 3, clock)
    TakeScreenshot("out/tour/5-boost.png")
    while wipe.game.phase == .Boost: wipe.game.choose(0)
    // Late run density.
    wipe.game.elapsed = 900.0
    wipe.game.stress(1500)
    for _ in 0..240:
        wipe.game.clear_events()
        wipe.game.tick(Controls { aim: V2 { x: 1.0 } }, 1.0 / 120.0)
        if wipe.game.phase == .Boost: wipe.game.choose(0)
    wipe.debug = true
    clock = frames(&wipe, &renderer, 3, clock)
    TakeScreenshot("out/tour/6-density.png")
    wipe.debug = false
    wipe.screen = .Pause
    clock = frames(&wipe, &renderer, 3, clock)
    TakeScreenshot("out/tour/7-pause.png")
    // Death and results.
    wipe.screen = .Run
    wipe.game.rules.contact_radius = 29.0
    wipe.game.health = 1
    wipe.game.invulnerable = 0.0
    wipe.game.freeze = 0.0
    wipe.game.hurt(Kind.Skimmer, false, 5)
    wipe.game.elapsed = 1120.0
    wipe.game.credits = 412
    wipe.finish_run()
    wipe.results.shown = GetTime() - 2.0
    clock = frames(&wipe, &renderer, 3, clock)
    TakeScreenshot("out/tour/8-results.png")
    wipe.screen = .Shop
    wipe.shop_cursor = 7
    clock = frames(&wipe, &renderer, 3, clock)
    TakeScreenshot("out/tour/9-shop.png")
    wipe.screen = .Collection
    wipe.tab = .Ships
    wipe.collection_cursor = 5
    clock = frames(&wipe, &renderer, 3, clock)
    TakeScreenshot("out/tour/10-collection.png")
    wipe.tab = .Registry
    wipe.collection_cursor = 4
    clock = frames(&wipe, &renderer, 3, clock)
    TakeScreenshot("out/tour/11-registry.png")
    print("tour done")
    0
