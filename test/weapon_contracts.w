//! expect-stdout: UAT passed: the Tether swings on a turn, the well pulls by kind, the drone covers the flank, the Lob reaches past
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

// How far the Tether's blade and the ship travel in two seconds of a given
// input: on a committed turn the blade swings wide and outruns the ship;
// flicked each frame, the rope just follows.
fn blade_travel(wiggle: bool) -> (f64, f64):
    var g = armed(.Tether, 1)
    var travel = 0.0
    var ship = 0.0
    for i in 0..240:
        let t = i as f64 / 120.0
        // A committed circle, or the stick flicked left and right each frame.
        let m = if wiggle: (if i % 2 == 0: V2 { x: 1.0 } else: V2 { x: -1.0 }) else: V2 { x: cos(t * 2.5), y: sin(t * 2.5) }
        let before: V2 = g.tether[TETHER_LINKS - 1]
        let at: V2 = g.player
        g = step(g, m, V2 { x: 1.0 })
        if g.tether_live and i > 0:
            travel += sqrt(length2(sub(g.tether[TETHER_LINKS - 1], before)))
            ship += sqrt(length2(sub(g.player, at)))
    (travel, ship)

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
    // The Tether swings wide on a committed turn and barely moves on a wiggle.
    let (swing, swing_ship) = blade_travel(false)
    let (wiggle, wiggle_ship) = blade_travel(true)
    assert(swing > swing_ship * 1.3)
    assert(wiggle < wiggle_ship * 1.1)
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
    let (a, _) = blade_travel(false)
    let (b, _) = blade_travel(false)
    assert(a == b)
    print("UAT passed: the Tether swings on a turn, the well pulls by kind, the drone covers the flank, the Lob reaches past")
