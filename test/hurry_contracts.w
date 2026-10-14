//! expect-stdout: UAT passed: Hurry runs the timeline at twice the rate and replays exactly
use game
use tuning
use pilots
use account
use save
use ships

fn hurry_game(seed: i32) -> Game:
    var g = Game.new(Rules {})
    var launch = launch_for(.Claw, &Save {}, false, true)
    for i in 0..8: launch.unlocked_weapons[i] = true
    g.rng = 4242 +% (seed as u32) *% 2654435761
    g.start(launch)
    g

fn main:
    // The clock: 120 real steps are two timeline seconds in Hurry, one otherwise.
    var h = hurry_game(1)
    var plain = test_game(.Claw, 1)
    for _ in 0..120:
        h.tick(Controls {}, 1.0 / 120.0)
        plain.tick(Controls {}, 1.0 / 120.0)
    assert(h.elapsed > 1.99 and h.elapsed < 2.01)
    assert(plain.elapsed > 0.99 and plain.elapsed < 1.01)
    assert(h.timeline_rate() == 2.0 and plain.timeline_rate() == 1.0)
    // The simulation does not speed up: the same rules, invulnerability and
    // projectile speed, and the ship covers the same ground per real second.
    assert(h.rules.invulnerability == plain.rules.invulnerability and h.rules.bullet_speed == plain.rules.bullet_speed)
    var mover = hurry_game(2)
    var walker = test_game(.Claw, 2)
    let from_h: V2 = mover.player
    let from_w: V2 = walker.player
    for _ in 0..60:
        mover.tick(Controls { motion: V2 { x: 1.0 }, aim: V2 { x: 1.0 } }, 1.0 / 120.0)
        walker.tick(Controls { motion: V2 { x: 1.0 }, aim: V2 { x: 1.0 } }, 1.0 / 120.0)
    let moved_h = mover.player.x - from_h.x
    let moved_w = walker.player.x - from_w.x
    assert(moved_h > 0.0 and moved_h < moved_w + 0.001 and moved_h > moved_w - 0.001)
    // The waves are timeline: the first boss arrives by real 2:35 in Hurry.
    var rush = hurry_game(3)
    let (after, _) = fly(rush, .Careful, 155.0 * 2.0)
    assert(after.boss_index >= 1 or after.boss_alive)
    // Exact replay: the same seed and inputs land in the same place.
    let (a, sa) = fly(hurry_game(4), .Careful, 90.0)
    let (b, sb) = fly(hurry_game(4), .Careful, 90.0)
    assert(a.elapsed == b.elapsed and a.kills == b.kills and a.level == b.level and a.health == b.health)
    assert(sa.seconds == sb.seconds)
    // A Hurry clear is a clear and a Hurry clear; the save counts both.
    var cleared = hurry_game(5)
    cleared.cleared = true
    let (s, _) = record_run(Save {}, &cleared)
    assert(s.clears == 1 and s.hurry_clears == 1 and met(.HurryClear, &s))
    // Hurry opens with the first clear; the gates are levels within a run.
    assert(not hurry_unlocked(&Save {}) and hurry_unlocked(&s))
    var leveled = Save {}
    leveled.best_level = 12
    assert(stage_unlocked(.Corridor, &leveled) and stage_unlocked(.Maze, &leveled) and not stage_unlocked(.Shaft, &leveled))
    print("UAT passed: Hurry runs the timeline at twice the rate and replays exactly")
