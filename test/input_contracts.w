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
    print("UAT passed: native axis range, independent sticks, aim retention, mouse takeover, disconnect")
