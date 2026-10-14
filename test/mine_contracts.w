//! expect-stdout: UAT passed: proximity mines where the ship is, paused near one, capped by Projectiles
use game
use tuning
use loadout
use pilots

// A Claw holding only the Mines at level V, nothing to shoot it, no swarm.
fn miner(seed: i32, count_bonus: i32) -> Game:
    var g = Game.new(Rules { minimum_start: 0.0 })
    g.rng = 31337 +% (seed as u32) *% 2654435761
    var launch = Launch {}
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    for i in 0..8: launch.unlocked_passives[i] = true
    launch.shop.count = count_bonus
    g.start(launch)
    g.build.weapons[0] = WeaponSlot { weapon: .Mines, level: MAX_WEAPON_LEVEL }
    g.refresh_mods()
    g.spawn_timer = 1.0e9
    // An empty arena: the stage's spawn scale at zero stops the floor and
    // the trickle, so nothing walks into a mine.
    g.rules.spawn_scale = 0.0
    g.next_elite = 1.0e9
    g.boss_index = 3
    g.event_index = 12
    g.xp_next = 1000000000
    g

// Fly for a while: a fixed heading, or a wide circle when `circle`, so the
// ship never parks against a wall.
fn run(g_in: Game, seconds: f64, motion: V2, circle: bool = false) -> Game:
    var g = g_in
    let steps = (seconds * 120.0) as i32
    for i in 0..steps:
        let t = i as f64 / 120.0
        let m = if circle: V2 { x: cos(t * 0.5), y: sin(t * 0.5) } else: motion
        g.clear_events()
        g.tick(Controls { motion: m, aim: V2 { x: 1.0 } }, 1.0 / 120.0)
    g

fn main:
    // Cruising: one mine about every cooldown, at the ship, none stacked.
    let stats = weapon_stats(.Mines, MAX_WEAPON_LEVEL, Mods {})
    // Three seconds at level I, under two at V.
    assert(stats.cooldown > 1.5 and stats.cooldown <= 3.0)
    assert(weapon_stats(.Mines, 1, Mods {}).cooldown == 3.0)
    let cruise = run(miner(1, 0), 12.0, V2 {}, circle: true)
    assert(cruise.mine_count >= 4 and cruise.mine_count <= 7)
    for i in 0..cruise.mine_count:
        for j in 0..cruise.mine_count:
            if i != j: assert(length2(sub(cruise.mines[i].pos, cruise.mines[j].pos)) > 100.0)
    // Parked: the first mine drops, then none, however long: standing still
    // stops production. Moving away releases the next at once.
    let parked = run(miner(2, 0), 20.0, V2 {})
    assert(parked.mine_count == 1)
    let moved = run(parked, 1.0, V2 { x: 1.0 })
    assert(moved.mine_count == 2)
    // The field is capped at eight; the oldest makes room; Projectiles raise
    // the cap by up to four and never the rate.
    let field = run(miner(3, 0), 60.0, V2 {}, circle: true)
    let wide = run(miner(3, 2), 60.0, V2 {}, circle: true)
    let widest = run(miner(3, 9), 60.0, V2 {}, circle: true)
    assert(field.mine_count == MINE_BASE_CAP)
    assert(wide.mine_count == MINE_BASE_CAP + 2)
    assert(widest.mine_count == MINE_BASE_CAP + MINE_CAP_BONUS)
    assert(weapon_stats(.Mines, MAX_WEAPON_LEVEL, Mods { count: 9 }).cooldown == stats.cooldown)
    // Area widens the blast and the trigger; Fire rate and Cooldown shorten
    // the interval.
    let big = weapon_stats(.Mines, MAX_WEAPON_LEVEL, Mods { area: 1.5 })
    assert(big.radius > stats.radius * 1.49 and big.radius < stats.radius * 1.51)
    assert(weapon_stats(.Mines, MAX_WEAPON_LEVEL, Mods { cannon_rate: 0.8 }).cooldown < stats.cooldown)
    assert(weapon_stats(.Mines, MAX_WEAPON_LEVEL, Mods { cooldown: 0.8 }).cooldown < stats.cooldown)
    // A mine detonates when an enemy enters its trigger ring, and only then.
    var trap = run(miner(4, 0), 0.5, V2 {})
    assert(trap.mine_count == 1)
    let at: V2 = trap.mines[0].pos
    let reach = trap.mines[0].radius * MINE_TRIGGER
    assert(trap.place_enemy(add(at, V2 { x: reach + 60.0 }), .Block))
    trap = run(trap, 0.05, V2 {})
    assert(trap.mine_count == 1)
    let kills_before: i32 = trap.kills
    assert(trap.place_enemy(add(at, V2 { x: reach * 0.5 }), .Block))
    trap = run(trap, 0.05, V2 {})
    assert(trap.mine_count == 0 and trap.kills > kills_before)
    // Exact replay: the same seed and inputs lay the same field.
    let a = run(miner(5, 1), 30.0, V2 {}, circle: true)
    let b = run(miner(5, 1), 30.0, V2 {}, circle: true)
    assert(a.mine_count == b.mine_count)
    for i in 0..a.mine_count: assert(a.mines[i].pos.x == b.mines[i].pos.x and a.mines[i].pos.y == b.mines[i].pos.y)
    print("UAT passed: proximity mines where the ship is, paused near one, capped by Projectiles")
