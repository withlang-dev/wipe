// The SDK integration test never writes WIPE achievements to Spacewar.
// It restores the original test flag, including after a failed phase.
use steam
use platform
use achievement_sync
use c_import("raylib.h")
use std.process.{args, env}
use std.time.now_ns

extend SteamPlatform:
    fn wait_for_achievement(mut self: Self, id: &str) -> Option[bool]:
        let deadline = now_ns() + 20000000000
        while self.initialized and now_ns() < deadline:
            self.frame()
            if let Some(value) = self.achievement_status(id): return Some(value)
            WaitTime(0.05)
        None

    fn wait_for_store(mut self: Self, after: i32, earned: &Vec[str]) -> bool:
        let deadline = now_ns() + 20000000000
        while self.initialized and now_ns() < deadline:
            self.frame()
            self.sync_achievements(earned)
            if self.stores_completed > after and not self.sync.dirty and not self.sync.waiting: return true
            WaitTime(0.02)
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

fn main:
    let read_only = env("WIPE_STEAM_DISABLE") == "1" or args().contains("--expect-unavailable") or args().contains("--probe") or args().contains("--no-stats") or args().contains("--overlay-only")
    var platform = SteamPlatform.open(0, spacewar_test: true)
    defer:
        // A failed callback can mark sync dirty even in a read-only mode.
        // Discard Steam's borrowed stats pointer so shutdown cannot store it.
        if read_only: platform.stats = null
        platform.shutdown()
    let none = Vec.new()
    if env("WIPE_STEAM_DISABLE") == "1" or args().contains("--expect-unavailable"):
        if platform.initialized:
            eprint("Steam initialized; the unavailable-client check requires a disconnected client.")
            return 1
        assert(not platform.initialized and not platform.manages_controllers())
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
    if args().contains("--no-stats"):
        // The interface belongs to Steam, so discarding our borrowed pointer
        // models an unavailable accessor without releasing any SDK resource.
        platform.stats = null
        platform.frame()
        platform.sync_achievements(&none)
        platform.shutdown()
        platform.shutdown()
        assert(not platform.initialized and not platform.manages_controllers())
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
        let before = platform.stores_completed
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
    var earned = Vec.new()
    earned.push(id.clone())
    var ok = true
    let before_clear = platform.stores_completed
    if not platform.clear_test_achievement(id): ok = false
    else if not platform.wait_for_store(before_clear, &none): ok = false
    if ok and platform.achievement_status(id) != Some(false): ok = false
    if ok:
        let before_set = platform.stores_completed
        if not platform.wait_for_store(before_set, &earned): ok = false
        else if platform.achievement_status(id) != Some(true): ok = false
    // Restore the account's original flag regardless of the test result.
    let before_restore = platform.stores_completed
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
