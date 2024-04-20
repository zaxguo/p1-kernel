/* 

Mar 10 24: ok to compile, but fail to link, b/c argv contains refs to path...
error related to "asm array of pointers relocation truncated to fit:...

b/c argv and path are too far away in the kern binary image? 

due to that we don't have such fine control of linker? 

xv6 seems to compile this individually, and hardcode insns into kernel binary?


as of now, still use the launcher (user.c) in C, which must be compiled using -O0
*/


.section .data

// Define the strings
path:
    .asciz "path"
argv1:
    .asciz "argv1"
argv2:
    .asciz "argv2"

// Define the array of pointers
argv:
    .word path
    .word argv1
    .word argv2
    .word 0   // Null pointer to terminate the array



