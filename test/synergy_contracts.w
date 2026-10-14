//! expect-stdout: UAT passed: the pairs that must stay found, and the ones that must keep fighting
use game
use tuning
use loadout
use ships
use pilots

// A pair on the bench against the shared-swarm expectation: the stronger
// alone, plus about a third of the weaker. Above one the two do more
// together than apart; below, they get in each other's way.
fn together(a: Weapon, b: Weapon, minute: f64, density: i32) -> f64:
    let seeds = 3
    let ka = pair_kills(a, None, 5, minute, 45.0, density, seeds)
    let kb = pair_kills(b, None, 5, minute, 45.0, density, seeds)
    let kab = pair_kills(a, Some(b), 5, minute, 45.0, density, seeds)
    let hi = if ka > kb: ka else: kb
    let lo = if ka > kb: kb else: ka
    (kab as f64) / ((hi as f64) * 1.02 + (lo as f64) * 0.37)

fn main:
    var failures = 0
    // Found: pairs that must do more together, at the minute they matter.
    let found = [
        (Weapon.Arc, Weapon.GravityWell, 14.0, 260, 1.12),
        (Weapon.Shockwave, Weapon.GravityWell, 14.0, 260, 1.12),
        (Weapon.Sweep, Weapon.Nova, 14.0, 260, 1.04),
        (Weapon.Tether, Weapon.GravityWell, 8.0, 160, 1.15),
    ]
    for (a, b, minute, density, floor) in found:
        let r = together(a, b, minute, density)
        eprint(f"{a.name()} with {b.name()}: {(r * 100.0) as i32}")
        if r < floor:
            failures += 1
            print(f"{a.name()} with {b.name()}: {(r * 100.0) as i32} of {(floor * 100.0) as i32}")
    // Fighting: pairs that must keep getting in each other's way.
    let fighting = [
        (Weapon.Arc, Weapon.TeslaField, 14.0, 260, 0.94),
        (Weapon.Tether, Weapon.TeslaField, 8.0, 160, 0.82),
    ]
    for (a, b, minute, density, ceiling) in fighting:
        let r = together(a, b, minute, density)
        eprint(f"{a.name()} with {b.name()}: {(r * 100.0) as i32}")
        if r > ceiling:
            failures += 1
            print(f"{a.name()} with {b.name()}: {(r * 100.0) as i32} over {(ceiling * 100.0) as i32}")
    assert(failures == 0)
    print("UAT passed: the pairs that must stay found, and the ones that must keep fighting")
