//! expect-stdout: UAT passed: Tanks arrive on their clock, shrug off the first points of a hit, and draw homing fire
use game
use tuning
use loadout
use ships
use pilots

fn fresh(seed: i32) -> Game:
    var g = Game.new(Stage.Field.rules())
    g.rng = 4242 +% (seed as u32) *% 2654435761
    var launch = Launch {}
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    for i in 0..8: launch.unlocked_passives[i] = true
    g.start(launch)
    g

fn tanks(g: &Game) -> i32:
    var n = 0
    for i in 0..g.enemy_count:
        if g.enemies[i].kind == .Tank: n += 1
    n

fn main:
    // None before 2:30; one soon after, and another on the interval.
    var g = fresh(1)
    g.jump_to(TANK_FIRST - 1.0)
    assert(tanks(&g) == 0)
    for _ in 0..240:
        g.clear_events()
        g.tick(Controls {}, 1.0 / 120.0)
    assert(tanks(&g) == 1)
    g.jump_to(TANK_FIRST + TANK_INTERVAL - 1.0)
    for _ in 0..240:
        g.clear_events()
        g.tick(Controls {}, 1.0 / 120.0)
    assert(tanks(&g) == 2)
    // Plating: at five minutes four points come off every hit, never all.
    var hit = fresh(2)
    hit.jump_to(300.0)
    hit.rules.spawn_scale = 0.0
    hit.next_tank = 1.0e9
    assert(hit.tank_armor() == 4)
    assert(hit.place_enemy(add(hit.player, V2 { x: 300.0 }), .Tank))
    let full: i32 = hit.enemies[0].max_hp
    assert(full > 40)
    let _ = hit.damage_enemy(0, 3, V2 { x: 1.0 })
    assert(hit.enemies[0].hp == full - 1)
    hit.enemies[0].hit_cd = 0.0
    let _ = hit.damage_enemy(0, 20, V2 { x: 1.0 })
    assert(hit.enemies[0].hp == full - 1 - 16)
    // The lure: a Tank twice as far as a Block is the nearer target to a
    // weapon choosing its own, and not to the aim assist.
    var lure = fresh(3)
    lure.rules.spawn_scale = 0.0
    lure.next_tank = 1.0e9
    assert(lure.place_enemy(add(lure.player, V2 { x: 100.0 }), .Block))
    assert(lure.place_enemy(add(lure.player, V2 { x: -220.0 }), .Tank))
    assert(lure.enemies[lure.nearest_enemy(lure.player, 900.0, false)].kind == .Tank)
    assert(lure.enemies[lure.nearest_enemy(lure.player, 900.0, false, false)].kind == .Block)
    assert(lure.enemies[lure.flank_target(lure.player)].kind == .Tank)
    // Tanks replay exactly.
    let (a, _) = fly(fresh(4), .Careful, 200.0)
    let (b, _) = fly(fresh(4), .Careful, 200.0)
    assert(a.elapsed == b.elapsed and a.kills == b.kills and a.health == b.health)
    print("UAT passed: Tanks arrive on their clock, shrug off the first points of a hit, and draw homing fire")
