// #define K2_DEBUG_WARN
// #define K2_DEBUG_VERBOSE
#define K2_DEBUG_INFO

/* In-kernel surface flinger (SF). 
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

struct sf_struct {
    unsigned char *buf; // kernel va
    unsigned x,y,w,h; // with regard to (0,0) of the hw fb
    int transparency;  // 0-100
    int dirty;  // redraw this surface? 
    int pid; // owner 
    struct kb_struct kb; // kb events dispatched to this surface
    slist_t list;
}; 

static struct spinlock sflock = {.locked=0, .cpu=0, .name="sflock"};
// ordered by z. tail: 0 (top most)
static slist_t sflist = SLIST_OBJECT_INIT(sflist);  

extern int procfs_parse_fbctl(int args[PROCFS_MAX_ARGS]); // mbox.c
extern int sys_getpid(void);  // sys.c

// return 0 on success
static int reset_fb() {
    // hw fb setup
    int args[PROCFS_MAX_ARGS] = {
        1024, 768, /*w,h*/
        1024, 768, /*vw,vh*/
        0,0 /*offsetx, offsety*/
    }; 
    return procfs_parse_fbctl(args);  // reuse the func
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

// caller MUST hold sflock
static void dirty_all_sf(void) {
    slist_t *node = 0;
    struct sf_struct *sf; 
    slist_for_each(node, &sflist) {
        sf = slist_entry(node, struct sf_struct/*struct name*/, list /*field name*/); BUG_ON(!sf);
        sf->dirty=1; 
    }
}

// return 0 on success; <0 on err
static int sf_create(int pid, int x, int y, int w, int h, int zorder) {
    struct sf_struct *s = malloc(sizeof(struct sf_struct));     
    W("called"); 

    if (!s) {BUG();return -1;}
    s->buf = malloc(w*h*PIXELSIZE); if (!s->buf) {free(s);BUG();return -2;}
    s->x=x; s->y=y; s->w=w; s->h=h; s->pid=pid; s->dirty=1; 

    acquire(&sflock);
    if (find_sf(pid)) {
        free(s->buf); free(s); 
        release(&sflock); return -3;
    }

    // put new surface on the list of surfaces
    if (zorder == ZORDER_BOTTOM) { // list head
        slist_insert(&sflist, &s->list);
        dirty_all_sf(); // XXX opt: sometimes we dont have to dirty all     
    } else if (zorder == ZORDER_TOP) // list tail
        slist_append(&sflist, &s->list);  // no dirty needed
    else BUG(); 

    if (slist_len(&sflist) == 1) // reset fb, if this is the 1st surface
        reset_fb();     
    wakeup(&sflist); // notify flinger
    release(&sflock);
    W("cr ok"); 
    return 0; 
}

// return 0 on success; <0 on err
int sf_free(int pid)  {
    struct sf_struct *sf = 0;
    int ret;

    acquire(&sflock);
    sf = find_sf(pid); 
    if (sf) {
        slist_remove(&sflist, &sf->list);
        if (sf->buf) free(sf->buf); 
        free(sf); 
    }    
    if (sf) {
        if (slist_len(&sflist) == 0) 
            {I("freed");fb_fini();}  // no surface left
        else
            dirty_all_sf(); 
        wakeup(&sflist);
        ret=0; 
    } else 
        ret=-1; 

    release(&sflock);
    return ret;
}

// needed by filelseek() (file.c)
// caller must NOT hold sflock 
// return -1 on error
int sf_size(int pid) {
    int ret = -1; 
    struct sf_struct *sf = 0;

    acquire(&sflock);
    sf = find_sf(pid); 
    if (!sf) 
        goto out; 
    ret = sf->w * sf->h * PIXELSIZE;
out:
    release(&sflock);
    return ret; 
}

// change pos/loc/zorder of an existing surface
// return 0 on success, <0 on error 
int sf_config(int pid, int x, int y, int w, int h, int zorder) {
    struct sf_struct *sf = 0;

    acquire(&sflock);
    sf = find_sf(pid); 
    if (sf) {
        if (sf->w!=w || sf->h!=h) {
            // TBD resize sf: alloc new buf, free old buf...
            BUG(); 
        }
        sf->x=x; sf->y=y; sf->w=w; sf->h=h;
        if (zorder != ZORDER_UNCHANGED) { 
            // take the sf out and plug in back
            slist_remove(&sflist, &sf->list); // XXX ok? or &sf->list?
            if (zorder == ZORDER_TOP)
                slist_append(&sflist, &sf->list); 
            else if (zorder == ZORDER_BOTTOM) 
                slist_insert(&sflist, &sf->list);
            else BUG(); // ZORDER_INC, ZORDER_DEC ... TBD
        }
    }
    dirty_all_sf(); // XXX opt: sometimes we dont have to dirty all 
    wakeup(&sflist); // notify flinger
    release(&sflock);
    if (!sf) return -1; // pid no found
    return 0; 
}

// mov the bottom surface to the top
// return 0 on success, <0 on error 
// call must NOT hold sflock
static int sf_alt_tab(void) {
    struct sf_struct *bot = 0;
    int ret; 
    
    I("%s", __func__); 
    acquire(&sflock);
    if (slist_len(&sflist) <= 1) {ret=0; goto out;}
    bot = slist_first_entry(&sflist, struct sf_struct, list); 
    slist_remove(&sflist, &bot->list); 
    slist_append(&sflist, &bot->list); 
    
    dirty_all_sf(); wakeup(&sflist); 
out: 
    release(&sflock);
    ret=0; 
    return ret; 
}

static void sf_dump(void) { // debugging 
    slist_t *node = 0; 
    struct sf_struct *sf; 

    acquire(&sflock);
    printf("pid x y w h\n"); 
    slist_for_each(node, &sflist) { // descending z order, bottom up
        sf = slist_entry(node, struct sf_struct, list /*field name*/);        
        printf("%d %d %d %d %d\n", sf->pid, sf->x, sf->y, sf->w, sf->h);
    }
    release(&sflock);
}

void test_sf() {
    int ret; 
    
    sf_dump();  // (null)

    ret=sf_create(1 /*pid*/, 0,0, 320,240, ZORDER_TOP); BUG_ON(ret!=0);
    ret=sf_create(2 /*pid*/, 0,0, 320,240, ZORDER_TOP); BUG_ON(ret!=0);
    ret=sf_create(3 /*pid*/, 0,0, 320,240, ZORDER_TOP); BUG_ON(ret!=0);
    ret=sf_create(3 /*pid*/, 0,0, 320,240, ZORDER_TOP); BUG_ON(ret==0); // shall fail

    sf_dump(); // 1..2..3

    ret=sf_config(2,100,100,320,240,ZORDER_BOTTOM); BUG_ON(ret!=0);
    ret=sf_config(10,0,0,640,480,ZORDER_BOTTOM); BUG_ON(ret==0);
    sf_dump(); // 2..1..3

    ret=sf_free(2); BUG_ON(ret!=0);
    ret=sf_free(2); BUG_ON(ret==0);

    sf_dump(); // 1..3

    ret=sf_free(1); BUG_ON(ret!=0);
    ret=sf_free(3); BUG_ON(ret!=0);

    sf_dump(); // (null)
}

/**********************
    the surface flinger
**********************/
// composite on demand (lazy) 
// caller MUST hold sflock
// return # of layers redrawn
int sf_composite(void) {
    unsigned char *p0, *p1, cnt=0;
    slist_t *node = 0; 
    struct sf_struct *sf;     

    acquire(&mboxlock);
    if (!the_fb.fb) {release(&mboxlock); return 0;} // maybe we have 0 surfaces, fb closed
    slist_for_each(node, &sflist) { // descending z order, bottom up
        sf = slist_entry(node, struct sf_struct, list /*field name*/);
        if (!sf->dirty) continue;
        I("%s draw surface pid %d", __func__, sf->pid); 
        p0 = the_fb.fb + sf->y * the_fb.pitch + sf->x*PIXELSIZE; p1 = sf->buf; 
        for (int j=0;j<sf->h;j++) {  // copy by row             
            // XXX handle transparency: read back the row from fb, compute, and write
            if ((unsigned long)p0%8==0 && (unsigned long)p1%8==0 && (sf->w*PIXELSIZE)%8==0)
                memcpy_aligned(p0, p1, sf->w*PIXELSIZE); // fast path
            else
                memcpy(p0, p1, sf->w*PIXELSIZE); 
            p0 += the_fb.pitch; p1 += sf->w*PIXELSIZE;
        }
        sf->dirty=0; cnt++; 
    }
    release(&mboxlock);

    return cnt; 
}

// extern int sys_sleep(int ms); 
static void sf_task(int arg) {
    I("%s starts", __func__);

    acquire(&sflock); 
    while (1)  {        
        int n = sf_composite(); I("%s: composite %d surfaces", __func__, n);
        sleep(&sflist, &sflock); 
    }
    release(&sflock); // never reach here?

    // periodic wakeup -- a bad idea; waste of cycles 
    // while (1)  {        
    //     acquire(&sflock); 
    //     int n = sf_composite(); I("%s: composite %d surfaces", __func__, n);
    //     release(&sflock);
    //     sys_sleep(1000/SF_HZ);
    // }
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
    case FB0_CMD_INIT: // format: cmd x y w h zorder
        W("called"); 
        ret = sf_create(pid, args[1], args[2], args[3], args[4], args[5]);
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

/* Write from /dev/fb0 from user task */
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
    
    len = MIN(sf->w*sf->h*PIXELSIZE - off, n); 
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

extern struct kb_struct the_kb; // kb.c

/* read from kb driver's queue, interpret surface commands (e.g. alt-tab), 
and dispatch other events to the surface that has the focus 

separate this from sf_task, b/c these two are logically diff, 
and sleep() on different events (kb inputs vs. user surface draw)

    cf kb_read() kb.c
*/
static void kb_dispatch_task(int arg) {
    struct kbevent ev;
    struct sf_struct *top=0; 

    I("%s starts", __func__);

    while (1)  {
        acquire(&the_kb.lock);
        // if (!blocking && (the_kb.r == the_kb.w)) break;

        // wait until interrupt handler has put some
        // input into the driver buffer.
        while (the_kb.r == the_kb.w) {         
            sleep(&the_kb.r, &the_kb.lock);
        }

        ev = the_kb.buf[the_kb.r++ % INPUT_BUF_SIZE];
        release(&the_kb.lock);

        if ((ev.mod & KEY_MOD_LCTRL) && (ev.type==KEYUP) 
            && (ev.scancode==KEY_TAB)) { // qemu cannot get alt-tab? seems intercepted by Windows
            sf_alt_tab(); 
            continue;
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


#include "sched.h"
#include "file.h"

int start_sf(void) {
    // register 
    devsw[KEYBOARD0].read = kb0_read;
    devsw[KEYBOARD0].write = 0; // nothing

    devsw[FRAMEBUFFER0].read = 0; // TBD (readback?
    devsw[FRAMEBUFFER0].write = devfb0_write;

    int res = copy_process(PF_KTHREAD, (unsigned long)&sf_task, 0/*arg*/,
		 "sftask"); BUG_ON(res<0); 
    res = copy_process(PF_KTHREAD, (unsigned long)&kb_dispatch_task, 0/*arg*/,
        "kbtask"); BUG_ON(res<0); 
    return 0; 
}