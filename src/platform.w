// What the game asks of a platform, and nothing more. The plain path runs
// with NoPlatform (tools, tests); the game with SteamPlatform, which falls
// back to this behavior when Steam isn't running. A console is another
// implementor. Every feature here has a platform-neutral owner in the game:
// achievements are facts of the save, the pause is the game's own, and
// controllers speak the game's actions (src/controls.w).
use controls

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
    // The controller in the player's hands, through the platform's own
    // input API, in the game's actions: Some while it has one, None when the
    // game should read SDL. `menu` says which actions the screen can use:
    // the menus' (confirm, back, navigation) or flight's (move, aim, pause).
    fn controller(mut self: Self, menu: bool) -> Option[ActionFrame]
    // The name of the control bound to each prompt, in input.w's Action
    // order (ACTION_COUNT entries), for the controller in use: "A", "Left
    // Stick", in Steam's language. Empty when the platform binds nothing.
    fn prompts(self: &Self) -> List[str]
    // Every achievement the save has earned; the platform mirrors any it
    // does not have yet. Called about once a second, so it must be cheap
    // when nothing changed.
    fn sync_achievements(mut self: Self, earned: &List[str])
    // A line for the title screen, once: "" when there is nothing to say.
    fn notice(self: &Self) -> str
    // At exit, after the last frame.
    fn shutdown(mut self: Self)

pub type NoPlatform {}

impl Platform for NoPlatform:
    fn frame(mut self: Self) -> PlatformFrame: PlatformFrame {}
    fn controller(mut self: Self, menu: bool) -> Option[ActionFrame]: None
    fn prompts(self: &Self) -> List[str]: List.new()
    fn sync_achievements(mut self: Self, earned: &List[str]): ()
    fn notice(self: &Self) -> str: ""
    fn shutdown(mut self: Self): ()
