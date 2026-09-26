use c_import("raylib.h")
use game
use gamepads

// Radial deadzone preserves analog magnitude without diagonal acceleration.
pub fn stick(x: f64, y: f64, deadzone: f64 = 0.2) -> V2:
    let v = V2 { x, y }
    let magnitude = sqrt(length2(v))
    if magnitude <= deadzone: V2 {} else: scale(direction(v), limit((magnitude - deadzone) / (1.0 - deadzone), 0.0, 1.0))

pub type Input { pad_aim: bool = false, last_mouse: V2 = V2 {}, deadzone: f64 = 0.2 }
extend Input:
    pub fn sample(mut self: Self, player: V2, previous_aim: V2, pad: PadFrame) -> Controls:
        if not IsWindowFocused(): return Controls { aim: previous_aim }
        var motion = V2 {}
        if IsKeyDown(KEY_W) or IsKeyDown(KEY_UP): motion.y -= 1.0
        if IsKeyDown(KEY_S) or IsKeyDown(KEY_DOWN): motion.y += 1.0
        if IsKeyDown(KEY_A) or IsKeyDown(KEY_LEFT): motion.x -= 1.0
        if IsKeyDown(KEY_D) or IsKeyDown(KEY_RIGHT): motion.x += 1.0
        let raw_mouse = GetMousePosition()
        let mouse = V2 { x: raw_mouse.x as f64, y: raw_mouse.y as f64 }
        self.resolve(motion, mouse, player, previous_aim, pad)

    // Pure input arbitration shared with acceptance tests. Real mouse movement
    // selects mouse aim; meaningful right-stick input takes priority this frame.
    pub fn resolve(mut self: Self, keyboard: V2, mouse: V2, player: V2, previous_aim: V2, pad: PadFrame) -> Controls:
        if length2(sub(mouse, self.last_mouse)) > 4.0: self.pad_aim = false
        self.last_mouse = mouse
        var aim = if self.pad_aim: previous_aim else: sub(mouse, player)
        var motion = keyboard
        if pad.id != 0:
            motion = add(motion, stick(pad.motion.x, pad.motion.y, self.deadzone))
            let right = stick(pad.aim.x, pad.aim.y, self.deadzone)
            if length2(right) > 0.0001:
                self.pad_aim = true
                aim = direction(right)
        Controls { motion, aim }

// One frame of menu input from every device: edges only, one value.
pub type MenuInput {
    confirm: bool = false, back: bool = false, shop: bool = false, collection: bool = false,
    lb: bool = false, rb: bool = false, start: bool = false, tab: bool = false,
    up: bool = false, down: bool = false, left: bool = false, right: bool = false,
    digit: i32 = 0, reroll: bool = false, skip: bool = false, banish: bool = false,
    click: bool = false, mouse: V2 = V2 {}, mouse_moved: bool = false,
    back_held: bool = false, any: bool = false,
}
impl Copy for MenuInput

// Stick flicks act as d-pad presses once per deflection.
pub type MenuState { stick_x: i32 = 0, stick_y: i32 = 0, last_mouse: V2 = V2 {} }
extend MenuState:
    pub fn sample(mut self: Self, pad: PadFrame) -> MenuInput:
        var m = MenuInput {}
        if not IsWindowFocused(): return m
        m.confirm = IsKeyPressed(KEY_SPACE) or IsKeyPressed(KEY_ENTER) or pad.down(BTN_SOUTH)
        m.back = IsKeyPressed(KEY_ESCAPE) or pad.down(BTN_EAST)
        m.back_held = IsKeyDown(KEY_ESCAPE) or (pad.held & BTN_EAST) != 0
        m.shop = IsKeyPressed(KEY_X) or pad.down(BTN_WEST)
        m.collection = IsKeyPressed(KEY_C) or pad.down(BTN_NORTH)
        m.lb = IsKeyPressed(KEY_Q) or pad.down(BTN_LB)
        m.rb = IsKeyPressed(KEY_E) or pad.down(BTN_RB)
        m.start = IsKeyPressed(KEY_ESCAPE) or pad.down(BTN_START)
        m.tab = IsKeyPressed(KEY_TAB) or pad.down(BTN_RB)
        m.reroll = IsKeyPressed(KEY_R) or pad.down(BTN_WEST)
        m.skip = IsKeyPressed(KEY_S) or pad.down(BTN_NORTH)
        m.banish = IsKeyPressed(KEY_N) or pad.down(BTN_LB)
        m.up = IsKeyPressed(KEY_UP) or IsKeyPressed(KEY_W) or pad.down(BTN_UP)
        m.down = IsKeyPressed(KEY_DOWN) or IsKeyPressed(KEY_S) or pad.down(BTN_DOWN)
        m.left = IsKeyPressed(KEY_LEFT) or IsKeyPressed(KEY_A) or pad.down(BTN_LEFT)
        m.right = IsKeyPressed(KEY_RIGHT) or IsKeyPressed(KEY_D) or pad.down(BTN_RIGHT)
        // The left stick flicks once per deflection.
        let sx = if pad.motion.x > 0.6: 1 else if pad.motion.x < -0.6: -1 else: 0
        let sy = if pad.motion.y > 0.6: 1 else if pad.motion.y < -0.6: -1 else: 0
        if sx != self.stick_x:
            if sx > 0: m.right = true
            if sx < 0: m.left = true
        if sy != self.stick_y:
            if sy > 0: m.down = true
            if sy < 0: m.up = true
        self.stick_x = sx
        self.stick_y = sy
        if IsKeyPressed(KEY_ONE): m.digit = 1
        if IsKeyPressed(KEY_TWO): m.digit = 2
        if IsKeyPressed(KEY_THREE): m.digit = 3
        if IsKeyPressed(KEY_FOUR): m.digit = 4
        let raw = GetMousePosition()
        m.mouse = V2 { x: raw.x as f64, y: raw.y as f64 }
        m.mouse_moved = length2(sub(m.mouse, self.last_mouse)) > 1.0
        self.last_mouse = m.mouse
        m.click = IsMouseButtonPressed(MOUSE_BUTTON_LEFT)
        m.any = m.confirm or m.back or m.shop or m.collection or m.click or m.start or GetKeyPressed() != 0
        m
