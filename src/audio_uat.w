// Verify real streaming, loop wrap, and independence from run resets.
use c_import("raylib.h")
use audio
use game

fn main:
    SetTraceLogLevel(LOG_WARNING)
    InitWindow(480, 160, "WIPE audio acceptance")
    defer: CloseWindow()
    if not IsWindowReady(): return 1
    InitAudioDevice()
    defer: CloseAudioDevice()
    if not IsAudioDeviceReady():
        eprint("Audio UAT requires an output device.")
        return 1
    let bank = Audio.open()
    assert(bank.valid())
    let duration = GetMusicTimeLength(bank.music.repr)
    assert(duration > 34.0 and duration < 36.0)
    assert(bank.music.repr.looping)
    SeekMusicStream(bank.music.repr, duration - 0.8)
    SetTargetFPS(60)
    var g = Game.new()
    var before_retry = 0.0
    var after_retry = 0.0
    for frame in 0..180:
        if frame == 15:
            before_retry = GetMusicTimePlayed(bank.music.repr) as f64
            g.reset()
            after_retry = GetMusicTimePlayed(bank.music.repr) as f64
        bank.play(g, GetTime())
        BeginDrawing()
        ClearBackground(Color { r: 3, g: 4, b: 14, a: 255 })
        DrawText("AUDIO ACCEPTANCE", 24, 28, 22, RAYWHITE)
        DrawText("Streaming / seamless loop / retry continuity", 24, 76, 16, SKYBLUE)
        EndDrawing()
    assert(IsMusicStreamPlaying(bank.music.repr))
    let position = GetMusicTimePlayed(bank.music.repr)
    assert(position > 0.5 and position < 4.0)
    assert(after_retry >= before_retry and after_retry - before_retry < 0.1)
    print(f"Audio UAT passed: valid assets; {duration}s loop wrapped to {position}s; retry preserved music position.")
    0
