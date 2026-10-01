//! expect-stdout: UAT passed: palette, deadzones, telemetry
use presentation
use input
use game
use metrics
use loadout
fn main:
    verify_colors()
    assert(text_size(10) == 20 and text_size(16) == 20 and text_size(20) == 20 and text_size(32) == 32)
    // A five-pixel lowercase body at 2x remains nine pixels at 720p.
    assert(5.0 * (MIN_TEXT_SIZE as f64 / 10.0) * fit(1280, 720, 1422, 800).scale >= 9.0)
    // The window at the scene's size draws it 1:1; fullscreen letterboxes.
    let own = fit(WIDTH, HEIGHT)
    assert(own.x == 0.0 and own.y == 0.0 and own.scale == 1.0)
    let hd = fit(1920, 1080)
    assert(hd.scale == 1.35 and hd.x == 96.0 and hd.y == 0.0)
    let tall = fit(1280, 1024)
    assert(tall.scale == 1.0 and tall.x == 0.0 and tall.y == 112.0)
    let minimized = fit(0, 0)
    assert(minimized.scale == 1.0)
    // The view takes the screen's aspect ratio, never cropping 1280x800, and
    // then fills that screen at one scale with nothing left over.
    let (deck_w, deck_h) = view_size(1280, 800)
    assert(deck_w == 1280 and deck_h == 800)
    let (hd_w, hd_h) = view_size(1920, 1080)
    assert(hd_w == 1422 and hd_h == 800)
    let (old_w, old_h) = view_size(1024, 768)
    assert(old_w == 1280 and old_h == 960)
    let (ultra_w, ultra_h) = view_size(3440, 1440)
    assert(ultra_w == 1911 and ultra_h == 800)
    let filled = fit(1920, 1080, hd_w, hd_h)
    assert(filled.x < 1.0 and filled.y < 1.0 and filled.scale > 1.349 and filled.scale < 1.351)
    let (none_w, none_h) = view_size(0, 0)
    assert(none_w == WIDTH and none_h == HEIGHT)
    assert(length2(stick(0.1, 0.1)) == 0.0)
    assert(length2(stick(1.0, 1.0)) < 1.001)
    assert(stick(0.6, 0.0).x > 0.49 and stick(0.6, 0.0).x < 0.51)
    var metric = Metric {}
    for _ in 0..95: metric.add(2.0)
    for _ in 0..5: metric.add(8.0)
    assert(metric.percentile(95) == 2.25)
    assert(metric.percentile(99) == 8.25)
    print("UAT passed: palette, deadzones, telemetry")
