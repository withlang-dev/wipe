// What a controller says, in the game's own actions. Every controller path
// produces this one frame: SDL's mapping (src/gamepads.w), Steam Input
// (src/steam.w), and a console's pad API; the game reads actions and never a
// button. A port adds a producer, not a change to the game.
use game

// Action bits, shared by the held and pressed masks. Menu actions (confirm,
// back, shop...) and flight actions (pause) share the mask: the producer
// knows which screen is up and fills the actions that screen can use.
pub const ACT_CONFIRM: u32 = 1
pub const ACT_BACK: u32 = 2
pub const ACT_SHOP: u32 = 4
pub const ACT_COLLECTION: u32 = 8
pub const ACT_TAB_LEFT: u32 = 16
pub const ACT_TAB_RIGHT: u32 = 32
pub const ACT_PAUSE: u32 = 64
pub const ACT_UP: u32 = 128
pub const ACT_DOWN: u32 = 256
pub const ACT_LEFT: u32 = 512
pub const ACT_RIGHT: u32 = 1024
pub const ACT_REROLL: u32 = 2048
pub const ACT_SKIP: u32 = 4096
pub const ACT_BANISH: u32 = 8192
pub const ACT_NEXT: u32 = 16384

pub type ActionFrame {
    // Nonzero while a controller is connected; which one is the producer's.
    id: u64 = 0,
    // Flight: the ship's motion and aim. Menus: motion flicks the cursor.
    motion: V2 = V2 {}, aim: V2 = V2 {},
    // Every action held this frame, and those that went down this frame.
    held: u32 = 0, pressed: u32 = 0,
} with Copy

extend ActionFrame:
    pub fn down(self: &Self, bit: u32) -> bool: (self.pressed & bit) != 0
    pub fn holding(self: &Self, bit: u32) -> bool: (self.held & bit) != 0
