use run
use steam

// WIPE, one build for every distribution: Steamworks (achievements, the
// overlay pause, Steam Input) when the Steam client is running, the plain
// SDL path otherwise. Steam is opened before the window so its overlay can
// hook the context the window creates.
fn main:
    run(SteamPlatform.open())
