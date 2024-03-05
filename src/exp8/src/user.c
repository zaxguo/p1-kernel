// "pseudo" user tasks, compiled into the kernel, but executed at EL0 and in their own va 
// besides syscalls, CANNOT call any kernel functions -- otherwise will trigger memory protection error
//
// in general, the programming environment is very limited, b/c everything needs to be re-implemented (e.g. printf())

#include "user_sys.h"
#include "user.h"
#include "fcntl.h"
// #include "utils.h"


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
void ls(char *path);

void user_process() 
{
  char *argv[] = {0};

	if(call_sys_open("console", O_RDWR) < 0){
		call_sys_mknod("console", CONSOLE, 0);
		call_sys_open("console", O_RDWR);
  }
  call_sys_dup(0);  // stdout
  call_sys_dup(0);  // stderr

	print_to_console("User process entry\n\r");


  call_sys_exec("/echo.elf", argv);
}

void user_process1() 
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
		// loop1("abcde");
    char *argv[] = {"arg0", "arg1", 0};
    call_sys_exec("/echo.elf", argv);
	} else {
		loop1("12345");
	}
}
