#include "utils.h"
#include "sched.h"
#include "syscall.h"
#include "mmu.h"

// in-kernel syscall impl
// we have a simplified mechanism getting syscall arguments & return values.

/*
	assumption 1: from kernel entry to sys_XXX, x0-x8 are untouched. 
	this allows syscalls to read args direcly 

	assumption 2: the user's va is mapped during the exec of the syscall.
	(and the user pointers are not used in irq context, in which the user
	va may not be mapped)	

	in general we shall not trust the user pointers passed to syscalls.  
	hence, the kernel must check user pointers, ie walking the backing pagetables 
	and copying contents to kernel va). 
	This allows the kernel to catch invalid user buffers and reject it as needed. 
	(^^ This does not avoid TOCTOU problems, which are a different topic)

*/ 

// copy to/from userspace: although the code is there (mm.c) and is in use, 
// it is not needed. 

// invoked from el0_svc (entry.S)
// x0..x9 were intact since kernel entry (svc). hence they can be directly used as arguments
// upon return, ret_from_syscall (entry.S) will copy x0 to pt_regs, as return value to user


// Fetch the uint64 at addr from the current process.
int
fetchaddr(uint64 addr, uint64 *ip)
{
  struct task_struct *p = myproc();
  // xzl: maybe check against brk and stack bottom? our task memlayout differs TODO:
//   if(addr >= p->sz || addr+sizeof(uint64) > p->sz) // both tests needed, in case of overflow
//     return -1;
  if(copyin(&p->mm, (char *)ip, addr, sizeof(*ip)) != 0)
    return -1;
  return 0;
}

// Fetch the nul-terminated string at addr from the current process.
// Returns length of string, not including nul, or -1 for error.
int
fetchstr(uint64 addr, char *buf, int max)
{  
  if(copyinstr(&myproc()->mm, buf, addr, max) < 0)
    return -1;
  return strlen(buf);
}

int argstr(uint64 addr, char *buf, int max) {return fetchstr(addr, buf, max);};

int sys_fork(void) {
	return copy_process(0 /*clone_flags*/, 0 /*fn*/, 0 /*arg*/);
}

int sys_exit(int c){
	I("exit called. pid %d code %d", current->pid, c);
	exit_process(c);
	return 0; 
}

int sys_wait(unsigned long p /* user va*/) {	
	return wait(p); 
}

int sys_kill(int pid) {
	/* TBD */
	return 0; 
}

int sys_getpid(void) {
	return current->pid; 
}

int sys_sleep(int t) {
	/* TBD */
	return 0; 
}

int sys_uptime(void) {
	/* TBD */
	return 0; 
}

// sysfile.c
extern int sys_dup(int fd);
extern int sys_read(int fd, unsigned long p /*user va*/, int n);
extern int sys_write(int fd, unsigned long p /*user va*/, int n);
extern int sys_close(int fd); 
extern int sys_fstat(int fd, unsigned long st /*user va*/);
extern int sys_link(unsigned long userold, unsigned long usernew);
extern int sys_unlink(unsigned long upath /*user va*/);
extern int sys_open(unsigned long upath, int omode);
extern int sys_mkdir(unsigned long upath);
extern int sys_mknod(unsigned long upath, short major, short minor);
extern int sys_chdir(unsigned long upath);
extern int sys_exec(unsigned long upath, unsigned long uargv);
extern int sys_pipe(unsigned long fdarray);

// mm.c
extern unsigned long sys_sbrk(int incr); 


/* An array of pointers to all syscall handlers. 
	Each syscall has a "syscall number" (sys.h) — which is just an index in this array 		
xzl: TODO -- gen this automatically in a separate file. then include here	
*/
void * const sys_call_table[] = {
	[SYS_fork]    sys_fork,
	[SYS_exit]    sys_exit,
	[SYS_wait]    sys_wait,
	[SYS_pipe]    sys_pipe,
	[SYS_read]    sys_read,
	[SYS_kill]    sys_kill,
	[SYS_exec]    sys_exec,
	[SYS_fstat]   sys_fstat,
	[SYS_chdir]   sys_chdir,
	[SYS_dup]     sys_dup,
	[SYS_getpid]  sys_getpid,
	[SYS_sbrk]    sys_sbrk,
	[SYS_sleep]   sys_sleep,
	[SYS_uptime]  sys_uptime,
	[SYS_open]    sys_open,
	[SYS_write]   sys_write,
	[SYS_mknod]   sys_mknod,
	[SYS_unlink]  sys_unlink,
	[SYS_link]    sys_link,
	[SYS_mkdir]   sys_mkdir,
	[SYS_close]   sys_close,	
};