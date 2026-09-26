// Visual verification gallery: stages every element of the game in the real
// simulation and renderer and saves frames to out/gallery/ for review
// against the prototype's record in docs/verification/.
use c_import("raylib.h")
use game
use tuning
use loadout
use ships
use presentation

fn shot(renderer: &Renderer, g: &Game, clock: f64, name: &str, cursor: i32 = 0):
    // raylib's screenshot reads the frame before the one just presented:
    // draw the scene twice so the saved image is this scene.
    for _ in 0..2:
        let cam = renderer.begin_world(g, clock, 1.0)
        renderer.draw_run(g, cam, Hud { best_time: 600.0, show_hints: false }, cursor, clock, None)
        let _ = renderer.present()
    let path = f"out/gallery/{name}.png"
    TakeScreenshot(path)

// A game with no spawns, a ring of still targets, and a chosen loadout.
fn staged(ship: Ship = .Claw) -> Game:
    var g = Game.new(Rules { minimum_start: 0.0 })
    var launch = Launch { ship }
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    for i in 0..PASSIVE_COUNT: launch.unlocked_passives[i] = true
    g.start(launch)
    g.rules.contact_radius = 0.0
    g.spawn_timer = 1.0e9
    g.next_elite = 1.0e9
    g.boss_index = 3
    g.event_index = 12
    g

fn surround(start: Game, count: i32, radius: f64, kind: Kind) -> Game:
    var g = start
    for i in 0..count:
        let a = (i as f64) / count as f64 * 6.283185307
        let pos = add(g.player, V2 { x: cos(a) * radius, y: sin(a) * radius * 0.7 })
        if g.place_enemy(pos, kind):
            g.enemies[g.enemy_count - 1].age = 1.0
            g.enemies[g.enemy_count - 1].speed = 0.0
            g.enemies[g.enemy_count - 1].hp = 6
    g

fn step(start: Game, seconds: f64, aim: V2) -> Game:
    var g = start
    let n = (seconds * 120.0) as i32
    for _ in 0..n:
        g.clear_events()
        g.tick(Controls { aim }, 1.0 / 120.0)
        if g.phase == .Boost: g.choose(0)
    g

fn main:
    SetTraceLogLevel(LOG_WARNING)
    SetConfigFlags(FLAG_MSAA_4X_HINT)
    InitWindow(WIDTH, HEIGHT, "WIPE: SURVIVAL | gallery")
    if not IsWindowReady(): return 1
    defer: CloseWindow()
    SetTargetFPS(0)
    let renderer = Renderer.open()
    if not renderer.valid(): return 1
    let right = V2 { x: 1.0 }
    // 1. Early combat, the prototype's gameplay frame: sixty chasers, kills.
    var early = Game.new()
    early.rules.contact_radius = 0.0
    early.stress(60)
    early = step(early, 2.0, right)
    for i in 0..80:
        early.clear_events()
        early.tick(Controls { aim: V2 { x: cos(i as f64 * 0.2), y: sin(i as f64 * 0.2) } }, 1.0 / 120.0)
    shot(&renderer, &early, 20.0, "01-early-combat")
    // 2. Every weapon at its maximum level, and four merged weapons.
    let showcase = [Weapon.Cannon, Weapon.Orbit, Weapon.Nova, Weapon.Seeker, Weapon.Lance, Weapon.Mines, Weapon.Arc, Weapon.Shard, Weapon.Railgun, Weapon.Corona, Weapon.Storm, Weapon.Shatter]
    var n = 2
    for w in showcase:
        var g = staged()
        g.build.weapons[0] = WeaponSlot { weapon: w, level: MAX_WEAPON_LEVEL }
        g = surround(g, 14, 260.0, Kind.Block)
        g = surround(g, 10, 150.0, Kind.Spinner)
        g = step(g, 1.0, V2 { x: 0.8, y: -0.6 })
        // Capture just after the weapon fires.
        g.build.weapons[0].timer = 0.0
        g = step(g, 0.07, V2 { x: 0.8, y: -0.6 })
        let name = f"{n:02}-weapon-{w.name()}"
        shot(&renderer, &g, 30.0 + n as f64, name)
        n += 1
    // 3. The enemy lineup, frozen, then a moving mixed swarm.
    var lineup = staged()
    let kinds = [Kind.Block, Kind.Spinner, Kind.Dart, Kind.Weaver, Kind.Skimmer, Kind.Well]
    for i in 0..6:
        let pos = add(lineup.player, V2 { x: -375.0 + i as f64 * 150.0, y: -160.0 })
        let _ = lineup.place_enemy(pos, kinds[i])
        lineup.enemies[lineup.enemy_count - 1].age = 1.0
        let elite_pos = add(pos, V2 { y: 150.0 })
        let _ = lineup.place_enemy(elite_pos, kinds[i], true)
        lineup.enemies[lineup.enemy_count - 1].age = 1.0
    lineup.enemies_frozen = 100.0
    lineup.build.weapons[0].level = 0
    lineup = step(lineup, 0.3, right)
    shot(&renderer, &lineup, 40.0, "20-enemy-lineup")
    var bosses = staged()
    bosses.build.weapons[0].level = 0
    let _ = bosses.place_enemy(add(bosses.player, V2 { x: -250.0, y: -100.0 }), Kind.Boss)
    let _ = bosses.place_enemy(add(bosses.player, V2 { x: 280.0, y: -60.0 }), Kind.Null)
    for i in 0..bosses.enemy_count: bosses.enemies[i].age = 1.0
    bosses.enemies_frozen = 100.0
    bosses = step(bosses, 0.3, right)
    shot(&renderer, &bosses, 41.0, "21-boss-and-null")
    // 4. Drops: cores, every pickup, a beacon.
    var drops = staged()
    drops.build.weapons[0].level = 0
    let pickups = [PickupKind.Tractor, PickupKind.Clear, PickupKind.Freeze, PickupKind.Repair, PickupKind.Credits, PickupKind.Bundle, PickupKind.Cache]
    for i in 0..7: drops.drop_pickup(add(drops.player, V2 { x: -390.0 + i as f64 * 130.0, y: -200.0 }), pickups[i])
    for i in 0..24: drops.drop_core(add(drops.player, V2 { x: -300.0 + (i % 12) as f64 * 55.0, y: 140.0 + (i / 12) as f64 * 60.0 }), 1 + (i % 6) * 4)
    drops.beacons[0].pos = add(drops.player, V2 { x: 330.0, y: 40.0 })
    drops = step(drops, 0.3, right)
    shot(&renderer, &drops, 42.0, "22-drops")
    // 5. Moments.
    var level = staged()
    level = surround(level, 12, 240.0, Kind.Dart)
    level.gain_xp(level.xp_next)
    level.clear_events()
    level.tick(Controls { aim: right }, 1.0 / 120.0)
    shot(&renderer, &level, 50.0, "30-level-up-cards", 1)
    var merge = staged()
    merge.build.weapons[0] = WeaponSlot { weapon: .Cannon, level: MAX_WEAPON_LEVEL }
    merge.build.add_passive(.FireRate)
    merge.gain_xp(merge.xp_next)
    merge.tick(Controls { aim: right }, 1.0 / 120.0)
    shot(&renderer, &merge, 51.0, "31-merge-offer")
    merge.choose(0)
    merge = step(merge, 0.35, right)
    shot(&renderer, &merge, 52.0, "32-merge-banner")
    var cache = staged()
    cache.open_cache()
    cache.tick(Controls { aim: right }, 1.0 / 120.0)
    cache.cache_reveal = 0.6
    shot(&renderer, &cache, 53.0, "33-cache-spin")
    var warn = staged()
    warn.spawn_boss()
    warn = step(warn, 0.5, right)
    shot(&renderer, &warn, 54.0, "34-boss-warning")
    var down = staged()
    down = surround(down, 30, 300.0, Kind.Block)
    let _ = down.place_enemy(add(down.player, V2 { x: 200.0 }), Kind.Boss)
    down.enemies[down.enemy_count - 1].age = 1.0
    let _ = down.damage_enemy(down.enemy_count - 1, 100000, right)
    down = step(down, 0.35, right)
    shot(&renderer, &down, 55.0, "35-boss-down")
    var telegraph = staged()
    telegraph.event_index = 0
    telegraph.elapsed = 150.0
    telegraph = step(telegraph, 1.0, right)
    shot(&renderer, &telegraph, 56.0, "36-event-telegraph")
    var death = staged()
    death = surround(death, 20, 200.0, Kind.Spinner)
    death.health = 1
    death.hurt(Kind.Spinner, false, 5)
    death = step(death, 0.08, right)
    shot(&renderer, &death, 57.0, "37-death")
    var reboot = staged()
    reboot.reboots = 1
    reboot = surround(reboot, 30, 220.0, Kind.Block)
    reboot.health = 1
    reboot.hurt(Kind.Block, false, 5)
    reboot = step(reboot, 0.3, right)
    shot(&renderer, &reboot, 58.0, "38-reboot")
    // 6. Every ship in flight, with its base weapon.
    for i in 0..SHIP_COUNT:
        var g = staged(ship_at(i))
        g = surround(g, 10, 240.0, Kind.Block)
        g = step(g, 0.8, V2 { x: 0.8, y: -0.6 })
        let name = f"{40 + i}-ship-{ship_at(i).name()}"
        shot(&renderer, &g, 60.0 + i as f64, name)
    // 7. Late run: the full build and a real density, fighting.
    var late = Game.new()
    // Real contact, a hull that cannot fall: the swarm presses as it would.
    late.max_health = 100000
    late.health = 100000
    late.elapsed = 840.0
    late.boss_index = 3
    late.event_index = 12
    late.build.weapons[0].level = 8
    late.build.add_weapon(.Orbit)
    late.build.add_weapon(.Arc)
    late.build.add_weapon(.Nova)
    late.build.add_weapon(.Seeker)
    for _ in 0..5:
        late.build.upgrade_weapon(.Orbit)
        late.build.upgrade_weapon(.Arc)
        late.build.upgrade_weapon(.Nova)
        late.build.upgrade_weapon(.Seeker)
    late.build.add_passive(.Area)
    late.build.add_passive(.Magnet)
    late.level = 30
    late.stress(900)
    late = step(late, 4.0, V2 { x: 0.3, y: 1.0 })
    var stacked = 0
    for i in 0..late.enemy_count:
        if length2(sub(late.enemies[i].pos, late.player)) < 40.0 * 40.0: stacked += 1
    let screen = sub(late.player, late.view_origin())
    print(f"late: ship at screen {screen.x as i32},{screen.y as i32}; {stacked} enemies within 40 px; particles {late.particle_count}")
    shot(&renderer, &late, 70.0, "50-late-run")
    // Pickups out of view: pulsing edge indicators.
    var off = staged()
    off.build.weapons[0].level = 0
    off.drop_pickup(add(off.player, V2 { x: 900.0, y: -120.0 }), PickupKind.Cache)
    off.drop_pickup(add(off.player, V2 { x: -800.0, y: 250.0 }), PickupKind.Repair)
    off.drop_pickup(add(off.player, V2 { x: 100.0, y: 600.0 }), PickupKind.Freeze)
    off = step(off, 0.2, V2 { x: 1.0 })
    shot(&renderer, &off, 80.0, "60-offscreen-pickups")
    // Lightning mid-strike: bolts from the ship, forking, chaining on.
    var zap = staged()
    zap.build.weapons[0] = WeaponSlot { weapon: .Arc, level: 5 }
    zap = surround(zap, 18, 300.0, Kind.Block)
    for i in 0..zap.enemy_count: zap.enemies[i].hp = 400
    zap.build.weapons[0].timer = 0.0
    zap = step(zap, 0.04, V2 { x: 1.0 })
    shot(&renderer, &zap, 90.0, "61-lightning")
    // Each boss mid-fight, one on one.
    for index in 1..4:
        var fight = staged()
        fight.build.weapons[0] = WeaponSlot { weapon: .Cannon, level: 4 }
        fight.boss_index = index
        fight.elapsed = 300.0 * index as f64
        fight.spawn_boss()
        fight = step(fight, 7.0, V2 { x: 0.8, y: -0.6 })
        let bname = f"63-boss-{index}"
        shot(&renderer, &fight, 100.0 + index as f64, bname)
    // Walled maps mid-fight.
    for st in [Stage.Gridlock, Stage.Maze]:
        var walled = Game.new(st.rules())
        walled.rules.contact_radius = 0.0
        walled.elapsed = 300.0
        walled.boss_index = 3
        walled = step(walled, 20.0, V2 { x: 1.0 })
        let name = f"62-map-{st.name()}"
        shot(&renderer, &walled, 95.0, name)
    print("gallery done")
    0
