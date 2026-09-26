//! expect-stdout: UAT passed: Vampire Survivors opening, ship profiles, weapon bands
// The balance targets of spec §9 (ship profiles) and §4 (the opening),
// measured with the careful and stationary bots over sixteen seeds. A
// change that moves a ship out of its intended shape fails the build.
use game
use tuning
use loadout
use ships
use pilots

const SEEDS: i32 = 16

// A phase's rating: 0 Weak, 1 Even, 2 Strong.
// Bands at the resolution sixteen bot runs can measure (about three runs
// either way): they catch a ship that collapses or outgrows its role.
fn in_band(phase: i32, rating: i32, count: i32) -> bool:
    match phase:
        0 => match rating:
            2 => count >= 14
            1 => count >= 12
            _ => count >= 8
        1 => match rating:
            2 => count >= 9
            1 => count >= 5 and count <= 13
            _ => count >= 3 and count <= 12
        _ => match rating:
            2 => count >= 3
            1 => count >= 1 and count <= 9
            _ => count <= 6

// Opening, middle, late for each ship, as the spec's profile table.
fn profile(ship: Ship) -> [i32; 3]:
    match ship:
        .Claw => [1, 1, 1]
        .Dart => [2, 1, 0]
        .Hull => [0, 1, 2]
        .Prism => [0, 2, 1]
        .Halo => [0, 1, 1]
        .Needle => [0, 1, 2]
        .Sapper => [2, 2, 0]
        .Phase => [1, 2, 0]
        .Null => [2, 1, 0]

fn main:
    // A standing-still Claw dies within the first minute.
    var stand = 0.0
    for seed in 0..SEEDS:
        let (_, s) = fly(test_game(.Claw, seed), .Stationary, 120.0)
        stand += s.seconds
    let mean = stand / SEEDS as f64
    print(f"stationary Claw dies at {mean as i32} s on average")
    // A little easier than Vampire Survivors' 10 to 13, from playtesting.
    assert(mean >= 15.0 and mean <= 45.0)
    var failures = 0
    let names = ["opening", "middle", "late"]
    let ratings = ["Weak", "Even", "Strong"]
    for i in 0..SHIP_COUNT:
        let ship = ship_at(i)
        var counts = [0, 0, 0]
        for seed in 0..SEEDS:
            let (_, s) = fly(test_game(ship, seed), .Careful, 901.0)
            if s.seconds >= 120.0: counts[0] += 1
            if s.seconds >= 600.0: counts[1] += 1
            if s.seconds >= 900.0: counts[2] += 1
        let want = profile(ship)
        for phase in 0..3:
            if not in_band(phase, want[phase], counts[phase]):
                failures += 1
                print(f"{ship.name()} {names[phase]}: {counts[phase]}/{SEEDS} is outside {ratings[want[phase]]}")
        print(f"{ship.name()}: {counts[0]} {counts[1]} {counts[2]} of {SEEDS}")
    // Every base weapon and merge inside its band at level V.
    for i in 0..WEAPON_COUNT:
        let w = weapon_at(i)
        let merged = w.is_merged()
        let kills = if merged: weapon_kills(w, 5, 14.0, 60.0, 260) else: weapon_kills(w, 5, 8.0, 60.0, 160)
        let low = if merged: 1100 else: 600
        let high = if merged: 3600 else: 1500
        if kills < low or kills > high:
            failures += 1
            print(f"{w.name()} at V kills {kills} a minute, outside {low} to {high}")
    assert(failures == 0)
    print("UAT passed: Vampire Survivors opening, ship profiles, weapon bands")
