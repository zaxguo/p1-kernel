/* A simple music player that can play ogg files
  based on: https://github.com/NJU-ProjectN/navy-apps/blob/master/apps/nplayer/src/main.c

  Usage (see main())

  Control (USB keyboard):
    - : volume down
    = : volume up
    p : pause / resume
    q : quit

  dependency: 
    rpi3 hardware. qemu lacks support for sound emulation (rpi3/4), so
  this can only be tried out on real hardware (which uses pwm 3.5mm jack for
  sound output) 
    sdl (abstraction for keyboard events, audio, and visualization)
    libvorbis (ogg playback)


  Some of the comments are by FL 
*/

#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <SDL.h>
#include <stb_vorbis.h>
#include "math.h"
// #include <fixedptc.h>           // xzl: for visualization 

#define MUSIC_PATH "/d/sample.ogg"
#define SAMPLES 4096
#define FPS 10
#define W 400
#define H 100
#define MAX_VOLUME 128

stb_vorbis *v = NULL;
stb_vorbis_info info = {};
int is_end = 0;

// Recent stream (samples), saved for visualization 
// written by SDL's audio thread, read by UI thread. needs lock
int16_t *stream_save = NULL;    
struct spinlock_u sslock = {.locked = 0};  // alternatively, we can use a semaphore
// int sem=-1; 

int volume = MAX_VOLUME;

// SDL_Surface *screen = NULL;
SDL_Window* window = NULL;
SDL_Renderer* renderer = NULL;

#ifdef HAS_VISUAL
static void drawVerticalLine(int x, int y0, int y1, uint32_t color /*abgr*/) {
  // NB: val is a/b/g/r. it does NOT matter here though. the caller just 
  // wants to create some changing colors
  assert(x>=0&& y0>=0 && y1>=0); 
  renderer->c.val = color; 
  SDL_RenderDrawLine(renderer,x,y0,x,y1);
}
#endif

static void visualeffect(int16_t *stream, int samples) {
#ifdef HAS_VISUAL
  int i;
  static int color = 0;
  SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0); // black bkgnd
  SDL_RenderClear(renderer); 
  int center_y = H / 2;
  spinlock_lock(&sslock);  // for accessing "stream"
  // sys_semp(sem);
  for (i = 0; i < samples; i ++) {
    float multipler = cos(3.14*2*i/samples); 
    int x = i * W / samples;
    // int y = center_y - fixedpt_toint(fixedpt_muli(fixedpt_divi(fixedpt_muli(multipler, stream[i]), 32768), H / 2));
    // int y = center_y - (int)((multipler * stream[i])/32768 *(H/2)); // result in overflow (y: large neg value), why?
    int y = center_y - (int)(multipler * stream[i]) *(H/2)/32768; 
    // if (y<0)     // TO DEL
    //   printf("multipler %.2f i %d stream[i] %d center_y %d y %d y00 %d %d %d samples %d\n", 
    //   multipler, i, stream[i], center_y, y, 
    //   (int)((multipler * stream[i])/32768 *(H/2)), 
    //   (int)(multipler * stream[i])/32768 *(H/2), 
    //   (int)(multipler * stream[i]) *(H/2)/32768, 
    //   samples
    //   );
    assert(y>=0 && y<=H);
    if (y < center_y) drawVerticalLine(x, y, center_y, color);
    else drawVerticalLine(x, center_y, y, color);
    color ++; color &= 0xffffff;
  }
  spinlock_unlock(&sslock);
  // sys_semv(sem);
  SDL_RenderPresent(renderer);
#endif  
}

// xzl: scale samples...
static void AdjustVolume(int16_t *stream, int samples) {
  if (volume == MAX_VOLUME) return;
  if (volume == 0) {
    memset(stream, 0, samples * sizeof(stream[0]));
    return;
  }
  int i;
  for (i = 0; i < samples; i ++) {
    stream[i] = stream[i] * volume / MAX_VOLUME;
  }
}

// Callback to be called by SDL's audio thread to fill its audio buffer. 
// stream:  A pointer to the audio buffer to be filled. 
// len: buf length. 
void FillAudio(void *userdata, uint8_t *stream, int len) {
  int nbyte = 0;
  // call vorbis to decode ogg & fill "stream"...
  int samples_per_channel = stb_vorbis_get_samples_short_interleaved(v,
      info.channels, (int16_t *)stream, len / sizeof(int16_t));
  if (samples_per_channel != 0 || len < sizeof(int16_t)) {
    int samples = samples_per_channel * info.channels;
    nbyte = samples * sizeof(int16_t);
    AdjustVolume((int16_t *)stream, samples);
  } else {
    is_end = 1;
  }
  // zero fill the remaining stream
  if (nbyte < len) memset(stream + nbyte, 0, len - nbyte);
  spinlock_lock(&sslock); 
  // sys_semp(sem);
  assert(stream_save); memcpy(stream_save, stream, len); // make a copy for visualization  
  spinlock_unlock(&sslock);
  // sys_semv(sem);
}

/* Usage
  # play /d/sample.ogg, visualize on hw surface
  ./nplayer 
  # play own sample, visualize on hw surface
  ./nplayer /d/angel.ogg 
  # play own sample, visualize on sw surface, offset at 10, 10
  ./nplayer /d/angel.ogg 10 10
*/
int main(int argc, char *argv[]) {
  char *path = (argc>1) ? argv[1] : MUSIC_PATH; 
  FILE *fp = fopen(path, "r");
  int ret, x=0, y=0, flags=(SDL_WINDOW_HWSURFACE|SDL_WINDOW_FULLSCREEN); 
  int evflags = SDL_EV_HW;

  if (!fp) {
    printf("failed to open file %s\n", path); 
    return -1; 
  } 

  if (argc>2) { // screen locations given. use sw surface
    x=atoi(argv[2]); y=atoi(argv[3]);
    flags=SDL_WINDOW_SWSURFACE;
    evflags = SDL_EV_SW; 
  }

  if (SDL_Init(SDL_INIT_AUDIO) != 0) {
    printf("WARNING -- %s: SDL_Init failed. No sound device?\n", __func__);
    // return -1;   // continue to run...
  }

#if HAS_VISUAL  
  // screen = SDL_SetVideoMode(W, H, 32, SDL_HWSURFACE); assert(screen); 
  // ret = SDL_FillRect(screen, NULL, 0); assert(ret==0); 
  // SDL_UpdateRect(screen, 0, 0, 0, 0);

  window = SDL_CreateWindow("SYSMON", x, y, W, H, flags); assert(window);
  renderer = SDL_CreateRenderer(window,-1/*index*/,0/*flags*/); assert(renderer);
  // SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
  // SDL_RenderClear(renderer);
#endif

  /* simple impl: read the whole .ogg file in one shot */
  fseek(fp, 0, SEEK_END);
  size_t size = ftell(fp);
  void *buf = malloc(size);  // alloc buf as large as the file
  assert(size); printf("ogg file %lu KB, malloc ok\n", size/1024);
  fseek(fp, 0, SEEK_SET);
  ret = fread(buf, size, 1, fp);
  assert(ret == 1);
  fclose(fp);

  /* will call stb_vorbis to decode ogg in pieces */
  int error;
  v = stb_vorbis_open_memory(buf, size, &error, NULL);
  assert(v);
  info = stb_vorbis_get_info(v);

  /* configure the audio device */
  SDL_AudioSpec spec;
  spec.freq = info.sample_rate;
  spec.channels = info.channels;
  spec.samples = SAMPLES;
  spec.format = AUDIO_S16SYS;
  spec.userdata = NULL;
  spec.callback = FillAudio; // will be called by SDL's audio thread

  // the segment of audio stream for visualization. must prep before 
  // the SDL audio thread launches
  // sem=sys_semcreate(1); assert(sem!=-1); 
  spinlock_lock(&sslock); 
  // sys_semp(sem);
  stream_save = malloc(SAMPLES * info.channels * sizeof(*stream_save));
  assert(stream_save);
  spinlock_unlock(&sslock);
  // sys_semv(sem);

  SDL_OpenAudio(&spec, NULL);

  printf("Playing %s(freq = %d, channels = %d)...\n", MUSIC_PATH, 
    info.sample_rate, info.channels);
  
  int pause_on = 0; 

  SDL_PauseAudio(pause_on); pause_on=1-pause_on; 

  while (!is_end) {
    SDL_Event ev;
    while (SDL_PollEvent(&ev, evflags)) {
      if (ev.type == SDL_KEYDOWN) {
        switch (ev.key.keysym.sym) {
          case SDLK_MINUS:  if (volume >= 8) volume -= 8; break;
          case SDLK_EQUALS: if (volume <= MAX_VOLUME - 8) volume += 8; break;
          case SDLK_p: SDL_PauseAudio(pause_on); pause_on=1-pause_on; break; 
          case SDLK_q: goto cleanup; break; 
        }
      }
    }
    SDL_Delay(1000 / FPS);
    visualeffect(stream_save, SAMPLES * info.channels);
  }

cleanup:
  SDL_CloseAudio();
  stb_vorbis_close(v);
  SDL_Quit();
  free(stream_save);
  free(buf);

  return 0;
}