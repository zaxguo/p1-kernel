#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "SDL.h"
// #include <SDL-video.h>
#include "math.h"

#define FPS 10
#define W 800
#define H 600

SDL_Surface *screen = NULL;

// static void drawVerticalLine(int x, int y0, int y1, uint32_t color) {
//   assert(y0 <= y1);
//   int i;
//   uint32_t *p = (void *)screen->pixels;
//   for (i = y0; i <= y1; i ++) {
//     p[i * W + x] = color;
//   }
// }

// static void visualize(int16_t *stream, int samples) {
//   int i;
//   static int color = 0;
//   SDL_FillRect(screen, NULL, 0);
//   int center_y = H / 2;
//   for (i = 0; i < samples; i ++) {
//     // fixedpt multipler = fixedpt_cos(fixedpt_divi(fixedpt_muli(FIXEDPT_PI, 2 * i), samples));
//     float multipler = cos(3.14*2*i/samples); 
//     int x = i * W / samples;
//     // int y = center_y - fixedpt_toint(fixedpt_muli(fixedpt_divi(fixedpt_muli(multipler, stream[i]), 32768), H / 2));
//     int y = center_y - (int)((multipler * stream[i])/32768 *(H/2));
//     if (y < center_y) drawVerticalLine(x, y, center_y, color);
//     else drawVerticalLine(x, center_y, y, color);
//     color ++;
//     color &= 0xffffff;
//   }
//   SDL_UpdateRect(screen, 0, 0, 0, 0);
// }


// each cpu: a horizontal bar
// below in pixels
#define BAR_ORIGIN_X  10 // top-left of bar 0
#define BAR_ORIGIN_Y  10 
#define BAR_HEIGHT 20
#define BAR_MAX_LEN 200
#define BAR_SPACING 10 

// video.c 
#define rgba_to_pixel(r, g, b, a) \
    (((char)a << 24) | ((char)r << 16) | ((char)g << 8) | ((char)b))

#define max(a, b) ((a) > (b) ? (a) : (b))

#define COLOR_BKGND rgba_to_pixel(56,56,56,0)  // gray

static SDL_Rect bars[MAX_NCPU]; 

static void init_bars(void) {
  for (int i = 0; i < MAX_NCPU; i++) {
    bars[i].x = BAR_ORIGIN_X; 
    bars[i].y = BAR_ORIGIN_Y + BAR_HEIGHT*i + BAR_SPACING*i; 

    bars[i].h = BAR_HEIGHT;
    bars[i].w = BAR_MAX_LEN;
  }
}

unsigned util_to_color(int util) {
  int r, g, b; 
  r = (util/100) * 255; 
  g = 0; 
  b = 255 - (util/100) * 255; 
  return rgba_to_pixel(r, g, b, 0); 
}

static void visualize(int util[MAX_NCPU], int ncpus) {
  int i;
  // int color = 0;

  for (i=0; i<ncpus; i++) {
    bars[i].w = BAR_MAX_LEN;
    SDL_FillRect(screen, bars+i, COLOR_BKGND);
    bars[i].w = util[i]*BAR_MAX_LEN/100;
    SDL_FillRect(screen, bars+i, util_to_color(util[i]));
  }
  SDL_UpdateRect(screen, 0, 0, 0, 0);
}


int main(int argc, char *argv[]) {
  int util[MAX_NCPU], ncpu; 

  screen = SDL_SetVideoMode(W, H, 32, SDL_HWSURFACE);
  SDL_FillRect(screen, NULL, 0);
  SDL_UpdateRect(screen, 0, 0, 0, 0);

  init_bars(); 

  while (1) {
    SDL_Event ev;
    while (SDL_PollEvent(&ev)) {
      if (ev.type == SDL_KEYDOWN) {
        switch (ev.key.keysym.sym) {
          case SDLK_q: goto cleanup; break; 
        }
      }
    }
    SDL_Delay(1000 / FPS);
    read_cpuinfo(util, &ncpu); 
    // for (int i=0; i<ncpu; i++) printf("%d ", util[i]);  // debugging
    // printf("\n"); 
    visualize(util, ncpu);
  }

cleanup:
  SDL_Quit();

  return 0;
}