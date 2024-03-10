// has to be a single file 
// included by both the kernel and mkfs

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
#define NR_TASKS				128     // 32 should be fine. usertests.c seems to expect > 100
#define ROOTDEV       1  // device number of file system root disk xzl: just disk id, not major/minor
#define LOGSIZE      (MAXOPBLOCKS*3)  // max data blocks in on-disk log
#define FSSIZE       2000  // size of file system in blocks


// large user vm, works, but usertests slow b/c freecount()
// #define USER_VA_END         (128 * 1024 * 1024) // == user stack top
// #define USER_MAX_STACK      (1 * 1024 * 1024)  // in bytes, must be page aligned. 
// #define MAX_TASK_USER_PAGES		(USER_VA_END / PAGE_SIZE)      // max userpages per task, 
// #define MAX_TASK_KER_PAGES      64       //max kernel pages per task. 128MB user va

// small user vm
#define USER_VA_END         (4 * 1024 * 1024) // == user stack top
#define USER_MAX_STACK      (1 * 1024 * 1024)  // in bytes, must be page aligned. 
#define MAX_TASK_USER_PAGES		(USER_VA_END / PAGE_SIZE)      // max userpages per task, 
#define MAX_TASK_KER_PAGES      16       //max kernel pages per task. 128MB user va


// keep xv6 code happy. TODO: replace them
typedef unsigned int   uint;
typedef unsigned short ushort;
typedef unsigned char  uchar;

typedef unsigned char uint8;
typedef unsigned short uint16;
typedef unsigned int  uint32;
typedef unsigned long uint64;