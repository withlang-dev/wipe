//! expect-stdout: UAT passed: SDL mapping, retry edges, held-button connect, disconnect, reconnect
// Process-local SDL fixtures exercise real mapping and device lifetimes without
// impersonating a system device or depending on attached physical controllers.
use sdl
use c_import("SDL3/SDL.h")
use gamepads
use std.mem.{alloc_zeroed, free_mem}

const DESC_BYTES: i32 = comptime SDL_VirtualJoystickDesc.size() as i32

fn attach() -> u32:
    // SDL requires zeroed storage (including optional C callback pointers).
    let storage = alloc_zeroed(1, DESC_BYTES)
    assert(storage != null)
    defer: free_mem(storage)
    let desc = storage as *mut SDL_VirtualJoystickDesc
    unsafe:
        desc.version = DESC_BYTES as u32
        desc.type_ = SDL_JOYSTICK_TYPE_GAMEPAD as u16
        desc.vendor_id = 0x1234
        desc.product_id = 1
        desc.naxes = 6
        desc.nbuttons = 15
        desc.axis_mask = 63
        desc.button_mask = 32767
        desc.name = c"WIPE acceptance controller".ptr
        let id = SDL_AttachVirtualJoystick(desc)
        assert(id != 0)
        id

fn main:
    var pads = Gamepads.open().unwrap()
    pads.report_connections = false
    let first = attach()
    pads.preferred_id = first
    unsafe:
        let joystick = SDL_OpenJoystick(first)
        assert(joystick != null)
        defer: SDL_CloseJoystick(joystick)
        assert(SDL_SetJoystickVirtualAxis(joystick, 0, 32767))
        assert(SDL_SetJoystickVirtualAxis(joystick, 3, -32768))
        assert(SDL_SetJoystickVirtualButton(joystick, 0, true))
        let connected = pads.poll()
        assert(connected.id == first)
        assert(connected.motion.x == 1.0 and connected.aim.y == -1.0)
        assert(connected.south and not connected.retry)
        assert(SDL_SetJoystickVirtualButton(joystick, 0, false))
        let released = pads.poll()
        assert(not released.south and not released.retry)
        assert(SDL_SetJoystickVirtualButton(joystick, 0, true))
        assert(pads.poll().retry)
        assert(not pads.poll().retry)
        assert(SDL_DetachVirtualJoystick(first))
        let gone = pads.poll()
        assert(gone.id == 0 and not gone.retry and not gone.south)
        assert(gone.motion.x == 0.0 and gone.aim.y == 0.0)
    let second = attach()
    defer: assert(SDL_DetachVirtualJoystick(second))
    assert(second != first)
    pads.preferred_id = second
    assert(pads.poll().id == second)
    print("UAT passed: SDL mapping, retry edges, held-button connect, disconnect, reconnect")
