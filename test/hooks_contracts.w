//! expect-stdout: UAT passed: a mark draws fire, lightning runs on through held enemies, a beam slows and herds what it crosses
use game
use tuning
use loadout
use ships
use pilots

// A Claw on the Field with nothing spawning, armed as asked.
fn armed(weapon: Weapon, level: i32, seed: i32) -> Game:
    var g = Game.new(Stage.Field.rules())
    g.rng = 777 +% (seed as u32) *% 2654435761
    var launch = Launch {}
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    for i in 0..8: launch.unlocked_passives[i] = true
    g.start(launch)
    g.build.weapons[0] = WeaponSlot { weapon, level }
    g.rules.spawn_scale = 0.0
    g.rules.contact_radius = 0.0
    g.spawn_timer = 1.0e9
    g.next_elite = 1.0e9
    g.next_tank = 1.0e9
    g.xp_next = 1000000000
    g

fn still(g_in: Game, seconds: f64) -> Game:
    var g = g_in
    for _ in 0..(seconds * 120.0) as i32:
        g.clear_events()
        g.tick(Controls { aim: V2 { x: 1.0 } }, 1.0 / 120.0)
    g

// Six one-hit Blocks in a line, sixty apart, starting 260 px right of the ship.
fn lined(seed: i32) -> Game:
    var g = armed(.Cannon, 1, seed)
    let origin = add(g.player, V2 { x: 200.0 })
    for k in 0..6:
        assert(g.place_enemy(add(origin, V2 { x: 60.0 * (k + 1) as f64 }), .Block))
        g.enemies[k].hp = 1
    g

fn main:
    // A marked Block twice as far as a plain one is the nearer target to
    // a weapon choosing its own; not to the aim assist.
    var mark = armed(.Cannon, 1, 1)
    assert(mark.place_enemy(add(mark.player, V2 { x: 100.0 }), .Block))
    assert(mark.place_enemy(add(mark.player, V2 { x: -160.0 }), .Block))
    mark.enemies[1].marked = 2.0
    assert(mark.nearest_enemy(mark.player, 900.0, false) == 1)
    assert(mark.nearest_enemy(mark.player, 900.0, false, false) == 0)
    // Lightning with two hops takes two enemies from a line of six; the
    // same line inside a well conducts, and it takes four.
    var dry = lined(2)
    let origin = add(dry.player, V2 { x: 200.0 })
    dry.arc_chain(origin, 2, 90.0, 5)
    assert(dry.kills == 2)
    var wet = lined(2)
    assert(not wet.held(add(origin, V2 { x: 180.0 })))
    wet.wells[0] = Well { pos: add(origin, V2 { x: 210.0 }), radius: 400.0 }
    wet.well_count = 1
    assert(wet.held(add(origin, V2 { x: 180.0 })))
    wet.arc_chain(origin, 2, 90.0, 5)
    assert(wet.kills == 4)
    // The Tesla field holds too, only while one is carried.
    var field = armed(.TeslaField, 1, 3)
    assert(not field.held(add(field.player, V2 { x: 40.0 })))
    field = still(field, 0.1)
    assert(field.held(add(field.player, V2 { x: 40.0 })))
    assert(not field.held(add(field.player, V2 { x: 900.0 })))
    // A Sweep's beam slows what it crosses: a Block in reach crawls at
    // half speed for a moment after the beam passes.
    var sweep = armed(.Sweep, 1, 4)
    assert(sweep.place_enemy(add(sweep.player, V2 { x: 200.0 }), .Block))
    sweep.enemies[0].hp = 100000
    sweep.enemies[0].age = 10.0
    sweep = still(sweep, 0.25)
    assert(sweep.enemies[0].slowed > 0.0)
    // ...and is carried along with the beam's turn, off the line it came in on.
    assert((sweep.enemies[0].pos.y - sweep.player.y).abs() > 5.0)
    var slow = armed(.Cannon, 0, 5)
    var fast = armed(.Cannon, 0, 5)
    assert(slow.place_enemy(add(slow.player, V2 { x: 400.0 }), .Block))
    assert(fast.place_enemy(add(fast.player, V2 { x: 400.0 }), .Block))
    slow.enemies[0].age = 10.0
    fast.enemies[0].age = 10.0
    slow.enemies[0].slowed = 10.0
    slow = still(slow, 0.5)
    fast = still(fast, 0.5)
    let crawled = 400.0 - (slow.enemies[0].pos.x - slow.player.x)
    let ran = 400.0 - (fast.enemies[0].pos.x - fast.player.x)
    assert(ran > 20.0 and crawled > 5.0 and crawled < ran * 0.6)
    // A crossing strike does more to a big hull: a ring crossing a boss
    // does four times a Block's damage, a Tank half again.
    assert(sweep.cross_share(.Boss) == 4.0 and sweep.cross_share(.Tank) == 1.5 and sweep.cross_share(.Block) == 1.0)
    var ringed = armed(.Nova, 5, 6)
    ringed.jump_to(300.0)
    ringed.boss_index = 1
    ringed.spawn_boss_of(0)
    ringed.freeze = 0.0
    var hp = 0
    if let Some((h, _)) = ringed.boss_health(): hp = h
    for i in 0..ringed.enemy_count:
        if ringed.enemies[i].kind == .Boss: ringed.player = add(ringed.enemies[i].pos, V2 { x: 60.0 })
    ringed = still(ringed, 3.0)
    var left = 0
    if let Some((h, _)) = ringed.boss_health(): left = h
    let ring_damage = weapon_stats(.Nova, 5, Mods {}).damage
    assert(hp - left >= ring_damage * 4)
    // A bullet's hit leaves a boss its whole hit cooldown; an overlapping
    // strike leaves a quarter. A piercing bolt crossing a big hull lands once.
    var bolt = armed(.Cannon, 5, 7)
    bolt.build.passives[0] = PassiveSlot { passive: .Pierce, level: 5 }
    bolt.refresh_mods()
    bolt.jump_to(300.0)
    bolt.boss_index = 1
    bolt.spawn_boss_of(0)
    bolt.freeze = 0.0
    var bi = -1
    for i in 0..bolt.enemy_count:
        if bolt.enemies[i].kind == .Boss: bi = i
    bolt.player = add(bolt.enemies[bi].pos, V2 { x: -200.0 })
    var full = 0
    if let Some((h, _)) = bolt.boss_health(): full = h
    var seen = false
    for _ in 0..240:
        bolt.clear_events()
        bolt.tick(Controls { aim: V2 { x: 1.0 } }, 1.0 / 120.0)
        for i in 0..bolt.enemy_count:
            if bolt.enemies[i].kind == .Boss and bolt.enemies[i].hp < full and not seen:
                seen = true
                assert(bolt.enemies[i].hit_cd > 0.1)
    assert(seen)
    var tesla = armed(.TeslaField, 5, 8)
    tesla.jump_to(300.0)
    tesla.boss_index = 1
    tesla.spawn_boss_of(0)
    tesla.freeze = 0.0
    for i in 0..tesla.enemy_count:
        if tesla.enemies[i].kind == .Boss: tesla.player = add(tesla.enemies[i].pos, V2 { x: -80.0 })
    var fh = 0
    if let Some((h, _)) = tesla.boss_health(): fh = h
    var ticked = false
    for _ in 0..240:
        tesla.clear_events()
        tesla.tick(Controls { aim: V2 { x: 1.0 } }, 1.0 / 120.0)
        for i in 0..tesla.enemy_count:
            if tesla.enemies[i].kind == .Boss and tesla.enemies[i].hp < fh and not ticked:
                ticked = true
                assert(tesla.enemies[i].hit_cd < 0.2)
    assert(ticked)
    print("UAT passed: a mark draws fire, lightning runs on through held enemies, a beam slows and herds what it crosses")
