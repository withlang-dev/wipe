//! expect-stdout: UAT passed: resource dependencies close in order on every exit
use platform
use platform_session

var events: str = ""
var platform_open: bool = false
var window_open: bool = false
var audio_open: bool = false
var sound_live: bool = false
var renderer_live: bool = false

fn note(event: &str): events = events ++ event ++ " "

type TestPlatform {}
impl Platform for TestPlatform:
    fn frame(mut self: Self) -> PlatformFrame: PlatformFrame {}
    fn sync_achievements(mut self: Self, earned: &Vec[str]): ()
    fn notice(self: &Self) -> str: "test"
    fn manages_controllers(self: &Self) -> bool: false
    fn shutdown(mut self: Self):
        assert(platform_open and not window_open and not audio_open)
        assert(not sound_live and not renderer_live)
        platform_open = false
        note("shutdown")
impl Drop for TestPlatform:
    move fn drop():
        assert(not platform_open)
        note("backend")

fn close_window:
    assert(platform_open and window_open)
    assert(not audio_open and not renderer_live and not sound_live)
    window_open = false
    note("window")

type TestWindow {}
impl Drop for TestWindow:
    move fn drop(): close_window()

type TestAudio {}
impl Drop for TestAudio:
    move fn drop():
        assert(platform_open and window_open and audio_open)
        assert(not sound_live and not renderer_live)
        audio_open = false
        note("audio")

type TestSound {}
impl Drop for TestSound:
    move fn drop():
        assert(audio_open and sound_live)
        sound_live = false
        note("sound")

type TestRenderer {}
impl Drop for TestRenderer:
    move fn drop():
        assert(window_open and renderer_live)
        renderer_live = false
        note("renderer")

// Mirrors the entrypoints' acquisition order, including the real generic
// platform owner. Every partial initialization must unwind only live owners.
fn owned_resources(stop: i32):
    platform_open = true
    let session = PlatformSession { backend: TestPlatform {} }
    if stop == 0: return
    window_open = true
    let window = TestWindow {}
    if stop == 1: return
    audio_open = true
    let audio = TestAudio {}
    if stop == 2: return
    sound_live = true
    let sound = TestSound {}
    if stop == 3: return
    renderer_live = true
    let renderer = TestRenderer {}
    if stop == 4: return
    assert(session.backend.notice() == "test")
    note("body")

fn verify(expected: &str):
    if events != expected: eprint(f"cleanup events: [{events}], expected: [{expected}]")
    assert(events == expected)
    assert(not platform_open and not window_open and not audio_open)
    assert(not sound_live and not renderer_live)
    events = ""

fn main:
    owned_resources(0)
    verify("shutdown backend ")
    owned_resources(1)
    verify("window shutdown backend ")
    owned_resources(2)
    verify("audio window shutdown backend ")
    owned_resources(3)
    verify("sound audio window shutdown backend ")
    owned_resources(4)
    verify("renderer sound audio window shutdown backend ")
    owned_resources(5)
    verify("body renderer sound audio window shutdown backend ")
    print("UAT passed: resource dependencies close in order on every exit")
