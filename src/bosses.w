// Boss bench: every ship flies the Field with the careful bot and meets
// the bosses at their minutes with whatever build it has made by then.
// Each encounter is three numbers: time to kill, hull lost, and the time
// spent unable to damage the boss outside an explicit mechanic — the
// metric that catches a boss you are alive against and merely waiting on.
//
//   bosses [SEEDS] [SHIP] [BOSS]    a boss index forces it into its pool's slot
//                                   (mid for 1, 3, 5; late for 2, 4, 5)
use game
use tuning
use loadout
use ships
use pilots
use account
use save
use std.process.{args}
use std.string.parse

fn main:
    let argv = args()
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
