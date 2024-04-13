#define K2_DEBUG_INFO 1
// #define K2_DEBUG_VERBOSE 1

//
// File-system system calls.
// Mostly argument checking, since we don't trust
// user code, and calls into file.c and fs.c.
// xzl: removed arg checks

#include "plat.h"
#include "utils.h"
#include "mmu.h"
#include "stat.h"
#include "spinlock.h"
#include "fs.h"
#include "sched.h"
#include "fcntl.h"
#include "sleeplock.h"
#include "file.h"
#include "procfs.h" 
#include "fb.h" // for fb device

// given fd, return the corresponding struct file.
// return 0 on success
static int
argfd(int fd, struct file **pf)
{
  struct file *f;

  if(fd < 0 || fd >= NOFILE || (f=myproc()->ofile[fd]) == 0)
    return -1;  
  if(pf) {
    *pf = f;
    return 0; 
  } else
    return -1;
}

// Allocate a file descriptor for the given file.
// Takes over file reference from caller on success. 
// xzl: reference meaning what
static int
fdalloc(struct file *f)
{
  int fd;
  struct task_struct *p = myproc();

  for(fd = 0; fd < NOFILE; fd++){
    if(p->ofile[fd] == 0){
      p->ofile[fd] = f;
      return fd;
    }
  }
  return -1;
}

int sys_dup(int fd) {
  struct file *f;
  int fd1;

  V("sys_dup called fd %d", fd);

  if(argfd(fd, &f) < 0)
    return -1;
  if((fd1=fdalloc(f)) < 0)
    return -1;
  filedup(f);  // inc refcnt for f
  return fd1;
}

int sys_read(int fd, unsigned long p /*user va*/, int n) {
  struct file *f;

  if(argfd(fd, &f) < 0)
    return -1;
  return fileread(f, p, n);
}

int sys_write(int fd, unsigned long p /*user va*/, int n) { 
  struct file *f;
    
  if(argfd(fd, &f) < 0)
    return -1;
    
  return filewrite(f, p, n);
}

int sys_lseek(int fd, int offset, int whence) {
  struct file *f;
    
  if(argfd(fd, &f) < 0)
    return -1;
    
  return filelseek(f, offset, whence);  
}

int sys_close(int fd) {
  struct file *f;

  if(argfd(fd, &f) < 0)
    return -1;
  myproc()->ofile[fd] = 0;
  fileclose(f);
  return 0;
}

int sys_fstat(int fd, unsigned long st /*user va*/) {
  struct file *f;
  
  if(argfd(fd, &f) < 0)
    return -1;
  return filestat(f, st);
}

// Create the path new as a link to the same inode as old.
// userold, usernew are user va
int sys_link(unsigned long userold, unsigned long usernew) {
  char name[DIRSIZ], new[MAXPATH], old[MAXPATH];
  struct inode *dp, *ip;

  if(fetchstr(userold, old, MAXPATH) < 0 || fetchstr(usernew, new, MAXPATH) < 0)
    return -1;

  begin_op();
  if((ip = namei(old)) == 0){
    end_op();
    return -1;
  }

  ilock(ip);
  if(ip->type == T_DIR){ // xzl: cannot link dir?
    iunlockput(ip);
    end_op();
    return -1;
  }

  ip->nlink++;
  iupdate(ip);
  iunlock(ip);

  // xzl: link under the new path's parent. dp-parent inode
  if((dp = nameiparent(new, name)) == 0)
    goto bad;
  ilock(dp);
  if(dp->dev != ip->dev || dirlink(dp, name, ip->inum) < 0){
    iunlockput(dp);
    goto bad;
  }
  iunlockput(dp);
  iput(ip); // xzl: dec inode refcnt. if 0, will write to disk

  end_op();

  return 0;

bad:
  ilock(ip);
  ip->nlink--;
  iupdate(ip);
  iunlockput(ip);
  end_op();
  return -1;
}

// Is the directory dp empty except for "." and ".." ?
static int
isdirempty(struct inode *dp)
{
  int off;
  struct dirent de;

  for(off=2*sizeof(de); off<dp->size; off+=sizeof(de)){
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
      panic("isdirempty: readi");
    if(de.inum != 0)
      return 0;
  }
  return 1;
}

int sys_unlink(unsigned long upath /*user va*/) {
  struct inode *ip, *dp;
  struct dirent de;
  char name[DIRSIZ], path[MAXPATH];
  uint off;

  if(fetchstr(upath, path, MAXPATH) < 0)
    return -1;

  begin_op();
  if((dp = nameiparent(path, name)) == 0){
    end_op();
    return -1;
  }

  ilock(dp);

  // Cannot unlink "." or "..".
  if(namecmp(name, ".") == 0 || namecmp(name, "..") == 0)
    goto bad;

  // xzl: dp-parent inode; ip-this inode
  if((ip = dirlookup(dp, name, &off)) == 0)
    goto bad;
  ilock(ip);

  if(ip->nlink < 1)
    panic("unlink: nlink < 1");
  if(ip->type == T_DIR && !isdirempty(ip)){ // xzl: cannot unlink nonempty dir
    iunlockput(ip);
    goto bad;
  }

  // xzl: clear the dir entry
  memset(&de, 0, sizeof(de));
  if(writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    panic("unlink: writei");
  if(ip->type == T_DIR){
    dp->nlink--; // xzl: if child is dir.. this accounts for its '..' (cf create())
    iupdate(dp);
  }
  iunlockput(dp);

  ip->nlink--;
  iupdate(ip);
  iunlockput(ip);

  end_op();

  return 0;

bad:
  iunlockput(dp);
  end_op();
  return -1;
}

PROC_DEV_TABLE    // fcntl.h

// xzl: "type" depends on caller. mkdir, type==T_DIR; mknod, T_DEVICE;
//    create, T_FILE
static struct inode*
create(char *path, short type, short major, short minor)
{
  struct inode *ip, *dp;
  char name[DIRSIZ];

  if((dp = nameiparent(path, name)) == 0)
    return 0;

  ilock(dp);

  if((ip = dirlookup(dp, name, 0)) != 0){
    iunlockput(dp);
    ilock(ip);
    if(type == T_FILE 
      && (ip->type == T_FILE || ip->type == T_DEVICE || ip->type == T_PROCFS))
      return ip;    // file already exists.. just return inode
    iunlockput(ip);
    return 0;
  }

  if((ip = ialloc(dp->dev, type)) == 0){ // xzl: failed to alloc inode on disk
    iunlockput(dp);
    return 0;
  }

  ilock(ip);
  ip->major = major;
  ip->minor = minor;
  ip->nlink = 1;
  // dirty hack for /procfs/XXX
  if (type == T_FILE) { 
    // const char *procfs_fnames[] = 
    // {"/proc/dispinfo", "/proc/cpuinfo", "/proc/meminfo", "/proc/fbctl", "/proc/sbctl"};
    // const int majors[] = 
    // {PROCFS_DISPINFO, PROCFS_CPUINFO, PROCFS_MEMINFO, PROCFS_FBCTL, PROCFS_SBCTL};

    for (int i = 0; i < sizeof(pdi)/sizeof(pdi[0]); i++) {
      struct proc_dev_info *p = pdi + i; 
      if (p->type == TYPE_PROCFS && strncmp(path, p->path, 40) == 0) { 
        type = ip->type = T_PROCFS;
        ip->major = p->major; // overwrite major num
      }
    }
  }
  iupdate(ip);

  if(type == T_DIR){  // Create . and .. entries.
    // No ip->nlink++ for ".": avoid cyclic ref count.
    if(dirlink(ip, ".", ip->inum) < 0 || dirlink(ip, "..", dp->inum) < 0)
      goto fail;
  }

  if(dirlink(dp, name, ip->inum) < 0)
    goto fail;

  if(type == T_DIR){
    // now that success is guaranteed:
    dp->nlink++;  // for ".."
    iupdate(dp);
  }

  iunlockput(dp);

  return ip;

 fail:
  // something went wrong. de-allocate ip.
  ip->nlink = 0;
  iupdate(ip);
  iunlockput(ip);
  iunlockput(dp);
  return 0;
}

int sys_open(unsigned long upath, int omode) {
  char path[MAXPATH];
  int fd;
  struct file *f;
  struct inode *ip;
  int n;

  V("%s called", __func__);

  if((n = argstr(upath, path, MAXPATH)) < 0) 
    return -1;

  V("%s called. path %s", __func__, path);

  begin_op();

  if(omode & O_CREATE){
    ip = create(path, T_FILE, 0, 0);
    if(ip == 0){
      end_op();
      return -1;
    }
  } else {
    if((ip = namei(path)) == 0){
      end_op();
      return -1;
    }
    ilock(ip);
    if(ip->type == T_DIR && omode != O_RDONLY){
      iunlockput(ip);
      end_op();
      return -1;
    }
  }

  if(ip->type == T_DEVICE && (ip->major < 0 || ip->major >= NDEV)){
    iunlockput(ip);
    end_op();
    return -1;
  }

  if((f = filealloc()) == 0 || (fd = fdalloc(f)) < 0){
    if(f)
      fileclose(f);
    iunlockput(ip);
    end_op();
    return -1;
  }
  // map inode's state (type,major,etc) to file desc
  if(ip->type == T_DEVICE){
    f->type = FD_DEVICE;
    f->major = ip->major;
    f->off = 0;         // /dev/fb supports seek
    if (f->major == FRAMEBUFFER) {
      ; // dont (re)init fb; instead, do it when user writes to /dev/fbctl
#if 0      
      fb_fini(); 
      if (fb_init() == 0) {
        f->content = the_fb.fb;
        ip->size = the_fb.size; 
      } else {
        fileclose(f);
        iunlockput(ip);
        end_op();
        return -1;
      }
#endif   
    } else if (f->major == DEVSB) {
      // init sound dev only upon writing to /proc/sbctl
      f->content = (void *)(unsigned long)(ip->minor);  // minor indicates sb dev id
#if 0  
        if ((f->content = sound_init(0/*default chunksize*/)) != 0) {
           // as a streaming device w/o seek, no size, offset, etc. 
           ;
        } else {
          fileclose(f);
          iunlockput(ip);
          end_op();
          return -1;
        }
#endif         
    }
  } else if (ip->type == T_PROCFS) {
    f->type = FD_PROCFS;
    f->major = ip->major; // type of procfs entries
    f->off = 0;    // procfs does not use this
    f->content = kalloc(); BUG_ON(!f->content); 
    struct procfs_state * st = f->content; 
    procfs_init_state(st);
    if ((st->ksize = procfs_gen_content(f->major, st->kbuf, MAX_PROCFS_SIZE)) < 0)
      BUG();
  } else {
    f->type = FD_INODE;
    f->off = 0;
  }
  f->ip = ip;
  f->readable = !(omode & O_WRONLY);
  f->writable = (omode & O_WRONLY) || (omode & O_RDWR);

  if((omode & O_TRUNC) && ip->type == T_FILE){
    itrunc(ip);
  }

  iunlock(ip);
  end_op();

  return fd;
}

int sys_mkdir(unsigned long upath) {
  char path[MAXPATH];
  struct inode *ip;

  begin_op();
  if(argstr(upath, path, MAXPATH) < 0 || (ip = create(path, T_DIR, 0, 0)) == 0){
    end_op();
    return -1;
  }
  iunlockput(ip);
  end_op();
  return 0;
}

int sys_mknod(unsigned long upath, short major, short minor) {
  struct inode *ip;
  char path[MAXPATH];

  begin_op();
  if((argstr(upath, path, MAXPATH)) < 0 ||
     (ip = create(path, T_DEVICE, major, minor)) == 0){
    end_op();
    return -1;
  }
  iunlockput(ip);
  end_op();
  return 0;
}

int sys_chdir(unsigned long upath) {  
  char path[MAXPATH];
  struct inode *ip;
  struct task_struct *p = myproc();
  
  begin_op();
  if(argstr(upath, path, MAXPATH) < 0 || (ip = namei(path)) == 0){
    end_op();
    return -1;
  }
  ilock(ip);
  if(ip->type != T_DIR){
    iunlockput(ip);
    end_op();
    return -1;
  }
  iunlock(ip);
  iput(p->cwd);
  end_op();
  p->cwd = ip;
  return 0;
}

int sys_exec(unsigned long upath, unsigned long uargv) {
  char path[MAXPATH], *argv[MAXARG];
  int i;
  unsigned long uarg; // one element from uargv

  if(argstr(upath, path, MAXPATH) < 0) {
    return -1;
  }
  
  V("fetched path %s upath %lx uargv %lx", path, upath, uargv);

  memset(argv, 0, sizeof(argv));
  for(i=0;; i++){
    if(i >= NELEM(argv)){
      goto bad;
    }
    if(fetchaddr(uargv+sizeof(uint64)*i, (uint64*)&uarg) < 0){
      goto bad;
    }
    V("fetched uarg %lx", uarg);

    if(uarg == 0){ // xzl: end of argv
      argv[i] = 0;
      break;
    }
    argv[i] = kalloc(); // 1 page per argument, exec() will copy them to task stak. also free below
    if(argv[i] == 0)
      goto bad;
    if(fetchstr(uarg, argv[i], PAGE_SIZE) < 0)
      goto bad;    
  }

  int ret = exec(path, argv);

  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    kfree(argv[i]);

  return ret;

 bad:
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    kfree(argv[i]);
  return -1;
}

/* fdarray: user pointer to array of two integers,  int *fdarray */
int sys_pipe(unsigned long fdarray) {  
  struct file *rf, *wf;
  int fd0, fd1;
  struct task_struct *p = myproc();
  
  if(pipealloc(&rf, &wf) < 0)
    return -1;
  fd0 = -1;
  if((fd0 = fdalloc(rf)) < 0 || (fd1 = fdalloc(wf)) < 0){
    if(fd0 >= 0)
      p->ofile[fd0] = 0;
    fileclose(rf);
    fileclose(wf);
    return -1;
  }
  if(copyout(&(p->mm), fdarray, (char*)&fd0, sizeof(fd0)) < 0 ||
     copyout(&(p->mm), fdarray+sizeof(fd0), (char *)&fd1, sizeof(fd1)) < 0){
    p->ofile[fd0] = 0;
    p->ofile[fd1] = 0;
    fileclose(rf);
    fileclose(wf);
    return -1;
  }
  V("sys_pipe ok %d %d dfarray %lx", fd0, fd1, fdarray);
  return 0;
}
