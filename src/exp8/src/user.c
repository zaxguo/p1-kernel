// "pseudo" user tasks, compiled into the kernel, but executed at EL0 and in their own va 
// besides syscalls, CANNOT call any kernel functions -- otherwise will trigger memory protection error

#include "user_sys.h"
#include "user.h"
#include "fcntl.h"
#include "utils.h"


static void user_delay (unsigned long cnt) {
	volatile unsigned long c = cnt; 
	while (c)
		c--; 
}

// cannot call kernel's strlen
 __attribute__((unused)) static unsigned int
user_strlen(const char *s)    
{
  int n;
  for(n = 0; s[n]; n++)
    ;
  return n;
}

void print_to_console(char *msg) {
	call_sys_write(1 /*stdout*/, msg, user_strlen(msg)); 
  // call_sys_write(1 /*stdout*/, msg, strlen(msg));     // WILL FAIL. can be used for debugging 
}

void loop(char* str)
{
	char buf[2] = {""};
	while (1){
		for (int i = 0; i < 5; i++){
			buf[0] = str[i];
			call_sys_write(0, buf, 1);
			user_delay(1000000);
		}
	}
}

void loop1(char *str) {
	for (;;)
	// for (int i = 0; i < 3; i++)
		print_to_console(str);
}

#define CONSOLE 1     // major num for device console

void user_process() 
{
	if(call_sys_open("console", O_RDWR) < 0){
		call_sys_mknod("console", CONSOLE, 0);
		call_sys_open("console", O_RDWR);
  }
  call_sys_dup(0);  // stdout
  call_sys_dup(0);  // stderr

	print_to_console("User process entry\n\r");

	int pid = call_sys_fork();
	if (pid < 0) {
		print_to_console("Error during fork\n\r");
		call_sys_exit(1);
		return;
	}
	print_to_console("fork() succeeds\n\r");

	if (pid == 0){
		loop1("abcde");
	} else {
		loop1("12345");
	}
}

// -------------------------------------------
// ls
//
#if 1
#include "fs.h"
#include "stat.h"

static int
stat(const char *n, struct stat *st)
{
  int fd;
  int r;

  fd = call_sys_open(n, O_RDONLY);
  if(fd < 0)
    return -1;
  r = call_sys_fstat(fd, st);
  call_sys_close(fd);
  return r;
}

static char*
fmtname(char *path)
{
  static char buf[DIRSIZ+1];
  char *p;

  // Find first character after last slash.
  for(p=path+strlen(path); p >= path && *p != '/'; p--)
    ;
  p++;

  // Return blank-padded name.
  if(strlen(p) >= DIRSIZ)
    return p;
  memmove(buf, p, strlen(p));
  memset(buf+strlen(p), ' ', DIRSIZ-strlen(p));
  return buf;
}

void
ls(char *path)
{
  char buf[512], *p;
  int fd;
  struct dirent de;
  struct stat st;

  if((fd = call_sys_open(path, 0)) < 0){
    //fprintf(2, "ls: cannot open %s\n", path);
	W("ls: cannot open %s\n", path);
    return;
  }

  if(call_sys_fstat(fd, &st) < 0){
    // fprintf(2, "ls: cannot stat %s\n", path);
	W("ls: cannot stat %s\n", path);
    call_sys_close(fd);
    return;
  }

  switch(st.type){
  case T_DEVICE:
  case T_FILE:
    printf("%s %d %d %l\n", fmtname(path), st.type, st.ino, st.size);
    break;

  case T_DIR:
    if(strlen(path) + 1 + DIRSIZ + 1 > sizeof buf){
      printf("ls: path too long\n");
      break;
    }
    safestrcpy(buf, path, 512);
    p = buf+strlen(buf);
    *p++ = '/';
    while(call_sys_read(fd, &de, sizeof(de)) == sizeof(de)){
      if(de.inum == 0)
        continue;
      memmove(p, de.name, DIRSIZ);
      p[DIRSIZ] = 0;
      if(stat(buf, &st) < 0){
        printf("ls: cannot stat %s\n", buf);
        continue;
      }
      printf("%s %d %d %d\n", fmtname(buf), st.type, st.ino, st.size);
    }
    break;
  }
  call_sys_close(fd);
}
#endif