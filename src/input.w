use c_import("raylib.h")
use game

// Radial deadzone preserves analog magnitude without diagonal acceleration.
pub fn stick(x: f64, y: f64, deadzone: f64 = 0.2) -> V2:
    let v = V2 { x, y }
    let magnitude = sqrt(length2(v))
    if magnitude <= deadzone: V2 {} else: scale(direction(v), limit((magnitude - deadzone) / (1.0 - deadzone), 0.0, 1.0))

pub fn active_pad() -> i32:
    for index in 0..4:
        if IsGamepadAvailable(index): return index
    -1

pub type Input { pad_aim: bool = false, last_mouse: V2 = V2 {}, deadzone: f64 = 0.2 }
extend Input:
    pub fn sample(mut self: Self, player: V2, previous_aim: V2) -> Controls:
        var motion = V2 {}
        if IsKeyDown(KEY_W) or IsKeyDown(KEY_UP): motion.y -= 1.0
        if IsKeyDown(KEY_S) or IsKeyDown(KEY_DOWN): motion.y += 1.0
        if IsKeyDown(KEY_A) or IsKeyDown(KEY_LEFT): motion.x -= 1.0
        if IsKeyDown(KEY_D) or IsKeyDown(KEY_RIGHT): motion.x += 1.0
        let raw_mouse = GetMousePosition()
        let mouse = V2 { x: raw_mouse.x as f64, y: raw_mouse.y as f64 }
        if length2(sub(mouse, self.last_mouse)) > 4.0: self.pad_aim = false
        self.last_mouse = mouse
        var aim = if self.pad_aim: previous_aim else: sub(mouse, player)
        let pad = active_pad()
        if pad >= 0:
            motion = add(motion, stick(GetGamepadAxisMovement(pad, GAMEPAD_AXIS_LEFT_X) as f64, GetGamepadAxisMovement(pad, GAMEPAD_AXIS_LEFT_Y) as f64, self.deadzone))
            let right = stick(GetGamepadAxisMovement(pad, GAMEPAD_AXIS_RIGHT_X) as f64, GetGamepadAxisMovement(pad, GAMEPAD_AXIS_RIGHT_Y) as f64, self.deadzone)
            if length2(right) > 0.0001:
                self.pad_aim = true
                aim = direction(right)
        Controls { motion, aim }
