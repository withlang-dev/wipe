//! expect-stdout: UAT passed: live tuning, exact replay, footer check
use game
use tuning
use loadout
use ships
use save
use account
use pilots
use record

fn main:
    // Tuning: dump, parse, override, report unknown names.
    let (tuned, count, unknown) = apply_tuning(Rules {}, "# note\nenemy_speed 150.5\nmax_health 7\nnope 3\n")
    assert(tuned.enemy_speed == 150.5 and tuned.max_health == 7 and count == 2 and unknown == "nope")
    let (back, _, none) = apply_tuning(Rules { enemy_speed: 1.0 }, rules_dump(Rules {}))
    assert(back.enemy_speed == 110.0 and none.len() == 0)
    // Record a run the way the app does: quantized controls, cards, a
    // reroll, a tuning change mid-run.
    let save = Save {}
    let h = Header { seed: 424242, ship: .Claw, stage: .Field, save, tuning: "enemy_speed 120\n" }
    var g = start_game(&h)
    var rec = Recorder {}
    rec.begin(h.seed, h.ship, h.stage, false, h.view_w, h.view_h, save.serialize(), h.tuning)
    var rerolled = false
    while g.phase != .Over and g.elapsed < 90.0:
        let c = quantize(careful(&g))
        g.clear_events()
        rec.tick(c, true)
        g.tick(c, 1.0 / 120.0)
        if g.phase == .Boost:
            if not rerolled and g.rerolls > 0:
                rec.event("r")
                g.reroll()
                rerolled = true
            let pick = pick_card(&g)
            rec.event(f"c {pick}")
            g.choose(pick)
        if g.elapsed > 45.0 and g.elapsed < 45.01:
            let text = "enemy_speed 130\n"
            rec.tuning(text)
            let (rules, _, _) = apply_tuning(h.stage.rules(), text)
            g.rules = rules
    let recording = rec.finish(&g)
    let played = replay(recording).unwrap()
    assert(played.matched)
    assert(played.game.kills == g.kills and played.game.elapsed == g.elapsed and played.game.rng == g.rng)
    // A tampered footer is caught.
    let bad = recording.replace("end ", "end 1")
    assert(not replay(bad).unwrap().matched)
    print("UAT passed: live tuning, exact replay, footer check")
