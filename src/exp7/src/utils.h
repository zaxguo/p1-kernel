#ifndef	_UTILS_H
#define	_UTILS_H

#include <stdint.h>

// -------------- configuration -------------------------- //
#define NOFILE          16  // open files per process
#define NCPU	        1			
#define MAXPATH         128   // maximum file path name
#define NINODE          50  // maximum number of active i-nodes
#define NDEV            10  // maximum major device number
#define MAXARG       32  // max exec arguments
#define NFILE       100  // open files per system
#define MAXOPBLOCKS  10  // max # of blocks any FS op writes xzl:too small?
#define NBUF         (MAXOPBLOCKS*3)  // size of disk block cache
#define NR_TASKS				32
#define ROOTDEV       1  // device number of file system root disk xzl: just disk id, not major/minor

// keep xv6 code happy. TODO: replace them
typedef unsigned int   uint;
typedef unsigned short ushort;
typedef unsigned char  uchar;

typedef unsigned char uint8;
typedef unsigned short uint16;
typedef unsigned int  uint32;
typedef unsigned long uint64;


// the kernel's HAL
#include "printf.h"

#ifdef PLAT_VIRT
#include "plat-virt.h"
#endif

#define __REG32(x)      (*((volatile uint32_t *)(x)))

struct buf; 
struct spinlock; 
struct sleeplock; 
struct file;
struct inode;
struct superblock;
struct stat; 
struct pipe; 

// ------------------- misc ----------------------------- //

extern void delay ( unsigned long);
extern void put32 ( unsigned long, unsigned int );
extern unsigned int get32 ( unsigned long );
extern int get_el ( void );

// ------------------- uart ----------------------------- //
void uart_init (unsigned long base);
char uart_recv ( void );
void uart_send ( char c );
void putc ( void* p, char c );
// new apis, from xv6
void            uartintr(void);
void            uartputc(int);
void            uartputc_sync(int);
int             uartgetc(void);


// ------------------- timer ----------------------------- //
// TODO: clean up
/* These are for "System Timer". See timer.c for details */
void timer_init ( void );
void handle_timer_irq ( void );

/* below are for Arm generic timers */
void generic_timer_init ( void );
void handle_generic_timer_irq ( void );

extern void gen_timer_init();
/* set timer to be fired after @interval System ticks */
extern void gen_timer_reset(int interval); 

// ------------------- irq ---------------------------- //
void enable_interrupt_controller( void ); // irq.c 

/* functions below defined in irq.S */
void irq_vector_init( void );    
void enable_irq( void );         
void disable_irq( void );
int is_irq_masked(void); 
/*return 1 if irq enabled, 0 otherwise*/
static inline int intr_get(void) {return 1-is_irq_masked();}; 

// ---------------- kernel mm ---------------------- //
unsigned long get_free_page();
void free_page(unsigned long p);
void memzero(unsigned long src, unsigned long n);   // boot.S
void memcpy(unsigned long dst, unsigned long src, unsigned long n);

#include "sched.h"
unsigned long *map_page(struct task_struct *task, unsigned long va, unsigned long page, int alloc);
int copy_virt_memory(struct task_struct *dst); 
void *kalloc(); // get kernel va
void kfree(void *p);    // give kernel va
void *allocate_user_page(struct task_struct *task, unsigned long va); 

// the virtual base address of the pgtables. Its actual value is set by the linker. 
//  cf the linker script (e.g. linker-qemu.ld)
extern unsigned long pg_dir;  

extern void set_pgd(unsigned long pgd);
extern unsigned long get_pgd();

#define VA2PA(x) ((unsigned long)x - VA_START)          // kernel va to pa
#define PA2VA(x) ((void *)((unsigned long)x + VA_START))  // pa to kernel va

int             copyout(struct task_struct *, uint64, char *, uint64);
int             copyin(struct task_struct *, char *, uint64, uint64);
int             copyinstr(struct task_struct *, char *, uint64, uint64);
int             either_copyout(int user_dst, uint64 dst, void *src, uint64 len);
int             either_copyin(void *dst, int user_src, uint64 src, uint64 len);

// ------------------- spinlock ---------------------------- //
void            acquire(struct spinlock*);
int             holding(struct spinlock*);
void            initlock(struct spinlock*, char*);
void            release(struct spinlock*);
void            push_off(void);
void            pop_off(void);

// ------------------- sleeplock ---------------------------- //
void            acquiresleep(struct sleeplock*);
void            releasesleep(struct sleeplock*);
int             holdingsleep(struct sleeplock*);
void            initsleeplock(struct sleeplock*, char*);

// ------------------- sched ---------------------------- //
void exit_process(void);
void sleep(void *, struct spinlock *);
int wait(uint64_t);
void wakeup(void *);
int killed(struct task_struct *p);
int kill(int pid);
void setkilled(struct task_struct *p);

// log.c
void            initlog(int, struct superblock*);
void            log_write(struct buf*); // xzl: replaces bwrite
void            begin_op(void);
void            end_op(void);

// bio.c buffer cache
void            binit(void);
struct buf*     bread(uint, uint);
void            brelse(struct buf*);
void            bwrite(struct buf*);
void            bpin(struct buf*);
void            bunpin(struct buf*);

// file.c
struct file*    filealloc(void);
void            fileclose(struct file*);
struct file*    filedup(struct file*);
void            fileinit(void);
int             fileread(struct file*, uint64, int n);
int             filestat(struct file*, uint64 addr);
int             filewrite(struct file*, uint64, int n);

// fs.c
void            fsinit(int);
int             dirlink(struct inode*, char*, uint);
struct inode*   dirlookup(struct inode*, char*, uint*);
struct inode*   ialloc(uint, short);
struct inode*   idup(struct inode*);
void            iinit();
void            ilock(struct inode*);
void            iput(struct inode*);
void            iunlock(struct inode*);
void            iunlockput(struct inode*);
void            iupdate(struct inode*);
int             namecmp(const char*, const char*);
struct inode*   namei(char*);
struct inode*   nameiparent(char*, char*);
int             readi(struct inode*, int, uint64, uint, uint);
void            stati(struct inode*, struct stat*);
int             writei(struct inode*, int, uint64, uint, uint);
void            itrunc(struct inode*);

// string.c
int             memcmp(const void*, const void*, uint);
void*           memmove(void*, const void*, uint);
void*           memset(void*, int, uint);
char*           safestrcpy(char*, const char*, int);
int             strlen(const char*);
int             strncmp(const char*, const char*, uint);
char*           strncpy(char*, const char*, int);

//sys.c 
int             fetchstr(uint64, char*, int);
int             argstr(uint64 addr, char *buf, int max);
int             fetchaddr(uint64 addr, uint64 *ip);

// exec.c
int             exec(char*, char**);

// pipe.c
int             pipealloc(struct file**, struct file**);
void            pipeclose(struct pipe*, int);
int             piperead(struct pipe*, uint64, int);
int             pipewrite(struct pipe*, uint64, int);

// virtio_disk.c
void            virtio_disk_init(void);
void            virtio_disk_rw(struct buf *, int);
void            virtio_disk_intr(void);

// console.c
void            consoleinit(void);
void            consoleintr(int);
void            consputc(int);

// number of elements in fixed-size array
#define NELEM(x) (sizeof(x)/sizeof((x)[0]))


#ifdef NDEBUG
        #define assert(expr)    ((void) 0)
#else
    // linux
    #define likely(exp)     __builtin_expect (!!(exp), 1)
    #define unlikely(exp)   __builtin_expect (!!(exp), 0)

    // circle assert.cpp        
    static inline void assertion_failed (const char *pExpr, const char *pFile, unsigned nLine) {
        printf("assertion failed: %s at %s:%u\n", pExpr, pFile, nLine); 
        panic("kernel hangs"); 
    }
    #define assert(expr)    (  likely (expr)        \
                                ? ((void) 0)           \
                                : assertion_failed (#expr, __FILE__, __LINE__))
#endif


#endif  /*_UTILS_H */
