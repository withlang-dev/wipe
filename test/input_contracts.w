//! expect-stdout: UAT passed: native axis range, independent sticks, aim retention, mouse takeover, disconnect
use game
use gamepads
use input

fn near(actual: f64, expected: f64):
    assert(actual > expected - 0.001 and actual < expected + 0.001)

fn main:
    near(axis_unit(-32768), -1.0)
    near(axis_unit(32767), 1.0)
    near(axis_unit(0), 0.0)
    var input = Input {}
    let sticks = input.resolve(V2 {}, V2 {}, V2 {}, V2 { x: 1.0 }, PadFrame {
        id: 1, motion: V2 { x: 0.6 }, aim: V2 { y: -1.0 },
    })
    near(sticks.motion.x, 0.5)
    near(sticks.motion.y, 0.0)
    near(sticks.aim.x, 0.0)
    near(sticks.aim.y, -1.0)
    let centered = input.resolve(V2 {}, V2 {}, V2 {}, sticks.aim, PadFrame { id: 1, motion: V2 { x: 0.1, y: 0.1 } })
    near(length2(centered.motion), 0.0)
    near(centered.aim.y, -1.0)
    let disconnected = input.resolve(V2 { y: 1.0 }, V2 {}, V2 {}, centered.aim, PadFrame {})
    near(disconnected.motion.y, 1.0)
    near(disconnected.aim.y, -1.0)
    let mouse = input.resolve(V2 {}, V2 { x: 100.0 }, V2 {}, disconnected.aim, PadFrame {})
    near(mouse.aim.x, 100.0)
    near(mouse.aim.y, 0.0)
    let combined = input.resolve(V2 { x: 1.0 }, V2 { x: 120.0 }, V2 {}, mouse.aim, PadFrame {
        id: 2, motion: V2 { y: 1.0 }, aim: V2 { y: 1.0 },
    })
    near(length2(movement(combined.motion)), 1.0)
    near(combined.aim.x, 0.0)
    near(combined.aim.y, 1.0)
    // A d-pad press echoed as an arrow key a few frames later counts once;
    // two real presses on one device both count.
    let (after_pad, first) = one_press([-100, -100], false, true, 10)
    assert(first)
    let (after_echo, echo) = one_press(after_pad, true, false, 13)
    assert(not echo)
    let (_, later) = one_press(after_echo, false, true, 30)
    assert(later)
    let (twice_marks, one) = one_press([-100, -100], false, true, 40)
    let (_, two) = one_press(twice_marks, false, true, 42)
    assert(one and two)
    print("UAT passed: native axis range, independent sticks, aim retention, mouse takeover, disconnect")
