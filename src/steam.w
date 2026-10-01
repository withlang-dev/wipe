// The optional Steam binding. All application-facing behavior is With;
// c_import reads Valve's C-linkage surface directly from its local SDK.
use c_import("steam/steam_api_flat.h", lang: "c++", link: "steam_api", no_methods: true)
use platform
use achievement_sync
use steam_config
use std.time.now_ns
use std.process.env
use std.string

const OVERLAY_BYTES: i32 = comptime GameOverlayActivated_t.size() as i32
const STORED_BYTES: i32 = comptime UserStatsStored_t.size() as i32

fn steam_time() -> f64: now_ns() as f64 / 1000000000.0

pub type SteamPlatform {
    initialized: bool = false,
    restarting: bool = false,
    overlay: bool = false,
    pipe: i32 = 0,
    app_id: u32 = 0,
    spacewar_test: bool = false,
    stats: *mut ISteamUserStats = null,
    sync: AchievementSync,
    message: str = "",
    stores_completed: i32 = 0,
    store_errors: i32 = 0,
    overlay_events: i32 = 0,
}

// Open before the graphics context so Steam can attach its overlay.
// App ID 0 uses the development steam_appid.txt without requesting a restart.
pub fn SteamPlatform.open(app_id: u32 = STEAM_APP_ID, spacewar_test: bool = false) -> SteamPlatform:
    var p = SteamPlatform { sync: AchievementSync.new(), spacewar_test }
    // Also provides a deterministic disconnected-platform acceptance path.
    if env("WIPE_STEAM_DISABLE") == "1":
        p.message = "Steam isn't running: achievements will sync next time."
        return p
    if app_id != 0 and SteamAPI_RestartAppIfNecessary(app_id):
        p.restarting = true
        return p
    var err: SteamErrMsg = [0 as c_char; 1024]
    let result = unsafe { SteamAPI_InitFlat(&raw mut err) }
    if result != k_ESteamAPIInitResult_OK:
        p.message = "Steam isn't running: achievements will sync next time."
        eprint(f"Steam initialization unavailable (result {result}).")
        return p
    p.initialized = true
    SteamAPI_ManualDispatch_Init()
    p.pipe = SteamAPI_GetHSteamPipe()
    unsafe:
        p.stats = SteamAPI_SteamUserStats_v013()
        let utils = SteamAPI_SteamUtils_v011()
        if utils != null: p.app_id = SteamAPI_ISteamUtils_GetAppID(utils)
    if p.stats == null: p.message = "Steam's achievements are unavailable this session."
    else if p.app_id == 480 and not p.spacewar_test:
        p.message = "Steam test app: WIPE achievements remain local."
    p

extend SteamPlatform:
    pub fn relaunching(self: &Self) -> bool: self.restarting

    pub fn achievement_status(self: &Self, id: &str) -> Option[bool]:
        if not self.initialized or self.stats == null: return None
        if self.app_id == 480 and not self.spacewar_test: return None
        let Ok(name) = id.to_cstring() else return None
        var achieved = false
        let ok = unsafe { SteamAPI_ISteamUserStats_GetAchievement(self.stats, name.ptr as *const c_char, &raw mut achieved) }
        if ok: Some(achieved) else: None

    // Read-only test diagnostics: connection/schema facts, never account IDs.
    pub fn diagnostics(self: &Self) -> Vec[str]:
        var lines: Vec[str] = Vec.new()
        lines.push(f"Steam initialized={self.initialized}, app={self.app_id}, stats={self.stats != null}")
        if not self.initialized: return lines
        unsafe:
            let user = SteamAPI_SteamUser_v023()
            if user != null: lines.push(f"Steam client online={SteamAPI_ISteamUser_BLoggedOn(user)}")
            if self.stats != null:
                let count = SteamAPI_ISteamUserStats_GetNumAchievements(self.stats)
                lines.push(f"Steam achievement schema contains {count} entries")
                for index in 0..count as i32:
                    if index >= 32: break
                    let name = SteamAPI_ISteamUserStats_GetAchievementName(self.stats, index as u32)
                    if name != null: lines.push(CStr.from_ptr(name as *const i8).to_owned())
        lines

    // Used only by steam-uat, and physically limited to Valve's test app.
    // The harness restores the original flag before reporting success.
    pub fn clear_test_achievement(mut self: Self, id: &str) -> bool:
        if not self.initialized or self.stats == null or self.app_id != 480 or not self.spacewar_test: return false
        let Ok(name) = id.to_cstring() else return false
        let cleared = unsafe { SteamAPI_ISteamUserStats_ClearAchievement(self.stats, name.ptr as *const c_char) }
        if cleared:
            self.sync.known.clear()
            self.sync.dirty = true
            self.sync.flush()
        cleared

    fn store(mut self: Self, now: f64):
        if self.sync.ready(now):
            let accepted = unsafe { SteamAPI_ISteamUserStats_StoreStats(self.stats) }
            self.sync.submitted(accepted, now)
            if not accepted:
                self.store_errors += 1
                eprint("Steam achievement store deferred; WIPE will retry.")

impl Platform for SteamPlatform:
    fn frame(mut self: Self) -> PlatformFrame:
        var out = PlatformFrame {}
        if not self.initialized: return out
        var shutdown_requested = false
        let now = steam_time()
        SteamAPI_ManualDispatch_RunFrame(self.pipe)
        unsafe:
            var msg = CallbackMsg_t {}
            while SteamAPI_ManualDispatch_GetNextCallback(self.pipe, &raw mut msg):
                if msg.m_iCallback == GameOverlayActivated_t_k_iCallback and msg.m_pubParam != null and msg.m_cubParam >= OVERLAY_BYTES:
                    let event = msg.m_pubParam as *const GameOverlayActivated_t
                    let active = (*event).m_bActive != 0
                    if active and not self.overlay: out.overlay_opened = true
                    if not active and self.overlay: out.overlay_closed = true
                    self.overlay = active
                    self.overlay_events += 1
                else if msg.m_iCallback == UserStatsStored_t_k_iCallback and msg.m_pubParam != null and msg.m_cubParam >= STORED_BYTES:
                    let event = msg.m_pubParam as *const UserStatsStored_t
                    if (*event).m_nGameID == self.app_id as u64:
                        let ok = (*event).m_eResult == k_EResultOK
                        self.sync.completed(ok, (*event).m_eResult == k_EResultInvalidParam, now)
                        if ok: self.stores_completed += 1
                        else:
                            self.store_errors += 1
                            eprint(f"Steam achievement store failed ({(*event).m_eResult}); WIPE will retry.")
                else if msg.m_iCallback == SteamShutdown_t_k_iCallback:
                    shutdown_requested = true
                SteamAPI_ManualDispatch_FreeLastCallback(self.pipe)
                if shutdown_requested: break
        if shutdown_requested:
            self.shutdown()
            out.overlay_closed = out.overlay_closed or self.overlay
            self.overlay = false
            return out
        self.sync.tick(now)
        out.overlay_active = self.overlay
        out

    fn sync_achievements(mut self: Self, earned: &Vec[str]):
        if not self.initialized or self.stats == null: return
        if self.app_id == 480 and not self.spacewar_test: return
        // SDK 1.65/v013 has the client synchronize stats before the process
        // starts. RequestCurrentStats is removed; failed queries stay eligible.
        for id in earned:
            if not self.sync.needs(id): continue
            let Some(achieved) = self.achievement_status(id) else continue
            if achieved:
                self.sync.remember(id, false)
                continue
            let Ok(name) = id.to_cstring() else continue
            if unsafe { SteamAPI_ISteamUserStats_SetAchievement(self.stats, name.ptr as *const c_char) }:
                self.sync.remember(id, true)
        self.store(steam_time())

    fn notice(self: &Self) -> str: self.message.clone()
    fn manages_controllers(self: &Self) -> bool: self.initialized

    fn shutdown(mut self: Self):
        if not self.initialized: return
        if self.stats != null and self.sync.dirty:
            // One final best-effort store; persisted game facts are retried
            // next launch even if the client cannot accept it at exit.
            let accepted = unsafe { SteamAPI_ISteamUserStats_StoreStats(self.stats) }
            if not accepted: eprint("Steam achievements will sync next launch.")
        SteamAPI_Shutdown()
        self.initialized = false
        self.stats = null
        self.pipe = 0
