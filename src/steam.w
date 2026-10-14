// The optional Steam binding. All application-facing behavior is With;
// c_import reads Valve's C-linkage surface directly from its local SDK.
use c_import("steam/steam_api_flat.h", lang: "c++", link: "steam_api", no_methods: true)
use platform
use controls
use input
use game
use paths
use achievement_sync
use std.time.now_ns
use std.process.env
use std.string

const OVERLAY_BYTES = comptime GameOverlayActivated_t.size() as i32
const STORED_BYTES = comptime UserStatsStored_t.size() as i32

fn steam_time() -> f64: now_ns() as f64 / 1000000000.0

pub type SteamPlatform {
    initialized: bool = false,
    overlay: bool = false,
    pipe: i32 = 0,
    app_id: u32 = 0,
    spacewar_test: bool = false,
    stats: *mut ISteamUserStats = null,
    // Steam Input: the action sets and actions of assets/steam, resolved
    // once Steam has loaded the manifest; the controller in the player's
    // hands and its actions held last frame.
    input: *mut ISteamInput = null,
    set_menu: u64 = 0, set_flight: u64 = 0,
    digital: [u64; 16] = [0; 16],
    analog_move: u64 = 0, analog_aim: u64 = 0, analog_navigate: u64 = 0,
    pad: u64 = 0, pad_held: u32 = 0, pad_count: i32 = 0,
    next_resolve: f64 = 0.0,
    sync: AchievementSync,
    message: str = "",
    stores_completed: i32 = 0,
    store_errors: i32 = 0,
    overlay_events: i32 = 0,
}

// Open before the graphics context so Steam can attach its overlay. One
// build serves every distribution: launched from Steam, the client supplies
// the App ID; launched from anywhere else, Steam's absence is a notice and
// the game runs without it. Nothing here ever relaunches through Steam.
pub fn SteamPlatform.open(spacewar_test: bool = false) -> SteamPlatform:
    var p = SteamPlatform { sync: AchievementSync.new(), spacewar_test }
    // Also provides a deterministic disconnected-platform acceptance path.
    if env("WIPE_STEAM_DISABLE") == "1":
        p.message = "Steam isn't running: achievements will sync next time."
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
    p.open_input()
    p

// ----- Steam Input ----------------------------------------------------------
//
// The game's actions are declared in assets/steam/steam_input_manifest.vdf
// with a default layout per controller type beside it; Steam binds them to
// whatever controller the player holds, lets the player rebind in its own
// configurator, and names the bound control for the prompts. The game reads
// actions and never a button.

// Digital actions, in the order of their bits in src/controls.w. The pause
// exists in both sets under its own name: Steam resolves actions by name.
const DIGITAL_ACTIONS = ["confirm", "back", "shop", "collection", "tab_left", "tab_right", "pause", "up", "down", "left", "right", "reroll", "skip", "banish", "next", "fly_pause"]
const DIGITAL_COUNT = 16
const ACTIVE_STICK2 = 0.25

fn digital_bit(index: i32) -> u32: if index == DIGITAL_COUNT - 1: ACT_PAUSE else: (1 as u32) << index as u32

// Steam's own static text, copied: the pointer is valid until the next call.
unsafe fn steam_text(text: *const c_char) -> str:
    if text == null: "" else: CStr.from_ptr(text as *const i8).to_owned()

extend SteamPlatform:
    fn open_input(mut self: Self):
        unsafe:
            self.input = SteamAPI_SteamInput_v007()
        if self.input == null: return
        let Ok(manifest) = asset_path("steam/steam_input_manifest.vdf").to_cstring() else:
            self.input = null
            return
        unsafe:
            // The manifest beside the executable, whether or not this copy
            // was installed by Steam: the game never depends on the depot's
            // Steamworks setting to find its own actions.
            if not SteamAPI_ISteamInput_SetInputActionManifestFilePath(self.input, manifest.as_cstr().ptr() as *const c_char):
                eprint("Steam Input did not accept WIPE's action manifest; controllers fall back to SDL.")
            if not SteamAPI_ISteamInput_Init(self.input, true):
                self.input = null
                return
        self.resolve_actions()

    // Handles are 0 until Steam has a controller and its mapping for the
    // game; ask once a second until they are (the lookup is not free: Steam
    // waits on its mapping before answering).
    fn resolve_actions(mut self: Self):
        if self.set_menu != 0 and self.set_flight != 0: return
        let now = steam_time()
        if now < self.next_resolve: return
        self.next_resolve = now + 1.0
        unsafe:
            self.set_menu = SteamAPI_ISteamInput_GetActionSetHandle(self.input, c"Menu".ptr as *const c_char)
            self.set_flight = SteamAPI_ISteamInput_GetActionSetHandle(self.input, c"Flight".ptr as *const c_char)
            if self.set_menu == 0 or self.set_flight == 0: return
            for i in 0..DIGITAL_COUNT:
                let Ok(name) = DIGITAL_ACTIONS[i].to_cstring() else continue
                self.digital[i] = SteamAPI_ISteamInput_GetDigitalActionHandle(self.input, name.as_cstr().ptr() as *const c_char)
            self.analog_move = SteamAPI_ISteamInput_GetAnalogActionHandle(self.input, c"move".ptr as *const c_char)
            self.analog_aim = SteamAPI_ISteamInput_GetAnalogActionHandle(self.input, c"aim".ptr as *const c_char)
            self.analog_navigate = SteamAPI_ISteamInput_GetAnalogActionHandle(self.input, c"navigate".ptr as *const c_char)

    pub fn input_ready(self: &Self) -> bool: self.input != null and self.set_menu != 0 and self.set_flight != 0

    fn actions_held(self: &Self, handle: u64) -> u32:
        var mask: u32 = 0
        for i in 0..DIGITAL_COUNT:
            if self.digital[i] == 0: continue
            let data = unsafe { SteamAPI_ISteamInput_GetDigitalActionData(self.input, handle, self.digital[i]) }
            if data.bState: mask |= digital_bit(i)
        mask

    // Steam's sticks point up for positive y; the game's screen points down.
    fn stick(self: &Self, handle: u64, action: u64) -> V2:
        if action == 0: return V2 {}
        let data = unsafe { SteamAPI_ISteamInput_GetAnalogActionData(self.input, handle, action) }
        V2 { x: limit(data.x as f64, -1.0, 1.0), y: limit(-(data.y as f64), -1.0, 1.0) }

    fn origin_name(self: &Self, set: u64, action: u64, analog: bool) -> str:
        if self.pad == 0 or action == 0: return ""
        var origins: [i32; 8] = [0; 8]
        let count = unsafe {
            if analog: SteamAPI_ISteamInput_GetAnalogActionOrigins(self.input, self.pad, set, action, &raw mut origins[0])
            else: SteamAPI_ISteamInput_GetDigitalActionOrigins(self.input, self.pad, set, action, &raw mut origins[0])
        }
        if count <= 0: return ""
        unsafe { steam_text(SteamAPI_ISteamInput_GetStringForActionOrigin(self.input, origins[0])) }

    fn digital_name(self: &Self, index: i32) -> str:
        let set = if index == DIGITAL_COUNT - 1: self.set_flight else: self.set_menu
        self.origin_name(set, self.digital[index], false)

    // Read-only diagnostics for steam-uat: never account facts.
    pub fn input_diagnostics(self: &Self) -> List[str]:
        var lines: List[str] = List.new()
        lines.push(f"Steam Input interface={self.input != null}, sets menu={self.set_menu} flight={self.set_flight}, controllers={self.pad_count}, in hand={self.pad}")
        if self.pad != 0:
            let kind = unsafe { SteamAPI_ISteamInput_GetInputTypeForHandle(self.input, self.pad) }
            lines.push(f"Controller type {kind as i32}")
        lines

    pub fn achievement_status(self: &Self, id: &str) -> Option[bool]:
        if not self.initialized or self.stats == null: return None
        if self.app_id == 480 and not self.spacewar_test: return None
        let Ok(name) = id.to_cstring() else return None
        var achieved = false
        let ok = unsafe { SteamAPI_ISteamUserStats_GetAchievement(self.stats, name.as_cstr().ptr() as *const c_char, &raw mut achieved) }
        if ok: Some(achieved) else: None

    // Read-only test diagnostics: connection/schema facts, never account IDs.
    pub fn diagnostics(self: &Self) -> List[str]:
        var lines: List[str] = List.new()
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
        let cleared = unsafe { SteamAPI_ISteamUserStats_ClearAchievement(self.stats, name.as_cstr().ptr() as *const c_char) }
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

    fn sync_achievements(mut self: Self, earned: &List[str]):
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
            if unsafe { SteamAPI_ISteamUserStats_SetAchievement(self.stats, name.as_cstr().ptr() as *const c_char) }:
                self.sync.remember(id, true)
        self.store(steam_time())

    fn notice(self: &Self) -> str: self.message.clone()

    fn controller(mut self: Self, menu: bool) -> Option[ActionFrame]:
        if not self.initialized or self.input == null: return None
        unsafe:
            SteamAPI_ISteamInput_RunFrame(self.input, false)
        self.resolve_actions()
        var handles: [u64; 16] = [0; 16]
        let count = unsafe { SteamAPI_ISteamInput_GetConnectedControllers(self.input, &raw mut handles[0]) }
        self.pad_count = count
        if count <= 0 or not self.input_ready():
            self.pad = 0
            self.pad_held = 0
            return None
        // Every controller follows the screen, and the one used last drives
        // the game (on a Deck with a controller on its puck, both are
        // present; the Deck's own sticks drift, so half travel is the bar).
        let set = if menu: self.set_menu else: self.set_flight
        var present = false
        for i in 0..count:
            let handle = handles[i]
            unsafe:
                SteamAPI_ISteamInput_ActivateActionSet(self.input, handle, set)
            if handle == self.pad: present = true
        for i in 0..count:
            let handle = handles[i]
            if handle == self.pad: continue
            let motion = self.stick(handle, if menu: self.analog_navigate else: self.analog_move)
            let aim = if menu: V2 {} else: self.stick(handle, self.analog_aim)
            if self.actions_held(handle) != 0 or length2(motion) > ACTIVE_STICK2 or length2(aim) > ACTIVE_STICK2:
                self.pad = handle
                self.pad_held = 0
                present = true
        if not present:
            self.pad = handles[0]
            self.pad_held = 0
        let held = self.actions_held(self.pad)
        let frame = ActionFrame {
            id: self.pad,
            motion: self.stick(self.pad, if menu: self.analog_navigate else: self.analog_move),
            aim: if menu: V2 {} else: self.stick(self.pad, self.analog_aim),
            held, pressed: held & ~self.pad_held,
        }
        self.pad_held = held
        Some(frame)

    // The bound control's name per prompt, in input.w's Action order.
    fn bound_name(self: &Self, index: i32) -> str:
        let back = self.digital_name(1)
        match index:
            0 => self.digital_name(0)
            1 => back
            2 => self.digital_name(2)
            3 => self.digital_name(3)
            4 => self.digital_name(15)
            5 => f"{back} / {self.digital_name(6)}"
            6 => f"HOLD {back}"
            7 => f"{self.digital_name(7)} / {self.digital_name(8)}"
            8 => f"{self.digital_name(4)} / {self.digital_name(5)}"
            9 => self.digital_name(14)
            10 => self.digital_name(11)
            11 => self.digital_name(12)
            12 => self.digital_name(13)
            13 => self.origin_name(self.set_flight, self.analog_move, true)
            _ => self.origin_name(self.set_flight, self.analog_aim, true)

    fn prompts(self: &Self) -> List[str]:
        var names: List[str] = List.new()
        if self.pad == 0 or not self.input_ready(): return names
        // No name for confirm means the bindings are still loading: the
        // game keeps its own table until Steam has them.
        if self.digital_name(0).len() == 0: return names
        for index in 0..ACTION_COUNT: names.push(self.bound_name(index))
        names

    fn shutdown(mut self: Self):
        if not self.initialized: return
        if self.stats != null and self.sync.dirty:
            // One final best-effort store; persisted game facts are retried
            // next launch even if the client cannot accept it at exit.
            let accepted = unsafe { SteamAPI_ISteamUserStats_StoreStats(self.stats) }
            if not accepted: eprint("Steam achievements will sync next launch.")
        if self.input != null:
            unsafe:
                let _ = SteamAPI_ISteamInput_Shutdown(self.input)
        SteamAPI_Shutdown()
        self.initialized = false
        self.stats = null
        self.input = null
        self.pad = 0
        self.pipe = 0
