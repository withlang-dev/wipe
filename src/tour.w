// Screenshot tour: every screen of spec §11 against a scratch save, for
// review and for the verification record. Set WIPE_SAVE_DIR to a scratch path.
use c_import("raylib.h")
use game
use loadout
use ships
use save
use devices
use account
use presentation
use app
use gamepads
use input
use std.process.env
use std.string.parse

fn frames(wipe: &App, renderer: &Renderer, count: i32, clock: f64) -> f64:
    var t = clock
    for _ in 0..count:
        let _ = wipe.draw(renderer, t)
        t += 1.0 / 60.0
    t

fn capture(path: &str):
    // raylib 6 TakeScreenshot multiplies the physical render size by DPI again.
    // LoadImageFromScreen reads the actual framebuffer dimensions directly.
    let image = LoadImageFromScreen()
    defer: UnloadImage(image)
    assert(IsImageValid(image))
    assert(image.width == GetRenderWidth() and image.height == GetRenderHeight())
    assert(ExportImage(image, path))
    print(f"capture: {path} {image.width}x{image.height}")

// Measure the actual bitmap alpha bounds, not its padded font cell. The
// lowercase body is the limiting case for the small UI labels.
fn glyph_body_rows(font: Font, codepoint: i32) -> i32:
    let glyph = GetGlyphInfo(font, codepoint)
    unsafe:
        let pixels = LoadImageColors(glyph.image)
        if pixels == null: return 0
        defer: UnloadImageColors(pixels)
        var first = glyph.image.height
        var last = -1
        for y in 0..glyph.image.height:
            for x in 0..glyph.image.width:
                if pixels[y * glyph.image.width + x].a > 127:
                    if y < first: first = y
                    if y > last: last = y
        if last < first: 0 else: last - first + 1

fn verify_font_readability():
    let font = GetFontDefault()
    let names = ["a", "e", "m", "x"]
    let codepoints = [97, 101, 109, 120]
    let deck_scale = fit(1280, 800, 1280, 800).scale
    let hd_scale = fit(1280, 720, 1422, 800).scale
    for i in 0..4:
        let rows = glyph_body_rows(font, codepoints[i])
        let logical_height = rows as f64 * MIN_TEXT_SIZE as f64 / font.baseSize as f64
        let at800 = logical_height * deck_scale
        let at720 = logical_height * hd_scale
        print(f"font: {names[i]} alpha body {rows}/{font.baseSize}; floor {MIN_TEXT_SIZE}; visible {at800}px at 1280x800, {at720}px at 1280x720")
        assert(at800 >= 9.0 and at720 >= 9.0)

fn main:
    SetTraceLogLevel(LOG_WARNING)
    var window_flags = FLAG_MSAA_4X_HINT as u32
    if env("WIPE_TOUR_HIGHDPI") == "1": window_flags = window_flags | FLAG_WINDOW_HIGHDPI as u32
    SetConfigFlags(window_flags)
    // WIPE_TOUR_VIEW=1422x800 tours the view a screen of that shape gets.
    var view_w = WIDTH
    var view_h = HEIGHT
    let asked = env("WIPE_TOUR_VIEW").split("x")
    if asked.len() == 2:
        view_w = parse(asked[0])
        view_h = parse(asked[1])
    // A higher physical output exercises crisp rendering without changing
    // simulation/view coordinates. For example 1422x800 at 1920x1080.
    var output_w = view_w
    var output_h = view_h
    let output = env("WIPE_TOUR_OUTPUT").split("x")
    if output.len() == 2:
        output_w = parse(output[0])
        output_h = parse(output[1])
    InitWindow(output_w, output_h, "WIPE: SURVIVAL | tour")
    if not IsWindowReady(): return 1
    let window_device = WindowDevice {}
    verify_font_readability()
    SetExitKey(KEY_NULL)
    SetTargetFPS(0)
    if env("WIPE_SAVE_DIR").len() == 0:
        eprint("tour: set WIPE_SAVE_DIR to a scratch directory")
        return 1
    var renderer = Renderer.open(view_w, view_h)
    // Exercise resize/reuse before capturing, including the minimized case.
    assert(renderer.resize_output(1920, 1080) and renderer.valid())
    let surface_id: u32 = renderer.scene.id
    assert(renderer.resize_output(1920, 1080) and renderer.scene.id == surface_id)
    assert(renderer.resize_output(0, 0) and renderer.scene.id == surface_id)
    if not renderer.resize_output(GetRenderWidth(), GetRenderHeight()): return 1
    if not renderer.valid(): return 1
    print(f"tour: view {view_w}x{view_h}, window {GetScreenWidth()}x{GetScreenHeight()}, framebuffer {GetRenderWidth()}x{GetRenderHeight()}, scene {renderer.scene.texture.width}x{renderer.scene.texture.height}")
    var wipe = App.open()
    wipe.set_view(view_w, view_h)
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
    capture("out/tour/1-title.png")
    wipe.screen = .Select
    wipe.ship_cursor = 2
    clock = frames(&wipe, &renderer, 3, clock)
    capture("out/tour/2-select.png")
    wipe.ship_cursor = 5
    clock = frames(&wipe, &renderer, 3, clock)
    capture("out/tour/3-select-locked.png")
    wipe.screen = .Maps
    wipe.stage_cursor = 4
    clock = frames(&wipe, &renderer, 3, clock)
    capture("out/tour/3b-maps.png")
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
    capture("out/tour/4-run.png")
    wipe.game.gain_xp(wipe.game.xp_next)
    wipe.game.tick(Controls {}, 1.0 / 120.0)
    wipe.boost_cursor = 1
    clock = frames(&wipe, &renderer, 3, clock)
    capture("out/tour/5-boost.png")
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
    capture("out/tour/6-density.png")
    wipe.debug = false
    wipe.screen = .Pause
    clock = frames(&wipe, &renderer, 3, clock)
    capture("out/tour/7-pause.png")
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
    capture("out/tour/8-results.png")
    wipe.screen = .Shop
    wipe.shop_cursor = 7
    clock = frames(&wipe, &renderer, 3, clock)
    capture("out/tour/9-shop.png")
    wipe.screen = .Collection
    wipe.tab = .Ships
    wipe.collection_cursor = 5
    clock = frames(&wipe, &renderer, 3, clock)
    capture("out/tour/10-collection.png")
    wipe.tab = .Registry
    wipe.collection_cursor = 4
    clock = frames(&wipe, &renderer, 3, clock)
    capture("out/tour/11-registry.png")
    // The Ring stage mid-boss-entry: the dead center and the zoomed camera.
    wipe.stage = .Ring
    wipe.launch_as(.Claw)
    wipe.game.rules.contact_radius = 0.0
    wipe.game.stress(300)
    wipe.game.player = add(wipe.game.center(), V2 { x: 0.0, y: 520.0 })
    wipe.game.view = add(wipe.game.center(), V2 { x: 0.0, y: 300.0 })
    wipe.game.zoom_timer = 1.2
    clock = frames(&wipe, &renderer, 3, clock)
    capture("out/tour/12-ring-zoom.png")
    // Active pad prompts on every interactive screen, including both award
    // pages. These renders do not sample the desktop mouse between captures.
    wipe.menu.device = .Pad
    wipe.screen = .Title
    clock = frames(&wipe, &renderer, 2, clock)
    capture("out/tour/13-pad-title.png")
    wipe.screen = .Select
    clock = frames(&wipe, &renderer, 2, clock)
    capture("out/tour/14-pad-select.png")
    wipe.screen = .Maps
    clock = frames(&wipe, &renderer, 2, clock)
    capture("out/tour/15-pad-maps.png")
    wipe.screen = .Run
    clock = frames(&wipe, &renderer, 2, clock)
    capture("out/tour/16-pad-run.png")
    wipe.game.gain_xp(wipe.game.xp_next)
    wipe.game.tick(Controls {}, 1.0 / 120.0)
    clock = frames(&wipe, &renderer, 2, clock)
    capture("out/tour/17-pad-boost.png")
    while wipe.game.phase == .Boost: wipe.game.choose(0)
    wipe.screen = .Pause
    wipe.pause_cursor = 7
    clock = frames(&wipe, &renderer, 2, clock)
    capture("out/tour/18-pad-pause.png")
    wipe.screen = .Results
    clock = frames(&wipe, &renderer, 2, clock)
    capture("out/tour/19-pad-results.png")
    wipe.screen = .Shop
    clock = frames(&wipe, &renderer, 2, clock)
    capture("out/tour/20-pad-shop.png")
    wipe.screen = .Collection
    wipe.tab = .Achievements
    wipe.collection_cursor = 0
    clock = frames(&wipe, &renderer, 2, clock)
    capture("out/tour/21-pad-awards.png")
    wipe.collection_cursor = 28
    clock = frames(&wipe, &renderer, 2, clock)
    capture("out/tour/22-pad-awards-page-2.png")
    print("tour done")
    0
