#include "../param.h"
#include "../stat.h"
#include "../fcntl.h"
#include "user.h"

#define CONSOLE 1     // major num for device console

const char msg[] = "--- HELLO USER SPACE ----- \n";

int
main(int argc, char *argv[])
{
  int i;

#if 0   // no need. exec() will preserve fds
  if(open("console", O_RDWR) < 0){
		mknod("console", CONSOLE, 0);
		open("console", O_RDWR);
  }
  dup(0);  // stdout
  dup(0);  // stderr
#endif

  printf(" --- HELLO USER SPACE ----- \n");
  printf("argc %d, argv[0] %s, argv[1] %s\n", argc, argv[0], argv[1]);

  // write(1, msg, strlen(msg)); 

  // NB: argv[0] should be path itself
  for(i = 1; i < argc; i++){
    write(1, argv[i], strlen(argv[i]));
    if(i + 1 < argc){
      write(1, " ", 1);
    } else {
      write(1, "\n", 1);
    }
  }
  exit(0);
} 
