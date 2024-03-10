// the kernel launcher for user tasks

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

#if 0       // wont work 
char usertests[][] = {
    {"/usertests.elf"}, // path
    {"/usertests.elf"}, 
    {"sbrkbasic"},
    0
};
#endif 

// make sure they are linked in user va
// are there better ways?? 
// args must be in user va. not static (kernel va)

#define USER_PROGRAM1(name, arg0, arg1)  \
    char path[] = {name};            \
    char argv0[] = {arg0};            \
    char argv1[] = {arg1};            \
    char *argv[] = {argv0, argv1, 0};

#define USER_PROGRAM2(name, arg0, arg1, arg2)  \
    char path[] = {name};            \
    char argv0[] = {arg0};            \
    char argv1[] = {arg1};            \
    char argv2[] = {arg2};            \
    char *argv[] = {argv0, argv1, argv2, 0};

#define USER_PROGRAM3(name, arg0, arg1, arg2, arg3)  \
    char path[] = {name};            \
    char argv0[] = {arg0};            \
    char argv1[] = {arg1};            \
    char argv2[] = {arg2};            \
    char argv3[] = {arg3};            \
    char *argv[] = {argv0, argv1, argv2, argv3, 0};



// "launcher" for standalone user programs
void user_process() {
    // won't work as "arg0"	const string will be linked to kernel va.
    // exec() expecting user va will fail to "copyin" them
    // char *argv[] = {"arg0", "arg1", 0};
    // char *argv[] = {arg0, arg1, arg2, 0};
	// char *argv[] = {arg0, arg1, 0};

    // variables defined on stack... forced to load based on PC relative 

    
    // USER_PROGRAM1("/echo.elf", "/echo.elf", "aaa");    
    // USER_PROGRAM1("/ls.elf", "/ls.elf", "/");    
    // USER_PROGRAM1("/mkdir.elf", "/mkdir.elf", "ccc");    
    // USER_PROGRAM1("/forktest.elf", "/forktest.elf", "/");    

    // USER_PROGRAM1("usertests.elf", "/usertests.elf", "sbrkbasic");    
    // USER_PROGRAM1("usertests.elf", "/usertests.elf", "sbrkmuch");    
    // USER_PROGRAM1("/usertests.elf", "/usertests.elf", "rwsbrk");    
    //  USER_PROGRAM1("/usertests.elf", "/usertests.elf", "sbrkarg");    

    // USER_PROGRAM1("/usertests.elf", "/usertests.elf", "killstatus");    
    // USER_PROGRAM1("/usertests.elf", "/usertests.elf", "kernmem");    
    // USER_PROGRAM1("/usertests.elf", "/usertests.elf", "copyin");    
    // USER_PROGRAM1("/usertests.elf", "/usertests.elf", "copyout");    
    // USER_PROGRAM1("/usertests.elf", "/usertests.elf", "copyinstr1");    
    // USER_PROGRAM1("/usertests.elf", "/usertests.elf", "copyinstr2");    
    USER_PROGRAM1("/usertests.elf", "/usertests.elf", "copyinstr3");    

    char console[] = {"console"}; 

    if (call_sys_open(console, O_RDWR) < 0) {
        call_sys_mknod(console, CONSOLE, 0);
        call_sys_open(console, O_RDWR);
    }
    call_sys_dup(0); // stdout
    call_sys_dup(0); // stderr

    char msg[] = {"User process entry\n\r"};
    print_to_console(msg);
    print_to_console(path);

    call_sys_exec(path, argv);
}

void user_process1() {
    if (call_sys_open("console", O_RDWR) < 0) {
        call_sys_mknod("console", CONSOLE, 0);
        call_sys_open("console", O_RDWR);
    }
    call_sys_dup(0); // stdout
    call_sys_dup(0); // stderr

    print_to_console("User process entry\n\r");

    int pid = call_sys_fork();
    if (pid < 0) {
        print_to_console("Error during fork\n\r");
        call_sys_exit(1);
        return;
    }
    print_to_console("fork() succeeds\n\r");

    static char *argv[] = {"arg0", "arg1", 0};

    if (pid == 0) {
        // loop1("abcde");
        call_sys_exec("/echo.elf", argv);
    } else {
        loop1("12345");
    }
}

