struct fb_struct {
    unsigned char *fb;  // framebuffer, kernel va
    unsigned width, height, vwidth, vheight, pitch; 
    unsigned scr_width, scr_height; // screen dimension probed before init fb
    unsigned depth; 
    unsigned isrgb; 
    unsigned offsetx, offsety; 
    unsigned size; 
}; 

extern struct fb_struct the_fb; //mbox.c
extern struct spinlock mboxlock; 