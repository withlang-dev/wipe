//! expect-stdout: UAT passed: controller awards, pause settings, and resume
use app
use game
use input
use std.fs
use std.process.set_env
use std.process.pid

fn main:
    let dir = f"/tmp/wipe-menu-test-{pid()}"
    let _ = set_env("WIPE_SAVE_DIR", dir)
    defer:
        let _ = remove_tree(dir)
    var wipe = App.open()
    wipe.screen = .Collection
    wipe.return_to = .Title
    // Left bumper from Ships wraps to all 29 awards; cursor navigation
    // crosses the page boundary and can reach the final milestone.
    wipe.step(MenuInput { lb: true }, Controls {}, 0.0)
    assert(wipe.tab == .Achievements)
    for _ in 0..28: wipe.step(MenuInput { right: true }, Controls {}, 0.0)
    assert(wipe.collection_cursor == 28)
    wipe.step(MenuInput { right: true }, Controls {}, 0.0)
    assert(wipe.collection_cursor == 0)
    wipe.step(MenuInput { left: true }, Controls {}, 0.0)
    assert(wipe.collection_cursor == 28)
    wipe.step(MenuInput { rb: true }, Controls {}, 0.0)
    assert(wipe.tab == .Ships and wipe.collection_cursor == 0)
    wipe.step(MenuInput { back: true }, Controls {}, 0.0)
    assert(wipe.screen == .Title)
    // Both pacing controls are reachable using only menu directions and A.
    wipe.screen = .Pause
    for _ in 0..6: wipe.step(MenuInput { down: true }, Controls {}, 0.0)
    assert(wipe.pause_cursor == 6 and wipe.settings.vsync)
    wipe.step(MenuInput { confirm: true }, Controls {}, 0.0)
    assert(not wipe.settings.vsync)
    wipe.step(MenuInput { down: true }, Controls {}, 0.0)
    wipe.step(MenuInput { right: true }, Controls {}, 0.0)
    assert(wipe.settings.frame_limit == 30)
    wipe.step(MenuInput { left: true }, Controls {}, 0.0)
    assert(wipe.settings.frame_limit == 0)
    wipe.step(MenuInput { back: true }, Controls {}, 0.0)
    assert(wipe.screen == .Run)
    // Pausing before simulation still consumes the previous frame's sound
    // cues; staying paused cannot replay them on subsequent frames.
    wipe.game.shot_event = true
    wipe.game.merge_event = true
    wipe.ui_move = true
    wipe.ui_confirm = true
    wipe.ui_buy = true
    wipe.step(MenuInput { start: true }, Controls {}, 0.0)
    assert(wipe.screen == .Pause)
    assert(not wipe.game.shot_event and not wipe.game.merge_event)
    assert(not wipe.ui_move and not wipe.ui_confirm and not wipe.ui_buy)
    wipe.game.death_event = true
    wipe.step(MenuInput {}, Controls {}, 0.0)
    assert(not wipe.game.death_event)
    // Overlay frames bypass step altogether and call the public clear hook.
    wipe.game.boss_kill_event = true
    wipe.game.first_kill_event = true
    wipe.ui_confirm = true
    wipe.clear_frame_events()
    assert(not wipe.game.boss_kill_event and not wipe.game.first_kill_event and not wipe.ui_confirm)
    print("UAT passed: controller awards, pause settings, and resume")
