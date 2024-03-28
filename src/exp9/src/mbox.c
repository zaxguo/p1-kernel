/*
 * Copyright (C) 2018 bzt (bztsrc@github)
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 */

 // https://github.com/raspberrypi/firmware/wiki/Mailboxes
// ref: https://github.com/RT-Thread/rt-thread/blob/master/bsp/raspberry-pi/raspi3-64/driver/mbox.c 
// ref: https://www.valvers.com/open-software/raspberry-pi/bare-metal-programming-in-c-part-5/#part-5armc-016

#include "plat.h"
#include "mmu.h"
#include "utils.h"
#include "spinlock.h"

static struct spinlock mboxlock = {.locked=0, .cpu=0, .name="mbox_lock"};

/* mailbox message buffer */
// xzl: dont have to be "coherent" mem?
volatile unsigned int  __attribute__((aligned(16))) mbox[36];

#define MMIO_BASE       0x3F000000
#define VIDEOCORE_MBOX  (MMIO_BASE+0x0000B880)
#define MBOX_READ       ((volatile unsigned int*)(PA2VA(VIDEOCORE_MBOX)+0x0))
#define MBOX_POLL       ((volatile unsigned int*)(PA2VA(VIDEOCORE_MBOX)+0x10))
#define MBOX_SENDER     ((volatile unsigned int*)(PA2VA(VIDEOCORE_MBOX)+0x14))
#define MBOX_STATUS     ((volatile unsigned int*)(PA2VA(VIDEOCORE_MBOX)+0x18))
#define MBOX_CONFIG     ((volatile unsigned int*)(PA2VA(VIDEOCORE_MBOX)+0x1C))
#define MBOX_WRITE      ((volatile unsigned int*)(PA2VA(VIDEOCORE_MBOX)+0x20))
#define MBOX_RESPONSE   0x80000000
#define MBOX_FULL       0x80000000
#define MBOX_EMPTY      0x40000000

// addr seen by gpu
#define BUS_ADDRESS(phys)   (((phys) & ~0xC0000000)  |  0xC0000000)

/**
 * Make a mailbox call. Use the "mbox" buffer for both request and response.
 * response overwrites request
 * Spin wait for mailbox hw.  
 * Returns 0 on failure, non-zero on success
 * 
 * caller must hold mboxlock
 */
int mbox_call(unsigned char ch)
{
    // the buf addr (pa) w/ ch (chan id) in LSB 
    // unsigned int r = (((unsigned int)((unsigned long)&mbox)&~0xF) | (ch&0xF));
    unsigned int r = (unsigned int)(VA2PA(&mbox)&~0xF) | (ch&0xF);
    r = BUS_ADDRESS(r); 
    /* wait until we can write to the mailbox */
    do{asm volatile("nop");}while(*MBOX_STATUS & MBOX_FULL);
    __asm__ volatile ("dmb sy" ::: "memory");    // mem barrier, ensuring msg in mem
    __asm_flush_dcache_range((void *)mbox, (char *)mbox + sizeof(mbox)); 

    /* write the address of our message to the mailbox with channel identifier */
    *MBOX_WRITE = r; 
    /* now wait for the response */
    while(1) {
        /* is there a response? */
        do{asm volatile("nop");}while(*MBOX_STATUS & MBOX_EMPTY);
        /* is it a response to our message? */
        if(r == *MBOX_READ) {
            V("r is 0x%x", r); 
            __asm_invalidate_dcache_range((void *)mbox, (char *)mbox + sizeof(mbox)); 
            /* is it a valid successful response? */
            return mbox[1]==MBOX_RESPONSE;
        } else {
            W("got an irrelvant msg. bug?"); 
        }
    }
    return 0;
}

///////////////////////////////////////////////////
// property interfaces via mbox
#define MBOX_REQUEST    0
#define CODE_RESPONSE_SUCCESS	0x80000000
#define CODE_RESPONSE_FAILURE	0x80000001
	
/* channels */
#define MBOX_CH_POWER   0
#define MBOX_CH_FB      1
#define MBOX_CH_VUART   2
#define MBOX_CH_VCHIQ   3
#define MBOX_CH_LEDS    4
#define MBOX_CH_BTNS    5
#define MBOX_CH_TOUCH   6
#define MBOX_CH_COUNT   7
#define MBOX_CH_PROP    8

/* tags */
#define MBOX_TAG_SETPOWER       0x28001
#define MBOX_TAG_SETCLKRATE     0x38002
#define MBOX_TAG_LAST           0

// in a successful resp, b31 is set; b30-0 is "value length in bytes"
#define VALUE_LENGTH_RESPONSE	(1 << 31)

#define PROPTAG_GET_FIRMWARE_REVISION	0x00000001
#define PROPTAG_GET_BOARD_MODEL		0x00010001
#define PROPTAG_GET_BOARD_REVISION	0x00010002
#define PROPTAG_GET_MAC_ADDRESS		0x00010003
#define PROPTAG_GET_BOARD_SERIAL	0x00010004
#define PROPTAG_GET_ARM_MEMORY		0x00010005
#define PROPTAG_GET_VC_MEMORY		0x00010006
#define PROPTAG_SET_POWER_STATE		0x00028001
    #define DEVICE_ID_SD_CARD	0
	#define DEVICE_ID_USB_HCD	3
    #define POWER_STATE_OFF		(0 << 0)
	#define POWER_STATE_ON		(1 << 0)
	#define POWER_STATE_WAIT	(1 << 1)
	#define POWER_STATE_NO_DEVICE	(1 << 1)	// in response
#define PROPTAG_GET_CLOCK_RATE		0x00030002
#define PROPTAG_GET_TEMPERATURE		0x00030006
#define PROPTAG_GET_EDID_BLOCK		0x00030020
#define PROPTAG_GET_DISPLAY_DIMENSIONS	0x00040003
#define PROPTAG_GET_COMMAND_LINE	0x00050001

///////////////////////////////////////////////////
//  a simple framebuffer 
//
#include "rev_uva_logo_color3-resized.h"

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
extern volatile unsigned char _binary_font_psf_start;

/* Scalable Screen Font (https://gitlab.com/bztsrc/scalable-font2) */
typedef struct {
    unsigned char  magic[4];
    unsigned int   size;
    unsigned char  type;
    unsigned char  features;
    unsigned char  width;
    unsigned char  height;
    unsigned char  baseline;
    unsigned char  underline;
    unsigned short fragments_offs;
    unsigned int   characters_offs;
    unsigned int   ligature_offs;
    unsigned int   kerning_offs;
    unsigned int   cmap_offs;
} __attribute__((packed)) sfn_t;

extern volatile unsigned char _binary_font_sfn_start; // linker script

struct fb_struct {
    unsigned char *fb;  // framebuffer, kernel va
    unsigned width, height, vwidth, vheight, pitch; 
    unsigned depth; 
    unsigned isrgb; 
    unsigned offsetx, offsety; 
    unsigned size; 
}; 

// 1024x768, phys WH = virt WH, offset (0,0)
static struct fb_struct the_fb = {
    .width = 1024,
    .height = 768, 
    .vwidth = 1024, 
    .vheight = 768,
    .depth = 32, 
    .offsetx = 0,
    .offsety = 0,
}; 

/**
 * For mailbox property interface,
 * cf: https://github.com/raspberrypi/firmware/wiki/Mailbox-property-interface
 * 
 * return 0 if succeeds. 
 */
static int do_fb_init(struct fb_struct *fbs)
{    
    if (!fbs) return -1; 

    acquire(&mboxlock); 

    mbox[0] = 35*4;     // size of the whole buf that follows
    mbox[1] = MBOX_REQUEST; // cpu->gpu request

    // a sequence of tags below 

    mbox[2] = 0x48003;  //set phy width & height
    mbox[3] = 8;        // total buf size of this tag
    mbox[4] = 8;        // req val size (needed?), to be overwritten as resp val size
    mbox[5] = fbs->width;           //(val) FrameBufferInfo.width
    mbox[6] = fbs->height;          //(val) FrameBufferInfo.height

    mbox[7] = 0x48004;  //set virt width & height
    mbox[8] = 8;
    mbox[9] = 8;
    mbox[10] = fbs->vwidth;        //FrameBufferInfo.virtual_width
    mbox[11] = fbs->vheight;         //FrameBufferInfo.virtual_height

    mbox[12] = 0x48009; //set virt offset
    mbox[13] = 8;
    mbox[14] = 8;
    mbox[15] = fbs->offsetx;           
    mbox[16] = fbs->offsety;           

    mbox[17] = 0x48005; //set depth
    mbox[18] = 4;
    mbox[19] = 4;
    mbox[20] = fbs->depth;       

    mbox[21] = 0x48006;     //set pixel order
    mbox[22] = 4;
    mbox[23] = 4;
    mbox[24] = 1;           //RGB, not BGR preferably

    mbox[25] = 0x40001;     //get framebuffer, gets alignment on request
    mbox[26] = 8;
    mbox[27] = 8;           // xzl: should be 4?? (req para size)
    mbox[28] = 4096;        //req: alignment; resp: FrameBufferInfo.pointer
    mbox[29] = 0;           //resp: FrameBufferInfo.size

    mbox[30] = 0x40008;     //get pitch
    mbox[31] = 4;
    mbox[32] = 4;
    mbox[33] = 0;           //FrameBufferInfo.pitch

    mbox[34] = MBOX_TAG_LAST;   // the end of tag seq

    // make call, then check some response vals that may fail
    if(mbox_call(MBOX_CH_PROP) 
        && mbox[20]==fbs->depth /*depth*/ 
        && mbox[28]!=0 /*framebuf*/) {
        // extract framebuf info from resp...
        mbox[28]&=0x3FFFFFFF;  
        fbs->fb = PA2VA((unsigned long)mbox[28]);   // save framebuf ptr
        fbs->width=mbox[5];
        fbs->height=mbox[6];
        fbs->pitch=mbox[33];
        fbs->vwidth=mbox[10];
        fbs->vheight=mbox[11];        
        fbs->isrgb=mbox[24];         // channel order        
        fbs->size = fbs->pitch * fbs->vheight; 
        I("OK. fb pa: 0x%08x pitch %u", mbox[28], mbox[33]); 
    } else {
        E("Unable to set screen resolution to 1024x768x32\n");
        return -2; 
    }
    release(&mboxlock); 
    if (reserve_phys_region(mbox[28], fbs->size)) {
        E("failed to reserve fb memory. already in use."); 
        return -1; 
    } else 
        return 0; 
}

int fb_init(void) {
    return do_fb_init(&the_fb); 
}

// Display a string using fixed size PSF update x,y screen coordinates
// x/y IN|OUT: the postion before/after the screen output
// void fb_print(struct fb_struct *fbs, int *x, int *y, char *s)
void fb_print(int *x, int *y, char *s)
{
    unsigned pitch = the_fb.pitch; 
    unsigned char *fb = the_fb.fb; 

    // get our font
    psf_t *font = (psf_t*)&_binary_font_psf_start;
    // draw next character if it's not zero
    while(*s) {
        // get the offset of the glyph. Need to adjust this to support unicode table
        unsigned char *glyph = (unsigned char*)&_binary_font_psf_start +
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
                // display one row
                line=offs;
                mask=1<<(font->width-1);
                for(i=0;i<font->width;i++){
                    // if bit set, we use white color, otherwise black
                    *((unsigned int*)(fb + line))=((int)*glyph) & mask?0xFFFFFF:0;
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

#if 0
/**
 * Display a string using proportional SSFN
 */
void lfb_proprint(int x, int y, char *s)
{
    // get our font
    sfn_t *font = (sfn_t*)&_binary_font_sfn_start;
    unsigned char *ptr, *chr, *frg;
    unsigned int c;
    unsigned long o, p;
    int i, j, k, l, m, n;

    while(*s) {
        // UTF-8 to UNICODE code point
        if((*s & 128) != 0) {
            if(!(*s & 32)) { c = ((*s & 0x1F)<<6)|(*(s+1) & 0x3F); s += 1; } else
            if(!(*s & 16)) { c = ((*s & 0xF)<<12)|((*(s+1) & 0x3F)<<6)|(*(s+2) & 0x3F); s += 2; } else
            if(!(*s & 8)) { c = ((*s & 0x7)<<18)|((*(s+1) & 0x3F)<<12)|((*(s+2) & 0x3F)<<6)|(*(s+3) & 0x3F); s += 3; }
            else c = 0;
        } else c = *s;
        s++;
        // handle carrige return
        if(c == '\r') {
            x = 0; continue;
        } else
        // new line
        if(c == '\n') {
            x = 0; y += font->height; continue;
        }
        // find glyph, look up "c" in Character Table
        for(ptr = (unsigned char*)font + font->characters_offs, chr = 0, i = 0; i < 0x110000; i++) {
            if(ptr[0] == 0xFF) { i += 65535; ptr++; }
            else if((ptr[0] & 0xC0) == 0xC0) { j = (((ptr[0] & 0x3F) << 8) | ptr[1]); i += j; ptr += 2; }
            else if((ptr[0] & 0xC0) == 0x80) { j = (ptr[0] & 0x3F); i += j; ptr++; }
            else { if((unsigned int)i == c) { chr = ptr; break; } ptr += 6 + ptr[1] * (ptr[0] & 0x40 ? 6 : 5); }
        }
        if(!chr) continue;
        // uncompress and display fragments
        ptr = chr + 6; o = (unsigned long)lfb + y * pitch + x * 4;
        for(i = n = 0; i < chr[1]; i++, ptr += chr[0] & 0x40 ? 6 : 5) {
            if(ptr[0] == 255 && ptr[1] == 255) continue;
            frg = (unsigned char*)font + (chr[0] & 0x40 ? ((ptr[5] << 24) | (ptr[4] << 16) | (ptr[3] << 8) | ptr[2]) :
                ((ptr[4] << 16) | (ptr[3] << 8) | ptr[2]));
            if((frg[0] & 0xE0) != 0x80) continue;
            o += (int)(ptr[1] - n) * pitch; n = ptr[1];
            k = ((frg[0] & 0x1F) + 1) << 3; j = frg[1] + 1; frg += 2;
            for(m = 1; j; j--, n++, o += pitch)
                for(p = o, l = 0; l < k; l++, p += 4, m <<= 1) {
                    if(m > 0x80) { frg++; m = 1; }
                    if(*frg & m) *((unsigned int*)p) = 0xFFFFFF;
                }
        }
        // add advances
        x += chr[4]+1; y += chr[5];
    }
}
#endif

#define IMG_DATA img_data      
#define IMG_HEIGHT img_height
#define IMG_WIDTH img_width

void fb_showpicture()
{
    int x,y;
    unsigned char *ptr=the_fb.fb;
    char *data=IMG_DATA, pixel[4];
    // fill framebuf. crop img data per the framebuf size
    unsigned int img_fb_height = the_fb.vheight < IMG_HEIGHT ? the_fb.vheight : IMG_HEIGHT; 
    unsigned int img_fb_width = the_fb.vwidth < IMG_WIDTH ? the_fb.vwidth : IMG_WIDTH; 

    // xzl: copy the image pixels to the start (top) of framebuf    
    //ptr += (vheight-img_fb_height)/2*pitch + (vwidth-img_fb_width)*2;  
    ptr += (the_fb.vwidth-img_fb_width)*2;  
    
    for(y=0;y<img_fb_height;y++) {
        for(x=0;x<img_fb_width;x++) {
            HEADER_PIXEL(data, pixel);
            // the image is in RGB. So if we have an RGB framebuffer, we can copy the pixels
            // directly, but for BGR we must swap R (pixel[0]) and B (pixel[2]) channels.
            *((unsigned int*)ptr)=the_fb.isrgb ? *((unsigned int *)&pixel) : (unsigned int)(pixel[0]<<16 | pixel[1]<<8 | pixel[2]);
            ptr+=4;
        }
        ptr+=the_fb.pitch-img_fb_width*4;
    }
    __asm_flush_dcache_range(the_fb.fb, the_fb.fb + the_fb.size); 
}

/////////////////////////////
// other property tag operations. 
// xzl TODO: add lock??

// 0 on success, <0 on errors
int set_powerstate_on(unsigned deviceid) {
    int ret = 0; 
    unsigned power = (POWER_STATE_ON | POWER_STATE_WAIT); 

    acquire(&mboxlock); 

    mbox[0] = 8*4;
    mbox[1] = MBOX_REQUEST;

    mbox[2] = PROPTAG_SET_POWER_STATE; 
    mbox[3] = 8; 
    mbox[4] = 8; 
    mbox[5] = deviceid; 
    mbox[6] = power;

    mbox[7] = MBOX_TAG_LAST;   // the end of tag seq

    // make call, then check some response vals that may fail
    if(!mbox_call(MBOX_CH_PROP))
        {ret = -1; goto fail;}
    // routine checks 
    if (mbox[1] != CODE_RESPONSE_SUCCESS)
        {ret = -2; goto fail;}
    if (!(mbox[4] & VALUE_LENGTH_RESPONSE)) 	// resp bit not set
        {ret = -3; goto fail;}
    if ((mbox[4] &= ~VALUE_LENGTH_RESPONSE) == 0)  // resp val length is 0 
        {ret = -4; goto fail;}
    // resp checks
    power = mbox[6];
    if (power & POWER_STATE_NO_DEVICE)
        {ret = -5; goto fail;}
    if (!(power & POWER_STATE_ON))
        {ret = -6; goto fail;}

    release(&mboxlock); 
    return 0; 
fail:
    release(&mboxlock); 
    W("%s failed. %d", __func__, ret); 
    return ret; 
}

// 0 on success, <0 on errors
int get_mac_addr(unsigned char buf[MAC_SIZE]) {
    int ret = 0; 

    acquire(&mboxlock); 
    mbox[0] = 8*4;
    mbox[1] = MBOX_REQUEST;

    mbox[2] = PROPTAG_GET_MAC_ADDRESS; 
    mbox[3] = 8;                // total buf size of this tag
    mbox[4] = 0;                // req val size, to be overwritten as resp val size
    mbox[5] = 0;                // for returned mac addr
    mbox[6] = 0;                // for returned mac addr. 2 bytes padding

    mbox[7] = MBOX_TAG_LAST;   // the end of tag seq    

    // make call, then check some response vals that may fail
    if(!mbox_call(MBOX_CH_PROP))
        {ret = -1; W("mbox[1] 0x%x  mbox[5] 0x%x", mbox[1], mbox[5]); goto fail;}
    // routine checks 
    if (mbox[1] != CODE_RESPONSE_SUCCESS)
        {ret = -2; goto fail;}
    if (!(mbox[4] & VALUE_LENGTH_RESPONSE)) 	// resp bit not set
        {ret = -3; goto fail;}
    if ((mbox[4] &= ~VALUE_LENGTH_RESPONSE) == 0)  // resp val length is 0 
        {ret = -4; goto fail;}
    // resp checks
    if (mbox[4] != MAC_SIZE)      
        {ret = -5; goto fail;}
    memmove(buf, (void *)&mbox[5], MAC_SIZE); 

    release(&mboxlock); 
    return 0; 
fail:
    release(&mboxlock); 
    W("%s failed. %d", __func__, ret); 
    return ret; 
}

// return 0 on success
int get_board_serial(unsigned long *s) {
    if (!s) return -1;

    acquire(&mboxlock); 

    // get the board's unique serial number with a mailbox call
    mbox[0] = 8*4;                  // length of the message
    mbox[1] = MBOX_REQUEST;         // this is a request message
    
    mbox[2] = PROPTAG_GET_BOARD_SERIAL;   // get serial number command
    mbox[3] = 8;                    // buffer size
    mbox[4] = 8;
    mbox[5] = 0;                    // clear output buffer
    mbox[6] = 0;

    mbox[7] = MBOX_TAG_LAST;

    // send the message to the GPU and receive answer
    if (mbox_call(MBOX_CH_PROP)) {      
        release(&mboxlock);   
        memmove(s, (void*)&mbox[5], 8); 
        return 0; 
    } else {
        release(&mboxlock); 
        return -2; 
    }
}

