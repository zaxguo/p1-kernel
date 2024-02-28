#include "user_sys.h"
#include "user.h"
#include "printf.h"

static void user_delay (unsigned long cnt) {
	volatile unsigned long c = cnt; 
	while (c)
		c--; 
}

static unsigned int
strlen(const char *s)
{
  int n;

  for(n = 0; s[n]; n++)
    ;
  return n;
}

void print_to_console(char *msg) {
	call_sys_write(0, msg, strlen(msg)); 
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

void user_process() 
{
	print_to_console("User process entry\n\r");
	int pid = call_sys_fork();
	if (pid < 0) {
		print_to_console("Error during fork\n\r");
		call_sys_exit(1);
		return;
	}
	print_to_console("fork() succeeds \n\r");
	if (pid == 0){
		loop("abcde");
	} else {
		loop("12345");
	}
}

