// Watched playtest: the careful bot flies a ship into a boss in the real
// renderer, the fight plays at speed on screen, a frame is saved every few
// seconds and a probe line printed every second, so a reviewer can judge
// what the bot cannot: readability, tells, and whether a death looks fair.
//
//   ./out/bin/playtest SHIP [BOSS] [SEED]      frames land in out/playtest/
use c_import("raylib.h")
use std.process.args
use std.string.parse
use game
use tuning
use loadout
use ships
use save
use account
use pilots
use presentation
use input
use devices

fn main:
    let argv = args()
    if argv.len() < 2:
        print("usage: playtest SHIP [BOSS] [SEED]")
        return 1
    var ship = Ship.Claw
    var found = false
    for i in 0..SHIP_COUNT:
        if ship_at(i).name() == argv[1]:
            ship = ship_at(i)
            found = true
    if not found:
        print(f"unknown ship {argv[1]}")
        return 1
    let force = if argv.len() > 2: parse(argv[2]) else: -1
    let seed = if argv.len() > 3: parse(argv[3]) else: 0
    var g = Game.new()
    g.rng = 55555 +% (seed as u32) *% 2654435761
    var account = Save {}
    for w in 0..BASE_WEAPON_COUNT: account.weapon_unlocked_run[w] = 0
    var launch = launch_for(ship, &account, false)
    for w in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[w] = true
    for p in 0..8: launch.unlocked_passives[p] = true
    g.start(launch)
    if force == 1 or force == 3 or force == 5: g.slot_boss[1] = force
    if force == 2 or force == 4 or force == 5: g.slot_boss[2] = force
    if force == 0: g.slot_boss[0] = 0
    // To the boss, unseen.
    var held = Controls {}
    while g.phase != .Over and g.elapsed < 1200.0 and not g.boss_alive:
        g.clear_events()
        held = human(&g, held)
        g.tick(held, 1.0 / 120.0)
        var guard = 0
        while g.phase == .Boost and guard < 20:
            guard += 1
            g.cache_reveal = 0.0
            g.choose(pick_card(&g))
    if not g.boss_alive:
        print("no boss reached")
        return 1
    SetTraceLogLevel(LOG_WARNING)
    SetConfigFlags(FLAG_MSAA_4X_HINT as u32)
    InitWindow(WIDTH, HEIGHT, f"WIPE: SURVIVAL | playtest {ship.name()}")
    if not IsWindowReady(): return 1
    let window_device = WindowDevice {}
    SetTargetFPS(60)
    let renderer = Renderer.open()
    if not renderer.valid(): return 1
    var clock = 0.0
    var since_shot = 10.0
    var since_line = 10.0
    var after = 0.0
    var shots = 0
    var last_hp = 0
    while not WindowShouldClose():
        let dt = 1.0 / 60.0
        clock += dt
        for _ in 0..2:
            g.clear_events()
            held = human(&g, held)
            g.tick(held, 1.0 / 120.0)
            var guard = 0
            while g.phase == .Boost and guard < 20:
                guard += 1
                g.cache_reveal = 0.0
                g.choose(pick_card(&g))
        let cam = renderer.begin_world(&g, clock, 1.0)
        renderer.draw_run(&g, cam, Hud { best_time: 600.0, show_hints: false }, 0, clock, None)
        let _ = renderer.present()
        since_shot += dt
        since_line += dt
        if since_line >= 1.0:
            since_line -= 1.0
            for i in 0..g.enemy_count:
                let e = g.enemies[i]
                if e.kind != .Boss or e.boss < 0: continue
                let d = sub(g.player, e.pos)
                let dist = sqrt(length2(d))
                let along = (d.x * e.facing.x + d.y * e.facing.y) / (dist + 0.001)
                let dealt = if last_hp > 0: last_hp - e.hp else: 0
                print(f"{g.elapsed as i32}s {BOSS_NAMES[e.boss]} dist {dist as i32} along {(along * 100.0) as i32} hp {e.hp} dealt/s {dealt} desperate {e.age > g.desperation_of(e.boss)} health {g.health} enemies {g.enemy_count}")
                last_hp = e.hp
        if since_shot >= 3.0:
            since_shot -= 3.0
            shots += 1
            TakeScreenshot(f"out/playtest/{ship.name()}-{shots}.png")
        if not g.boss_alive or g.phase == .Over:
            after += dt
            if after > 2.5:
                shots += 1
                TakeScreenshot(f"out/playtest/{ship.name()}-{shots}.png")
                break
    CloseWindow()
    print(f"{shots} frames in out/playtest/, phase over {g.phase == .Over}, boss alive {g.boss_alive}")
    0
