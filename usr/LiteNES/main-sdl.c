/*
  the sdl version of main.c 
  cf comments in main.c
*/

#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include "fce.h"
#include "nes.h"
#include "common.h"   

#include "mario-rom.h"    // built-in rom buffer with Super Mario

#if 0   // TODO. Our OS lacks signal
void do_exit() // normal exit at SIGINT
{
    kill(getpid(), SIGKILL);
}
#endif

/* PC Screen Font as used by Linux Console */
typedef struct {
    unsigned int magic;
    unsigned int version;
    unsigned int headersize;
    unsigned int flags;
    unsigned int numglyph;
    unsigned int bytesperglyph;
    unsigned int height;
    unsigned int width;
    unsigned char glyphs;
} __attribute__((packed)) psf_t;

psf_t *font = 0; 

// return 0 on success
int load_font(const char *path) {
  int ret; 

  FILE *fp = fopen(path, "r");
  if (!fp) return -1;
  
  /* read the whole font file  */
  fseek(fp, 0, SEEK_END);
  size_t size = ftell(fp);
  font = (psf_t *)malloc(size);  // alloc buf as large as the file
  assert(size); 
  fseek(fp, 0, SEEK_SET);
  ret = fread(font, size, 1, fp);
  assert(ret == 1);
  fclose(fp);

  printf("loaded font %s %lu KB magic 0x%x\n", path, size, font->magic);
  return 0; 
}

#ifndef PIXELSIZE
#define PIXELSIZE 4 /*ARGB, expected by /dev/fb*/ 
#endif

/* Display a string using fixed size PSF update x,y screen coordinates
  x/y IN|OUT: the postion before/after the screen output
  TBD: transparent rendering (no black bkgnd)
*/
void fb_print(unsigned char *fb, int *x, int *y, char *s)
{
    unsigned pitch = SCREEN_WIDTH*PIXELSIZE; 

    // draw next character if it's not zero
    while(*s) {
        // get the offset of the glyph. Need to adjust this to support unicode table
        unsigned char *glyph = (unsigned char*)font +
         font->headersize + (*((unsigned char*)s)<font->numglyph?*s:0)*font->bytesperglyph;
        // calculate the offset on screen
        int offs = (*y * pitch) + (*x * 4);
        // variables
        int i,j, line,mask, bytesperline=(font->width+7)/8;
        // handle carrige return
        if(*s == '\r') {
            *x = 0;
        } else
        // new line
        if(*s == '\n') {
            *x = 0; *y += font->height;
        } else {
            // display a character
            for(j=0;j<font->height;j++){
                // display one row of pixels
                line=offs;
                mask=1<<(font->width-1);
                for(i=0;i<font->width;i++){
                    // if bit set, we use white color, otherwise black
                    // xzl: "mask" extracts a bit from the glyph. if the bit is 
                    // set (1), meaning the pixel should be drawn; otherwise not
                    // *((unsigned int*)(fb + line))=((int)*glyph) & mask?0xFFFFFF:0;
                    // xzl: below: only draw a pixel if the bit is set; otherwise
                    //  do NOT draw
                    if (((int)*glyph) & mask)
                      *((unsigned int*)(fb + line))=0x00FF0000; // red
                    mask>>=1;
                    line+=4;
                }
                // adjust to next line
                glyph+=bytesperline;
                offs+=pitch;
            }
            *x += (font->width+1);
        }
        // next character
        s++;
    }
}

int xx=0, yy=0; 
int main(int argc, char *argv[])
{
    int fd; 

    if (argc < 2) {
        fprintf(stderr, "Usage: mynes romfile.nes\n");
        fprintf(stderr, "no rom file specified. use built-in rom\n"); 
        goto load; 
    }

    if (argc==4) { // screen locations given.
      xx=atoi(argv[2]); yy=atoi(argv[3]);
    }

    fprintf(stdout, "start %d %d %d....\n", xx, yy, argc); 

    if (strncmp(argv[1], "--", 3) == 0)
      goto load; 
    
    if ((fd = open(argv[1], O_RDONLY)) <0) {
        fprintf(stderr, "Open rom file failed.\n");
        return 1; 
    }

    int nread = read(fd, rom, sizeof(rom));     
    if (nread==0) { // Ok if rom smaller than buf size
      fprintf(stderr, "Read rom file failed.\n");
      return 1; 
    }
    printf("open rom...ok\n"); 

load: 
    if (fce_load_rom(rom) != 0) {
        fprintf(stderr, "Invalid or unsupported rom.\n");
        return 1; 
    }
    printf("load rom...ok\n"); 
    // signal(SIGINT, do_exit);

    load_font("font.psf");

    fce_init();

    printf("running fce ...\n"); 
    fce_run();
    return 0;
}
