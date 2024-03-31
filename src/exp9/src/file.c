// Support functions for system calls that involve file descriptors.
//  Like vfs; derived from xv6-riscv
//  tightly coupled with fs.c (fs code...)

#include "param.h"
#include "spinlock.h"
#include "sleeplock.h"
#include "fs.h"
#include "file.h"
#include "fcntl.h"
#include "sched.h"
#include "stat.h"
#include "utils.h"


struct devsw devsw[NDEV]; // devices and their direct read/write funcs
struct {
    struct spinlock lock;
    struct file file[NFILE]; // opened files
} ftable;

static void init_devfs(); 
void fileinit(void) {
    initlock(&ftable.lock, "ftable");
    init_devfs(); 
}

// Allocate a file structure.
struct file *
filealloc(void) {
    struct file *f;

    acquire(&ftable.lock);
    for (f = ftable.file; f < ftable.file + NFILE; f++) {
        if (f->ref == 0) {
            f->ref = 1;
            release(&ftable.lock);
            return f;
        }
    }
    release(&ftable.lock);
    return 0;
}

// Increment ref count for file f.
struct file *
filedup(struct file *f) {
    acquire(&ftable.lock);
    if (f->ref < 1)
        panic("filedup");
    f->ref++;
    release(&ftable.lock);
    return f;
}

// Close file f.  (Decrement ref count, close when reaches 0.)
void fileclose(struct file *f) {
    struct file ff;

    acquire(&ftable.lock);
    if (f->ref < 1)
        panic("fileclose");
    if (--f->ref > 0) {
        release(&ftable.lock);
        return;
    }
    if (f->type == FD_PROCFS && f->content)
        kfree(f->content); 
    if (f->type == FD_DEVICE && f->major == FRAMEBUFFER && f->content)
        ; // fb_fini(); 
    ff = *f;
    f->ref = 0;
    f->type = FD_NONE;
    release(&ftable.lock);

    if (ff.type == FD_PIPE) {
        pipeclose(ff.pipe, ff.writable);
    } else if (ff.type == FD_INODE || ff.type == FD_DEVICE 
        || ff.type == FD_PROCFS) {
        begin_op();
        iput(ff.ip);
        end_op();
    }
}

// Get metadata about file f.
// addr is a user virtual address, pointing to a struct stat.
int filestat(struct file *f, uint64 addr) {
    struct task_struct *p = myproc();
    struct stat st;

    if (f->type == FD_INODE || f->type == FD_DEVICE ||
        f->type == FD_PROCFS) {
        ilock(f->ip);
        stati(f->ip, &st);
        iunlock(f->ip);
        if (copyout(&p->mm, addr, (char *)&st, sizeof(st)) < 0) // copy to user
            return -1;
        return 0;
    }
    return -1;
}

static int readprocfs(struct file *f, uint64 dst, uint n);

// Read from file f.
// addr is a user virtual address.
int fileread(struct file *f, uint64 addr, int n) {
    int r = 0;

    if (f->readable == 0)
        return -1;

    if (f->type == FD_PIPE) {
        r = piperead(f->pipe, addr, n);
    } else if (f->type == FD_DEVICE) {
        if (f->major < 0 || f->major >= NDEV || !devsw[f->major].read)
            return -1;
        r = devsw[f->major].read(1, addr, 0/*off*/, n); // device read
    } else if (f->type == FD_INODE) { // normal file
        ilock(f->ip);
        if ((r = readi(f->ip, 1, addr, f->off, n)) > 0) // fs read
            f->off += r;
        iunlock(f->ip);
    } else if (f->type == FD_PROCFS) {
        if (f->off != 0) return 0; // we dont support seek in profs
        return readprocfs(f, addr, n); 
    } else {
        panic("fileread");
    }

    return r;
}

static int writeprocfs(struct file *f, uint64 src, uint n); 

// Write to file f.
// addr is a user virtual address.
int filewrite(struct file *f, uint64 addr, int n) {
    int r, ret = 0;

    if (f->writable == 0)
        return -1;

    if (f->type == FD_PIPE) {
        ret = pipewrite(f->pipe, addr, n);
    } else if (f->type == FD_DEVICE) {
        if (f->major < 0 || f->major >= NDEV || !devsw[f->major].write)
            return -1;
        ret = devsw[f->major].write(1/*userdst*/, addr, f->off, n);
        if (ret>0 && f->major == FRAMEBUFFER)
            f->off += ret; 
    } else if (f->type == FD_INODE) {
        // write a few blocks at a time to avoid exceeding
        // the maximum log transaction size, including
        // i-node, indirect block, allocation blocks,
        // and 2 blocks of slop for non-aligned writes.
        // this really belongs lower down, since writei()
        // might be writing a device like the console.  xzl: last sentence means??
        int max = ((MAXOPBLOCKS - 1 - 1 - 2) / 2) * BSIZE;
        int i = 0;
        while (i < n) {
            int n1 = n - i;
            if (n1 > max) // write n1 (<=max) blocks at a time...
                n1 = max;

            begin_op();
            ilock(f->ip);
            if ((r = writei(f->ip, 1, addr + i, f->off, n1)) > 0)
                f->off += r;
            iunlock(f->ip);
            end_op();

            if (r != n1) {
                // error from writei
                break;
            }
            i += r;
        }
        ret = (i == n ? n : -1);
    } else if (f->type == FD_PROCFS) {
        return writeprocfs(f, addr, n); 
    } else
        panic("filewrite");

    return ret;
}

/// devfs
int devnull_read(int user_dst, uint64 dst, int off, int n) {
    return 0; 
}

int devnull_write(int user_src, uint64 src, int off, int n) {
    return 0; 
}

int devzero_read(int user_dst, uint64 dst, int off, int n) {
    char zeros[64]; memzero(zeros, 64); 
    int target=n;
    while (n>0) {
        int len = MIN(64,n); 
        if (either_copyout(user_dst, dst, zeros, len) == -1)
            break;
        dst+=len; 
        n-=len; 
    }    
    return target; 
}

#include "fb.h"
int devfb_write(int user_src, uint64 src, int off, int n) {
    int ret = 0, len; 

    acquire(&mboxlock); 
    if (!the_fb.fb)
        goto out; 
    len = MIN(the_fb.size - off, n); 
    if (either_copyin(the_fb.fb + off, 1, src, len) == -1)
        goto out; 
    ret = len;
    __asm_flush_dcache_range(the_fb.fb+off, the_fb.fb+len); 
out: 
    release(&mboxlock); 
    return ret; 
}

/// procfs 
// return: len of content generated 
#define TXTSIZE  64 
static int procfs_gen_content(int major, char *txtbuf) {
    int len; 

    switch (major)
    {
    case PROCFS_DISPINFO:
        len = snprintf(txtbuf, TXTSIZE, "%s\n", "dispinfo"); 
        break;    
    case PROCFS_FBCTL: 
        len = snprintf(txtbuf, TXTSIZE, "format: W H\n"); 
        break; 
    default:
        len = snprintf(txtbuf, TXTSIZE, "%s\n", "TBD"); 
        break;
    }
    BUG_ON(len<0||len>=TXTSIZE);
    return len; 
}

// for simplicity, we dont support seek. the entire content needs to 
//      be read out in one shot, otherwise the content is truncated
static int readprocfs(struct file *f, uint64 dst, uint n) {    
    uint len, off=0;
    char content[TXTSIZE];
    procfs_gen_content(f->major, content); 
    
    len = MIN(n, strlen(content)-off); 
    if (either_copyout(1/*userdst*/, dst, content+off, len) == -1) {
        BUG(); return -1; 
    }
    return len; 
}

int atoi(const char *s) {
  int n;
  n = 0;
  while('0' <= *s && *s <= '9')
    n = n*10 + *s++ - '0';
  return n;
}

// so far, procfs extracts a line from each write() 
//           (not parsing a line across write()s
// return 0 on failure
#define LINESIZE   32
#define MAX_ARGS   8
static int writeprocfs(struct file *f, uint64 src, uint n) {
    char buf[LINESIZE], *s; 
    int args[MAX_ARGS]={0}; 
    int len = MIN(n,LINESIZE), nargs = 0; 
    if (either_copyin(buf, 1, src, len) == -1)
        return 0; 

    for (s = buf; s < buf+len; s++) {
        if (*s=='\n' || *s=='\0')
            break;         
        if ('0' <= *s && *s <= '9') { // start of a num
            args[nargs] = atoi(s); W("got arg %d", args[nargs]);             
            while ('0' <= *s && *s <= '9' && s<buf+len) 
                s++; 
            if (nargs++ == MAX_ARGS)
                break; 
        } 
    }

    switch (f->major)
    {
    case PROCFS_FBCTL:
        break;    
    default:
        break;
    }
    return (s-buf); 
}

static void init_devfs() {
    devsw[DEVNULL].read = devnull_read;
    devsw[DEVNULL].write = devnull_write; 

    devsw[DEVZERO].read = devzero_read;
    devsw[DEVZERO].write = 0; // nothing

    devsw[FRAMEBUFFER].read = 0; // TBD (readback fb
    devsw[FRAMEBUFFER].write = devfb_write; 
}