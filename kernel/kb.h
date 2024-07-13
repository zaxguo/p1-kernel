#ifndef _KB_H
#define _KB_H
// kb event, modeled after SDL keyboard event
// https://wiki.libsdl.org/SDL2/SDL_KeyboardEvent
struct kbevent {
    uint32 type;
#define KEYDOWN 0
#define KEYUP 1
    uint32 timestamp;
    uint8 mod;
    uint8 scancode;
};

struct kb_struct {
    struct spinlock lock;
    // input
#define INPUT_BUF_SIZE 8
    struct kbevent buf[INPUT_BUF_SIZE];
    uint r; // Read index
    uint w; // Write index
}; 

// needed by surface flinger to interpret surface commands (e.g. Ctrl-tab)
// https://gist.github.com/MightyPork/6da26e382a7ad91b5496ee55fdc73db2
#define KEY_MOD_LCTRL  0x01
#define KEY_MOD_LSHIFT 0x02
#define KEY_MOD_LALT   0x04
#define KEY_MOD_LMETA  0x08
#define KEY_MOD_RCTRL  0x10
#define KEY_MOD_RSHIFT 0x20
#define KEY_MOD_RALT   0x40
#define KEY_MOD_RMETA  0x80

#define KEY_TAB 0x2b // Keyboard Tab

#define KEY_RIGHT 0x4f // Keyboard Right Arrow
#define KEY_LEFT 0x50 // Keyboard Left Arrow
#define KEY_DOWN 0x51 // Keyboard Down Arrow
#define KEY_UP 0x52 // Keyboard Up Arrow

#endif

