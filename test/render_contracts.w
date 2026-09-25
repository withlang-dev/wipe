//! expect-stdout: UAT passed: palette, deadzones, telemetry
use presentation
use input
use game
use metrics
fn main:
    verify_colors()
    assert(length2(stick(0.1, 0.1)) == 0.0)
    assert(length2(stick(1.0, 1.0)) < 1.001)
    assert(stick(0.6, 0.0).x > 0.49 and stick(0.6, 0.0).x < 0.51)
    var metric = Metric {}
    for _ in 0..95: metric.add(2.0)
    for _ in 0..5: metric.add(8.0)
    assert(metric.percentile(95) == 2.25)
    assert(metric.percentile(99) == 8.25)
    print("UAT passed: palette, deadzones, telemetry")
