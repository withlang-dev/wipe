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
        // The bench piles the swarm onto the ship; a Lob lands past it by
        // design, so its reach is pinned in weapon_contracts.w instead.
        if w.family() == .Lobbed: continue
        let merged = w.is_merged()
        // Two seeds of forty-five seconds each: forty-six weapons must fit the
        // suite's two minutes, and the bands are wide.
        let kills = if merged: weapon_kills(w, 5, 14.0, 45.0, 260, 2) else: weapon_kills(w, 5, 8.0, 45.0, 160, 2)
        // Re-pinned for enemies that toughen from minute two (pressure, 2026-10-13).
        // A Satellite is an interceptor and a Turret stands where the circling
        // bench leaves it, so their floors are lower; the Sweep, the
        // Shockwave and the spun Tether touch everything around the ship,
        // so their ceilings are a little higher.
        let family = w.family()
        var low = if merged: 1000 else: 550
        var high = if merged: 3600 else: 1500
        if family == .Satellite: low = if merged: 800 else: 400
        if family == .Turret: low = if merged: 650 else: 450
        if family == .Sweep or family == .Shock or family == .Tether: high = if merged: 3600 else: 1700
        if kills < low or kills > high:
            failures += 1
            print(f"{w.name()} at V kills {kills} a minute, outside {low} to {high}")
        // The campaign's back half: a base weapon at V, unmerged, against the
        // minute-fourteen swarm. Bolts are single-target and fall behind the
        // hull curve; contact weapons scale with the crowd. The band holds
        // the two within four times of each other.
        if not merged:
            let late = weapon_kills(w, 5, 14.0, 45.0, 260, 2)
            let late_high = if family == .Sweep or family == .Shock or family == .Tether: 2200 else: 1600
            // The floor is coarse: this bench underrates an aimed weapon that a
            // pilot steers; the ship profiles in targets.w are the real contract.
            if late < 250 or late > late_high:
                failures += 1
                print(f"{w.name()} at V kills {late} a minute at fourteen, outside 250 to {late_high}")
    assert(failures == 0)
    print("UAT passed: weapon and merge kill-rate bands")
