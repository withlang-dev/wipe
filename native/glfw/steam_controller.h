// WIPE extension to GLFW 3.4. Original implementation, zlib license.
// Wire-format facts: Valve's controller_structs.h and SDL's Triton driver.
// USB 28de:1302 only; no SDL code or runtime is included.
#ifndef WIPE_GLFW_STEAM_CONTROLLER_H
#define WIPE_GLFW_STEAM_CONTROLLER_H

#include <stddef.h>
#include <stdint.h>

typedef struct WipeSteamState
{
    float axes[6];
    unsigned char buttons[15];
} WipeSteamState;

static int wipeSteamSigned16(const unsigned char* bytes)
{
    const unsigned value = bytes[0] | ((unsigned) bytes[1] << 8);
    return value >= 32768 ? (int) value - 65536 : (int) value;
}

static float wipeSteamAxis(int value)
{
    return value / (value < 0 ? 32768.f : 32767.f);
}

// Parse into a temporary so invalid/truncated reports cannot partially update
// live input. No unaligned loads, packed-struct casts, or host-endian assumptions.
static int wipeSteamDecode(const unsigned char* bytes, size_t length,
                           WipeSteamState* result)
{
    if (!bytes || !result || length < 46 || length > 64 ||
        (bytes[0] != 0x42 && bytes[0] != 0x47))
    {
        return 0;
    }

    // Both USB report revisions share this prefix. Sensor/touchpad payloads
    // differ later and are deliberately not exposed by GLFW's gamepad API.
    const uint32_t buttons = (uint32_t) bytes[2] |
        ((uint32_t) bytes[3] << 8) | ((uint32_t) bytes[4] << 16) |
        ((uint32_t) bytes[5] << 24);
    const uint32_t masks[15] = {
        0x1, 0x2, 0x4, 0x8, 0x80000, 0x200, 0x40, 0x4000,
        0x10000, 0x8000, 0x20, 0x2000, 0x800, 0x400, 0x1000
    };
    WipeSteamState state = {{0}, {0}};
    for (int i = 0; i < 4; ++i)
    {
        const float value = wipeSteamAxis(wipeSteamSigned16(bytes + 10 + i * 2));
        state.axes[i] = (i & 1) ? -value : value;
    }
    for (int i = 0; i < 2; ++i)
    {
        int value = wipeSteamSigned16(bytes + 6 + i * 2);
        if (value < 0) value = 0;
        state.axes[4 + i] = value / 32767.f * 2.f - 1.f;
    }
    for (int i = 0; i < 15; ++i)
        state.buttons[i] = (buttons & masks[i]) != 0;

    *result = state;
    return 1;
}

#endif
