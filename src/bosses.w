// Boss bench: each boss against a build typical of its minute, flown by the
// careful bot and by a ship that stands still. Reports time to kill, hits
// taken, and deaths, so "requires dodging" and "massive health" are numbers.
use game
use tuning
use loadout
use ships
use pilots

fn armed(index: i32, seed: i32) -> Game:
    var g = test_game(.Claw, seed, Rules { minimum_start: 0.0 })
    let level = 1 + index
    g.build.weapons[0] = WeaponSlot { weapon: .Cannon, level: level + 1 }
    g.build.add_weapon(.Orbit)
    g.build.add_weapon(.Arc)
    if index >= 2: g.build.add_weapon(.Nova)
    for _ in 0..level:
        g.build.upgrade_weapon(.Orbit)
        g.build.upgrade_weapon(.Arc)
        if index >= 2: g.build.upgrade_weapon(.Nova)
    g.build.add_passive(.Damage)
    g.build.add_passive(.FireRate)
    g.level = 8 + index * 8
    g.xp_next = 1000000000
    g.boss_index = index
    g.elapsed = 300.0 * index as f64
    g.spawn_boss()
    g

fn fight(index: i32, style: Style, seed: i32) -> (f64, i32, bool, f64):
    var g = armed(index, seed)
    let start = g.elapsed
    var hits = 0
    while g.phase != .Over and g.boss_alive and g.elapsed < start + 240.0:
        g.clear_events()
        g.tick(controls(&g, style), 1.0 / 120.0)
        if g.hurt_event:
            hits += 1
            if false:
                print(f"  hit at {g.elapsed - start}: health {g.health}/{g.max_health} before {g.health_before} beat {g.enemies[0].state % 30}")
        if g.phase == .Boost:
            g.pending_levels = 0
            g.pending_cache_items = 0
            g.phase = .Running
    var left = 0.0
    if let Some((hp, max_hp)) = g.boss_health(): left = hp as f64 / max_hp as f64
    if not g.boss_alive: left = 0.0
    (g.elapsed - start, hits, g.phase == .Over, left)

fn main:
    print("boss      pilot       seconds  hits  deaths (of 4)")
    for index in 1..4:
        for style in [Style.Careful, Style.Stationary]:
            var seconds = 0.0
            var hits = 0
            var deaths = 0
            var left = 0.0
            for seed in 0..4:
                let (s, h, died, l) = fight(index, style, seed)
                left += l
                seconds += s
                hits += h
                if died: deaths += 1
            let label = if style == .Careful: "careful   " else: "stationary"
            print(f"{BOSS_NAMES[index - 1]}    {label}  {(seconds / 4.0) as i32}      {hits / 4}    {deaths}     boss health left {(left * 25.0) as i32}%")
    0
