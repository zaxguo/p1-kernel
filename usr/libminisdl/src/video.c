// xzl: from NJU project. the choice of SDL interfaces seems good.
// the plan is to implement the same SDL interface atop our kernel,
// then build/port apps atop the SDL interface

// in impl, we refer back to SDL API defs.

#include "SDL.h"
#include "assert.h"
#include "sdl-video.h"
// Below: newlib/libc/include/
#include "fcntl.h"  // not kernel/fcntl.h
#include "stdio.h"
#include "unistd.h"
#include "stdlib.h"
#include "string.h"

//////////////////////////////////////////
//// New APIs (renderer, window, texture)

// Create direct or indirect windows (i.e. /dev/fb vs /dev/fb0)
// flags are ignored. expected to be SDL_WINDOW_FULLSCREEN
SDL_Window *SDL_CreateWindow(const char *title,
                             int x, int y, int w,
                             int h, Uint32 flags) {
    int n, fb;
    char isfb = (flags & SDL_WINDOW_HWSURFACE)?1:0; // hw surface or not 

    if ((fb = open(isfb?"/dev/fb/":"/dev/fb0/", O_RDWR)) <= 0)
        return 0;

    if (isfb) {
        // ask for a vframebuf that scales the window (viewport) by 2x
        if (config_fbctl(w, h,     // desired viewport ("phys")
                        w, h * 2, // two fbs, each contig, each can be written to /dev/fb in a write()
                        0, 0) != 0) {
            return 0;
        }
    } else {
        int zorder = (flags & SDL_WINDOW_FLOATING) ? ZORDER_FLOATING:ZORDER_TOP;
        if (config_fbctl0(FB0_CMD_INIT,x,y,w,h,zorder,
            (flags & SDL_WINDOW_TRANSPARENCY) ? 80:100 // transparency. can change value 
            ) != 0) return 0;
    }

    SDL_Window *win = malloc(sizeof(SDL_Window)); assert(win);
    memset(win, 0, sizeof(SDL_Window));

    if (isfb) {
        read_dispinfo(win->dispinfo, &n); assert(n > 0);
        printf("/proc/dispinfo: width %d height %d vwidth %d vheight %d pitch %d depth %d\n",
            win->dispinfo[WIDTH], win->dispinfo[HEIGHT], win->dispinfo[VWIDTH],
            win->dispinfo[VWIDTH], win->dispinfo[PITCH], win->dispinfo[DEPTH]);
    } else {
        win->dispinfo[WIDTH]=w; win->dispinfo[HEIGHT]=h; 
        // win->dispinfo[VWIDTH]=x; win->dispinfo[VHEIGHT]=y; // dirty: steal these fields for passing x/y
        win->dispinfo[PITCH]=w*PIXELSIZE; // no padding
    }
    win->fb = fb;
    win->flags = flags; 
    win->title = title; 
    return win;
}

void SDL_DestroyWindow(SDL_Window *win) {
    assert(win && win->fb);
    close(win->fb);
    free(win);
}

SDL_Renderer *SDL_CreateRenderer(SDL_Window *win,
                                 int index, Uint32 flags) {

    char isfb = (win->flags & SDL_WINDOW_HWSURFACE)?1:0; // hw surface or not 

    SDL_Renderer *render = malloc(sizeof(SDL_Renderer));
    assert(render);
    memset(render, 0, sizeof(SDL_Renderer));

    render->win = win;
    render->w = win->dispinfo[WIDTH];
    render->h = win->dispinfo[HEIGHT];
    render->pitch = win->dispinfo[PITCH];

    if (isfb) {
        assert(win->dispinfo[VHEIGHT] >= 2 * render->h); // enough for 2 tgts
        render->buf_sz = win->dispinfo[PITCH] * win->dispinfo[VHEIGHT];
        render->buf = malloc(render->buf_sz); assert(render->buf);
        render->tgt_sz = render->h * render->pitch;
        render->tgt[0] = render->buf;
        render->tgt[1] = render->buf + render->tgt_sz;
        render->cur_id = 0;
    } else { 
        render->buf_sz = render->pitch * render->h;
        render->buf = malloc(render->buf_sz); assert(render->buf);
        render->tgt_sz = render->buf_sz;
        render->tgt[0] = render->buf; 
        render->tgt[1] = 0; render->cur_id = 0; // no flipping 
    }

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

static inline void setpixel(char *buf, int x, int y, int pit, PIXEL p) {
    assert(x >= 0 && y >= 0);
    *(PIXEL *)(buf + y * pit + x * PIXELSIZE) = p;
}

static inline PIXEL getpixel(char *buf, int x, int y, int pit) {
    assert(x >= 0 && y >= 0);
    return *(PIXEL *)(buf + y * pit + x * PIXELSIZE);
}

/* Clear the current rendering target with the drawing color. */
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

/* Update the screen with any rendering performed since the previous call.
    Write window buf contents to /dev/fb(0) */
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

    if (win->flags & SDL_WINDOW_HWSURFACE) {
        // make the cur fb visible
        n = config_fbctl(0, 0, 0, 0 /*dc*/, 0 /*xoff*/, 
            rdr->cur_id * rdr->h /*yoff*/); assert(n == 0);
        rdr->cur_id = 1 - rdr->cur_id; // flip buf
    }
}

/* Create a texture for a rendering context. */
SDL_Texture *SDL_CreateTexture(SDL_Renderer *renderer,
                               Uint32 format,
                               int access /*ignored*/, int w, int h) {
    assert(format == SDL_PIXELFORMAT_RGB888); // only support this 

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

/* Update the given texture rectangle with new pixel data.
    rect: if NULL, update the entire texture
    pixels: the raw pixel data in the format of the texture
    pitch: # of bytes in a row of pixel data, including padding */
int SDL_UpdateTexture(SDL_Texture *texture,
                      const SDL_Rect *r,
                      const void *pixels, int pitch) {
    // update whole texture
    if (!r) {
        assert(pitch == texture->w * PIXELSIZE); // TBD
        memcpy(texture->buf, pixels, texture->buf_sz);
    } else { // update only a rect
        assert(pitch == r->w * PIXELSIZE); // TBD
        char *dest = texture->buf + r->y * texture->w * PIXELSIZE + r->x * PIXELSIZE;
        const char *src = pixels;
        for (int y = 0; y < r->h; y++) {
            //copy one row at a time, from "pixels" to "texture"    
            memcpy(dest, src, pitch); 
            src += pitch; dest += (texture->w * PIXELSIZE);
        }
    } 

    return 0;
}

/* Copy a portion of the texture to the current rendering target.
    srcrect, dstrect: NULL for the entire texture / rendering target */
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
            // fast path: texture & rendering target same dimensions
            memcpy(rdr->tgt[rdr->cur_id], texture->buf, sz);
        } else
        // TBD texture needs to be stretched to match rendering tgt
        // or update part of the tgt (not full), or use part of the texture
            assert(0);
    }
    return 0;
}

void SDL_SetWindowTitle(SDL_Window *window,
                        const char *title) 
    { printf("window title set %s", title); }

// rect==NULL to fill the entire target
// Returns 0 on success or a negative error code on failure
int SDL_RenderFillRect(SDL_Renderer * rdr,
                   const SDL_Rect * r) {
    char *tgt = rdr->tgt[rdr->cur_id];
    int pitch = rdr->pitch;
    PIXEL p = rgba_to_pixel(rdr->c.r, rdr->c.g, rdr->c.b, rdr->c.a);

    if (r) { // fill a region 
        for (int y = r->y; y < r->y + r->h; y++)
                for (int x = r->x; x < r->x + r->w; x++)
                    setpixel(tgt, x, y, pitch, p);
    } else { // fill the whole surface
        for (int y = 0; y < rdr->h; y++)
            for (int x = 0; x < rdr->w; x++)
                setpixel(tgt, x, y, pitch, p);
    }
    return 0; 
}

//////////////////////////////////////////
//// Old APIs (e.g. SDL_Surface)

// (xzl) unlike window/texture, surface APIs are more "direct", 
// allows app to access surface-provided pixels, which are 
// then written to /dev/fb. so less buffering vs. window APIs


// https://wiki.libsdl.org/SDL2/SDL_CreateRGBSurface
// depth: the depth of the surface in bits (only support 32 XXX)
// flags: cf SDL_HWSURFACE etc
// return 0 on failure
// XXX support /dev/fb only, dont support /dev/fb0 (interface limitation)
// XXX ignored: R/G/B/A mask, 
SDL_Surface* SDL_CreateRGBSurface(uint32_t flags, int w, int h, int depth,
    uint32_t Rmask, uint32_t Gmask, uint32_t Bmask, uint32_t Amask) {
    
    int n, fb; 
    int dispinfo[MAX_DISP_ARGS]; 
    char isfb = (flags & SDL_HWSURFACE)?1:0; // hw surface or not 

    if (depth!=32) return 0;
    
    if ((fb = open(isfb?"/dev/fb/":"/dev/fb0/", O_RDWR)) <= 0)
        return 0;

    if (isfb) {
        // ask for a vframebuf that scales the window (viewport) by 2x
        if (config_fbctl(w, h,     // desired viewport ("phys")
                        w, h * 2, // two fbs, each contig, each can be written to /dev/fb in a write()
                        0, 0) != 0) {
            return 0;
        }
    } else {
        // only support x=y=0, limited by this func's interface
        int trans=100;
        if (flags & SDL_TRANSPARENCY) trans=80;
        if (config_fbctl0(FB0_CMD_INIT,0,0,w,h,ZORDER_TOP,trans) != 0) return 0;
    }

    SDL_Surface * suf = calloc(1, sizeof(SDL_Surface)); assert(suf); 
    
    if (isfb) {
        read_dispinfo(dispinfo, &n); assert(n > 0);
        suf->w = dispinfo[VWIDTH]; assert(w<=dispinfo[VWIDTH]);
        suf->h = h;  assert(2*h <= dispinfo[VHEIGHT]); 
        suf->pitch = dispinfo[PITCH];   // app must respect this
        // if (suf->w * sizeof(PIXEL) != suf->pitch) {printf("TBD"); return 0;}
    } else {
        suf->w=w; suf->h=h; suf->pitch=suf->w*PIXELSIZE;
    }

    suf->pixels = calloc(suf->h, suf->pitch); assert(suf->pixels); 
    suf->fb = fb; 
    suf->cur_id = 0; 
    suf->flags = flags; 

    return suf; 
}

SDL_Surface* SDL_SetVideoMode(int w, int h, int bpp, uint32_t flags) {
    return SDL_CreateRGBSurface(flags, w, h, bpp, 0, 0, 0, 0); 
}

void SDL_FreeSurface(SDL_Surface *s) {
    if (!s) return; 
    if (s->pixels) free(s->pixels); 
    if (s->fb) close(s->fb); 
    free(s); 
}

// Perform a fast fill of a rectangle with a specific color.
// https://wiki.libsdl.org/SDL2/SDL_FillRect
// rect==NULL to fill the entire surface
// Returns 0 on success or a negative error code on failure
int SDL_FillRect(SDL_Surface *suf, SDL_Rect *r, uint32_t color) {
    if (r) { // fill a region 
        for (int y = r->y; y < r->y + r->h; y++)
                for (int x = r->x; x < r->x + r->w; x++)
                    setpixel((char *)suf->pixels, x, y, suf->pitch, color);            
    } else { // fill the whole surface
        for (int y = 0; y < suf->h; y++)
            for (int x = 0; x < suf->w; x++)
                setpixel((char *)suf->pixels, x, y, suf->pitch, color);
    }
    return 0; 
}

// legacy API
// Makes sure the given area is updated on the given screen. 
// The rectangle must be confined within the screen boundaries (no clipping is done).
// If 'x', 'y', 'w' and 'h' are all 0, SDL_UpdateRect will update the entire surface
// https://www.libsdl.org/release/SDL-1.2.15/docs/html/sdlupdaterect.html
void SDL_UpdateRect(SDL_Surface *suf, int x, int y, int w, int h) {
    int n; 
    assert(x==0 && y==0 && w==0 && h==0); // only support full scr now
    int sz = suf->h * suf->pitch; 
    char isfb = (suf->flags & SDL_HWSURFACE)?1:0; // hw surface or not 
    
    if (isfb) { // /dev/fb
        n = lseek(suf->fb, suf->cur_id * sz, SEEK_SET);
        assert(n == suf->cur_id * sz); 
        if ((n = write(suf->fb, suf->pixels, sz)) != sz) {
            printf("%s: failed to write to hw fb. fb %d sz %d ret %d\n",
                __func__, suf->fb, sz, n);
        }
        // make the cur fb visible
        n = config_fbctl(0, 0, 0, 0 /*dc*/, 0 /*xoff*/, suf->cur_id * suf->h /*yoff*/);
        assert(n == 0);
        suf->cur_id = 1 - suf->cur_id;
    } else {    // /dev/fb0
        n = lseek(suf->fb, 0, SEEK_SET); assert(n==0); 
        if ((n = write(suf->fb, suf->pixels, sz)) != sz) {
            printf("%s: failed to write to hw fb. fb %d sz %d ret %d\n",
                __func__, suf->fb, sz, n);
        }
    }
}

// https://wiki.libsdl.org/SDL2/SDL_LockSurface
// "Between calls to SDL_LockSurface() / SDL_UnlockSurface(), 
// you can write to and read from surface->pixels, using the pixel format 
// stored in surface->format. Once you are done accessing the surface, 
// you should use SDL_UnlockSurface() to release it."

// Set up a surface for directly accessing the pixels.
// Returns 0 on success
int SDL_LockSurface(SDL_Surface *s) {
    return 0; 
}

// Release a surface after directly accessing the pixels.
void SDL_UnlockSurface(SDL_Surface *s) {
}
