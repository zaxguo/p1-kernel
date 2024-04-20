//  do this in .S, as naked attribute never supported by gcc for aarch64? https://gcc.gnu.org/legacy-ml/gcc-bugs/2016-10/msg00510.html

.macro switch_in
    mov x9, sp   // cannot ldr/str with sp. ok to use x9 (caller saved
    stp d8, d9, [x0, 0x00] 
    stp d10, d11, [x0, 0x10] 
    stp d12, d13, [x0, 0x20] 
    stp d14, d15, [x0, 0x30] 
    stp x19, x20, [x0, 0x40] 
    stp x21, x22, [x0, 0x50] 
    stp x23, x24, [x0, 0x60] 
    stp x25, x26, [x0, 0x70] 
    stp x27, x28, [x0, 0x80] 
    stp x29, x9,  [x0, 0x90]        // x9==old sp
    str lr,       [x0, 0xa0] 
.endm

.macro switch_out
    ldp d8, d9,   [x1, 0x00] 
    ldp d10, d11, [x1, 0x10] 
    ldp d12, d13, [x1, 0x20] 
    ldp d14, d15, [x1, 0x30] 
    ldp x19, x20, [x1, 0x40] 
    ldp x21, x22, [x1, 0x50] 
    ldp x23, x24, [x1, 0x60] 
    ldp x25, x26, [x1, 0x70] 
    ldp x27, x28, [x1, 0x80] 
    ldp x29, x9,  [x1, 0x90]        //x9==new sp
    ldr lr,       [x1, 0xa0]         // (aarch64 cannot ldr to pc)
    mov sp, x9
    ret         // jump to where lr points to 
.endm

.globl ampi_co_jump_arg
ampi_co_jump_arg:
    switch_in
    mov x0, x2
    switch_out

.globl ampi_co_jump
ampi_co_jump:
    switch_in   
    switch_out

