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

// A single main-thread owner retains its selected controller until disconnect.
// Discovery allocates only while disconnected, at most twice per second.
pub type Gamepads {
    pad: Option[Pad] = None, ready: bool = false, next_scan: u64 = 0,
    preferred_id: u32 = 0, south_held: bool = false, held: u32 = 0,
    report_connections: bool = true, warned: bool = false,
}

pub fn Gamepads.open(preferred_id: u32 = 0) -> Result[Gamepads, str]:
    SDL_SetHint("SDL_JOYSTICK_HIDAPI", "1")
    SDL_SetHint("SDL_JOYSTICK_HIDAPI_STEAM", "1")
    // SDL has no window; WIPE gates gameplay on raylib's window focus instead.
    SDL_SetHint("SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1")
    if not SDL_InitSubSystem(SDL_INIT_GAMEPAD): return Err(controller_error())
    SDL_SetGamepadEventsEnabled(false)
    SDL_SetJoystickEventsEnabled(false)
    Gamepads { ready: true, preferred_id }

impl Drop for Gamepads:
    fn drop(move self: Self):
        drop(self.pad)
        if self.ready: SDL_QuitSubSystem(SDL_INIT_GAMEPAD)

extend Gamepads:
    fn report_failure(mut self: Self):
        if not self.warned: eprint(f"WIPE controller access failed: {controller_error()}")
        self.warned = true

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
                let id: u32 = ids[i]
                if self.preferred_id != 0 and id != self.preferred_id: continue
                if let Some(pad) = Pad.open(id):
                    let name = pad.name().map(it.to_str_lossy()) ?? "Gamepad"
                    if self.report_connections: print(f"Controller connected: {name} (vendor {pad.vendor()}, product {pad.product()})")
                    // Connecting with A held must not automatically restart.
                    self.south_held = pad.button(SDL_GAMEPAD_BUTTON_SOUTH)
                    self.held = held_mask(&pad)
                    self.pad = Some(pad)
                    self.warned = false
                    return
                self.report_failure()

    pub fn poll(mut self: Self) -> PadFrame:
        if not self.ready: return PadFrame {}
        SDL_UpdateGamepads()
        let disconnected = match &self.pad:
            Some(pad) => not pad.connected()
            None => false
        if disconnected:
            if self.report_connections: print("Controller disconnected")
            self.pad = None
            self.south_held = false
            self.held = 0
            self.next_scan = 0
            self.warned = false
            return PadFrame {}
        if self.pad.is_none(): self.discover()
        let Some(pad) = &self.pad else return PadFrame {}
        let south = pad.button(SDL_GAMEPAD_BUTTON_SOUTH)
        let held = held_mask(pad)
        let frame = PadFrame {
            id: pad.id(),
            motion: V2 { x: axis_unit(pad.axis(SDL_GAMEPAD_AXIS_LEFTX)), y: axis_unit(pad.axis(SDL_GAMEPAD_AXIS_LEFTY)) },
            aim: V2 { x: axis_unit(pad.axis(SDL_GAMEPAD_AXIS_RIGHTX)), y: axis_unit(pad.axis(SDL_GAMEPAD_AXIS_RIGHTY)) },
            south, retry: south and not self.south_held,
            held, pressed: held & ~self.held,
        }
        self.south_held = south
        self.held = held
        frame

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
