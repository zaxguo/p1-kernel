#include "utils.h"
#include "spinlock.h"
#include "sleeplock.h"
#include "fs.h"
#include "buf.h"

// assuming a sector is 512B

// defined in linker.ld, kernel va
extern char ramdisk_start, ramdisk_end; 

static struct spinlock ramdisk_lock;

void            
ramdisk_init(void) {
    initlock(&ramdisk_lock, "ramdisk");
}

void            
ramdisk_rw(struct buf *b, int write) {
    uint64 sector = b->blockno * (BSIZE / 512);

    BUG_ON(&ramdisk_start + 512*sector > &ramdisk_end);

    acquire(&ramdisk_lock);
    if (write)
        memmove(&ramdisk_start + 512*sector, b->data, BSIZE); 
    else 
        memmove(b->data, &ramdisk_start + 512*sector, BSIZE); 
    release(&ramdisk_lock);
}