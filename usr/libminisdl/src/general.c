// #include <NDL.h>
#include "SDL.h"
#include "stdio.h"

int SDL_Init(uint32_t flags) {
  // return NDL_Init(flags);
  return 0; 
}

void SDL_Quit() {
  // NDL_Quit();
  printf("sdl quit\n"); 
}

char *SDL_GetError() {
  return "Navy does not support SDL_GetError()";
}

int SDL_SetError(const char* fmt, ...) {
  return -1;
}

int SDL_ShowCursor(int toggle) {
  return 0;
}

void SDL_WM_SetCaption(const char *title, const char *icon) {
}
