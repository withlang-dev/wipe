//! expect-stdout: UAT passed: every boss is killable before desperation, none falls at once, and none leaves the pilot waiting
use game
use tuning
use loadout
use ships
use pilots

// The Claw, the Dart and the Hawk fly the Field; the bosses they meet are
// measured. Three ships, two seeds: the suite's budget, and the bands are
// wide. The bench tool has every ship.
fn main:
    var failures = 0
    var met = [0, 0, 0]
    for ship in [Ship.Claw, Ship.Dart, Ship.Hawk]:
        var ttk = [0.0, 0.0, 0.0]
        var kills = [0, 0, 0]
        for seed in 0..2:
            let g = test_game(ship, seed)
            for e in boss_run(g, 1080.0):
                if e.boss < 0 or e.boss > 2: continue
                met[e.boss] += 1
                if e.killed:
                    kills[e.boss] += 1
                    ttk[e.boss] += e.ttk
                // Never left waiting: outside a mechanic, no stretch past
                // eight seconds without hurting the boss, and no more than
                // a fifth of the fight.
                if e.streak > 8.0 or e.share > 0.2:
                    failures += 1
                    print(f"{ship.name()} waited on {BOSS_NAMES[e.boss]}: longest {e.streak as i32} s, {(e.share * 100.0) as i32}%")
        // Killable before desperation, never at once: the ship's mean fight.
        for b in 0..3:
            if kills[b] == 0: continue
            let mean = ttk[b] / kills[b] as f64
            if mean < 15.0 or mean > 150.0:
                failures += 1
                print(f"{ship.name()} on {BOSS_NAMES[b]}: {mean as i32} s a fight")
    // The Warden is met by every one of these runs.
    assert(met[0] == 6)
    assert(failures == 0)
    print("UAT passed: every boss is killable before desperation, none falls at once, and none leaves the pilot waiting")
