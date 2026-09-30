use run
use platform

// The plain build: no store, no Steam. src/main_steam.w is the Steam build.
fn main:
    return run(NoPlatform {})
