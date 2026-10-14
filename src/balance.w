// Balance bench: weapons against the same swarm. The ship circles the
// arena center and aims as the bot does; the swarm is the minute-eight mix,
// respawned to a fixed density. Kills per minute are reported, so an
// outlier reads as a number, not a feeling.
//
//   balance            every base weapon alone at L1, L3, L5; every merge
//   balance scaling    every base weapon at L5 with each passive at max,
//                      as a ratio to the weapon alone
//   balance pairs      every pair of base weapons at L5, kills a minute,
//                      with each weapon alone on the same bench
//   balance ships      every ship with every base weapon at L5
use game
use tuning
use loadout
use ships
use pilots
use std.process.{args}

type Bench {
    first: Weapon = .Cannon,
    second: Weapon = .Cannon,
    paired: bool = false,
    level: i32 = 5,
    passive: Passive = .Damage,
    passive_level: i32 = 0,
    ship: Ship = .Claw,
    ship_level: i32 = 0,
    minute: f64 = 8.0,
    seconds: f64 = 45.0,
    density: i32 = 160,
}
impl Copy for Bench

// Kills a minute on one bench, averaged over the seeds.
fn kills(b: Bench, seeds: i32 = 2) -> i32:
    var total = 0
    for seed in 0..seeds: total += kills_once(b, seed)
    total / seeds

fn kills_once(b: Bench, seed: i32) -> i32:
    var g = Game.new()
    g.rng = 1234567 +% (seed as u32) *% 2654435761
    var launch = Launch { ship: b.ship }
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    for i in 0..PASSIVE_COUNT: launch.unlocked_passives[i] = true
    g.start(launch)
    g.build.weapons[0] = WeaponSlot { weapon: b.first, level: b.level }
    if b.paired: g.build.weapons[1] = WeaponSlot { weapon: b.second, level: b.level }
    if b.passive_level > 0: g.build.passives[0] = PassiveSlot { passive: b.passive, level: b.passive_level }
    g.level = b.ship_level
    g.refresh_mods()
    g.rules.contact_radius = 0.0
    g.spawn_timer = 1.0e9
    g.next_elite = 1.0e9
    g.next_tank = 1.0e9
    g.boss_index = 3
    g.event_index = 12
    g.jump_to(b.minute * 60.0)
    // No level-ups: their hit-stop would freeze the weapon being measured.
    g.xp_next = 1000000000
    // An unkillable hull keeps the weapon firing.
    g.max_health = 100000000
    g.health = 100000000
    let steps = (b.seconds * 120.0) as i32
    for i in 0..steps:
        // Keep the swarm at density, spawning off screen as the game does.
        while g.enemy_count < b.density: g.spawn_enemy()
        let t = i as f64 / 120.0
        let c = g.center()
        let goal = V2 { x: c.x + cos(t * 0.5) * 300.0, y: c.y + sin(t * 0.5) * 220.0 }
        g.clear_events()
        g.tick(Controls { motion: movement(scale(sub(goal, g.player), 1.0 / 60.0)), aim: nearest_aim(&g) }, 1.0 / 120.0)
        if g.phase == .Boost:
            g.pending_levels = 0
            g.pending_cache_items = 0
            g.phase = .Running
    g.kills * 60 / (b.seconds as i32)

fn cmd_solo -> i32:
    print("kills per minute against the minute-8 swarm at density 160, one weapon, no passives")
    print("weapon       L1     L3     L5")
    for i in 0..BASE_WEAPON_COUNT:
        let w = weapon_at(i)
        let a = kills(Bench { first: w, level: 1 }, 3)
        let b = kills(Bench { first: w, level: 3 }, 3)
        let c = kills(Bench { first: w, level: 5 }, 3)
        print(f"{w.name()}   {a}   {b}   {c}")
    print("merged (final, no levels)")
    for i in BASE_WEAPON_COUNT..WEAPON_COUNT:
        let w = weapon_at(i)
        let a = kills(Bench { first: w, level: 1, minute: 14.0, density: 260 }, 3)
        print(f"{w.name()}   {a}")
    0

// A table of every base weapon at V against every passive at its top
// level: kills a minute with the passive over kills a minute without, in
// hundredths. A row with no cell past 100 is a weapon nothing scales.
fn cmd_scaling -> i32:
    var header = "weapon,alone"
    for p in 0..PASSIVE_COUNT: header = header ++ "," ++ passive_at(p).name()
    print(header)
    for i in 0..BASE_WEAPON_COUNT:
        let w = weapon_at(i)
        let alone = kills(Bench { first: w })
        var row = f"{w.name()},{alone}"
        for p in 0..PASSIVE_COUNT:
            let with_it = kills(Bench { first: w, passive: passive_at(p), passive_level: MAX_PASSIVE_LEVEL })
            let ratio = if alone > 0: with_it * 100 / alone else: 0
            row = row ++ f",{ratio}"
        print(row)
    0

// Every pair of base weapons at V in two slots, kills a minute, after a
// row of each weapon alone. The two share one swarm, so a pair never
// reaches the sum of its parts; a synergy is a pair that beats the rest
// of its row.
fn cmd_pairs -> i32:
    var header = "weapon,alone"
    for j in 0..BASE_WEAPON_COUNT: header = header ++ "," ++ weapon_at(j).name()
    print(header)
    for i in 0..BASE_WEAPON_COUNT:
        let w = weapon_at(i)
        var row = f"{w.name()},{kills(Bench { first: w })}"
        for j in 0..BASE_WEAPON_COUNT:
            if j <= i: row = row ++ ","
            else: row = row ++ f",{kills(Bench { first: w, second: weapon_at(j), paired: true })}"
        print(row)
    0

// Every ship with every base weapon at V, at run level 15, kills a minute:
// what each hull wants to carry. Survival is the profile's to measure.
fn cmd_ships -> i32:
    var header = "ship"
    for j in 0..BASE_WEAPON_COUNT: header = header ++ "," ++ weapon_at(j).name()
    print(header)
    for i in 0..SHIP_COUNT:
        let ship = ship_at(i)
        var row = ship.name()
        for j in 0..BASE_WEAPON_COUNT:
            row = row ++ f",{kills(Bench { first: weapon_at(j), ship, ship_level: 15 })}"
        print(row)
    0

fn main:
    let argv = args()
    if argv.len() < 2: return cmd_solo()
    if argv[1] == "scaling": return cmd_scaling()
    if argv[1] == "pairs": return cmd_pairs()
    if argv[1] == "ships": return cmd_ships()
    print("usage: balance [scaling | pairs | ships]")
    1
