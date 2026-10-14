//! expect-stdout: UAT passed: platform-independent play and overlay input gate
use platform
use controls

fn main:
    var plain = NoPlatform {}
    assert(plain.controller(true).is_none() and plain.controller(false).is_none())
    assert(plain.prompts().len() == 0)
    assert(plain.notice() == "")
    assert(not plain.frame().blocks_input())
    let none = List.new()
    plain.sync_achievements(&none)
    plain.shutdown()
    plain.shutdown()
    // The opening and closing frames are blocked even if two callbacks
    // arrive in one pump; a close cannot leak a held resume button.
    assert(PlatformFrame { overlay_opened: true }.blocks_input())
    assert(PlatformFrame { overlay_active: true }.blocks_input())
    assert(PlatformFrame { overlay_closed: true }.blocks_input())
    assert(PlatformFrame { overlay_opened: true, overlay_closed: true }.blocks_input())
    print("UAT passed: platform-independent play and overlay input gate")
