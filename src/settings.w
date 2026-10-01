use std.fs
use std.process.env
use save
use game

// Per-machine settings, kept apart from the save: Steam Cloud carries the
// save between a Deck and a desktop, and whether this screen runs
// fullscreen belongs to the machine. `key value` lines like the save,
// written atomically beside it.
pub type Settings { volume: f64 = 1.0, deadzone: f64 = 0.2, fullscreen: bool = false, vsync: bool = true, frame_limit: i32 = 0 }
impl Copy for Settings

extend Settings:
    pub fn serialize(self: &Self) -> str:
        f"volume {fmt_float(self.volume)}\ndeadzone {fmt_float(self.deadzone)}\nfullscreen {fmt_bool(self.fullscreen)}\nvsync {fmt_bool(self.vsync)}\nframe_limit {self.frame_limit}\n"

// Unknown keys and malformed lines are ignored; a missing key keeps its
// default.
pub fn Settings.parse_text(text: &str) -> Settings:
    var s = Settings {}
    for raw in text.split("\n"):
        let parts = raw.trim().split(" ")
        if parts.len() < 2: continue
        let key = parts[0]
        let value = parts[1]
        if key == "volume": s.volume = limit(parse_float(value), 0.0, 1.0)
        else if key == "deadzone": s.deadzone = limit(parse_float(value), 0.05, 0.5)
        else if key == "fullscreen": s.fullscreen = parse_bool(value)
        else if key == "vsync":
            if value == "true" or value == "1": s.vsync = true
            else if value == "false" or value == "0": s.vsync = false
        else if key == "frame_limit":
            for cap in FRAME_LIMITS:
                if value == f"{cap}": s.frame_limit = cap
    s

// A machine without settings.txt takes volume and deadzone from the save,
// where they lived before; the save keeps reading them and stops writing them.
// A first launch under SteamOS's gamescope (a Steam Deck, a Steam Machine)
// starts fullscreen: there a window should cover the panel.
pub fn Settings.from_save(save: &Save) -> Settings:
    Settings { volume: save.volume, deadzone: save.deadzone, fullscreen: under_gamescope() }

pub fn under_gamescope() -> bool:
    env("SteamDeck") == "1" or env("XDG_CURRENT_DESKTOP") == "gamescope"


pub type SettingsFile { path: str, temp: str }

pub fn SettingsFile.open(directory: &str) -> SettingsFile:
    SettingsFile { path: f"{directory}/settings.txt", temp: f"{directory}/settings.tmp" }

extend SettingsFile:
    pub fn load(self: &Self) -> Option[Settings]:
        if not file_exists(self.path): return None
        match read_file(self.path):
            Ok(text) => Some(Settings.parse_text(text))
            Err(_) => None

    // Temp file, then rename over the current one.
    pub fn store(self: &Self, settings: &Settings) -> bool:
        if write_file(self.temp, settings.serialize()) != 0: return false
        rename_file(self.temp, self.path) == 0

// AUTO follows the active panel (60 Hz LCD, 90 Hz OLED, or a docked screen).
// The fallback limiter also keeps a driver that ignores VSync from spinning.
pub const FRAME_LIMITS: [i32; 7] = [0, 30, 40, 45, 60, 90, 120]
pub fn frame_target(settings: &Settings, refresh: i32) -> i32:
    if settings.frame_limit > 0: settings.frame_limit
    else if refresh > 0: refresh
    else: 60
pub fn next_frame_limit(current: i32, direction: i32) -> i32:
    for i in 0..7:
        if FRAME_LIMITS[i] == current: return FRAME_LIMITS[(i + direction + 7) % 7]
    0
