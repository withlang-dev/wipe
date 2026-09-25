use c_import("raylib.h")
use game
use paths

// Each clip owns exactly one raylib sound buffer. These operations borrow
// the token; they neither retain nor destroy the owner's sound resource.
// The compiler does not yet project methods for by-value resource tokens,
// so callers pass `.repr` to the raylib functions directly.
c facade sounds:
    resource Track wraps Music
        from LoadMusicStream
        drop UnloadMusicStream
    fn LoadMusicStream
        of Track
        rename open
    fn PlayMusicStream
        lend
    fn UpdateMusicStream
        lend
    fn SetMusicVolume
        lend
    fn IsMusicValid
        lend
    resource Clip wraps Sound
        from LoadSound
        drop UnloadSound
    fn LoadSound
        of Clip
        rename load
    fn PlaySound
        of Clip
        rename play
        lend
    fn SetSoundVolume
        of Clip
        rename volume
        lend
    fn SetSoundPitch
        of Clip
        rename pitch
        lend
    fn IsSoundValid
        of Clip
        rename valid
        lend

pub type Audio {
    shot: Clip, hit: Clip, kill: Clip, hurt: Clip, death: Clip,
    music: Track,
}
pub fn Audio.open() -> Audio:
    let bank = Audio {
        music: Track.open(asset_path("audio/ambient_house.wav")),
        shot: Clip.load(asset_path("audio/shot.wav")),
        hit: Clip.load(asset_path("audio/hit.wav")),
        kill: Clip.load(asset_path("audio/kill.wav")),
        hurt: Clip.load(asset_path("audio/hurt.wav")),
        death: Clip.load(asset_path("audio/death.wav")),
    }
    SetMusicVolume(bank.music.repr, 0.32)
    PlayMusicStream(bank.music.repr)
    SetSoundVolume(bank.shot.repr, 0.20)
    SetSoundVolume(bank.hit.repr, 0.24)
    SetSoundVolume(bank.kill.repr, 0.35)
    SetSoundVolume(bank.hurt.repr, 0.55)
    SetSoundVolume(bank.death.repr, 0.65)
    bank

extend Audio:
    pub fn valid(self: &Self) -> bool:
        IsMusicValid(self.music.repr) and IsSoundValid(self.shot.repr) and IsSoundValid(self.hit.repr) and IsSoundValid(self.kill.repr) and IsSoundValid(self.hurt.repr) and IsSoundValid(self.death.repr)

    pub fn play(self: &Self, g: &Game, clock: f64) -> Unit:
        UpdateMusicStream(self.music.repr)
        // Presentation variation never consumes the simulation's RNG.
        if g.shot_event:
            SetSoundPitch(self.shot.repr, (0.96 + (sin(clock * 73.0) + 1.0) * 0.04) as f32)
            PlaySound(self.shot.repr)
        if g.hit_event and not g.kill_event: PlaySound(self.hit.repr)
        if g.kill_event:
            SetSoundPitch(self.kill.repr, (0.9 + (sin(clock * 57.0) + 1.0) * 0.1) as f32)
            PlaySound(self.kill.repr)
        if g.hurt_event and not g.death_event: PlaySound(self.hurt.repr)
        if g.death_event: PlaySound(self.death.repr)
