#ifndef	_USER_SYS_H
#define	_USER_SYS_H

void call_sys_write(int fd, char * buf, int n);
int call_sys_fork();
void call_sys_exit();

// xzl: TODO move non syscalls out... as inline asm . 
extern unsigned long get_sp ( void );
extern unsigned long get_pc ( void );

#endif  /*_USER_SYS_H */
