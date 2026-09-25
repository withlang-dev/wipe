#include "steam_controller.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

static void put16(unsigned char* p, unsigned value)
{
    p[0] = value & 255;
    p[1] = value >> 8;
}

int main(void)
{
    // Captured from the attached controller before the GLFW patch.
    unsigned char report[64] = {
        0x42,0x94,0,0,0,0,0,0,0,0,0xd2,0,0xa4,0,0xcf,0xfd,0xbe,0xff,
        0,0,0,0,0,0,0,0,0,0,0,0,0x26,0xfb,0x20,0x26,0x5a,0,
        0x0a,0xf5,0x1f,0x3f,0,0,0,0,0,0,0xff,0x7f,0,0,0,0,0,0
    };
    WipeSteamState state;
    assert(wipeSteamDecode(report,54,&state));
    assert(fabsf(state.axes[0] - 210.f/32767.f) < 0.00001f);
    assert(state.axes[1] < 0.f && state.axes[2] < 0.f && state.axes[3] > 0.f);
    assert(state.axes[4] == -1.f && state.axes[5] == -1.f);

    for (int revision = 0; revision < 2; ++revision)
    {
        report[0] = revision ? 0x47 : 0x42;
        put16(report+10,32767); put16(report+12,32768);
        put16(report+14,32768); put16(report+16,32767);
        put16(report+6,32767); put16(report+8,0);
        report[2] = 1; // A alone must never become B/retry repeats.
        assert(wipeSteamDecode(report,46,&state));
        assert(state.axes[0] == 1.f && state.axes[1] == 1.f);
        assert(state.axes[2] == -1.f && state.axes[3] == -1.f);
        assert(state.axes[4] == 1.f && state.axes[5] == -1.f);
        assert(state.buttons[0] && !state.buttons[1]);
    }

    const uint32_t masks[15] = {
        1,2,4,8,1u<<19,1u<<9,1u<<6,1u<<14,1u<<16,1u<<15,
        1u<<5,1u<<13,1u<<11,1u<<10,1u<<12
    };
    for (int button = 0; button < 15; ++button)
    {
        for (int b = 0; b < 4; ++b) report[2+b] = masks[button] >> (b*8);
        assert(wipeSteamDecode(report,54,&state));
        for (int other = 0; other < 15; ++other)
            assert(state.buttons[other] == (button == other));
    }

    WipeSteamState before = state;
    for (size_t size = 0; size < 46; ++size)
    {
        assert(!wipeSteamDecode(report,size,&state));
        assert(memcmp(&state,&before,sizeof(state)) == 0);
    }
    assert(!wipeSteamDecode(report,65,&state));
    assert(!wipeSteamDecode(NULL,54,&state));
    assert(!wipeSteamDecode(report,54,NULL));
    report[0] = 0x43; // Battery packets must not be treated as controller state.
    assert(!wipeSteamDecode(report,54,&state));

    // All possible signed axis values remain bounded, including -32768.
    report[0] = 0x42;
    for (unsigned value = 0; value <= 65535; ++value)
    {
        for (int axis = 0; axis < 6; ++axis) put16(report+6+axis*2,value);
        assert(wipeSteamDecode(report,54,&state));
        for (int axis = 0; axis < 6; ++axis)
            assert(isfinite(state.axes[axis]) && fabsf(state.axes[axis]) <= 1.f);
    }
    puts("Steam USB decoder passed: captured report, revisions, axes, buttons, malformed reports");
}
