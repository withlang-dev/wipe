//! expect-stdout: UAT passed: twelve weapons that change how the ship moves, aims and stands
use game
use tuning
use loadout
use pilots

// A Claw holding one weapon at level V in an empty arena, nothing to hurt it.
fn armed(weapon: Weapon, seed: i32) -> Game:
    var g = Game.new(Rules { minimum_start: 0.0 })
    g.rng = 777 +% (seed as u32) *% 2654435761
    var launch = Launch {}
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    for i in 0..8: launch.unlocked_passives[i] = true
    g.start(launch)
    g.build.weapons[0] = WeaponSlot { weapon, level: MAX_WEAPON_LEVEL }
    g.refresh_mods()
    g.rules.contact_radius = 0.0
    g.rules.spawn_scale = 0.0
    g.spawn_timer = 1.0e9
    g.next_elite = 1.0e9
    g.next_tank = 1.0e9
    g.boss_index = 3
    g.event_index = 12
    g.xp_next = 1000000000
    g

// One fixed step: the game is a value, so the stepped game comes back.
fn step(g_in: Game, motion: V2, aim: V2) -> Game:
    var g = g_in
    g.clear_events()
    g.tick(Controls { motion, aim }, 1.0 / 120.0)
    g

// How far the Tether's blade travels in two seconds with the ship still:
// the aim stick is the chain's handle, so a spun stick whirls the blade
// around the ship, and a held stick leaves it hanging.
fn blade_travel(spin: bool) -> f64:
    var g = armed(.Tether, 1)
    var travel = 0.0
    for i in 0..240:
        let t = i as f64 / 120.0 * 9.42
        let aim = if spin: V2 { x: cos(t), y: sin(t) } else: V2 { x: 1.0 }
        let before: V2 = g.tether[TETHER_LINKS - 1]
        g = step(g, V2 {}, aim)
        if g.tether_live and i > 30: travel += sqrt(length2(sub(g.tether[TETHER_LINKS - 1], before)))
    travel

// A still enemy of a kind near a well: how far it is pulled in a second.
fn pulled(kind: Kind, elite: bool) -> f64:
    var g = armed(.GravityWell, 2)
    // Face right: the well lands 220 px out. Put the enemy 100 px past it.
    let at = add(g.player, V2 { x: 320.0 })
    assert(g.place_enemy(at, kind, elite))
    g.enemies[0].speed = 0.0
    g.enemies[0].age = 1.0
    g.enemies[0].hp = 100000
    // A third of a second of pull: nothing has reached the middle yet.
    for _ in 0..42: g = step(g, V2 {}, V2 { x: 1.0 })
    assert(g.well_count == 1)
    let now: V2 = g.enemies[0].pos
    at.x - now.x

fn main:
    // The Tether whirls on a spun stick and hangs on a held one.
    let spun = blade_travel(true)
    let held = blade_travel(false)
    assert(spun > 600.0)
    assert(held < spun * 0.1)
    // The well pulls a Dart farther than a Block, an elite less, a boss not at all.
    let dart = pulled(.Dart, false)
    let block = pulled(.Block, false)
    let elite = pulled(.Dart, true)
    assert(dart > 60.0 and dart > block * 2.0 and block > 5.0)
    assert(elite < dart * 0.4 and elite > 0.0)
    assert(pulled(.Boss, false) == 0.0)
    assert(Kind.Boss.displacement() == 0.0 and Kind.Dart.displacement() == 1.0)
    // The drone covers the flank: with one enemy ahead and one behind, it
    // shoots the one behind, and only takes the one ahead when alone.
    var g = armed(.Drone, 3)
    let ahead = add(g.player, V2 { x: 300.0 })
    let behind = add(g.player, V2 { x: -300.0 })
    assert(g.place_enemy(ahead, .Block))
    assert(g.place_enemy(behind, .Block))
    for i in 0..2:
        g.enemies[i].speed = 0.0
        g.enemies[i].age = 1.0
        g.enemies[i].hp = 100000
    let from: V2 = g.player
    assert(g.flank_target(from) == 1)
    g.enemy_count = 1
    assert(g.flank_target(from) == 0)
    // The Lob reaches past what is near: a shell lands at its range and
    // bursts there, and an enemy at arm's length is untouched.
    var lob = armed(.Lob, 4)
    let stats = weapon_stats(.Lob, MAX_WEAPON_LEVEL, Mods {})
    let range = stats.speed * stats.lifetime
    let near = add(lob.player, V2 { x: 90.0 })
    let far = add(lob.player, V2 { x: range })
    assert(lob.place_enemy(near, .Block))
    assert(lob.place_enemy(far, .Block))
    for i in 0..2:
        lob.enemies[i].speed = 0.0
        lob.enemies[i].age = 1.0
        lob.enemies[i].hp = 100000
    let near_hp: i32 = lob.enemies[0].hp
    let far_hp: i32 = lob.enemies[1].hp
    for _ in 0..(stats.lifetime * 120.0 + 30.0) as i32: lob = step(lob, V2 {}, V2 { x: 1.0 })
    assert(lob.enemies[0].hp == near_hp)
    assert(lob.enemies[1].hp < far_hp)
    // Duration lengthens a well's life and a shell's range.
    let longer = weapon_stats(.Lob, MAX_WEAPON_LEVEL, Mods { duration: 1.5 })
    assert(longer.lifetime > stats.lifetime * 1.49)
    // Exact replay: the Tether's rope lands in the same place twice.
    let a = blade_travel(true)
    let b = blade_travel(true)
    assert(a == b)
    // Flak: a fan of several bolts that die within a short reach.
    var flak = armed(.Flak, 5)
    flak = step(flak, V2 {}, V2 { x: 1.0 })
    assert(flak.bullet_count >= 5)
    let flak_stats = weapon_stats(.Flak, MAX_WEAPON_LEVEL, Mods {})
    for _ in 0..(flak_stats.lifetime * 120.0 + 4.0) as i32: flak = step(flak, V2 {}, V2 { x: 1.0 })
    assert(flak.bullet_count == 0)
    // A Turret stands where it was dropped and fires at what is in reach.
    var turret = armed(.Turret, 6)
    turret = step(turret, V2 {}, V2 { x: 1.0 })
    assert(turret.turret_count == 1)
    let post: V2 = turret.turrets[0].pos
    assert(turret.place_enemy(add(post, V2 { x: 200.0 }), .Block))
    turret.enemies[0].speed = 0.0
    turret.enemies[0].age = 1.0
    turret.enemies[0].hp = 100000
    let standing: i32 = turret.enemies[0].hp
    for _ in 0..60: turret = step(turret, V2 { x: -1.0 }, V2 { x: 1.0 })
    assert(turret.enemies[0].hp < standing)
    assert(turret.turrets[0].pos.x == post.x and turret.turrets[0].pos.y == post.y)
    // The Sweep's beam turns: its heading differs a quarter second on.
    var sweep = armed(.Sweep, 7)
    sweep = step(sweep, V2 {}, V2 { x: 1.0 })
    let first_phase: f64 = sweep.build.weapons[0].phase
    for _ in 0..30: sweep = step(sweep, V2 {}, V2 { x: 1.0 })
    assert(sweep.build.weapons[0].phase > first_phase + 0.3)
    assert(sweep.beam_count > 0)
    // The Tesla Field shocks what is inside its radius and nothing outside.
    var tesla = armed(.TeslaField, 8)
    let field = weapon_stats(.TeslaField, MAX_WEAPON_LEVEL, Mods {})
    assert(tesla.place_enemy(add(tesla.player, V2 { x: field.radius * 0.6 }), .Block))
    assert(tesla.place_enemy(add(tesla.player, V2 { x: field.radius + 80.0 }), .Block))
    for i in 0..2:
        tesla.enemies[i].speed = 0.0
        tesla.enemies[i].age = 1.0
        tesla.enemies[i].hp = 100000
    for _ in 0..30: tesla = step(tesla, V2 {}, V2 { x: 1.0 })
    assert(tesla.enemies[0].hp < 100000 and tesla.enemies[1].hp == 100000)
    // A Boomerang comes back: out, then home, then caught.
    var ring = armed(.Boomerang, 9)
    ring = step(ring, V2 {}, V2 { x: 1.0 })
    assert(ring.bullet_count == 1 and ring.bullets[0].boomerang)
    let out_stats = weapon_stats(.Boomerang, MAX_WEAPON_LEVEL, Mods {})
    for _ in 0..(out_stats.lifetime * 60.0) as i32: ring = step(ring, V2 {}, V2 { x: 1.0 })
    assert(ring.bullet_count == 1 and ring.bullets[0].pos.x > ring.player.x + 100.0)
    for _ in 0..(out_stats.lifetime * 60.0 + 10.0) as i32: ring = step(ring, V2 {}, V2 { x: 1.0 })
    var caught = true
    for i in 0..ring.bullet_count:
        if ring.bullets[i].boomerang and ring.bullets[i].total == out_stats.lifetime and ring.bullets[i].life < 0.0: caught = false
    assert(caught)
    // A Shockwave shoves a Dart out and marks it; a marked enemy takes half again.
    var shock = armed(.Shockwave, 10)
    let near_dart = add(shock.player, V2 { x: 60.0 })
    assert(shock.place_enemy(near_dart, .Dart))
    shock.enemies[0].speed = 0.0
    shock.enemies[0].age = 1.0
    shock.enemies[0].hp = 100000
    for _ in 0..20: shock = step(shock, V2 {}, V2 { x: 1.0 })
    assert(shock.enemies[0].pos.x > near_dart.x + 30.0)
    assert(shock.enemies[0].marked > 0.0)
    let before_mark: i32 = shock.enemies[0].hp
    let _ = shock.damage_enemy(0, 10, V2 { x: 1.0 })
    assert(before_mark - shock.enemies[0].hp == 15)
    // A Satellite catches hostile fire.
    var sat = armed(.Satellite, 11)
    sat = step(sat, V2 {}, V2 { x: 1.0 })
    let body: V2 = sat.satellite_position(0, 0, 1, weapon_stats(.Satellite, MAX_WEAPON_LEVEL, Mods {}).radius)
    sat.bullets[sat.bullet_count] = Bullet { pos: body, vel: V2 {}, life: 5.0, damage: 3, hostile: true }
    sat.bullet_count += 1
    sat = step(sat, V2 {}, V2 { x: 1.0 })
    var hostile_left = 0
    for i in 0..sat.bullet_count:
        if sat.bullets[i].hostile: hostile_left += 1
    assert(hostile_left == 0)
    // The Repulsor's zone shoves a Dart out while it holds.
    var rep = armed(.Repulsor, 12)
    let close = add(rep.player, V2 { x: 50.0 })
    assert(rep.place_enemy(close, .Dart))
    rep.enemies[0].speed = 0.0
    rep.enemies[0].age = 1.0
    rep.enemies[0].hp = 100000
    for _ in 0..60: rep = step(rep, V2 {}, V2 { x: 1.0 })
    assert(rep.repulse > 0.0 and rep.enemies[0].pos.x > close.x + 60.0)
    // Pierce adds to every bolt; Failsafe revives once, at a share of hull.
    assert(weapon_stats(.Cannon, 1, Mods { pierce: 2 }).pierce == weapon_stats(.Cannon, 1, Mods {}).pierce + 2)
    var saved = armed(.Cannon, 13)
    saved.mods.failsafe = 4
    saved.max_health = 10
    saved.health = 1
    saved.hurt(.Block, false, 5)
    assert(saved.health == 5 and saved.failsafe_used and saved.phase != .Over)
    saved.invulnerable = 0.0
    saved.hurt(.Block, false, 50)
    assert(saved.phase == .Over)
    print("UAT passed: twelve weapons that change how the ship moves, aims and stands")
