// The keyboard and mouse, read from raylib once per frame into the game's
// own Keys. Nothing else in the input layer touches the window system.
use c_import("raylib.h")
use game
use controls

pub fn sample_keys() -> Keys:
    if not IsWindowFocused(): return Keys { focused: false }
    let mouse = GetMousePosition()
    let delta = GetMouseDelta()
    var digit = 0
    if IsKeyPressed(KEY_ONE): digit = 1
    if IsKeyPressed(KEY_TWO): digit = 2
    if IsKeyPressed(KEY_THREE): digit = 3
    if IsKeyPressed(KEY_FOUR): digit = 4
    Keys {
        move_up: IsKeyDown(KEY_W) or IsKeyDown(KEY_UP),
        move_down: IsKeyDown(KEY_S) or IsKeyDown(KEY_DOWN),
        move_left: IsKeyDown(KEY_A) or IsKeyDown(KEY_LEFT),
        move_right: IsKeyDown(KEY_D) or IsKeyDown(KEY_RIGHT),
        confirm: IsKeyPressed(KEY_SPACE) or IsKeyPressed(KEY_ENTER),
        escape: IsKeyPressed(KEY_ESCAPE), escape_held: IsKeyDown(KEY_ESCAPE),
        x: IsKeyPressed(KEY_X), c: IsKeyPressed(KEY_C), q: IsKeyPressed(KEY_Q), e: IsKeyPressed(KEY_E),
        tab: IsKeyPressed(KEY_TAB), r: IsKeyPressed(KEY_R), k: IsKeyPressed(KEY_K), n: IsKeyPressed(KEY_N),
        f1: IsKeyPressed(KEY_F1),
        up: IsKeyPressed(KEY_UP) or IsKeyPressed(KEY_W),
        down: IsKeyPressed(KEY_DOWN) or IsKeyPressed(KEY_S),
        left: IsKeyPressed(KEY_LEFT) or IsKeyPressed(KEY_A),
        right: IsKeyPressed(KEY_RIGHT) or IsKeyPressed(KEY_D),
        digit, any_key: GetKeyPressed() != 0,
        mouse: V2 { x: mouse.x as f64, y: mouse.y as f64 },
        mouse_delta: V2 { x: delta.x as f64, y: delta.y as f64 },
        click: IsMouseButtonPressed(MOUSE_BUTTON_LEFT),
    }
