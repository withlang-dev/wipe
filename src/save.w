use std.fs
use std.time
use std.string.parse
use std.sysinfo.os
use std.process.env
use loadout
use ships
use game

// The player never loses a save. One file of `key value` lines, written
// atomically with a backup on every change, read before the first frame.
pub const SAVE_VERSION: i32 = 1
pub const SHOP_ITEM_COUNT: i32 = 16

pub type Save {
    version: i32 = SAVE_VERSION,
    credits: i32 = 0,
    spent: i32 = 0,
    ranks: [i32; 16] = [0; 16],
    runs: i32 = 0, clears: i32 = 0, kills: i32 = 0, seconds: f64 = 0.0,
    cores: i32 = 0, elites: i32 = 0, bosses: i32 = 0, caches: i32 = 0,
    hits: i32 = 0, banked: i32 = 0, merges: i32 = 0,
    best_level: i32 = 0, best_combo: i32 = 0, best_merges_in_run: i32 = 0,
    best_hits_survived: i32 = 0, bounced_kills: i32 = 0,
    no_reboot_clear: bool = false, null_killed: bool = false,
    best_time: [f64; 9] = [0.0; 9],
    best_endless: [f64; 9] = [0.0; 9],
    cleared: [bool; 9] = [false; 9],
    ship_runs: [i32; 9] = [0; 9],
    // Longest a run held each base weapon, in seconds.
    held: [f64; 8] = [0.0; 8],
    taken_weapons: [bool; 20] = [false; 20],
    taken_passives: [bool; 14] = [false; 14],
    registry_kills: [i32; 8] = [0; 8],
    registry_first: [f64; 8] = [-1.0; 8],
    last_ship: i32 = 0,
    volume: f64 = 1.0,
    deadzone: f64 = 0.2,
}
impl Copy for Save

// A save that could be read only partly, or not at all, says so once.
pub enum LoadNotice { | Fresh | Loaded | Restored | SetAside | TooNew(version: i32) }
impl Copy for LoadNotice
impl Eq for LoadNotice

fn fmt_float(x: f64) -> str:
    // Three decimals, no locale, no exponent.
    let negative = x < 0.0
    let magnitude = if negative: -x else: x
    let whole = magnitude as i64
    let frac = ((magnitude - whole as f64) * 1000.0 + 0.5) as i64
    let frac_text = if frac < 10: f"00{frac}" else if frac < 100: f"0{frac}" else: f"{frac}"
    let sign = if negative: "-" else: ""
    f"{sign}{whole}.{frac_text}"

pub fn parse_float(s: &str) -> f64:
    // Digits, one optional point, one optional leading minus. Anything else
    // ends the number, as a hand-edited save deserves.
    var i: i64 = 0
    let n = s.len() as i64
    while i < n and s.byte_at(i) as i32 == 32: i += 1
    var negative = false
    if i < n and s.byte_at(i) as i32 == 45:
        negative = true
        i += 1
    var value = 0.0
    while i < n:
        let c = s.byte_at(i) as i32
        if c < 48 or c > 57: break
        value = value * 10.0 + (c - 48) as f64
        i += 1
    if i < n and s.byte_at(i) as i32 == 46:
        i += 1
        var place = 0.1
        while i < n:
            let c = s.byte_at(i) as i32
            if c < 48 or c > 57: break
            value += (c - 48) as f64 * place
            place *= 0.1
            i += 1
    if negative: -value else: value

fn parse_bool(s: &str) -> bool: s == "1" or s == "true"
fn fmt_bool(b: bool) -> str: if b: "1" else: "0"

extend Save:
    pub fn serialize(self: &Self) -> str:
        var out = f"version {self.version}\n"
        out = out ++ f"credits {self.credits}\nspent {self.spent}\n"
        for i in 0..SHOP_ITEM_COUNT: out = out ++ f"rank {i} {self.ranks[i]}\n"
        out = out ++ f"runs {self.runs}\nclears {self.clears}\nkills {self.kills}\nseconds {fmt_float(self.seconds)}\n"
        out = out ++ f"cores {self.cores}\nelites {self.elites}\nbosses {self.bosses}\ncaches {self.caches}\n"
        out = out ++ f"hits {self.hits}\nbanked {self.banked}\nmerges {self.merges}\n"
        out = out ++ f"best_level {self.best_level}\nbest_combo {self.best_combo}\nbest_merges_in_run {self.best_merges_in_run}\n"
        out = out ++ f"best_hits_survived {self.best_hits_survived}\nbounced_kills {self.bounced_kills}\n"
        out = out ++ f"no_reboot_clear {fmt_bool(self.no_reboot_clear)}\nnull_killed {fmt_bool(self.null_killed)}\n"
        for i in 0..SHIP_COUNT:
            out = out ++ f"best_time {i} {fmt_float(self.best_time[i])}\nbest_endless {i} {fmt_float(self.best_endless[i])}\n"
            out = out ++ f"cleared {i} {fmt_bool(self.cleared[i])}\nship_runs {i} {self.ship_runs[i]}\n"
        for i in 0..BASE_WEAPON_COUNT: out = out ++ f"held {i} {fmt_float(self.held[i])}\n"
        for i in 0..WEAPON_COUNT: out = out ++ f"taken_weapon {i} {fmt_bool(self.taken_weapons[i])}\n"
        for i in 0..PASSIVE_COUNT: out = out ++ f"taken_passive {i} {fmt_bool(self.taken_passives[i])}\n"
        for i in 0..KIND_COUNT: out = out ++ f"registry {i} {self.registry_kills[i]} {fmt_float(self.registry_first[i])}\n"
        out = out ++ f"last_ship {self.last_ship}\nvolume {fmt_float(self.volume)}\ndeadzone {fmt_float(self.deadzone)}\n"
        out

// Parse a save. Unknown keys are ignored so newer fields never break an
// older reader of the same version; a newer version is refused.
pub fn Save.parse_text(text: &str) -> Result[Save, LoadNotice]:
    var s = Save {}
    var saw_version = false
    for raw in text.split("\n"):
        let line = raw.trim()
        if line.len() == 0: continue
        let parts = line.split(" ")
        if parts.len() < 2: continue
        let key = parts[0]
        let a = parts[1]
        let index = parse(a)
        let third = if parts.len() >= 3: parts[2].clone() else: ""
        let fourth = if parts.len() >= 4: parts[3].clone() else: ""
        if key == "version":
            saw_version = true
            s.version = index
            if s.version > SAVE_VERSION: return Err(.TooNew(version: s.version))
        else if key == "credits": s.credits = index
        else if key == "spent": s.spent = index
        else if key == "rank":
            if index >= 0 and index < SHOP_ITEM_COUNT: s.ranks[index] = parse(third)
        else if key == "runs": s.runs = index
        else if key == "clears": s.clears = index
        else if key == "kills": s.kills = index
        else if key == "seconds": s.seconds = parse_float(a)
        else if key == "cores": s.cores = index
        else if key == "elites": s.elites = index
        else if key == "bosses": s.bosses = index
        else if key == "caches": s.caches = index
        else if key == "hits": s.hits = index
        else if key == "banked": s.banked = index
        else if key == "merges": s.merges = index
        else if key == "best_level": s.best_level = index
        else if key == "best_combo": s.best_combo = index
        else if key == "best_merges_in_run": s.best_merges_in_run = index
        else if key == "best_hits_survived": s.best_hits_survived = index
        else if key == "bounced_kills": s.bounced_kills = index
        else if key == "no_reboot_clear": s.no_reboot_clear = parse_bool(a)
        else if key == "null_killed": s.null_killed = parse_bool(a)
        else if key == "best_time":
            if index >= 0 and index < SHIP_COUNT: s.best_time[index] = parse_float(third)
        else if key == "best_endless":
            if index >= 0 and index < SHIP_COUNT: s.best_endless[index] = parse_float(third)
        else if key == "cleared":
            if index >= 0 and index < SHIP_COUNT: s.cleared[index] = parse_bool(third)
        else if key == "ship_runs":
            if index >= 0 and index < SHIP_COUNT: s.ship_runs[index] = parse(third)
        else if key == "held":
            if index >= 0 and index < BASE_WEAPON_COUNT: s.held[index] = parse_float(third)
        else if key == "taken_weapon":
            if index >= 0 and index < WEAPON_COUNT: s.taken_weapons[index] = parse_bool(third)
        else if key == "taken_passive":
            if index >= 0 and index < PASSIVE_COUNT: s.taken_passives[index] = parse_bool(third)
        else if key == "registry":
            if index >= 0 and index < KIND_COUNT:
                s.registry_kills[index] = parse(third)
                s.registry_first[index] = parse_float(fourth)
        else if key == "last_ship": s.last_ship = index
        else if key == "volume": s.volume = parse_float(a)
        else if key == "deadzone": s.deadzone = parse_float(a)
    if not saw_version: return Err(.SetAside)
    s.version = SAVE_VERSION
    Ok(s)

// Where the save lives: the per-user data directory, never beside the
// executable. WIPE_SAVE_DIR overrides it for tests.
pub fn save_directory() -> str:
    let override = env("WIPE_SAVE_DIR")
    if override.len() > 0: return override
    let platform = os()
    let home = env("HOME")
    if platform == "Macos": return f"{home}/Library/Application Support/WIPE"
    if platform == "Windows":
        let appdata = env("APPDATA")
        return f"{appdata}\\WIPE"
    let xdg = env("XDG_DATA_HOME")
    if xdg.len() > 0: f"{xdg}/wipe" else: f"{home}/.local/share/wipe"

pub type SaveFile { directory: str, path: str, backup: str, temp: str, read_only: bool = false }

pub fn SaveFile.open() -> SaveFile:
    let directory = save_directory()
    let _ = mkdir_p(directory)
    SaveFile { path: f"{directory}/save.txt", backup: f"{directory}/save.bak", temp: f"{directory}/save.tmp", directory }

extend SaveFile:
    // Read the primary, then the backup. Both unreadable: set them aside
    // under a dated name and start fresh. A newer file is never touched.
    pub fn load(mut self: Self) -> (Save, LoadNotice):
        match self.read_one(self.path):
            Ok(s) => return (s, .Loaded)
            Err(.TooNew(v)) => {
                self.read_only = true
                return (Save {}, .TooNew(version: v))
            }
            Err(_) => ()
        match self.read_one(self.backup):
            Ok(s) => return (s, .Restored)
            Err(.TooNew(v)) => {
                self.read_only = true
                return (Save {}, .TooNew(version: v))
            }
            Err(_) => ()
        if not file_exists(self.path) and not file_exists(self.backup): return (Save {}, .Fresh)
        // Both unreadable: keep them under a dated name, never delete them.
        let stamp = now()
        if file_exists(self.path):
            let aside = f"{self.directory}/save.unreadable-{stamp}.txt"
            let _ = rename_file(self.path, aside)
        if file_exists(self.backup):
            let aside = f"{self.directory}/save.unreadable-{stamp}.bak"
            let _ = rename_file(self.backup, aside)
        (Save {}, .SetAside)

    fn read_one(self: &Self, path: &str) -> Result[Save, LoadNotice]:
        match read_file(path):
            Ok(text) => Save.parse_text(text)
            Err(_) => Err(.SetAside)

    // Temp file, rename the current to .bak, rename the temp over the current.
    pub fn store(self: &Self, save: &Save) -> bool:
        if self.read_only: return false
        if write_file(self.temp, save.serialize()) != 0: return false
        if file_exists(self.path):
            if rename_file(self.path, self.backup) != 0: return false
        rename_file(self.temp, self.path) == 0

// ----- the account's view of a finished run ---------------------------------

// Fold a run's facts into the save. Returns whether a new best was set.
pub fn record_run(save: Save, g: &Game) -> (Save, bool):
    var s = save
    let ship = g.launch.ship.index()
    s.runs += 1
    s.ship_runs[ship] += 1
    s.kills += g.kills
    s.seconds += g.elapsed
    s.cores += g.cores_collected
    s.elites += g.elites_killed
    s.bosses += g.bosses_killed
    s.caches += g.caches_opened
    s.hits += g.hits_taken
    s.merges += g.build.merges_this_run
    s.credits += g.credits
    s.banked += g.credits
    s.bounced_kills += g.bounced_kills
    if g.level > s.best_level: s.best_level = g.level
    if g.best_combo > s.best_combo: s.best_combo = g.best_combo
    if g.build.merges_this_run > s.best_merges_in_run: s.best_merges_in_run = g.build.merges_this_run
    // A hit is survived when the ship was still flying after it; a death's
    // final hit is not.
    let survived = if g.health > 0 or g.cleared: g.hits_taken else: g.hits_taken - 1
    if survived > s.best_hits_survived: s.best_hits_survived = survived
    if g.cleared and not g.launch.endless:
        s.clears += 1
        s.cleared[ship] = true
        if not g.reboot_used: s.no_reboot_clear = true
    if g.null_killed: s.null_killed = true
    var new_best = false
    if g.launch.endless:
        if g.elapsed > s.best_endless[ship]:
            s.best_endless[ship] = g.elapsed
            new_best = true
    else if g.elapsed > s.best_time[ship]:
        s.best_time[ship] = g.elapsed
        new_best = true
    for slot in 0..SLOT_COUNT:
        let w: WeaponSlot = g.build.weapons[slot]
        if w.level > 0 and w.weapon.is_base() and g.elapsed > s.held[w.weapon.index()]: s.held[w.weapon.index()] = g.elapsed
    for i in 0..WEAPON_COUNT:
        let taken: bool = g.launch.taken_weapons[i]
        if taken: s.taken_weapons[i] = true
    for i in 0..PASSIVE_COUNT:
        let taken: bool = g.launch.taken_passives[i]
        if taken: s.taken_passives[i] = true
    for i in 0..KIND_COUNT:
        s.registry_kills[i] += g.kills_by_kind[i]
        if g.kills_by_kind[i] > 0 and s.registry_first[i] < 0.0: s.registry_first[i] = g.minute()
    (s, new_best)
