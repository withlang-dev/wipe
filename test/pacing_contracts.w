//! expect-stdout: UAT passed: refresh-independent fixed-step pacing
use app

fn main:
    // Four seconds at each supported cap and above the simulation's rate.
    for fps in [30, 40, 45, 60, 90, 120, 144, 240]:
        var remainder = 0.0
        var total = 0
        for _ in 0..(fps * 4):
            let (next, count) = simulation_steps(remainder, 1.0 / fps as f64)
            remainder = next
            total += count
        assert(total == 480)
        assert(remainder < 0.00000001)
    let (after_sleep, bounded) = simulation_steps(0.0, 100.0)
    assert(bounded == 12 and after_sleep < 0.00000001)
    let (_, negative) = simulation_steps(0.0, -1.0)
    assert(negative == 0)
    print("UAT passed: refresh-independent fixed-step pacing")
