/*
This file presents all abstractions needed to port LiteNES.
  (The current working implementation uses allegro library.)

To port this project, replace the following functions by your own:
1) nes_hal_init()
    Do essential initialization work, including starting a FPS HZ timer.

2) nes_set_bg_color(c)
    Set the back ground color to be the NES internal color code c.

3) nes_flush_buf(*buf)
    Flush the entire pixel buf's data to frame buffer.

4) nes_flip_display()
    Fill the screen with previously set background color, and
    display all contents in the frame buffer.

5) wait_for_frame()
    Implement it to make the following code is executed FPS times a second:
        while (1) {
            wait_for_frame();
            do_something();
        }
    xzl: could use sleep()

6) int nes_key_state(int b) 
    Query button b's state (1 to be pressed, otherwise 0).
    The correspondence of b and the buttons:
      0 - Power
      1 - A
      2 - B
      3 - SELECT
      4 - START
      5 - UP
      6 - DOWN
      7 - LEFT
      8 - RIGHT
*/
#include "hal.h"
#include "fce.h"
#include "common.h"
#include "../user.h"
#include "../../fcntl.h"    // kernel's

#define FB_FLIP  1   // double fb buffering

static int cur_id = 0; // id of fb being worked on, 0 or 1 (if FB_FLIP on)

static char *vtx = 0;       // byte-to-byte mirror of hw fb (inc pitch)
static int vtx_sz = 0;      // in bytes

static int dispinfo[MAX_DISP_ARGS]={0};    // display config
static int fb = 0;      // /dev/fb /proc/fbctl
static int fds[2]; //pipes for exchanging events

struct event {
    int type; 
#define EV_INVALID      -1    
#define EV_KEYUP        0    
#define EV_KEYDOWN      1
#define EV_TIMER        2
    int scancode;   // for EV_KEY
}; 

// kb state 
char key_states[NUM_SCANCODES] = {0}; // all EV_KEYUP

/* Wait until next allegro timer event is fired. */
void wait_for_frame()
{
    struct event ev; 

    if (fds[0]<=0) {printf("fatal:pipe invalid\n"); exit(1);};

    while (1) { 
        if (read(fds[0], &ev, sizeof ev) != sizeof ev) {
            printf("read ev failed"); exit(1); 
        }
        switch (ev.type)
        {
        case EV_TIMER:
            // printf("timer ev\n");        // lots of prints
            return;     
        case EV_KEYDOWN: 
        case EV_KEYUP:
            assert(ev.scancode<NUM_SCANCODES); 
            key_states[ev.scancode]=ev.type;   
            // printf("key %x %s\n", ev.scancode, ev.type == EV_KEYDOWN ? "down":"up");
            break;      // continue to wait for timer ev   
        default:
            printf("unknown ev"); exit(1); 
            break;
        }
    }
}

// id: fb 0 or 1
static inline void setpixel(int id, char *buf, int x, int y, int pit, PIXEL p) {
    assert(x>=0 && y>=0); 
    y += (id*SCREEN_HEIGHT);
    *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p; 
}

static inline PIXEL getpixel(int id, char *buf, int x, int y, int pit) {
    assert(x>=0 && y>=0); 
    y += (id*SCREEN_HEIGHT);
    return *(PIXEL *)(buf + y*pit + x*PIXELSIZE); 
}

#define fcecolor_to_pixel(color) \
(((char)color.r<<16)|((char)color.g<<8)|((char)color.b))

/* Set background color. RGB value of c is defined in fce.h */
void nes_set_bg_color(int c)
{
    int pitch = dispinfo[PITCH];
    PIXEL p = fcecolor_to_pixel(palette[c]);
    for (int y = 0; y < SCREEN_HEIGHT; y++) 
        for (int x = 0; x < SCREEN_WIDTH; x++)
            setpixel(cur_id,vtx,x,y,pitch,p); 
}

/* Flush the pixel buffer */
// xzl: materialize nes's drawing (unordered pixels) to fb
//          this lays out pixels in memory (hw format
// xzl: ver1: draw to an app fb, which is to be write to /dev/fb in one shot
//      ver2: draw to a "back" fb (which will be made visible later)
// 
// fb basics
// https://github.com/fxlin/p1-kernel/blob/master/docs/exp3/fb.md
void nes_flush_buf(PixelBuf *buf) {
    int pitch = dispinfo[PITCH]; //in bytes

    for (int i = 0; i < buf->size; i ++) {
        Pixel *p = &buf->buf[i];
        int x = p->x, y = p->y;
        pal color = palette[p->c];
        PIXEL c = fcecolor_to_pixel(color);

        // Pixel could have x<0 (loopks like fce was shifting drawn pixels
        //  by applying offsets to them). these pixels shall be invisible. 
        assert(x<SCREEN_WIDTH && y>=0 && y<SCREEN_HEIGHT);
        if (x>=0) {
            setpixel(cur_id,vtx,x,y,pitch,c); //1x scaling
            // the original code scales fce's raw pixels by 2x for larger display;
            //   since the hw gpu will scale fb to display anyway, we don't need this
            // setpixel(vtx, x*2,      y*2,    pitch, c); 
            // setpixel(vtx, x*2+1,    y*2,    pitch, c); 
            // setpixel(vtx, x*2,      y*2+1,  pitch, c); 
            // setpixel(vtx, x*2+1,    y*2+1,  pitch, c); 
        }
    }
}


// assume sleep(1) sleeps for 1/60 sec, i.e. schedule ticks are 60Hz within the kernel
#define TICKS_PER_TIMEREV  1   
#define LINESIZE 128    // linebuf for reading 

/* Initialization:
   (1) start a 1/FPS Hz timer. 
   (2) register fce_timer handle on each timer event */
void nes_hal_init() {
    int n; 
    char buf[LINESIZE], *s; 
    struct event ev; 

    if (pipe(fds) != 0) {
        printf("%s: pipe() failed\n", __func__);
        exit(1);
    }

    if (fork() == 0) { // timer task, wakeup every 1 tick and writes to pipe
        close(fds[0]);
        ev.type = EV_TIMER; 
        printf("timer task running\n");
        while (1) {            
            sleep(TICKS_PER_TIMEREV);
            if(write(fds[1], &ev, sizeof ev) != sizeof ev){
                printf("write timerev failed"); 
                exit(1);
            }            
        }
        exit(0); // shall never reach here
    }

    if (fork() == 0)  { // keyboard task, read kb events and writes to pipe
        close(fds[0]);
        int events = open("/dev/events", O_RDONLY); assert(events>0); 

        printf("input task running\n");
        while (1) {             // xzl: TODO replace with read_kb_events()
            // read a line from /dev/events and parse it into key events
            // line format: [kd|ku] 0x12
            n = read(events, buf, LINESIZE); assert(n>0); 
            s=buf; ev.type=EV_INVALID; ev.scancode = 0; // init
            if (buf[0] == 'k' && buf[1] == 'd') {
                ev.type = EV_KEYDOWN;
            } else if (buf[0] == 'k' && buf[1] == 'u') {
                ev.type = EV_KEYUP;
            }
            s += 2;
            while (*s == ' ')
                s++;
            if (s[0] == '0' && s[1] == 'x')
                ev.scancode = atoi16(s);
            if (ev.scancode==0 || ev.scancode >= NUM_SCANCODES || ev.type==EV_INVALID) {
                printf("failed to parse %s", buf);
            } else {
                if(write(fds[1], &ev, sizeof ev) != sizeof ev) {
                    printf("write keyev failed"); 
                    exit(1);
                }
            }            
        }
        exit(0); // shall never reach here
    }
    close(fds[1]); 

    //// config fb 
    fb = open("/dev/fb/", O_RDWR);
    // fbctl = open("/proc/fbctl", O_RDWR); 
    // int dp = open("/proc/dispinfo", O_RDONLY); 
    assert(fb>0); 
    
    //      ask for a vframebuf that scales the native fce canvas by 2x
    n = config_fbctl(SCREEN_WIDTH, SCREEN_HEIGHT,    // desired viewport ("phys")
#ifdef FB_FLIP
        SCREEN_WIDTH, 2*SCREEN_HEIGHT,0,0);  // two fbs, each contig (can be write to /dev/fb in a shot
#else        
        SCREEN_WIDTH, SCREEN_HEIGHT,0,0); 
#endif        
    assert(n==0); 

    read_dispinfo(dispinfo, &n); assert(n>0); 
    // close(dp); 
    printf("FB_FLIP=%d SCREEN_WIDTH=%d SCREEN_HEIGHT=%d\n ", FB_FLIP, SCREEN_WIDTH, SCREEN_HEIGHT); 
    printf("/proc/dispinfo: width %d height %d vwidth %d vheight %d pitch %d depth %d isrgb %d\n", 
    dispinfo[WIDTH], dispinfo[HEIGHT], dispinfo[VWIDTH], dispinfo[VHEIGHT], dispinfo[PITCH], dispinfo[DEPTH], dispinfo[ISRGB]); 

    // note: pitch already in bytes
    vtx_sz = dispinfo[PITCH] * dispinfo[VHEIGHT]; 
    vtx = malloc(vtx_sz);
    if (!vtx) {printf("failed to alloc vtx\n"); exit(1);}
    printf("fb alloc ...ok\n"); 

    // TODO: free vtx
}

/* Update screen at FPS rate by allegro's drawing function. 
   Timer ensures this function is called FPS times a second. */
void nes_flip_display()
{
    int n;     
    assert(fb && vtx && vtx_sz); 
    
#ifdef FB_FLIP
    int sz = SCREEN_HEIGHT*dispinfo[PITCH]; 
    n = lseek(fb, cur_id*sz, SEEK_SET); assert(n==cur_id*sz); 
    if ((n=write(fb, vtx, sz)) != sz) {
        printf("%s: failed to write to hw fb. fb %d sz %d ret %d\n",
            __func__, fb, sz, n); 
    }    
    // make the cur fb visible
    // assert(fbctl);
    n = config_fbctl(0,0,0,0/*dc*/, 0/*xoff*/, cur_id*SCREEN_HEIGHT/*yoff*/);
    assert(n==0);     
    cur_id = 1-cur_id; 
#else    
    n = lseek(fb, 0, SEEK_SET); assert(n==0); 
    if ((n=write(fb, vtx, vtx_sz)) != vtx_sz) {
        printf("%s: failed to write to hw fb. fb %d vtx_sz %d ret %d\n",
            __func__, fb, vtx_sz, n); 
    }
#endif    
}

// #define KEY_A 0x04 // Keyboard a and A
// #define KEY_B 0x05 // Keyboard b and B
// #define KEY_C 0x06 // Keyboard c and C
// #define KEY_D 0x07 // Keyboard d and D
// #define KEY_E 0x08 // Keyboard e and E
// #define KEY_F 0x09 // Keyboard f and F
// #define KEY_G 0x0a // Keyboard g and G
// #define KEY_H 0x0b // Keyboard h and H
// #define KEY_I 0x0c // Keyboard i and I
// #define KEY_J 0x0d // Keyboard j and J
// #define KEY_K 0x0e // Keyboard k and K
// #define KEY_L 0x0f // Keyboard l and L
// #define KEY_M 0x10 // Keyboard m and M
// #define KEY_N 0x11 // Keyboard n and N
// #define KEY_O 0x12 // Keyboard o and O
// #define KEY_P 0x13 // Keyboard p and P
// #define KEY_Q 0x14 // Keyboard q and Q
// #define KEY_R 0x15 // Keyboard r and R
// #define KEY_S 0x16 // Keyboard s and S
// #define KEY_T 0x17 // Keyboard t and T
// #define KEY_U 0x18 // Keyboard u and U
// #define KEY_V 0x19 // Keyboard v and V
// #define KEY_W 0x1a // Keyboard w and W
// #define KEY_X 0x1b // Keyboard x and X
// #define KEY_Y 0x1c // Keyboard y and Y
// #define KEY_Z 0x1d // Keyboard z and Z


/* Query a button's state.
   Returns 1 if button #b is pressed. */
int nes_key_state(int b)
{
    switch (b)
    {
        case 0: // On / Off
            return 1;
        case 1: // A  (k)
            return (key_states[KEY_K]==EV_KEYDOWN);
        case 2: // B  (j)
            return (key_states[KEY_J]==EV_KEYDOWN); 
        case 3: // SELECT (u)
            return (key_states[KEY_U]==EV_KEYDOWN);
        case 4: // START  (i)
            return (key_states[KEY_I]==EV_KEYDOWN);
        case 5: // UP  (w)
            return (key_states[KEY_W]==EV_KEYDOWN);
        case 6: // DOWN (s)
            return (key_states[KEY_S]==EV_KEYDOWN);
        case 7: // LEFT (a)
            return (key_states[KEY_A]==EV_KEYDOWN);
        case 8: // RIGHT (d)
            return (key_states[KEY_D]==EV_KEYDOWN);
        default:
            return 1;
    }
}

