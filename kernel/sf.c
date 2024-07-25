// #define K2_DEBUG_WARN
// #define K2_DEBUG_VERBOSE
#define K2_DEBUG_INFO

/* 
    In-kernel surface flinger (SF). 
   each task configures desired surface size/loc via /proc/sfctl, 
   and writes their pixels to /dev/sf; 
   the SF maintains per-task buffers and composite them to the actual hw
   framebuffer (fb). 

   each pid: can only have at most 1 surface. 

   This helps demonstrate the idea of multitasking OS
*/

#include "plat.h"
#include "mmu.h"
#include "utils.h"
#include "spinlock.h"
#include "fb.h"
#include "kb.h"
#include "list.h"
#include "fcntl.h"
#include "sched.h"
#include "file.h"

struct region {
    int x,y,w,h;
}; 

int do_regions_intersect(struct region *r1, struct region *r2) {
    // Calculate bottom-right coordinates
    int r1_x2 = r1->x + r1->w;
    int r1_y2 = r1->y + r1->h;
    int r2_x2 = r2->x + r2->w;
    int r2_y2 = r2->y + r2->h;
    // Check if one rectangle is to the left of the other
    if (r1->x >= r2_x2 || r2->x >= r1_x2)
        return 0;
    // Check if one rectangle is above the other
    if (r1->y >= r2_y2 || r2->y >= r1_y2)
        return 0;
    return 1;
}

struct region regions_union(struct region *r1, struct region *r2) {
    int r1_x2 = r1->x + r1->w;
    int r1_y2 = r1->y + r1->h;
    int r2_x2 = r2->x + r2->w;
    int r2_y2 = r2->y + r2->h;
    struct region r; 
    r.x = MIN(r1->x, r2->x); 
    r.y = MIN(r1->y, r2->y); 
    r.w = MAX(r1_x2, r2_x2) - r.x; 
    r.h = MAX(r1_y2, r2_y2) - r.y;
    return r; 
}

struct sf_struct {
    unsigned char *buf; // kernel va
    // unsigned x,y,w,h; // with regard to (0,0) of the hw fb
    struct region r; // with regard to (0,0) of the hw fb
    int transparency;  // 0-100
    int dirty;  // redraw this surface? 
    int pid; // owner 
    int floating; // always on top?
    struct kb_struct kb; // kb events dispatched to this surface
    slist_t list;
    slist_t list1;  // to link sf on a tmplist, cf sf_composite()
}; 

// dimension of hw fb
#define VW 1024
#define VH 768

// bkgnd color, gray
#define BK_COLOR  0x00222222   

static struct spinlock sflock = {.locked=0, .cpu=0, .name="sflock"};
// ordered by z. tail: 0 (top most)
static slist_t sflist = SLIST_OBJECT_INIT(sflist);  
// static int bk_dirty = 1; // is background dirty? protected by sflock
/* the dirty region on the background. 
    when the bkgnd is dirty (e.g. a window moved, a window closed), often only a
    very small region in the bkgnd needs to be redrawn, e.g. the region exposed
    by the moved/closed window. if we only redraw such regions instead of the
    entire bkgnd, we can avoid overdrawing lots of surfaces atop the bkgnd 
*/    
// static struct {
//     int x,y,w,h;
// } bk_dirty = {.x=0, .y=0, .w=VW, .h=VH};

static struct region bk_dirty = {.x=0, .y=0, .w=VW, .h=VH};

extern int procfs_parse_fbctl(int args[PROCFS_MAX_ARGS]); // mbox.c
extern int sys_getpid(void);  // sys.c

// return 0 on success
static int reset_fb() {
    I("%s +++++ ", __func__);
    // hw fb setup
    int args[PROCFS_MAX_ARGS] = {
        VW, VH, /*w,h*/
        VW, VH, /*vw,vh*/
        0,0 /*offsetx, offsety*/
    }; 
    int ret = procfs_parse_fbctl(args);  // reuse the func
    I("%s +++++ done ", __func__);
    return ret; 
}

// find sf given pid, return 0 if no found
// caller MUST hold sflock
static struct sf_struct *find_sf(int pid) {
    slist_t *node = 0;
    struct sf_struct *sf = 0; 

    slist_for_each(node, &sflist) {
        sf = slist_entry(node, struct sf_struct/*struct name*/, list /*field name*/); BUG_ON(!sf);
        if (sf->pid == pid)
            return sf; 
    }
    return 0; 
}

// mark all sfs as dirty, to be redrawn
// caller MUST hold sflock
static void dirty_all_sf(void) {
    slist_t *node = 0;
    struct sf_struct *sf; 
    slist_for_each(node, &sflist) {
        sf = slist_entry(node, struct sf_struct/*struct name*/, list /*field name*/); BUG_ON(!sf);
        sf->dirty=1; 
    }
    // bk_dirty=1; 
}

extern struct kb_struct the_kb; // kb.c
int kb_task_quit = 0; // protected by the_kb.lock
int kb_task_id = -1;
static void kb_task(int arg); 

// zorder: ZORDER_BOTTOM, ZORDER_TOP, etc 
// trans: transparency, 0 (fully transparent)-100(fullyopaque)
// return 0 on success; <0 on err
static int sf_create(int pid, int x, int y, int w, int h, int zorder, int trans) {
    struct sf_struct *s = malloc(sizeof(struct sf_struct));     

    if (!s) {BUG();return -1;}
    s->buf = malloc(w*h*PIXELSIZE); if (!s->buf) {free(s);BUG();return -2;}
    s->r.x=x; s->r.y=y; s->r.w=w; s->r.h=h; s->pid=pid; 
    s->dirty=1; s->transparency=trans; s->floating=0; 
    s->kb.r=s->kb.w=0; // spinlock unused

    acquire(&sflock);
    if (find_sf(pid)) {
        free(s->buf); free(s); 
        release(&sflock); return -3;
    }

    // put new surface on the list of surfaces
    if (zorder == ZORDER_BOTTOM) { // list head
        slist_insert(&sflist, &s->list);         
    } else if (zorder == ZORDER_TOP) // list tail
        slist_append(&sflist, &s->list);  // no dirty needed
    else if (zorder == ZORDER_FLOATING) {
        s->floating = 1; slist_append(&sflist, &s->list);
    }
    else BUG(); 

    dirty_all_sf(); // XXX opt: sometimes we dont have to dirty all    

    if (slist_len(&sflist) == 1) { // reset the fb hw, if this is the 1st surface
        reset_fb();
        int res = copy_process(PF_KTHREAD, (unsigned long)&kb_task, 0/*arg*/,
        "[kb]"); BUG_ON(res<0); 
    }

    wakeup(&sflist); // notify flinger
    release(&sflock);
    W("cr ok. pid %d", pid); 
    return 0; 
}

// called by exit_process() (sched.c)
// return 0 on success; <0 on err
int sf_free(int pid)  {
    struct sf_struct *sf = 0;
    int ret;

    acquire(&sflock);
    sf = find_sf(pid); 
    if (sf) {
        slist_remove(&sflist, &sf->list);            
        if (slist_len(&sflist) == 0) { // no surface left
            // clean up hw fb        
            I("freed");fb_fini();
            // terminate the kb task
            acquire(&the_kb.lock);
            kb_task_quit = 1; 
            wakeup(&the_kb.r);
            release(&the_kb.lock);
            I("wait for kb task to finish...");
            int wpid=wait(0); BUG_ON(wpid<0);
        }  else {
            // dirty_all_sf(); 
            // dirty the bkgnd region occupied by the free'd surface
            // bk_dirty = sf->r; 
            bk_dirty = regions_union(&bk_dirty, &sf->r); 
        }
        
        if (sf->buf) free(sf->buf); 
        free(sf); 
        wakeup(&sflist);
        ret=0; 
    } else 
        ret=-1; 

    release(&sflock);
    return ret;
}

/*  return the buf size (in bytes) of a sf. 
    needed by filelseek() (file.c)
    caller must NOT hold sflock 
    return -1 on error */
int sf_size(int pid) {
    int ret = -1; 
    struct sf_struct *sf = 0;

    acquire(&sflock);
    sf = find_sf(pid); 
    if (!sf) 
        goto out; 
    ret = sf->r.w * sf->r.h * PIXELSIZE;
out:
    release(&sflock);
    return ret; 
}

// change pos/loc/zorder of an existing surface
// return 0 on success, <0 on error 
static int sf_config(int pid, int x, int y, int w, int h, int zorder) {
    struct sf_struct *sf = 0;

    acquire(&sflock);
    sf = find_sf(pid); 
    if (sf) {
        if (sf->r.w!=w || sf->r.h!=h) {
            // TBD resize sf: alloc new buf, free old buf...
            BUG(); 
        }
        sf->r.x=x; sf->r.y=y; sf->r.w=w; sf->r.h=h;
        if (zorder != ZORDER_UNCHANGED) { 
            // take the sf out and plug in back
            slist_remove(&sflist, &sf->list); 
            sf->dirty = 1; // sf_composite() will figure out redrawing other sf
            if (zorder == ZORDER_TOP)
                slist_append(&sflist, &sf->list); 
            else if (zorder == ZORDER_BOTTOM) 
                slist_insert(&sflist, &sf->list);
            else if (zorder == ZORDER_FLOATING) 
                sf->floating = 1;
            else BUG(); // ZORDER_INC, ZORDER_DEC ... TBD
        }
    }
    // dirty_all_sf(); // XXX opt: sometimes we dont have to dirty all 
    wakeup(&sflist); // notify flinger
    release(&sflock);
    if (!sf) return -1; // pid no found
    return 0; 
}

// mov the bottom surface to the top, which also moves focus to it 
// return 0 on success, <0 on error 
// call must NOT hold sflock
static int sf_alt_tab(void) {
    struct sf_struct *bot = 0;
    int ret; 
    
    V("%s", __func__); 
    acquire(&sflock);
    if (slist_len(&sflist) <= 1) {ret=0; goto out;}
    bot = slist_first_entry(&sflist, struct sf_struct, list); 
    slist_remove(&sflist, &bot->list); 
    slist_append(&sflist, &bot->list); 
    bot->dirty = 1; 
    // dirty_all_sf(); 
    wakeup(&sflist); 
    ret=0; 
out: 
    release(&sflock);
    return ret; 
}

// change the top surface location
// dir=0/1/2/3 R/L/Dn/Up  corresponding to their scancode order
// call must NOT hold sflock
#define STEPSIZE 5 // # of pixels to move, per key event
static int sf_move(int dir) {
    int ret=0; 
    struct sf_struct *top = 0;
    
    V("%s", __func__); 

    acquire(&sflock);
    if (slist_len(&sflist)==0) {ret=-1; goto out;}

    top = slist_tail_entry(&sflist, struct sf_struct, list); 
    struct region *r = &top->r, r0 = top->r; 
    switch(dir) {        
        case 0: // R
            // TBD: allow part of the surface to move out of the window 
            r->x = MIN(VW - r->w, (int)(r->x) + STEPSIZE);
            bk_dirty.x = r0.x;          bk_dirty.w = ABS(r->x - r0.x)+1; //+1 b/c the way we render boundary
            bk_dirty.y = r->y;          bk_dirty.h = r->h; 
            break; 
        case 1: // L
            r->x = MAX(0, (int)(r->x) - STEPSIZE);
            bk_dirty.x = r->x + r->w;   bk_dirty.w = ABS(r->x - r0.x)+1; 
            bk_dirty.y = r->y;          bk_dirty.h = r->h;
            break;
        case 2: // Dn
            r->y = MIN(VH - r->h, (int)(r->y) + STEPSIZE); 
            bk_dirty.x = r->x;          bk_dirty.w = r->w; 
            bk_dirty.y = r0.y;          bk_dirty.h = ABS(r->y - r0.y)+1;
            break; 
        case 3: // Up
            r->y = MAX(0, (int)(r->y) - STEPSIZE);
            bk_dirty.x = r->x;          bk_dirty.w = r->w;  
            bk_dirty.y = r->y + r->h;   bk_dirty.h = ABS(r->y - r0.y)+1;
            break;
        default: 
            ret = -1; 
            break; 
    }
    if (ret!=-1) {
        // dirty_all_sf();
        top->dirty = 1; 
        wakeup(&sflist);
    }
out: 
    release(&sflock);
    return ret; 
}

static void sf_dump(void) { // debugging 
    slist_t *node = 0; 
    struct sf_struct *sf; 

    acquire(&sflock);
    printf("pid x y w h\n"); 
    slist_for_each(node, &sflist) { // descending z order, bottom up
        sf = slist_entry(node, struct sf_struct, list /*field name*/);        
        printf("%d %d %d %d %d\n", sf->pid, sf->r.x, sf->r.y, sf->r.w, sf->r.h);
    }
    release(&sflock);
}

void test_sf() {    // unittest. basic sf data structures & ops
    int ret; 
    
    sf_dump();  // expect: (null)

    ret=sf_create(1 /*pid*/, 0,0, 320,240, ZORDER_TOP,100); BUG_ON(ret!=0);
    ret=sf_create(2 /*pid*/, 0,0, 320,240, ZORDER_TOP,100); BUG_ON(ret!=0);
    ret=sf_create(3 /*pid*/, 0,0, 320,240, ZORDER_TOP,100); BUG_ON(ret!=0);
    ret=sf_create(3 /*pid*/, 0,0, 320,240, ZORDER_TOP,100); BUG_ON(ret==0); // shall fail

    sf_dump(); // expect: 1..2..3

    ret=sf_config(2,100,100,320,240,ZORDER_BOTTOM); BUG_ON(ret!=0);
    ret=sf_config(10,0,0,640,480,ZORDER_BOTTOM); BUG_ON(ret==0);
    sf_dump(); // expect: 2..1..3

    ret=sf_free(2); BUG_ON(ret!=0);
    ret=sf_free(2); BUG_ON(ret==0);

    sf_dump(); // expect: 1..3

    ret=sf_free(1); BUG_ON(ret!=0);
    ret=sf_free(3); BUG_ON(ret!=0);

    sf_dump(); // (null)
}

/**********************
    the surface flinger
**********************/

/* Draw a boundary around the top most (focused) surface. 
  Within the real estate of the surface. 
  Caller MUST hold mboxlock
*/
#define B_THICKNESS     3      // in pixels
#define B_COLOR  0x00ff0000    // red
static int draw_boundary(int x, int y, int w, int h, unsigned int clr) {
    unsigned char *t0, *b0;
    unsigned int *t, *b;
    BUG_ON(h<=B_THICKNESS || w<=B_THICKNESS);
    V("%s: %d %d %d %d", __func__, x,y,w,h);

    // top & bottom boundaries
    for (int j=0; j<B_THICKNESS; j++) {
        t0 = the_fb.fb + (y+j)*the_fb.pitch + x*PIXELSIZE; // top
        b0 = the_fb.fb + (y+h+1+j-B_THICKNESS)*the_fb.pitch + x*PIXELSIZE; // bottom
        t = (unsigned int *)t0; b = (unsigned int *)b0;
        for (int i=0; i<w; i++)
            t[i] = b[i] = clr;
    }

    // left & right boundaries
    for (int yy=y; yy<y+h; yy++) { //yy:row num in fb
        // per row
        t0 = the_fb.fb + yy*the_fb.pitch + x*PIXELSIZE; // left
        b0 = the_fb.fb + yy*the_fb.pitch + (x+w+1-B_THICKNESS)*PIXELSIZE; // right
        t = (unsigned int *)t0; b = (unsigned int *)b0;
        for (int i=0; i<B_THICKNESS;i++)
            t[i] = b[i] = clr;
    }

    return 0; 
}

// composite on demand (lazy) 
// caller MUST hold sflock
// return # of layers redrawn
extern int sys_uptime(); 
#define MAX_SF  20 
static int sf_composite(void) {
    unsigned char *p0, *p1, cnt=0;
    slist_t *node = 0; 
    struct sf_struct *sf;
    struct region redrawn_regions[MAX_SF]; int n_redrawn = 0; 

    acquire(&mboxlock);
    if (!the_fb.fb) {release(&mboxlock); return 0;} // we may have 0 surface, fb closed
    
    I("%s starts >>>>>>> ", __func__);  __attribute__ ((unused)) int t00 = sys_uptime(); 
    if (bk_dirty.w || bk_dirty.h) { // draw backgnd
        int y0=MAX(bk_dirty.y, 0), y1=MIN(bk_dirty.y+bk_dirty.h, VH);
        int x0=MAX(bk_dirty.x, 0), x1=MIN(bk_dirty.x+bk_dirty.w, VW);
        I("%s: draw bkgnd %d %d %d %d", __func__, x0,y0,x1,y1); 
        for (int i=y0; i<y1;i++) {
            unsigned int *p0 = (unsigned int *)(the_fb.fb + the_fb.pitch*i); 
            for (int j=x0; j<x1;j++)
                p0[j]=BK_COLOR;
        }
        redrawn_regions[n_redrawn++] = bk_dirty; 
        bk_dirty.x=bk_dirty.y=bk_dirty.w=bk_dirty.h=0;
    }

    /* iterate over all sfs in two passes, in descending z order
        pass0: defer floating sf to pass1, draw remaing sf, if dirty     
        pass1: draw floating sfs */
    slist_t tmplist = SLIST_OBJECT_INIT(tmplist), *ll=0; 
    struct region bbb; // top surface's boundary
    for (int pass=0;pass<2;pass++) {
        if (pass==0) ll=&sflist; else ll=&tmplist; 
        slist_for_each(node, ll) { 
            if (pass==0) { // pass0: iterate over all sfs: 
                sf = slist_entry(node, struct sf_struct, list);
                if (!node->next) // top surface. will draw its bounary later
                    // {xx=sf->x; yy=sf->y; ww=sf->w; hh=sf->h;}
                    bbb = sf->r; 
                if (sf->floating) { // defer floating sf to pass1
                    slist_append(&tmplist, &sf->list1);  
                    continue;
                }
            } else // pass1: iterate over floating sfs (deferred from pass0)
                sf = slist_entry(node, struct sf_struct, list1);

            if (!sf->dirty) { 
                // should this sf intersected with any prior redrawn region, 
                // the sf is also dirty 
                for (int ii=0; ii<n_redrawn; ii++) {
                    if (do_regions_intersect(&sf->r, redrawn_regions+ii)) {
                        sf->dirty=1; break; 
                    }
                }
            }
            if (!sf->dirty)
                continue;
                            
            I("%s draw pass%d: pid %d; x %d y %d w %d h %d trans %d", __func__, 
                pass, sf->pid,
                sf->r.x, sf->r.y, sf->r.w, sf->r.h, sf->transparency); 
            // p0 (dest): hw fb; p1 (src): the current surface
            p0 = the_fb.fb + sf->r.y * the_fb.pitch + sf->r.x*PIXELSIZE; p1 = sf->buf; 
            for (int j=0;j<sf->r.h;j++) {  // copy by row
                if (sf->transparency!=100) { // sf transparent
                    // read back the fb row, mix, and write back                
                    __asm_invalidate_dcache_range(p0, p0+sf->r.w*PIXELSIZE); //what if no invalidation?
                    int t1=sf->transparency, t0=100-t1;
                    for (int k=0;k<sf->r.w;k++) {
                        unsigned int *px0 = (unsigned int*)p0; 
                        unsigned int *px1 = (unsigned int*)p1; 
                        //  mix per pixel, per channel
                        unsigned char r0=(px0[k]>>16)&0xff,g0=(px0[k]>>8)&0xff,b0=px0[k]&0xff;
                        unsigned char r1=(px1[k]>>16)&0xff,g1=(px1[k]>>8)&0xff,b1=px1[k]&0xff;
                        px0[k]= (MIN((r0*t0+r1*t1)/100, 0xff)<<16) 
                                | (MIN((g0*t0+g1*t1)/100, 0xff)<<8) 
                                | (MIN((b0*t0+b1*t1)/100, 0xff));  
                    }
                } else if ((unsigned long)p0%8==0 && (unsigned long)p1%8==0 && (sf->r.w*PIXELSIZE)%8==0)
                    memcpy_aligned(p0, p1, sf->r.w*PIXELSIZE); // fast path: opaque sf, aligned
                else
                    memcpy(p0, p1, sf->r.w*PIXELSIZE); // slow path
                p0 += the_fb.pitch; p1 += sf->r.w*PIXELSIZE;
            }
            redrawn_regions[n_redrawn++] = sf->r; sf->dirty=0; cnt++; 
        }
    }

    if (cnt) {
        draw_boundary(bbb.x,bbb.y,bbb.w,bbb.h, B_COLOR);
        // what if no flush? (TBD optimization: partial flush)
        __asm_flush_dcache_range(the_fb.fb, the_fb.fb+the_fb.size); 
    }
    release(&mboxlock);

    I("%s done. %d ms", __func__, sys_uptime()-t00);
    return cnt; 
}

// extern int sys_sleep(int ms); 
static void sf_task(int arg) {
    __attribute__ ((unused)) int n;
    I("%s starts", __func__);

    acquire(&sflock); 
    while (1)  {
        if (slist_len(&sflist)) {
            sf_composite(); V("%s: composite %d surfaces", __func__, n);
        }
        sleep(&sflist, &sflock); 
    }
    release(&sflock); // never reach here?
}
    
/**********************
    devfs, procfs interfaces                    
**********************/

// format: command [drvid]
// unused/extra args will be ignored
// return 0 on success 
int procfs_parse_fbctl0(int args[PROCFS_MAX_ARGS]) {  
    int cmd = args[0], ret = 0, pid = sys_getpid(); 
    switch(cmd) 
    {
    case FB0_CMD_INIT: // format: cmd x y w h zorder transparency(100=opaque)
        W("FB0_CMD_INIT called"); 
        ret = sf_create(pid, args[1], args[2], args[3], args[4], args[5], args[6]);
        break; 
    case FB0_CMD_FINI: // format: cmd
        ret = sf_free(pid); 
        break; 
    case FB0_CMD_CONFIG: // format: cmd x y w h zorder
        ret = sf_config(pid, args[1], args[2], args[3], args[4], args[5]);
        break; 
    case FB0_CMD_TEST: // format: cmd
        acquire(&sflock); 
        ret = sf_composite(); // force to composite...
        release(&sflock); 
        break; 
    default:
        W("unknown cmd %d", cmd); 
        break;
    }
    return ret; 
}

/* Write to /dev/fb0 by user task */
int devfb0_write(int user_src, uint64 src, int off, int n, void *content) {
    int ret = 0, len, pid = sys_getpid(); 
    slist_t *node = 0;
    struct sf_struct *sf=0;  // surface found

    acquire(&sflock);
    slist_for_each(node, &sflist) {
        struct sf_struct *sff = slist_entry(node, 
            struct sf_struct/*struct name*/, list /*field name*/); BUG_ON(!sff);
        if (sff->pid == pid)
            // break; 
            sf=sff;  // continue to dirty all layers & up 
        if (sf) sff->dirty=1; 
    }
    if (!sf) {BUG(); ret=-1; goto out;} // pid not found 
    BUG_ON(!sf->buf); 
    
    len = MIN(sf->r.w * sf->r.h * PIXELSIZE - off, n); 
    if (either_copyin(sf->buf + off, 1, src, len) == -1)
        goto out;
    ret = len;
    /* Current design: wakes up flinger for evrey write(). This could be
    expensive, e.g. if a task write to /dev/fb0 in small batches. However, tasks
    are more likely to update the whole surface (/dev/fb0) in one write()
    syscall b/c there is no row padding etc. If this because a concern in the
    future, a possible optimization: write() does not wake up flinger; instead,
    add a new fbctl0 command for tasks to explicitly "request" update, 
    which the task calls at the end of writing the entire surface */
    wakeup(&sflist); // notify flinger 
out:     
    release(&sflock); 
    return ret; 
}

/* 
    Read from kb driver's queue, interpret surface commands (e.g. alt-tab), 
    and dispatch other events to the surface that has the focus 

    separate this from sf_task, b/c these two are logically diff, 
    and sleep() on different events (kb inputs vs. user surface draw)

    Once launched, the task will block kb, racing any app tries to read from 
    /dev/events. Therefore, this task only runs when # of sf clients >=1.

    cf kb_read() kb.c
*/
static void kb_task(int arg) {
    struct kbevent ev;
    struct sf_struct *top=0; 

    I("%s starts", __func__);

    while (1)  {
        acquire(&the_kb.lock);

        // wait until interrupt handler has put some
        // input into the driver buffer.
        while (the_kb.r == the_kb.w && !kb_task_quit) {         
            sleep(&the_kb.r, &the_kb.lock);
        }
        if (kb_task_quit) {
            release(&the_kb.lock);I("%s quits", __func__);return;
        }

        ev = the_kb.buf[the_kb.r++ % INPUT_BUF_SIZE];
        release(&the_kb.lock);

        // qemu cannot get alt-tab? seems intercepted by Windows
        if ((ev.mod & KEY_MOD_LCTRL) && (ev.type==KEYUP)) {
            if (ev.scancode==KEY_TAB) { 
                sf_alt_tab(); 
                continue;
            } else if (ev.scancode>=KEY_RIGHT && ev.scancode<=KEY_UP) {
                sf_move(ev.scancode-KEY_RIGHT);
                continue;
            }
        } // TODO: handle more, e.g. Ctrl+Fn
        
        // dispatch the kb event to the top surface
        acquire(&sflock); 
        if (slist_len(&sflist)>0) {
            top = slist_tail_entry(&sflist, struct sf_struct, list); 
            V("ev: %s mod %04x scan %04x dispatch to: pid %d", 
                ev.type?"KEYUP":"KEYDOWN", ev.mod, ev.scancode, top->pid); 
            // NB we rely on sflock and do NOT use the surface.kb::lock 
            // (simple, also avoid the race between event dispatch vs. 
            // changing surface z order)
            top->kb.buf[top->kb.w++ % INPUT_BUF_SIZE] = ev; 
            wakeup(&top->kb.r); 
        } else {
            I("ev: %s mod %04x scan %04x (no surface to dispatch)", 
                ev.type?"KEYUP":"KEYDOWN", ev.mod, ev.scancode); 
        }
        release(&sflock);
    }
}

/* User read()s from the kb device file (/dev/events0). 
    interface == kb_read() in kb.c
*/
int kb0_read(int user_dst, uint64 dst, int off, int n, char blocking, void *content) {
    uint target = n; 
    struct kbevent ev;
#define TXTSIZE 20     
    char ev_txt[TXTSIZE]; 
    struct sf_struct *sf; 
    int pid = sys_getpid(); 

    V("called user_dst %d", user_dst);

    acquire(&sflock);

    if (!(sf=find_sf(pid))) {
        release(&sflock);
        return -1; 
    }
    struct kb_struct *kb = &sf->kb;

    while (n > 0) {     // n:remaining space in userbuf
        if (!blocking && (kb->r == kb->w)) break;

        // wait until interrupt handler has put some
        // input into cons.buffer.
        while (kb->r == kb->w) {
            if (killed(myproc())) {
                release(&sflock);
                return -1;
            }
            sleep(&kb->r, &sflock);
        }

        if (n < TXTSIZE) break; // no enough space in userbuf

        ev = kb->buf[kb->r++ % INPUT_BUF_SIZE];
        int len = snprintf(ev_txt, TXTSIZE, "%s 0x%02x\n", 
            ev.type == KEYDOWN ? "kd":"ku", ev.scancode); 
        BUG_ON(len < 0 || len >= TXTSIZE); // ev_txt too small

        if (n < len) break; // no enough space in userbuf (XXX should do kb.r--?)
        
        // copy the input byte to the user buffer.
        if (either_copyout(user_dst, dst, ev_txt, len) == -1)
            break;

        dst+=len; n-=len;        

        break; 
    }
    release(&sflock);
    return target - n;
}

int start_sf(void) {
    // register 
    devsw[KEYBOARD0].read = kb0_read;
    devsw[KEYBOARD0].write = 0; // nothing

    devsw[FRAMEBUFFER0].read = 0; // TBD (readback?
    devsw[FRAMEBUFFER0].write = devfb0_write;

    int res = copy_process(PF_KTHREAD, (unsigned long)&sf_task, 0/*arg*/,
		 "[sf]"); BUG_ON(res<0);         
    // res = copy_process(PF_KTHREAD, (unsigned long)&kb_task, 0/*arg*/,
    //     "[kb]"); BUG_ON(res<0);  // fork on demand, instead
    return 0; 
}