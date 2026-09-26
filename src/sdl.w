// Shared SDL declarations and ownership facade. Keep one selective import:
// the compiler deduplicates C declarations before filtering later imports.
// Virtual-device calls are used only by the controller acceptance tests.
use c_import("SDL3/SDL.h", only: [
    "SDL_InitSubSystem", "SDL_QuitSubSystem", "SDL_INIT_GAMEPAD",
    "SDL_SetHint", "SDL_GetError", "SDL_GetTicks",
    "SDL_GetGamepads", "SDL_free", "SDL_Gamepad",
    "SDL_OpenGamepad", "SDL_CloseGamepad", "SDL_GamepadConnected",
    "SDL_GetGamepadID", "SDL_GetGamepadName", "SDL_GetGamepadVendor",
    "SDL_GetGamepadProduct", "SDL_GetGamepadAxis", "SDL_GetGamepadButton",
    "SDL_UpdateGamepads", "SDL_SetGamepadEventsEnabled", "SDL_SetJoystickEventsEnabled",
    "SDL_GAMEPAD_AXIS_LEFTX", "SDL_GAMEPAD_AXIS_LEFTY", "SDL_GAMEPAD_AXIS_RIGHTX",
    "SDL_GAMEPAD_AXIS_RIGHTY", "SDL_GAMEPAD_BUTTON_SOUTH", "SDL_GAMEPAD_BUTTON_EAST",
    "SDL_GAMEPAD_BUTTON_WEST", "SDL_GAMEPAD_BUTTON_NORTH", "SDL_GAMEPAD_BUTTON_LEFT_SHOULDER",
    "SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER", "SDL_GAMEPAD_BUTTON_START", "SDL_GAMEPAD_BUTTON_DPAD_UP",
    "SDL_GAMEPAD_BUTTON_DPAD_DOWN", "SDL_GAMEPAD_BUTTON_DPAD_LEFT", "SDL_GAMEPAD_BUTTON_DPAD_RIGHT", "SDL_Joystick",
    "SDL_VirtualJoystickDesc", "SDL_VirtualJoystickSensorDesc", "SDL_VirtualJoystickTouchpadDesc",
    "SDL_JOYSTICK_TYPE_GAMEPAD", "SDL_AttachVirtualJoystick", "SDL_DetachVirtualJoystick",
    "SDL_OpenJoystick", "SDL_CloseJoystick", "SDL_SetJoystickVirtualAxis",
    "SDL_SetJoystickVirtualButton",
])
c facade controllers:
    resource Pad wraps *mut SDL_Gamepad
        from SDL_OpenGamepad
        drop SDL_CloseGamepad
    fn SDL_OpenGamepad
        of Pad
        rename open
    fn SDL_GamepadConnected
        of Pad
        rename connected
        lend
    fn SDL_GetGamepadID
        of Pad
        rename id
        lend
    fn SDL_GetGamepadAxis
        of Pad
        rename axis
        lend
    fn SDL_GetGamepadButton
        of Pad
        rename button
        lend
    fn SDL_GetGamepadVendor
        of Pad
        rename vendor
        lend
    fn SDL_GetGamepadProduct
        of Pad
        rename product
        lend
    fn SDL_GetGamepadName
        of Pad
        rename name
        returns borrow CStr from param 0
    domain errors thread
    fn SDL_GetError
        returns borrow CStr from domain errors
    fn SDL_SetHint
        lend

