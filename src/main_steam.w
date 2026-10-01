use run
use steam

// The Steam build: WIPE with Steamworks (achievements, the overlay pause).
// Steam is opened before the window; if it is missing, the game runs
// without it. src/main.w is the plain build.
fn main:
    let steam = SteamPlatform.open()
    if steam.relaunching(): return 0
    return run(steam)
