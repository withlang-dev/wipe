// Balance bench: every weapon, alone, against the same swarm. The ship
// circles the arena center and aims at the nearest enemy; the swarm is the
// minute-eight mix, respawned to a fixed density. Kills per minute and
// damage-weighted kills are reported per weapon and level, so an outlier
// reads as a number, not a feeling.
use game
use tuning
use loadout
use ships

fn kills_for(weapon: Weapon, level: i32, minute: f64, seconds: f64, density: i32) -> (i32, f64):
    var total = 0
    for seed in 0..3:
        let (k, _) = kills_once(weapon, level, minute, seconds, density, seed)
        total += k
    (total / 3, 0.0)

fn kills_once(weapon: Weapon, level: i32, minute: f64, seconds: f64, density: i32, seed: i32) -> (i32, f64):
    var g = Game.new()
    g.rng = 1234567 +% (seed as u32) *% 2654435761
    var launch = Launch {}
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    for i in 0..8: launch.unlocked_passives[i] = true
    g.start(launch)
    g.build.weapons[0] = WeaponSlot { weapon, level }
    g.rules.contact_radius = 0.0
    g.spawn_timer = 1.0e9
    g.next_elite = 1.0e9
    g.boss_index = 3
    g.event_index = 12
    g.elapsed = minute * 60.0
    // No level-ups: their hit-stop would freeze the weapon being measured.
    g.xp_next = 1000000000
    // Weaver bolts still land: an unkillable hull keeps the weapon firing.
    g.max_health = 100000000
    g.health = 100000000
    var hp_killed = 0.0
    var arcs = 0
    let steps = (seconds * 120.0) as i32
    for i in 0..steps:
        // Keep the swarm at density, spawning off screen as the game does.
        while g.enemy_count < density: g.spawn_enemy()
        var hp_before = 0
        for e in 0..g.enemy_count: hp_before += g.enemies[e].hp
        let t = i as f64 / 120.0
        let c = g.center()
        let goal = V2 { x: c.x + cos(t * 0.5) * 300.0, y: c.y + sin(t * 0.5) * 220.0 }
        var aim = g.aim
        var best = 1.0e12
        for e in 0..g.enemy_count:
            let d = sub(g.enemies[e].pos, g.player)
            if length2(d) < best:
                best = length2(d)
                aim = d
        g.clear_events()
        let kills_before = g.kills
        g.tick(Controls { motion: movement(scale(sub(goal, g.player), 1.0 / 60.0)), aim }, 1.0 / 120.0)
        if g.phase == .Boost:
            g.pending_levels = 0
            g.pending_cache_items = 0
            g.phase = .Running
        let _ = kills_before
        let _ = hp_before
        arcs += g.arc_count
    if weapon == .Arc and seed == 0 and level == 5: print(f"  arc bolts alive per tick, summed: {arcs}")
    (g.kills * 60 / (seconds as i32), hp_killed)

fn main:
    let minute = 8.0
    let seconds = 90.0
    let density = 160
    print(f"kills per minute against the minute-{minute as i32} swarm at density {density}, one weapon, no passives")
    print("weapon       L1     L3     L5")
    for i in 0..BASE_WEAPON_COUNT:
        let w = weapon_at(i)
        let (a, _) = kills_for(w, 1, minute, seconds, density)
        let (b, _) = kills_for(w, 3, minute, seconds, density)
        let (c, _) = kills_for(w, 5, minute, seconds, density)
        print(f"{w.name()}   {a}   {b}   {c}")
    print("merged (final, no levels)")
    for i in BASE_WEAPON_COUNT..WEAPON_COUNT:
        let w = weapon_at(i)
        let (a, _) = kills_for(w, 1, 14.0, seconds, 260)
        print(f"{w.name()}   {a}")
    0
