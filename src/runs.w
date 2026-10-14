// Run tools, headless:
//
//   runs replay FILE_OR_DIR...   re-simulate recordings, check each lands where it ended
//   runs calibrate [DIR]         your recorded runs beside the careful bot on the same seeds
//   runs profile [SEEDS] [RANKS] every ship, stationary and careful, across a whole run, at a rank count
//   runs account [DIR]           score every recorded run from its save, print the cadence
//   runs exposure [DIR]          runs from each weapon's unlock to its first pick
//   runs account-sim [RUNS]      a fresh account played by the careful bot, buying ranks between runs
//
// DIR defaults to the save directory's runs/ folder (WIPE_SAVE_DIR honored).
use std.fs
use std.process.{args, env}
use std.string.parse
use game
use tuning
use loadout
use ships
use save
use pilots
use record
use account
use cadence

fn recordings(paths: &List[str]) -> List[str]:
    var out = List.new()
    for p in paths:
        if p.ends_with(".rec"):
            out.push(p.clone())
            continue
        for line in list_files_text(p).split("\n"):
            if line.ends_with(".rec"): out.push(line.clone())
    out

fn stamp(seconds: f64) -> str:
    let s = seconds as i32
    let r = s % 60
    if r < 10: f"{s / 60}:0{r}" else: f"{s / 60}:{r}"

fn first_hit(s: Stats) -> str: if s.first_hit < 0.0: "-" else: stamp(s.first_hit)

fn cmd_replay(paths: List[str]) -> i32:
    var bad = 0
    var total = 0
    for path in recordings(&paths):
        total += 1
        let text = match read_file(path):
            Ok(t) => t
            Err(e) => {
                print(f"UNREADABLE {path}: {e.message()}")
                bad += 1
                continue
            }
        match replay(text):
            Ok(r) => {
                let tag = if r.matched: "match" else: "MISMATCH"
                if not r.matched: bad += 1
                print(f"{tag} {path}: {r.header.ship.name()} {r.header.stage.name()} {stamp(r.stats.seconds)} kills {r.stats.kills} level {r.stats.level} hits {r.stats.hits} first hit {first_hit(r.stats)}")
                if not r.matched: print(f"    recorded end {r.expected}, replayed end {r.actual}")
            }
            Err(message) => {
                print(f"BROKEN {path}: {message}")
                bad += 1
            }
    print(f"{total - bad} of {total} recordings replay exactly")
    if bad > 0: 1 else: 0

fn cmd_calibrate(paths: List[str]) -> i32:
    print("run                               ship     you: time  hit1  hits<2m kills<1m   bot: time  hit1  hits<2m kills<1m")
    var n = 0
    var you_t = 0.0
    var bot_t = 0.0
    var you_k = 0
    var bot_k = 0
    var you_h = 0
    var bot_h = 0
    for path in recordings(&paths):
        let text = match read_file(path):
            Ok(t) => t
            Err(_) => continue
        let Ok(r) = replay(text) else continue
        // The bot flies the same seed, ship, account, and tuning.
        let limit_seconds = if r.stats.seconds > 1.0: r.stats.seconds else: 1200.0
        let (_, bot) = fly(start_game(&r.header), .Careful, limit_seconds)
        let short = if path.len() > 32: path.slice(path.len() - 32, path.len()) else: path.clone()
        print(f"{short}  {r.header.ship.name()}   {stamp(r.stats.seconds)}  {first_hit(r.stats)}  {r.stats.hits_2min}  {r.stats.kills_1min}     {stamp(bot.seconds)}  {first_hit(bot)}  {bot.hits_2min}  {bot.kills_1min}")
        n += 1
        you_t += r.stats.seconds
        bot_t += bot.seconds
        you_k += r.stats.kills_1min
        bot_k += bot.kills_1min
        you_h += r.stats.hits_2min
        bot_h += bot.hits_2min
    if n == 0:
        print("no recordings found")
        return 1
    print(f"mean over {n}: you {stamp(you_t / n as f64)}, hits in 2 min {you_h / n}, kills in 1 min {you_k / n}; bot {stamp(bot_t / n as f64)}, hits in 2 min {bot_h / n}, kills in 1 min {bot_k / n}")
    0

// The recordings of one account in run order (run-N-Ship.rec).
fn account_recordings(paths: &List[str]) -> List[str]:
    let found = recordings(paths)
    var numbers: List[i32] = List.new()
    var names: List[str] = List.new()
    for path in found:
        let name = path.slice(path.rfind("/") + 1, path.len())
        if not name.starts_with("run-"): continue
        let rest = name.slice(4, name.len())
        let dash = rest.find("-")
        if dash <= 0: continue
        numbers.push(parse(rest.slice(0, dash)))
        names.push(path.clone())
    for i in 1..numbers.len() as i32:
        var j = i
        while j > 0 and numbers[j - 1] > numbers[j]:
            let n: i32 = numbers[j]
            numbers[j] = numbers[j - 1]
            numbers[j - 1] = n
            let t: str = names[j].clone()
            names[j] = names[j - 1].clone()
            names[j - 1] = t
            j -= 1
    names

// Every recorded run scored from its own header: the save it launched from
// already holds the shop visit before it, so the window matches the app's.
type Scored { row: RunRow, before: Save, after: Save }

fn score_recordings(paths: &List[str]) -> List[Scored]:
    var out: List[Scored] = List.new()
    var logged = Save {}
    for path in account_recordings(paths):
        let text = match read_file(path):
            Ok(t) => t
            Err(_) => continue
        let Ok(r) = replay(text) else continue
        let (recorded, _) = record_run(r.header.save, &r.game)
        let after = stamp_unlocks(&r.header.save, recorded)
        let report = progress_score(&logged, &after)
        let number = out.len() as i32 + 1
        out.push(Scored { row: RunRow { number, seconds: r.stats.seconds, cleared: r.game.cleared and not r.header.endless, hurry: r.header.hurry, score: report.score, events: report.events.clone() }, before: logged, after })
        logged = after
    out

fn print_cadence(scored: &List[Scored]):
    var rows: List[RunRow] = List.new()
    for s in scored:
        var events = ""
        for e in &s.row.events: events = events ++ e ++ ", "
        print(f"run {s.row.number}  {stamp(s.row.seconds)}  score {s.row.score}  {events.trim()}")
        rows.push(RunRow { number: s.row.number, seconds: s.row.seconds, cleared: s.row.cleared, hurry: s.row.hurry, score: s.row.score, events: s.row.events.clone() })
    for line in cadence_lines(&cadence(&rows)): print(line)

fn cmd_account(paths: List[str]) -> i32:
    let scored = score_recordings(&paths)
    if scored.len() == 0:
        print("no recordings found")
        return 1
    print_cadence(&scored)
    0

// Runs from a weapon's unlock to its first pick: a long gap means the
// player never meets the thing they earned.
fn print_exposure(scored: &List[Scored]):
    print("weapon     unlocked  first pick  gap")
    for i in 0..BASE_WEAPON_COUNT:
        let w = weapon_at(i)
        var unlocked = if met(weapon_condition(w), &Save {}): 0 else: -1
        var picked = -1
        for s in scored:
            if unlocked < 0 and met(weapon_condition(w), &s.after): unlocked = s.row.number
            if picked < 0 and s.after.taken_weapons[i]: picked = s.row.number
        let gap = if unlocked < 0: "-" else if picked < 0: "never" else: f"{picked - unlocked}"
        let unlock_text = if unlocked < 0: "never" else if unlocked == 0: "start" else: f"run {unlocked}"
        let pick_text = if picked < 0: "never" else: f"run {picked}"
        print(f"{w.name()}    {unlock_text}    {pick_text}    {gap}")

fn cmd_exposure(paths: List[str]) -> i32:
    let scored = score_recordings(&paths)
    if scored.len() == 0:
        print("no recordings found")
        return 1
    print_exposure(&scored)
    0

// A fresh account played by the careful bot: every run on the Claw in the
// Field, the cheapest affordable ranks bought after each. The control group
// for any change to the cadence.
fn cmd_account_sim(count: i32) -> i32:
    var save = Save {}
    var logged = Save {}
    var scored: List[Scored] = List.new()
    for n in 1..count + 1:
        var g = Game.new(Stage.Field.rules())
        g.rng = 777 +% (n as u32) *% 2654435761
        g.start(launch_for(.Claw, &save, false))
        let (flown, stats) = fly(g, .Careful, 1200.0)
        let (recorded, _) = record_run(save, &flown)
        let after = stamp_unlocks(&save, recorded)
        let report = progress_score(&logged, &after)
        scored.push(Scored { row: RunRow { number: n, seconds: stats.seconds, cleared: flown.cleared, score: report.score, events: report.events.clone() }, before: logged, after })
        logged = after
        save = after
        while let Some(next) = next_rank(&save):
            if save.credits < next.price: break
            save.credits -= next.price
            save.spent += next.price
            save.ranks[next.item.index()] += 1
    print_cadence(&scored)
    print_exposure(&scored)
    0

// Every ship across a run: when the careful bot survives to each mark,
// how fast it kills, its level at 5, 10 and 15 minutes (the XP curve the
// pressure tuning must hold), and when a stationary one dies. RANKS
// pre-buys that many of the cheapest shop ranks, the account's power.
fn profile_game(ship: Ship, seed: i32, ranks: i32) -> Game:
    var save = Save {}
    for i in 0..BASE_WEAPON_COUNT: save.weapon_unlocked_run[i] = 0
    for _ in 0..ranks:
        let Some(next) = next_rank(&save) else break
        save.ranks[next.item.index()] += 1
    // WIPE_TUNING holds tuning.txt lines, for trying a knob without a rebuild.
    let (rules, _, _) = apply_tuning(Stage.Field.rules(), env("WIPE_TUNING"))
    var g = Game.new(rules)
    var launch = launch_for(ship, &save, false)
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    for i in 0..8: launch.unlocked_passives[i] = true
    g.rng = 55555 +% (seed as u32) *% 2654435761
    g.start(launch)
    // WIPE_PASSIVE=Name:level presets one passive, for a real-run check of it.
    let preset = env("WIPE_PASSIVE")
    if preset.len() > 0:
        let parts = preset.split(":")
        for i in 0..PASSIVE_COUNT:
            if passive_at(i).name() == parts[0]:
                g.build.passives[0] = PassiveSlot { passive: passive_at(i), level: parse(parts[1]) }
                g.refresh_mods()
    g

// Fly to a limit, noting the level and kills as each mark passes.
fn fly_marks(start: Game, seconds: f64) -> (Stats, [i32; 3], [i32; 3]):
    var g = start
    var stats = Stats {}
    var levels = [0; 3]
    var kills = [0; 3]
    while g.phase != .Over and g.elapsed < seconds:
        g.clear_events()
        g.tick(controls(&g, .Careful), 1.0 / 120.0)
        stats.observe(&g)
        for m in 0..3:
            if levels[m] == 0 and g.elapsed >= (m + 1) as f64 * 300.0:
                levels[m] = g.level
                kills[m] = g.kills
        var guard = 0
        while g.phase == .Boost and guard < 20:
            guard += 1
            g.cache_reveal = 0.0
            g.choose(pick_card(&g))
    (stats, levels, kills)

fn cmd_profile(seeds: i32, ranks: i32, only: str) -> i32:
    print(f"ranks {ranks}")
    print(f"ship      stand  careful: >2m  >5m  >10m  >15m  >20m  kills/min  level@death   level@5/10/15   kills@5/10/15")
    for i in 0..SHIP_COUNT:
        let ship = ship_at(i)
        if only.len() > 0 and ship.name() != only: continue
        var stand = 0.0
        for seed in 0..seeds:
            let (_, s) = fly(profile_game(ship, seed, ranks), .Stationary, 120.0)
            stand += s.seconds
        var marks = [0, 0, 0, 0, 0]
        var kill_rate = 0.0
        var levels = 0
        var level_at = [0; 3]
        var kills_at = [0; 3]
        var reached = [0; 3]
        for seed in 0..seeds:
            let (s, lv, ks) = fly_marks(profile_game(ship, seed, ranks), 1200.0)
            if s.seconds >= 120.0: marks[0] += 1
            if s.seconds >= 300.0: marks[1] += 1
            if s.seconds >= 600.0: marks[2] += 1
            if s.seconds >= 900.0: marks[3] += 1
            if s.seconds >= 1199.0: marks[4] += 1
            kill_rate += s.kills as f64 * 60.0 / s.seconds
            levels += s.level
            for m in 0..3:
                if lv[m] > 0:
                    level_at[m] += lv[m]
                    kills_at[m] += ks[m]
                    reached[m] += 1
        var at = ""
        var kt = ""
        for m in 0..3:
            at = at ++ (if reached[m] > 0: f"{level_at[m] / reached[m]}" else: "-") ++ " "
            kt = kt ++ (if reached[m] > 0: f"{kills_at[m] / reached[m]}" else: "-") ++ " "
        print(f"{ship.name()}    {(stand / seeds as f64) as i32}s       {marks[0]}/{seeds}  {marks[1]}/{seeds}  {marks[2]}/{seeds}  {marks[3]}/{seeds}  {marks[4]}/{seeds}   {(kill_rate / seeds as f64) as i32}      {levels / seeds}   {at.trim()}   {kt.trim()}")
    0

fn main:
    let argv = args()
    if argv.len() < 2:
        print("usage: runs replay PATH... | runs calibrate [DIR] | runs profile [SEEDS] | runs account [DIR] | runs exposure [DIR] | runs account-sim [RUNS]")
        return 2
    let command = argv[1].clone()
    var rest = List.new()
    for i in 2..argv.len() as i32: rest.push(argv[i].clone())
    if rest.len() == 0 and command != "profile" and command != "account-sim": rest.push(f"{save_directory()}/runs")
    if command == "account": return cmd_account(rest)
    if command == "exposure": return cmd_exposure(rest)
    if command == "account-sim": return cmd_account_sim(if rest.len() > 0: parse(rest[0]) else: 20)
    if command == "replay": return cmd_replay(rest)
    if command == "calibrate": return cmd_calibrate(rest)
    if command == "profile": return cmd_profile(if rest.len() > 0: parse(rest[0]) else: 8, if rest.len() > 1: parse(rest[1]) else: 0, if rest.len() > 2: rest[2].clone() else: "")
    print(f"unknown command {command}")
    2
