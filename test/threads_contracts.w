//! expect-stdout: UAT passed: three open loops, each a different goal
use save
use account
use ships

fn name(t: &Option[NextUnlock]) -> str:
    match t:
        Some(u) => u.name.clone()
        None => ""

fn main:
    // A fresh account: three threads, all different, near the furthest along.
    let t = next_unlocks(&Save {})
    assert(t.near.is_some() and t.new.is_some() and t.stretch.is_some())
    assert(name(&t.near) != name(&t.new) and name(&t.new) != name(&t.stretch) and name(&t.near) != name(&t.stretch))
    // Near is the goal closest to done: 4:30 survived is 90% of the Dart.
    var s = Save {}
    s.best_time[0] = 270.0
    let near = next_unlocks(&s)
    assert(name(&near.near) == "Dart ship")
    // New is a goal just begun, under a third of the way: 10 of Armor's 40 hits.
    s.hits = 10
    let begun = next_unlocks(&s)
    assert(name(&begun.new) == "Armor")
    // Stretch is a stage far off, never the near or new goal.
    assert(name(&begun.stretch).ends_with(" stage"))
    assert(name(&begun.stretch) != name(&begun.near) and name(&begun.stretch) != name(&begun.new))
    // A met goal leaves the threads.
    s.best_time[0] = 300.0
    let after = next_unlocks(&s)
    assert(name(&after.near) != "Dart ship" and name(&after.new) != "Dart ship" and name(&after.stretch) != "Dart ship")
    print("UAT passed: three open loops, each a different goal")
