// The SDK integration test never writes WIPE achievements to Spacewar.
// It restores the original test flag, including after a failed phase.
use steam
use platform
use controls
use input
use game
use achievement_sync
use c_import("raylib.h")
use std.process.{args, env}
use std.time.now_ns

// A pause without a window: raylib's WaitTime needs one, and spins forever
// otherwise. The harness waits on the clock instead.
fn pause_ms(ms: i64):
    let until = now_ns() + ms * 1000000
    while now_ns() < until: ()

extend SteamPlatform:
    fn wait_for_achievement(mut self: Self, id: &str) -> Option[bool]:
        let deadline = now_ns() + 20000000000
        while self.initialized and now_ns() < deadline:
            self.frame()
            if let Some(value) = self.achievement_status(id): return Some(value)
            pause_ms(50)
        None

    fn wait_for_store(mut self: Self, after: i32, earned: &List[str]) -> bool:
        let deadline = now_ns() + 20000000000
        while self.initialized and now_ns() < deadline:
            self.frame()
            self.sync_achievements(earned)
            if self.stores_completed > after and not self.sync.dirty and not self.sync.waiting: return true
            pause_ms(20)
        false

    fn test_overlay(mut self: Self) -> i32:
        SetTraceLogLevel(LOG_WARNING)
        InitWindow(960, 600, "WIPE Steam overlay acceptance")
        if not IsWindowReady(): return 1
        defer: CloseWindow()
        SetTargetFPS(60)
        let started = GetTime()
        var opened = false
        var closed = false
        while not WindowShouldClose() and GetTime() - started < 60.0:
            let events = self.frame()
            if events.overlay_opened: opened = true
            if opened and events.overlay_closed: closed = true
            BeginDrawing()
            ClearBackground(BLACK)
            DrawText("Open and close Steam Overlay (Shift+Tab)", 40, 200, 24, WHITE)
            DrawText(if events.blocks_input(): "Gameplay input blocked" else: "Overlay inactive", 40, 260, 24, GREEN)
            EndDrawing()
            if closed: break
        if not opened or not closed:
            eprint("Steam overlay acceptance incomplete: opening and closing callbacks were not both observed.")
            return 1
        print("Steam UAT passed: overlay open/close callbacks and input gate.")
        0

extend SteamPlatform:
    // Steam Input: the manifest loads, a controller is seen, and its
    // bindings name the prompts. Needs a controller connected to Steam.
    fn test_input(mut self: Self) -> i32:
        let started = now_ns()
        var frame = ActionFrame {}
        var names: List[str] = List.new()
        var frames = 0
        while now_ns() - started < 15000000000:
            frames += 1
            self.frame()
            if let Some(f) = self.controller(true): frame = f
            if frame.id != 0:
                names = self.prompts()
                if names.len() > 0: break
            pause_ms(50)
        for line in self.input_diagnostics(): print(line)
        print(f"Steam Input probe: {frames} frames in {(now_ns() - started) / 1000000} ms")
        if not self.input_ready():
            eprint("Steam Input never resolved WIPE's action sets: check assets/steam/steam_input_manifest.vdf beside the executable.")
            return 1
        if frame.id == 0:
            eprint("Steam Input saw no controller in 15 seconds; connect one to Steam and rerun.")
            return 1
        if names.len() == 0:
            eprint("Steam Input bound no actions for the controller: the default layout for its type did not load.")
            return 1
        for action in [Action.Confirm, .Back, .Pause, .Move, .Aim, .Reroll]:
            print(f"prompt {action_index(action)} -> {names[action_index(action)]}")
        print("Steam UAT passed: Steam Input manifest, controller, bindings and prompts.")
        0

fn main:
    let read_only = env("WIPE_STEAM_DISABLE") == "1" or args().contains("--expect-unavailable") or args().contains("--probe") or args().contains("--no-stats") or args().contains("--overlay-only") or args().contains("--input")
    var platform = SteamPlatform.open(spacewar_test: true)
    defer:
        // A failed callback can mark sync dirty even in a read-only mode.
        // Discard Steam's borrowed stats pointer so shutdown cannot store it.
        if read_only: platform.stats = null
        platform.shutdown()
    let none = List.new()
    if env("WIPE_STEAM_DISABLE") == "1" or args().contains("--expect-unavailable"):
        if platform.initialized:
            eprint("Steam initialized; the unavailable-client check requires a disconnected client.")
            return 1
        assert(not platform.initialized and platform.controller(true).is_none() and platform.prompts().len() == 0)
        assert(platform.notice().len() > 0 and not platform.frame().blocks_input())
        platform.sync_achievements(&none)
        platform.shutdown()
        print("Steam UAT passed: unavailable platform, notices, harmless sync and repeated cleanup.")
        return 0
    if not platform.initialized:
        eprint("Steam UAT needs a logged-in Steam client and a development steam_appid.txt containing 480.")
        return 2
    if platform.app_id != 480:
        eprint(f"Steam UAT refuses to alter achievements for app {platform.app_id}; use Spacewar (480).")
        return 2
    if args().contains("--overlay-only"): return platform.test_overlay()
    if args().contains("--input"): return platform.test_input()
    if args().contains("--no-stats"):
        // The interface belongs to Steam, so discarding our borrowed pointer
        // models an unavailable accessor without releasing any SDK resource.
        platform.stats = null
        platform.frame()
        platform.sync_achievements(&none)
        platform.shutdown()
        platform.shutdown()
        assert(not platform.initialized and platform.controller(true).is_none())
        print("Steam UAT passed: initialized client without stats, callbacks and repeated cleanup.")
        return 0
    let id = "ACH_WIN_ONE_GAME"
    let Some(original) = platform.wait_for_achievement(id) else:
        eprint("Steam UAT could not read the Spacewar test achievement after 20 seconds of callback dispatch. Check the test account's client connection and Spacewar access.")
        for line in platform.diagnostics(): eprint(line)
        return 2
    if args().contains("--probe"):
        platform.frame()
        print(f"Steam UAT passed: Spacewar initialization, stats accessor, achievement query and manual dispatch; test achievement unlocked={original}; no achievement changes.")
        return 0
    if args().contains("--store-unchanged"):
        let before: i32 = platform.stores_completed
        // Submit the client's current stats through the normal retry path.
        // The empty earned list cannot call SetAchievement; this branch
        // never clears an achievement or enters the mutation test below.
        platform.sync.dirty = true
        platform.sync.flush()
        if not platform.wait_for_store(before, &none):
            eprint("Steam UAT failed: unchanged stats store did not receive a confirmed successful manual-dispatch callback within 20 seconds.")
            return 1
        if platform.achievement_status(id) != Some(original):
            eprint("Steam UAT failed: the test achievement flag could not be confirmed unchanged after storing stats.")
            return 1
        print(f"Steam UAT passed: unchanged stats submitted, successful manual-dispatch store callback received, test achievement unlocked={original}; no unlock or reset calls.")
        return 0
    if original:
        eprint("Steam UAT needs a test account where ACH_WIN_ONE_GAME is still locked. It will not reset an existing achievement's unlock timestamp.")
        return 2
    var earned = List.new()
    earned.push(id.clone())
    var ok = true
    let before_clear: i32 = platform.stores_completed
    if not platform.clear_test_achievement(id): ok = false
    else if not platform.wait_for_store(before_clear, &none): ok = false
    if ok and platform.achievement_status(id) != Some(false): ok = false
    if ok:
        let before_set: i32 = platform.stores_completed
        if not platform.wait_for_store(before_set, &earned): ok = false
        else if platform.achievement_status(id) != Some(true): ok = false
    // Restore the account's original flag regardless of the test result.
    let before_restore: i32 = platform.stores_completed
    var restored = true
    if original:
        platform.sync.flush()
        platform.sync_achievements(&earned)
        if platform.sync.dirty or platform.sync.waiting:
            restored = platform.wait_for_store(before_restore, &earned)
    else:
        restored = platform.clear_test_achievement(id)
        if restored: restored = platform.wait_for_store(before_restore, &none)
    if not restored or platform.achievement_status(id) != Some(original):
        eprint("Steam UAT failed to confirm restoration of the test achievement; rerun with Steam online.")
        return 1
    if not ok:
        eprint("Steam UAT failed a store or callback check; original achievement restored.")
        return 1
    print(f"Steam UAT passed: app {platform.app_id}, query, clear, set, manual dispatch, {platform.stores_completed} successful store callbacks, original flag restored.")
    if args().contains("--overlay"): return platform.test_overlay()
    0
