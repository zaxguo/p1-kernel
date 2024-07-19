/* 
  Display CPU usage, on serial console; display (/dev/fb or /deb/fb0)
  Depends on: SDL_xxx for drawing; libc (newlib)
*/

#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "SDL.h"
// #include <SDL-video.h>
#include "math.h"

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

#define FPS 10
#define W 200
#define H 80

// each cpu: a horizontal bar
// below in pixels
#define BAR_SPACING (W/20) 
#define BAR_ORIGIN_X  BAR_SPACING // top-left of bar 0, wrt to the current window
#define BAR_ORIGIN_Y  BAR_SPACING 
#define BAR_MAX_LEN (W-2*BAR_SPACING)
#define BAR_HEIGHT ((H-2*BAR_SPACING)/(MAX_NCPU)-BAR_SPACING)

static_assert(BAR_MAX_LEN>0 && BAR_HEIGHT>0);

// video.c 
#define rgba_to_pixel(r, g, b, a) \
    (((char)a << 24) | ((char)r << 16) | ((char)g << 8) | ((char)b))

#define max(a, b) ((a) > (b) ? (a) : (b))

#define COLOR_BKGND rgba_to_pixel(56,56,56,0)  // gray

static SDL_Rect bars[MAX_NCPU]; 

void init_bars(void) {
  for (int i = 0; i < MAX_NCPU; i++) {
    bars[i].x = BAR_ORIGIN_X; 
    bars[i].y = BAR_ORIGIN_Y + BAR_HEIGHT*i + BAR_SPACING*i; 

    bars[i].h = BAR_HEIGHT;
    bars[i].w = BAR_MAX_LEN;
  }
}

unsigned util_to_color(int util) {
  int r, g, b; 
  r = util*255 / 100; 
  g = 0; 
  b = 255 - r; 
  return rgba_to_pixel(r, g, b, 0); 
}

void visualize(int util[MAX_NCPU], int ncpus) {
  int i;
  static int last_util[MAX_NCPU];

  if (memcmp(last_util, util, sizeof(last_util)) == 0)  // why not working??
  // if(last_util[0]==util[0] && last_util[1]==util[1] && last_util[2]==util[2] && last_util[3]==util[3])
    return; 
  
  memcpy(last_util, util, sizeof(last_util)); 

  printf("%s redraw\n", __func__);

  for (i=0; i<ncpus; i++) {
    bars[i].w = BAR_MAX_LEN;
    SDL_FillRect(screen, bars+i, COLOR_BKGND);
    bars[i].w = util[i]*BAR_MAX_LEN/100;
    SDL_FillRect(screen, bars+i, util_to_color(util[i]));
  }
  SDL_UpdateRect(screen, 0, 0, 0, 0);
}

// visualize on the serial terminal 
#define BAR_MAX_LEN_CHAR 10 
void visual_console(int util[MAX_NCPU], int ncpus) {
  int i,j,len;
  // clear current line
  // https://stackoverflow.com/questions/1508490/erase-the-current-printed-console-line
  // printf("\33[2K\r");  // not working well??
  printf("\033[2J");  // reset the temrinal 
  for (i=0; i<ncpus; i++) {
    len = util[i]*BAR_MAX_LEN_CHAR/100;
    printf("cpu%d[",i); 
    for (j=0;j<len;j++) printf("*");
    for (j=0;j<BAR_MAX_LEN_CHAR-len;j++) printf(" ");
    printf("]   ");     
  }  
  printf("\n");
}

/* Usage: 
  ./sysmon [con|fb|fb0]
  con: visualize on serial console
  fb:  visualize on hw fb (/dev/fb)
  fb0:  visualize on surface (/dev/fb0)
*/
#define MOD_CON 1
#define MOD_FB 2
#define MOD_FB0 3

int mode=MOD_CON;

int main(int argc, char *argv[]) {
  int util[MAX_NCPU], ncpu; 

  if (argc>1) { 
    if (strcmp(argv[1], "con")==0) 
      mode=MOD_CON;
    else if (strcmp(argv[1], "fb")==0) 
      mode=MOD_FB; 
    else if (strcmp(argv[1], "fb0")==0) 
      mode=MOD_FB0; 
  }

  if (mode!=MOD_CON) {
    if (mode==MOD_FB)
      screen = SDL_SetVideoMode(W, H, 32, SDL_HWSURFACE);
    else 
      screen = SDL_SetVideoMode(W, H, 32, SDL_SWSURFACE|SDL_TRANSPARENCY);
      // screen = SDL_SetVideoMode(W, H, 32, SDL_SWSURFACE);

    assert(screen); 
    SDL_FillRect(screen, NULL, 0);
    SDL_UpdateRect(screen, 0, 0, 0, 0);
    init_bars(); 
  }

  // // test color bars -- OK. to del
  // util[0]=0;
  // while (1) {
  //   util[0]=(util[0]+5)%100;
  //   visualize(util, 4);
  //   msleep(1000);
  // }

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
    if (mode==MOD_CON)
      visual_console(util, ncpu);
    else 
      visualize(util, ncpu);
  }

cleanup:
  if (mode!=MOD_CON)
    SDL_Quit();

  return 0;
}