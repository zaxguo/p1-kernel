// a simple music player that can do ogg
// idea: https://github.com/NJU-ProjectN/navy-apps/blob/master/apps/nplayer/src/main.c
//
// qemu lacks support for sound emulation (rpi3/4), so this can only be tried
// out on real hardware (which uses pwm 3.5mm jack for sound output)

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
int16_t *stream_save = NULL;    // xzl: recent stream (samples), saved for visualization 
int volume = MAX_VOLUME;

SDL_Surface *screen = NULL;

#ifdef HAS_VISUAL
static void drawVerticalLine(int x, int y0, int y1, uint32_t color) {
  assert(y0 <= y1);
  int i;
  uint32_t *p = (void *)screen->pixels;
  for (i = y0; i <= y1; i ++) {
    p[i * W + x] = color;
  }
}
#endif

static void visualize(int16_t *stream, int samples) {
#ifdef HAS_VISUAL
  int i;
  static int color = 0;
  SDL_FillRect(screen, NULL, 0);
  int center_y = H / 2;
  for (i = 0; i < samples; i ++) {
    // fixedpt multipler = fixedpt_cos(fixedpt_divi(fixedpt_muli(FIXEDPT_PI, 2 * i), samples));
    float multipler = cos(3.14*2*i/samples); 
    int x = i * W / samples;
    // int y = center_y - fixedpt_toint(fixedpt_muli(fixedpt_divi(fixedpt_muli(multipler, stream[i]), 32768), H / 2));
    int y = center_y - (int)((multipler * stream[i])/32768 *(H/2));
    if (y < center_y) drawVerticalLine(x, y, center_y, color);
    else drawVerticalLine(x, center_y, y, color);
    color ++;
    color &= 0xffffff;
  }
  SDL_UpdateRect(screen, 0, 0, 0, 0);
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

// xzl: "stream"  A pointer to the audio buffer to be filled. 
// len: buf length. 
void FillAudio(void *userdata, uint8_t *stream, int len) {
  int nbyte = 0;
  // xzl: call vorbis to fill "stream"...
  int samples_per_channel = stb_vorbis_get_samples_short_interleaved(v,
      info.channels, (int16_t *)stream, len / sizeof(int16_t));
  if (samples_per_channel != 0 || len < sizeof(int16_t)) {
    int samples = samples_per_channel * info.channels;
    nbyte = samples * sizeof(int16_t);
    AdjustVolume((int16_t *)stream, samples);
  } else {
    is_end = 1;
  }
  // xzl: zero fill the remaining stream
  if (nbyte < len) memset(stream + nbyte, 0, len - nbyte);
  memcpy(stream_save, stream, len);
  // xzl: make a copy? for visualization?
}

int main(int argc, char *argv[]) {
  char *path = (argc>1) ? argv[1] : MUSIC_PATH; 
  FILE *fp = fopen(path, "r");
  if (!fp) {
    printf("failed to open file %s\n", path); 
    return -1; 
  } 

  SDL_Init(SDL_INIT_AUDIO);
#if HAS_VISUAL  
  screen = SDL_SetVideoMode(W, H, 32, SDL_HWSURFACE);
  SDL_FillRect(screen, NULL, 0);
  SDL_UpdateRect(screen, 0, 0, 0, 0);
#endif

  fseek(fp, 0, SEEK_END);
  size_t size = ftell(fp);
  void *buf = malloc(size);  // alloc buf as large as the file
  assert(size); printf("ogg file %lu KB, malloc ok\n", size/1024);
  fseek(fp, 0, SEEK_SET);
  int ret = fread(buf, size, 1, fp);
  assert(ret == 1);
  fclose(fp);

  int error;
  v = stb_vorbis_open_memory(buf, size, &error, NULL);
  assert(v);
  info = stb_vorbis_get_info(v);

  SDL_AudioSpec spec;
  spec.freq = info.sample_rate;
  spec.channels = info.channels;
  spec.samples = SAMPLES;
  spec.format = AUDIO_S16SYS;
  spec.userdata = NULL;
  spec.callback = FillAudio;
  SDL_OpenAudio(&spec, NULL);

  stream_save = malloc(SAMPLES * info.channels * sizeof(*stream_save));
  assert(stream_save);
  printf("Playing %s(freq = %d, channels = %d)...\n", MUSIC_PATH, info.sample_rate, info.channels);
  
  int pause_on = 0; 

  SDL_PauseAudio(pause_on); pause_on=1-pause_on; 

  while (!is_end) {
    SDL_Event ev;
    while (SDL_PollEvent(&ev)) {
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
    visualize(stream_save, SAMPLES * info.channels);
  }

cleanup:
  SDL_CloseAudio();
  stb_vorbis_close(v);
  SDL_Quit();
  free(stream_save);
  free(buf);

  return 0;
}