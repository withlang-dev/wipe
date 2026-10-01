// What the game asks of a store platform, and nothing more. The plain build
// runs with NoPlatform; the Steam build (src/main_steam.w) with
// SteamPlatform. Every feature here has a platform-neutral owner in the game:
// achievements are facts of the save, the pause is the game's own.
pub type PlatformFrame {
    // The store's overlay opened this frame (Shift+Tab, the Deck's Steam
    // button): a run in progress pauses.
    overlay_opened: bool = false,
    overlay_active: bool = false,
    overlay_closed: bool = false,
}
impl Copy for PlatformFrame

extend PlatformFrame:
    pub fn blocks_input(self: &Self) -> bool:
        self.overlay_active or self.overlay_opened or self.overlay_closed

pub trait Platform:
    // Once per frame: the platform's own event pump.
    fn frame(mut self: Self) -> PlatformFrame
    // Every achievement the save has earned; the platform mirrors any it
    // does not have yet. Called about once a second, so it must be cheap
    // when nothing changed.
    fn sync_achievements(mut self: Self, earned: &Vec[str])
    // A line for the title screen, once: "" when there is nothing to say.
    fn notice(self: &Self) -> str
    // True when the platform owns physical controllers and exposes its
    // virtual gamepad, including a direct development launch.
    fn manages_controllers(self: &Self) -> bool
    // At exit, after the last frame.
    fn shutdown(mut self: Self)

pub type NoPlatform {}

impl Platform for NoPlatform:
    fn frame(mut self: Self) -> PlatformFrame: PlatformFrame {}
    fn sync_achievements(mut self: Self, earned: &Vec[str]): ()
    fn notice(self: &Self) -> str: ""
    fn manages_controllers(self: &Self) -> bool: false
    fn shutdown(mut self: Self): ()
