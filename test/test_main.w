//! expect-stdout: UAT passed: movement, camera, fire, damage, cores, level-up, merge, death, restart, timeline, capacity, determinism
use game
use tuning
use loadout
use ships

fn near(actual: f64, expected: f64):
    assert(actual > expected - 0.001 and actual < expected + 0.001)

fn movement_uat:
    var g = Game.new()
    let start: V2 = g.player
    g.tick(Controls { motion: V2 { x: 1.0, y: 1.0 }, aim: V2 { x: 0.0, y: -1.0 } }, 0.1)
    near(sqrt(length2(sub(g.player, start))), 26.5)
    near(g.aim.y, -1.0)
    assert(g.bullet_count == 1)
    assert(g.bullets[0].vel.y < 0.0)
    assert(g.bullets[0].vel.x == 0.0)
    near(length2(movement(V2 { x: 0.25, y: 0.0 })), 0.0625)
    for _ in 0..2000: g.tick(Controls { motion: V2 { x: -1.0, y: -1.0 } }, 1.0 / 120.0)
    // Walls hold the ship; the camera stops at the arena edge.
    assert(g.player.x >= 14.0 and g.player.y >= 14.0 and g.player.x < 15.0)
    let origin = g.view_origin()
    assert(origin.x == 0.0 and origin.y == 0.0)
    assert(g.on_screen(g.player, 0.0))
    assert(not g.on_screen(V2 { x: 2000.0, y: 1300.0 }, 0.0))

fn combat_uat:
    assert(segment_hit(V2 {}, V2 { x: 100.0 }, V2 { x: 50.0, y: 3.0 }, 5.0))
    assert(not segment_hit(V2 {}, V2 { x: 100.0 }, V2 { x: 50.0, y: 6.0 }, 5.0))
    var g = Game.new()
    let _ = g.place_enemy(add(g.player, V2 { x: 40.0 }), .Dart)
    g.enemies[0].age = 1.0
    g.enemies[0].speed = 0.0
    g.enemies[0].hp = 1
    g.tick(Controls {}, 1.0 / 120.0)
    assert(g.kills == 1 and g.enemy_count == 0)
    assert(g.kill_event and g.core_count == 1)
    // The core is collected by the magnet and fills the bar.
    for _ in 0..120: g.tick(Controls {}, 1.0 / 120.0)
    assert(g.core_count == 0 and g.cores_collected == 1 and g.combo == 1 and g.xp == 1)
    // Contact damage, armor, invulnerability.
    g.enemy_count = 0
    let _ = g.place_enemy(g.player, .Block)
    g.enemies[0].age = 1.0
    g.enemies[0].speed = 0.0
    g.tick(Controls {}, 1.0 / 120.0)
    assert(g.health == 8 and g.hurt_event and g.hits_taken == 1 and g.combo == 0)
    g.enemy_count = 0
    // Death names its killer and records the health before the hit.
    g.health = 2
    g.invulnerable = 0.0
    g.freeze = 0.0
    let _ = g.place_enemy(g.player, .Spinner)
    g.enemies[0].age = 1.0
    g.enemies[0].speed = 0.0
    g.tick(Controls {}, 1.0 / 120.0)
    assert(g.phase == .Over and g.death_event and not g.cleared)
    let killer: Kind = g.killer.unwrap()
    assert(killer == Kind.Spinner and g.health_before == 2)
    let ended: f64 = g.elapsed
    for _ in 0..60: g.tick(Controls { motion: V2 { x: 1.0 } }, 1.0 / 120.0)
    near(g.elapsed, ended)
    g.reset()
    assert(g.health == 10 and g.kills == 0 and g.elapsed == 0.0 and g.phase == .Running)
    assert(g.enemy_count == 0 and g.bullet_count == 0 and g.particle_count == 0 and g.core_count == 0)
    assert(g.killer.is_none() and g.beacon_count == 3)
    g.tick(Controls {}, 1.0 / 120.0)
    assert(g.bullet_count == 1 and g.shot_event)

fn boost_uat:
    var g = Game.new()
    // Ten XP is the first level; the boost pauses the world.
    g.gain_xp(10)
    g.tick(Controls {}, 1.0 / 120.0)
    assert(g.level == 2 and g.phase == .Boost and g.level_event)
    assert(g.offer_count == 3)
    let before: f64 = g.elapsed
    for _ in 0..30: g.tick(Controls { motion: V2 { x: 1.0 } }, 1.0 / 120.0)
    near(g.elapsed, before)
    g.choose(0)
    assert(g.phase == .Running)
    assert(g.build.weapon_count() + g.build.passive_count() >= 2 or g.build.weapon_level(.Cannon) == 2)
    // A ready recipe leads the next boost and merging consumes the components.
    g.build = Build { unlocked_weapons: g.build.unlocked_weapons, unlocked_passives: g.build.unlocked_passives }
    g.build.add_weapon(.Cannon)
    for _ in 0..7: g.build.upgrade_weapon(.Cannon)
    g.build.add_passive(.FireRate)
    g.gain_xp(1000)
    g.tick(Controls {}, 1.0 / 120.0)
    assert(g.phase == .Boost and g.offers[0].pick.is_merge())
    g.choose(0)
    assert(g.merge_event and g.build.weapon_level(.Railgun) == 1 and g.build.weapon_level(.Cannon) == 0)
    // Queued levels chain boosts; skip spends a skip.
    assert(g.phase == .Boost)
    g.skips = 1
    g.skip()
    assert(g.skips == 0)
    // Rerolls redraw, banish removes.
    g.rerolls = 1
    g.reroll()
    assert(g.rerolls == 0)
    while g.phase == .Boost: g.choose(0)
    assert(g.phase == .Running)

fn timeline_uat:
    var g = Game.new()
    g.elapsed = 299.9
    for _ in 0..30: g.tick(Controls {}, 1.0 / 120.0)
    assert(g.boss_alive and g.boss_event or g.boss_alive)
    assert(g.boss_index == 1)
    // Elites arrive on schedule and carry a cache.
    var h = Game.new()
    h.elapsed = 179.9
    for _ in 0..30: h.tick(Controls {}, 1.0 / 120.0)
    var elites = 0
    for i in 0..h.enemy_count:
        if h.enemies[i].elite: elites += 1
    assert(elites == 1)
    // The cap spawns the Null and marks the run cleared.
    var n = Game.new()
    n.elapsed = 1199.99
    n.boss_index = 3
    for _ in 0..10: n.tick(Controls {}, 1.0 / 120.0)
    assert(n.cleared and n.null_alive)
    var found = false
    for i in 0..n.enemy_count:
        if n.enemies[i].kind == .Null: found = true
    assert(found)
    // Endless never spawns the Null.
    var e = Game.new()
    var launch = Launch {}
    for i in 0..8: launch.unlocked_weapons[i] = true
    for i in 0..8: launch.unlocked_passives[i] = true
    launch.endless = true
    e.start(launch)
    e.boss_index = 3
    e.elapsed = 1199.99
    for _ in 0..10: e.tick(Controls {}, 1.0 / 120.0)
    assert(not e.cleared and not e.null_alive)

fn ships_uat:
    var g = Game.new()
    var launch = Launch { ship: .Hull }
    for i in 0..8: launch.unlocked_weapons[i] = true
    for i in 0..8: launch.unlocked_passives[i] = true
    g.start(launch)
    assert(g.max_health == 15 and g.mods.armor == 1)
    assert(g.build.weapon_level(.Nova) == 1)
    launch.ship = .Sapper
    g.start(launch)
    assert(g.build.weapon_slots == 4)
    launch.ship = .Null
    g.start(launch)
    assert(g.level == 5 and g.build.weapon_count() == 3)

fn capacity_uat:
    var g = Game.new()
    g.stress()
    assert(g.enemy_count == 350)
    for _ in 0..3000: g.spawn_enemy()
    assert(g.enemy_count <= ENEMY_CAP)
    g.burst(V2 {}, V2 {}, 5000, .Cyan, 1.0)
    assert(g.particle_count == PARTICLE_CAP)
    for _ in 0..2000: g.drop_core(g.center(), 1)
    assert(g.core_count <= CORE_CAP)
    for _ in 0..30: g.tick(Controls {}, 1.0 / 120.0)
    // Aged cores on the floor merge into one larger core.
    var m = Game.new()
    m.drop_core(V2 { x: 200.0, y: 200.0 }, 1)
    m.drop_core(V2 { x: 220.0, y: 200.0 }, 2)
    for _ in 0..(120 * 4): m.tick(Controls {}, 1.0 / 120.0)
    assert(m.cores_collected == 0)
    var total = 0
    for i in 0..m.core_count:
        if m.cores[i].pos.x < 400.0 and m.cores[i].pos.y < 400.0: total += 1
    assert(total == 1)

fn determinism_uat:
    var a = Game.new()
    var b = Game.new()
    for i in 0..600:
        let controls = Controls { motion: V2 { x: sin(i as f64 * 0.05), y: cos(i as f64 * 0.03) }, aim: V2 { x: cos(i as f64 * 0.1), y: sin(i as f64 * 0.1) } }
        a.tick(controls, 1.0 / 120.0)
        b.tick(controls, 1.0 / 120.0)
        if a.phase == .Boost: a.choose(0)
        if b.phase == .Boost: b.choose(0)
    assert(a.enemy_count == b.enemy_count and a.kills == b.kills and a.xp == b.xp)
    assert(a.player.x == b.player.x and a.view.y == b.view.y and a.rng == b.rng)

fn main:
    movement_uat()
    combat_uat()
    boost_uat()
    timeline_uat()
    ships_uat()
    capacity_uat()
    determinism_uat()
    print("UAT passed: movement, camera, fire, damage, cores, level-up, merge, death, restart, timeline, capacity, determinism")
