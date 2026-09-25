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
