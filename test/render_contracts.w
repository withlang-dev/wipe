//! expect-stdout: UAT passed: palette, deadzones, telemetry
use presentation
use input
use game
use metrics
use loadout
fn main:
    verify_colors()
    // The window at the scene's size draws it 1:1; fullscreen letterboxes.
    let own = fit(WIDTH, HEIGHT)
    assert(own.x == 0.0 and own.y == 0.0 and own.scale == 1.0)
    let hd = fit(1920, 1080)
    assert(hd.scale == 1.35 and hd.x == 96.0 and hd.y == 0.0)
    let tall = fit(1280, 1024)
    assert(tall.scale == 1.0 and tall.x == 0.0 and tall.y == 112.0)
    let minimized = fit(0, 0)
    assert(minimized.scale == 1.0)
    assert(length2(stick(0.1, 0.1)) == 0.0)
    assert(length2(stick(1.0, 1.0)) < 1.001)
    assert(stick(0.6, 0.0).x > 0.49 and stick(0.6, 0.0).x < 0.51)
    var metric = Metric {}
    for _ in 0..95: metric.add(2.0)
    for _ in 0..5: metric.add(8.0)
    assert(metric.percentile(95) == 2.25)
    assert(metric.percentile(99) == 8.25)
    print("UAT passed: palette, deadzones, telemetry")
