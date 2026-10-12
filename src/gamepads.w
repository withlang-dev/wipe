// SDL owns native controller transport and mapping; raylib owns the window.
use sdl
use c_import("SDL3/SDL.h")
use game

pub fn controller_error() -> str:
    SDL_GetError().map(it.to_str_lossy()) ?? "Unknown SDL error"

pub fn axis_unit(value: i16) -> f64:
    value as f64 / (if value < 0: 32768.0 else: 32767.0)

// Button bits, shared by held and pressed masks.
pub const BTN_SOUTH: u32 = 1
pub const BTN_EAST: u32 = 2
pub const BTN_WEST: u32 = 4
pub const BTN_NORTH: u32 = 8
pub const BTN_LB: u32 = 16
pub const BTN_RB: u32 = 32
pub const BTN_START: u32 = 64
pub const BTN_UP: u32 = 128
pub const BTN_DOWN: u32 = 256
pub const BTN_LEFT: u32 = 512
pub const BTN_RIGHT: u32 = 1024

pub type PadFrame {
    id: u32 = 0, motion: V2 = V2 {}, aim: V2 = V2 {},
    south: bool = false, retry: bool = false,
    // Every button held this frame, and those that went down this frame.
    held: u32 = 0, pressed: u32 = 0,
} with Copy
extend PadFrame:
    pub fn down(self: &Self, bit: u32) -> bool: (self.pressed & bit) != 0

// Every connected controller stays open, and the one last used drives the
// game: on a Steam Deck with a Steam Controller on its puck, Steam Input
// presents two virtual pads (the Deck's own controls first), and holding
// only the first left the controller in the player's hands dead.
// Discovery runs at most twice per second.
type Seat {
    pad: Pad, south_held: bool = false, held: u32 = 0,
    // A physical Valve controller: when "lizard mode off" was last sent.
    valve: bool = false, next_controller_mode: u64 = 0,
}

pub type Gamepads {
    seats: List[Seat] = List.new(), active: u32 = 0, ready: bool = false, next_scan: u64 = 0,
    preferred_id: u32 = 0,
    report_connections: bool = true, warned: bool = false,
}

pub fn Gamepads.open(preferred_id: u32 = 0) -> Result[Gamepads, str]:
    SDL_SetHint("SDL_JOYSTICK_HIDAPI", "1")
    // SDL drives the Steam Controller's USB puck directly. When Steam Input
    // owns a controller, Steam tells SDL to ignore the physical device and
    // WIPE sees only Steam's virtual pad, so this never fights Steam.
    SDL_SetHint("SDL_JOYSTICK_HIDAPI_STEAM", "1")
    // SDL has no window; WIPE gates gameplay on raylib's window focus instead.
    SDL_SetHint("SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1")
    // SDL's SIGINT/SIGTERM handlers only queue SDL_EVENT_QUIT, and WIPE
    // reads no SDL events, so they swallowed the signal: Steam's "Exit game"
    // (SIGTERM) left the game running. The default action ends it; the save
    // is already on disk, written atomically on every change.
    SDL_SetHint("SDL_NO_SIGNAL_HANDLERS", "1")
    if not SDL_InitSubSystem(SDL_INIT_GAMEPAD): return Err(controller_error())
    SDL_SetGamepadEventsEnabled(false)
    SDL_SetJoystickEventsEnabled(false)
    Gamepads { ready: true, preferred_id }

impl Drop for Gamepads:
    fn drop(move self: Self):
        drop(self.seats)
        if self.ready: SDL_QuitSubSystem(SDL_INIT_GAMEPAD)

// A stick past half travel is a player's hand, not drift.
const ACTIVE_STICK = 0.5

fn stick_moved(pad: &Pad, x: SDL_GamepadAxis, y: SDL_GamepadAxis) -> bool:
    axis_unit(pad.axis(x)).abs() > ACTIVE_STICK or axis_unit(pad.axis(y)).abs() > ACTIVE_STICK

// A button went down or a stick was pushed since this controller was last read.
fn seat_used(seat: &Seat) -> bool:
    (held_mask(&seat.pad) & ~seat.held) != 0 or stick_moved(&seat.pad, SDL_GAMEPAD_AXIS_LEFTX, SDL_GAMEPAD_AXIS_LEFTY) or stick_moved(&seat.pad, SDL_GAMEPAD_AXIS_RIGHTX, SDL_GAMEPAD_AXIS_RIGHTY)

extend Gamepads:
    fn report_failure(mut self: Self):
        if not self.warned: eprint(f"WIPE controller access failed: {controller_error()}")
        self.warned = true

    fn holds(self: &Self, id: u32) -> bool:
        for seat in &self.seats:
            if seat.pad.id() == id: return true
        false

    fn discover(mut self: Self):
        let now = SDL_GetTicks()
        if now < self.next_scan: return
        self.next_scan = now + 500
        var count = 0
        // SDL returns exactly count IDs, owned by this scope and freed once.
        unsafe:
            let ids = SDL_GetGamepads(&raw mut count)
            if ids == null:
                self.report_failure()
                return
            defer: SDL_free(ids)
            for i in 0..count:
                let id = ids[i]
                if self.preferred_id != 0 and id != self.preferred_id: continue
                if self.holds(id): continue
                if let Some(found) = Pad.open(id):
                    let name = found.name().map(it.to_str_lossy()) ?? "Gamepad"
                    if self.report_connections: print(f"Controller connected: {name} (vendor {found.vendor()}, product {found.product()})")
                    // Connecting with A held must not automatically restart.
                    let south_held = found.button(SDL_GAMEPAD_BUTTON_SOUTH)
                    let held = held_mask(&found)
                    // A physical Valve controller, not Steam Input's virtual pad.
                    let valve = found.vendor() == VALVE_VENDOR and found.product() != STEAM_VIRTUAL_GAMEPAD
                    self.seats.push(Seat { pad: found, south_held, held, valve })
                    if self.active == 0: self.active = id
                    self.warned = false
                else:
                    self.report_failure()

    pub fn poll(mut self: Self) -> PadFrame:
        if not self.ready: return PadFrame {}
        SDL_UpdateGamepads()
        var removed = false
        var i = 0
        while i < self.seats.len():
            if self.seats[i].pad.connected():
                i += 1
                continue
            if self.report_connections: print("Controller disconnected")
            let gone = self.seats.remove(i)
            removed = true
            if gone.pad.id() == self.active: self.active = 0
            self.next_scan = 0
            self.warned = false
        if self.active == 0 and self.seats.len() > 0: self.active = self.seats[0].pad.id()
        // A disconnect's frame does not scan, so the next poll scans at once
        // (a controller that reconnects is picked up without waiting).
        if not removed: self.discover()
        self.hold_controller_mode()
        // Whichever controller was used this frame takes over the game.
        for seat in &self.seats:
            if seat_used(seat): self.active = seat.pad.id()
        // Edges are each controller's own, kept every frame, so the press
        // that takes over the game counts on the controller that made it.
        var frame = PadFrame {}
        for k in 0..self.seats.len():
            let seat = &self.seats[k]
            let south = seat.pad.button(SDL_GAMEPAD_BUTTON_SOUTH)
            let held_now = held_mask(&seat.pad)
            if seat.pad.id() == self.active:
                frame = PadFrame {
                    id: self.active,
                    motion: V2 { x: axis_unit(seat.pad.axis(SDL_GAMEPAD_AXIS_LEFTX)), y: axis_unit(seat.pad.axis(SDL_GAMEPAD_AXIS_LEFTY)) },
                    aim: V2 { x: axis_unit(seat.pad.axis(SDL_GAMEPAD_AXIS_RIGHTX)), y: axis_unit(seat.pad.axis(SDL_GAMEPAD_AXIS_RIGHTY)) },
                    south, retry: south and not seat.south_held,
                    held: held_now, pressed: held_now & ~seat.held,
                }
            self.seats[k].south_held = south
            self.seats[k].held = held_now
        frame

pub const VALVE_VENDOR: u16 = 0x28DE
// Steam Input's virtual gamepad. Seeing it means Steam owns the physical
// controller, hides it from SDL, and manages its lizard mode; lizard-mode
// reports go only to a physical Valve controller WIPE holds itself, whether
// or not Steam is running (a direct launch of the Steam build included).
pub const STEAM_VIRTUAL_GAMEPAD: u16 = 0x11FF

// A Steam Controller with no software claiming it runs in "lizard mode":
// its firmware moves the OS cursor and types arrow keys from the d-pad. SDL
// turns that off only every three seconds, and the firmware's watchdog
// turns it back on in between, so the cursor wanders toward the screen's hot
// corners and one d-pad press can arrive as a key and a button. While WIPE
// holds the controller it sends "lizard mode off" twice a second.
//
// The report is the driver's own: report 1, ID_SET_SETTINGS_VALUES (0x87),
// one three-byte setting, SETTING_LIZARD_MODE (9) = LIZARD_MODE_OFF (0).
const CONTROLLER_MODE_REPORT_BYTES = 64

extend Gamepads:
    fn hold_controller_mode(mut self: Self):
        let now = SDL_GetTicks()
        for k in 0..self.seats.len():
            if not self.seats[k].valve or now < self.seats[k].next_controller_mode: continue
            self.seats[k].next_controller_mode = now + 500
            var report = [0; 64]
            report[0] = 1
            report[1] = 0x87
            report[2] = 3
            report[3] = 9
            // The controller rejects nothing it can't parse; a non-Triton Valve
            // controller reports the effect unsupported, which is harmless.
            unsafe:
                let _ = SDL_SendGamepadEffect(self.seats[k].pad.repr, &raw const report[0] as *const u8, CONTROLLER_MODE_REPORT_BYTES)

fn held_mask(pad: &Pad) -> u32:
    var mask: u32 = 0
    if pad.button(SDL_GAMEPAD_BUTTON_SOUTH): mask |= BTN_SOUTH
    if pad.button(SDL_GAMEPAD_BUTTON_EAST): mask |= BTN_EAST
    if pad.button(SDL_GAMEPAD_BUTTON_WEST): mask |= BTN_WEST
    if pad.button(SDL_GAMEPAD_BUTTON_NORTH): mask |= BTN_NORTH
    if pad.button(SDL_GAMEPAD_BUTTON_LEFT_SHOULDER): mask |= BTN_LB
    if pad.button(SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER): mask |= BTN_RB
    if pad.button(SDL_GAMEPAD_BUTTON_START): mask |= BTN_START
    if pad.button(SDL_GAMEPAD_BUTTON_DPAD_UP): mask |= BTN_UP
    if pad.button(SDL_GAMEPAD_BUTTON_DPAD_DOWN): mask |= BTN_DOWN
    if pad.button(SDL_GAMEPAD_BUTTON_DPAD_LEFT): mask |= BTN_LEFT
    if pad.button(SDL_GAMEPAD_BUTTON_DPAD_RIGHT): mask |= BTN_RIGHT
    mask
