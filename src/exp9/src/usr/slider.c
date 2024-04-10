// display a sequence of slides (as bmps), controlled by usb keyboard
// inspired by nslider 
//
// an example of self contained user app
//  low dep (no newlib, minisdl, snprintf, sscanf)
// as such, this file includes small implementation of common functions like atoi
//  Mar 2024 xzl
//
// https://github.com/NJU-ProjectN/navy-apps/blob/master/apps/nslider/src/main.cpp
// how to gen slides: see slides/conver.sh 

// USAGE:
//   j/down - page down
//   k/up - page up
//   gg - first page
//   (xzl): number then j/k to jmp fwd/back by X slides

#include <stdint.h> 
#include <assert.h>

#include "../param.h"
#include "../stat.h"
#include "../fcntl.h"
#include "../fs.h"
#include "user.h"

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

// load bmp file into a packed buf. expect 24bit color depth
// return:  pixel buffer. 
// caller must free the buffer 
void* BMP_Load(const char *filename, int *width, int *height) {
  int nread; 
  int fd = open(filename, O_RDONLY);
  if (fd<0) return 0; 

  struct BitmapHeader hdr;
  assert(sizeof(hdr) == 54);
  nread = read(fd, &hdr, sizeof hdr); 
  assert(nread == sizeof(hdr)); 

  if (hdr.bitcount != 24) return 0;
  if (hdr.compression != 0) return 0;
  int w = hdr.width;
  int h = hdr.height;
  uint32_t *pixels = malloc(w * h * sizeof(uint32_t));  // each pixel 4bytes
  assert(pixels); 
  
  int line_off = (w * 3 + 3) & ~0x3;
  for (int i = 0; i < h; i ++) {
    lseek(fd, hdr.offset + (h - 1 - i) * line_off, SEEK_SET);
    nread = read(fd, &pixels[w * i], 3*w);  assert(nread==3*w); // read a row
    // reshape a row: from pixel r/g/b to 0/r/g/b 
    for (int j = w - 1; j >= 0; j --) {
      uint8_t b = *(((uint8_t*)&pixels[w * i]) + 3 * j);
      uint8_t g = *(((uint8_t*)&pixels[w * i]) + 3 * j + 1);
      uint8_t r = *(((uint8_t*)&pixels[w * i]) + 3 * j + 2);
      pixels[w * i + j] = (r << 16) | (g << 8) | b;
    }
  }

  close(fd); 
  if (width) *width = w;
  if (height) *height = h;
  return pixels;
}

//// main loop

// will be used as virt fb size
#define W 400
#define H 300

const int N = 10; // max slide num 
// slides path pattern (starts from 1, per pptx export naming convention)
const char *path = "/Slide%d.bmp";

int dispinfo[MAX_DISP_ARGS]={0};

static int cur = 1;   // cur slide num 
static int fb = 0; 

void render() {
  char fname[256];
  int w, h; 
  sprintf(fname, (char *)path, cur);
  char *pixels = BMP_Load(fname, &w, &h); 
  if (!pixels) {printf("load from %s failed\n", fname); return;}

  // crop img data per the framebuf size  
  int vwidth= dispinfo[VWIDTH], vheight = dispinfo[VHEIGHT]; 
  int pitch = dispinfo[PITCH]; 
  int fb_w = min(vwidth,w), fb_h = min(vheight,h); // actual size for visible area

  printf("%s:size: w %d h %d; canvas w %d h %d\n", fname, w, h, fb_w, fb_h); 

  assert(fb); 
  int n, y; 
  // write to /dev/fb by row 
  for(y=0;y<fb_h;y++) {
    n = lseek(fb, y*pitch, SEEK_SET); assert(n>=0); 
    if (write(fb, pixels+y*w*PIXELSIZE, fb_w*PIXELSIZE) < fb_w*PIXELSIZE) {
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
  if (cur <= 0) cur = 1;
  render();
}

void next(int rep) {
  if (rep == 0) rep = 1;
  cur += rep;
  if (cur > N) cur = N;
  render();
}

int main() {
  int n;
  int rep = 0, g = 0; // rep: num of slides to skip
  // char buf[LINESIZE], *s=buf; 
  int evtype;
  unsigned scancode; 

  int events = open("/dev/events", O_RDONLY); 
  // int dp = open("/proc/dispinfo", O_RDONLY); 
  // int fbctl = open("/proc/fbctl", O_RDWR); 
  fb = open("/dev/fb/", O_RDWR); //printf("fb is %d\n", fb); 
  assert(fb>0 && events>0); 

  // config fb 
  // n = config_fbctl(fbctl, 1360, 768, W, H, 0, 0); assert(n==0); 
  n = config_fbctl(W, H, W, H, 0, 0); assert(n==0); 
  // close(fbctl); 

  // after config, read dispinfo again (GPU may specify different dims)
  // parse /proc/dispinfo into dispinfo[]
  // n=read(dp, buf, LINESIZE); assert(n>0); 
  // // parse the 1st line to a list of int args... (ignore other lines
  // for (s = buf; s < buf+n; s++) {
  //     if (*s=='\n' || *s=='\0')
  //         break;         
  //     if ('0' <= *s && *s <= '9') { // start of a num
  //         dispinfo[nargs] = atoi(s); // printf("got arg %d\n", dispinfo[nargs]);             
  //         while ('0' <= *s && *s <= '9' && s<buf+n) 
  //             s++; 
  //         if (nargs++ == MAX_ARGS)
  //             break; 
  //     } 
  // }
  read_dispinfo(dispinfo, &n); assert(n>0);
  printf("/proc/dispinfo: width %d height %d vwidth %d vheight %d pitch %d\n", 
    dispinfo[WIDTH], dispinfo[HEIGHT], dispinfo[VWIDTH], dispinfo[VWIDTH], dispinfo[PITCH]); 

  render();
  
  // main loop. handle keydown event, switch among bmps
  while (1) {
    evtype = INVALID; scancode = 0; //invalid

    // read a line from /dev/events and parse it into key events
    // line format: [kd|ku] 0x12
    // n = read(events, buf, LINESIZE); assert(n>0); 
    // s=buf;         
    // if (buf[0]=='k' && buf[1]=='d') {
    //   evtype = KEYDOWN; 
    // } else if (buf[0]=='k' && buf[1]=='u') {
    //   evtype = KEYUP; 
    // } 
    // s += 2; while (*s==' ') s++; 
    // if (s[0]=='0' && s[1]=='x')
    //   scancode = atoi16(s); 
    n = read_kb_event(events, &evtype, &scancode); assert(n==0); 
    if (!(scancode && evtype)) {
      printf("warning:"); 
      // printf("%s", buf); 
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
