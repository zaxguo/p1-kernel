#ifndef	_SYS_H
#define	_SYS_H

// xzl: combine this file with others?

#ifndef __ASSEMBLER__

void sys_write(int fd, char * buf, int n);
int sys_fork();

#endif

#endif  /*_SYS_H */
