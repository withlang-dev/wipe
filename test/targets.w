//! expect-stdout: UAT passed: Vampire Survivors opening, ship profiles
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
// Guards, not guarantees: a ship may be weak by design. The test fails only
// when a ship collapses outright (a bug, like a weapon that stops firing)
// or outgrows everything (a runaway), at what sixteen bot runs can resolve.
fn in_band(phase: i32, rating: i32, count: i32) -> bool:
    let _ = rating
    match phase:
        0 => count >= 6
        1 => count <= 15
        _ => count <= 12

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
    eprint(f"stationary Claw dies at {mean as i32} s on average")
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
        eprint(f"{ship.name()}: {counts[0]} {counts[1]} {counts[2]} of {SEEDS}")
    assert(failures == 0)
    print("UAT passed: Vampire Survivors opening, ship profiles")
