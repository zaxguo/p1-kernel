#include "utils.h"
#include "sched.h"

void sys_write(char * buf){
	printf(buf);
}

int sys_fork(){
	return copy_process(0 /*clone_flags*/, 0 /*fn*/, 0 /*arg*/);
}

void sys_exit(){
	exit_process();
}

void * const sys_call_table[] = {sys_write, sys_fork, sys_exit};
