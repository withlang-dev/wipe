//! expect-stdout: UAT passed: native axis range, independent sticks, aim retention, mouse takeover, disconnect, menu sampling
use game
use gamepads
use controls
use input

fn near(actual: f64, expected: f64):
    assert(actual > expected - 0.001 and actual < expected + 0.001)

fn main:
    near(axis_unit(-32768), -1.0)
    near(axis_unit(32767), 1.0)
    near(axis_unit(0), 0.0)
    // Prompt selection responds to both menu buttons and either stick,
    // ignores drift/disconnection, and changes back for a real mouse/key use.
    assert(active_device(.Keyboard, false, false, ActionFrame { id: 1, pressed: ACT_PAUSE }, 0.2) == .Pad)
    assert(active_device(.Keyboard, false, false, ActionFrame { id: 1, motion: V2 { x: 0.7 } }, 0.2) == .Pad)
    assert(active_device(.Keyboard, false, false, ActionFrame { id: 1, aim: V2 { y: -0.8 } }, 0.2) == .Pad)
    assert(active_device(.Keyboard, false, false, ActionFrame { id: 1, motion: V2 { x: 0.1 } }, 0.2) == .Keyboard)
    assert(active_device(.Pad, false, false, ActionFrame {}, 0.2) == .Pad)
    assert(active_device(.Pad, false, true, ActionFrame {}, 0.2) == .Keyboard)
    assert(active_device(.Pad, true, false, ActionFrame {}, 0.2) == .Keyboard)
    assert(active_device(.Keyboard, true, true, ActionFrame { id: 1, pressed: ACT_CONFIRM }, 0.2) == .Pad)
    assert(prompt(.Pad, .Pause) == "MENU")
    assert(prompt(.Keyboard, .Confirm) == "SPACE")
    assert(prompt(.Pad, .Confirm) == "A")
    assert(prompt(.Pad, .Collection) == "Y" and prompt(.Keyboard, .Collection) == "C")
    assert(prompt(.Pad, .Reroll) == "X" and prompt(.Keyboard, .Reroll) == "R")
    assert(prompt(.Pad, .Next) == "RB" and prompt(.Keyboard, .Next) == "TAB")
    // A platform's bound names replace the table for the pad only, entry by
    // entry; a missing name or an incomplete table falls back.
    var bound = Prompts { device: .Pad }
    assert(bound.get(.Confirm) == "A")
    for _ in 0..ACTION_COUNT: bound.bound.push("")
    bound.bound[action_index(.Confirm)] = "Cross"
    assert(bound.get(.Confirm) == "Cross" and bound.get(.Back) == "B")
    bound.device = .Keyboard
    assert(bound.get(.Confirm) == "SPACE")
    var input = Input {}
    let sticks = input.resolve(V2 {}, V2 {}, V2 {}, V2 { x: 1.0 }, ActionFrame {
        id: 1, motion: V2 { x: 0.6 }, aim: V2 { y: -1.0 },
    })
    near(sticks.motion.x, 0.5)
    near(sticks.motion.y, 0.0)
    near(sticks.aim.x, 0.0)
    near(sticks.aim.y, -1.0)
    let centered = input.resolve(V2 {}, V2 {}, V2 {}, sticks.aim, ActionFrame { id: 1, motion: V2 { x: 0.1, y: 0.1 } })
    near(length2(centered.motion), 0.0)
    near(centered.aim.y, -1.0)
    let disconnected = input.resolve(V2 { y: 1.0 }, V2 {}, V2 {}, centered.aim, ActionFrame {})
    near(disconnected.motion.y, 1.0)
    near(disconnected.aim.y, -1.0)
    let mouse = input.resolve(V2 {}, V2 { x: 100.0 }, V2 {}, disconnected.aim, ActionFrame {})
    near(mouse.aim.x, 100.0)
    near(mouse.aim.y, 0.0)
    let combined = input.resolve(V2 { x: 1.0 }, V2 { x: 120.0 }, V2 {}, mouse.aim, ActionFrame {
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
    // Menus sample keys and actions without a window: a key and the pad
    // action both confirm, an unfocused window yields nothing, the pad
    // selects pad prompts, and a key press selects the keyboard's.
    var menu = MenuState {}
    let both = menu.sample(Keys { confirm: true, any_key: true }, ActionFrame { id: 1, pressed: ACT_BACK, held: ACT_BACK })
    assert(both.confirm and both.back and both.back_held and both.any)
    assert(menu.device == .Pad)
    let typed = menu.sample(Keys { x: true, any_key: true, digit: 3 }, ActionFrame {})
    assert(typed.shop and typed.digit == 3 and menu.device == .Keyboard)
    let away = menu.sample(Keys { focused: false, confirm: true }, ActionFrame { id: 1, pressed: ACT_CONFIRM })
    assert(not away.confirm and not away.any)
    // The left stick flicks once per deflection.
    let flick = menu.sample(Keys {}, ActionFrame { id: 1, motion: V2 { y: 1.0 } })
    let held_over = menu.sample(Keys {}, ActionFrame { id: 1, motion: V2 { y: 1.0 } })
    assert(flick.down and not held_over.down)
    var flight = Input {}
    let keyed = flight.sample(Keys { move_up: true, move_right: true }, V2 {}, V2 { x: 1.0 }, ActionFrame {})
    near(keyed.motion.x, 1.0)
    near(keyed.motion.y, -1.0)
    print("UAT passed: native axis range, independent sticks, aim retention, mouse takeover, disconnect, menu sampling")
