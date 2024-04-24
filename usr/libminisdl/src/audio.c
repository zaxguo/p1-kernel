// #include <NDL.h>
#include <SDL.h>

static int sb = -1; // fd for /dev/sb/ 

// 0 on success 
int sdl_init_audio(void) {
  if ((sb = open("/dev/sb/", O_RDWR)) <= 0)  return -1; 

  if (config_sbctl(SB_CMD_INIT, 0 /*dont care*/) != 0) return -1; 
  // TBD: readback sbctl and check status
  return 0; 
}

int SDL_OpenAudio(SDL_AudioSpec *desired, SDL_AudioSpec *obtained) {

  // call int read_sbctl(struct sbctl_config *cfg) {
  return 0;
}

void SDL_CloseAudio() {
}

void SDL_PauseAudio(int pause_on) {
}

void SDL_MixAudio(uint8_t *dst, uint8_t *src, uint32_t len, int volume) {
}

SDL_AudioSpec *SDL_LoadWAV(const char *file, SDL_AudioSpec *spec, uint8_t **audio_buf, uint32_t *audio_len) {
  return NULL;
}

void SDL_FreeWAV(uint8_t *audio_buf) {
}

void SDL_LockAudio() {
}

void SDL_UnlockAudio() {
}
