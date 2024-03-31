// inspired by nslider 
// but removed as much dep as possible (newlib, minisdl)
// https://github.com/NJU-ProjectN/navy-apps/blob/master/apps/nslider/src/main.cpp

#include <stdint.h> 
#include <assert.h>

#include "../param.h"
#include "../stat.h"
#include "../fcntl.h"
#include "../fs.h"
#include "user.h"

/// assert 
void __assert_fail(const char * assertion, const char * file, 
  unsigned int line, const char * function) {  
  printf("assertion failed: %s at %s:%d\n", assertion, file, (int)line); 
  exit(1); 
}

////////// bmp load 

struct BitmapHeader {
  uint16_t type;
  uint32_t filesize;
  uint32_t resv_1;
  uint32_t offset;
  uint32_t ih_size;
  uint32_t width;
  uint32_t height;
  uint16_t planes;
  uint16_t bitcount; // 1, 4, 8, or 24
  uint32_t compression;
  uint32_t sizeimg;
  uint32_t xres, yres;
  uint32_t clrused, clrimportant;
} __attribute__((packed));

// xzl: load bmp file into a packed buf. expect 24bit color depth
// return pixel buffer. 
// caller must free the buffer 
void* BMP_Load(const char *filename, int *width, int *height) {
//   FILE *fp = fopen(filename, "r");  
//   if (!fp) return NULL;
  int nread; 
  int fd = open(filename, O_RDONLY);
  if (fd<0) return 0; 

  struct BitmapHeader hdr;
  assert(sizeof(hdr) == 54);
  // assert(1 == fread(&hdr, sizeof(struct BitmapHeader), 1, fp));
  nread = read(fd, &hdr, sizeof hdr); 
  assert(nread == sizeof(hdr)); 

  if (hdr.bitcount != 24) return 0;
  if (hdr.compression != 0) return 0;
  int w = hdr.width;
  int h = hdr.height;
  uint32_t *pixels = malloc(w * h * sizeof(uint32_t));  // xzl: each pixel 4bytes
  assert(pixels); 
  
  int line_off = (w * 3 + 3) & ~0x3;
  for (int i = 0; i < h; i ++) {
    // fseek(fp, hdr.offset + (h - 1 - i) * line_off, SEEK_SET);
    lseek(fd, hdr.offset + (h - 1 - i) * line_off, SEEK_SET);
    // nread = fread(&pixels[w * i], 3, w, fp);
    nread = read(fd, &pixels[w * i], 3*w);  assert(nread==3*w); // read a row
    // reshape row: pixel r/g/b as 0/r/g/b 
    for (int j = w - 1; j >= 0; j --) {
      uint8_t b = *(((uint8_t*)&pixels[w * i]) + 3 * j);
      uint8_t g = *(((uint8_t*)&pixels[w * i]) + 3 * j + 1);
      uint8_t r = *(((uint8_t*)&pixels[w * i]) + 3 * j + 2);
      pixels[w * i + j] = (r << 16) | (g << 8) | b;
    }
  }

  // fclose(fp);
  close(fd); 
  if (width) *width = w;
  if (height) *height = h;
  return pixels;
}


// scancode defs: 
// https://gist.github.com/MightyPork/6da26e382a7ad91b5496ee55fdc73db2
#define KEY_A 0x04 // Keyboard a and A
#define KEY_B 0x05 // Keyboard b and B
#define KEY_C 0x06 // Keyboard c and C
#define KEY_D 0x07 // Keyboard d and D
#define KEY_E 0x08 // Keyboard e and E
#define KEY_F 0x09 // Keyboard f and F
#define KEY_G 0x0a // Keyboard g and G
#define KEY_H 0x0b // Keyboard h and H
#define KEY_I 0x0c // Keyboard i and I
#define KEY_J 0x0d // Keyboard j and J
#define KEY_K 0x0e // Keyboard k and K
#define KEY_L 0x0f // Keyboard l and L
#define KEY_M 0x10 // Keyboard m and M
#define KEY_N 0x11 // Keyboard n and N
#define KEY_O 0x12 // Keyboard o and O
#define KEY_P 0x13 // Keyboard p and P
#define KEY_Q 0x14 // Keyboard q and Q
#define KEY_R 0x15 // Keyboard r and R
#define KEY_S 0x16 // Keyboard s and S
#define KEY_T 0x17 // Keyboard t and T
#define KEY_U 0x18 // Keyboard u and U
#define KEY_V 0x19 // Keyboard v and V
#define KEY_W 0x1a // Keyboard w and W
#define KEY_X 0x1b // Keyboard x and X
#define KEY_Y 0x1c // Keyboard y and Y
#define KEY_Z 0x1d // Keyboard z and Z

#define KEY_1 0x1e // Keyboard 1 and !
#define KEY_2 0x1f // Keyboard 2 and @
#define KEY_3 0x20 // Keyboard 3 and #
#define KEY_4 0x21 // Keyboard 4 and $
#define KEY_5 0x22 // Keyboard 5 and %
#define KEY_6 0x23 // Keyboard 6 and ^
#define KEY_7 0x24 // Keyboard 7 and &
#define KEY_8 0x25 // Keyboard 8 and *
#define KEY_9 0x26 // Keyboard 9 and (
#define KEY_0 0x27 // Keyboard 0 and )

#define KEY_RIGHT 0x4f // Keyboard Right Arrow
#define KEY_LEFT 0x50 // Keyboard Left Arrow
#define KEY_DOWN 0x51 // Keyboard Down Arrow
#define KEY_UP 0x52 // Keyboard Up Arrow


//// main loop

#define W 400
#define H 300

// USAGE:
//   j/down - page down
//   k/up - page up
//   gg - first page
//   (xzl): number then j/k to jmp fwd/back by X slides

// number of slides
const int N = 10;
// slides path pattern (starts from 0)
// const char *path = "/slides/slides-%d.bmp";
const char *path = "/Slide%d.bmp";

// display config
// the field of /proc/dispinfo. order must be right
#define MAX_ARGS   8
enum{WIDTH=0,HEIGHT,VWIDTH,VHEIGHT,SWIDTH,SHEIGHT,PITCH,DEPTH,ISRGB}; 
int dispinfo[MAX_ARGS]={0};

#define PIXELSIZE 4 /*ARGB*/ 

// static SDL_Surface *slide = NULL;
static int cur = 0;   // cur slide num 
static int fb; 

#define min(a, b) ((a) < (b) ? (a) : (b))

void render() {
#if 0
  if (slide) {
    SDL_FreeSurface(slide);//free a prev surface
  }
  char fname[256];
  sprintf(fname, path, cur);
  slide = SDL_LoadBMP(fname);// cr a new surface
  assert(slide);
  SDL_UpdateRect(slide, 0, 0, 0, 0);
#endif  

  char fname[256];
  int w, h; 
  sprintf(fname, (char *)path, cur);
  char *pixels = BMP_Load(fname, &w, &h); 
  if (!pixels) {printf("load from %s failed\n", fname); return;}

  // crop img data per the framebuf size  
  int vwidth= dispinfo[VWIDTH], vheight = dispinfo[VHEIGHT]; 
  int pitch = dispinfo[PITCH]; 
  int fb_w = min(vwidth,w), fb_h = min(vheight,h); // the actual canvas

  printf("bmpsize: w %d h %d; canvas w %d h %d\n", w, h, fb_w, fb_h); 

  assert(fb); 
  int n, y; 
  for(y=0;y<fb_h;y++) {
    n = lseek(fb, y*pitch, SEEK_SET); assert(n>=0); 
    if (write(fb, pixels+y*w*PIXELSIZE, fb_w*PIXELSIZE) < sizeof(fb_w*PIXELSIZE)) {
      printf("failed to write (row %d) to fb\n", y); 
      break; 
    }    
  }
  free(pixels); 
  printf("show %s\n", fname);   
  // no need to close fb
}

void prev(int rep) {
  if (rep == 0) rep = 1;
  cur -= rep;
  if (cur < 0) cur = 0;
  render();
}

void next(int rep) {
  if (rep == 0) rep = 1;
  cur += rep;
  if (cur >= N) cur = N - 1;
  render();
}

#define LINESIZE 128

enum{INVALID=0,KEYDOWN,KEYUP};

int main() {
  int n, nargs = 0; 
  int rep = 0, g = 0; // rep: num of slides to skip
  char buf[LINESIZE], *s=buf; 
  int evtype; uint scancode; 

  fb = open("/dev/fb/", O_RDWR); 
  int events = open("/dev/events", O_RDONLY); 
  int dp = open("/proc/dispinfo", O_RDONLY); 
  assert(fb>0 && events>0 && dispinfo>0); 

  // parse /proc/dispinfo into dispinfo[]
  n=read(dp, buf, LINESIZE); assert(n>0); 
  close(dp);   
  // parse the 1st line of write to a list of int args... (ignore other lines
  for (s = buf; s < buf+n; s++) {
      if (*s=='\n' || *s=='\0')
          break;         
      if ('0' <= *s && *s <= '9') { // start of a num
          dispinfo[nargs] = atoi(s); // W("got arg %d", args[nargs]);             
          while ('0' <= *s && *s <= '9' && s<buf+n) 
              s++; 
          if (nargs++ == MAX_ARGS)
              break; 
      } 
  }
  printf("/proc/dispinfo: width %d height %d vwidth %d vheight %d pitch %d\n", 
    dispinfo[WIDTH], dispinfo[HEIGHT], dispinfo[VWIDTH], dispinfo[VWIDTH], dispinfo[PITCH]); 

  render();
  
  while (1) {
    evtype = INVALID; scancode = 0; //invalid

    // read a line from /dev/events and parse it into key events
    // line format: [kd|ku] 0x12
    n = read(events, buf, LINESIZE); assert(n>0); 
    s=buf;         
    if (buf[0]=='k' && buf[1]=='d') {
      evtype = KEYDOWN; 
    } else if (buf[0]=='k' && buf[1]=='u') {
      evtype = KEYUP; 
    } 
    s += 2; while (*s==' ') s++; 
    if (s[0]=='0' && s[1]=='x')
      scancode = atoi16(s); 
      
    if (!(scancode && evtype)) {
      printf("warning:"); 
      printf("%s", buf); 
      printf("ev %d scancode 0x%x\n", evtype, scancode); 
    }
    
    if (evtype == KEYDOWN) {
      switch(scancode) {
        case KEY_0: rep = rep * 10 + 0; break;
        case KEY_1: rep = rep * 10 + 1; break;
        case KEY_2: rep = rep * 10 + 2; break;
        case KEY_3: rep = rep * 10 + 3; break;
        case KEY_4: rep = rep * 10 + 4; break;
        case KEY_5: rep = rep * 10 + 5; break;
        case KEY_6: rep = rep * 10 + 6; break;
        case KEY_7: rep = rep * 10 + 7; break;
        case KEY_8: rep = rep * 10 + 8; break;
        case KEY_9: rep = rep * 10 + 9; break;
        case KEY_J:
        case KEY_DOWN: next(rep); rep = 0; g = 0; break;
        case KEY_K:
        case KEY_UP: prev(rep); rep = 0; g = 0; break;
        case KEY_G:
          g ++;
          if (g > 1) {
            prev(100000);
            rep = 0; g = 0;
          }
          break;
      }
    }
  }

  return 0;
}


