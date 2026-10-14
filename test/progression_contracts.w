//! expect-stdout: UAT passed: progression score, events, cadence
use save
use account
use cadence
use loadout

fn has(events: &List[str], token: &str) -> bool:
    for e in events:
        if e == token: return true
    false

fn main:
    // Nothing changed scores nothing.
    let fresh = Save {}
    let same = progress_score(&fresh, &fresh)
    assert(same.score == 0 and same.events.len() == 0)
    // Surviving 5:00 unlocks the Dart, the Lance and the Mines (3 each) and
    // advances five survival goals a fifth or more (the Pillars, the Tether,
    // the Lob, the Sweep, Duration): 1 each.
    var dart = Save {}
    dart.best_time[0] = 300.0
    let unlocked = progress_score(&fresh, &dart)
    assert(unlocked.score == 14 and has(&unlocked.events, "ship:Dart") and has(&unlocked.events, "weapon:Lance"))
    assert(has(&unlocked.events, "weapon:Mines") and has(&unlocked.events, "goal:Pillars stage") and has(&unlocked.events, "goal:Tether"))
    // A rank bought is 2; the cheapest rank newly affordable is 2.
    var bought = Save {}
    bought.ranks[6] = 1
    let rank = progress_score(&fresh, &bought)
    assert(rank.score == 2 and has(&rank.events, "rank:Hull 1"))
    var rich = Save {}
    rich.credits = 300
    let afford = progress_score(&fresh, &rich)
    assert(afford.score == 2 and has(&afford.events, "afford:Magnet 1"))
    // A goal a fifth closer is 1 (Armor wants 100 hits taken), unmet only.
    var hits = Save {}
    hits.hits = 25
    let goal = progress_score(&fresh, &hits)
    assert(goal.score == 1 and has(&goal.events, "goal:Armor"))
    hits.hits = 100
    let done = progress_score(&fresh, &hits)
    assert(done.score == 3 and has(&done.events, "passive:Armor") and not has(&done.events, "goal:Armor"))
    // A merged weapon taken for the first time is a recipe discovered: 3.
    var merged = Save {}
    merged.taken_weapons[Weapon.Railgun.index()] = true
    let merge = progress_score(&fresh, &merged)
    assert(merge.score == 3 and has(&merge.events, "merge:Railgun"))
    // The cadence: streaks of zero runs, events per hour, time to first.
    var rows: List[RunRow] = List.new()
    rows.push(RunRow { number: 1, seconds: 300.0, score: 3, events: ["ship:Dart"] })
    rows.push(RunRow { number: 2, seconds: 300.0 })
    rows.push(RunRow { number: 3, seconds: 600.0 })
    rows.push(RunRow { number: 4, seconds: 600.0, score: 6, events: ["weapon:Lance", "merge:Railgun"] })
    rows.push(RunRow { number: 5, seconds: 1200.0, cleared: true, score: 3, events: ["stage:Corridor"] })
    let c = cadence(&rows)
    assert(c.runs == 5 and c.zero_runs == 2 and c.longest_zero_streak == 2)
    assert(c.events == 4 and c.events_per_hour as i32 == 4)
    assert(c.first_ship == (1, 5) and c.first_weapon == (4, 30) and c.first_merge == (4, 30))
    assert(c.first_stage == (5, 50) and c.first_clear == (5, 50) and c.first_hurry_clear == (0, 0))
    // A log row, with and without the score columns.
    let old = parse_row("7\tClaw\tField\t0\t412\t9\t500\t6\tDart\t0\t90\tCannon:3\tHull:1\tL2:x\trun-7-Claw.rec").unwrap()
    assert(old.number == 7 and old.seconds == 412.0 and old.score == 0 and old.events.len() == 0)
    let new = parse_row("8\tClaw\tField\t0\t1200\t30\t900\t2\tcleared\t1\t400\tCannon:5\tHull:2\tL2:x\trun-8-Claw.rec\t5\tship:Hull,goal:Prism ship").unwrap()
    assert(new.cleared and new.score == 5 and has(&new.events, "ship:Hull") and has(&new.events, "goal:Prism ship"))
    assert(parse_row("garbage").is_none())
    print("UAT passed: progression score, events, cadence")
