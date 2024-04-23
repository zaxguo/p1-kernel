// xzl: from NJU project. the choice of SDL interfaces seems good.
// the plan is to implement the same SDL interface atop our kernel,
// then build/port apps atop the SDL interface

// in impl, we refer back to SDL API defs.

#include "SDL.h"
#include "assert.h"
#include "sdl-video.h"
// newlib
#include "fcntl.h"
#include "stdio.h"
#include "unistd.h"
#include "stdlib.h"
#include "string.h"

//////////////////////////////////////////
//// new APIs

SDL_Window *SDL_CreateWindow(const char *title,
                             int x, int y, int w,
                             int h, Uint32 flags) {
    assert(x == 0 && y == 0); // only support this. TBD
    assert(flags & SDL_WINDOW_FULLSCREEN);

    int n, fb;

    if ((fb = open("/dev/fb/", O_RDWR)) <= 0)
        return 0;

    // ask for a vframebuf that scales the window (viewport) by 2x
    if (config_fbctl(w, h,     // desired viewport ("phys")
                     w, h * 2, // two fbs, each contig, each can be written to /dev/fb in a write()
                     0, 0) != 0) {
        return 0;
    }

    SDL_Window *win = malloc(sizeof(SDL_Window));
    assert(win);
    memset(win, 0, sizeof(SDL_Window));

    read_dispinfo(win->dispinfo, &n);
    assert(n > 0);

    printf("/proc/dispinfo: width %d height %d vwidth %d vheight %d pitch %d depth %d\n",
           win->dispinfo[WIDTH], win->dispinfo[HEIGHT], win->dispinfo[VWIDTH],
           win->dispinfo[VWIDTH], win->dispinfo[PITCH], win->dispinfo[DEPTH]);

    win->fb = fb;
    return win;
}

void SDL_DestroyWindow(SDL_Window *win) {
    assert(win && win->fb);
    close(win->fb);
    free(win);
}

SDL_Renderer *SDL_CreateRenderer(SDL_Window *win,
                                 int index, Uint32 flags) {

    SDL_Renderer *render = malloc(sizeof(SDL_Renderer));
    assert(render);
    memset(render, 0, sizeof(SDL_Renderer));

    render->win = win;
    render->w = win->dispinfo[WIDTH];
    render->h = win->dispinfo[HEIGHT];
    render->pitch = win->dispinfo[PITCH];

    assert(win->dispinfo[VHEIGHT] >= 2 * render->h); // enough for 2 tgts
    render->buf_sz = win->dispinfo[PITCH] * win->dispinfo[VHEIGHT];
    render->buf = malloc(render->buf_sz);
    assert(render->buf);
    render->tgt_sz = render->h * render->pitch;
    render->tgt[0] = render->buf;
    render->tgt[1] = render->buf + render->tgt_sz;

    render->cur_id = 0;

    return render;
}

void SDL_DestroyRenderer(SDL_Renderer *renderer) {
    assert(renderer);
    free(renderer);
}

int SDL_SetRenderDrawColor(SDL_Renderer *renderer,
                           Uint8 r, Uint8 g, Uint8 b,
                           Uint8 a) {
    assert(renderer);
    renderer->c.r = r;
    renderer->c.g = g;
    renderer->c.b = b;
    renderer->c.a = a;
    return 0;
}

#define rgba_to_pixel(r, g, b, a) \
    (((char)a << 24) | ((char)r << 16) | ((char)g << 8) | ((char)b))

// id: fb 0 or 1
// static inline void setpixel(int id, int SCREEN_HEIGHT, char *buf, int x, int y, int pit, PIXEL p) {
//     assert(x>=0 && y>=0);
//     y += (id*SCREEN_HEIGHT);
//     *(PIXEL *)(buf + y*pit + x*PIXELSIZE) = p;
// }

static inline void setpixel(char *buf, int x, int y, int pit, PIXEL p) {
    assert(x >= 0 && y >= 0);
    *(PIXEL *)(buf + y * pit + x * PIXELSIZE) = p;
}

// static inline PIXEL getpixel(int id, int SCREEN_HEIGHT, char *buf, int x, int y, int pit) {
//     assert(x>=0 && y>=0);
//     y += (id*SCREEN_HEIGHT);
//     return *(PIXEL *)(buf + y*pit + x*PIXELSIZE);
// }

static inline PIXEL getpixel(char *buf, int x, int y, int pit) {
    assert(x >= 0 && y >= 0);
    return *(PIXEL *)(buf + y * pit + x * PIXELSIZE);
}

int SDL_RenderClear(SDL_Renderer *rdr) {
    char *tgt = rdr->tgt[rdr->cur_id];

    int pitch = rdr->pitch;
    int SCREEN_HEIGHT = rdr->h;
    int SCREEN_WIDTH = rdr->w;

    PIXEL p = rgba_to_pixel(rdr->c.r, rdr->c.g, rdr->c.b, rdr->c.a);
    for (int y = 0; y < SCREEN_HEIGHT; y++)
        for (int x = 0; x < SCREEN_WIDTH; x++)
            setpixel(tgt, x, y, pitch, p);
    return 0;
}

void SDL_RenderPresent(SDL_Renderer *rdr) {
    SDL_Window *win = rdr->win;
    int n;
    assert(rdr && rdr->buf && rdr->buf_sz);
    int sz = rdr->tgt_sz;

    n = lseek(win->fb, rdr->cur_id * sz, SEEK_SET);
    assert(n == rdr->cur_id * sz);
    if ((n = write(win->fb, rdr->tgt[rdr->cur_id], sz)) != sz) {
        printf("%s: failed to write to hw fb. fb %d sz %d ret %d\n",
               __func__, win->fb, sz, n);
    }
    // make the cur fb visible
    n = config_fbctl(0, 0, 0, 0 /*dc*/, 0 /*xoff*/, rdr->cur_id * rdr->h /*yoff*/);
    assert(n == 0);
    rdr->cur_id = 1 - rdr->cur_id;
}

SDL_Texture *SDL_CreateTexture(SDL_Renderer *renderer,
                               Uint32 format,
                               int access, int w,
                               int h) {
    // ignore access
    assert(format == SDL_PIXELFORMAT_RGB888); // only suport this 

    SDL_Texture *tx = malloc(sizeof(SDL_Texture)); assert(tx);
    tx->w = w;
    tx->h = h;
    tx->buf_sz = w * h * sizeof(uint32_t);
    tx->buf = malloc(tx->buf_sz); assert(tx->buf);

    return tx;
}

void SDL_DestroyTexture(SDL_Texture *tx) {
    assert(tx && tx->buf);
    free(tx->buf);
    free(tx);
}

// rect == NULL to update the entire texture
// pixels: the raw pixel data in the format of the texture
// the number of bytes in a row of pixel data, including padding between lines
int SDL_UpdateTexture(SDL_Texture *texture,
                      const SDL_Rect *rect,
                      const void *pixels, int pitch) {
    // fast path: update whole texture; no row padding
    if (!rect && pitch == texture->w * sizeof(SDL_Color))
        memcpy(texture->buf, pixels, texture->buf_sz);
    else {
        assert(0);
    } // TBD, partial update, or handle row padding.

    return 0;
}

// srcrect, dstrect: NULL for the entire texture / rendering target
int SDL_RenderCopy(SDL_Renderer *rdr,
                   SDL_Texture *texture,
                   const SDL_Rect *srcrect,
                   const SDL_Rect *dstrect) {
    int sz = rdr->tgt_sz;

    // fast path: copy entire texture to the rendering target
    //    rendering tgt no row padding
    if (!srcrect && !dstrect) {
        if (texture->h == rdr->h &&
            texture->w == rdr->w && rdr->w * sizeof(PIXEL) == rdr->pitch) {
            // fasth path: texture & rendering target same dimensions
            memcpy(rdr->tgt[rdr->cur_id], texture->buf, sz);
        } else
        // TBD texture needs to be stretched to match rendering tgt
        // or update part of the tgt (not full), or use part of the texture
        {
            assert(0);
        }
    }
    return 0;
}

void SDL_SetWindowTitle(SDL_Window *window,
                        const char *title) 
    { printf("window title set %s", title); }