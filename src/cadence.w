// The reward cadence of an account, from its run log: the plan's metrics
// (progression-plan §3). Pure: the runs tool and the tests feed it rows.
use std.string.parse

// One finished run as the cadence sees it.
pub type RunRow {
    number: i32 = 0, seconds: f64 = 0.0, cleared: bool = false, hurry: bool = false,
    score: i32 = 0, events: List[str] = List.new(),
}

pub type Cadence {
    runs: i32 = 0, hours: f64 = 0.0,
    zero_runs: i32 = 0, longest_zero_streak: i32 = 0,
    events: i32 = 0, events_per_hour: f64 = 0.0,
    // Time to first, as (run, account minute); run 0 means never.
    first_weapon: (i32, i32) = (0, 0), first_ship: (i32, i32) = (0, 0),
    first_merge: (i32, i32) = (0, 0), first_stage: (i32, i32) = (0, 0),
    first_clear: (i32, i32) = (0, 0), first_hurry_clear: (i32, i32) = (0, 0),
}

fn has_kind(row: &RunRow, kind: &str) -> bool:
    for e in &row.events:
        if e.starts_with(kind): return true
    false

pub fn cadence(rows: &List[RunRow]) -> Cadence:
    var c = Cadence {}
    var streak = 0
    var seconds = 0.0
    for row in rows:
        c.runs += 1
        seconds += row.seconds
        let minute = (seconds / 60.0) as i32
        c.events += row.events.len() as i32
        if row.score == 0:
            c.zero_runs += 1
            streak += 1
            if streak > c.longest_zero_streak: c.longest_zero_streak = streak
        else: streak = 0
        if c.first_weapon.0 == 0 and has_kind(row, "weapon:"): c.first_weapon = (row.number, minute)
        if c.first_ship.0 == 0 and has_kind(row, "ship:"): c.first_ship = (row.number, minute)
        if c.first_merge.0 == 0 and has_kind(row, "merge:"): c.first_merge = (row.number, minute)
        if c.first_stage.0 == 0 and has_kind(row, "stage:"): c.first_stage = (row.number, minute)
        if c.first_clear.0 == 0 and row.cleared and not row.hurry: c.first_clear = (row.number, minute)
        if c.first_hurry_clear.0 == 0 and row.cleared and row.hurry: c.first_hurry_clear = (row.number, minute)
    c.hours = seconds / 3600.0
    c.events_per_hour = if c.hours > 0.0: c.events as f64 / c.hours else: 0.0
    c

fn first_text(f: (i32, i32)) -> str: if f.0 == 0: "never" else: f"run {f.0}, minute {f.1}"

pub fn cadence_lines(c: &Cadence) -> List[str]:
    var out: List[str] = List.new()
    out.push(f"runs {c.runs}, account hours {((c.hours * 10.0) as i32) as f64 / 10.0}")
    out.push(f"zero-progress runs {c.zero_runs}, longest zero-progress streak {c.longest_zero_streak}")
    out.push(f"progression events {c.events}, per hour {c.events_per_hour as i32}")
    out.push(f"first weapon unlock   {first_text(c.first_weapon)}")
    out.push(f"first ship unlock     {first_text(c.first_ship)}")
    out.push(f"first merge           {first_text(c.first_merge)}")
    out.push(f"first new stage       {first_text(c.first_stage)}")
    out.push(f"first clear           {first_text(c.first_clear)}")
    out.push(f"first Hurry clear     {first_text(c.first_hurry_clear)}")
    out

// A run-log row (runs.tsv, with or without the score columns) as a RunRow.
pub fn parse_row(line: &str) -> Option[RunRow]:
    let f = line.split("\t")
    if f.len() < 15: return None
    var row = RunRow { number: parse(f[0]), seconds: parse(f[4]) as f64, cleared: f[9] == "1", hurry: f[3] == "2" }
    if f.len() >= 17:
        row.score = parse(f[15])
        for e in f[16].split(","):
            if e.len() > 0: row.events.push(e.clone())
    Some(row)
