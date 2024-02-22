#include "utils.h"
#include "sched.h"
#include "syscall.h"

// to make things easier, do we check for arguments legality? 
// at least should do copyinstr() and copyin() ... as in xv6...

// @buf can be directly used as x0 was intact since kernel entry
void sys_write(char * buf){
	printf(buf);
}

int sys_fork(){
	return copy_process(0 /*clone_flags*/, 0 /*fn*/, 0 /*arg*/);
}

void sys_exit(){
	exit_process();
}

void sys_wait() {
	/* TBD */
}

void sys_pipe() {
	/* TBD */
}
void sys_read() {
	/* TBD */
}
void sys_kill() {
	/* TBD */
}
void sys_exec() {
	/* TBD */
}
void sys_fstat() {
	/* TBD */
}
void sys_chdir() {
	/* TBD */
}
void sys_dup() {
	/* TBD */
}
void sys_getpid() {
	/* TBD */
}
void sys_sbrk() {
	/* TBD */
}
void sys_sleep() {
	/* TBD */
}
void sys_uptime() {
	/* TBD */
}
void sys_open() {
	/* TBD */
}
void sys_mknod() {
	/* TBD */
}
void sys_unlink() {
	/* TBD */
}
void sys_link() {
	/* TBD */
}
void sys_mkdir() {
	/* TBD */
}
void sys_close() {
	/* TBD */
}

/* An array of pointers to all syscall handlers. 
	Each syscall has a "syscall number" (sys.h) — which is just an index in this array 
	
	invoked from el0_svc

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
