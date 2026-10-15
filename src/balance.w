// Balance bench: weapons against the same swarm. The ship circles the
// arena center and aims as the bot does; the swarm is the minute-eight mix,
// respawned to a fixed density. Kills per minute are reported, so an
// outlier reads as a number, not a feeling.
//
//   balance            every base weapon alone at L1, L3, L5; every merge
//   balance scaling    every base weapon at L5 with each passive at max,
//                      as a ratio to the weapon alone
//   balance pairs [MINUTE DENSITY]   every pair of base weapons at L5, kills
//                      a minute, with each weapon alone on the same bench
//   balance ships      every ship with every base weapon at L5
//   balance five [MINUTE DENSITY]   every base weapon at L5 on one bench
//   balance bosses [SEEDS]          every base weapon at L5 against every
//                                   boss at its minute, alone, as damage a second
//   balance pair A B [SEEDS [MINUTE DENSITY]]   one pair against the shared-swarm expectation
use game
use tuning
use loadout
use ships
use pilots
use std.process.{args}
use std.string.parse

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
fn cmd_pairs(minute: f64, density: i32) -> i32:
    var header = "weapon,alone"
    for j in 0..BASE_WEAPON_COUNT: header = header ++ "," ++ weapon_at(j).name()
    print(header)
    for i in 0..BASE_WEAPON_COUNT:
        let w = weapon_at(i)
        var row = f"{w.name()},{kills(Bench { first: w, minute, density })}"
        for j in 0..BASE_WEAPON_COUNT:
            if j <= i: row = row ++ ","
            else: row = row ++ f",{kills(Bench { first: w, second: weapon_at(j), paired: true, minute, density })}"
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

// One pair, named, with more seeds: the two alone and together, and the
// pair against the shared-swarm expectation (stronger + half the weaker).
fn cmd_pair(a: str, b: str, seeds: i32, minute: f64, density: i32) -> i32:
    var first = Weapon.Cannon
    var second = Weapon.Cannon
    var found = 0
    for i in 0..WEAPON_COUNT:
        if weapon_at(i).name() == a: { first = weapon_at(i); found += 1 }
        if weapon_at(i).name() == b: { second = weapon_at(i); found += 1 }
    if found < 2:
        print(f"unknown weapon in {a}, {b}")
        return 1
    let ka = kills(Bench { first, minute, density }, seeds)
    let kb = kills(Bench { first: second, minute, density }, seeds)
    let kab = kills(Bench { first, second, paired: true, minute, density }, seeds)
    let hi = if ka > kb: ka else: kb
    let lo = if ka > kb: kb else: ka
    let expect = (hi as f64) * 1.03 + (lo as f64) * 0.46
    print(f"{a} {ka}  {b} {kb}  together {kab}  expected {expect as i32}  ratio {(kab as f64 / expect * 100.0) as i32}")
    0

// Every base weapon at V on one bench: the quick look while tuning.
fn cmd_five(minute: f64, density: i32) -> i32:
    print(f"base weapons at V, minute {minute as i32}, density {density}")
    for i in 0..BASE_WEAPON_COUNT:
        let w = weapon_at(i)
        print(f"{w.name()} {kills(Bench { first: w, minute, density })}")
    0

// Damage a second one weapon deals a boss over thirty seconds, the ship
// held at a distance from the boss (behind the Warden, inside the
// Keeper's sector), aiming at it, with an unkillable hull: the weapon's
// reach against that boss's shape, with no pilot in the way.
fn boss_dps(weapon: Weapon, boss: i32, distance: f64, seed: i32) -> f64:
    var g = Game.new(Rules { minimum_start: 0.0 })
    g.rng = 1234567 +% (seed as u32) *% 2654435761
    var launch = Launch {}
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    for i in 0..PASSIVE_COUNT: launch.unlocked_passives[i] = true
    g.start(launch)
    g.build.weapons[0] = WeaponSlot { weapon, level: 5 }
    g.rules.spawn_scale = 0.0
    g.rules.contact_radius = 0.0
    g.spawn_timer = 1.0e9
    g.next_elite = 1.0e9
    g.next_tank = 1.0e9
    g.event_index = 12
    g.xp_next = 1000000000
    g.max_health = 100000000
    g.health = 100000000
    let minute = if boss == 0: 5.0 else if boss == 2 or boss == 4: 15.0 else: 10.0
    g.jump_to(minute * 60.0)
    g.boss_index = if boss == 0: 1 else if boss == 2 or boss == 4: 3 else: 2
    g.spawn_boss_of(boss)
    g.freeze = 0.0
    var before = 0
    if let Some((hp, _)) = g.boss_health(): before = hp
    for _ in 0..(30 * 120):
        // Hold the ship: behind the Warden, down the Keeper's sector,
        // else on the boss's facing side, at the distance asked.
        for i in 0..g.enemy_count:
            let e = g.enemies[i]
            if e.kind != .Boss or e.boss < 0: continue
            let dir = if boss == 0: scale(e.facing, -1.0) else if boss == 4: V2 { x: cos(e.angle), y: sin(e.angle) } else: e.facing
            g.player = g.clamp_to_arena(add(e.pos, scale(dir, distance)), 20.0)
            break
        g.clear_events()
        g.tick(Controls { aim: nearest_aim(&g) }, 1.0 / 120.0)
        if g.phase == .Boost:
            g.pending_levels = 0
            g.pending_cache_items = 0
            g.phase = .Running
        if not g.boss_alive: return before as f64 / 30.0
    var after = 0
    if let Some((hp, _)) = g.boss_health(): after = hp
    (before - after) as f64 / 30.0

fn cmd_bosses(seeds: i32) -> i32:
    for distance in [120.0, 280.0]:
        print(f"held {distance as i32} px from the boss, damage a second")
        var header = "weapon"
        for b in 0..BOSS_COUNT: header = header ++ "," ++ BOSS_NAMES[b]
        print(header)
        for i in 0..BASE_WEAPON_COUNT:
            let w = weapon_at(i)
            var row = w.name()
            for b in 0..BOSS_COUNT:
                var total = 0.0
                for seed in 0..seeds: total += boss_dps(w, b, distance, seed)
                row = row ++ f",{(total / seeds as f64) as i32}"
            print(row)
    0

fn main:
    let argv = args()
    if argv.len() < 2: return cmd_solo()
    if argv[1] == "scaling": return cmd_scaling()
    if argv[1] == "pairs": return cmd_pairs(if argv.len() > 2: parse(argv[2]) as f64 else: 8.0, if argv.len() > 3: parse(argv[3]) else: 160)
    if argv[1] == "ships": return cmd_ships()
    if argv[1] == "bosses": return cmd_bosses(if argv.len() > 2: parse(argv[2]) else: 2)
    if argv[1] == "five": return cmd_five(if argv.len() > 2: parse(argv[2]) as f64 else: 8.0, if argv.len() > 3: parse(argv[3]) else: 160)
    if argv[1] == "pair" and argv.len() >= 4:
        let seeds = if argv.len() > 4: parse(argv[4]) else: 4
        let minute = if argv.len() > 5: parse(argv[5]) as f64 else: 8.0
        let density = if argv.len() > 6: parse(argv[6]) else: 160
        return cmd_pair(argv[2], argv[3], seeds, minute, density)
    print("usage: balance [scaling | pairs | ships]")
    1
