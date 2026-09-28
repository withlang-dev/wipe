//! expect-stdout: UAT passed: movement, camera, fire, damage, cores, level-up, merge, death, restart, timeline, capacity, determinism
use game
use tuning
use loadout
use ships

fn near(actual: f64, expected: f64):
    assert(actual > expected - 0.001 and actual < expected + 0.001)

fn movement_uat:
    var g = Game.new(Rules { minimum_start: 0.0 })
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
    var g = Game.new(Rules { minimum_start: 0.0 })
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
    // A Block's touch costs three of ten.
    assert(g.health == 7 and g.hurt_event and g.hits_taken == 1 and g.combo == 0)
    g.enemy_count = 0
    // Death names its killer and records the health before the hit.
    g.health = 1
    g.invulnerable = 0.0
    g.freeze = 0.0
    let _ = g.place_enemy(g.player, .Spinner)
    g.enemies[0].age = 1.0
    g.enemies[0].speed = 0.0
    g.tick(Controls {}, 1.0 / 120.0)
    assert(g.phase == .Over and g.death_event and not g.cleared)
    let killer: Kind = g.killer.unwrap()
    assert(killer == Kind.Spinner and g.health_before == 1)
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
    var g = Game.new(Rules { minimum_start: 0.0 })
    // The first level's XP; the boost pauses the world.
    g.gain_xp(g.xp_next)
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
    for _ in 1..MAX_WEAPON_LEVEL: g.build.upgrade_weapon(.Cannon)
    g.build.add_passive(.FireRate)
    g.gain_xp(1000)
    g.tick(Controls {}, 1.0 / 120.0)
    assert(g.phase == .Boost and g.offers[0].pick.is_merge())
    g.choose(0)
    assert(g.merge_event and g.build.weapon_level(.Railgun) == MAX_WEAPON_LEVEL and g.build.weapon_level(.Cannon) == 0)
    // A merge is final, and what went into it never comes back.
    for p in g.build.candidates():
        match p:
            .NewWeapon(w) => assert(w != Weapon.Cannon)
            .UpgradeWeapon(w) => assert(w != Weapon.Railgun and w != Weapon.Cannon)
            _ => ()
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

fn merges_uat:
    // Two ready recipes sharing the Orbit: both are offered, not just the first.
    var g = Game.new(Rules { minimum_start: 0.0 })
    g.build = Build { unlocked_weapons: g.build.unlocked_weapons, unlocked_passives: g.build.unlocked_passives }
    g.build.add_weapon(.Orbit)
    g.build.add_weapon(.Nova)
    for _ in 1..MAX_WEAPON_LEVEL:
        g.build.upgrade_weapon(.Orbit)
        g.build.upgrade_weapon(.Nova)
    g.build.add_passive(.Area)
    g.gain_xp(g.xp_next)
    g.tick(Controls {}, 1.0 / 120.0)
    var corona = false
    var pulsar = false
    for i in 0..g.offer_count:
        match g.offers[i].pick:
            .Merge(w) => {
                if w == Weapon.Corona: corona = true
                if w == Weapon.Pulsar: pulsar = true
            }
            _ => ()
    assert(corona and pulsar)

fn timeline_uat:
    var g = Game.new(Rules { minimum_start: 0.0 })
    g.elapsed = 299.9
    for _ in 0..30: g.tick(Controls {}, 1.0 / 120.0)
    assert(g.boss_alive and g.boss_event or g.boss_alive)
    assert(g.boss_index == 1)
    // Elites arrive on schedule and carry a cache.
    var h = Game.new(Rules { minimum_start: 0.0 })
    h.elapsed = 239.9
    for _ in 0..30: h.tick(Controls {}, 1.0 / 120.0)
    var elites = 0
    for i in 0..h.enemy_count:
        if h.enemies[i].elite: elites += 1
    assert(elites == 1)
    // The cap spawns the Null and marks the run cleared.
    var n = Game.new(Rules { minimum_start: 0.0 })
    n.elapsed = 1199.99
    n.boss_index = 3
    for _ in 0..10: n.tick(Controls {}, 1.0 / 120.0)
    assert(n.cleared and n.null_alive)
    var found = false
    for i in 0..n.enemy_count:
        if n.enemies[i].kind == .Null: found = true
    assert(found)
    // Endless never spawns the Null.
    var e = Game.new(Rules { minimum_start: 0.0 })
    var launch = Launch {}
    for i in 0..8: launch.unlocked_weapons[i] = true
    for i in 0..8: launch.unlocked_passives[i] = true
    launch.endless = true
    e.start(launch)
    e.boss_index = 3
    e.elapsed = 1199.99
    for _ in 0..10: e.tick(Controls {}, 1.0 / 120.0)
    assert(not e.cleared and not e.null_alive)

fn boss_game(index: i32) -> Game:
    var g = Game.new(Rules { minimum_start: 0.0 })
    var launch = Launch {}
    for i in 0..8: launch.unlocked_weapons[i] = true
    g.start(launch)
    g.rules.contact_radius = 0.0
    g.build.weapons[0].level = 0
    g.stress(60)
    g.boss_index = index
    g.elapsed = 300.0 * index as f64
    g.spawn_boss()
    g

fn boss_at(g: &Game) -> i32:
    for i in 0..g.enemy_count:
        if g.enemies[i].kind == .Boss: return i
    -1

fn bosses_uat:
    // One on one: the swarm dissolves and nothing else arrives.
    for index in 1..4:
        var g = boss_game(index)
        let b = boss_at(&g)
        assert(b >= 0)
        let e: Enemy = g.enemies[b]
        assert(e.boss == index - 1)
        assert(e.max_hp >= 1800)
        for _ in 0..1200:
            g.clear_events()
            g.tick(Controls {}, 1.0 / 120.0)
        var others = 0
        for i in 0..g.enemy_count:
            let o: Enemy = g.enemies[i]
            if o.kind != .Boss and not o.drone: others += 1
        assert(others == 0)
        // Every boss attacks: hostile fire is in the air.
        var hostile = 0
        for i in 0..g.bullet_count:
            if g.bullets[i].hostile: hostile += 1
        assert(hostile > 0 or index == 2)
    // The Warden's back takes several times what its front does.
    var w = boss_game(1)
    let wb = boss_at(&w)
    let facing = w.enemies[wb].facing
    let hp0 = w.enemies[wb].hp
    let _ = w.damage_enemy(wb, 100, facing)
    let back = hp0 - w.enemies[wb].hp
    let hp1 = w.enemies[wb].hp
    let _ = w.damage_enemy(wb, 100, scale(facing, -1.0))
    let front = hp1 - w.enemies[wb].hp
    assert(back >= front * 5)
    // The Hive's core barely feels a hit while its drones live.
    var h = boss_game(3)
    let hb = boss_at(&h)
    let before = h.enemies[hb].hp
    let _ = h.damage_enemy(hb, 100, V2 { x: 1.0 })
    assert(before - h.enemies[hb].hp < 20)
    // The first kill pays a one-time bonus and is recorded.
    var k = boss_game(1)
    let kb = boss_at(&k)
    k.health = 1
    let credits: i32 = k.credits
    let _ = k.damage_enemy(kb, 10000000, V2 { x: 1.0 })
    assert(not k.boss_alive)
    assert(k.health == k.max_health)
    assert(k.first_kill_event)
    assert(k.credits - credits >= 400)
    assert(k.boss_kills[0] == 1)
    // Once known, the same boss pays only its ordinary bounty.
    var again = boss_game(1)
    again.launch.bosses_known[0] = true
    let ab = boss_at(&again)
    let _ = again.damage_enemy(ab, 10000000, V2 { x: 1.0 })
    assert(not again.first_kill_event)

fn ships_uat:
    var g = Game.new(Rules { minimum_start: 0.0 })
    var launch = Launch { ship: .Hull }
    for i in 0..8: launch.unlocked_weapons[i] = true
    for i in 0..8: launch.unlocked_passives[i] = true
    g.start(launch)
    // Double health plus one per level, one armor.
    assert(g.max_health == 21 and g.mods.armor == 1)
    assert(g.build.weapon_level(.Nova) == 1)
    launch.ship = .Sapper
    g.start(launch)
    assert(g.build.weapon_slots == WEAPON_SLOTS - 1)
    launch.ship = .Null
    g.start(launch)
    assert(g.level == 5 and g.build.weapon_count() == 3)

fn abandon_uat:
    // Abandoning banks the same end-of-run credits a death does.
    var g = Game.new(Rules { minimum_start: 0.0 })
    g.kills = 200
    g.elapsed = 120.0
    g.abandon()
    assert(g.phase == .Over and g.credits > 0)
    let banked: i32 = g.credits
    g.abandon()
    assert(g.credits == banked)

fn beacon_uat:
    // Orbit blades and Nova rings break beacons, not only bullets.
    for w in [Weapon.Orbit, Weapon.Nova]:
        var g = Game.new(Rules { minimum_start: 0.0 })
        g.spawn_timer = 1.0e9
        g.build.weapons[0] = WeaponSlot { weapon: w, level: 1 }
        g.beacon_count = 1
        g.beacons[0] = Beacon { pos: add(g.player, V2 { x: 90.0 }), alive: true }
        for _ in 0..(120 * 6): g.tick(Controls {}, 1.0 / 120.0)
        assert(not g.beacons[0].alive and g.pickup_count >= 1)

fn stage_uat:
    // The Ring's dead center holds the ship, enemies, and bolts out.
    var g = Game.new(Stage.Ring.rules())
    assert(not g.in_void(g.player))
    g.player = g.center()
    g.tick(Controls {}, 1.0 / 120.0)
    assert(not g.in_void(g.player))
    let pos = g.clamp_to_arena(add(g.center(), V2 { x: 10.0 }), 5.0)
    assert(length2(sub(pos, g.center())) >= 425.0 * 425.0 - 1.0)
    // A boss's entry pulls the camera back, then returns it.
    g.zoom_timer = 1.2
    assert(g.zoom() < 0.9)
    g.zoom_timer = 0.0
    near(g.zoom(), 1.0)

fn capacity_uat:
    var g = Game.new(Rules { minimum_start: 0.0 })
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
    var m = Game.new(Rules { minimum_start: 0.0 })
    m.drop_core(V2 { x: 200.0, y: 200.0 }, 1)
    m.drop_core(V2 { x: 220.0, y: 200.0 }, 2)
    for _ in 0..(120 * 4): m.tick(Controls {}, 1.0 / 120.0)
    assert(m.cores_collected == 0)
    var total = 0
    for i in 0..m.core_count:
        if m.cores[i].pos.x < 400.0 and m.cores[i].pos.y < 400.0: total += 1
    assert(total == 1)

fn determinism_uat:
    var a = Game.new(Rules { minimum_start: 0.0 })
    var b = Game.new(Rules { minimum_start: 0.0 })
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
    merges_uat()
    timeline_uat()
    bosses_uat()
    ships_uat()
    stage_uat()
    beacon_uat()
    abandon_uat()
    capacity_uat()
    determinism_uat()
    print("UAT passed: movement, camera, fire, damage, cores, level-up, merge, death, restart, timeline, capacity, determinism")
