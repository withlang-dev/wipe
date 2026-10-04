// Run recordings: the seed, the account, the tuning, and every input the
// simulation received, so any run can be replayed exactly. Inputs are
// quantized to 1/4096 before the simulation sees them, which makes the
// recorded integers the exact values simulated.
use game
use tuning
use loadout
use ships
use save
use account
use pilots

pub const RECORDING_VERSION: i32 = 1
const Q: f64 = 4096.0

fn q_int(v: f64) -> i64:
    if v >= 0.0: (v * Q + 0.5) as i64 else: -((-v * Q + 0.5) as i64)

pub fn quantize(c: Controls) -> Controls:
    Controls {
        motion: V2 { x: q_int(c.motion.x) as f64 / Q, y: q_int(c.motion.y) as f64 / Q },
        aim: V2 { x: q_int(c.aim.x) as f64 / Q, y: q_int(c.aim.y) as f64 / Q },
    }

fn block(tag: &str, text: &str) -> str:
    let lines = text.split("\n")
    var count = 0
    var body = ""
    for l in lines:
        if l.len() == 0: continue
        body = body ++ l ++ "\n"
        count += 1
    f"{tag} {count}\n" ++ body

// Collects a run. Consecutive identical ticks are stored as one line.
pub type Recorder { active: bool = false, text: str = "", last: str = "", repeat: i32 = 0 }

extend Recorder:
    pub fn begin(mut self: Self, seed: u32, ship: Ship, stage: Stage, endless: bool, view_w: i32, view_h: i32, save_text: &str, tuning_text: &str):
        self.active = true
        self.last = ""
        self.repeat = 0
        var head = f"wipe-recording {RECORDING_VERSION}\nseed {seed}\nship {ship.index()}\nstage {stage.index()}\nendless {if endless: 1 else: 0}\nview {view_w} {view_h}\n"
        head = head ++ block("save", save_text) ++ block("tuning", tuning_text) ++ "events\n"
        self.text = head

    fn flush(mut self: Self):
        if self.repeat == 0: return
        if self.repeat == 1: self.text = self.text ++ self.last ++ "\n"
        else: self.text = self.text ++ self.last ++ f" *{self.repeat}\n"
        self.repeat = 0
        self.last = ""

    // A simulation tick with quantized controls; full is a 1/120 s step.
    pub fn tick(mut self: Self, c: Controls, full: bool):
        if not self.active: return
        let line = f"t {q_int(c.motion.x)} {q_int(c.motion.y)} {q_int(c.aim.x)} {q_int(c.aim.y)} {if full: 1 else: 0}"
        if line == self.last: self.repeat += 1
        else:
            self.flush()
            self.last = line
            self.repeat = 1

    pub fn event(mut self: Self, line: str):
        if not self.active: return
        self.flush()
        self.text = self.text ++ line ++ "\n"

    pub fn tuning(mut self: Self, body: &str):
        if not self.active: return
        self.flush()
        self.text = self.text ++ block("u", body)

    // Close the recording with what the run came to, for verification.
    pub fn finish(mut self: Self, g: &Game) -> str:
        self.flush()
        self.active = false
        self.text ++ f"end {(g.elapsed * 1000.0) as i64} {g.kills} {g.level} {g.health}\n"

// ----- replay -------------------------------------------------------------------

pub type Header {
    seed: u32 = 0, ship: Ship = .Claw, stage: Stage = .Field, endless: bool = false,
    // The view the run was played in; a recording from before views varied is 1280x800.
    view_w: i32 = WIDTH, view_h: i32 = HEIGHT,
    save: Save = Save {}, tuning: str = "",
}

pub type Replayed {
    header: Header,
    game: Game,
    stats: Stats,
    matched: bool = false,
    expected: str = "",
    actual: str = "",
}

fn read_int(s: &str) -> i64:
    let v = read_number(s)
    if v >= 0.0: (v + 0.5) as i64 else: -((-v + 0.5) as i64)

// The game a recording starts from, exactly as the app builds it.
pub fn start_game(h: &Header) -> Game:
    let (rules, _, _) = apply_tuning(h.stage.rules(), h.tuning)
    var g = Game.new(rules)
    g.screen_w = h.view_w as f64
    g.screen_h = h.view_h as f64
    g.rng = h.seed
    g.start(launch_for(h.ship, &h.save, h.endless))
    g

fn take_block(lines: &Vec[str], at: i32) -> (str, i32):
    let parts = lines[at].split(" ")
    let count = read_int(parts[1].clone()) as i32
    var text = ""
    for k in 0..count: text = text ++ lines[at + 1 + k] ++ "\n"
    (text, at + 1 + count)

pub fn read_header(text: &str) -> Result[(Header, i32), str]:
    let lines = text.split("\n")
    if lines.len() < 6 or not lines[0].starts_with("wipe-recording"): return Err("not a WIPE recording")
    var h = Header {}
    var i = 1
    while i < lines.len() as i32:
        let line = lines[i].clone()
        if line == "events": return Ok((h, i + 1))
        let parts = line.split(" ")
        let key = parts[0].clone()
        if key == "seed": h.seed = read_int(parts[1].clone()) as u32
        else if key == "ship": h.ship = ship_at(read_int(parts[1].clone()) as i32)
        else if key == "stage": h.stage = stage_at(read_int(parts[1].clone()) as i32)
        else if key == "endless": h.endless = parts[1] == "1"
        else if key == "view" and parts.len() >= 3:
            h.view_w = read_int(parts[1].clone()) as i32
            h.view_h = read_int(parts[2].clone()) as i32
        else if key == "save":
            let (body, next) = take_block(&lines, i)
            match Save.parse_text(body):
                Ok(s) => h.save = s
                Err(_) => return Err("unreadable save block")
            i = next
            continue
        else if key == "tuning":
            let (body, next) = take_block(&lines, i)
            h.tuning = body
            i = next
            continue
        i += 1
    Err("no events")

// Re-simulate a recording and check it lands where the recording ended.
pub fn replay(text: &str) -> Result[Replayed, str]:
    let (h, first) = read_header(text)?
    var g = start_game(&h)
    var stats = Stats {}
    let lines = text.split("\n")
    var expected = ""
    var i = first
    while i < lines.len() as i32:
        let line = lines[i].clone()
        i += 1
        if line.len() == 0: continue
        let parts = line.split(" ")
        let op = parts[0].clone()
        if op == "t":
            let c = Controls {
                motion: V2 { x: read_int(parts[1].clone()) as f64 / Q, y: read_int(parts[2].clone()) as f64 / Q },
                aim: V2 { x: read_int(parts[3].clone()) as f64 / Q, y: read_int(parts[4].clone()) as f64 / Q },
            }
            let dt = if parts[5] == "1": 1.0 / 120.0 else: 0.0
            let times = if parts.len() > 6: read_int(parts[6].slice(1, parts[6].len())) as i32 else: 1
            for _ in 0..times:
                g.clear_events()
                g.tick(c, dt)
                stats.observe(&g)
        else if op == "c": g.choose(read_int(parts[1].clone()) as i32)
        else if op == "r": g.reroll()
        else if op == "s": g.skip()
        else if op == "b": g.banish(read_int(parts[1].clone()) as i32)
        else if op == "v": g.cache_reveal = 0.0
        else if op == "a": g.abandon()
        else if op == "x": g.stress(read_int(parts[1].clone()) as i32)
        else if op == "u":
            let count = read_int(parts[1].clone()) as i32
            var body = ""
            for k in 0..count: body = body ++ lines[i + k] ++ "\n"
            i += count
            let (rules, _, _) = apply_tuning(h.stage.rules(), body)
            g.rules = rules
        else if op == "end":
            expected = f"{parts[1]} {parts[2]} {parts[3]} {parts[4]}"
    let actual = f"{(g.elapsed * 1000.0) as i64} {g.kills} {g.level} {g.health}"
    Ok(Replayed { header: h, game: g, stats, matched: expected == actual, expected, actual })
