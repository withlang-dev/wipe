use platform

// Own the platform before graphics/audio owners so shutdown is last on every
// exit path, without relying on defer ordering relative to resource drops.
pub type PlatformSession[P] { backend: P }
impl[P: Platform] Drop for PlatformSession[P]:
    move fn drop(): self.backend.shutdown()
