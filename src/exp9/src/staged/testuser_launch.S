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
