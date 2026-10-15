//! expect-stdout: UAT passed: the Shield takes one hit, comes back on its clock, sooner a rank, and never the Null's
use game
use tuning
use loadout
use ships
use pilots

fn shielded(level: i32) -> Game:
    var g = Game.new(Rules { minimum_start: 0.0 })
    var launch = Launch {}
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    for i in 0..PASSIVE_COUNT: launch.unlocked_passives[i] = true
    g.start(launch)
    g.rules.spawn_scale = 0.0
    g.spawn_timer = 1.0e9
    g.next_elite = 1.0e9
    g.next_tank = 1.0e9
    g.build.passives[0] = PassiveSlot { passive: .Shield, level }
    g.refresh_mods()
    g.freeze = 0.0
    g

fn still(g_in: Game, seconds: f64) -> Game:
    var g = g_in
    for _ in 0..(seconds * 120.0) as i32:
        g.clear_events()
        g.tick(Controls {}, 1.0 / 120.0)
    g

fn main:
    assert(PASSIVE_COUNT == 18 and passive_at(17) == .Shield and Passive.Shield.index() == 17)
    // One hit taken whole; the next, inside the recharge, lands.
    var g = shielded(1)
    let full: i32 = g.health
    g.combo = 7
    g.hurt(.Block, false, 3)
    assert(g.health == full and g.shield_event and g.combo == 7)
    assert(g.shield_cd > 11.9 and g.shield_cd <= 12.0)
    g = still(g, 1.0)
    g.hurt(.Block, false, 3)
    assert(g.health == full - 3)
    // Back after its clock.
    g = still(g, 11.5)
    assert(g.shield_cd == 0.0)
    g.hurt(.Block, false, 3)
    assert(g.health == full - 3)
    // Sooner a rank: six seconds at V.
    var v = shielded(5)
    assert(v.shield_recharge() == 6.0)
    v.hurt(.Block, false, 3)
    assert(v.shield_cd <= 6.0 and v.shield_cd > 5.9)
    // The Null's touch is not taken.
    var n = shielded(3)
    let before: i32 = n.health
    n.hurt(.Null, false, 1000)
    assert(n.health < before)
    // Without the passive, nothing changes.
    var plain = shielded(0)
    plain.build.passives[0] = PassiveSlot {}
    plain.refresh_mods()
    let hull: i32 = plain.health
    plain.hurt(.Block, false, 3)
    assert(plain.health == hull - 3 and not plain.shield_event)
    print("UAT passed: the Shield takes one hit, comes back on its clock, sooner a rank, and never the Null's")
