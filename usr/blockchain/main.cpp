#include <stdio.h>
#include "Blockchain.h"
#include "vos.h"

class Test {
public:
  Test()  { printf("%s,%d: Hello, Project-N!\n", __func__, __LINE__); }
  ~Test() { printf("%s,%d: Goodbye, Project-N!\n", __func__, __LINE__); }
};
Test test;

extern "C" {
void __libc_init_array(void);       // newlib init.c; not useful besides calling _init()
void __libc_fini_array(void);       // ditto. 
extern void _fini();
void _init(void);
}

int main(int argc, char **args) {
    int difficulty = 4;
    enum {NBLOCKS=3};
    unsigned t0; 

    printf("argc is %d\n", argc); 

    if (argc>1 && args != NULL && args[1][0] >= '0' && args[1][0] <= '9') {
        difficulty = args[1][0] - '0';
    }
    printf("Using difficulty = %d\n", difficulty);

    const char *input_str[NBLOCKS] = {
        "Block 1 Data",
        "Block 2 Data",
        "Block 3 Data",
    };

    for (int i=0; i<NBLOCKS;i++) {
        t0 = uptime_ms(); 
        Blockchain bChain(difficulty);
        bChain.AddBlock(i+1, input_str[i]);
        printf("Done mining block %d...%d ms\n", i+1, uptime_ms() - t0);
    }

    return 0;
}