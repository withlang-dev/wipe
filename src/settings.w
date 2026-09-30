use std.fs
use std.process.env
use save
use game

// Per-machine settings, kept apart from the save: Steam Cloud carries the
// save between a Deck and a desktop, and whether this screen runs
// fullscreen belongs to the machine. `key value` lines like the save,
// written atomically beside it.
pub type Settings { volume: f64 = 1.0, deadzone: f64 = 0.2, fullscreen: bool = false }
impl Copy for Settings

extend Settings:
    pub fn serialize(self: &Self) -> str:
        f"volume {fmt_float(self.volume)}\ndeadzone {fmt_float(self.deadzone)}\nfullscreen {fmt_bool(self.fullscreen)}\n"

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
