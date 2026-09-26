// Run tools, headless:
//
//   runs replay FILE_OR_DIR...   re-simulate recordings, check each lands where it ended
//   runs calibrate [DIR]         your recorded runs beside the careful bot on the same seeds
//   runs profile [SEEDS]         every ship, stationary and careful, across a whole run
//
// DIR defaults to the save directory's runs/ folder (WIPE_SAVE_DIR honored).
use std.fs
use std.process.args
use std.string.parse
use game
use tuning
use loadout
use ships
use save
use pilots
use record

fn recordings(paths: &Vec[str]) -> Vec[str]:
    var out: Vec[str] = Vec.new()
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

fn cmd_replay(paths: Vec[str]) -> i32:
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

fn cmd_calibrate(paths: Vec[str]) -> i32:
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

// Every ship across a run: when the careful bot survives to each mark,
// how fast it kills, and when a stationary one dies.
fn cmd_profile(seeds: i32) -> i32:
    print(f"ship      stand  careful: >2m  >5m  >10m  >15m  >20m  kills/min  level@death")
    for i in 0..SHIP_COUNT:
        let ship = ship_at(i)
        var stand = 0.0
        for seed in 0..seeds:
            let (_, s) = fly(test_game(ship, seed), .Stationary, 120.0)
            stand += s.seconds
        var marks = [0, 0, 0, 0, 0]
        var kill_rate = 0.0
        var levels = 0
        for seed in 0..seeds:
            let (_, s) = fly(test_game(ship, seed), .Careful, 1200.0)
            if s.seconds >= 120.0: marks[0] += 1
            if s.seconds >= 300.0: marks[1] += 1
            if s.seconds >= 600.0: marks[2] += 1
            if s.seconds >= 900.0: marks[3] += 1
            if s.seconds >= 1199.0: marks[4] += 1
            kill_rate += s.kills as f64 * 60.0 / s.seconds
            levels += s.level
        print(f"{ship.name()}    {(stand / seeds as f64) as i32}s       {marks[0]}/{seeds}  {marks[1]}/{seeds}  {marks[2]}/{seeds}  {marks[3]}/{seeds}  {marks[4]}/{seeds}   {(kill_rate / seeds as f64) as i32}      {levels / seeds}")
    0

fn main:
    let argv = args()
    if argv.len() < 2:
        print("usage: runs replay PATH... | runs calibrate [DIR] | runs profile [SEEDS]")
        return 2
    let command = argv[1].clone()
    var rest: Vec[str] = Vec.new()
    for i in 2..argv.len() as i32: rest.push(argv[i].clone())
    if rest.len() == 0 and command != "profile": rest.push(f"{save_directory()}/runs")
    if command == "replay": return cmd_replay(rest)
    if command == "calibrate": return cmd_calibrate(rest)
    if command == "profile": return cmd_profile(if rest.len() > 0: parse(rest[0]) else: 8)
    print(f"unknown command {command}")
    2
