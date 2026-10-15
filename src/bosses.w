// Boss bench: every ship flies the Field with the careful bot and meets
// the bosses at their minutes with whatever build it has made by then.
// Each encounter is three numbers: time to kill, hull lost, and the time
// spent unable to damage the boss outside an explicit mechanic — the
// metric that catches a boss you are alive against and merely waiting on.
//
//   bosses [SEEDS] [SHIP] [BOSS]    a boss index forces it into its pool's slot
//                                   (mid for 1, 3, 5; late for 2, 4, 5)
//   bosses matrix [SEEDS]           every ship forced into every boss at the
//                                   boss's own slot: reached, killed, died,
//                                   time to kill, hull lost, per pair
//   bosses probe SHIP [BOSS]        one run, seed 0, a line a second through
//                                   each boss fight: where the ship is, what
//                                   it deals, what it carries
use game
use tuning
use loadout
use ships
use pilots
use account
use save
use std.process.{args}
use std.string.parse

// The instrument: a line a second through every boss fight of one run.
fn probe(ship: Ship, force: i32) -> i32:
    var g = Game.new()
    g.rng = 55555
    var save = Save {}
    for w in 0..BASE_WEAPON_COUNT: save.weapon_unlocked_run[w] = 0
    var launch = launch_for(ship, &save, false)
    for w in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[w] = true
    for p in 0..8: launch.unlocked_passives[p] = true
    g.start(launch)
    if force == 1 or force == 3 or force == 5: g.slot_boss[1] = force
    if force == 2 or force == 4 or force == 5: g.slot_boss[2] = force
    var last_hp = 0
    var second = 0.0
    var held = Controls {}
    while g.phase != .Over and g.elapsed < 1200.0:
        g.clear_events()
        held = human(&g, held)
        g.tick(held, 1.0 / 120.0)
        var guard = 0
        while g.phase == .Boost and guard < 20:
            guard += 1
            g.cache_reveal = 0.0
            g.choose(pick_card(&g))
        if not g.boss_alive:
            last_hp = 0
            continue
        second += 1.0 / 120.0
        if second < 1.0: continue
        second -= 1.0
        for i in 0..g.enemy_count:
            let e = g.enemies[i]
            if e.kind != .Boss or e.boss < 0: continue
            let d = sub(g.player, e.pos)
            let dist = sqrt(length2(d))
            let along = (d.x * e.facing.x + d.y * e.facing.y) / (dist + 0.001)
            var slots = ""
            for s in 0..SLOT_COUNT:
                if g.build.weapons[s].level > 0: slots = slots ++ f"{g.build.weapons[s].weapon.name()}:{g.build.weapons[s].level} "
            let dealt = if last_hp > 0: last_hp - e.hp else: 0
            print(f"{g.elapsed as i32}s {BOSS_NAMES[e.boss]} dist {dist as i32} along {(along * 100.0) as i32} hp {e.hp} dealt/s {dealt} state {e.state} desperate {e.age > g.rules.desperation} health {g.health} enemies {g.enemy_count}  {slots}")
            last_hp = e.hp
    0

// The grid: every ship against every boss, the boss forced into its slot.
fn matrix(seeds: i32) -> i32:
    print("ship,boss,reached,killed,died,ttk,hull_lost,streak,share")
    for i in 0..SHIP_COUNT:
        let ship = ship_at(i)
        for b in 0..BOSS_COUNT:
            var reached = 0
            var killed = 0
            var died = 0
            var ttk = 0.0
            var lost = 0
            var streak = 0.0
            var share = 0.0
            for seed in 0..seeds:
                var g = Game.new()
                g.rng = 55555 +% (seed as u32) *% 2654435761
                var save = Save {}
                for w in 0..BASE_WEAPON_COUNT: save.weapon_unlocked_run[w] = 0
                var launch = launch_for(ship, &save, false)
                for w in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[w] = true
                for p in 0..8: launch.unlocked_passives[p] = true
                g.start(launch)
                if b == 0: g.slot_boss[0] = 0
                else if b == 1 or b == 3 or b == 5: g.slot_boss[1] = b
                else: g.slot_boss[2] = b
                for e in boss_run(g, 1200.0):
                    if e.boss != b: continue
                    reached += 1
                    if e.killed: killed += 1
                    if e.died: died += 1
                    ttk += e.ttk
                    lost += e.hull_lost
                    if e.streak > streak: streak = e.streak
                    share += e.share
            let n = if reached > 0: reached else: 1
            print(f"{ship.name()},{BOSS_NAMES[b]},{reached},{killed},{died},{(ttk / n as f64) as i32},{lost / n},{(streak * 10.0) as i32 as f64 / 10.0},{(share / n as f64 * 100.0) as i32}")
    0

fn main:
    let argv = args()
    if argv.len() > 1 and argv[1] == "matrix": return matrix(if argv.len() > 2: parse(argv[2]) else: 2)
    if argv.len() > 2 and argv[1] == "probe":
        for i in 0..SHIP_COUNT:
            if ship_at(i).name() == argv[2]: return probe(ship_at(i), if argv.len() > 3: parse(argv[3]) else: -1)
        print(f"unknown ship {argv[2]}")
        return 1
    let seeds = if argv.len() > 1: parse(argv[1]) else: 4
    let only = if argv.len() > 2: argv[2].clone() else: ""
    let force = if argv.len() > 3: parse(argv[3]) else: -1
    print("ship     boss     reached  killed  died   ttk   hull lost  no-damage streak  share   (means over seeds that reached)")
    for i in 0..SHIP_COUNT:
        let ship = ship_at(i)
        if only.len() > 0 and ship.name() != only: continue
        var reached = [0; 6]
        var killed = [0; 6]
        var died = [0; 6]
        var ttk = [0.0; 6]
        var lost = [0; 6]
        var streak = [0.0; 6]
        var share = [0.0; 6]
        var hp = [0; 6]
        for seed in 0..seeds:
            var g = Game.new()
            g.rng = 55555 +% (seed as u32) *% 2654435761
            var save = Save {}
            for w in 0..BASE_WEAPON_COUNT: save.weapon_unlocked_run[w] = 0
            var launch = launch_for(ship, &save, false)
            for w in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[w] = true
            for p in 0..8: launch.unlocked_passives[p] = true
            g.start(launch)
            if force == 1 or force == 3 or force == 5: g.slot_boss[1] = force
            if force == 2 or force == 4 or force == 5: g.slot_boss[2] = force
            if force == 0: g.slot_boss[0] = 0
            for e in boss_run(g, 1200.0):
                eprint(f"  {ship.name()} seed {seed}: boss {e.boss} reached {e.reached} killed {e.killed} died {e.died} ttk {e.ttk as i32} hp {e.max_hp}")
                if e.boss < 0 or e.boss >= BOSS_COUNT: continue
                let slot = e.boss
                reached[slot] += 1
                if e.killed: killed[slot] += 1
                if e.died: died[slot] += 1
                ttk[slot] += e.ttk
                lost[slot] += e.hull_lost
                if e.streak > streak[slot]: streak[slot] = e.streak
                share[slot] += e.share
                hp[slot] += e.max_hp
        for b in 0..BOSS_COUNT:
            let n = reached[b]
            if n == 0 and b >= 3: continue
            if force >= 0 and b != force: continue
            if n == 0:
                print(f"{ship.name()}  {BOSS_NAMES[b]}  0/{seeds}")
                continue
            print(f"{ship.name()}  {BOSS_NAMES[b]}  {n}/{seeds}  {killed[b]}  {died[b]}  {(ttk[b] / n as f64) as i32}s  {lost[b] / n}  {(streak[b] * 10.0) as i32 as f64 / 10.0}s  {(share[b] / n as f64 * 100.0) as i32}%  hp {hp[b] / n}")
    0
