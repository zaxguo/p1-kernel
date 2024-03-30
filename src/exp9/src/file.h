// from xv6-riscv 
// a vfs layer
struct file {
  enum { FD_NONE, FD_PIPE, FD_INODE, FD_DEVICE, FD_PROCFS } type;
  int ref; // reference count
  char readable;
  char writable;
  struct pipe *pipe; // FD_PIPE
  struct inode *ip;  // FD_INODE and FD_DEVICE (& FD_PROCFS)
  uint off;          // FD_INODE
  short major;       // FD_DEVICE (& FD_PROCFS)
  char *content;    // 1 page, allocated on open(). FD_PROCFS
};

#define major(dev)  ((dev) >> 16 & 0xFFFF)
#define minor(dev)  ((dev) & 0xFFFF)
#define	mkdev(m,n)  ((uint)((m)<<16| (n)))

// in-memory copy of an inode
struct inode {
  uint dev;           // Device number   xzl: ROOTDEV=1, but not major/minor for which CONSOLE=1.
  uint inum;          // Inode number
  int ref;            // Reference count
  struct sleeplock lock; // protects everything below here (xzl: above protected by itable spinlock)
  int valid;          // inode has been read from disk?

  // copy of disk inode 
  short type;         // cf stat.h
  short major;
  short minor;
  short nlink;
  uint size;
  uint addrs[NDIRECT+1];
};

// map major device number to device functions.
struct devsw {
  int (*read)(int, uint64, int);
  int (*write)(int, uint64, int);
};

extern struct devsw devsw[];

