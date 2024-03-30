// keyboard
//  modeled after console.c

#include <stdarg.h>

#include "param.h"
#include "spinlock.h"
#include "sleeplock.h"
#include "fs.h"
#include "file.h"
#include "fcntl.h"
#include "sched.h"
#include "utils.h"

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

struct {
    struct spinlock lock;
    // input
#define INPUT_BUF_SIZE 8
    // #define SCAN_SLOTS       8
    struct kbevent buf[INPUT_BUF_SIZE];
    uint r; // Read index
    uint w; // Write index
} kb;

#define NUM_SCANCODES   0x64 // all the way to KEY_KPDOT, cf https://gist.github.com/MightyPork/6da26e382a7ad91b5496ee55fdc73db2  
#define KEY_RELEASED    0
#define KEY_CONT_PRESSED 1
#define KEY_JUST_PRESSED 2

char key_states[NUM_SCANCODES] = {KEY_RELEASED}; // 0: keyup, 1: keydown

//
// user read()s from kb device file go here.
// as long as there's one ev, return to user read()        
//      we may also change the behaviors to return a batch of evs
// user_dist indicates whether dst is a user
// or kernel address.
// "n": user buffer size
// user_dst=1 means dst is user va
int kb_read(int user_dst, uint64 dst, int n) {
    uint target;
    struct kbevent ev;
#define TXTSIZE 20     
    char ev_txt[TXTSIZE]; 

    V("called user_dst %d", user_dst);

    target = n;
    acquire(&kb.lock);
    while (n > 0) {     // n:remaining space in userbuf
        // wait until interrupt handler has put some
        // input into cons.buffer.
        while (kb.r == kb.w) {
            if (killed(myproc())) {
                release(&kb.lock);
                return -1;
            }
            sleep(&kb.r, &kb.lock);
        }

        ev = kb.buf[kb.r++ % INPUT_BUF_SIZE];
        int len = snprintf(ev_txt, TXTSIZE, "%s 0x%02x\n", 
            ev.type == KEYDOWN ? "kd":"ku", ev.scancode); 

        BUG_ON(len < 0 || len >= TXTSIZE); // ev_txt too small

        if (len > n) break; 
        
        // copy the input byte to the user-space buffer.
        if (either_copyout(user_dst, dst, ev_txt, len) == -1)
            break;

        dst+=len; n-=len;        

        break; 
    }
    release(&kb.lock);

    return target - n;
}

// if buf full, drop event but still change key state
void kb_intr(unsigned char mod, const unsigned char keys[6]) {
    unsigned char c;

    if (keys[0] == 1 /*KEY_ERR_OVF*/) // too many keys
        return;

    V("mod %u key %02x %02x %02x %02x %02x %02x", mod, keys[0], keys[1], keys[2], keys[3], keys[4], keys[5]);

    acquire(&kb.lock);

    for (int i = 0; i < 6; i++) {
        c = keys[i];
        if (c > NUM_SCANCODES) {E("unknown code?"); continue;}
        if (c == 0) break; // no more scan code
        if (key_states[c] == KEY_RELEASED) {
            if (kb.w-kb.r < INPUT_BUF_SIZE) {
                struct kbevent ev = {
                    .type = KEYDOWN,
                    .mod = mod,
                    .scancode = c};
                kb.buf[kb.w++ % INPUT_BUF_SIZE] = ev;
            }
            key_states[c] = KEY_JUST_PRESSED;
        } else if (key_states[c] == KEY_CONT_PRESSED)
            key_states[c] = KEY_JUST_PRESSED; // renew the state
    }

    for (c = 2; c < NUM_SCANCODES; c++) {       //0,1 are nocode,ovf
        switch (key_states[c]) {
        case KEY_CONT_PRESSED: // pressed before, but not pressed in current scan
            if (kb.w-kb.r < INPUT_BUF_SIZE) {
                struct kbevent ev = {
                    .type = KEYUP,
                    .mod = mod,
                    .scancode = c};
                kb.buf[kb.w++ % INPUT_BUF_SIZE] = ev;
            }
            key_states[c] = KEY_RELEASED;
            break;
        case KEY_JUST_PRESSED:
            key_states[c] = KEY_CONT_PRESSED; // for future scan
            break;
        case KEY_RELEASED: // released before && not pressed
            break;
        default:
            BUG();
        }
    }

    wakeup(&kb.r);
    release(&kb.lock);
}

#include "uspios.h"
#include "uspi.h"

// return 0 on success
int usbkb_init(void) {

    initlock(&kb.lock, "kb");

	if (!USPiInitialize ()) {
		E("cannot init"); 
        return -1; 
	}
	if (!USPiKeyboardAvailable ()) {
        E("kb not found");
        return -1; 
	}
    USPiKeyboardRegisterKeyStatusHandlerRaw(kb_intr); 

    devsw[KEYBOARD].read = kb_read;
    devsw[KEYBOARD].write = 0; // nothing
    return 0; 
}