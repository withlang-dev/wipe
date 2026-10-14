// The input layer: pure arbitration between the keyboard (Keys), a
// controller (ActionFrame) and the mouse, with no window system in it.
use game
use controls

// Prompts are selected once from the last meaningful input, across every
// screen. MENU is the Deck/Steam virtual pad label and is clear on other pads.
pub enum Device { | Keyboard | Pad }
impl Copy for Device
impl Eq for Device
pub enum Action { | Confirm | Back | Shop | Collection | Pause | Resume | Quit | Toggle | Tabs | Next | Reroll | Skip | Banish | Move | Aim }
impl Copy for Action
// The prompts' order, for a platform's table of bound control names.
pub const ACTION_COUNT: i32 = 15
pub fn action_index(action: Action) -> i32:
    match action:
        .Confirm => 0
        .Back => 1
        .Shop => 2
        .Collection => 3
        .Pause => 4
        .Resume => 5
        .Quit => 6
        .Toggle => 7
        .Tabs => 8
        .Next => 9
        .Reroll => 10
        .Skip => 11
        .Banish => 12
        .Move => 13
        .Aim => 14

// The prompt for an action on the device in use. A platform that binds
// actions itself (Steam Input, a console) names the bound control; the
// table below is the plain SDL layout, and the keyboard's.
pub type Prompts { device: Device = .Keyboard, bound: List[str] = List.new() }
extend Prompts:
    pub fn clone(self: &Self) -> Prompts: Prompts { device: self.device, bound: self.bound.clone() }

    pub fn get(self: &Self, action: Action) -> str:
        if self.device == .Pad and self.bound.len() as i32 == ACTION_COUNT:
            let text = &self.bound[action_index(action)]
            if text.len() > 0: return text.clone()
        prompt(self.device, action)

pub fn prompt(device: Device, action: Action) -> str:
    if device == .Pad:
        match action:
            .Confirm => "A"
            .Back => "B"
            .Shop => "X"
            .Collection => "Y"
            .Pause => "MENU"
            .Resume => "B / MENU"
            .Quit => "HOLD B"
            .Toggle => "D-PAD UP / DOWN"
            .Tabs => "LB / RB"
            .Next => "RB"
            .Reroll => "X"
            .Skip => "Y"
            .Banish => "LB"
            .Move => "LEFT STICK"
            .Aim => "RIGHT STICK"
    else:
        match action:
            .Confirm => "SPACE"
            .Back => "ESC"
            .Shop => "X"
            .Collection => "C"
            .Pause => "ESC"
            .Resume => "SPACE ON RESUME"
            .Quit => "ESC / Q"
            .Toggle => "UP / DOWN"
            .Tabs => "Q / E"
            .Next => "TAB"
            .Reroll => "R"
            .Skip => "K"
            .Banish => "N"
            .Move => "WASD"
            .Aim => "MOUSE"

// Drift cannot change prompts. A pad wins simultaneous emulated key/mouse
// events; a genuine later keyboard press or mouse movement takes over.
pub fn active_device(previous: Device, keyboard: bool, mouse_moved: bool, pad: ActionFrame, deadzone: f64) -> Device:
    if pad.id != 0 and (pad.pressed != 0 or length2(pad.motion) > deadzone * deadzone or length2(pad.aim) > deadzone * deadzone): return .Pad
    if keyboard or mouse_moved: return .Keyboard
    previous

// Radial deadzone preserves analog magnitude without diagonal acceleration.
pub fn stick(x: f64, y: f64, deadzone: f64 = 0.2) -> V2:
    let v = V2 { x, y }
    let magnitude = sqrt(length2(v))
    if magnitude <= deadzone: V2 {} else: scale(direction(v), limit((magnitude - deadzone) / (1.0 - deadzone), 0.0, 1.0))

pub type Input { pad_aim: bool = false, last_mouse: V2 = V2 {}, deadzone: f64 = 0.2 }
extend Input:
    pub fn sample(mut self: Self, keys: Keys, player: V2, previous_aim: V2, pad: ActionFrame) -> Controls:
        if not keys.focused: return Controls { aim: previous_aim }
        var motion = V2 {}
        if keys.move_up: motion.y -= 1.0
        if keys.move_down: motion.y += 1.0
        if keys.move_left: motion.x -= 1.0
        if keys.move_right: motion.x += 1.0
        self.resolve(motion, keys.mouse, player, previous_aim, pad)

    // Pure input arbitration shared with acceptance tests. Real mouse movement
    // selects mouse aim; meaningful right-stick input takes priority this frame.
    pub fn resolve(mut self: Self, keyboard: V2, mouse: V2, player: V2, previous_aim: V2, pad: ActionFrame) -> Controls:
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
    // Escape itself, for the title's quit, and the debug toggle.
    escape: bool = false, escape_held: bool = false, debug: bool = false,
    // The Q key itself: quit from the title, leave a run from pause.
    q: bool = false,
}
impl Copy for MenuInput

// Stick flicks act as d-pad presses once per deflection. A direction that
// arrives from two devices within a few frames (a d-pad press echoed as an
// arrow key) counts once.
pub type MenuState {
    stick_x: i32 = 0, stick_y: i32 = 0, last_mouse: V2 = V2 {},
    frame: i32 = 0, device: Device = .Keyboard, mouse_seen: bool = false,
    // Frame of the last press per direction, per source: 0 keys, 1 pad.
    last_up: [i32; 2] = [-100; 2], last_down: [i32; 2] = [-100; 2],
    last_left: [i32; 2] = [-100; 2], last_right: [i32; 2] = [-100; 2],
}

const ECHO_FRAMES = 8

pub fn one_press(seen: [i32; 2], key: bool, pad: bool, frame: i32) -> ([i32; 2], bool):
    var marks = seen
    var fired = false
    if key:
        if frame - marks[1] > ECHO_FRAMES: fired = true
        marks[0] = frame
    if pad:
        if frame - marks[0] > ECHO_FRAMES or key: fired = true
        marks[1] = frame
    (marks, fired)
extend MenuState:
    pub fn sample(mut self: Self, keys: Keys, pad: ActionFrame, deadzone: f64 = 0.2) -> MenuInput:
        var m = MenuInput {}
        if not keys.focused: return m
        m.confirm = keys.confirm or pad.down(ACT_CONFIRM)
        m.back = keys.escape or pad.down(ACT_BACK)
        m.back_held = keys.escape_held or pad.holding(ACT_BACK)
        m.shop = keys.x or pad.down(ACT_SHOP)
        m.collection = keys.c or pad.down(ACT_COLLECTION)
        m.lb = keys.q or pad.down(ACT_TAB_LEFT)
        m.rb = keys.e or pad.down(ACT_TAB_RIGHT)
        m.start = keys.escape or pad.down(ACT_PAUSE)
        m.tab = keys.tab or pad.down(ACT_NEXT)
        m.reroll = keys.r or pad.down(ACT_REROLL)
        // Not S: S is a movement key, and a level-up can open mid-stride.
        m.skip = keys.k or pad.down(ACT_SKIP)
        m.banish = keys.n or pad.down(ACT_BANISH)
        self.frame += 1
        let (up_marks, up) = one_press(self.last_up, keys.up, pad.down(ACT_UP), self.frame)
        let (down_marks, down) = one_press(self.last_down, keys.down, pad.down(ACT_DOWN), self.frame)
        let (left_marks, left) = one_press(self.last_left, keys.left, pad.down(ACT_LEFT), self.frame)
        let (right_marks, right) = one_press(self.last_right, keys.right, pad.down(ACT_RIGHT), self.frame)
        self.last_up = up_marks
        self.last_down = down_marks
        self.last_left = left_marks
        self.last_right = right_marks
        m.up = up
        m.down = down
        m.left = left
        m.right = right
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
        m.digit = keys.digit
        m.mouse = keys.mouse
        m.mouse_moved = self.mouse_seen and length2(keys.mouse_delta) > 4.0
        self.mouse_seen = true
        self.last_mouse = m.mouse
        m.click = keys.click
        m.escape = keys.escape
        m.q = keys.q
        m.escape_held = keys.escape_held
        m.debug = keys.f1
        let key_pressed = keys.any_key
        m.any = m.confirm or m.back or m.shop or m.collection or m.click or m.start or key_pressed
        self.device = active_device(self.device, key_pressed or m.click, m.mouse_moved, pad, deadzone)
        m
