//! expect-stdout: UAT passed: no boss fight stalls, and none leaves the pilot waiting (ships 0 to 13)
use game
use tuning
use loadout
use ships
use pilots

// Every ship, one seed, the Field: every boss fight the bot reaches ends
// within eight minutes, by a kill or a death — the stalemate floor's
// promise — and no fight leaves the pilot more than thirty seconds, or
// more than six tenths of its seconds, unable to hurt the boss outside an
// explicit mechanic: the roster's floor as the campaign found it, to
// tighten as the pilot improves. Two files, half the roster each, for
// the suite's clock; the bench tool has the numbers.
fn main:
    var failures = 0
    for i in 0..13:
        let ship = ship_at(i)
        for e in boss_run(test_game(ship, 0), 1200.0):
            if e.boss < 0: continue
            if not e.killed and not e.died and e.ttk >= 480.0:
                failures += 1
                print(f"{ship.name()} stalled on {BOSS_NAMES[e.boss]}: {e.ttk as i32} s, neither dead")
            if e.killed and e.ttk > 480.0:
                failures += 1
                print(f"{ship.name()} took {e.ttk as i32} s on {BOSS_NAMES[e.boss]}")
            if e.streak > 30.0 or e.share > 0.6:
                failures += 1
                print(f"{ship.name()} waited on {BOSS_NAMES[e.boss]}: longest {e.streak as i32} s, {(e.share * 100.0) as i32}%")
    assert(failures == 0)
    print("UAT passed: no boss fight stalls, and none leaves the pilot waiting (ships 0 to 13)")
