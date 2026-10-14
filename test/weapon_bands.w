//! expect-stdout: UAT passed: weapon and merge kill-rate bands
// Every base weapon at level V and every merge inside its kill-rate band on
// the balance bench (spec §9).
use game
use loadout
use pilots

fn main:
    var failures = 0
    for i in 0..WEAPON_COUNT:
        let w = weapon_at(i)
        let merged = w.is_merged()
        let kills = if merged: weapon_kills(w, 5, 14.0, 60.0, 260) else: weapon_kills(w, 5, 8.0, 60.0, 160)
        // Re-pinned for enemies that toughen from minute two (pressure, 2026-10-13).
        let low = if merged: 1000 else: 550
        let high = if merged: 3600 else: 1500
        if kills < low or kills > high:
            failures += 1
            print(f"{w.name()} at V kills {kills} a minute, outside {low} to {high}")
    assert(failures == 0)
    print("UAT passed: weapon and merge kill-rate bands")
