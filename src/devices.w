// Declare device owners before the resources that use them. With drops
// locals in reverse declaration order, including on an early return.
// A defer is unsuitable here: its order relative to local Drop is unspecified.
use c_import("raylib.h")

pub type WindowDevice {}
impl Drop for WindowDevice:
    move fn drop(): CloseWindow()

pub type AudioDevice {}
impl Drop for AudioDevice:
    move fn drop(): CloseAudioDevice()
