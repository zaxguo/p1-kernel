
build/kernel8.elf:     file format elf64-littleaarch64
build/kernel8.elf


Disassembly of section .text.boot:

ffff000040080000 <_start>:

.section ".text.boot"

.globl _start
_start:
	mrs	x0, mpidr_el1		
ffff000040080000:	d53800a0 	mrs	x0, mpidr_el1
	and	x0, x0,#0xFF		// Check processor id
ffff000040080004:	92401c00 	and	x0, x0, #0xff
	cbz	x0, master		// Hang for all non-primary CPU
ffff000040080008:	b4000060 	cbz	x0, ffff000040080014 <master>
	b	proc_hang
ffff00004008000c:	14000001 	b	ffff000040080010 <proc_hang>

ffff000040080010 <proc_hang>:

proc_hang: 
	b proc_hang
ffff000040080010:	14000000 	b	ffff000040080010 <proc_hang>

ffff000040080014 <master>:

master:
	ldr	x0, =SCTLR_VALUE_MMU_DISABLED
ffff000040080014:	58000f20 	ldr	x0, ffff0000400801f8 <__create_page_tables+0xbc>
	msr	sctlr_el1, x0		
ffff000040080018:	d5181000 	msr	sctlr_el1, x0
	
	# check the current exception level: EL3 (rpi3 hardware) or EL2 (qemu)?
	# both eret to EL1 
	mrs x0, CurrentEL
ffff00004008001c:	d5384240 	mrs	x0, currentel
  	lsr x0, x0, #2
ffff000040080020:	d342fc00 	lsr	x0, x0, #2
	cmp x0, #3
ffff000040080024:	f1000c1f 	cmp	x0, #0x3
	beq el3		
ffff000040080028:	54000120 	b.eq	ffff00004008004c <el3>  // b.none

	# set EL1 as AArch64
	mrs	x0, hcr_el2
ffff00004008002c:	d53c1100 	mrs	x0, hcr_el2
	orr	x0, x0, #HCR_RW  
ffff000040080030:	b2610000 	orr	x0, x0, #0x80000000
	msr	hcr_el2, x0
ffff000040080034:	d51c1100 	msr	hcr_el2, x0

	mov x0, #SPSR_VALUE
ffff000040080038:	d28038a0 	mov	x0, #0x1c5                 	// #453
	msr	spsr_el2, x0
ffff00004008003c:	d51c4000 	msr	spsr_el2, x0

	adr	x0, el1_entry
ffff000040080040:	10000180 	adr	x0, ffff000040080070 <el1_entry>
	msr	elr_el2, x0
ffff000040080044:	d51c4020 	msr	elr_el2, x0
	eret
ffff000040080048:	d69f03e0 	eret

ffff00004008004c <el3>:

el3:
  	ldr x0, =HCR_VALUE
ffff00004008004c:	58000da0 	ldr	x0, ffff000040080200 <__create_page_tables+0xc4>
  	msr hcr_el2, x0
ffff000040080050:	d51c1100 	msr	hcr_el2, x0

	ldr	x0, =SCR_VALUE
ffff000040080054:	58000da0 	ldr	x0, ffff000040080208 <__create_page_tables+0xcc>
	msr	scr_el3, x0
ffff000040080058:	d51e1100 	msr	scr_el3, x0

	ldr	x0, =SPSR_VALUE
ffff00004008005c:	58000da0 	ldr	x0, ffff000040080210 <__create_page_tables+0xd4>
	msr	spsr_el3, x0
ffff000040080060:	d51e4000 	msr	spsr_el3, x0

	adr	x0, el1_entry		
ffff000040080064:	10000060 	adr	x0, ffff000040080070 <el1_entry>
	msr	elr_el3, x0
ffff000040080068:	d51e4020 	msr	elr_el3, x0

	eret				
ffff00004008006c:	d69f03e0 	eret

ffff000040080070 <el1_entry>:

el1_entry:
	ldr	x0, =bss_begin
ffff000040080070:	58000d40 	ldr	x0, ffff000040080218 <__create_page_tables+0xdc>
	ldr	x1, =bss_end
ffff000040080074:	58000d61 	ldr	x1, ffff000040080220 <__create_page_tables+0xe4>
	sub	x1, x1, x0
ffff000040080078:	cb000021 	sub	x1, x1, x0
	bl 	memzero
ffff00004008007c:	940014a4 	bl	ffff00004008530c <memzero>
// pgtable tree at TTBR0 that maps all physical DRAM (0 -- PHYS_MEMORY_SIZE) to virtual 
// addresses with the same values. That keeps translation going on at the switch of MMU. 
//
// Cf: https://github.com/s-matyukevich/raspberry-pi-os/issues/8
// https://www.raspberrypi.org/forums/viewtopic.php?t=222408
	bl	__create_idmap
ffff000040080080:	94000011 	bl	ffff0000400800c4 <__create_idmap>
	adrp	x0, idmap_dir
ffff000040080084:	d0000c00 	adrp	x0, ffff000040202000 <idmap_dir>
	msr	ttbr0_el1, x0
ffff000040080088:	d5182000 	msr	ttbr0_el1, x0
#endif

	// create kernel's pgtable (for memory and IO)
	bl 	__create_page_tables
ffff00004008008c:	9400002c 	bl	ffff00004008013c <__create_page_tables>

	// set virt sp (assuming linear mapping, phys 0 --> virt VA_START)
	// NB: we won't the sp until mmu is on
	mov	x0, #VA_START			
ffff000040080090:	d2ffffe0 	mov	x0, #0xffff000000000000    	// #-281474976710656
	ldr x1, =LOW_MEMORY
ffff000040080094:	58000ca1 	ldr	x1, ffff000040080228 <__create_page_tables+0xec>
	add	sp, x0, x1		
ffff000040080098:	8b21601f 	add	sp, x0, x1

	// load kernel's pgtable
	adrp	x0, pg_dir			// @pg_dir: the virtual base address of the pgtables. cf utils.h
ffff00004008009c:	b0000c20 	adrp	x0, ffff000040205000 <pg_dir>
	msr		ttbr1_el1, x0
ffff0000400800a0:	d5182020 	msr	ttbr1_el1, x0

	// configuring mm translation (granule, user/kernel split, etc)
	// tcr_el1: Translation Control Register. cf mmu.h
	ldr	x0, =(TCR_VALUE)		
ffff0000400800a4:	58000c60 	ldr	x0, ffff000040080230 <__create_page_tables+0xf4>
	msr	tcr_el1, x0 
ffff0000400800a8:	d5182040 	msr	tcr_el1, x0

	// memory attributes. we only set two: for mem and for io. cf mmu.h
	ldr	x0, =(MAIR_VALUE)
ffff0000400800ac:	58000c60 	ldr	x0, ffff000040080238 <__create_page_tables+0xfc>
	msr	mair_el1, x0
ffff0000400800b0:	d518a200 	msr	mair_el1, x0

	// load the linking (virt) addr of kernel_main
	ldr	x2, =kernel_main
ffff0000400800b4:	58000c62 	ldr	x2, ffff000040080240 <__create_page_tables+0x104>

	mov	x0, #SCTLR_MMU_ENABLED				
ffff0000400800b8:	d2800020 	mov	x0, #0x1                   	// #1
	msr	sctlr_el1, x0	// BOOM! we are on virtual after this.
ffff0000400800bc:	d5181000 	msr	sctlr_el1, x0

	// go to the virt addr of kernel_main
	br 	x2
ffff0000400800c0:	d61f0040 	br	x2

ffff0000400800c4 <__create_idmap>:
	_create_block_map \tbl, \phys, \start, \end, \flags, SECTION_SHIFT, \tmp1
	.endm

#ifdef USE_QEMU
__create_idmap:
	mov	x29, x30
ffff0000400800c4:	aa1e03fd 	mov	x29, x30
	
	adrp	x0, idmap_dir		// idmap_dir allocated in linker-qemu.ld, 3 pages. 
ffff0000400800c8:	d0000c00 	adrp	x0, ffff000040202000 <idmap_dir>
	mov	x1, #PG_DIR_SIZE		// 3pgs, PGD|PUD|PMD
ffff0000400800cc:	d2860001 	mov	x1, #0x3000                	// #12288
	bl	memzero
ffff0000400800d0:	9400148f 	bl	ffff00004008530c <memzero>

	adrp	x0, idmap_dir
ffff0000400800d4:	d0000c00 	adrp	x0, ffff000040202000 <idmap_dir>
	mov	x1, xzr					// starting mapping from 0x0 (phys device base)
ffff0000400800d8:	aa1f03e1 	mov	x1, xzr
	create_table_entry x0, x1, PGD_SHIFT, x2, x3 	// install the PGD entry
ffff0000400800dc:	d367fc22 	lsr	x2, x1, #39
ffff0000400800e0:	92402042 	and	x2, x2, #0x1ff
ffff0000400800e4:	91400403 	add	x3, x0, #0x1, lsl #12
ffff0000400800e8:	b2400463 	orr	x3, x3, #0x3
ffff0000400800ec:	f8227803 	str	x3, [x0, x2, lsl #3]
ffff0000400800f0:	91400400 	add	x0, x0, #0x1, lsl #12
	// after this, x0 points to the new PUD table
	
	ldr	x1, =PHYS_BASE
ffff0000400800f4:	58000aa1 	ldr	x1, ffff000040080248 <__create_page_tables+0x10c>
	ldr	x2, =PHYS_BASE
ffff0000400800f8:	58000a82 	ldr	x2, ffff000040080248 <__create_page_tables+0x10c>
	ldr	x3, =(PHYS_BASE + PHYS_SIZE - SUPERSECTION_SIZE)
ffff0000400800fc:	58000a63 	ldr	x3, ffff000040080248 <__create_page_tables+0x10c>
	create_block_map_supersection x0, x1, x2, x3, MMU_FLAGS, x4
ffff000040080100:	d35efc42 	lsr	x2, x2, #30
ffff000040080104:	92402042 	and	x2, x2, #0x1ff
ffff000040080108:	d35efc63 	lsr	x3, x3, #30
ffff00004008010c:	92402063 	and	x3, x3, #0x1ff
ffff000040080110:	d35efc21 	lsr	x1, x1, #30
ffff000040080114:	d28080a4 	mov	x4, #0x405                 	// #1029
ffff000040080118:	aa017881 	orr	x1, x4, x1, lsl #30
ffff00004008011c:	f8227801 	str	x1, [x0, x2, lsl #3]
ffff000040080120:	91000442 	add	x2, x2, #0x1
ffff000040080124:	d2a80004 	mov	x4, #0x40000000            	// #1073741824
ffff000040080128:	8b040021 	add	x1, x1, x4
ffff00004008012c:	eb03005f 	cmp	x2, x3
ffff000040080130:	54ffff69 	b.ls	ffff00004008011c <__create_idmap+0x58>  // b.plast

	mov	x30, x29
ffff000040080134:	aa1d03fe 	mov	x30, x29
	ret
ffff000040080138:	d65f03c0 	ret

ffff00004008013c <__create_page_tables>:
#endif

__create_page_tables:
	mov		x29, x30						// save return address
ffff00004008013c:	aa1e03fd 	mov	x29, x30

	// clear the mem region backing pgtables
	adrp 	x0, pg_dir
ffff000040080140:	b0000c20 	adrp	x0, ffff000040205000 <pg_dir>
	mov		x1, #PG_DIR_SIZE
ffff000040080144:	d2860001 	mov	x1, #0x3000                	// #12288
	bl 		memzero
ffff000040080148:	94001471 	bl	ffff00004008530c <memzero>

	// allocate one PUD & one PMD; link PGD (pg_dir)->PUD
	adrp	x0, pg_dir
ffff00004008014c:	b0000c20 	adrp	x0, ffff000040205000 <pg_dir>
	mov		x1, #VA_START 
ffff000040080150:	d2ffffe1 	mov	x1, #0xffff000000000000    	// #-281474976710656
	create_table_entry x0, x1, PGD_SHIFT, x2, x3
ffff000040080154:	d367fc22 	lsr	x2, x1, #39
ffff000040080158:	92402042 	and	x2, x2, #0x1ff
ffff00004008015c:	91400403 	add	x3, x0, #0x1, lsl #12
ffff000040080160:	b2400463 	orr	x3, x3, #0x3
ffff000040080164:	f8227803 	str	x3, [x0, x2, lsl #3]
ffff000040080168:	91400400 	add	x0, x0, #0x1, lsl #12
	// after this, x0 points to the new PUD table

	/* Mapping device memory. Phys addr range: DEVICE_BASE(0)--DEVICE_SIZE(0x40000000) */
	mov 	x1, #DEVICE_BASE						// x1 = start mapping from device base address 
ffff00004008016c:	d2800001 	mov	x1, #0x0                   	// #0
	ldr 	x2, =(VA_START + DEVICE_BASE)			// x2 = first virtual address
ffff000040080170:	58000702 	ldr	x2, ffff000040080250 <__create_page_tables+0x114>
	ldr		x3, =(VA_START + DEVICE_BASE + DEVICE_SIZE - SUPERSECTION_SIZE)	// x3 = the virtual base of the last section
ffff000040080174:	580006e3 	ldr	x3, ffff000040080250 <__create_page_tables+0x114>
	create_block_map_supersection x0, x1, x2, x3, MMU_DEVICE_FLAGS, x4
ffff000040080178:	d35efc42 	lsr	x2, x2, #30
ffff00004008017c:	92402042 	and	x2, x2, #0x1ff
ffff000040080180:	d35efc63 	lsr	x3, x3, #30
ffff000040080184:	92402063 	and	x3, x3, #0x1ff
ffff000040080188:	d35efc21 	lsr	x1, x1, #30
ffff00004008018c:	d2808024 	mov	x4, #0x401                 	// #1025
ffff000040080190:	aa017881 	orr	x1, x4, x1, lsl #30
ffff000040080194:	f8227801 	str	x1, [x0, x2, lsl #3]
ffff000040080198:	91000442 	add	x2, x2, #0x1
ffff00004008019c:	d2a80004 	mov	x4, #0x40000000            	// #1073741824
ffff0000400801a0:	8b040021 	add	x1, x1, x4
ffff0000400801a4:	eb03005f 	cmp	x2, x3
ffff0000400801a8:	54ffff69 	b.ls	ffff000040080194 <__create_page_tables+0x58>  // b.plast
	//_create_block_map x0, x1, x2, x3, MMU_DEVICE_FLAGS, SUPERSECTION_SHIFT, x4

	/* Mapping kernel and init stack. Phys addr range: 0x4000:0000, +PHYS_SIZE */
	mov 	x1, #PHYS_BASE				// x1 = starting phys addr. set x1 to 0. 
ffff0000400801ac:	d2a80001 	mov	x1, #0x40000000            	// #1073741824
	ldr 	x2, =(VA_START + DEVICE_BASE + DEVICE_SIZE)	 // x2 = the virtual base of the first section
ffff0000400801b0:	58000542 	ldr	x2, ffff000040080258 <__create_page_tables+0x11c>
	ldr		x3, =(VA_START + DEVICE_BASE + DEVICE_SIZE + PHYS_SIZE - SUPERSECTION_SIZE)  // x3 = the virtual base of the last section
ffff0000400801b4:	58000523 	ldr	x3, ffff000040080258 <__create_page_tables+0x11c>
	create_block_map_supersection x0, x1, x2, x3, MMU_FLAGS, x4
ffff0000400801b8:	d35efc42 	lsr	x2, x2, #30
ffff0000400801bc:	92402042 	and	x2, x2, #0x1ff
ffff0000400801c0:	d35efc63 	lsr	x3, x3, #30
ffff0000400801c4:	92402063 	and	x3, x3, #0x1ff
ffff0000400801c8:	d35efc21 	lsr	x1, x1, #30
ffff0000400801cc:	d28080a4 	mov	x4, #0x405                 	// #1029
ffff0000400801d0:	aa017881 	orr	x1, x4, x1, lsl #30
ffff0000400801d4:	f8227801 	str	x1, [x0, x2, lsl #3]
ffff0000400801d8:	91000442 	add	x2, x2, #0x1
ffff0000400801dc:	d2a80004 	mov	x4, #0x40000000            	// #1073741824
ffff0000400801e0:	8b040021 	add	x1, x1, x4
ffff0000400801e4:	eb03005f 	cmp	x2, x3
ffff0000400801e8:	54ffff69 	b.ls	ffff0000400801d4 <__create_page_tables+0x98>  // b.plast

	mov	x30, x29						// restore return address
ffff0000400801ec:	aa1d03fe 	mov	x30, x29
ffff0000400801f0:	d65f03c0 	ret
ffff0000400801f4:	00000000 	.inst	0x00000000 ; undefined
ffff0000400801f8:	30d00800 	.word	0x30d00800
ffff0000400801fc:	00000000 	.word	0x00000000
ffff000040080200:	80000000 	.word	0x80000000
ffff000040080204:	00000000 	.word	0x00000000
ffff000040080208:	00000431 	.word	0x00000431
ffff00004008020c:	00000000 	.word	0x00000000
ffff000040080210:	000001c5 	.word	0x000001c5
ffff000040080214:	00000000 	.word	0x00000000
ffff000040080218:	40182348 	.word	0x40182348
ffff00004008021c:	ffff0000 	.word	0xffff0000
ffff000040080220:	40201cd0 	.word	0x40201cd0
ffff000040080224:	ffff0000 	.word	0xffff0000
ffff000040080228:	40400000 	.word	0x40400000
ffff00004008022c:	00000000 	.word	0x00000000
ffff000040080230:	80100010 	.word	0x80100010
ffff000040080234:	00000000 	.word	0x00000000
ffff000040080238:	00004400 	.word	0x00004400
ffff00004008023c:	00000000 	.word	0x00000000
ffff000040080240:	400850bc 	.word	0x400850bc
ffff000040080244:	ffff0000 	.word	0xffff0000
ffff000040080248:	40000000 	.word	0x40000000
	...
ffff000040080254:	ffff0000 	.word	0xffff0000
ffff000040080258:	40000000 	.word	0x40000000
ffff00004008025c:	ffff0000 	.word	0xffff0000

Disassembly of section .text.user:

ffff000040081000 <loop>:
#include "user_sys.h"
#include "user.h"
#include "printf.h"

void loop(char* str)
{
ffff000040081000:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
ffff000040081004:	910003fd 	mov	x29, sp
ffff000040081008:	f9000fe0 	str	x0, [sp, #24]
	char buf[2] = {""};
ffff00004008100c:	790053ff 	strh	wzr, [sp, #40]
	while (1){
		for (int i = 0; i < 5; i++){
ffff000040081010:	b9002fff 	str	wzr, [sp, #44]
ffff000040081014:	1400000e 	b	ffff00004008104c <loop+0x4c>
			buf[0] = str[i];
ffff000040081018:	b9802fe0 	ldrsw	x0, [sp, #44]
ffff00004008101c:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040081020:	8b000020 	add	x0, x1, x0
ffff000040081024:	39400000 	ldrb	w0, [x0]
ffff000040081028:	3900a3e0 	strb	w0, [sp, #40]
			call_sys_write(buf);
ffff00004008102c:	9100a3e0 	add	x0, sp, #0x28
ffff000040081030:	94000029 	bl	ffff0000400810d4 <call_sys_write>
			user_delay(1000000);
ffff000040081034:	d2884800 	mov	x0, #0x4240                	// #16960
ffff000040081038:	f2a001e0 	movk	x0, #0xf, lsl #16
ffff00004008103c:	94000023 	bl	ffff0000400810c8 <user_delay>
		for (int i = 0; i < 5; i++){
ffff000040081040:	b9402fe0 	ldr	w0, [sp, #44]
ffff000040081044:	11000400 	add	w0, w0, #0x1
ffff000040081048:	b9002fe0 	str	w0, [sp, #44]
ffff00004008104c:	b9402fe0 	ldr	w0, [sp, #44]
ffff000040081050:	7100101f 	cmp	w0, #0x4
ffff000040081054:	54fffe2d 	b.le	ffff000040081018 <loop+0x18>
ffff000040081058:	17ffffee 	b	ffff000040081010 <loop+0x10>

ffff00004008105c <user_process>:
		}
	}
}

void user_process() 
{
ffff00004008105c:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
ffff000040081060:	910003fd 	mov	x29, sp
	call_sys_write("User process\n\r");
ffff000040081064:	90000000 	adrp	x0, ffff000040081000 <loop>
ffff000040081068:	9103e000 	add	x0, x0, #0xf8
ffff00004008106c:	9400001a 	bl	ffff0000400810d4 <call_sys_write>
	int pid = call_sys_fork();
ffff000040081070:	9400001f 	bl	ffff0000400810ec <call_sys_fork>
ffff000040081074:	b9001fe0 	str	w0, [sp, #28]
	if (pid < 0) {
ffff000040081078:	b9401fe0 	ldr	w0, [sp, #28]
ffff00004008107c:	7100001f 	cmp	w0, #0x0
ffff000040081080:	540000ca 	b.ge	ffff000040081098 <user_process+0x3c>  // b.tcont
		call_sys_write("Error during fork\n\r");
ffff000040081084:	90000000 	adrp	x0, ffff000040081000 <loop>
ffff000040081088:	91042000 	add	x0, x0, #0x108
ffff00004008108c:	94000012 	bl	ffff0000400810d4 <call_sys_write>
		call_sys_exit();
ffff000040081090:	94000014 	bl	ffff0000400810e0 <call_sys_exit>
		return;
ffff000040081094:	1400000b 	b	ffff0000400810c0 <user_process+0x64>
	}
	if (pid == 0){
ffff000040081098:	b9401fe0 	ldr	w0, [sp, #28]
ffff00004008109c:	7100001f 	cmp	w0, #0x0
ffff0000400810a0:	540000a1 	b.ne	ffff0000400810b4 <user_process+0x58>  // b.any
		loop("abcde");
ffff0000400810a4:	90000000 	adrp	x0, ffff000040081000 <loop>
ffff0000400810a8:	91048000 	add	x0, x0, #0x120
ffff0000400810ac:	97ffffd5 	bl	ffff000040081000 <loop>
ffff0000400810b0:	14000004 	b	ffff0000400810c0 <user_process+0x64>
	} else {
		loop("12345");
ffff0000400810b4:	90000000 	adrp	x0, ffff000040081000 <loop>
ffff0000400810b8:	9104a000 	add	x0, x0, #0x128
ffff0000400810bc:	97ffffd1 	bl	ffff000040081000 <loop>
	}
}
ffff0000400810c0:	a8c27bfd 	ldp	x29, x30, [sp], #32
ffff0000400810c4:	d65f03c0 	ret

ffff0000400810c8 <user_delay>:
.set SYS_FORK_NUMBER, 1 	
.set SYS_EXIT_NUMBER, 2 	

.globl user_delay
user_delay:
	subs x0, x0, #1
ffff0000400810c8:	f1000400 	subs	x0, x0, #0x1
	bne user_delay
ffff0000400810cc:	54ffffe1 	b.ne	ffff0000400810c8 <user_delay>  // b.any
	ret
ffff0000400810d0:	d65f03c0 	ret

ffff0000400810d4 <call_sys_write>:

.globl call_sys_write
call_sys_write:
	mov w8, #SYS_WRITE_NUMBER	
ffff0000400810d4:	52800008 	mov	w8, #0x0                   	// #0
	svc #0
ffff0000400810d8:	d4000001 	svc	#0x0
	ret
ffff0000400810dc:	d65f03c0 	ret

ffff0000400810e0 <call_sys_exit>:

.globl call_sys_exit
call_sys_exit:
	mov w8, #SYS_EXIT_NUMBER	
ffff0000400810e0:	52800048 	mov	w8, #0x2                   	// #2
	svc #0
ffff0000400810e4:	d4000001 	svc	#0x0
	ret
ffff0000400810e8:	d65f03c0 	ret

ffff0000400810ec <call_sys_fork>:

.globl call_sys_fork
call_sys_fork:
	mov w8, #SYS_FORK_NUMBER	
ffff0000400810ec:	52800028 	mov	w8, #0x1                   	// #1
	svc #0
ffff0000400810f0:	d4000001 	svc	#0x0
	ret
ffff0000400810f4:	d65f03c0 	ret

Disassembly of section .text:

ffff000040081800 <mbox_call>:

/**
 * Make a mailbox call. Returns 0 on failure, non-zero on success
 */
int mbox_call(unsigned char ch)
{
ffff000040081800:	d10083ff 	sub	sp, sp, #0x20
ffff000040081804:	39003fe0 	strb	w0, [sp, #15]
    unsigned int r = (((unsigned int)((unsigned long)&mbox)&~0xF) | (ch&0xF));
ffff000040081808:	39403fe0 	ldrb	w0, [sp, #15]
ffff00004008180c:	12000c01 	and	w1, w0, #0xf
ffff000040081810:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081814:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081818:	121c6c00 	and	w0, w0, #0xfffffff0
ffff00004008181c:	2a000020 	orr	w0, w1, w0
ffff000040081820:	b9001fe0 	str	w0, [sp, #28]
    /* wait until we can write to the mailbox */
    do{asm volatile("nop");}while(*MBOX_STATUS & MBOX_FULL);
ffff000040081824:	d503201f 	nop
ffff000040081828:	d2971300 	mov	x0, #0xb898                	// #47256
ffff00004008182c:	f2a7e000 	movk	x0, #0x3f00, lsl #16
ffff000040081830:	b9400000 	ldr	w0, [x0]
ffff000040081834:	7100001f 	cmp	w0, #0x0
ffff000040081838:	54ffff6b 	b.lt	ffff000040081824 <mbox_call+0x24>  // b.tstop
    /* write the address of our message to the mailbox with channel identifier */
    *MBOX_WRITE = r;
ffff00004008183c:	d2971400 	mov	x0, #0xb8a0                	// #47264
ffff000040081840:	f2a7e000 	movk	x0, #0x3f00, lsl #16
ffff000040081844:	b9401fe1 	ldr	w1, [sp, #28]
ffff000040081848:	b9000001 	str	w1, [x0]
    /* now wait for the response */
    while(1) {
        /* is there a response? */
        do{asm volatile("nop");}while(*MBOX_STATUS & MBOX_EMPTY);
ffff00004008184c:	d503201f 	nop
ffff000040081850:	d2971300 	mov	x0, #0xb898                	// #47256
ffff000040081854:	f2a7e000 	movk	x0, #0x3f00, lsl #16
ffff000040081858:	b9400000 	ldr	w0, [x0]
ffff00004008185c:	12020000 	and	w0, w0, #0x40000000
ffff000040081860:	7100001f 	cmp	w0, #0x0
ffff000040081864:	54ffff41 	b.ne	ffff00004008184c <mbox_call+0x4c>  // b.any
        /* is it a response to our message? */
        if(r == *MBOX_READ)
ffff000040081868:	d2971000 	mov	x0, #0xb880                	// #47232
ffff00004008186c:	f2a7e000 	movk	x0, #0x3f00, lsl #16
ffff000040081870:	b9400000 	ldr	w0, [x0]
ffff000040081874:	b9401fe1 	ldr	w1, [sp, #28]
ffff000040081878:	6b00003f 	cmp	w1, w0
ffff00004008187c:	54fffe81 	b.ne	ffff00004008184c <mbox_call+0x4c>  // b.any
            /* is it a valid successful response? */
            return mbox[1]==MBOX_RESPONSE;
ffff000040081880:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081884:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081888:	b9400401 	ldr	w1, [x0, #4]
ffff00004008188c:	52b00000 	mov	w0, #0x80000000            	// #-2147483648
ffff000040081890:	6b00003f 	cmp	w1, w0
ffff000040081894:	1a9f17e0 	cset	w0, eq  // eq = none
ffff000040081898:	12001c00 	and	w0, w0, #0xff
    }
    return 0;
}
ffff00004008189c:	910083ff 	add	sp, sp, #0x20
ffff0000400818a0:	d65f03c0 	ret

ffff0000400818a4 <lfb_init>:

/**
 * Set screen resolution to 1024x768
 */
void lfb_init()
{
ffff0000400818a4:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
ffff0000400818a8:	910003fd 	mov	x29, sp
    mbox[0] = 35*4;
ffff0000400818ac:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400818b0:	f9401c00 	ldr	x0, [x0, #56]
ffff0000400818b4:	52801181 	mov	w1, #0x8c                  	// #140
ffff0000400818b8:	b9000001 	str	w1, [x0]
    mbox[1] = MBOX_REQUEST;
ffff0000400818bc:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400818c0:	f9401c00 	ldr	x0, [x0, #56]
ffff0000400818c4:	b900041f 	str	wzr, [x0, #4]

    mbox[2] = 0x48003;  //set phy wh
ffff0000400818c8:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400818cc:	f9401c00 	ldr	x0, [x0, #56]
ffff0000400818d0:	52900061 	mov	w1, #0x8003                	// #32771
ffff0000400818d4:	72a00081 	movk	w1, #0x4, lsl #16
ffff0000400818d8:	b9000801 	str	w1, [x0, #8]
    mbox[3] = 8;
ffff0000400818dc:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400818e0:	f9401c00 	ldr	x0, [x0, #56]
ffff0000400818e4:	52800101 	mov	w1, #0x8                   	// #8
ffff0000400818e8:	b9000c01 	str	w1, [x0, #12]
    mbox[4] = 8;
ffff0000400818ec:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400818f0:	f9401c00 	ldr	x0, [x0, #56]
ffff0000400818f4:	52800101 	mov	w1, #0x8                   	// #8
ffff0000400818f8:	b9001001 	str	w1, [x0, #16]
    mbox[5] = width;         //FrameBufferInfo.width
ffff0000400818fc:	90000800 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff000040081900:	91170000 	add	x0, x0, #0x5c0
ffff000040081904:	b9400001 	ldr	w1, [x0]
ffff000040081908:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff00004008190c:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081910:	b9001401 	str	w1, [x0, #20]
    mbox[6] = height;          //FrameBufferInfo.height
ffff000040081914:	90000800 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff000040081918:	91171000 	add	x0, x0, #0x5c4
ffff00004008191c:	b9400001 	ldr	w1, [x0]
ffff000040081920:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081924:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081928:	b9001801 	str	w1, [x0, #24]

    mbox[7] = 0x48004;  //set virt wh
ffff00004008192c:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081930:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081934:	52900081 	mov	w1, #0x8004                	// #32772
ffff000040081938:	72a00081 	movk	w1, #0x4, lsl #16
ffff00004008193c:	b9001c01 	str	w1, [x0, #28]
    mbox[8] = 8;
ffff000040081940:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081944:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081948:	52800101 	mov	w1, #0x8                   	// #8
ffff00004008194c:	b9002001 	str	w1, [x0, #32]
    mbox[9] = 8;
ffff000040081950:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081954:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081958:	52800101 	mov	w1, #0x8                   	// #8
ffff00004008195c:	b9002401 	str	w1, [x0, #36]
    mbox[10] = vwidth;        //FrameBufferInfo.virtual_width
ffff000040081960:	90000800 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff000040081964:	91172000 	add	x0, x0, #0x5c8
ffff000040081968:	b9400001 	ldr	w1, [x0]
ffff00004008196c:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081970:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081974:	b9002801 	str	w1, [x0, #40]
    mbox[11] = vheight;         //FrameBufferInfo.virtual_height
ffff000040081978:	90000800 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff00004008197c:	91173000 	add	x0, x0, #0x5cc
ffff000040081980:	b9400001 	ldr	w1, [x0]
ffff000040081984:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081988:	f9401c00 	ldr	x0, [x0, #56]
ffff00004008198c:	b9002c01 	str	w1, [x0, #44]

    mbox[12] = 0x48009; //set virt offset
ffff000040081990:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081994:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081998:	52900121 	mov	w1, #0x8009                	// #32777
ffff00004008199c:	72a00081 	movk	w1, #0x4, lsl #16
ffff0000400819a0:	b9003001 	str	w1, [x0, #48]
    mbox[13] = 8;
ffff0000400819a4:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400819a8:	f9401c00 	ldr	x0, [x0, #56]
ffff0000400819ac:	52800101 	mov	w1, #0x8                   	// #8
ffff0000400819b0:	b9003401 	str	w1, [x0, #52]
    mbox[14] = 8;
ffff0000400819b4:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400819b8:	f9401c00 	ldr	x0, [x0, #56]
ffff0000400819bc:	52800101 	mov	w1, #0x8                   	// #8
ffff0000400819c0:	b9003801 	str	w1, [x0, #56]
    mbox[15] = offsetx;           //FrameBufferInfo.x_offset
ffff0000400819c4:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400819c8:	910d8000 	add	x0, x0, #0x360
ffff0000400819cc:	b9400001 	ldr	w1, [x0]
ffff0000400819d0:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400819d4:	f9401c00 	ldr	x0, [x0, #56]
ffff0000400819d8:	b9003c01 	str	w1, [x0, #60]
    mbox[16] = offsety;           //FrameBufferInfo.y.offset
ffff0000400819dc:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400819e0:	910d9000 	add	x0, x0, #0x364
ffff0000400819e4:	b9400001 	ldr	w1, [x0]
ffff0000400819e8:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400819ec:	f9401c00 	ldr	x0, [x0, #56]
ffff0000400819f0:	b9004001 	str	w1, [x0, #64]

    mbox[17] = 0x48005; //set depth
ffff0000400819f4:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400819f8:	f9401c00 	ldr	x0, [x0, #56]
ffff0000400819fc:	529000a1 	mov	w1, #0x8005                	// #32773
ffff000040081a00:	72a00081 	movk	w1, #0x4, lsl #16
ffff000040081a04:	b9004401 	str	w1, [x0, #68]
    mbox[18] = 4;
ffff000040081a08:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081a0c:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081a10:	52800081 	mov	w1, #0x4                   	// #4
ffff000040081a14:	b9004801 	str	w1, [x0, #72]
    mbox[19] = 4;
ffff000040081a18:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081a1c:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081a20:	52800081 	mov	w1, #0x4                   	// #4
ffff000040081a24:	b9004c01 	str	w1, [x0, #76]
    mbox[20] = 32;          //FrameBufferInfo.depth
ffff000040081a28:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081a2c:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081a30:	52800401 	mov	w1, #0x20                  	// #32
ffff000040081a34:	b9005001 	str	w1, [x0, #80]

    mbox[21] = 0x48006; //set pixel order
ffff000040081a38:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081a3c:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081a40:	529000c1 	mov	w1, #0x8006                	// #32774
ffff000040081a44:	72a00081 	movk	w1, #0x4, lsl #16
ffff000040081a48:	b9005401 	str	w1, [x0, #84]
    mbox[22] = 4;
ffff000040081a4c:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081a50:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081a54:	52800081 	mov	w1, #0x4                   	// #4
ffff000040081a58:	b9005801 	str	w1, [x0, #88]
    mbox[23] = 4;
ffff000040081a5c:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081a60:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081a64:	52800081 	mov	w1, #0x4                   	// #4
ffff000040081a68:	b9005c01 	str	w1, [x0, #92]
    mbox[24] = 1;           //RGB, not BGR preferably
ffff000040081a6c:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081a70:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081a74:	52800021 	mov	w1, #0x1                   	// #1
ffff000040081a78:	b9006001 	str	w1, [x0, #96]

    mbox[25] = 0x40001; //get framebuffer, gets alignment on request
ffff000040081a7c:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081a80:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081a84:	52800021 	mov	w1, #0x1                   	// #1
ffff000040081a88:	72a00081 	movk	w1, #0x4, lsl #16
ffff000040081a8c:	b9006401 	str	w1, [x0, #100]
    mbox[26] = 8;
ffff000040081a90:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081a94:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081a98:	52800101 	mov	w1, #0x8                   	// #8
ffff000040081a9c:	b9006801 	str	w1, [x0, #104]
    mbox[27] = 8;
ffff000040081aa0:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081aa4:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081aa8:	52800101 	mov	w1, #0x8                   	// #8
ffff000040081aac:	b9006c01 	str	w1, [x0, #108]
    mbox[28] = 4096;        //FrameBufferInfo.pointer
ffff000040081ab0:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081ab4:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081ab8:	52820001 	mov	w1, #0x1000                	// #4096
ffff000040081abc:	b9007001 	str	w1, [x0, #112]
    mbox[29] = 0;           //FrameBufferInfo.size
ffff000040081ac0:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081ac4:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081ac8:	b900741f 	str	wzr, [x0, #116]

    mbox[30] = 0x40008; //get pitch
ffff000040081acc:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081ad0:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081ad4:	52800101 	mov	w1, #0x8                   	// #8
ffff000040081ad8:	72a00081 	movk	w1, #0x4, lsl #16
ffff000040081adc:	b9007801 	str	w1, [x0, #120]
    mbox[31] = 4;
ffff000040081ae0:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081ae4:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081ae8:	52800081 	mov	w1, #0x4                   	// #4
ffff000040081aec:	b9007c01 	str	w1, [x0, #124]
    mbox[32] = 4;
ffff000040081af0:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081af4:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081af8:	52800081 	mov	w1, #0x4                   	// #4
ffff000040081afc:	b9008001 	str	w1, [x0, #128]
    mbox[33] = 0;           //FrameBufferInfo.pitch
ffff000040081b00:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081b04:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081b08:	b900841f 	str	wzr, [x0, #132]

    mbox[34] = MBOX_TAG_LAST;
ffff000040081b0c:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081b10:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081b14:	b900881f 	str	wzr, [x0, #136]

    if(mbox_call(MBOX_CH_PROP) && mbox[20]==32 && mbox[28]!=0) {
ffff000040081b18:	52800100 	mov	w0, #0x8                   	// #8
ffff000040081b1c:	97ffff39 	bl	ffff000040081800 <mbox_call>
ffff000040081b20:	7100001f 	cmp	w0, #0x0
ffff000040081b24:	540007e0 	b.eq	ffff000040081c20 <lfb_init+0x37c>  // b.none
ffff000040081b28:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081b2c:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081b30:	b9405000 	ldr	w0, [x0, #80]
ffff000040081b34:	7100801f 	cmp	w0, #0x20
ffff000040081b38:	54000741 	b.ne	ffff000040081c20 <lfb_init+0x37c>  // b.any
ffff000040081b3c:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081b40:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081b44:	b9407000 	ldr	w0, [x0, #112]
ffff000040081b48:	7100001f 	cmp	w0, #0x0
ffff000040081b4c:	540006a0 	b.eq	ffff000040081c20 <lfb_init+0x37c>  // b.none
        mbox[28]&=0x3FFFFFFF;
ffff000040081b50:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081b54:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081b58:	b9407000 	ldr	w0, [x0, #112]
ffff000040081b5c:	12007401 	and	w1, w0, #0x3fffffff
ffff000040081b60:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081b64:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081b68:	b9007001 	str	w1, [x0, #112]
        width=mbox[5];
ffff000040081b6c:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081b70:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081b74:	b9401401 	ldr	w1, [x0, #20]
ffff000040081b78:	90000800 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff000040081b7c:	91170000 	add	x0, x0, #0x5c0
ffff000040081b80:	b9000001 	str	w1, [x0]
        height=mbox[6];
ffff000040081b84:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081b88:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081b8c:	b9401801 	ldr	w1, [x0, #24]
ffff000040081b90:	90000800 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff000040081b94:	91171000 	add	x0, x0, #0x5c4
ffff000040081b98:	b9000001 	str	w1, [x0]
        pitch=mbox[33];
ffff000040081b9c:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081ba0:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081ba4:	b9408401 	ldr	w1, [x0, #132]
ffff000040081ba8:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081bac:	910d6000 	add	x0, x0, #0x358
ffff000040081bb0:	b9000001 	str	w1, [x0]
        vwidth=mbox[10];
ffff000040081bb4:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081bb8:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081bbc:	b9402801 	ldr	w1, [x0, #40]
ffff000040081bc0:	90000800 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff000040081bc4:	91172000 	add	x0, x0, #0x5c8
ffff000040081bc8:	b9000001 	str	w1, [x0]
        vheight=mbox[11];        
ffff000040081bcc:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081bd0:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081bd4:	b9402c01 	ldr	w1, [x0, #44]
ffff000040081bd8:	90000800 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff000040081bdc:	91173000 	add	x0, x0, #0x5cc
ffff000040081be0:	b9000001 	str	w1, [x0]
        isrgb=mbox[24];         //get the actual channel order
ffff000040081be4:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081be8:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081bec:	b9406001 	ldr	w1, [x0, #96]
ffff000040081bf0:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081bf4:	910d7000 	add	x0, x0, #0x35c
ffff000040081bf8:	b9000001 	str	w1, [x0]
        lfb=(void*)((unsigned long)mbox[28]);
ffff000040081bfc:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081c00:	f9401c00 	ldr	x0, [x0, #56]
ffff000040081c04:	b9407000 	ldr	w0, [x0, #112]
ffff000040081c08:	2a0003e0 	mov	w0, w0
ffff000040081c0c:	aa0003e1 	mov	x1, x0
ffff000040081c10:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081c14:	910d4000 	add	x0, x0, #0x350
ffff000040081c18:	f9000001 	str	x1, [x0]
ffff000040081c1c:	14000005 	b	ffff000040081c30 <lfb_init+0x38c>
    } else {
        printf("Unable to set screen resolution to 1024x768x32\n");
ffff000040081c20:	f00007e0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff000040081c24:	91264000 	add	x0, x0, #0x990
ffff000040081c28:	94000ca5 	bl	ffff000040084ebc <tfp_printf>
    }
}
ffff000040081c2c:	d503201f 	nop
ffff000040081c30:	d503201f 	nop
ffff000040081c34:	a8c17bfd 	ldp	x29, x30, [sp], #16
ffff000040081c38:	d65f03c0 	ret

ffff000040081c3c <lfb_print>:

/**
 * Display a string using fixed size PSF
 */
void lfb_print(int x, int y, char *s)
{
ffff000040081c3c:	d10103ff 	sub	sp, sp, #0x40
ffff000040081c40:	b9000fe0 	str	w0, [sp, #12]
ffff000040081c44:	b9000be1 	str	w1, [sp, #8]
ffff000040081c48:	f90003e2 	str	x2, [sp]
    // get our font
    psf_t *font = (psf_t*)&_binary_font_psf_start;
ffff000040081c4c:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081c50:	f9403800 	ldr	x0, [x0, #112]
ffff000040081c54:	f9000fe0 	str	x0, [sp, #24]
    // draw next character if it's not zero
    while(*s) {
ffff000040081c58:	1400007d 	b	ffff000040081e4c <lfb_print+0x210>
        // get the offset of the glyph. Need to adjust this to support unicode table
        unsigned char *glyph = (unsigned char*)&_binary_font_psf_start +
         font->headersize + (*((unsigned char*)s)<font->numglyph?*s:0)*font->bytesperglyph;
ffff000040081c5c:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040081c60:	b9400800 	ldr	w0, [x0, #8]
ffff000040081c64:	2a0003e1 	mov	w1, w0
ffff000040081c68:	f94003e0 	ldr	x0, [sp]
ffff000040081c6c:	39400000 	ldrb	w0, [x0]
ffff000040081c70:	2a0003e2 	mov	w2, w0
ffff000040081c74:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040081c78:	b9401000 	ldr	w0, [x0, #16]
ffff000040081c7c:	6b00005f 	cmp	w2, w0
ffff000040081c80:	540000a2 	b.cs	ffff000040081c94 <lfb_print+0x58>  // b.hs, b.nlast
ffff000040081c84:	f94003e0 	ldr	x0, [sp]
ffff000040081c88:	39400000 	ldrb	w0, [x0]
ffff000040081c8c:	2a0003e2 	mov	w2, w0
ffff000040081c90:	14000002 	b	ffff000040081c98 <lfb_print+0x5c>
ffff000040081c94:	52800002 	mov	w2, #0x0                   	// #0
ffff000040081c98:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040081c9c:	b9401400 	ldr	w0, [x0, #20]
ffff000040081ca0:	1b007c40 	mul	w0, w2, w0
ffff000040081ca4:	2a0003e0 	mov	w0, w0
ffff000040081ca8:	8b000021 	add	x1, x1, x0
        unsigned char *glyph = (unsigned char*)&_binary_font_psf_start +
ffff000040081cac:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081cb0:	f9403800 	ldr	x0, [x0, #112]
ffff000040081cb4:	8b000020 	add	x0, x1, x0
ffff000040081cb8:	f9001fe0 	str	x0, [sp, #56]
        // calculate the offset on screen
        int offs = (y * pitch) + (x * 4);
ffff000040081cbc:	b9400be1 	ldr	w1, [sp, #8]
ffff000040081cc0:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081cc4:	910d6000 	add	x0, x0, #0x358
ffff000040081cc8:	b9400000 	ldr	w0, [x0]
ffff000040081ccc:	1b007c20 	mul	w0, w1, w0
ffff000040081cd0:	b9400fe1 	ldr	w1, [sp, #12]
ffff000040081cd4:	531e7421 	lsl	w1, w1, #2
ffff000040081cd8:	0b010000 	add	w0, w0, w1
ffff000040081cdc:	b90037e0 	str	w0, [sp, #52]
        // variables
        int i,j, line,mask, bytesperline=(font->width+7)/8;
ffff000040081ce0:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040081ce4:	b9401c00 	ldr	w0, [x0, #28]
ffff000040081ce8:	11001c00 	add	w0, w0, #0x7
ffff000040081cec:	53037c00 	lsr	w0, w0, #3
ffff000040081cf0:	b90017e0 	str	w0, [sp, #20]
        // handle carrige return
        if(*s == '\r') {
ffff000040081cf4:	f94003e0 	ldr	x0, [sp]
ffff000040081cf8:	39400000 	ldrb	w0, [x0]
ffff000040081cfc:	7100341f 	cmp	w0, #0xd
ffff000040081d00:	54000061 	b.ne	ffff000040081d0c <lfb_print+0xd0>  // b.any
            x = 0;
ffff000040081d04:	b9000fff 	str	wzr, [sp, #12]
ffff000040081d08:	1400004e 	b	ffff000040081e40 <lfb_print+0x204>
        } else
        // new line
        if(*s == '\n') {
ffff000040081d0c:	f94003e0 	ldr	x0, [sp]
ffff000040081d10:	39400000 	ldrb	w0, [x0]
ffff000040081d14:	7100281f 	cmp	w0, #0xa
ffff000040081d18:	54000101 	b.ne	ffff000040081d38 <lfb_print+0xfc>  // b.any
            x = 0; y += font->height;
ffff000040081d1c:	b9000fff 	str	wzr, [sp, #12]
ffff000040081d20:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040081d24:	b9401801 	ldr	w1, [x0, #24]
ffff000040081d28:	b9400be0 	ldr	w0, [sp, #8]
ffff000040081d2c:	0b000020 	add	w0, w1, w0
ffff000040081d30:	b9000be0 	str	w0, [sp, #8]
ffff000040081d34:	14000043 	b	ffff000040081e40 <lfb_print+0x204>
        } else {
            // display a character
            for(j=0;j<font->height;j++){
ffff000040081d38:	b9002fff 	str	wzr, [sp, #44]
ffff000040081d3c:	14000036 	b	ffff000040081e14 <lfb_print+0x1d8>
                // display one row
                line=offs;
ffff000040081d40:	b94037e0 	ldr	w0, [sp, #52]
ffff000040081d44:	b9002be0 	str	w0, [sp, #40]
                mask=1<<(font->width-1);
ffff000040081d48:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040081d4c:	b9401c00 	ldr	w0, [x0, #28]
ffff000040081d50:	51000400 	sub	w0, w0, #0x1
ffff000040081d54:	52800021 	mov	w1, #0x1                   	// #1
ffff000040081d58:	1ac02020 	lsl	w0, w1, w0
ffff000040081d5c:	b90027e0 	str	w0, [sp, #36]
                for(i=0;i<font->width;i++){
ffff000040081d60:	b90033ff 	str	wzr, [sp, #48]
ffff000040081d64:	1400001a 	b	ffff000040081dcc <lfb_print+0x190>
                    // if bit set, we use white color, otherwise black
                    *((unsigned int*)(lfb + line))=((int)*glyph) & mask?0xFFFFFF:0;
ffff000040081d68:	f9401fe0 	ldr	x0, [sp, #56]
ffff000040081d6c:	39400000 	ldrb	w0, [x0]
ffff000040081d70:	2a0003e1 	mov	w1, w0
ffff000040081d74:	b94027e0 	ldr	w0, [sp, #36]
ffff000040081d78:	0a000020 	and	w0, w1, w0
ffff000040081d7c:	7100001f 	cmp	w0, #0x0
ffff000040081d80:	54000060 	b.eq	ffff000040081d8c <lfb_print+0x150>  // b.none
ffff000040081d84:	12bfe000 	mov	w0, #0xffffff              	// #16777215
ffff000040081d88:	14000002 	b	ffff000040081d90 <lfb_print+0x154>
ffff000040081d8c:	52800000 	mov	w0, #0x0                   	// #0
ffff000040081d90:	b0000801 	adrp	x1, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081d94:	910d4021 	add	x1, x1, #0x350
ffff000040081d98:	f9400022 	ldr	x2, [x1]
ffff000040081d9c:	b9802be1 	ldrsw	x1, [sp, #40]
ffff000040081da0:	8b010041 	add	x1, x2, x1
ffff000040081da4:	b9000020 	str	w0, [x1]
                    mask>>=1;
ffff000040081da8:	b94027e0 	ldr	w0, [sp, #36]
ffff000040081dac:	13017c00 	asr	w0, w0, #1
ffff000040081db0:	b90027e0 	str	w0, [sp, #36]
                    line+=4;
ffff000040081db4:	b9402be0 	ldr	w0, [sp, #40]
ffff000040081db8:	11001000 	add	w0, w0, #0x4
ffff000040081dbc:	b9002be0 	str	w0, [sp, #40]
                for(i=0;i<font->width;i++){
ffff000040081dc0:	b94033e0 	ldr	w0, [sp, #48]
ffff000040081dc4:	11000400 	add	w0, w0, #0x1
ffff000040081dc8:	b90033e0 	str	w0, [sp, #48]
ffff000040081dcc:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040081dd0:	b9401c01 	ldr	w1, [x0, #28]
ffff000040081dd4:	b94033e0 	ldr	w0, [sp, #48]
ffff000040081dd8:	6b00003f 	cmp	w1, w0
ffff000040081ddc:	54fffc68 	b.hi	ffff000040081d68 <lfb_print+0x12c>  // b.pmore
                }
                // adjust to next line
                glyph+=bytesperline;
ffff000040081de0:	b98017e0 	ldrsw	x0, [sp, #20]
ffff000040081de4:	f9401fe1 	ldr	x1, [sp, #56]
ffff000040081de8:	8b000020 	add	x0, x1, x0
ffff000040081dec:	f9001fe0 	str	x0, [sp, #56]
                offs+=pitch;
ffff000040081df0:	b94037e1 	ldr	w1, [sp, #52]
ffff000040081df4:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081df8:	910d6000 	add	x0, x0, #0x358
ffff000040081dfc:	b9400000 	ldr	w0, [x0]
ffff000040081e00:	0b000020 	add	w0, w1, w0
ffff000040081e04:	b90037e0 	str	w0, [sp, #52]
            for(j=0;j<font->height;j++){
ffff000040081e08:	b9402fe0 	ldr	w0, [sp, #44]
ffff000040081e0c:	11000400 	add	w0, w0, #0x1
ffff000040081e10:	b9002fe0 	str	w0, [sp, #44]
ffff000040081e14:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040081e18:	b9401801 	ldr	w1, [x0, #24]
ffff000040081e1c:	b9402fe0 	ldr	w0, [sp, #44]
ffff000040081e20:	6b00003f 	cmp	w1, w0
ffff000040081e24:	54fff8e8 	b.hi	ffff000040081d40 <lfb_print+0x104>  // b.pmore
            }
            x += (font->width+1);
ffff000040081e28:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040081e2c:	b9401c01 	ldr	w1, [x0, #28]
ffff000040081e30:	b9400fe0 	ldr	w0, [sp, #12]
ffff000040081e34:	0b000020 	add	w0, w1, w0
ffff000040081e38:	11000400 	add	w0, w0, #0x1
ffff000040081e3c:	b9000fe0 	str	w0, [sp, #12]
        }
        // next character
        s++;
ffff000040081e40:	f94003e0 	ldr	x0, [sp]
ffff000040081e44:	91000400 	add	x0, x0, #0x1
ffff000040081e48:	f90003e0 	str	x0, [sp]
    while(*s) {
ffff000040081e4c:	f94003e0 	ldr	x0, [sp]
ffff000040081e50:	39400000 	ldrb	w0, [x0]
ffff000040081e54:	7100001f 	cmp	w0, #0x0
ffff000040081e58:	54fff021 	b.ne	ffff000040081c5c <lfb_print+0x20>  // b.any
    }
}
ffff000040081e5c:	d503201f 	nop
ffff000040081e60:	d503201f 	nop
ffff000040081e64:	910103ff 	add	sp, sp, #0x40
ffff000040081e68:	d65f03c0 	ret

ffff000040081e6c <lfb_print_update>:

// x/y IN|OUT: the postion before/after the screen output
void lfb_print_update(int *x, int *y, char *s)
{
ffff000040081e6c:	d10143ff 	sub	sp, sp, #0x50
ffff000040081e70:	f9000fe0 	str	x0, [sp, #24]
ffff000040081e74:	f9000be1 	str	x1, [sp, #16]
ffff000040081e78:	f90007e2 	str	x2, [sp, #8]
    // get our font
    psf_t *font = (psf_t*)&_binary_font_psf_start;
ffff000040081e7c:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081e80:	f9403800 	ldr	x0, [x0, #112]
ffff000040081e84:	f90017e0 	str	x0, [sp, #40]
    // draw next character if it's not zero
    while(*s) {
ffff000040081e88:	1400008a 	b	ffff0000400820b0 <lfb_print_update+0x244>
        // get the offset of the glyph. Need to adjust this to support unicode table
        unsigned char *glyph = (unsigned char*)&_binary_font_psf_start +
         font->headersize + (*((unsigned char*)s)<font->numglyph?*s:0)*font->bytesperglyph;
ffff000040081e8c:	f94017e0 	ldr	x0, [sp, #40]
ffff000040081e90:	b9400800 	ldr	w0, [x0, #8]
ffff000040081e94:	2a0003e1 	mov	w1, w0
ffff000040081e98:	f94007e0 	ldr	x0, [sp, #8]
ffff000040081e9c:	39400000 	ldrb	w0, [x0]
ffff000040081ea0:	2a0003e2 	mov	w2, w0
ffff000040081ea4:	f94017e0 	ldr	x0, [sp, #40]
ffff000040081ea8:	b9401000 	ldr	w0, [x0, #16]
ffff000040081eac:	6b00005f 	cmp	w2, w0
ffff000040081eb0:	540000a2 	b.cs	ffff000040081ec4 <lfb_print_update+0x58>  // b.hs, b.nlast
ffff000040081eb4:	f94007e0 	ldr	x0, [sp, #8]
ffff000040081eb8:	39400000 	ldrb	w0, [x0]
ffff000040081ebc:	2a0003e2 	mov	w2, w0
ffff000040081ec0:	14000002 	b	ffff000040081ec8 <lfb_print_update+0x5c>
ffff000040081ec4:	52800002 	mov	w2, #0x0                   	// #0
ffff000040081ec8:	f94017e0 	ldr	x0, [sp, #40]
ffff000040081ecc:	b9401400 	ldr	w0, [x0, #20]
ffff000040081ed0:	1b007c40 	mul	w0, w2, w0
ffff000040081ed4:	2a0003e0 	mov	w0, w0
ffff000040081ed8:	8b000021 	add	x1, x1, x0
        unsigned char *glyph = (unsigned char*)&_binary_font_psf_start +
ffff000040081edc:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081ee0:	f9403800 	ldr	x0, [x0, #112]
ffff000040081ee4:	8b000020 	add	x0, x1, x0
ffff000040081ee8:	f90027e0 	str	x0, [sp, #72]
        // calculate the offset on screen
        int offs = (*y * pitch) + (*x * 4);
ffff000040081eec:	f9400be0 	ldr	x0, [sp, #16]
ffff000040081ef0:	b9400000 	ldr	w0, [x0]
ffff000040081ef4:	2a0003e1 	mov	w1, w0
ffff000040081ef8:	b0000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081efc:	910d6000 	add	x0, x0, #0x358
ffff000040081f00:	b9400000 	ldr	w0, [x0]
ffff000040081f04:	1b007c20 	mul	w0, w1, w0
ffff000040081f08:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040081f0c:	b9400021 	ldr	w1, [x1]
ffff000040081f10:	531e7421 	lsl	w1, w1, #2
ffff000040081f14:	0b010000 	add	w0, w0, w1
ffff000040081f18:	b90047e0 	str	w0, [sp, #68]
        // variables
        int i,j, line,mask, bytesperline=(font->width+7)/8;
ffff000040081f1c:	f94017e0 	ldr	x0, [sp, #40]
ffff000040081f20:	b9401c00 	ldr	w0, [x0, #28]
ffff000040081f24:	11001c00 	add	w0, w0, #0x7
ffff000040081f28:	53037c00 	lsr	w0, w0, #3
ffff000040081f2c:	b90027e0 	str	w0, [sp, #36]
        // handle carrige return
        if(*s == '\r') {
ffff000040081f30:	f94007e0 	ldr	x0, [sp, #8]
ffff000040081f34:	39400000 	ldrb	w0, [x0]
ffff000040081f38:	7100341f 	cmp	w0, #0xd
ffff000040081f3c:	54000081 	b.ne	ffff000040081f4c <lfb_print_update+0xe0>  // b.any
            *x = 0;
ffff000040081f40:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040081f44:	b900001f 	str	wzr, [x0]
ffff000040081f48:	14000057 	b	ffff0000400820a4 <lfb_print_update+0x238>
        } else
        // new line
        if(*s == '\n') {
ffff000040081f4c:	f94007e0 	ldr	x0, [sp, #8]
ffff000040081f50:	39400000 	ldrb	w0, [x0]
ffff000040081f54:	7100281f 	cmp	w0, #0xa
ffff000040081f58:	540001a1 	b.ne	ffff000040081f8c <lfb_print_update+0x120>  // b.any
            *x = 0; *y += font->height;
ffff000040081f5c:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040081f60:	b900001f 	str	wzr, [x0]
ffff000040081f64:	f9400be0 	ldr	x0, [sp, #16]
ffff000040081f68:	b9400000 	ldr	w0, [x0]
ffff000040081f6c:	2a0003e1 	mov	w1, w0
ffff000040081f70:	f94017e0 	ldr	x0, [sp, #40]
ffff000040081f74:	b9401800 	ldr	w0, [x0, #24]
ffff000040081f78:	0b000020 	add	w0, w1, w0
ffff000040081f7c:	2a0003e1 	mov	w1, w0
ffff000040081f80:	f9400be0 	ldr	x0, [sp, #16]
ffff000040081f84:	b9000001 	str	w1, [x0]
ffff000040081f88:	14000047 	b	ffff0000400820a4 <lfb_print_update+0x238>
        } else {
            // display a character
            for(j=0;j<font->height;j++){
ffff000040081f8c:	b9003fff 	str	wzr, [sp, #60]
ffff000040081f90:	14000036 	b	ffff000040082068 <lfb_print_update+0x1fc>
                // display one row
                line=offs;
ffff000040081f94:	b94047e0 	ldr	w0, [sp, #68]
ffff000040081f98:	b9003be0 	str	w0, [sp, #56]
                mask=1<<(font->width-1);
ffff000040081f9c:	f94017e0 	ldr	x0, [sp, #40]
ffff000040081fa0:	b9401c00 	ldr	w0, [x0, #28]
ffff000040081fa4:	51000400 	sub	w0, w0, #0x1
ffff000040081fa8:	52800021 	mov	w1, #0x1                   	// #1
ffff000040081fac:	1ac02020 	lsl	w0, w1, w0
ffff000040081fb0:	b90037e0 	str	w0, [sp, #52]
                for(i=0;i<font->width;i++){
ffff000040081fb4:	b90043ff 	str	wzr, [sp, #64]
ffff000040081fb8:	1400001a 	b	ffff000040082020 <lfb_print_update+0x1b4>
                    // if bit set, we use white color, otherwise black
                    *((unsigned int*)(lfb + line))=((int)*glyph) & mask?0xFFFFFF:0;
ffff000040081fbc:	f94027e0 	ldr	x0, [sp, #72]
ffff000040081fc0:	39400000 	ldrb	w0, [x0]
ffff000040081fc4:	2a0003e1 	mov	w1, w0
ffff000040081fc8:	b94037e0 	ldr	w0, [sp, #52]
ffff000040081fcc:	0a000020 	and	w0, w1, w0
ffff000040081fd0:	7100001f 	cmp	w0, #0x0
ffff000040081fd4:	54000060 	b.eq	ffff000040081fe0 <lfb_print_update+0x174>  // b.none
ffff000040081fd8:	12bfe000 	mov	w0, #0xffffff              	// #16777215
ffff000040081fdc:	14000002 	b	ffff000040081fe4 <lfb_print_update+0x178>
ffff000040081fe0:	52800000 	mov	w0, #0x0                   	// #0
ffff000040081fe4:	b0000801 	adrp	x1, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040081fe8:	910d4021 	add	x1, x1, #0x350
ffff000040081fec:	f9400022 	ldr	x2, [x1]
ffff000040081ff0:	b9803be1 	ldrsw	x1, [sp, #56]
ffff000040081ff4:	8b010041 	add	x1, x2, x1
ffff000040081ff8:	b9000020 	str	w0, [x1]
                    mask>>=1;
ffff000040081ffc:	b94037e0 	ldr	w0, [sp, #52]
ffff000040082000:	13017c00 	asr	w0, w0, #1
ffff000040082004:	b90037e0 	str	w0, [sp, #52]
                    line+=4;
ffff000040082008:	b9403be0 	ldr	w0, [sp, #56]
ffff00004008200c:	11001000 	add	w0, w0, #0x4
ffff000040082010:	b9003be0 	str	w0, [sp, #56]
                for(i=0;i<font->width;i++){
ffff000040082014:	b94043e0 	ldr	w0, [sp, #64]
ffff000040082018:	11000400 	add	w0, w0, #0x1
ffff00004008201c:	b90043e0 	str	w0, [sp, #64]
ffff000040082020:	f94017e0 	ldr	x0, [sp, #40]
ffff000040082024:	b9401c01 	ldr	w1, [x0, #28]
ffff000040082028:	b94043e0 	ldr	w0, [sp, #64]
ffff00004008202c:	6b00003f 	cmp	w1, w0
ffff000040082030:	54fffc68 	b.hi	ffff000040081fbc <lfb_print_update+0x150>  // b.pmore
                }
                // adjust to next line
                glyph+=bytesperline;
ffff000040082034:	b98027e0 	ldrsw	x0, [sp, #36]
ffff000040082038:	f94027e1 	ldr	x1, [sp, #72]
ffff00004008203c:	8b000020 	add	x0, x1, x0
ffff000040082040:	f90027e0 	str	x0, [sp, #72]
                offs+=pitch;
ffff000040082044:	b94047e1 	ldr	w1, [sp, #68]
ffff000040082048:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff00004008204c:	910d6000 	add	x0, x0, #0x358
ffff000040082050:	b9400000 	ldr	w0, [x0]
ffff000040082054:	0b000020 	add	w0, w1, w0
ffff000040082058:	b90047e0 	str	w0, [sp, #68]
            for(j=0;j<font->height;j++){
ffff00004008205c:	b9403fe0 	ldr	w0, [sp, #60]
ffff000040082060:	11000400 	add	w0, w0, #0x1
ffff000040082064:	b9003fe0 	str	w0, [sp, #60]
ffff000040082068:	f94017e0 	ldr	x0, [sp, #40]
ffff00004008206c:	b9401801 	ldr	w1, [x0, #24]
ffff000040082070:	b9403fe0 	ldr	w0, [sp, #60]
ffff000040082074:	6b00003f 	cmp	w1, w0
ffff000040082078:	54fff8e8 	b.hi	ffff000040081f94 <lfb_print_update+0x128>  // b.pmore
            }
            *x += (font->width+1);
ffff00004008207c:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040082080:	b9400000 	ldr	w0, [x0]
ffff000040082084:	2a0003e1 	mov	w1, w0
ffff000040082088:	f94017e0 	ldr	x0, [sp, #40]
ffff00004008208c:	b9401c00 	ldr	w0, [x0, #28]
ffff000040082090:	0b000020 	add	w0, w1, w0
ffff000040082094:	11000400 	add	w0, w0, #0x1
ffff000040082098:	2a0003e1 	mov	w1, w0
ffff00004008209c:	f9400fe0 	ldr	x0, [sp, #24]
ffff0000400820a0:	b9000001 	str	w1, [x0]
        }
        // next character
        s++;
ffff0000400820a4:	f94007e0 	ldr	x0, [sp, #8]
ffff0000400820a8:	91000400 	add	x0, x0, #0x1
ffff0000400820ac:	f90007e0 	str	x0, [sp, #8]
    while(*s) {
ffff0000400820b0:	f94007e0 	ldr	x0, [sp, #8]
ffff0000400820b4:	39400000 	ldrb	w0, [x0]
ffff0000400820b8:	7100001f 	cmp	w0, #0x0
ffff0000400820bc:	54ffee81 	b.ne	ffff000040081e8c <lfb_print_update+0x20>  // b.any
    }
}
ffff0000400820c0:	d503201f 	nop
ffff0000400820c4:	d503201f 	nop
ffff0000400820c8:	910143ff 	add	sp, sp, #0x50
ffff0000400820cc:	d65f03c0 	ret

ffff0000400820d0 <lfb_showpicture>:
#define IMG_DATA img_data      
#define IMG_HEIGHT img_height
#define IMG_WIDTH img_width

void lfb_showpicture()
{
ffff0000400820d0:	d100c3ff 	sub	sp, sp, #0x30
    int x,y;
    unsigned char *ptr=lfb;
ffff0000400820d4:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400820d8:	910d4000 	add	x0, x0, #0x350
ffff0000400820dc:	f9400000 	ldr	x0, [x0]
ffff0000400820e0:	f90013e0 	str	x0, [sp, #32]
    char *data=IMG_DATA, pixel[4];
ffff0000400820e4:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400820e8:	91028000 	add	x0, x0, #0xa0
ffff0000400820ec:	f9400000 	ldr	x0, [x0]
ffff0000400820f0:	f9000fe0 	str	x0, [sp, #24]
    // fill framebuf. crop img data per the framebuf size
    unsigned int img_fb_height = vheight < IMG_HEIGHT ? vheight : IMG_HEIGHT; 
ffff0000400820f4:	f00007e0 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff0000400820f8:	9116f000 	add	x0, x0, #0x5bc
ffff0000400820fc:	b9400001 	ldr	w1, [x0]
ffff000040082100:	f00007e0 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff000040082104:	91173000 	add	x0, x0, #0x5cc
ffff000040082108:	b9400000 	ldr	w0, [x0]
ffff00004008210c:	6b00003f 	cmp	w1, w0
ffff000040082110:	1a809020 	csel	w0, w1, w0, ls  // ls = plast
ffff000040082114:	b90017e0 	str	w0, [sp, #20]
    unsigned int img_fb_width = vwidth < IMG_WIDTH ? vwidth : IMG_WIDTH; 
ffff000040082118:	f00007e0 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff00004008211c:	9116e000 	add	x0, x0, #0x5b8
ffff000040082120:	b9400001 	ldr	w1, [x0]
ffff000040082124:	f00007e0 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff000040082128:	91172000 	add	x0, x0, #0x5c8
ffff00004008212c:	b9400000 	ldr	w0, [x0]
ffff000040082130:	6b00003f 	cmp	w1, w0
ffff000040082134:	1a809020 	csel	w0, w1, w0, ls  // ls = plast
ffff000040082138:	b90013e0 	str	w0, [sp, #16]

    // xzl: copy the image pixels to the start (top) of framebuf    
    //ptr += (vheight-img_fb_height)/2*pitch + (vwidth-img_fb_width)*2;  
    ptr += (vwidth-img_fb_width)*2;  
ffff00004008213c:	f00007e0 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff000040082140:	91172000 	add	x0, x0, #0x5c8
ffff000040082144:	b9400001 	ldr	w1, [x0]
ffff000040082148:	b94013e0 	ldr	w0, [sp, #16]
ffff00004008214c:	4b000020 	sub	w0, w1, w0
ffff000040082150:	531f7800 	lsl	w0, w0, #1
ffff000040082154:	2a0003e0 	mov	w0, w0
ffff000040082158:	f94013e1 	ldr	x1, [sp, #32]
ffff00004008215c:	8b000020 	add	x0, x1, x0
ffff000040082160:	f90013e0 	str	x0, [sp, #32]
    
    for(y=0;y<img_fb_height;y++) {
ffff000040082164:	b9002bff 	str	wzr, [sp, #40]
ffff000040082168:	1400005d 	b	ffff0000400822dc <lfb_showpicture+0x20c>
        for(x=0;x<img_fb_width;x++) {
ffff00004008216c:	b9002fff 	str	wzr, [sp, #44]
ffff000040082170:	1400004a 	b	ffff000040082298 <lfb_showpicture+0x1c8>
            HEADER_PIXEL(data, pixel);
ffff000040082174:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040082178:	39400000 	ldrb	w0, [x0]
ffff00004008217c:	51008400 	sub	w0, w0, #0x21
ffff000040082180:	531e7400 	lsl	w0, w0, #2
ffff000040082184:	13001c01 	sxtb	w1, w0
ffff000040082188:	f9400fe0 	ldr	x0, [sp, #24]
ffff00004008218c:	91000400 	add	x0, x0, #0x1
ffff000040082190:	39400000 	ldrb	w0, [x0]
ffff000040082194:	51008400 	sub	w0, w0, #0x21
ffff000040082198:	13047c00 	asr	w0, w0, #4
ffff00004008219c:	13001c00 	sxtb	w0, w0
ffff0000400821a0:	2a000020 	orr	w0, w1, w0
ffff0000400821a4:	13001c00 	sxtb	w0, w0
ffff0000400821a8:	12001c00 	and	w0, w0, #0xff
ffff0000400821ac:	390023e0 	strb	w0, [sp, #8]
ffff0000400821b0:	f9400fe0 	ldr	x0, [sp, #24]
ffff0000400821b4:	91000400 	add	x0, x0, #0x1
ffff0000400821b8:	39400000 	ldrb	w0, [x0]
ffff0000400821bc:	51008400 	sub	w0, w0, #0x21
ffff0000400821c0:	531c6c00 	lsl	w0, w0, #4
ffff0000400821c4:	13001c01 	sxtb	w1, w0
ffff0000400821c8:	f9400fe0 	ldr	x0, [sp, #24]
ffff0000400821cc:	91000800 	add	x0, x0, #0x2
ffff0000400821d0:	39400000 	ldrb	w0, [x0]
ffff0000400821d4:	51008400 	sub	w0, w0, #0x21
ffff0000400821d8:	13027c00 	asr	w0, w0, #2
ffff0000400821dc:	13001c00 	sxtb	w0, w0
ffff0000400821e0:	2a000020 	orr	w0, w1, w0
ffff0000400821e4:	13001c00 	sxtb	w0, w0
ffff0000400821e8:	12001c00 	and	w0, w0, #0xff
ffff0000400821ec:	390027e0 	strb	w0, [sp, #9]
ffff0000400821f0:	f9400fe0 	ldr	x0, [sp, #24]
ffff0000400821f4:	91000800 	add	x0, x0, #0x2
ffff0000400821f8:	39400000 	ldrb	w0, [x0]
ffff0000400821fc:	51008400 	sub	w0, w0, #0x21
ffff000040082200:	531a6400 	lsl	w0, w0, #6
ffff000040082204:	13001c01 	sxtb	w1, w0
ffff000040082208:	f9400fe0 	ldr	x0, [sp, #24]
ffff00004008220c:	91000c00 	add	x0, x0, #0x3
ffff000040082210:	39400000 	ldrb	w0, [x0]
ffff000040082214:	51008400 	sub	w0, w0, #0x21
ffff000040082218:	12001c00 	and	w0, w0, #0xff
ffff00004008221c:	13001c00 	sxtb	w0, w0
ffff000040082220:	2a000020 	orr	w0, w1, w0
ffff000040082224:	13001c00 	sxtb	w0, w0
ffff000040082228:	12001c00 	and	w0, w0, #0xff
ffff00004008222c:	39002be0 	strb	w0, [sp, #10]
ffff000040082230:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040082234:	91001000 	add	x0, x0, #0x4
ffff000040082238:	f9000fe0 	str	x0, [sp, #24]
            // the image is in RGB. So if we have an RGB framebuffer, we can copy the pixels
            // directly, but for BGR we must swap R (pixel[0]) and B (pixel[2]) channels.
            *((unsigned int*)ptr)=isrgb ? *((unsigned int *)&pixel) : (unsigned int)(pixel[0]<<16 | pixel[1]<<8 | pixel[2]);
ffff00004008223c:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082240:	910d7000 	add	x0, x0, #0x35c
ffff000040082244:	b9400000 	ldr	w0, [x0]
ffff000040082248:	7100001f 	cmp	w0, #0x0
ffff00004008224c:	54000080 	b.eq	ffff00004008225c <lfb_showpicture+0x18c>  // b.none
ffff000040082250:	910023e0 	add	x0, sp, #0x8
ffff000040082254:	b9400000 	ldr	w0, [x0]
ffff000040082258:	14000008 	b	ffff000040082278 <lfb_showpicture+0x1a8>
ffff00004008225c:	394023e0 	ldrb	w0, [sp, #8]
ffff000040082260:	53103c01 	lsl	w1, w0, #16
ffff000040082264:	394027e0 	ldrb	w0, [sp, #9]
ffff000040082268:	53185c00 	lsl	w0, w0, #8
ffff00004008226c:	2a000020 	orr	w0, w1, w0
ffff000040082270:	39402be1 	ldrb	w1, [sp, #10]
ffff000040082274:	2a010000 	orr	w0, w0, w1
ffff000040082278:	f94013e1 	ldr	x1, [sp, #32]
ffff00004008227c:	b9000020 	str	w0, [x1]
            ptr+=4;
ffff000040082280:	f94013e0 	ldr	x0, [sp, #32]
ffff000040082284:	91001000 	add	x0, x0, #0x4
ffff000040082288:	f90013e0 	str	x0, [sp, #32]
        for(x=0;x<img_fb_width;x++) {
ffff00004008228c:	b9402fe0 	ldr	w0, [sp, #44]
ffff000040082290:	11000400 	add	w0, w0, #0x1
ffff000040082294:	b9002fe0 	str	w0, [sp, #44]
ffff000040082298:	b9402fe0 	ldr	w0, [sp, #44]
ffff00004008229c:	b94013e1 	ldr	w1, [sp, #16]
ffff0000400822a0:	6b00003f 	cmp	w1, w0
ffff0000400822a4:	54fff688 	b.hi	ffff000040082174 <lfb_showpicture+0xa4>  // b.pmore
        }
        ptr+=pitch-img_fb_width*4;
ffff0000400822a8:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400822ac:	910d6000 	add	x0, x0, #0x358
ffff0000400822b0:	b9400001 	ldr	w1, [x0]
ffff0000400822b4:	b94013e0 	ldr	w0, [sp, #16]
ffff0000400822b8:	531e7400 	lsl	w0, w0, #2
ffff0000400822bc:	4b000020 	sub	w0, w1, w0
ffff0000400822c0:	2a0003e0 	mov	w0, w0
ffff0000400822c4:	f94013e1 	ldr	x1, [sp, #32]
ffff0000400822c8:	8b000020 	add	x0, x1, x0
ffff0000400822cc:	f90013e0 	str	x0, [sp, #32]
    for(y=0;y<img_fb_height;y++) {
ffff0000400822d0:	b9402be0 	ldr	w0, [sp, #40]
ffff0000400822d4:	11000400 	add	w0, w0, #0x1
ffff0000400822d8:	b9002be0 	str	w0, [sp, #40]
ffff0000400822dc:	b9402be0 	ldr	w0, [sp, #40]
ffff0000400822e0:	b94017e1 	ldr	w1, [sp, #20]
ffff0000400822e4:	6b00003f 	cmp	w1, w0
ffff0000400822e8:	54fff428 	b.hi	ffff00004008216c <lfb_showpicture+0x9c>  // b.pmore
    }
ffff0000400822ec:	d503201f 	nop
ffff0000400822f0:	d503201f 	nop
ffff0000400822f4:	9100c3ff 	add	sp, sp, #0x30
ffff0000400822f8:	d65f03c0 	ret

ffff0000400822fc <sys_write>:
#include "utils.h"
#include "sched.h"

void sys_write(char * buf){
ffff0000400822fc:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
ffff000040082300:	910003fd 	mov	x29, sp
ffff000040082304:	f9000fe0 	str	x0, [sp, #24]
	printf(buf);
ffff000040082308:	f9400fe0 	ldr	x0, [sp, #24]
ffff00004008230c:	94000aec 	bl	ffff000040084ebc <tfp_printf>
}
ffff000040082310:	d503201f 	nop
ffff000040082314:	a8c27bfd 	ldp	x29, x30, [sp], #32
ffff000040082318:	d65f03c0 	ret

ffff00004008231c <sys_fork>:

int sys_fork(){
ffff00004008231c:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
ffff000040082320:	910003fd 	mov	x29, sp
	return copy_process(0 /*clone_flags*/, 0 /*fn*/, 0 /*arg*/);
ffff000040082324:	d2800002 	mov	x2, #0x0                   	// #0
ffff000040082328:	d2800001 	mov	x1, #0x0                   	// #0
ffff00004008232c:	d2800000 	mov	x0, #0x0                   	// #0
ffff000040082330:	94000864 	bl	ffff0000400844c0 <copy_process>
}
ffff000040082334:	a8c17bfd 	ldp	x29, x30, [sp], #16
ffff000040082338:	d65f03c0 	ret

ffff00004008233c <sys_exit>:

void sys_exit(){
ffff00004008233c:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
ffff000040082340:	910003fd 	mov	x29, sp
	exit_process();
ffff000040082344:	94000261 	bl	ffff000040082cc8 <exit_process>
}
ffff000040082348:	d503201f 	nop
ffff00004008234c:	a8c17bfd 	ldp	x29, x30, [sp], #16
ffff000040082350:	d65f03c0 	ret

ffff000040082354 <enable_interrupt_controller>:
    "ERROR_INVALID_EL0_32"	
};

// Enables Core 0 Timers interrupt control for the generic timer 
void enable_interrupt_controller()
{
ffff000040082354:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
ffff000040082358:	910003fd 	mov	x29, sp
    // (search for "Core timers interrupts"). Note the manual is NOT for the BCM2837 SoC used by Rpi3    
    put32(TIMER_INT_CTRL_0, TIMER_INT_CTRL_0_VALUE);
#endif

#ifdef PLAT_VIRT
    arm_gic_dist_init(0 /* core */, QEMU_GIC_DIST_BASE, 0 /*irq start*/);
ffff00004008235c:	52800002 	mov	w2, #0x0                   	// #0
ffff000040082360:	d2a10001 	mov	x1, #0x8000000             	// #134217728
ffff000040082364:	d2800000 	mov	x0, #0x0                   	// #0
ffff000040082368:	9400069a 	bl	ffff000040083dd0 <arm_gic_dist_init>
    arm_gic_cpu_init(0 /* core*/, QEMU_GIC_CPU_BASE);
ffff00004008236c:	d2a10021 	mov	x1, #0x8010000             	// #134283264
ffff000040082370:	d2800000 	mov	x0, #0x0                   	// #0
ffff000040082374:	94000748 	bl	ffff000040084094 <arm_gic_cpu_init>
    arm_gic_umask(0 /* core */, IRQ_ARM_GENERIC_TIMER);
ffff000040082378:	528003c1 	mov	w1, #0x1e                  	// #30
ffff00004008237c:	d2800000 	mov	x0, #0x0                   	// #0
ffff000040082380:	940002ef 	bl	ffff000040082f3c <arm_gic_umask>
    // gic_dump(); // debugging 
#endif
}
ffff000040082384:	d503201f 	nop
ffff000040082388:	a8c17bfd 	ldp	x29, x30, [sp], #16
ffff00004008238c:	d65f03c0 	ret

ffff000040082390 <show_invalid_entry_message>:

void show_invalid_entry_message(int type, unsigned long esr, unsigned long address)
{
ffff000040082390:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
ffff000040082394:	910003fd 	mov	x29, sp
ffff000040082398:	b9002fe0 	str	w0, [sp, #44]
ffff00004008239c:	f90013e1 	str	x1, [sp, #32]
ffff0000400823a0:	f9000fe2 	str	x2, [sp, #24]
    printf("%s, ESR: %x, address: %x\r\n", entry_error_messages[type], esr, address);
ffff0000400823a4:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400823a8:	9102a000 	add	x0, x0, #0xa8
ffff0000400823ac:	b9802fe1 	ldrsw	x1, [sp, #44]
ffff0000400823b0:	f8617800 	ldr	x0, [x0, x1, lsl #3]
ffff0000400823b4:	f9400fe3 	ldr	x3, [sp, #24]
ffff0000400823b8:	f94013e2 	ldr	x2, [sp, #32]
ffff0000400823bc:	aa0003e1 	mov	x1, x0
ffff0000400823c0:	d00007e0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff0000400823c4:	912d0000 	add	x0, x0, #0xb40
ffff0000400823c8:	94000abd 	bl	ffff000040084ebc <tfp_printf>
}
ffff0000400823cc:	d503201f 	nop
ffff0000400823d0:	a8c37bfd 	ldp	x29, x30, [sp], #48
ffff0000400823d4:	d65f03c0 	ret

ffff0000400823d8 <handle_irq>:

// called from hw irq handler (el1_irq, entry.S)
void handle_irq(void)
{
ffff0000400823d8:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
ffff0000400823dc:	910003fd 	mov	x29, sp
    uint64_t cpu = 0; 
ffff0000400823e0:	f9000fff 	str	xzr, [sp, #24]
    
    int irq = arm_gic_get_active_irq(cpu);
ffff0000400823e4:	f9400fe0 	ldr	x0, [sp, #24]
ffff0000400823e8:	94000258 	bl	ffff000040082d48 <arm_gic_get_active_irq>
ffff0000400823ec:	b90017e0 	str	w0, [sp, #20]
    arm_gic_ack(cpu, irq);
ffff0000400823f0:	b94017e1 	ldr	w1, [sp, #20]
ffff0000400823f4:	f9400fe0 	ldr	x0, [sp, #24]
ffff0000400823f8:	94000272 	bl	ffff000040082dc0 <arm_gic_ack>

    switch (irq) {
ffff0000400823fc:	b94017e0 	ldr	w0, [sp, #20]
ffff000040082400:	7100781f 	cmp	w0, #0x1e
ffff000040082404:	54000061 	b.ne	ffff000040082410 <handle_irq+0x38>  // b.any
        case (IRQ_ARM_GENERIC_TIMER):
            handle_generic_timer_irq();
ffff000040082408:	94000824 	bl	ffff000040084498 <handle_generic_timer_irq>
            break;
ffff00004008240c:	14000006 	b	ffff000040082424 <handle_irq+0x4c>
        default:
            printf("Unknown irq: %d\r\n", irq);
ffff000040082410:	b94017e1 	ldr	w1, [sp, #20]
ffff000040082414:	d00007e0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff000040082418:	912d8000 	add	x0, x0, #0xb60
ffff00004008241c:	94000aa8 	bl	ffff000040084ebc <tfp_printf>
            break;
        default:
            printf("Unknown pending irq: %x\r\n", irq);
    }
#endif    
ffff000040082420:	d503201f 	nop
ffff000040082424:	d503201f 	nop
ffff000040082428:	a8c27bfd 	ldp	x29, x30, [sp], #32
ffff00004008242c:	d65f03c0 	ret

ffff000040082430 <allocate_kernel_page>:
/* 
	minimalist page allocation 
*/
static unsigned short mem_map [ PAGING_PAGES ] = {0,};

unsigned long allocate_kernel_page() {
ffff000040082430:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
ffff000040082434:	910003fd 	mov	x29, sp
	unsigned long page = get_free_page();
ffff000040082438:	94000020 	bl	ffff0000400824b8 <get_free_page>
ffff00004008243c:	f9000fe0 	str	x0, [sp, #24]
	if (page == 0) {
ffff000040082440:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040082444:	f100001f 	cmp	x0, #0x0
ffff000040082448:	54000061 	b.ne	ffff000040082454 <allocate_kernel_page+0x24>  // b.any
		return 0;
ffff00004008244c:	d2800000 	mov	x0, #0x0                   	// #0
ffff000040082450:	14000004 	b	ffff000040082460 <allocate_kernel_page+0x30>
	}
	return page + VA_START;
ffff000040082454:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040082458:	d2ffffe0 	mov	x0, #0xffff000000000000    	// #-281474976710656
ffff00004008245c:	8b000020 	add	x0, x1, x0
}
ffff000040082460:	a8c27bfd 	ldp	x29, x30, [sp], #32
ffff000040082464:	d65f03c0 	ret

ffff000040082468 <allocate_user_page>:

unsigned long allocate_user_page(struct task_struct *task, unsigned long va) {
ffff000040082468:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
ffff00004008246c:	910003fd 	mov	x29, sp
ffff000040082470:	f9000fe0 	str	x0, [sp, #24]
ffff000040082474:	f9000be1 	str	x1, [sp, #16]
	unsigned long page = get_free_page();
ffff000040082478:	94000010 	bl	ffff0000400824b8 <get_free_page>
ffff00004008247c:	f90017e0 	str	x0, [sp, #40]
	if (page == 0) {
ffff000040082480:	f94017e0 	ldr	x0, [sp, #40]
ffff000040082484:	f100001f 	cmp	x0, #0x0
ffff000040082488:	54000061 	b.ne	ffff000040082494 <allocate_user_page+0x2c>  // b.any
		return 0;
ffff00004008248c:	d2800000 	mov	x0, #0x0                   	// #0
ffff000040082490:	14000008 	b	ffff0000400824b0 <allocate_user_page+0x48>
	}
	map_page(task, va, page);
ffff000040082494:	f94017e2 	ldr	x2, [sp, #40]
ffff000040082498:	f9400be1 	ldr	x1, [sp, #16]
ffff00004008249c:	f9400fe0 	ldr	x0, [sp, #24]
ffff0000400824a0:	94000080 	bl	ffff0000400826a0 <map_page>
	return page + VA_START;
ffff0000400824a4:	f94017e1 	ldr	x1, [sp, #40]
ffff0000400824a8:	d2ffffe0 	mov	x0, #0xffff000000000000    	// #-281474976710656
ffff0000400824ac:	8b000020 	add	x0, x1, x0
}
ffff0000400824b0:	a8c37bfd 	ldp	x29, x30, [sp], #48
ffff0000400824b4:	d65f03c0 	ret

ffff0000400824b8 <get_free_page>:

unsigned long get_free_page()
{
ffff0000400824b8:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
ffff0000400824bc:	910003fd 	mov	x29, sp
	for (int i = 0; i < PAGING_PAGES; i++){
ffff0000400824c0:	b9001fff 	str	wzr, [sp, #28]
ffff0000400824c4:	1400001d 	b	ffff000040082538 <get_free_page+0x80>
		if (mem_map[i] == 0){
ffff0000400824c8:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400824cc:	910da000 	add	x0, x0, #0x368
ffff0000400824d0:	b9801fe1 	ldrsw	x1, [sp, #28]
ffff0000400824d4:	78617800 	ldrh	w0, [x0, x1, lsl #1]
ffff0000400824d8:	7100001f 	cmp	w0, #0x0
ffff0000400824dc:	54000281 	b.ne	ffff00004008252c <get_free_page+0x74>  // b.any
			mem_map[i] = 1;
ffff0000400824e0:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400824e4:	910da000 	add	x0, x0, #0x368
ffff0000400824e8:	b9801fe1 	ldrsw	x1, [sp, #28]
ffff0000400824ec:	52800022 	mov	w2, #0x1                   	// #1
ffff0000400824f0:	78217802 	strh	w2, [x0, x1, lsl #1]
			unsigned long page = LOW_MEMORY + i*PAGE_SIZE;
ffff0000400824f4:	b9401fe1 	ldr	w1, [sp, #28]
ffff0000400824f8:	52808000 	mov	w0, #0x400                 	// #1024
ffff0000400824fc:	72a00080 	movk	w0, #0x4, lsl #16
ffff000040082500:	0b000020 	add	w0, w1, w0
ffff000040082504:	53144c00 	lsl	w0, w0, #12
ffff000040082508:	93407c00 	sxtw	x0, w0
ffff00004008250c:	f9000be0 	str	x0, [sp, #16]
			memzero(page + VA_START, PAGE_SIZE);
ffff000040082510:	f9400be1 	ldr	x1, [sp, #16]
ffff000040082514:	d2ffffe0 	mov	x0, #0xffff000000000000    	// #-281474976710656
ffff000040082518:	8b000020 	add	x0, x1, x0
ffff00004008251c:	d2820001 	mov	x1, #0x1000                	// #4096
ffff000040082520:	94000b7b 	bl	ffff00004008530c <memzero>
			return page;
ffff000040082524:	f9400be0 	ldr	x0, [sp, #16]
ffff000040082528:	14000009 	b	ffff00004008254c <get_free_page+0x94>
	for (int i = 0; i < PAGING_PAGES; i++){
ffff00004008252c:	b9401fe0 	ldr	w0, [sp, #28]
ffff000040082530:	11000400 	add	w0, w0, #0x1
ffff000040082534:	b9001fe0 	str	w0, [sp, #28]
ffff000040082538:	b9401fe1 	ldr	w1, [sp, #28]
ffff00004008253c:	32161fe0 	mov	w0, #0x3fc00               	// #261120
ffff000040082540:	6b00003f 	cmp	w1, w0
ffff000040082544:	54fffc23 	b.cc	ffff0000400824c8 <get_free_page+0x10>  // b.lo, b.ul, b.last
		}
	}
	return 0;
ffff000040082548:	d2800000 	mov	x0, #0x0                   	// #0
}
ffff00004008254c:	a8c27bfd 	ldp	x29, x30, [sp], #32
ffff000040082550:	d65f03c0 	ret

ffff000040082554 <free_page>:

void free_page(unsigned long p){
ffff000040082554:	d10043ff 	sub	sp, sp, #0x10
ffff000040082558:	f90007e0 	str	x0, [sp, #8]
	mem_map[(p - LOW_MEMORY) / PAGE_SIZE] = 0;
ffff00004008255c:	f94007e1 	ldr	x1, [sp, #8]
ffff000040082560:	929fffe0 	mov	x0, #0xffffffffffff0000    	// #-65536
ffff000040082564:	f2b7f800 	movk	x0, #0xbfc0, lsl #16
ffff000040082568:	8b000020 	add	x0, x1, x0
ffff00004008256c:	d34cfc01 	lsr	x1, x0, #12
ffff000040082570:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082574:	910da000 	add	x0, x0, #0x368
ffff000040082578:	7821781f 	strh	wzr, [x0, x1, lsl #1]
}
ffff00004008257c:	d503201f 	nop
ffff000040082580:	910043ff 	add	sp, sp, #0x10
ffff000040082584:	d65f03c0 	ret

ffff000040082588 <map_table_entry>:
	Virtual memory implementation
*/

/* set a pte (at the lowest lv of a pgtable tree), 
   so that @va is mapped to @pa. @pte: the 0-th pte of that pgtable */
void map_table_entry(unsigned long *pte, unsigned long va, unsigned long pa) {
ffff000040082588:	d100c3ff 	sub	sp, sp, #0x30
ffff00004008258c:	f9000fe0 	str	x0, [sp, #24]
ffff000040082590:	f9000be1 	str	x1, [sp, #16]
ffff000040082594:	f90007e2 	str	x2, [sp, #8]
	unsigned long index = va >> PAGE_SHIFT;
ffff000040082598:	f9400be0 	ldr	x0, [sp, #16]
ffff00004008259c:	d34cfc00 	lsr	x0, x0, #12
ffff0000400825a0:	f90017e0 	str	x0, [sp, #40]
	index = index & (PTRS_PER_TABLE - 1);
ffff0000400825a4:	f94017e0 	ldr	x0, [sp, #40]
ffff0000400825a8:	92402000 	and	x0, x0, #0x1ff
ffff0000400825ac:	f90017e0 	str	x0, [sp, #40]
	unsigned long entry = pa | MMU_PTE_FLAGS; 
ffff0000400825b0:	f94007e1 	ldr	x1, [sp, #8]
ffff0000400825b4:	d28088e0 	mov	x0, #0x447                 	// #1095
ffff0000400825b8:	aa000020 	orr	x0, x1, x0
ffff0000400825bc:	f90013e0 	str	x0, [sp, #32]
	pte[index] = entry;
ffff0000400825c0:	f94017e0 	ldr	x0, [sp, #40]
ffff0000400825c4:	d37df000 	lsl	x0, x0, #3
ffff0000400825c8:	f9400fe1 	ldr	x1, [sp, #24]
ffff0000400825cc:	8b000020 	add	x0, x1, x0
ffff0000400825d0:	f94013e1 	ldr	x1, [sp, #32]
ffff0000400825d4:	f9000001 	str	x1, [x0]
}
ffff0000400825d8:	d503201f 	nop
ffff0000400825dc:	9100c3ff 	add	sp, sp, #0x30
ffff0000400825e0:	d65f03c0 	ret

ffff0000400825e4 <map_table>:
   @va: the virt address of the page to be mapped
   @new_table [out]: 1 means a new pgtable is allocated; 0 otherwise

   Return: the phys addr of the next pgtable. 
*/
unsigned long map_table(unsigned long *table, unsigned long shift, unsigned long va, int* new_table) {
ffff0000400825e4:	a9bb7bfd 	stp	x29, x30, [sp, #-80]!
ffff0000400825e8:	910003fd 	mov	x29, sp
ffff0000400825ec:	f90017e0 	str	x0, [sp, #40]
ffff0000400825f0:	f90013e1 	str	x1, [sp, #32]
ffff0000400825f4:	f9000fe2 	str	x2, [sp, #24]
ffff0000400825f8:	f9000be3 	str	x3, [sp, #16]
	unsigned long index = va >> shift;
ffff0000400825fc:	f94013e0 	ldr	x0, [sp, #32]
ffff000040082600:	2a0003e1 	mov	w1, w0
ffff000040082604:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040082608:	9ac12400 	lsr	x0, x0, x1
ffff00004008260c:	f90027e0 	str	x0, [sp, #72]
	index = index & (PTRS_PER_TABLE - 1);
ffff000040082610:	f94027e0 	ldr	x0, [sp, #72]
ffff000040082614:	92402000 	and	x0, x0, #0x1ff
ffff000040082618:	f90027e0 	str	x0, [sp, #72]
	if (!table[index]){ /* next level pgtable absent. alloate a new page & install. */
ffff00004008261c:	f94027e0 	ldr	x0, [sp, #72]
ffff000040082620:	d37df000 	lsl	x0, x0, #3
ffff000040082624:	f94017e1 	ldr	x1, [sp, #40]
ffff000040082628:	8b000020 	add	x0, x1, x0
ffff00004008262c:	f9400000 	ldr	x0, [x0]
ffff000040082630:	f100001f 	cmp	x0, #0x0
ffff000040082634:	54000221 	b.ne	ffff000040082678 <map_table+0x94>  // b.any
		*new_table = 1;
ffff000040082638:	f9400be0 	ldr	x0, [sp, #16]
ffff00004008263c:	52800021 	mov	w1, #0x1                   	// #1
ffff000040082640:	b9000001 	str	w1, [x0]
		unsigned long next_level_table = get_free_page();
ffff000040082644:	97ffff9d 	bl	ffff0000400824b8 <get_free_page>
ffff000040082648:	f90023e0 	str	x0, [sp, #64]
		unsigned long entry = next_level_table | MM_TYPE_PAGE_TABLE;
ffff00004008264c:	f94023e0 	ldr	x0, [sp, #64]
ffff000040082650:	b2400400 	orr	x0, x0, #0x3
ffff000040082654:	f9001fe0 	str	x0, [sp, #56]
		table[index] = entry;
ffff000040082658:	f94027e0 	ldr	x0, [sp, #72]
ffff00004008265c:	d37df000 	lsl	x0, x0, #3
ffff000040082660:	f94017e1 	ldr	x1, [sp, #40]
ffff000040082664:	8b000020 	add	x0, x1, x0
ffff000040082668:	f9401fe1 	ldr	x1, [sp, #56]
ffff00004008266c:	f9000001 	str	x1, [x0]
		return next_level_table;
ffff000040082670:	f94023e0 	ldr	x0, [sp, #64]
ffff000040082674:	14000009 	b	ffff000040082698 <map_table+0xb4>
	} else {
		*new_table = 0;
ffff000040082678:	f9400be0 	ldr	x0, [sp, #16]
ffff00004008267c:	b900001f 	str	wzr, [x0]
	}
	return table[index] & PAGE_MASK;
ffff000040082680:	f94027e0 	ldr	x0, [sp, #72]
ffff000040082684:	d37df000 	lsl	x0, x0, #3
ffff000040082688:	f94017e1 	ldr	x1, [sp, #40]
ffff00004008268c:	8b000020 	add	x0, x1, x0
ffff000040082690:	f9400000 	ldr	x0, [x0]
ffff000040082694:	9274cc00 	and	x0, x0, #0xfffffffffffff000
}
ffff000040082698:	a8c57bfd 	ldp	x29, x30, [sp], #80
ffff00004008269c:	d65f03c0 	ret

ffff0000400826a0 <map_page>:

/* map a page to the given @task at its virtual address @va. 
   @page: the phys addr of the page start. 
   Descend in the task's pgtable tree and alloate any absent pgtables on the way.
   */
void map_page(struct task_struct *task, unsigned long va, unsigned long page){
ffff0000400826a0:	a9b97bfd 	stp	x29, x30, [sp, #-112]!
ffff0000400826a4:	910003fd 	mov	x29, sp
ffff0000400826a8:	f90017e0 	str	x0, [sp, #40]
ffff0000400826ac:	f90013e1 	str	x1, [sp, #32]
ffff0000400826b0:	f9000fe2 	str	x2, [sp, #24]
	unsigned long pgd;
	if (!task->mm.pgd) { /* start from the task's top-level pgtable. allocate if absent */
ffff0000400826b4:	f94017e0 	ldr	x0, [sp, #40]
ffff0000400826b8:	f9404800 	ldr	x0, [x0, #144]
ffff0000400826bc:	f100001f 	cmp	x0, #0x0
ffff0000400826c0:	54000281 	b.ne	ffff000040082710 <map_page+0x70>  // b.any
		task->mm.pgd = get_free_page();
ffff0000400826c4:	97ffff7d 	bl	ffff0000400824b8 <get_free_page>
ffff0000400826c8:	aa0003e1 	mov	x1, x0
ffff0000400826cc:	f94017e0 	ldr	x0, [sp, #40]
ffff0000400826d0:	f9004801 	str	x1, [x0, #144]
		task->mm.kernel_pages[++task->mm.kernel_pages_count] = task->mm.pgd;
ffff0000400826d4:	f94017e0 	ldr	x0, [sp, #40]
ffff0000400826d8:	b941a000 	ldr	w0, [x0, #416]
ffff0000400826dc:	11000401 	add	w1, w0, #0x1
ffff0000400826e0:	f94017e0 	ldr	x0, [sp, #40]
ffff0000400826e4:	b901a001 	str	w1, [x0, #416]
ffff0000400826e8:	f94017e0 	ldr	x0, [sp, #40]
ffff0000400826ec:	b941a003 	ldr	w3, [x0, #416]
ffff0000400826f0:	f94017e0 	ldr	x0, [sp, #40]
ffff0000400826f4:	f9404801 	ldr	x1, [x0, #144]
ffff0000400826f8:	f94017e2 	ldr	x2, [sp, #40]
ffff0000400826fc:	93407c60 	sxtw	x0, w3
ffff000040082700:	9100d000 	add	x0, x0, #0x34
ffff000040082704:	d37df000 	lsl	x0, x0, #3
ffff000040082708:	8b000040 	add	x0, x2, x0
ffff00004008270c:	f9000401 	str	x1, [x0, #8]
	}
	pgd = task->mm.pgd;
ffff000040082710:	f94017e0 	ldr	x0, [sp, #40]
ffff000040082714:	f9404800 	ldr	x0, [x0, #144]
ffff000040082718:	f90037e0 	str	x0, [sp, #104]
	int new_table; 
	/* move to the next level pgtable. allocate one if absent */
	unsigned long pud = map_table((unsigned long *)(pgd + VA_START), PGD_SHIFT, va, &new_table);
ffff00004008271c:	f94037e1 	ldr	x1, [sp, #104]
ffff000040082720:	d2ffffe0 	mov	x0, #0xffff000000000000    	// #-281474976710656
ffff000040082724:	8b000020 	add	x0, x1, x0
ffff000040082728:	aa0003e4 	mov	x4, x0
ffff00004008272c:	910133e0 	add	x0, sp, #0x4c
ffff000040082730:	aa0003e3 	mov	x3, x0
ffff000040082734:	f94013e2 	ldr	x2, [sp, #32]
ffff000040082738:	d28004e1 	mov	x1, #0x27                  	// #39
ffff00004008273c:	aa0403e0 	mov	x0, x4
ffff000040082740:	97ffffa9 	bl	ffff0000400825e4 <map_table>
ffff000040082744:	f90033e0 	str	x0, [sp, #96]
	if (new_table) { /* we've allocated a new kernel page. take it into account for future reclaim */
ffff000040082748:	b9404fe0 	ldr	w0, [sp, #76]
ffff00004008274c:	7100001f 	cmp	w0, #0x0
ffff000040082750:	540001e0 	b.eq	ffff00004008278c <map_page+0xec>  // b.none
		task->mm.kernel_pages[++task->mm.kernel_pages_count] = pud;
ffff000040082754:	f94017e0 	ldr	x0, [sp, #40]
ffff000040082758:	b941a000 	ldr	w0, [x0, #416]
ffff00004008275c:	11000401 	add	w1, w0, #0x1
ffff000040082760:	f94017e0 	ldr	x0, [sp, #40]
ffff000040082764:	b901a001 	str	w1, [x0, #416]
ffff000040082768:	f94017e0 	ldr	x0, [sp, #40]
ffff00004008276c:	b941a000 	ldr	w0, [x0, #416]
ffff000040082770:	f94017e1 	ldr	x1, [sp, #40]
ffff000040082774:	93407c00 	sxtw	x0, w0
ffff000040082778:	9100d000 	add	x0, x0, #0x34
ffff00004008277c:	d37df000 	lsl	x0, x0, #3
ffff000040082780:	8b000020 	add	x0, x1, x0
ffff000040082784:	f94033e1 	ldr	x1, [sp, #96]
ffff000040082788:	f9000401 	str	x1, [x0, #8]
	}
	/* next level ... */
	unsigned long pmd = map_table((unsigned long *)(pud + VA_START) , PUD_SHIFT, va, &new_table);
ffff00004008278c:	f94033e1 	ldr	x1, [sp, #96]
ffff000040082790:	d2ffffe0 	mov	x0, #0xffff000000000000    	// #-281474976710656
ffff000040082794:	8b000020 	add	x0, x1, x0
ffff000040082798:	aa0003e4 	mov	x4, x0
ffff00004008279c:	910133e0 	add	x0, sp, #0x4c
ffff0000400827a0:	aa0003e3 	mov	x3, x0
ffff0000400827a4:	f94013e2 	ldr	x2, [sp, #32]
ffff0000400827a8:	d28003c1 	mov	x1, #0x1e                  	// #30
ffff0000400827ac:	aa0403e0 	mov	x0, x4
ffff0000400827b0:	97ffff8d 	bl	ffff0000400825e4 <map_table>
ffff0000400827b4:	f9002fe0 	str	x0, [sp, #88]
	if (new_table) {
ffff0000400827b8:	b9404fe0 	ldr	w0, [sp, #76]
ffff0000400827bc:	7100001f 	cmp	w0, #0x0
ffff0000400827c0:	540001e0 	b.eq	ffff0000400827fc <map_page+0x15c>  // b.none
		task->mm.kernel_pages[++task->mm.kernel_pages_count] = pmd;
ffff0000400827c4:	f94017e0 	ldr	x0, [sp, #40]
ffff0000400827c8:	b941a000 	ldr	w0, [x0, #416]
ffff0000400827cc:	11000401 	add	w1, w0, #0x1
ffff0000400827d0:	f94017e0 	ldr	x0, [sp, #40]
ffff0000400827d4:	b901a001 	str	w1, [x0, #416]
ffff0000400827d8:	f94017e0 	ldr	x0, [sp, #40]
ffff0000400827dc:	b941a000 	ldr	w0, [x0, #416]
ffff0000400827e0:	f94017e1 	ldr	x1, [sp, #40]
ffff0000400827e4:	93407c00 	sxtw	x0, w0
ffff0000400827e8:	9100d000 	add	x0, x0, #0x34
ffff0000400827ec:	d37df000 	lsl	x0, x0, #3
ffff0000400827f0:	8b000020 	add	x0, x1, x0
ffff0000400827f4:	f9402fe1 	ldr	x1, [sp, #88]
ffff0000400827f8:	f9000401 	str	x1, [x0, #8]
	}
	/* next level ... */
	unsigned long pte = map_table((unsigned long *)(pmd + VA_START), PMD_SHIFT, va, &new_table);
ffff0000400827fc:	f9402fe1 	ldr	x1, [sp, #88]
ffff000040082800:	d2ffffe0 	mov	x0, #0xffff000000000000    	// #-281474976710656
ffff000040082804:	8b000020 	add	x0, x1, x0
ffff000040082808:	aa0003e4 	mov	x4, x0
ffff00004008280c:	910133e0 	add	x0, sp, #0x4c
ffff000040082810:	aa0003e3 	mov	x3, x0
ffff000040082814:	f94013e2 	ldr	x2, [sp, #32]
ffff000040082818:	d28002a1 	mov	x1, #0x15                  	// #21
ffff00004008281c:	aa0403e0 	mov	x0, x4
ffff000040082820:	97ffff71 	bl	ffff0000400825e4 <map_table>
ffff000040082824:	f9002be0 	str	x0, [sp, #80]
	if (new_table) {
ffff000040082828:	b9404fe0 	ldr	w0, [sp, #76]
ffff00004008282c:	7100001f 	cmp	w0, #0x0
ffff000040082830:	540001e0 	b.eq	ffff00004008286c <map_page+0x1cc>  // b.none
		task->mm.kernel_pages[++task->mm.kernel_pages_count] = pte;
ffff000040082834:	f94017e0 	ldr	x0, [sp, #40]
ffff000040082838:	b941a000 	ldr	w0, [x0, #416]
ffff00004008283c:	11000401 	add	w1, w0, #0x1
ffff000040082840:	f94017e0 	ldr	x0, [sp, #40]
ffff000040082844:	b901a001 	str	w1, [x0, #416]
ffff000040082848:	f94017e0 	ldr	x0, [sp, #40]
ffff00004008284c:	b941a000 	ldr	w0, [x0, #416]
ffff000040082850:	f94017e1 	ldr	x1, [sp, #40]
ffff000040082854:	93407c00 	sxtw	x0, w0
ffff000040082858:	9100d000 	add	x0, x0, #0x34
ffff00004008285c:	d37df000 	lsl	x0, x0, #3
ffff000040082860:	8b000020 	add	x0, x1, x0
ffff000040082864:	f9402be1 	ldr	x1, [sp, #80]
ffff000040082868:	f9000401 	str	x1, [x0, #8]
	}
	/* reached the bottom level of pgtable tree */
	map_table_entry((unsigned long *)(pte + VA_START), va, page);
ffff00004008286c:	f9402be1 	ldr	x1, [sp, #80]
ffff000040082870:	d2ffffe0 	mov	x0, #0xffff000000000000    	// #-281474976710656
ffff000040082874:	8b000020 	add	x0, x1, x0
ffff000040082878:	f9400fe2 	ldr	x2, [sp, #24]
ffff00004008287c:	f94013e1 	ldr	x1, [sp, #32]
ffff000040082880:	97ffff42 	bl	ffff000040082588 <map_table_entry>
	struct user_page p = {page, va};
ffff000040082884:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040082888:	f9001fe0 	str	x0, [sp, #56]
ffff00004008288c:	f94013e0 	ldr	x0, [sp, #32]
ffff000040082890:	f90023e0 	str	x0, [sp, #64]
	task->mm.user_pages[task->mm.user_pages_count++] = p;
ffff000040082894:	f94017e0 	ldr	x0, [sp, #40]
ffff000040082898:	b9409800 	ldr	w0, [x0, #152]
ffff00004008289c:	11000402 	add	w2, w0, #0x1
ffff0000400828a0:	f94017e1 	ldr	x1, [sp, #40]
ffff0000400828a4:	b9009822 	str	w2, [x1, #152]
ffff0000400828a8:	f94017e1 	ldr	x1, [sp, #40]
ffff0000400828ac:	93407c00 	sxtw	x0, w0
ffff0000400828b0:	91002800 	add	x0, x0, #0xa
ffff0000400828b4:	d37cec00 	lsl	x0, x0, #4
ffff0000400828b8:	8b000022 	add	x2, x1, x0
ffff0000400828bc:	a94387e0 	ldp	x0, x1, [sp, #56]
ffff0000400828c0:	a9000440 	stp	x0, x1, [x2]
}
ffff0000400828c4:	d503201f 	nop
ffff0000400828c8:	a8c77bfd 	ldp	x29, x30, [sp], #112
ffff0000400828cc:	d65f03c0 	ret

ffff0000400828d0 <copy_virt_memory>:

/* duplicate the contents of the @current task's user pages to the @dst task */
int copy_virt_memory(struct task_struct *dst) {
ffff0000400828d0:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
ffff0000400828d4:	910003fd 	mov	x29, sp
ffff0000400828d8:	f9000fe0 	str	x0, [sp, #24]
	struct task_struct* src = current;
ffff0000400828dc:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400828e0:	f9402000 	ldr	x0, [x0, #64]
ffff0000400828e4:	f9400000 	ldr	x0, [x0]
ffff0000400828e8:	f9001be0 	str	x0, [sp, #48]
	for (int i = 0; i < src->mm.user_pages_count; i++) {
ffff0000400828ec:	b9003fff 	str	wzr, [sp, #60]
ffff0000400828f0:	1400001c 	b	ffff000040082960 <copy_virt_memory+0x90>
		unsigned long kernel_va = allocate_user_page(dst, src->mm.user_pages[i].virt_addr);
ffff0000400828f4:	f9401be1 	ldr	x1, [sp, #48]
ffff0000400828f8:	b9803fe0 	ldrsw	x0, [sp, #60]
ffff0000400828fc:	91002800 	add	x0, x0, #0xa
ffff000040082900:	d37cec00 	lsl	x0, x0, #4
ffff000040082904:	8b000020 	add	x0, x1, x0
ffff000040082908:	f9400400 	ldr	x0, [x0, #8]
ffff00004008290c:	aa0003e1 	mov	x1, x0
ffff000040082910:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040082914:	97fffed5 	bl	ffff000040082468 <allocate_user_page>
ffff000040082918:	f90017e0 	str	x0, [sp, #40]
		if( kernel_va == 0) {
ffff00004008291c:	f94017e0 	ldr	x0, [sp, #40]
ffff000040082920:	f100001f 	cmp	x0, #0x0
ffff000040082924:	54000061 	b.ne	ffff000040082930 <copy_virt_memory+0x60>  // b.any
			return -1;
ffff000040082928:	12800000 	mov	w0, #0xffffffff            	// #-1
ffff00004008292c:	14000013 	b	ffff000040082978 <copy_virt_memory+0xa8>
		}
		memcpy(src->mm.user_pages[i].virt_addr, kernel_va, PAGE_SIZE);
ffff000040082930:	f9401be1 	ldr	x1, [sp, #48]
ffff000040082934:	b9803fe0 	ldrsw	x0, [sp, #60]
ffff000040082938:	91002800 	add	x0, x0, #0xa
ffff00004008293c:	d37cec00 	lsl	x0, x0, #4
ffff000040082940:	8b000020 	add	x0, x1, x0
ffff000040082944:	f9400400 	ldr	x0, [x0, #8]
ffff000040082948:	d2820002 	mov	x2, #0x1000                	// #4096
ffff00004008294c:	f94017e1 	ldr	x1, [sp, #40]
ffff000040082950:	94000a6a 	bl	ffff0000400852f8 <memcpy>
	for (int i = 0; i < src->mm.user_pages_count; i++) {
ffff000040082954:	b9403fe0 	ldr	w0, [sp, #60]
ffff000040082958:	11000400 	add	w0, w0, #0x1
ffff00004008295c:	b9003fe0 	str	w0, [sp, #60]
ffff000040082960:	f9401be0 	ldr	x0, [sp, #48]
ffff000040082964:	b9409800 	ldr	w0, [x0, #152]
ffff000040082968:	b9403fe1 	ldr	w1, [sp, #60]
ffff00004008296c:	6b00003f 	cmp	w1, w0
ffff000040082970:	54fffc2b 	b.lt	ffff0000400828f4 <copy_virt_memory+0x24>  // b.tstop
	}
	return 0;
ffff000040082974:	52800000 	mov	w0, #0x0                   	// #0
}
ffff000040082978:	a8c47bfd 	ldp	x29, x30, [sp], #64
ffff00004008297c:	d65f03c0 	ret

ffff000040082980 <do_mem_abort>:

static int ind = 1;

// called from el0_da, which was from data access exception 
int do_mem_abort(unsigned long addr, unsigned long esr) {
ffff000040082980:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
ffff000040082984:	910003fd 	mov	x29, sp
ffff000040082988:	f9000fe0 	str	x0, [sp, #24]
ffff00004008298c:	f9000be1 	str	x1, [sp, #16]
	unsigned long dfs = (esr & 0b111111);
ffff000040082990:	f9400be0 	ldr	x0, [sp, #16]
ffff000040082994:	92401400 	and	x0, x0, #0x3f
ffff000040082998:	f90017e0 	str	x0, [sp, #40]
	/* whether the current exception is actually a translation fault.. */		
	if ((dfs & 0b111100) == 0b100) {
ffff00004008299c:	f94017e0 	ldr	x0, [sp, #40]
ffff0000400829a0:	927e0c00 	and	x0, x0, #0x3c
ffff0000400829a4:	f100101f 	cmp	x0, #0x4
ffff0000400829a8:	54000421 	b.ne	ffff000040082a2c <do_mem_abort+0xac>  // b.any
		unsigned long page = get_free_page();
ffff0000400829ac:	97fffec3 	bl	ffff0000400824b8 <get_free_page>
ffff0000400829b0:	f90013e0 	str	x0, [sp, #32]
		if (page == 0) {
ffff0000400829b4:	f94013e0 	ldr	x0, [sp, #32]
ffff0000400829b8:	f100001f 	cmp	x0, #0x0
ffff0000400829bc:	54000061 	b.ne	ffff0000400829c8 <do_mem_abort+0x48>  // b.any
			return -1;
ffff0000400829c0:	12800000 	mov	w0, #0xffffffff            	// #-1
ffff0000400829c4:	1400001b 	b	ffff000040082a30 <do_mem_abort+0xb0>
		}
		map_page(current, addr & PAGE_MASK, page);
ffff0000400829c8:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400829cc:	f9402000 	ldr	x0, [x0, #64]
ffff0000400829d0:	f9400003 	ldr	x3, [x0]
ffff0000400829d4:	f9400fe0 	ldr	x0, [sp, #24]
ffff0000400829d8:	9274cc00 	and	x0, x0, #0xfffffffffffff000
ffff0000400829dc:	f94013e2 	ldr	x2, [sp, #32]
ffff0000400829e0:	aa0003e1 	mov	x1, x0
ffff0000400829e4:	aa0303e0 	mov	x0, x3
ffff0000400829e8:	97ffff2e 	bl	ffff0000400826a0 <map_page>
		ind++;
ffff0000400829ec:	f00007e0 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff0000400829f0:	91174000 	add	x0, x0, #0x5d0
ffff0000400829f4:	b9400000 	ldr	w0, [x0]
ffff0000400829f8:	11000401 	add	w1, w0, #0x1
ffff0000400829fc:	f00007e0 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff000040082a00:	91174000 	add	x0, x0, #0x5d0
ffff000040082a04:	b9000001 	str	w1, [x0]
		if (ind > 2){
ffff000040082a08:	f00007e0 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff000040082a0c:	91174000 	add	x0, x0, #0x5d0
ffff000040082a10:	b9400000 	ldr	w0, [x0]
ffff000040082a14:	7100081f 	cmp	w0, #0x2
ffff000040082a18:	5400006d 	b.le	ffff000040082a24 <do_mem_abort+0xa4>
			return -1;
ffff000040082a1c:	12800000 	mov	w0, #0xffffffff            	// #-1
ffff000040082a20:	14000004 	b	ffff000040082a30 <do_mem_abort+0xb0>
		}
		return 0;
ffff000040082a24:	52800000 	mov	w0, #0x0                   	// #0
ffff000040082a28:	14000002 	b	ffff000040082a30 <do_mem_abort+0xb0>
	}
	return -1;
ffff000040082a2c:	12800000 	mov	w0, #0xffffffff            	// #-1
}
ffff000040082a30:	a8c37bfd 	ldp	x29, x30, [sp], #48
ffff000040082a34:	d65f03c0 	ret

ffff000040082a38 <preempt_disable>:
struct task_struct * task[NR_TASKS] = {&(init_task), };
int nr_tasks = 1;

void preempt_disable(void)
{
	current->preempt_count++;
ffff000040082a38:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082a3c:	9104a000 	add	x0, x0, #0x128
ffff000040082a40:	f9400000 	ldr	x0, [x0]
ffff000040082a44:	f9404001 	ldr	x1, [x0, #128]
ffff000040082a48:	91000421 	add	x1, x1, #0x1
ffff000040082a4c:	f9004001 	str	x1, [x0, #128]
}
ffff000040082a50:	d503201f 	nop
ffff000040082a54:	d65f03c0 	ret

ffff000040082a58 <preempt_enable>:

void preempt_enable(void)
{
	current->preempt_count--;
ffff000040082a58:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082a5c:	9104a000 	add	x0, x0, #0x128
ffff000040082a60:	f9400000 	ldr	x0, [x0]
ffff000040082a64:	f9404001 	ldr	x1, [x0, #128]
ffff000040082a68:	d1000421 	sub	x1, x1, #0x1
ffff000040082a6c:	f9004001 	str	x1, [x0, #128]
}
ffff000040082a70:	d503201f 	nop
ffff000040082a74:	d65f03c0 	ret

ffff000040082a78 <_schedule>:


void _schedule(void)
{
ffff000040082a78:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
ffff000040082a7c:	910003fd 	mov	x29, sp
	/* ensure no context happens in the following code region
		we still leave irq on, because irq handler may set a task to be TASK_RUNNING, which 
		will be picked up by the scheduler below */
		
	preempt_disable(); 
ffff000040082a80:	97ffffee 	bl	ffff000040082a38 <preempt_disable>
	int next,c;
	struct task_struct * p;
	while (1) {
		c = -1; // the maximum counter of all tasks 
ffff000040082a84:	12800000 	mov	w0, #0xffffffff            	// #-1
ffff000040082a88:	b9002be0 	str	w0, [sp, #40]
		next = 0;
ffff000040082a8c:	b9002fff 	str	wzr, [sp, #44]
		/* Iterates over all tasks and tries to find a task in 
		TASK_RUNNING state with the maximum counter. If such 
		a task is found, we immediately break from the while loop 
		and switch to this task. */

		for (int i = 0; i < NR_TASKS; i++){
ffff000040082a90:	b90027ff 	str	wzr, [sp, #36]
ffff000040082a94:	1400001a 	b	ffff000040082afc <_schedule+0x84>
			p = task[i];
ffff000040082a98:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082a9c:	9104c000 	add	x0, x0, #0x130
ffff000040082aa0:	b98027e1 	ldrsw	x1, [sp, #36]
ffff000040082aa4:	f8617800 	ldr	x0, [x0, x1, lsl #3]
ffff000040082aa8:	f9000fe0 	str	x0, [sp, #24]
			if (p && p->state == TASK_RUNNING && p->counter > c) {
ffff000040082aac:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040082ab0:	f100001f 	cmp	x0, #0x0
ffff000040082ab4:	540001e0 	b.eq	ffff000040082af0 <_schedule+0x78>  // b.none
ffff000040082ab8:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040082abc:	f9403400 	ldr	x0, [x0, #104]
ffff000040082ac0:	f100001f 	cmp	x0, #0x0
ffff000040082ac4:	54000161 	b.ne	ffff000040082af0 <_schedule+0x78>  // b.any
ffff000040082ac8:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040082acc:	f9403801 	ldr	x1, [x0, #112]
ffff000040082ad0:	b9802be0 	ldrsw	x0, [sp, #40]
ffff000040082ad4:	eb00003f 	cmp	x1, x0
ffff000040082ad8:	540000cd 	b.le	ffff000040082af0 <_schedule+0x78>
				c = p->counter;
ffff000040082adc:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040082ae0:	f9403800 	ldr	x0, [x0, #112]
ffff000040082ae4:	b9002be0 	str	w0, [sp, #40]
				next = i;
ffff000040082ae8:	b94027e0 	ldr	w0, [sp, #36]
ffff000040082aec:	b9002fe0 	str	w0, [sp, #44]
		for (int i = 0; i < NR_TASKS; i++){
ffff000040082af0:	b94027e0 	ldr	w0, [sp, #36]
ffff000040082af4:	11000400 	add	w0, w0, #0x1
ffff000040082af8:	b90027e0 	str	w0, [sp, #36]
ffff000040082afc:	b94027e0 	ldr	w0, [sp, #36]
ffff000040082b00:	7100fc1f 	cmp	w0, #0x3f
ffff000040082b04:	54fffcad 	b.le	ffff000040082a98 <_schedule+0x20>
			}
		}
		if (c) {
ffff000040082b08:	b9402be0 	ldr	w0, [sp, #40]
ffff000040082b0c:	7100001f 	cmp	w0, #0x0
ffff000040082b10:	54000341 	b.ne	ffff000040082b78 <_schedule+0x100>  // b.any
		/* If no such task is found, this is either because i) no 
		task is in TASK_RUNNING state or ii) all such tasks have 0 counters.
		in our current implemenation which misses TASK_WAIT, only condition ii) is possible. 
		Hence, we recharge counters. Bump counters for all tasks once. */
		
		for (int i = 0; i < NR_TASKS; i++) {
ffff000040082b14:	b90023ff 	str	wzr, [sp, #32]
ffff000040082b18:	14000014 	b	ffff000040082b68 <_schedule+0xf0>
			p = task[i];
ffff000040082b1c:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082b20:	9104c000 	add	x0, x0, #0x130
ffff000040082b24:	b98023e1 	ldrsw	x1, [sp, #32]
ffff000040082b28:	f8617800 	ldr	x0, [x0, x1, lsl #3]
ffff000040082b2c:	f9000fe0 	str	x0, [sp, #24]
			if (p) {
ffff000040082b30:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040082b34:	f100001f 	cmp	x0, #0x0
ffff000040082b38:	54000120 	b.eq	ffff000040082b5c <_schedule+0xe4>  // b.none
				p->counter = (p->counter >> 1) + p->priority;
ffff000040082b3c:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040082b40:	f9403800 	ldr	x0, [x0, #112]
ffff000040082b44:	9341fc01 	asr	x1, x0, #1
ffff000040082b48:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040082b4c:	f9403c00 	ldr	x0, [x0, #120]
ffff000040082b50:	8b000021 	add	x1, x1, x0
ffff000040082b54:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040082b58:	f9003801 	str	x1, [x0, #112]
		for (int i = 0; i < NR_TASKS; i++) {
ffff000040082b5c:	b94023e0 	ldr	w0, [sp, #32]
ffff000040082b60:	11000400 	add	w0, w0, #0x1
ffff000040082b64:	b90023e0 	str	w0, [sp, #32]
ffff000040082b68:	b94023e0 	ldr	w0, [sp, #32]
ffff000040082b6c:	7100fc1f 	cmp	w0, #0x3f
ffff000040082b70:	54fffd6d 	b.le	ffff000040082b1c <_schedule+0xa4>
		c = -1; // the maximum counter of all tasks 
ffff000040082b74:	17ffffc4 	b	ffff000040082a84 <_schedule+0xc>
			break;
ffff000040082b78:	d503201f 	nop
			}
		}
	}
	switch_to(task[next]);
ffff000040082b7c:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082b80:	9104c000 	add	x0, x0, #0x130
ffff000040082b84:	b9802fe1 	ldrsw	x1, [sp, #44]
ffff000040082b88:	f8617800 	ldr	x0, [x0, x1, lsl #3]
ffff000040082b8c:	9400000f 	bl	ffff000040082bc8 <switch_to>
	preempt_enable();
ffff000040082b90:	97ffffb2 	bl	ffff000040082a58 <preempt_enable>
}
ffff000040082b94:	d503201f 	nop
ffff000040082b98:	a8c37bfd 	ldp	x29, x30, [sp], #48
ffff000040082b9c:	d65f03c0 	ret

ffff000040082ba0 <schedule>:

void schedule(void)
{
ffff000040082ba0:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
ffff000040082ba4:	910003fd 	mov	x29, sp
	current->counter = 0;
ffff000040082ba8:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082bac:	9104a000 	add	x0, x0, #0x128
ffff000040082bb0:	f9400000 	ldr	x0, [x0]
ffff000040082bb4:	f900381f 	str	xzr, [x0, #112]
	_schedule();
ffff000040082bb8:	97ffffb0 	bl	ffff000040082a78 <_schedule>
}
ffff000040082bbc:	d503201f 	nop
ffff000040082bc0:	a8c17bfd 	ldp	x29, x30, [sp], #16
ffff000040082bc4:	d65f03c0 	ret

ffff000040082bc8 <switch_to>:

void switch_to(struct task_struct * next) 
{
ffff000040082bc8:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
ffff000040082bcc:	910003fd 	mov	x29, sp
ffff000040082bd0:	f9000fe0 	str	x0, [sp, #24]
	if (current == next) 
ffff000040082bd4:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082bd8:	9104a000 	add	x0, x0, #0x128
ffff000040082bdc:	f9400000 	ldr	x0, [x0]
ffff000040082be0:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040082be4:	eb00003f 	cmp	x1, x0
ffff000040082be8:	54000200 	b.eq	ffff000040082c28 <switch_to+0x60>  // b.none
		return;
	struct task_struct * prev = current;
ffff000040082bec:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082bf0:	9104a000 	add	x0, x0, #0x128
ffff000040082bf4:	f9400000 	ldr	x0, [x0]
ffff000040082bf8:	f90017e0 	str	x0, [sp, #40]
	current = next;
ffff000040082bfc:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082c00:	9104a000 	add	x0, x0, #0x128
ffff000040082c04:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040082c08:	f9000001 	str	x1, [x0]
	set_pgd(next->mm.pgd);
ffff000040082c0c:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040082c10:	f9404800 	ldr	x0, [x0, #144]
ffff000040082c14:	940009ae 	bl	ffff0000400852cc <set_pgd>
			80d50:       f9400fe1        ldr     x1, [sp, #24]
			80d54:       f94017e0        ldr     x0, [sp, #40]
			80d58:       9400083b        bl      82e44 <cpu_switch_to>
		==> 80d5c:       14000002        b       80d64 <switch_to+0x58>
	*/
	cpu_switch_to(prev, next);  /* will branch to @next->cpu_context.pc ...*/
ffff000040082c18:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040082c1c:	f94017e0 	ldr	x0, [sp, #40]
ffff000040082c20:	94000f45 	bl	ffff000040086934 <cpu_switch_to>
ffff000040082c24:	14000002 	b	ffff000040082c2c <switch_to+0x64>
		return;
ffff000040082c28:	d503201f 	nop
}
ffff000040082c2c:	a8c37bfd 	ldp	x29, x30, [sp], #48
ffff000040082c30:	d65f03c0 	ret

ffff000040082c34 <schedule_tail>:

void schedule_tail(void) {
ffff000040082c34:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
ffff000040082c38:	910003fd 	mov	x29, sp
	preempt_enable();
ffff000040082c3c:	97ffff87 	bl	ffff000040082a58 <preempt_enable>
}
ffff000040082c40:	d503201f 	nop
ffff000040082c44:	a8c17bfd 	ldp	x29, x30, [sp], #16
ffff000040082c48:	d65f03c0 	ret

ffff000040082c4c <timer_tick>:


void timer_tick()
{
ffff000040082c4c:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
ffff000040082c50:	910003fd 	mov	x29, sp
	--current->counter;
ffff000040082c54:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082c58:	9104a000 	add	x0, x0, #0x128
ffff000040082c5c:	f9400000 	ldr	x0, [x0]
ffff000040082c60:	f9403801 	ldr	x1, [x0, #112]
ffff000040082c64:	d1000421 	sub	x1, x1, #0x1
ffff000040082c68:	f9003801 	str	x1, [x0, #112]
	if (current->counter > 0 || current->preempt_count > 0) 
ffff000040082c6c:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082c70:	9104a000 	add	x0, x0, #0x128
ffff000040082c74:	f9400000 	ldr	x0, [x0]
ffff000040082c78:	f9403800 	ldr	x0, [x0, #112]
ffff000040082c7c:	f100001f 	cmp	x0, #0x0
ffff000040082c80:	540001ec 	b.gt	ffff000040082cbc <timer_tick+0x70>
ffff000040082c84:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082c88:	9104a000 	add	x0, x0, #0x128
ffff000040082c8c:	f9400000 	ldr	x0, [x0]
ffff000040082c90:	f9404000 	ldr	x0, [x0, #128]
ffff000040082c94:	f100001f 	cmp	x0, #0x0
ffff000040082c98:	5400012c 	b.gt	ffff000040082cbc <timer_tick+0x70>
		return;
	current->counter=0;
ffff000040082c9c:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082ca0:	9104a000 	add	x0, x0, #0x128
ffff000040082ca4:	f9400000 	ldr	x0, [x0]
ffff000040082ca8:	f900381f 	str	xzr, [x0, #112]

	/* Note: we just came from an interrupt handler and CPU just automatically disabled all interrupts. 
		Now call scheduler with interrupts enabled */
	enable_irq();
ffff000040082cac:	9400097f 	bl	ffff0000400852a8 <enable_irq>
	_schedule();
ffff000040082cb0:	97ffff72 	bl	ffff000040082a78 <_schedule>
	/* disable irq until kernel_exit, in which eret will resort the interrupt flag from spsr, which sets it on. */
	disable_irq(); 
ffff000040082cb4:	9400097f 	bl	ffff0000400852b0 <disable_irq>
ffff000040082cb8:	14000002 	b	ffff000040082cc0 <timer_tick+0x74>
		return;
ffff000040082cbc:	d503201f 	nop
}
ffff000040082cc0:	a8c17bfd 	ldp	x29, x30, [sp], #16
ffff000040082cc4:	d65f03c0 	ret

ffff000040082cc8 <exit_process>:

void exit_process(){
ffff000040082cc8:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
ffff000040082ccc:	910003fd 	mov	x29, sp
	preempt_disable();
ffff000040082cd0:	97ffff5a 	bl	ffff000040082a38 <preempt_disable>
	for (int i = 0; i < NR_TASKS; i++){
ffff000040082cd4:	b9001fff 	str	wzr, [sp, #28]
ffff000040082cd8:	14000014 	b	ffff000040082d28 <exit_process+0x60>
		if (task[i] == current) {
ffff000040082cdc:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082ce0:	9104c000 	add	x0, x0, #0x130
ffff000040082ce4:	b9801fe1 	ldrsw	x1, [sp, #28]
ffff000040082ce8:	f8617801 	ldr	x1, [x0, x1, lsl #3]
ffff000040082cec:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082cf0:	9104a000 	add	x0, x0, #0x128
ffff000040082cf4:	f9400000 	ldr	x0, [x0]
ffff000040082cf8:	eb00003f 	cmp	x1, x0
ffff000040082cfc:	54000101 	b.ne	ffff000040082d1c <exit_process+0x54>  // b.any
			task[i]->state = TASK_ZOMBIE;
ffff000040082d00:	90000800 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040082d04:	9104c000 	add	x0, x0, #0x130
ffff000040082d08:	b9801fe1 	ldrsw	x1, [sp, #28]
ffff000040082d0c:	f8617800 	ldr	x0, [x0, x1, lsl #3]
ffff000040082d10:	d2800021 	mov	x1, #0x1                   	// #1
ffff000040082d14:	f9003401 	str	x1, [x0, #104]
			break;
ffff000040082d18:	14000007 	b	ffff000040082d34 <exit_process+0x6c>
	for (int i = 0; i < NR_TASKS; i++){
ffff000040082d1c:	b9401fe0 	ldr	w0, [sp, #28]
ffff000040082d20:	11000400 	add	w0, w0, #0x1
ffff000040082d24:	b9001fe0 	str	w0, [sp, #28]
ffff000040082d28:	b9401fe0 	ldr	w0, [sp, #28]
ffff000040082d2c:	7100fc1f 	cmp	w0, #0x3f
ffff000040082d30:	54fffd6d 	b.le	ffff000040082cdc <exit_process+0x14>
		}
	}	
	/* no need to free stack page...*/
	preempt_enable();
ffff000040082d34:	97ffff49 	bl	ffff000040082a58 <preempt_enable>
	schedule();
ffff000040082d38:	97ffff9a 	bl	ffff000040082ba0 <schedule>
}
ffff000040082d3c:	d503201f 	nop
ffff000040082d40:	a8c27bfd 	ldp	x29, x30, [sp], #32
ffff000040082d44:	d65f03c0 	ret

ffff000040082d48 <arm_gic_get_active_irq>:
#define GIC_DIST_ICPIDR2(hw_base)           __REG32((hw_base) + 0xfe8U)

static unsigned int _gic_max_irq;

int arm_gic_get_active_irq(rt_uint64_t index)
{
ffff000040082d48:	d10083ff 	sub	sp, sp, #0x20
ffff000040082d4c:	f90007e0 	str	x0, [sp, #8]
    int irq;

    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = GIC_CPU_INTACK(_gic_table[index].cpu_hw_base);
ffff000040082d50:	f0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040082d54:	912da002 	add	x2, x0, #0xb68
ffff000040082d58:	f94007e1 	ldr	x1, [sp, #8]
ffff000040082d5c:	aa0103e0 	mov	x0, x1
ffff000040082d60:	d37ff800 	lsl	x0, x0, #1
ffff000040082d64:	8b010000 	add	x0, x0, x1
ffff000040082d68:	d37df000 	lsl	x0, x0, #3
ffff000040082d6c:	8b000040 	add	x0, x2, x0
ffff000040082d70:	f9400800 	ldr	x0, [x0, #16]
ffff000040082d74:	91003000 	add	x0, x0, #0xc
ffff000040082d78:	b9400000 	ldr	w0, [x0]
ffff000040082d7c:	b9001fe0 	str	w0, [sp, #28]
    irq += _gic_table[index].offset;
ffff000040082d80:	f0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040082d84:	912da002 	add	x2, x0, #0xb68
ffff000040082d88:	f94007e1 	ldr	x1, [sp, #8]
ffff000040082d8c:	aa0103e0 	mov	x0, x1
ffff000040082d90:	d37ff800 	lsl	x0, x0, #1
ffff000040082d94:	8b010000 	add	x0, x0, x1
ffff000040082d98:	d37df000 	lsl	x0, x0, #3
ffff000040082d9c:	8b000040 	add	x0, x2, x0
ffff000040082da0:	f9400000 	ldr	x0, [x0]
ffff000040082da4:	2a0003e1 	mov	w1, w0
ffff000040082da8:	b9401fe0 	ldr	w0, [sp, #28]
ffff000040082dac:	0b000020 	add	w0, w1, w0
ffff000040082db0:	b9001fe0 	str	w0, [sp, #28]
    return irq;
ffff000040082db4:	b9401fe0 	ldr	w0, [sp, #28]
}
ffff000040082db8:	910083ff 	add	sp, sp, #0x20
ffff000040082dbc:	d65f03c0 	ret

ffff000040082dc0 <arm_gic_ack>:

void arm_gic_ack(rt_uint64_t index, int irq)
{
ffff000040082dc0:	d10083ff 	sub	sp, sp, #0x20
ffff000040082dc4:	f90007e0 	str	x0, [sp, #8]
ffff000040082dc8:	b90007e1 	str	w1, [sp, #4]
    rt_uint64_t mask = 1U << (irq % 32U);
ffff000040082dcc:	b94007e0 	ldr	w0, [sp, #4]
ffff000040082dd0:	12001000 	and	w0, w0, #0x1f
ffff000040082dd4:	52800021 	mov	w1, #0x1                   	// #1
ffff000040082dd8:	1ac02020 	lsl	w0, w1, w0
ffff000040082ddc:	2a0003e0 	mov	w0, w0
ffff000040082de0:	f9000fe0 	str	x0, [sp, #24]

    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = irq - _gic_table[index].offset;
ffff000040082de4:	b94007e2 	ldr	w2, [sp, #4]
ffff000040082de8:	f0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040082dec:	912da003 	add	x3, x0, #0xb68
ffff000040082df0:	f94007e1 	ldr	x1, [sp, #8]
ffff000040082df4:	aa0103e0 	mov	x0, x1
ffff000040082df8:	d37ff800 	lsl	x0, x0, #1
ffff000040082dfc:	8b010000 	add	x0, x0, x1
ffff000040082e00:	d37df000 	lsl	x0, x0, #3
ffff000040082e04:	8b000060 	add	x0, x3, x0
ffff000040082e08:	f9400000 	ldr	x0, [x0]
ffff000040082e0c:	4b000040 	sub	w0, w2, w0
ffff000040082e10:	b90007e0 	str	w0, [sp, #4]
    RT_ASSERT(irq >= 0U);

    GIC_DIST_PENDING_CLEAR(_gic_table[index].dist_hw_base, irq) = mask;
ffff000040082e14:	f0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040082e18:	912da002 	add	x2, x0, #0xb68
ffff000040082e1c:	f94007e1 	ldr	x1, [sp, #8]
ffff000040082e20:	aa0103e0 	mov	x0, x1
ffff000040082e24:	d37ff800 	lsl	x0, x0, #1
ffff000040082e28:	8b010000 	add	x0, x0, x1
ffff000040082e2c:	d37df000 	lsl	x0, x0, #3
ffff000040082e30:	8b000040 	add	x0, x2, x0
ffff000040082e34:	f9400401 	ldr	x1, [x0, #8]
ffff000040082e38:	b94007e0 	ldr	w0, [sp, #4]
ffff000040082e3c:	53057c00 	lsr	w0, w0, #5
ffff000040082e40:	531e7400 	lsl	w0, w0, #2
ffff000040082e44:	2a0003e0 	mov	w0, w0
ffff000040082e48:	8b000020 	add	x0, x1, x0
ffff000040082e4c:	910a0000 	add	x0, x0, #0x280
ffff000040082e50:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040082e54:	b9000001 	str	w1, [x0]
    GIC_CPU_EOI(_gic_table[index].cpu_hw_base) = irq;
ffff000040082e58:	f0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040082e5c:	912da002 	add	x2, x0, #0xb68
ffff000040082e60:	f94007e1 	ldr	x1, [sp, #8]
ffff000040082e64:	aa0103e0 	mov	x0, x1
ffff000040082e68:	d37ff800 	lsl	x0, x0, #1
ffff000040082e6c:	8b010000 	add	x0, x0, x1
ffff000040082e70:	d37df000 	lsl	x0, x0, #3
ffff000040082e74:	8b000040 	add	x0, x2, x0
ffff000040082e78:	f9400800 	ldr	x0, [x0, #16]
ffff000040082e7c:	91004000 	add	x0, x0, #0x10
ffff000040082e80:	aa0003e1 	mov	x1, x0
ffff000040082e84:	b94007e0 	ldr	w0, [sp, #4]
ffff000040082e88:	b9000020 	str	w0, [x1]
}
ffff000040082e8c:	d503201f 	nop
ffff000040082e90:	910083ff 	add	sp, sp, #0x20
ffff000040082e94:	d65f03c0 	ret

ffff000040082e98 <arm_gic_mask>:

void arm_gic_mask(rt_uint64_t index, int irq)
{
ffff000040082e98:	d10083ff 	sub	sp, sp, #0x20
ffff000040082e9c:	f90007e0 	str	x0, [sp, #8]
ffff000040082ea0:	b90007e1 	str	w1, [sp, #4]
    rt_uint64_t mask = 1U << (irq % 32U);
ffff000040082ea4:	b94007e0 	ldr	w0, [sp, #4]
ffff000040082ea8:	12001000 	and	w0, w0, #0x1f
ffff000040082eac:	52800021 	mov	w1, #0x1                   	// #1
ffff000040082eb0:	1ac02020 	lsl	w0, w1, w0
ffff000040082eb4:	2a0003e0 	mov	w0, w0
ffff000040082eb8:	f9000fe0 	str	x0, [sp, #24]

    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = irq - _gic_table[index].offset;
ffff000040082ebc:	b94007e2 	ldr	w2, [sp, #4]
ffff000040082ec0:	f0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040082ec4:	912da003 	add	x3, x0, #0xb68
ffff000040082ec8:	f94007e1 	ldr	x1, [sp, #8]
ffff000040082ecc:	aa0103e0 	mov	x0, x1
ffff000040082ed0:	d37ff800 	lsl	x0, x0, #1
ffff000040082ed4:	8b010000 	add	x0, x0, x1
ffff000040082ed8:	d37df000 	lsl	x0, x0, #3
ffff000040082edc:	8b000060 	add	x0, x3, x0
ffff000040082ee0:	f9400000 	ldr	x0, [x0]
ffff000040082ee4:	4b000040 	sub	w0, w2, w0
ffff000040082ee8:	b90007e0 	str	w0, [sp, #4]
    RT_ASSERT(irq >= 0U);

    GIC_DIST_ENABLE_CLEAR(_gic_table[index].dist_hw_base, irq) = mask;
ffff000040082eec:	f0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040082ef0:	912da002 	add	x2, x0, #0xb68
ffff000040082ef4:	f94007e1 	ldr	x1, [sp, #8]
ffff000040082ef8:	aa0103e0 	mov	x0, x1
ffff000040082efc:	d37ff800 	lsl	x0, x0, #1
ffff000040082f00:	8b010000 	add	x0, x0, x1
ffff000040082f04:	d37df000 	lsl	x0, x0, #3
ffff000040082f08:	8b000040 	add	x0, x2, x0
ffff000040082f0c:	f9400401 	ldr	x1, [x0, #8]
ffff000040082f10:	b94007e0 	ldr	w0, [sp, #4]
ffff000040082f14:	53057c00 	lsr	w0, w0, #5
ffff000040082f18:	531e7400 	lsl	w0, w0, #2
ffff000040082f1c:	2a0003e0 	mov	w0, w0
ffff000040082f20:	8b000020 	add	x0, x1, x0
ffff000040082f24:	91060000 	add	x0, x0, #0x180
ffff000040082f28:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040082f2c:	b9000001 	str	w1, [x0]
}
ffff000040082f30:	d503201f 	nop
ffff000040082f34:	910083ff 	add	sp, sp, #0x20
ffff000040082f38:	d65f03c0 	ret

ffff000040082f3c <arm_gic_umask>:

void arm_gic_umask(rt_uint64_t index, int irq)
{
ffff000040082f3c:	d10083ff 	sub	sp, sp, #0x20
ffff000040082f40:	f90007e0 	str	x0, [sp, #8]
ffff000040082f44:	b90007e1 	str	w1, [sp, #4]
    rt_uint64_t mask = 1U << (irq % 32U);
ffff000040082f48:	b94007e0 	ldr	w0, [sp, #4]
ffff000040082f4c:	12001000 	and	w0, w0, #0x1f
ffff000040082f50:	52800021 	mov	w1, #0x1                   	// #1
ffff000040082f54:	1ac02020 	lsl	w0, w1, w0
ffff000040082f58:	2a0003e0 	mov	w0, w0
ffff000040082f5c:	f9000fe0 	str	x0, [sp, #24]

    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = irq - _gic_table[index].offset;
ffff000040082f60:	b94007e2 	ldr	w2, [sp, #4]
ffff000040082f64:	f0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040082f68:	912da003 	add	x3, x0, #0xb68
ffff000040082f6c:	f94007e1 	ldr	x1, [sp, #8]
ffff000040082f70:	aa0103e0 	mov	x0, x1
ffff000040082f74:	d37ff800 	lsl	x0, x0, #1
ffff000040082f78:	8b010000 	add	x0, x0, x1
ffff000040082f7c:	d37df000 	lsl	x0, x0, #3
ffff000040082f80:	8b000060 	add	x0, x3, x0
ffff000040082f84:	f9400000 	ldr	x0, [x0]
ffff000040082f88:	4b000040 	sub	w0, w2, w0
ffff000040082f8c:	b90007e0 	str	w0, [sp, #4]
    RT_ASSERT(irq >= 0U);

    GIC_DIST_ENABLE_SET(_gic_table[index].dist_hw_base, irq) = mask;
ffff000040082f90:	f0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040082f94:	912da002 	add	x2, x0, #0xb68
ffff000040082f98:	f94007e1 	ldr	x1, [sp, #8]
ffff000040082f9c:	aa0103e0 	mov	x0, x1
ffff000040082fa0:	d37ff800 	lsl	x0, x0, #1
ffff000040082fa4:	8b010000 	add	x0, x0, x1
ffff000040082fa8:	d37df000 	lsl	x0, x0, #3
ffff000040082fac:	8b000040 	add	x0, x2, x0
ffff000040082fb0:	f9400401 	ldr	x1, [x0, #8]
ffff000040082fb4:	b94007e0 	ldr	w0, [sp, #4]
ffff000040082fb8:	53057c00 	lsr	w0, w0, #5
ffff000040082fbc:	531e7400 	lsl	w0, w0, #2
ffff000040082fc0:	2a0003e0 	mov	w0, w0
ffff000040082fc4:	8b000020 	add	x0, x1, x0
ffff000040082fc8:	91040000 	add	x0, x0, #0x100
ffff000040082fcc:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040082fd0:	b9000001 	str	w1, [x0]
}
ffff000040082fd4:	d503201f 	nop
ffff000040082fd8:	910083ff 	add	sp, sp, #0x20
ffff000040082fdc:	d65f03c0 	ret

ffff000040082fe0 <arm_gic_get_pending_irq>:

rt_uint64_t arm_gic_get_pending_irq(rt_uint64_t index, int irq)
{
ffff000040082fe0:	d10083ff 	sub	sp, sp, #0x20
ffff000040082fe4:	f90007e0 	str	x0, [sp, #8]
ffff000040082fe8:	b90007e1 	str	w1, [sp, #4]
    rt_uint64_t pend;

    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = irq - _gic_table[index].offset;
ffff000040082fec:	b94007e2 	ldr	w2, [sp, #4]
ffff000040082ff0:	f0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040082ff4:	912da003 	add	x3, x0, #0xb68
ffff000040082ff8:	f94007e1 	ldr	x1, [sp, #8]
ffff000040082ffc:	aa0103e0 	mov	x0, x1
ffff000040083000:	d37ff800 	lsl	x0, x0, #1
ffff000040083004:	8b010000 	add	x0, x0, x1
ffff000040083008:	d37df000 	lsl	x0, x0, #3
ffff00004008300c:	8b000060 	add	x0, x3, x0
ffff000040083010:	f9400000 	ldr	x0, [x0]
ffff000040083014:	4b000040 	sub	w0, w2, w0
ffff000040083018:	b90007e0 	str	w0, [sp, #4]
    RT_ASSERT(irq >= 0U);

    if (irq >= 16U)
ffff00004008301c:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083020:	71003c1f 	cmp	w0, #0xf
ffff000040083024:	54000309 	b.ls	ffff000040083084 <arm_gic_get_pending_irq+0xa4>  // b.plast
    {
        pend = (GIC_DIST_PENDING_SET(_gic_table[index].dist_hw_base, irq) >> (irq % 32U)) & 0x1UL;
ffff000040083028:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff00004008302c:	912da002 	add	x2, x0, #0xb68
ffff000040083030:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083034:	aa0103e0 	mov	x0, x1
ffff000040083038:	d37ff800 	lsl	x0, x0, #1
ffff00004008303c:	8b010000 	add	x0, x0, x1
ffff000040083040:	d37df000 	lsl	x0, x0, #3
ffff000040083044:	8b000040 	add	x0, x2, x0
ffff000040083048:	f9400401 	ldr	x1, [x0, #8]
ffff00004008304c:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083050:	53057c00 	lsr	w0, w0, #5
ffff000040083054:	531e7400 	lsl	w0, w0, #2
ffff000040083058:	2a0003e0 	mov	w0, w0
ffff00004008305c:	8b000020 	add	x0, x1, x0
ffff000040083060:	91080000 	add	x0, x0, #0x200
ffff000040083064:	b9400001 	ldr	w1, [x0]
ffff000040083068:	b94007e0 	ldr	w0, [sp, #4]
ffff00004008306c:	12001000 	and	w0, w0, #0x1f
ffff000040083070:	1ac02420 	lsr	w0, w1, w0
ffff000040083074:	2a0003e0 	mov	w0, w0
ffff000040083078:	92400000 	and	x0, x0, #0x1
ffff00004008307c:	f9000fe0 	str	x0, [sp, #24]
ffff000040083080:	1400001e 	b	ffff0000400830f8 <arm_gic_get_pending_irq+0x118>
    }
    else
    {
        /* INTID 0-15 Software Generated Interrupt */
        pend = (GIC_DIST_SPENDSGI(_gic_table[index].dist_hw_base, irq) >> ((irq % 4U) * 8U)) & 0xFFUL;
ffff000040083084:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083088:	912da002 	add	x2, x0, #0xb68
ffff00004008308c:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083090:	aa0103e0 	mov	x0, x1
ffff000040083094:	d37ff800 	lsl	x0, x0, #1
ffff000040083098:	8b010000 	add	x0, x0, x1
ffff00004008309c:	d37df000 	lsl	x0, x0, #3
ffff0000400830a0:	8b000040 	add	x0, x2, x0
ffff0000400830a4:	f9400401 	ldr	x1, [x0, #8]
ffff0000400830a8:	b94007e0 	ldr	w0, [sp, #4]
ffff0000400830ac:	2a0003e0 	mov	w0, w0
ffff0000400830b0:	927e7400 	and	x0, x0, #0xfffffffc
ffff0000400830b4:	8b000020 	add	x0, x1, x0
ffff0000400830b8:	913c8000 	add	x0, x0, #0xf20
ffff0000400830bc:	b9400001 	ldr	w1, [x0]
ffff0000400830c0:	b94007e0 	ldr	w0, [sp, #4]
ffff0000400830c4:	12000400 	and	w0, w0, #0x3
ffff0000400830c8:	531d7000 	lsl	w0, w0, #3
ffff0000400830cc:	1ac02420 	lsr	w0, w1, w0
ffff0000400830d0:	2a0003e0 	mov	w0, w0
ffff0000400830d4:	92401c00 	and	x0, x0, #0xff
ffff0000400830d8:	f9000fe0 	str	x0, [sp, #24]
        /* No CPU identification offered */
        if (pend != 0U)
ffff0000400830dc:	f9400fe0 	ldr	x0, [sp, #24]
ffff0000400830e0:	f100001f 	cmp	x0, #0x0
ffff0000400830e4:	54000080 	b.eq	ffff0000400830f4 <arm_gic_get_pending_irq+0x114>  // b.none
        {
            pend = 1U;
ffff0000400830e8:	d2800020 	mov	x0, #0x1                   	// #1
ffff0000400830ec:	f9000fe0 	str	x0, [sp, #24]
ffff0000400830f0:	14000002 	b	ffff0000400830f8 <arm_gic_get_pending_irq+0x118>
        }
        else
        {
            pend = 0U;
ffff0000400830f4:	f9000fff 	str	xzr, [sp, #24]
        }
    }

    return (pend);
ffff0000400830f8:	f9400fe0 	ldr	x0, [sp, #24]
}
ffff0000400830fc:	910083ff 	add	sp, sp, #0x20
ffff000040083100:	d65f03c0 	ret

ffff000040083104 <arm_gic_set_pending_irq>:

void arm_gic_set_pending_irq(rt_uint64_t index, int irq)
{
ffff000040083104:	d10043ff 	sub	sp, sp, #0x10
ffff000040083108:	f90007e0 	str	x0, [sp, #8]
ffff00004008310c:	b90007e1 	str	w1, [sp, #4]
    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = irq - _gic_table[index].offset;
ffff000040083110:	b94007e2 	ldr	w2, [sp, #4]
ffff000040083114:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083118:	912da003 	add	x3, x0, #0xb68
ffff00004008311c:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083120:	aa0103e0 	mov	x0, x1
ffff000040083124:	d37ff800 	lsl	x0, x0, #1
ffff000040083128:	8b010000 	add	x0, x0, x1
ffff00004008312c:	d37df000 	lsl	x0, x0, #3
ffff000040083130:	8b000060 	add	x0, x3, x0
ffff000040083134:	f9400000 	ldr	x0, [x0]
ffff000040083138:	4b000040 	sub	w0, w2, w0
ffff00004008313c:	b90007e0 	str	w0, [sp, #4]
    RT_ASSERT(irq >= 0U);

    if (irq >= 16U)
ffff000040083140:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083144:	71003c1f 	cmp	w0, #0xf
ffff000040083148:	540002e9 	b.ls	ffff0000400831a4 <arm_gic_set_pending_irq+0xa0>  // b.plast
    {
        GIC_DIST_PENDING_SET(_gic_table[index].dist_hw_base, irq) = 1U << (irq % 32U);
ffff00004008314c:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083150:	12001002 	and	w2, w0, #0x1f
ffff000040083154:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083158:	912da003 	add	x3, x0, #0xb68
ffff00004008315c:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083160:	aa0103e0 	mov	x0, x1
ffff000040083164:	d37ff800 	lsl	x0, x0, #1
ffff000040083168:	8b010000 	add	x0, x0, x1
ffff00004008316c:	d37df000 	lsl	x0, x0, #3
ffff000040083170:	8b000060 	add	x0, x3, x0
ffff000040083174:	f9400401 	ldr	x1, [x0, #8]
ffff000040083178:	b94007e0 	ldr	w0, [sp, #4]
ffff00004008317c:	53057c00 	lsr	w0, w0, #5
ffff000040083180:	531e7400 	lsl	w0, w0, #2
ffff000040083184:	2a0003e0 	mov	w0, w0
ffff000040083188:	8b000020 	add	x0, x1, x0
ffff00004008318c:	91080000 	add	x0, x0, #0x200
ffff000040083190:	aa0003e1 	mov	x1, x0
ffff000040083194:	52800020 	mov	w0, #0x1                   	// #1
ffff000040083198:	1ac22000 	lsl	w0, w0, w2
ffff00004008319c:	b9000020 	str	w0, [x1]
    {
        /* INTID 0-15 Software Generated Interrupt */
        /* Forward the interrupt to the CPU interface that requested it */
        GIC_DIST_SOFTINT(_gic_table[index].dist_hw_base) = (irq | 0x02000000U);
    }
}
ffff0000400831a0:	1400000f 	b	ffff0000400831dc <arm_gic_set_pending_irq+0xd8>
        GIC_DIST_SOFTINT(_gic_table[index].dist_hw_base) = (irq | 0x02000000U);
ffff0000400831a4:	b94007e2 	ldr	w2, [sp, #4]
ffff0000400831a8:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400831ac:	912da003 	add	x3, x0, #0xb68
ffff0000400831b0:	f94007e1 	ldr	x1, [sp, #8]
ffff0000400831b4:	aa0103e0 	mov	x0, x1
ffff0000400831b8:	d37ff800 	lsl	x0, x0, #1
ffff0000400831bc:	8b010000 	add	x0, x0, x1
ffff0000400831c0:	d37df000 	lsl	x0, x0, #3
ffff0000400831c4:	8b000060 	add	x0, x3, x0
ffff0000400831c8:	f9400400 	ldr	x0, [x0, #8]
ffff0000400831cc:	913c0000 	add	x0, x0, #0xf00
ffff0000400831d0:	aa0003e1 	mov	x1, x0
ffff0000400831d4:	32070040 	orr	w0, w2, #0x2000000
ffff0000400831d8:	b9000020 	str	w0, [x1]
}
ffff0000400831dc:	d503201f 	nop
ffff0000400831e0:	910043ff 	add	sp, sp, #0x10
ffff0000400831e4:	d65f03c0 	ret

ffff0000400831e8 <arm_gic_clear_pending_irq>:

void arm_gic_clear_pending_irq(rt_uint64_t index, int irq)
{
ffff0000400831e8:	d10083ff 	sub	sp, sp, #0x20
ffff0000400831ec:	f90007e0 	str	x0, [sp, #8]
ffff0000400831f0:	b90007e1 	str	w1, [sp, #4]
    rt_uint64_t mask;

    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = irq - _gic_table[index].offset;
ffff0000400831f4:	b94007e2 	ldr	w2, [sp, #4]
ffff0000400831f8:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400831fc:	912da003 	add	x3, x0, #0xb68
ffff000040083200:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083204:	aa0103e0 	mov	x0, x1
ffff000040083208:	d37ff800 	lsl	x0, x0, #1
ffff00004008320c:	8b010000 	add	x0, x0, x1
ffff000040083210:	d37df000 	lsl	x0, x0, #3
ffff000040083214:	8b000060 	add	x0, x3, x0
ffff000040083218:	f9400000 	ldr	x0, [x0]
ffff00004008321c:	4b000040 	sub	w0, w2, w0
ffff000040083220:	b90007e0 	str	w0, [sp, #4]
    RT_ASSERT(irq >= 0U);

    if (irq >= 16U)
ffff000040083224:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083228:	71003c1f 	cmp	w0, #0xf
ffff00004008322c:	54000329 	b.ls	ffff000040083290 <arm_gic_clear_pending_irq+0xa8>  // b.plast
    {
        mask = 1U << (irq % 32U);
ffff000040083230:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083234:	12001000 	and	w0, w0, #0x1f
ffff000040083238:	52800021 	mov	w1, #0x1                   	// #1
ffff00004008323c:	1ac02020 	lsl	w0, w1, w0
ffff000040083240:	2a0003e0 	mov	w0, w0
ffff000040083244:	f9000fe0 	str	x0, [sp, #24]
        GIC_DIST_PENDING_CLEAR(_gic_table[index].dist_hw_base, irq) = mask;
ffff000040083248:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff00004008324c:	912da002 	add	x2, x0, #0xb68
ffff000040083250:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083254:	aa0103e0 	mov	x0, x1
ffff000040083258:	d37ff800 	lsl	x0, x0, #1
ffff00004008325c:	8b010000 	add	x0, x0, x1
ffff000040083260:	d37df000 	lsl	x0, x0, #3
ffff000040083264:	8b000040 	add	x0, x2, x0
ffff000040083268:	f9400401 	ldr	x1, [x0, #8]
ffff00004008326c:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083270:	53057c00 	lsr	w0, w0, #5
ffff000040083274:	531e7400 	lsl	w0, w0, #2
ffff000040083278:	2a0003e0 	mov	w0, w0
ffff00004008327c:	8b000020 	add	x0, x1, x0
ffff000040083280:	910a0000 	add	x0, x0, #0x280
ffff000040083284:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040083288:	b9000001 	str	w1, [x0]
    else
    {
        mask =  1U << ((irq % 4U) * 8U);
        GIC_DIST_CPENDSGI(_gic_table[index].dist_hw_base, irq) = mask;
    }
}
ffff00004008328c:	14000018 	b	ffff0000400832ec <arm_gic_clear_pending_irq+0x104>
        mask =  1U << ((irq % 4U) * 8U);
ffff000040083290:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083294:	12000400 	and	w0, w0, #0x3
ffff000040083298:	531d7000 	lsl	w0, w0, #3
ffff00004008329c:	52800021 	mov	w1, #0x1                   	// #1
ffff0000400832a0:	1ac02020 	lsl	w0, w1, w0
ffff0000400832a4:	2a0003e0 	mov	w0, w0
ffff0000400832a8:	f9000fe0 	str	x0, [sp, #24]
        GIC_DIST_CPENDSGI(_gic_table[index].dist_hw_base, irq) = mask;
ffff0000400832ac:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400832b0:	912da002 	add	x2, x0, #0xb68
ffff0000400832b4:	f94007e1 	ldr	x1, [sp, #8]
ffff0000400832b8:	aa0103e0 	mov	x0, x1
ffff0000400832bc:	d37ff800 	lsl	x0, x0, #1
ffff0000400832c0:	8b010000 	add	x0, x0, x1
ffff0000400832c4:	d37df000 	lsl	x0, x0, #3
ffff0000400832c8:	8b000040 	add	x0, x2, x0
ffff0000400832cc:	f9400401 	ldr	x1, [x0, #8]
ffff0000400832d0:	b94007e0 	ldr	w0, [sp, #4]
ffff0000400832d4:	2a0003e0 	mov	w0, w0
ffff0000400832d8:	927e7400 	and	x0, x0, #0xfffffffc
ffff0000400832dc:	8b000020 	add	x0, x1, x0
ffff0000400832e0:	913c4000 	add	x0, x0, #0xf10
ffff0000400832e4:	f9400fe1 	ldr	x1, [sp, #24]
ffff0000400832e8:	b9000001 	str	w1, [x0]
}
ffff0000400832ec:	d503201f 	nop
ffff0000400832f0:	910083ff 	add	sp, sp, #0x20
ffff0000400832f4:	d65f03c0 	ret

ffff0000400832f8 <arm_gic_set_configuration>:

void arm_gic_set_configuration(rt_uint64_t index, int irq, uint32_t config)
{
ffff0000400832f8:	d10083ff 	sub	sp, sp, #0x20
ffff0000400832fc:	f90007e0 	str	x0, [sp, #8]
ffff000040083300:	b90007e1 	str	w1, [sp, #4]
ffff000040083304:	b90003e2 	str	w2, [sp]
    rt_uint64_t icfgr;
    rt_uint64_t shift;

    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = irq - _gic_table[index].offset;
ffff000040083308:	b94007e2 	ldr	w2, [sp, #4]
ffff00004008330c:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083310:	912da003 	add	x3, x0, #0xb68
ffff000040083314:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083318:	aa0103e0 	mov	x0, x1
ffff00004008331c:	d37ff800 	lsl	x0, x0, #1
ffff000040083320:	8b010000 	add	x0, x0, x1
ffff000040083324:	d37df000 	lsl	x0, x0, #3
ffff000040083328:	8b000060 	add	x0, x3, x0
ffff00004008332c:	f9400000 	ldr	x0, [x0]
ffff000040083330:	4b000040 	sub	w0, w2, w0
ffff000040083334:	b90007e0 	str	w0, [sp, #4]
    RT_ASSERT(irq >= 0U);

    icfgr = GIC_DIST_CONFIG(_gic_table[index].dist_hw_base, irq);
ffff000040083338:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff00004008333c:	912da002 	add	x2, x0, #0xb68
ffff000040083340:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083344:	aa0103e0 	mov	x0, x1
ffff000040083348:	d37ff800 	lsl	x0, x0, #1
ffff00004008334c:	8b010000 	add	x0, x0, x1
ffff000040083350:	d37df000 	lsl	x0, x0, #3
ffff000040083354:	8b000040 	add	x0, x2, x0
ffff000040083358:	f9400401 	ldr	x1, [x0, #8]
ffff00004008335c:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083360:	53047c00 	lsr	w0, w0, #4
ffff000040083364:	531e7400 	lsl	w0, w0, #2
ffff000040083368:	2a0003e0 	mov	w0, w0
ffff00004008336c:	8b000020 	add	x0, x1, x0
ffff000040083370:	91300000 	add	x0, x0, #0xc00
ffff000040083374:	b9400000 	ldr	w0, [x0]
ffff000040083378:	2a0003e0 	mov	w0, w0
ffff00004008337c:	f9000fe0 	str	x0, [sp, #24]
    shift = (irq % 16U) << 1U;
ffff000040083380:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083384:	531f7800 	lsl	w0, w0, #1
ffff000040083388:	2a0003e0 	mov	w0, w0
ffff00004008338c:	927f0c00 	and	x0, x0, #0x1e
ffff000040083390:	f9000be0 	str	x0, [sp, #16]

    icfgr &= (~(3U << shift));
ffff000040083394:	f9400be0 	ldr	x0, [sp, #16]
ffff000040083398:	2a0003e1 	mov	w1, w0
ffff00004008339c:	52800060 	mov	w0, #0x3                   	// #3
ffff0000400833a0:	1ac12000 	lsl	w0, w0, w1
ffff0000400833a4:	2a2003e0 	mvn	w0, w0
ffff0000400833a8:	2a0003e0 	mov	w0, w0
ffff0000400833ac:	f9400fe1 	ldr	x1, [sp, #24]
ffff0000400833b0:	8a000020 	and	x0, x1, x0
ffff0000400833b4:	f9000fe0 	str	x0, [sp, #24]
    icfgr |= (config << (shift + 1));
ffff0000400833b8:	f9400be0 	ldr	x0, [sp, #16]
ffff0000400833bc:	11000400 	add	w0, w0, #0x1
ffff0000400833c0:	b94003e1 	ldr	w1, [sp]
ffff0000400833c4:	1ac02020 	lsl	w0, w1, w0
ffff0000400833c8:	2a0003e0 	mov	w0, w0
ffff0000400833cc:	f9400fe1 	ldr	x1, [sp, #24]
ffff0000400833d0:	aa000020 	orr	x0, x1, x0
ffff0000400833d4:	f9000fe0 	str	x0, [sp, #24]

    GIC_DIST_CONFIG(_gic_table[index].dist_hw_base, irq) = icfgr;
ffff0000400833d8:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400833dc:	912da002 	add	x2, x0, #0xb68
ffff0000400833e0:	f94007e1 	ldr	x1, [sp, #8]
ffff0000400833e4:	aa0103e0 	mov	x0, x1
ffff0000400833e8:	d37ff800 	lsl	x0, x0, #1
ffff0000400833ec:	8b010000 	add	x0, x0, x1
ffff0000400833f0:	d37df000 	lsl	x0, x0, #3
ffff0000400833f4:	8b000040 	add	x0, x2, x0
ffff0000400833f8:	f9400401 	ldr	x1, [x0, #8]
ffff0000400833fc:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083400:	53047c00 	lsr	w0, w0, #4
ffff000040083404:	531e7400 	lsl	w0, w0, #2
ffff000040083408:	2a0003e0 	mov	w0, w0
ffff00004008340c:	8b000020 	add	x0, x1, x0
ffff000040083410:	91300000 	add	x0, x0, #0xc00
ffff000040083414:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040083418:	b9000001 	str	w1, [x0]
}
ffff00004008341c:	d503201f 	nop
ffff000040083420:	910083ff 	add	sp, sp, #0x20
ffff000040083424:	d65f03c0 	ret

ffff000040083428 <arm_gic_get_configuration>:

rt_uint64_t arm_gic_get_configuration(rt_uint64_t index, int irq)
{
ffff000040083428:	d10043ff 	sub	sp, sp, #0x10
ffff00004008342c:	f90007e0 	str	x0, [sp, #8]
ffff000040083430:	b90007e1 	str	w1, [sp, #4]
    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = irq - _gic_table[index].offset;
ffff000040083434:	b94007e2 	ldr	w2, [sp, #4]
ffff000040083438:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff00004008343c:	912da003 	add	x3, x0, #0xb68
ffff000040083440:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083444:	aa0103e0 	mov	x0, x1
ffff000040083448:	d37ff800 	lsl	x0, x0, #1
ffff00004008344c:	8b010000 	add	x0, x0, x1
ffff000040083450:	d37df000 	lsl	x0, x0, #3
ffff000040083454:	8b000060 	add	x0, x3, x0
ffff000040083458:	f9400000 	ldr	x0, [x0]
ffff00004008345c:	4b000040 	sub	w0, w2, w0
ffff000040083460:	b90007e0 	str	w0, [sp, #4]
    RT_ASSERT(irq >= 0U);

    return (GIC_DIST_CONFIG(_gic_table[index].dist_hw_base, irq) >> ((irq % 16U) >> 1U));
ffff000040083464:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083468:	912da002 	add	x2, x0, #0xb68
ffff00004008346c:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083470:	aa0103e0 	mov	x0, x1
ffff000040083474:	d37ff800 	lsl	x0, x0, #1
ffff000040083478:	8b010000 	add	x0, x0, x1
ffff00004008347c:	d37df000 	lsl	x0, x0, #3
ffff000040083480:	8b000040 	add	x0, x2, x0
ffff000040083484:	f9400401 	ldr	x1, [x0, #8]
ffff000040083488:	b94007e0 	ldr	w0, [sp, #4]
ffff00004008348c:	53047c00 	lsr	w0, w0, #4
ffff000040083490:	531e7400 	lsl	w0, w0, #2
ffff000040083494:	2a0003e0 	mov	w0, w0
ffff000040083498:	8b000020 	add	x0, x1, x0
ffff00004008349c:	91300000 	add	x0, x0, #0xc00
ffff0000400834a0:	b9400001 	ldr	w1, [x0]
ffff0000400834a4:	b94007e0 	ldr	w0, [sp, #4]
ffff0000400834a8:	53017c00 	lsr	w0, w0, #1
ffff0000400834ac:	12000800 	and	w0, w0, #0x7
ffff0000400834b0:	1ac02420 	lsr	w0, w1, w0
ffff0000400834b4:	2a0003e0 	mov	w0, w0
}
ffff0000400834b8:	910043ff 	add	sp, sp, #0x10
ffff0000400834bc:	d65f03c0 	ret

ffff0000400834c0 <arm_gic_clear_active>:

void arm_gic_clear_active(rt_uint64_t index, int irq)
{
ffff0000400834c0:	d10083ff 	sub	sp, sp, #0x20
ffff0000400834c4:	f90007e0 	str	x0, [sp, #8]
ffff0000400834c8:	b90007e1 	str	w1, [sp, #4]
    rt_uint64_t mask = 1U << (irq % 32U);
ffff0000400834cc:	b94007e0 	ldr	w0, [sp, #4]
ffff0000400834d0:	12001000 	and	w0, w0, #0x1f
ffff0000400834d4:	52800021 	mov	w1, #0x1                   	// #1
ffff0000400834d8:	1ac02020 	lsl	w0, w1, w0
ffff0000400834dc:	2a0003e0 	mov	w0, w0
ffff0000400834e0:	f9000fe0 	str	x0, [sp, #24]

    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = irq - _gic_table[index].offset;
ffff0000400834e4:	b94007e2 	ldr	w2, [sp, #4]
ffff0000400834e8:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400834ec:	912da003 	add	x3, x0, #0xb68
ffff0000400834f0:	f94007e1 	ldr	x1, [sp, #8]
ffff0000400834f4:	aa0103e0 	mov	x0, x1
ffff0000400834f8:	d37ff800 	lsl	x0, x0, #1
ffff0000400834fc:	8b010000 	add	x0, x0, x1
ffff000040083500:	d37df000 	lsl	x0, x0, #3
ffff000040083504:	8b000060 	add	x0, x3, x0
ffff000040083508:	f9400000 	ldr	x0, [x0]
ffff00004008350c:	4b000040 	sub	w0, w2, w0
ffff000040083510:	b90007e0 	str	w0, [sp, #4]
    RT_ASSERT(irq >= 0U);

    GIC_DIST_ACTIVE_CLEAR(_gic_table[index].dist_hw_base, irq) = mask;
ffff000040083514:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083518:	912da002 	add	x2, x0, #0xb68
ffff00004008351c:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083520:	aa0103e0 	mov	x0, x1
ffff000040083524:	d37ff800 	lsl	x0, x0, #1
ffff000040083528:	8b010000 	add	x0, x0, x1
ffff00004008352c:	d37df000 	lsl	x0, x0, #3
ffff000040083530:	8b000040 	add	x0, x2, x0
ffff000040083534:	f9400401 	ldr	x1, [x0, #8]
ffff000040083538:	b94007e0 	ldr	w0, [sp, #4]
ffff00004008353c:	53057c00 	lsr	w0, w0, #5
ffff000040083540:	531e7400 	lsl	w0, w0, #2
ffff000040083544:	2a0003e0 	mov	w0, w0
ffff000040083548:	8b000020 	add	x0, x1, x0
ffff00004008354c:	910e0000 	add	x0, x0, #0x380
ffff000040083550:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040083554:	b9000001 	str	w1, [x0]
}
ffff000040083558:	d503201f 	nop
ffff00004008355c:	910083ff 	add	sp, sp, #0x20
ffff000040083560:	d65f03c0 	ret

ffff000040083564 <arm_gic_set_cpu>:

/* Set up the cpu mask for the specific interrupt */
void arm_gic_set_cpu(rt_uint64_t index, int irq, unsigned int cpumask)
{
ffff000040083564:	d10083ff 	sub	sp, sp, #0x20
ffff000040083568:	f90007e0 	str	x0, [sp, #8]
ffff00004008356c:	b90007e1 	str	w1, [sp, #4]
ffff000040083570:	b90003e2 	str	w2, [sp]
    rt_uint64_t old_tgt;

    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = irq - _gic_table[index].offset;
ffff000040083574:	b94007e2 	ldr	w2, [sp, #4]
ffff000040083578:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff00004008357c:	912da003 	add	x3, x0, #0xb68
ffff000040083580:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083584:	aa0103e0 	mov	x0, x1
ffff000040083588:	d37ff800 	lsl	x0, x0, #1
ffff00004008358c:	8b010000 	add	x0, x0, x1
ffff000040083590:	d37df000 	lsl	x0, x0, #3
ffff000040083594:	8b000060 	add	x0, x3, x0
ffff000040083598:	f9400000 	ldr	x0, [x0]
ffff00004008359c:	4b000040 	sub	w0, w2, w0
ffff0000400835a0:	b90007e0 	str	w0, [sp, #4]
    RT_ASSERT(irq >= 0U);

    old_tgt = GIC_DIST_TARGET(_gic_table[index].dist_hw_base, irq);
ffff0000400835a4:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400835a8:	912da002 	add	x2, x0, #0xb68
ffff0000400835ac:	f94007e1 	ldr	x1, [sp, #8]
ffff0000400835b0:	aa0103e0 	mov	x0, x1
ffff0000400835b4:	d37ff800 	lsl	x0, x0, #1
ffff0000400835b8:	8b010000 	add	x0, x0, x1
ffff0000400835bc:	d37df000 	lsl	x0, x0, #3
ffff0000400835c0:	8b000040 	add	x0, x2, x0
ffff0000400835c4:	f9400401 	ldr	x1, [x0, #8]
ffff0000400835c8:	b94007e0 	ldr	w0, [sp, #4]
ffff0000400835cc:	2a0003e0 	mov	w0, w0
ffff0000400835d0:	927e7400 	and	x0, x0, #0xfffffffc
ffff0000400835d4:	8b000020 	add	x0, x1, x0
ffff0000400835d8:	91200000 	add	x0, x0, #0x800
ffff0000400835dc:	b9400000 	ldr	w0, [x0]
ffff0000400835e0:	2a0003e0 	mov	w0, w0
ffff0000400835e4:	f9000fe0 	str	x0, [sp, #24]

    old_tgt &= ~(0x0FFUL << ((irq % 4U)*8U));
ffff0000400835e8:	b94007e0 	ldr	w0, [sp, #4]
ffff0000400835ec:	12000400 	and	w0, w0, #0x3
ffff0000400835f0:	531d7000 	lsl	w0, w0, #3
ffff0000400835f4:	d2801fe1 	mov	x1, #0xff                  	// #255
ffff0000400835f8:	9ac02020 	lsl	x0, x1, x0
ffff0000400835fc:	aa2003e0 	mvn	x0, x0
ffff000040083600:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040083604:	8a000020 	and	x0, x1, x0
ffff000040083608:	f9000fe0 	str	x0, [sp, #24]
    old_tgt |= cpumask << ((irq % 4U)*8U);
ffff00004008360c:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083610:	12000400 	and	w0, w0, #0x3
ffff000040083614:	531d7000 	lsl	w0, w0, #3
ffff000040083618:	b94003e1 	ldr	w1, [sp]
ffff00004008361c:	1ac02020 	lsl	w0, w1, w0
ffff000040083620:	2a0003e0 	mov	w0, w0
ffff000040083624:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040083628:	aa000020 	orr	x0, x1, x0
ffff00004008362c:	f9000fe0 	str	x0, [sp, #24]

    GIC_DIST_TARGET(_gic_table[index].dist_hw_base, irq) = old_tgt;
ffff000040083630:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083634:	912da002 	add	x2, x0, #0xb68
ffff000040083638:	f94007e1 	ldr	x1, [sp, #8]
ffff00004008363c:	aa0103e0 	mov	x0, x1
ffff000040083640:	d37ff800 	lsl	x0, x0, #1
ffff000040083644:	8b010000 	add	x0, x0, x1
ffff000040083648:	d37df000 	lsl	x0, x0, #3
ffff00004008364c:	8b000040 	add	x0, x2, x0
ffff000040083650:	f9400401 	ldr	x1, [x0, #8]
ffff000040083654:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083658:	2a0003e0 	mov	w0, w0
ffff00004008365c:	927e7400 	and	x0, x0, #0xfffffffc
ffff000040083660:	8b000020 	add	x0, x1, x0
ffff000040083664:	91200000 	add	x0, x0, #0x800
ffff000040083668:	f9400fe1 	ldr	x1, [sp, #24]
ffff00004008366c:	b9000001 	str	w1, [x0]
}
ffff000040083670:	d503201f 	nop
ffff000040083674:	910083ff 	add	sp, sp, #0x20
ffff000040083678:	d65f03c0 	ret

ffff00004008367c <arm_gic_get_target_cpu>:

rt_uint64_t arm_gic_get_target_cpu(rt_uint64_t index, int irq)
{
ffff00004008367c:	d10043ff 	sub	sp, sp, #0x10
ffff000040083680:	f90007e0 	str	x0, [sp, #8]
ffff000040083684:	b90007e1 	str	w1, [sp, #4]
    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = irq - _gic_table[index].offset;
ffff000040083688:	b94007e2 	ldr	w2, [sp, #4]
ffff00004008368c:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083690:	912da003 	add	x3, x0, #0xb68
ffff000040083694:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083698:	aa0103e0 	mov	x0, x1
ffff00004008369c:	d37ff800 	lsl	x0, x0, #1
ffff0000400836a0:	8b010000 	add	x0, x0, x1
ffff0000400836a4:	d37df000 	lsl	x0, x0, #3
ffff0000400836a8:	8b000060 	add	x0, x3, x0
ffff0000400836ac:	f9400000 	ldr	x0, [x0]
ffff0000400836b0:	4b000040 	sub	w0, w2, w0
ffff0000400836b4:	b90007e0 	str	w0, [sp, #4]
    RT_ASSERT(irq >= 0U);

    return (GIC_DIST_TARGET(_gic_table[index].dist_hw_base, irq) >> ((irq % 4U) * 8U)) & 0xFFUL;
ffff0000400836b8:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400836bc:	912da002 	add	x2, x0, #0xb68
ffff0000400836c0:	f94007e1 	ldr	x1, [sp, #8]
ffff0000400836c4:	aa0103e0 	mov	x0, x1
ffff0000400836c8:	d37ff800 	lsl	x0, x0, #1
ffff0000400836cc:	8b010000 	add	x0, x0, x1
ffff0000400836d0:	d37df000 	lsl	x0, x0, #3
ffff0000400836d4:	8b000040 	add	x0, x2, x0
ffff0000400836d8:	f9400401 	ldr	x1, [x0, #8]
ffff0000400836dc:	b94007e0 	ldr	w0, [sp, #4]
ffff0000400836e0:	2a0003e0 	mov	w0, w0
ffff0000400836e4:	927e7400 	and	x0, x0, #0xfffffffc
ffff0000400836e8:	8b000020 	add	x0, x1, x0
ffff0000400836ec:	91200000 	add	x0, x0, #0x800
ffff0000400836f0:	b9400001 	ldr	w1, [x0]
ffff0000400836f4:	b94007e0 	ldr	w0, [sp, #4]
ffff0000400836f8:	12000400 	and	w0, w0, #0x3
ffff0000400836fc:	531d7000 	lsl	w0, w0, #3
ffff000040083700:	1ac02420 	lsr	w0, w1, w0
ffff000040083704:	2a0003e0 	mov	w0, w0
ffff000040083708:	92401c00 	and	x0, x0, #0xff
}
ffff00004008370c:	910043ff 	add	sp, sp, #0x10
ffff000040083710:	d65f03c0 	ret

ffff000040083714 <arm_gic_set_priority>:

void arm_gic_set_priority(rt_uint64_t index, int irq, rt_uint64_t priority)
{
ffff000040083714:	d100c3ff 	sub	sp, sp, #0x30
ffff000040083718:	f9000fe0 	str	x0, [sp, #24]
ffff00004008371c:	b90017e1 	str	w1, [sp, #20]
ffff000040083720:	f90007e2 	str	x2, [sp, #8]
    rt_uint64_t mask;

    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = irq - _gic_table[index].offset;
ffff000040083724:	b94017e2 	ldr	w2, [sp, #20]
ffff000040083728:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff00004008372c:	912da003 	add	x3, x0, #0xb68
ffff000040083730:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040083734:	aa0103e0 	mov	x0, x1
ffff000040083738:	d37ff800 	lsl	x0, x0, #1
ffff00004008373c:	8b010000 	add	x0, x0, x1
ffff000040083740:	d37df000 	lsl	x0, x0, #3
ffff000040083744:	8b000060 	add	x0, x3, x0
ffff000040083748:	f9400000 	ldr	x0, [x0]
ffff00004008374c:	4b000040 	sub	w0, w2, w0
ffff000040083750:	b90017e0 	str	w0, [sp, #20]
    RT_ASSERT(irq >= 0U);

    mask = GIC_DIST_PRI(_gic_table[index].dist_hw_base, irq);
ffff000040083754:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083758:	912da002 	add	x2, x0, #0xb68
ffff00004008375c:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040083760:	aa0103e0 	mov	x0, x1
ffff000040083764:	d37ff800 	lsl	x0, x0, #1
ffff000040083768:	8b010000 	add	x0, x0, x1
ffff00004008376c:	d37df000 	lsl	x0, x0, #3
ffff000040083770:	8b000040 	add	x0, x2, x0
ffff000040083774:	f9400401 	ldr	x1, [x0, #8]
ffff000040083778:	b94017e0 	ldr	w0, [sp, #20]
ffff00004008377c:	2a0003e0 	mov	w0, w0
ffff000040083780:	927e7400 	and	x0, x0, #0xfffffffc
ffff000040083784:	8b000020 	add	x0, x1, x0
ffff000040083788:	91100000 	add	x0, x0, #0x400
ffff00004008378c:	b9400000 	ldr	w0, [x0]
ffff000040083790:	2a0003e0 	mov	w0, w0
ffff000040083794:	f90017e0 	str	x0, [sp, #40]
    mask &= ~(0xFFUL << ((irq % 4U) * 8U));
ffff000040083798:	b94017e0 	ldr	w0, [sp, #20]
ffff00004008379c:	12000400 	and	w0, w0, #0x3
ffff0000400837a0:	531d7000 	lsl	w0, w0, #3
ffff0000400837a4:	d2801fe1 	mov	x1, #0xff                  	// #255
ffff0000400837a8:	9ac02020 	lsl	x0, x1, x0
ffff0000400837ac:	aa2003e0 	mvn	x0, x0
ffff0000400837b0:	f94017e1 	ldr	x1, [sp, #40]
ffff0000400837b4:	8a000020 	and	x0, x1, x0
ffff0000400837b8:	f90017e0 	str	x0, [sp, #40]
    mask |= ((priority & 0xFFUL) << ((irq % 4U) * 8U));
ffff0000400837bc:	f94007e0 	ldr	x0, [sp, #8]
ffff0000400837c0:	92401c01 	and	x1, x0, #0xff
ffff0000400837c4:	b94017e0 	ldr	w0, [sp, #20]
ffff0000400837c8:	12000400 	and	w0, w0, #0x3
ffff0000400837cc:	531d7000 	lsl	w0, w0, #3
ffff0000400837d0:	9ac02020 	lsl	x0, x1, x0
ffff0000400837d4:	f94017e1 	ldr	x1, [sp, #40]
ffff0000400837d8:	aa000020 	orr	x0, x1, x0
ffff0000400837dc:	f90017e0 	str	x0, [sp, #40]
    GIC_DIST_PRI(_gic_table[index].dist_hw_base, irq) = mask;
ffff0000400837e0:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400837e4:	912da002 	add	x2, x0, #0xb68
ffff0000400837e8:	f9400fe1 	ldr	x1, [sp, #24]
ffff0000400837ec:	aa0103e0 	mov	x0, x1
ffff0000400837f0:	d37ff800 	lsl	x0, x0, #1
ffff0000400837f4:	8b010000 	add	x0, x0, x1
ffff0000400837f8:	d37df000 	lsl	x0, x0, #3
ffff0000400837fc:	8b000040 	add	x0, x2, x0
ffff000040083800:	f9400401 	ldr	x1, [x0, #8]
ffff000040083804:	b94017e0 	ldr	w0, [sp, #20]
ffff000040083808:	2a0003e0 	mov	w0, w0
ffff00004008380c:	927e7400 	and	x0, x0, #0xfffffffc
ffff000040083810:	8b000020 	add	x0, x1, x0
ffff000040083814:	91100000 	add	x0, x0, #0x400
ffff000040083818:	f94017e1 	ldr	x1, [sp, #40]
ffff00004008381c:	b9000001 	str	w1, [x0]
}
ffff000040083820:	d503201f 	nop
ffff000040083824:	9100c3ff 	add	sp, sp, #0x30
ffff000040083828:	d65f03c0 	ret

ffff00004008382c <arm_gic_get_priority>:

rt_uint64_t arm_gic_get_priority(rt_uint64_t index, int irq)
{
ffff00004008382c:	d10043ff 	sub	sp, sp, #0x10
ffff000040083830:	f90007e0 	str	x0, [sp, #8]
ffff000040083834:	b90007e1 	str	w1, [sp, #4]
    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = irq - _gic_table[index].offset;
ffff000040083838:	b94007e2 	ldr	w2, [sp, #4]
ffff00004008383c:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083840:	912da003 	add	x3, x0, #0xb68
ffff000040083844:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083848:	aa0103e0 	mov	x0, x1
ffff00004008384c:	d37ff800 	lsl	x0, x0, #1
ffff000040083850:	8b010000 	add	x0, x0, x1
ffff000040083854:	d37df000 	lsl	x0, x0, #3
ffff000040083858:	8b000060 	add	x0, x3, x0
ffff00004008385c:	f9400000 	ldr	x0, [x0]
ffff000040083860:	4b000040 	sub	w0, w2, w0
ffff000040083864:	b90007e0 	str	w0, [sp, #4]
    RT_ASSERT(irq >= 0U);

    return (GIC_DIST_PRI(_gic_table[index].dist_hw_base, irq) >> ((irq % 4U) * 8U)) & 0xFFUL;
ffff000040083868:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff00004008386c:	912da002 	add	x2, x0, #0xb68
ffff000040083870:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083874:	aa0103e0 	mov	x0, x1
ffff000040083878:	d37ff800 	lsl	x0, x0, #1
ffff00004008387c:	8b010000 	add	x0, x0, x1
ffff000040083880:	d37df000 	lsl	x0, x0, #3
ffff000040083884:	8b000040 	add	x0, x2, x0
ffff000040083888:	f9400401 	ldr	x1, [x0, #8]
ffff00004008388c:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083890:	2a0003e0 	mov	w0, w0
ffff000040083894:	927e7400 	and	x0, x0, #0xfffffffc
ffff000040083898:	8b000020 	add	x0, x1, x0
ffff00004008389c:	91100000 	add	x0, x0, #0x400
ffff0000400838a0:	b9400001 	ldr	w1, [x0]
ffff0000400838a4:	b94007e0 	ldr	w0, [sp, #4]
ffff0000400838a8:	12000400 	and	w0, w0, #0x3
ffff0000400838ac:	531d7000 	lsl	w0, w0, #3
ffff0000400838b0:	1ac02420 	lsr	w0, w1, w0
ffff0000400838b4:	2a0003e0 	mov	w0, w0
ffff0000400838b8:	92401c00 	and	x0, x0, #0xff
}
ffff0000400838bc:	910043ff 	add	sp, sp, #0x10
ffff0000400838c0:	d65f03c0 	ret

ffff0000400838c4 <arm_gic_set_interface_prior_mask>:

void arm_gic_set_interface_prior_mask(rt_uint64_t index, rt_uint64_t priority)
{
ffff0000400838c4:	d10043ff 	sub	sp, sp, #0x10
ffff0000400838c8:	f90007e0 	str	x0, [sp, #8]
ffff0000400838cc:	f90003e1 	str	x1, [sp]
    RT_ASSERT(index < ARM_GIC_MAX_NR);

    /* set priority mask */
    GIC_CPU_PRIMASK(_gic_table[index].cpu_hw_base) = priority & 0xFFUL;
ffff0000400838d0:	f94003e0 	ldr	x0, [sp]
ffff0000400838d4:	2a0003e3 	mov	w3, w0
ffff0000400838d8:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400838dc:	912da002 	add	x2, x0, #0xb68
ffff0000400838e0:	f94007e1 	ldr	x1, [sp, #8]
ffff0000400838e4:	aa0103e0 	mov	x0, x1
ffff0000400838e8:	d37ff800 	lsl	x0, x0, #1
ffff0000400838ec:	8b010000 	add	x0, x0, x1
ffff0000400838f0:	d37df000 	lsl	x0, x0, #3
ffff0000400838f4:	8b000040 	add	x0, x2, x0
ffff0000400838f8:	f9400800 	ldr	x0, [x0, #16]
ffff0000400838fc:	91001000 	add	x0, x0, #0x4
ffff000040083900:	aa0003e1 	mov	x1, x0
ffff000040083904:	12001c60 	and	w0, w3, #0xff
ffff000040083908:	b9000020 	str	w0, [x1]
}
ffff00004008390c:	d503201f 	nop
ffff000040083910:	910043ff 	add	sp, sp, #0x10
ffff000040083914:	d65f03c0 	ret

ffff000040083918 <arm_gic_get_interface_prior_mask>:

rt_uint64_t arm_gic_get_interface_prior_mask(rt_uint64_t index)
{
ffff000040083918:	d10043ff 	sub	sp, sp, #0x10
ffff00004008391c:	f90007e0 	str	x0, [sp, #8]
    RT_ASSERT(index < ARM_GIC_MAX_NR);

    return GIC_CPU_PRIMASK(_gic_table[index].cpu_hw_base);
ffff000040083920:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083924:	912da002 	add	x2, x0, #0xb68
ffff000040083928:	f94007e1 	ldr	x1, [sp, #8]
ffff00004008392c:	aa0103e0 	mov	x0, x1
ffff000040083930:	d37ff800 	lsl	x0, x0, #1
ffff000040083934:	8b010000 	add	x0, x0, x1
ffff000040083938:	d37df000 	lsl	x0, x0, #3
ffff00004008393c:	8b000040 	add	x0, x2, x0
ffff000040083940:	f9400800 	ldr	x0, [x0, #16]
ffff000040083944:	91001000 	add	x0, x0, #0x4
ffff000040083948:	b9400000 	ldr	w0, [x0]
ffff00004008394c:	2a0003e0 	mov	w0, w0
}
ffff000040083950:	910043ff 	add	sp, sp, #0x10
ffff000040083954:	d65f03c0 	ret

ffff000040083958 <arm_gic_set_binary_point>:

void arm_gic_set_binary_point(rt_uint64_t index, rt_uint64_t binary_point)
{
ffff000040083958:	d10043ff 	sub	sp, sp, #0x10
ffff00004008395c:	f90007e0 	str	x0, [sp, #8]
ffff000040083960:	f90003e1 	str	x1, [sp]
    GIC_CPU_BINPOINT(_gic_table[index].cpu_hw_base) = binary_point & 0x7U;
ffff000040083964:	f94003e0 	ldr	x0, [sp]
ffff000040083968:	2a0003e3 	mov	w3, w0
ffff00004008396c:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083970:	912da002 	add	x2, x0, #0xb68
ffff000040083974:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083978:	aa0103e0 	mov	x0, x1
ffff00004008397c:	d37ff800 	lsl	x0, x0, #1
ffff000040083980:	8b010000 	add	x0, x0, x1
ffff000040083984:	d37df000 	lsl	x0, x0, #3
ffff000040083988:	8b000040 	add	x0, x2, x0
ffff00004008398c:	f9400800 	ldr	x0, [x0, #16]
ffff000040083990:	91002000 	add	x0, x0, #0x8
ffff000040083994:	aa0003e1 	mov	x1, x0
ffff000040083998:	12000860 	and	w0, w3, #0x7
ffff00004008399c:	b9000020 	str	w0, [x1]
}
ffff0000400839a0:	d503201f 	nop
ffff0000400839a4:	910043ff 	add	sp, sp, #0x10
ffff0000400839a8:	d65f03c0 	ret

ffff0000400839ac <arm_gic_get_binary_point>:

rt_uint64_t arm_gic_get_binary_point(rt_uint64_t index)
{
ffff0000400839ac:	d10043ff 	sub	sp, sp, #0x10
ffff0000400839b0:	f90007e0 	str	x0, [sp, #8]
    return GIC_CPU_BINPOINT(_gic_table[index].cpu_hw_base);
ffff0000400839b4:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400839b8:	912da002 	add	x2, x0, #0xb68
ffff0000400839bc:	f94007e1 	ldr	x1, [sp, #8]
ffff0000400839c0:	aa0103e0 	mov	x0, x1
ffff0000400839c4:	d37ff800 	lsl	x0, x0, #1
ffff0000400839c8:	8b010000 	add	x0, x0, x1
ffff0000400839cc:	d37df000 	lsl	x0, x0, #3
ffff0000400839d0:	8b000040 	add	x0, x2, x0
ffff0000400839d4:	f9400800 	ldr	x0, [x0, #16]
ffff0000400839d8:	91002000 	add	x0, x0, #0x8
ffff0000400839dc:	b9400000 	ldr	w0, [x0]
ffff0000400839e0:	2a0003e0 	mov	w0, w0
}
ffff0000400839e4:	910043ff 	add	sp, sp, #0x10
ffff0000400839e8:	d65f03c0 	ret

ffff0000400839ec <arm_gic_get_irq_status>:

rt_uint64_t arm_gic_get_irq_status(rt_uint64_t index, int irq)
{
ffff0000400839ec:	d10083ff 	sub	sp, sp, #0x20
ffff0000400839f0:	f90007e0 	str	x0, [sp, #8]
ffff0000400839f4:	b90007e1 	str	w1, [sp, #4]
    rt_uint64_t pending;
    rt_uint64_t active;

    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = irq - _gic_table[index].offset;
ffff0000400839f8:	b94007e2 	ldr	w2, [sp, #4]
ffff0000400839fc:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083a00:	912da003 	add	x3, x0, #0xb68
ffff000040083a04:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083a08:	aa0103e0 	mov	x0, x1
ffff000040083a0c:	d37ff800 	lsl	x0, x0, #1
ffff000040083a10:	8b010000 	add	x0, x0, x1
ffff000040083a14:	d37df000 	lsl	x0, x0, #3
ffff000040083a18:	8b000060 	add	x0, x3, x0
ffff000040083a1c:	f9400000 	ldr	x0, [x0]
ffff000040083a20:	4b000040 	sub	w0, w2, w0
ffff000040083a24:	b90007e0 	str	w0, [sp, #4]
    RT_ASSERT(irq >= 0U);

    active = (GIC_DIST_ACTIVE_SET(_gic_table[index].dist_hw_base, irq) >> (irq % 32U)) & 0x1UL;
ffff000040083a28:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083a2c:	912da002 	add	x2, x0, #0xb68
ffff000040083a30:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083a34:	aa0103e0 	mov	x0, x1
ffff000040083a38:	d37ff800 	lsl	x0, x0, #1
ffff000040083a3c:	8b010000 	add	x0, x0, x1
ffff000040083a40:	d37df000 	lsl	x0, x0, #3
ffff000040083a44:	8b000040 	add	x0, x2, x0
ffff000040083a48:	f9400401 	ldr	x1, [x0, #8]
ffff000040083a4c:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083a50:	53057c00 	lsr	w0, w0, #5
ffff000040083a54:	531e7400 	lsl	w0, w0, #2
ffff000040083a58:	2a0003e0 	mov	w0, w0
ffff000040083a5c:	8b000020 	add	x0, x1, x0
ffff000040083a60:	910c0000 	add	x0, x0, #0x300
ffff000040083a64:	b9400001 	ldr	w1, [x0]
ffff000040083a68:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083a6c:	12001000 	and	w0, w0, #0x1f
ffff000040083a70:	1ac02420 	lsr	w0, w1, w0
ffff000040083a74:	2a0003e0 	mov	w0, w0
ffff000040083a78:	92400000 	and	x0, x0, #0x1
ffff000040083a7c:	f9000fe0 	str	x0, [sp, #24]
    pending = (GIC_DIST_PENDING_SET(_gic_table[index].dist_hw_base, irq) >> (irq % 32U)) & 0x1UL;
ffff000040083a80:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083a84:	912da002 	add	x2, x0, #0xb68
ffff000040083a88:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083a8c:	aa0103e0 	mov	x0, x1
ffff000040083a90:	d37ff800 	lsl	x0, x0, #1
ffff000040083a94:	8b010000 	add	x0, x0, x1
ffff000040083a98:	d37df000 	lsl	x0, x0, #3
ffff000040083a9c:	8b000040 	add	x0, x2, x0
ffff000040083aa0:	f9400401 	ldr	x1, [x0, #8]
ffff000040083aa4:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083aa8:	53057c00 	lsr	w0, w0, #5
ffff000040083aac:	531e7400 	lsl	w0, w0, #2
ffff000040083ab0:	2a0003e0 	mov	w0, w0
ffff000040083ab4:	8b000020 	add	x0, x1, x0
ffff000040083ab8:	91080000 	add	x0, x0, #0x200
ffff000040083abc:	b9400001 	ldr	w1, [x0]
ffff000040083ac0:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083ac4:	12001000 	and	w0, w0, #0x1f
ffff000040083ac8:	1ac02420 	lsr	w0, w1, w0
ffff000040083acc:	2a0003e0 	mov	w0, w0
ffff000040083ad0:	92400000 	and	x0, x0, #0x1
ffff000040083ad4:	f9000be0 	str	x0, [sp, #16]

    return ((active << 1U) | pending);
ffff000040083ad8:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040083adc:	d37ff801 	lsl	x1, x0, #1
ffff000040083ae0:	f9400be0 	ldr	x0, [sp, #16]
ffff000040083ae4:	aa000020 	orr	x0, x1, x0
}
ffff000040083ae8:	910083ff 	add	sp, sp, #0x20
ffff000040083aec:	d65f03c0 	ret

ffff000040083af0 <arm_gic_send_sgi>:

void arm_gic_send_sgi(rt_uint64_t index, int irq, rt_uint64_t target_list, rt_uint64_t filter_list)
{
ffff000040083af0:	d10083ff 	sub	sp, sp, #0x20
ffff000040083af4:	f9000fe0 	str	x0, [sp, #24]
ffff000040083af8:	b90017e1 	str	w1, [sp, #20]
ffff000040083afc:	f90007e2 	str	x2, [sp, #8]
ffff000040083b00:	f90003e3 	str	x3, [sp]
    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = irq - _gic_table[index].offset;
ffff000040083b04:	b94017e2 	ldr	w2, [sp, #20]
ffff000040083b08:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083b0c:	912da003 	add	x3, x0, #0xb68
ffff000040083b10:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040083b14:	aa0103e0 	mov	x0, x1
ffff000040083b18:	d37ff800 	lsl	x0, x0, #1
ffff000040083b1c:	8b010000 	add	x0, x0, x1
ffff000040083b20:	d37df000 	lsl	x0, x0, #3
ffff000040083b24:	8b000060 	add	x0, x3, x0
ffff000040083b28:	f9400000 	ldr	x0, [x0]
ffff000040083b2c:	4b000040 	sub	w0, w2, w0
ffff000040083b30:	b90017e0 	str	w0, [sp, #20]
    RT_ASSERT(irq >= 0U);

    GIC_DIST_SOFTINT(_gic_table[index].dist_hw_base) =
        ((filter_list & 0x3U) << 24U) | ((target_list & 0xFFUL) << 16U) | (irq & 0x0FUL);
ffff000040083b34:	f94003e0 	ldr	x0, [sp]
ffff000040083b38:	53081c00 	lsl	w0, w0, #24
ffff000040083b3c:	12080401 	and	w1, w0, #0x3000000
ffff000040083b40:	f94007e0 	ldr	x0, [sp, #8]
ffff000040083b44:	53103c00 	lsl	w0, w0, #16
ffff000040083b48:	12101c00 	and	w0, w0, #0xff0000
ffff000040083b4c:	2a000023 	orr	w3, w1, w0
ffff000040083b50:	b94017e0 	ldr	w0, [sp, #20]
ffff000040083b54:	12000c02 	and	w2, w0, #0xf
    GIC_DIST_SOFTINT(_gic_table[index].dist_hw_base) =
ffff000040083b58:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083b5c:	912da004 	add	x4, x0, #0xb68
ffff000040083b60:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040083b64:	aa0103e0 	mov	x0, x1
ffff000040083b68:	d37ff800 	lsl	x0, x0, #1
ffff000040083b6c:	8b010000 	add	x0, x0, x1
ffff000040083b70:	d37df000 	lsl	x0, x0, #3
ffff000040083b74:	8b000080 	add	x0, x4, x0
ffff000040083b78:	f9400400 	ldr	x0, [x0, #8]
ffff000040083b7c:	913c0000 	add	x0, x0, #0xf00
ffff000040083b80:	aa0003e1 	mov	x1, x0
        ((filter_list & 0x3U) << 24U) | ((target_list & 0xFFUL) << 16U) | (irq & 0x0FUL);
ffff000040083b84:	2a020060 	orr	w0, w3, w2
    GIC_DIST_SOFTINT(_gic_table[index].dist_hw_base) =
ffff000040083b88:	b9000020 	str	w0, [x1]
}
ffff000040083b8c:	d503201f 	nop
ffff000040083b90:	910083ff 	add	sp, sp, #0x20
ffff000040083b94:	d65f03c0 	ret

ffff000040083b98 <arm_gic_get_high_pending_irq>:

rt_uint64_t arm_gic_get_high_pending_irq(rt_uint64_t index)
{
ffff000040083b98:	d10043ff 	sub	sp, sp, #0x10
ffff000040083b9c:	f90007e0 	str	x0, [sp, #8]
    RT_ASSERT(index < ARM_GIC_MAX_NR);

    return GIC_CPU_HIGHPRI(_gic_table[index].cpu_hw_base);
ffff000040083ba0:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083ba4:	912da002 	add	x2, x0, #0xb68
ffff000040083ba8:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083bac:	aa0103e0 	mov	x0, x1
ffff000040083bb0:	d37ff800 	lsl	x0, x0, #1
ffff000040083bb4:	8b010000 	add	x0, x0, x1
ffff000040083bb8:	d37df000 	lsl	x0, x0, #3
ffff000040083bbc:	8b000040 	add	x0, x2, x0
ffff000040083bc0:	f9400800 	ldr	x0, [x0, #16]
ffff000040083bc4:	91006000 	add	x0, x0, #0x18
ffff000040083bc8:	b9400000 	ldr	w0, [x0]
ffff000040083bcc:	2a0003e0 	mov	w0, w0
}
ffff000040083bd0:	910043ff 	add	sp, sp, #0x10
ffff000040083bd4:	d65f03c0 	ret

ffff000040083bd8 <arm_gic_get_interface_id>:

rt_uint64_t arm_gic_get_interface_id(rt_uint64_t index)
{
ffff000040083bd8:	d10043ff 	sub	sp, sp, #0x10
ffff000040083bdc:	f90007e0 	str	x0, [sp, #8]
    RT_ASSERT(index < ARM_GIC_MAX_NR);

    return GIC_CPU_IIDR(_gic_table[index].cpu_hw_base);
ffff000040083be0:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083be4:	912da002 	add	x2, x0, #0xb68
ffff000040083be8:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083bec:	aa0103e0 	mov	x0, x1
ffff000040083bf0:	d37ff800 	lsl	x0, x0, #1
ffff000040083bf4:	8b010000 	add	x0, x0, x1
ffff000040083bf8:	d37df000 	lsl	x0, x0, #3
ffff000040083bfc:	8b000040 	add	x0, x2, x0
ffff000040083c00:	f9400800 	ldr	x0, [x0, #16]
ffff000040083c04:	9103f000 	add	x0, x0, #0xfc
ffff000040083c08:	b9400000 	ldr	w0, [x0]
ffff000040083c0c:	2a0003e0 	mov	w0, w0
}
ffff000040083c10:	910043ff 	add	sp, sp, #0x10
ffff000040083c14:	d65f03c0 	ret

ffff000040083c18 <arm_gic_set_group>:

void arm_gic_set_group(rt_uint64_t index, int irq, rt_uint64_t group)
{
ffff000040083c18:	d100c3ff 	sub	sp, sp, #0x30
ffff000040083c1c:	f9000fe0 	str	x0, [sp, #24]
ffff000040083c20:	b90017e1 	str	w1, [sp, #20]
ffff000040083c24:	f90007e2 	str	x2, [sp, #8]
    uint32_t shift;

    RT_ASSERT(index < ARM_GIC_MAX_NR);
    RT_ASSERT(group <= 1U);

    irq = irq - _gic_table[index].offset;
ffff000040083c28:	b94017e2 	ldr	w2, [sp, #20]
ffff000040083c2c:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083c30:	912da003 	add	x3, x0, #0xb68
ffff000040083c34:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040083c38:	aa0103e0 	mov	x0, x1
ffff000040083c3c:	d37ff800 	lsl	x0, x0, #1
ffff000040083c40:	8b010000 	add	x0, x0, x1
ffff000040083c44:	d37df000 	lsl	x0, x0, #3
ffff000040083c48:	8b000060 	add	x0, x3, x0
ffff000040083c4c:	f9400000 	ldr	x0, [x0]
ffff000040083c50:	4b000040 	sub	w0, w2, w0
ffff000040083c54:	b90017e0 	str	w0, [sp, #20]
    RT_ASSERT(irq >= 0U);

    igroupr = GIC_DIST_IGROUP(_gic_table[index].dist_hw_base, irq);
ffff000040083c58:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083c5c:	912da002 	add	x2, x0, #0xb68
ffff000040083c60:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040083c64:	aa0103e0 	mov	x0, x1
ffff000040083c68:	d37ff800 	lsl	x0, x0, #1
ffff000040083c6c:	8b010000 	add	x0, x0, x1
ffff000040083c70:	d37df000 	lsl	x0, x0, #3
ffff000040083c74:	8b000040 	add	x0, x2, x0
ffff000040083c78:	f9400401 	ldr	x1, [x0, #8]
ffff000040083c7c:	b94017e0 	ldr	w0, [sp, #20]
ffff000040083c80:	53057c00 	lsr	w0, w0, #5
ffff000040083c84:	531e7400 	lsl	w0, w0, #2
ffff000040083c88:	2a0003e0 	mov	w0, w0
ffff000040083c8c:	8b000020 	add	x0, x1, x0
ffff000040083c90:	91020000 	add	x0, x0, #0x80
ffff000040083c94:	b9400000 	ldr	w0, [x0]
ffff000040083c98:	b9002fe0 	str	w0, [sp, #44]
    shift = (irq % 32U);
ffff000040083c9c:	b94017e0 	ldr	w0, [sp, #20]
ffff000040083ca0:	12001000 	and	w0, w0, #0x1f
ffff000040083ca4:	b9002be0 	str	w0, [sp, #40]
    igroupr &= (~(1U << shift));
ffff000040083ca8:	b9402be0 	ldr	w0, [sp, #40]
ffff000040083cac:	52800021 	mov	w1, #0x1                   	// #1
ffff000040083cb0:	1ac02020 	lsl	w0, w1, w0
ffff000040083cb4:	2a2003e0 	mvn	w0, w0
ffff000040083cb8:	b9402fe1 	ldr	w1, [sp, #44]
ffff000040083cbc:	0a000020 	and	w0, w1, w0
ffff000040083cc0:	b9002fe0 	str	w0, [sp, #44]
    igroupr |= ((group & 0x1U) << shift);
ffff000040083cc4:	f94007e0 	ldr	x0, [sp, #8]
ffff000040083cc8:	92400001 	and	x1, x0, #0x1
ffff000040083ccc:	b9402be0 	ldr	w0, [sp, #40]
ffff000040083cd0:	9ac02020 	lsl	x0, x1, x0
ffff000040083cd4:	2a0003e1 	mov	w1, w0
ffff000040083cd8:	b9402fe0 	ldr	w0, [sp, #44]
ffff000040083cdc:	2a010000 	orr	w0, w0, w1
ffff000040083ce0:	b9002fe0 	str	w0, [sp, #44]

    GIC_DIST_IGROUP(_gic_table[index].dist_hw_base, irq) = igroupr;
ffff000040083ce4:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083ce8:	912da002 	add	x2, x0, #0xb68
ffff000040083cec:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040083cf0:	aa0103e0 	mov	x0, x1
ffff000040083cf4:	d37ff800 	lsl	x0, x0, #1
ffff000040083cf8:	8b010000 	add	x0, x0, x1
ffff000040083cfc:	d37df000 	lsl	x0, x0, #3
ffff000040083d00:	8b000040 	add	x0, x2, x0
ffff000040083d04:	f9400401 	ldr	x1, [x0, #8]
ffff000040083d08:	b94017e0 	ldr	w0, [sp, #20]
ffff000040083d0c:	53057c00 	lsr	w0, w0, #5
ffff000040083d10:	531e7400 	lsl	w0, w0, #2
ffff000040083d14:	2a0003e0 	mov	w0, w0
ffff000040083d18:	8b000020 	add	x0, x1, x0
ffff000040083d1c:	91020000 	add	x0, x0, #0x80
ffff000040083d20:	aa0003e1 	mov	x1, x0
ffff000040083d24:	b9402fe0 	ldr	w0, [sp, #44]
ffff000040083d28:	b9000020 	str	w0, [x1]
}
ffff000040083d2c:	d503201f 	nop
ffff000040083d30:	9100c3ff 	add	sp, sp, #0x30
ffff000040083d34:	d65f03c0 	ret

ffff000040083d38 <arm_gic_get_group>:

rt_uint64_t arm_gic_get_group(rt_uint64_t index, int irq)
{
ffff000040083d38:	d10043ff 	sub	sp, sp, #0x10
ffff000040083d3c:	f90007e0 	str	x0, [sp, #8]
ffff000040083d40:	b90007e1 	str	w1, [sp, #4]
    RT_ASSERT(index < ARM_GIC_MAX_NR);

    irq = irq - _gic_table[index].offset;
ffff000040083d44:	b94007e2 	ldr	w2, [sp, #4]
ffff000040083d48:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083d4c:	912da003 	add	x3, x0, #0xb68
ffff000040083d50:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083d54:	aa0103e0 	mov	x0, x1
ffff000040083d58:	d37ff800 	lsl	x0, x0, #1
ffff000040083d5c:	8b010000 	add	x0, x0, x1
ffff000040083d60:	d37df000 	lsl	x0, x0, #3
ffff000040083d64:	8b000060 	add	x0, x3, x0
ffff000040083d68:	f9400000 	ldr	x0, [x0]
ffff000040083d6c:	4b000040 	sub	w0, w2, w0
ffff000040083d70:	b90007e0 	str	w0, [sp, #4]
    RT_ASSERT(irq >= 0U);

    return (GIC_DIST_IGROUP(_gic_table[index].dist_hw_base, irq) >> (irq % 32U)) & 0x1UL;
ffff000040083d74:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083d78:	912da002 	add	x2, x0, #0xb68
ffff000040083d7c:	f94007e1 	ldr	x1, [sp, #8]
ffff000040083d80:	aa0103e0 	mov	x0, x1
ffff000040083d84:	d37ff800 	lsl	x0, x0, #1
ffff000040083d88:	8b010000 	add	x0, x0, x1
ffff000040083d8c:	d37df000 	lsl	x0, x0, #3
ffff000040083d90:	8b000040 	add	x0, x2, x0
ffff000040083d94:	f9400401 	ldr	x1, [x0, #8]
ffff000040083d98:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083d9c:	53057c00 	lsr	w0, w0, #5
ffff000040083da0:	531e7400 	lsl	w0, w0, #2
ffff000040083da4:	2a0003e0 	mov	w0, w0
ffff000040083da8:	8b000020 	add	x0, x1, x0
ffff000040083dac:	91020000 	add	x0, x0, #0x80
ffff000040083db0:	b9400001 	ldr	w1, [x0]
ffff000040083db4:	b94007e0 	ldr	w0, [sp, #4]
ffff000040083db8:	12001000 	and	w0, w0, #0x1f
ffff000040083dbc:	1ac02420 	lsr	w0, w1, w0
ffff000040083dc0:	2a0003e0 	mov	w0, w0
ffff000040083dc4:	92400000 	and	x0, x0, #0x1
}
ffff000040083dc8:	910043ff 	add	sp, sp, #0x10
ffff000040083dcc:	d65f03c0 	ret

ffff000040083dd0 <arm_gic_dist_init>:

int arm_gic_dist_init(rt_uint64_t index, rt_uint64_t dist_base, int irq_start)
{
ffff000040083dd0:	d10103ff 	sub	sp, sp, #0x40
ffff000040083dd4:	f9000fe0 	str	x0, [sp, #24]
ffff000040083dd8:	f9000be1 	str	x1, [sp, #16]
ffff000040083ddc:	b9000fe2 	str	w2, [sp, #12]
    unsigned int gic_type, i;
    rt_uint64_t cpumask = 1U << 0U;
ffff000040083de0:	d2800020 	mov	x0, #0x1                   	// #1
ffff000040083de4:	f9001be0 	str	x0, [sp, #48]

    RT_ASSERT(index < ARM_GIC_MAX_NR);

    _gic_table[index].dist_hw_base = dist_base;
ffff000040083de8:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083dec:	912da002 	add	x2, x0, #0xb68
ffff000040083df0:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040083df4:	aa0103e0 	mov	x0, x1
ffff000040083df8:	d37ff800 	lsl	x0, x0, #1
ffff000040083dfc:	8b010000 	add	x0, x0, x1
ffff000040083e00:	d37df000 	lsl	x0, x0, #3
ffff000040083e04:	8b000040 	add	x0, x2, x0
ffff000040083e08:	f9400be1 	ldr	x1, [sp, #16]
ffff000040083e0c:	f9000401 	str	x1, [x0, #8]
    _gic_table[index].offset = irq_start;
ffff000040083e10:	b9800fe2 	ldrsw	x2, [sp, #12]
ffff000040083e14:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083e18:	912da003 	add	x3, x0, #0xb68
ffff000040083e1c:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040083e20:	aa0103e0 	mov	x0, x1
ffff000040083e24:	d37ff800 	lsl	x0, x0, #1
ffff000040083e28:	8b010000 	add	x0, x0, x1
ffff000040083e2c:	d37df000 	lsl	x0, x0, #3
ffff000040083e30:	8b000060 	add	x0, x3, x0
ffff000040083e34:	f9000002 	str	x2, [x0]

    /* Find out how many interrupts are supported. */
    gic_type = GIC_DIST_TYPE(dist_base);
ffff000040083e38:	f9400be0 	ldr	x0, [sp, #16]
ffff000040083e3c:	91001000 	add	x0, x0, #0x4
ffff000040083e40:	b9400000 	ldr	w0, [x0]
ffff000040083e44:	b9002fe0 	str	w0, [sp, #44]
    _gic_max_irq = ((gic_type & 0x1fU) + 1U) * 32U;
ffff000040083e48:	b9402fe0 	ldr	w0, [sp, #44]
ffff000040083e4c:	12001000 	and	w0, w0, #0x1f
ffff000040083e50:	11000400 	add	w0, w0, #0x1
ffff000040083e54:	531b6801 	lsl	w1, w0, #5
ffff000040083e58:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083e5c:	9130a000 	add	x0, x0, #0xc28
ffff000040083e60:	b9000001 	str	w1, [x0]
    /*
     * The GIC only supports up to 1020 interrupt sources.
     * Limit this to either the architected maximum, or the
     * platform maximum.
     */
    if (_gic_max_irq > 1020U)
ffff000040083e64:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083e68:	9130a000 	add	x0, x0, #0xc28
ffff000040083e6c:	b9400000 	ldr	w0, [x0]
ffff000040083e70:	710ff01f 	cmp	w0, #0x3fc
ffff000040083e74:	540000a9 	b.ls	ffff000040083e88 <arm_gic_dist_init+0xb8>  // b.plast
    {
        _gic_max_irq = 1020U;
ffff000040083e78:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083e7c:	9130a000 	add	x0, x0, #0xc28
ffff000040083e80:	52807f81 	mov	w1, #0x3fc                 	// #1020
ffff000040083e84:	b9000001 	str	w1, [x0]
    }
    if (_gic_max_irq > ARM_GIC_NR_IRQS) /* the platform maximum interrupts */
ffff000040083e88:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083e8c:	9130a000 	add	x0, x0, #0xc28
ffff000040083e90:	b9400000 	ldr	w0, [x0]
ffff000040083e94:	7102001f 	cmp	w0, #0x80
ffff000040083e98:	540000a9 	b.ls	ffff000040083eac <arm_gic_dist_init+0xdc>  // b.plast
    {
        _gic_max_irq = ARM_GIC_NR_IRQS;
ffff000040083e9c:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083ea0:	9130a000 	add	x0, x0, #0xc28
ffff000040083ea4:	52801001 	mov	w1, #0x80                  	// #128
ffff000040083ea8:	b9000001 	str	w1, [x0]
    }

    cpumask |= cpumask << 8U;
ffff000040083eac:	f9401be0 	ldr	x0, [sp, #48]
ffff000040083eb0:	d378dc00 	lsl	x0, x0, #8
ffff000040083eb4:	f9401be1 	ldr	x1, [sp, #48]
ffff000040083eb8:	aa000020 	orr	x0, x1, x0
ffff000040083ebc:	f9001be0 	str	x0, [sp, #48]
    cpumask |= cpumask << 16U;
ffff000040083ec0:	f9401be0 	ldr	x0, [sp, #48]
ffff000040083ec4:	d370bc00 	lsl	x0, x0, #16
ffff000040083ec8:	f9401be1 	ldr	x1, [sp, #48]
ffff000040083ecc:	aa000020 	orr	x0, x1, x0
ffff000040083ed0:	f9001be0 	str	x0, [sp, #48]
    cpumask |= cpumask << 24U;
ffff000040083ed4:	f9401be0 	ldr	x0, [sp, #48]
ffff000040083ed8:	d3689c00 	lsl	x0, x0, #24
ffff000040083edc:	f9401be1 	ldr	x1, [sp, #48]
ffff000040083ee0:	aa000020 	orr	x0, x1, x0
ffff000040083ee4:	f9001be0 	str	x0, [sp, #48]

    GIC_DIST_CTRL(dist_base) = 0x0U;
ffff000040083ee8:	f9400be0 	ldr	x0, [sp, #16]
ffff000040083eec:	b900001f 	str	wzr, [x0]

    /* Set all global interrupts to be level triggered, active low. */
    for (i = 32U; i < _gic_max_irq; i += 16U)
ffff000040083ef0:	52800400 	mov	w0, #0x20                  	// #32
ffff000040083ef4:	b9003fe0 	str	w0, [sp, #60]
ffff000040083ef8:	1400000c 	b	ffff000040083f28 <arm_gic_dist_init+0x158>
    {
        GIC_DIST_CONFIG(dist_base, i) = 0x0U;
ffff000040083efc:	b9403fe0 	ldr	w0, [sp, #60]
ffff000040083f00:	53047c00 	lsr	w0, w0, #4
ffff000040083f04:	531e7400 	lsl	w0, w0, #2
ffff000040083f08:	2a0003e1 	mov	w1, w0
ffff000040083f0c:	f9400be0 	ldr	x0, [sp, #16]
ffff000040083f10:	8b000020 	add	x0, x1, x0
ffff000040083f14:	91300000 	add	x0, x0, #0xc00
ffff000040083f18:	b900001f 	str	wzr, [x0]
    for (i = 32U; i < _gic_max_irq; i += 16U)
ffff000040083f1c:	b9403fe0 	ldr	w0, [sp, #60]
ffff000040083f20:	11004000 	add	w0, w0, #0x10
ffff000040083f24:	b9003fe0 	str	w0, [sp, #60]
ffff000040083f28:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083f2c:	9130a000 	add	x0, x0, #0xc28
ffff000040083f30:	b9400000 	ldr	w0, [x0]
ffff000040083f34:	b9403fe1 	ldr	w1, [sp, #60]
ffff000040083f38:	6b00003f 	cmp	w1, w0
ffff000040083f3c:	54fffe03 	b.cc	ffff000040083efc <arm_gic_dist_init+0x12c>  // b.lo, b.ul, b.last
    }

    /* Set all global interrupts to this CPU only. */
    for (i = 32U; i < _gic_max_irq; i += 4U)
ffff000040083f40:	52800400 	mov	w0, #0x20                  	// #32
ffff000040083f44:	b9003fe0 	str	w0, [sp, #60]
ffff000040083f48:	1400000b 	b	ffff000040083f74 <arm_gic_dist_init+0x1a4>
    {
        GIC_DIST_TARGET(dist_base, i) = cpumask;
ffff000040083f4c:	b9403fe0 	ldr	w0, [sp, #60]
ffff000040083f50:	927e7401 	and	x1, x0, #0xfffffffc
ffff000040083f54:	f9400be0 	ldr	x0, [sp, #16]
ffff000040083f58:	8b000020 	add	x0, x1, x0
ffff000040083f5c:	91200000 	add	x0, x0, #0x800
ffff000040083f60:	f9401be1 	ldr	x1, [sp, #48]
ffff000040083f64:	b9000001 	str	w1, [x0]
    for (i = 32U; i < _gic_max_irq; i += 4U)
ffff000040083f68:	b9403fe0 	ldr	w0, [sp, #60]
ffff000040083f6c:	11001000 	add	w0, w0, #0x4
ffff000040083f70:	b9003fe0 	str	w0, [sp, #60]
ffff000040083f74:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083f78:	9130a000 	add	x0, x0, #0xc28
ffff000040083f7c:	b9400000 	ldr	w0, [x0]
ffff000040083f80:	b9403fe1 	ldr	w1, [sp, #60]
ffff000040083f84:	6b00003f 	cmp	w1, w0
ffff000040083f88:	54fffe23 	b.cc	ffff000040083f4c <arm_gic_dist_init+0x17c>  // b.lo, b.ul, b.last
    }

    /* Set priority on all interrupts. */
    for (i = 0U; i < _gic_max_irq; i += 4U)
ffff000040083f8c:	b9003fff 	str	wzr, [sp, #60]
ffff000040083f90:	1400000d 	b	ffff000040083fc4 <arm_gic_dist_init+0x1f4>
    {
        GIC_DIST_PRI(dist_base, i) = 0xa0a0a0a0U;
ffff000040083f94:	b9403fe0 	ldr	w0, [sp, #60]
ffff000040083f98:	927e7401 	and	x1, x0, #0xfffffffc
ffff000040083f9c:	f9400be0 	ldr	x0, [sp, #16]
ffff000040083fa0:	8b000020 	add	x0, x1, x0
ffff000040083fa4:	91100000 	add	x0, x0, #0x400
ffff000040083fa8:	aa0003e1 	mov	x1, x0
ffff000040083fac:	52941400 	mov	w0, #0xa0a0                	// #41120
ffff000040083fb0:	72b41400 	movk	w0, #0xa0a0, lsl #16
ffff000040083fb4:	b9000020 	str	w0, [x1]
    for (i = 0U; i < _gic_max_irq; i += 4U)
ffff000040083fb8:	b9403fe0 	ldr	w0, [sp, #60]
ffff000040083fbc:	11001000 	add	w0, w0, #0x4
ffff000040083fc0:	b9003fe0 	str	w0, [sp, #60]
ffff000040083fc4:	d0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040083fc8:	9130a000 	add	x0, x0, #0xc28
ffff000040083fcc:	b9400000 	ldr	w0, [x0]
ffff000040083fd0:	b9403fe1 	ldr	w1, [sp, #60]
ffff000040083fd4:	6b00003f 	cmp	w1, w0
ffff000040083fd8:	54fffde3 	b.cc	ffff000040083f94 <arm_gic_dist_init+0x1c4>  // b.lo, b.ul, b.last
    }

    /* Disable all interrupts. */
    for (i = 0U; i < _gic_max_irq; i += 32U)
ffff000040083fdc:	b9003fff 	str	wzr, [sp, #60]
ffff000040083fe0:	1400000e 	b	ffff000040084018 <arm_gic_dist_init+0x248>
    {
        GIC_DIST_ENABLE_CLEAR(dist_base, i) = 0xffffffffU;
ffff000040083fe4:	b9403fe0 	ldr	w0, [sp, #60]
ffff000040083fe8:	53057c00 	lsr	w0, w0, #5
ffff000040083fec:	531e7400 	lsl	w0, w0, #2
ffff000040083ff0:	2a0003e1 	mov	w1, w0
ffff000040083ff4:	f9400be0 	ldr	x0, [sp, #16]
ffff000040083ff8:	8b000020 	add	x0, x1, x0
ffff000040083ffc:	91060000 	add	x0, x0, #0x180
ffff000040084000:	aa0003e1 	mov	x1, x0
ffff000040084004:	12800000 	mov	w0, #0xffffffff            	// #-1
ffff000040084008:	b9000020 	str	w0, [x1]
    for (i = 0U; i < _gic_max_irq; i += 32U)
ffff00004008400c:	b9403fe0 	ldr	w0, [sp, #60]
ffff000040084010:	11008000 	add	w0, w0, #0x20
ffff000040084014:	b9003fe0 	str	w0, [sp, #60]
ffff000040084018:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff00004008401c:	9130a000 	add	x0, x0, #0xc28
ffff000040084020:	b9400000 	ldr	w0, [x0]
ffff000040084024:	b9403fe1 	ldr	w1, [sp, #60]
ffff000040084028:	6b00003f 	cmp	w1, w0
ffff00004008402c:	54fffdc3 	b.cc	ffff000040083fe4 <arm_gic_dist_init+0x214>  // b.lo, b.ul, b.last
    for (i = 0; i < _gic_max_irq; i += 32)
    {
        GIC_DIST_IGROUP(dist_base, i) = 0xffffffffU;
    }
    */
    for (i = 0U; i < _gic_max_irq; i += 32U)
ffff000040084030:	b9003fff 	str	wzr, [sp, #60]
ffff000040084034:	1400000c 	b	ffff000040084064 <arm_gic_dist_init+0x294>
    {
        GIC_DIST_IGROUP(dist_base, i) = 0U;
ffff000040084038:	b9403fe0 	ldr	w0, [sp, #60]
ffff00004008403c:	53057c00 	lsr	w0, w0, #5
ffff000040084040:	531e7400 	lsl	w0, w0, #2
ffff000040084044:	2a0003e1 	mov	w1, w0
ffff000040084048:	f9400be0 	ldr	x0, [sp, #16]
ffff00004008404c:	8b000020 	add	x0, x1, x0
ffff000040084050:	91020000 	add	x0, x0, #0x80
ffff000040084054:	b900001f 	str	wzr, [x0]
    for (i = 0U; i < _gic_max_irq; i += 32U)
ffff000040084058:	b9403fe0 	ldr	w0, [sp, #60]
ffff00004008405c:	11008000 	add	w0, w0, #0x20
ffff000040084060:	b9003fe0 	str	w0, [sp, #60]
ffff000040084064:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040084068:	9130a000 	add	x0, x0, #0xc28
ffff00004008406c:	b9400000 	ldr	w0, [x0]
ffff000040084070:	b9403fe1 	ldr	w1, [sp, #60]
ffff000040084074:	6b00003f 	cmp	w1, w0
ffff000040084078:	54fffe03 	b.cc	ffff000040084038 <arm_gic_dist_init+0x268>  // b.lo, b.ul, b.last
    }

    /* Enable group0 and group1 interrupt forwarding. */
    GIC_DIST_CTRL(dist_base) = 0x01U;
ffff00004008407c:	f9400be0 	ldr	x0, [sp, #16]
ffff000040084080:	52800021 	mov	w1, #0x1                   	// #1
ffff000040084084:	b9000001 	str	w1, [x0]

    return 0;
ffff000040084088:	52800000 	mov	w0, #0x0                   	// #0
}
ffff00004008408c:	910103ff 	add	sp, sp, #0x40
ffff000040084090:	d65f03c0 	ret

ffff000040084094 <arm_gic_cpu_init>:

int arm_gic_cpu_init(rt_uint64_t index, rt_uint64_t cpu_base)
{
ffff000040084094:	d10043ff 	sub	sp, sp, #0x10
ffff000040084098:	f90007e0 	str	x0, [sp, #8]
ffff00004008409c:	f90003e1 	str	x1, [sp]
    RT_ASSERT(index < ARM_GIC_MAX_NR);

    if (!_gic_table[index].cpu_hw_base)
ffff0000400840a0:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400840a4:	912da002 	add	x2, x0, #0xb68
ffff0000400840a8:	f94007e1 	ldr	x1, [sp, #8]
ffff0000400840ac:	aa0103e0 	mov	x0, x1
ffff0000400840b0:	d37ff800 	lsl	x0, x0, #1
ffff0000400840b4:	8b010000 	add	x0, x0, x1
ffff0000400840b8:	d37df000 	lsl	x0, x0, #3
ffff0000400840bc:	8b000040 	add	x0, x2, x0
ffff0000400840c0:	f9400800 	ldr	x0, [x0, #16]
ffff0000400840c4:	f100001f 	cmp	x0, #0x0
ffff0000400840c8:	54000161 	b.ne	ffff0000400840f4 <arm_gic_cpu_init+0x60>  // b.any
    {
        _gic_table[index].cpu_hw_base = cpu_base;
ffff0000400840cc:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400840d0:	912da002 	add	x2, x0, #0xb68
ffff0000400840d4:	f94007e1 	ldr	x1, [sp, #8]
ffff0000400840d8:	aa0103e0 	mov	x0, x1
ffff0000400840dc:	d37ff800 	lsl	x0, x0, #1
ffff0000400840e0:	8b010000 	add	x0, x0, x1
ffff0000400840e4:	d37df000 	lsl	x0, x0, #3
ffff0000400840e8:	8b000040 	add	x0, x2, x0
ffff0000400840ec:	f94003e1 	ldr	x1, [sp]
ffff0000400840f0:	f9000801 	str	x1, [x0, #16]
    }
    cpu_base = _gic_table[index].cpu_hw_base;
ffff0000400840f4:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400840f8:	912da002 	add	x2, x0, #0xb68
ffff0000400840fc:	f94007e1 	ldr	x1, [sp, #8]
ffff000040084100:	aa0103e0 	mov	x0, x1
ffff000040084104:	d37ff800 	lsl	x0, x0, #1
ffff000040084108:	8b010000 	add	x0, x0, x1
ffff00004008410c:	d37df000 	lsl	x0, x0, #3
ffff000040084110:	8b000040 	add	x0, x2, x0
ffff000040084114:	f9400800 	ldr	x0, [x0, #16]
ffff000040084118:	f90003e0 	str	x0, [sp]

    GIC_CPU_PRIMASK(cpu_base) = 0xf0U;
ffff00004008411c:	f94003e0 	ldr	x0, [sp]
ffff000040084120:	91001000 	add	x0, x0, #0x4
ffff000040084124:	aa0003e1 	mov	x1, x0
ffff000040084128:	52801e00 	mov	w0, #0xf0                  	// #240
ffff00004008412c:	b9000020 	str	w0, [x1]
    GIC_CPU_BINPOINT(cpu_base) = 0x7U;
ffff000040084130:	f94003e0 	ldr	x0, [sp]
ffff000040084134:	91002000 	add	x0, x0, #0x8
ffff000040084138:	aa0003e1 	mov	x1, x0
ffff00004008413c:	528000e0 	mov	w0, #0x7                   	// #7
ffff000040084140:	b9000020 	str	w0, [x1]
    /* Enable CPU interrupt */
    GIC_CPU_CTRL(cpu_base) = 0x01U;
ffff000040084144:	f94003e0 	ldr	x0, [sp]
ffff000040084148:	52800021 	mov	w1, #0x1                   	// #1
ffff00004008414c:	b9000001 	str	w1, [x0]

    return 0;
ffff000040084150:	52800000 	mov	w0, #0x0                   	// #0
}
ffff000040084154:	910043ff 	add	sp, sp, #0x10
ffff000040084158:	d65f03c0 	ret

ffff00004008415c <arm_gic_dump_type>:

void arm_gic_dump_type(rt_uint64_t index)
{
ffff00004008415c:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
ffff000040084160:	910003fd 	mov	x29, sp
ffff000040084164:	f9000fe0 	str	x0, [sp, #24]
    unsigned int gic_type;

    gic_type = GIC_DIST_TYPE(_gic_table[index].dist_hw_base);
ffff000040084168:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff00004008416c:	912da002 	add	x2, x0, #0xb68
ffff000040084170:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040084174:	aa0103e0 	mov	x0, x1
ffff000040084178:	d37ff800 	lsl	x0, x0, #1
ffff00004008417c:	8b010000 	add	x0, x0, x1
ffff000040084180:	d37df000 	lsl	x0, x0, #3
ffff000040084184:	8b000040 	add	x0, x2, x0
ffff000040084188:	f9400400 	ldr	x0, [x0, #8]
ffff00004008418c:	91001000 	add	x0, x0, #0x4
ffff000040084190:	b9400000 	ldr	w0, [x0]
ffff000040084194:	b9002fe0 	str	w0, [sp, #44]
    printf("GICv%d on %08x, max IRQs: %d, %s security extension(%08x)\n",
               (GIC_DIST_ICPIDR2(_gic_table[index].dist_hw_base) >> 4U) & 0xfUL,
ffff000040084198:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff00004008419c:	912da002 	add	x2, x0, #0xb68
ffff0000400841a0:	f9400fe1 	ldr	x1, [sp, #24]
ffff0000400841a4:	aa0103e0 	mov	x0, x1
ffff0000400841a8:	d37ff800 	lsl	x0, x0, #1
ffff0000400841ac:	8b010000 	add	x0, x0, x1
ffff0000400841b0:	d37df000 	lsl	x0, x0, #3
ffff0000400841b4:	8b000040 	add	x0, x2, x0
ffff0000400841b8:	f9400400 	ldr	x0, [x0, #8]
ffff0000400841bc:	913fa000 	add	x0, x0, #0xfe8
ffff0000400841c0:	b9400000 	ldr	w0, [x0]
ffff0000400841c4:	53047c00 	lsr	w0, w0, #4
    printf("GICv%d on %08x, max IRQs: %d, %s security extension(%08x)\n",
ffff0000400841c8:	2a0003e0 	mov	w0, w0
ffff0000400841cc:	92400c06 	and	x6, x0, #0xf
ffff0000400841d0:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400841d4:	912da002 	add	x2, x0, #0xb68
ffff0000400841d8:	f9400fe1 	ldr	x1, [sp, #24]
ffff0000400841dc:	aa0103e0 	mov	x0, x1
ffff0000400841e0:	d37ff800 	lsl	x0, x0, #1
ffff0000400841e4:	8b010000 	add	x0, x0, x1
ffff0000400841e8:	d37df000 	lsl	x0, x0, #3
ffff0000400841ec:	8b000040 	add	x0, x2, x0
ffff0000400841f0:	f9400401 	ldr	x1, [x0, #8]
ffff0000400841f4:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400841f8:	9130a000 	add	x0, x0, #0xc28
ffff0000400841fc:	b9400002 	ldr	w2, [x0]
               _gic_table[index].dist_hw_base,
               _gic_max_irq,
               gic_type & (1U << 10U) ? "has" : "no",
ffff000040084200:	b9402fe0 	ldr	w0, [sp, #44]
ffff000040084204:	12160000 	and	w0, w0, #0x400
    printf("GICv%d on %08x, max IRQs: %d, %s security extension(%08x)\n",
ffff000040084208:	7100001f 	cmp	w0, #0x0
ffff00004008420c:	54000080 	b.eq	ffff00004008421c <arm_gic_dump_type+0xc0>  // b.none
ffff000040084210:	900007e0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff000040084214:	912de000 	add	x0, x0, #0xb78
ffff000040084218:	14000003 	b	ffff000040084224 <arm_gic_dump_type+0xc8>
ffff00004008421c:	900007e0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff000040084220:	912e0000 	add	x0, x0, #0xb80
ffff000040084224:	b9402fe5 	ldr	w5, [sp, #44]
ffff000040084228:	aa0003e4 	mov	x4, x0
ffff00004008422c:	2a0203e3 	mov	w3, w2
ffff000040084230:	aa0103e2 	mov	x2, x1
ffff000040084234:	aa0603e1 	mov	x1, x6
ffff000040084238:	900007e0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff00004008423c:	912e2000 	add	x0, x0, #0xb88
ffff000040084240:	9400031f 	bl	ffff000040084ebc <tfp_printf>
               gic_type);
}
ffff000040084244:	d503201f 	nop
ffff000040084248:	a8c37bfd 	ldp	x29, x30, [sp], #48
ffff00004008424c:	d65f03c0 	ret

ffff000040084250 <arm_gic_dump>:

void arm_gic_dump(rt_uint64_t index)
{
ffff000040084250:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
ffff000040084254:	910003fd 	mov	x29, sp
ffff000040084258:	f9000fe0 	str	x0, [sp, #24]
    unsigned int i, k;

    k = GIC_CPU_HIGHPRI(_gic_table[index].cpu_hw_base);
ffff00004008425c:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040084260:	912da002 	add	x2, x0, #0xb68
ffff000040084264:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040084268:	aa0103e0 	mov	x0, x1
ffff00004008426c:	d37ff800 	lsl	x0, x0, #1
ffff000040084270:	8b010000 	add	x0, x0, x1
ffff000040084274:	d37df000 	lsl	x0, x0, #3
ffff000040084278:	8b000040 	add	x0, x2, x0
ffff00004008427c:	f9400800 	ldr	x0, [x0, #16]
ffff000040084280:	91006000 	add	x0, x0, #0x18
ffff000040084284:	b9400000 	ldr	w0, [x0]
ffff000040084288:	b9002be0 	str	w0, [sp, #40]
    printf("--- high pending priority: %d(%08x)\n", k, k);
ffff00004008428c:	b9402be2 	ldr	w2, [sp, #40]
ffff000040084290:	b9402be1 	ldr	w1, [sp, #40]
ffff000040084294:	900007e0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff000040084298:	912f2000 	add	x0, x0, #0xbc8
ffff00004008429c:	94000308 	bl	ffff000040084ebc <tfp_printf>
    printf("--- hw mask ---\n");
ffff0000400842a0:	900007e0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff0000400842a4:	912fc000 	add	x0, x0, #0xbf0
ffff0000400842a8:	94000305 	bl	ffff000040084ebc <tfp_printf>
    for (i = 0U; i < _gic_max_irq / 32U; i++)
ffff0000400842ac:	b9002fff 	str	wzr, [sp, #44]
ffff0000400842b0:	14000018 	b	ffff000040084310 <arm_gic_dump+0xc0>
    {
        printf("0x%08x, ",
                   GIC_DIST_ENABLE_SET(_gic_table[index].dist_hw_base,
ffff0000400842b4:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400842b8:	912da002 	add	x2, x0, #0xb68
ffff0000400842bc:	f9400fe1 	ldr	x1, [sp, #24]
ffff0000400842c0:	aa0103e0 	mov	x0, x1
ffff0000400842c4:	d37ff800 	lsl	x0, x0, #1
ffff0000400842c8:	8b010000 	add	x0, x0, x1
ffff0000400842cc:	d37df000 	lsl	x0, x0, #3
ffff0000400842d0:	8b000040 	add	x0, x2, x0
ffff0000400842d4:	f9400401 	ldr	x1, [x0, #8]
ffff0000400842d8:	b9402fe0 	ldr	w0, [sp, #44]
ffff0000400842dc:	12006800 	and	w0, w0, #0x7ffffff
ffff0000400842e0:	531e7400 	lsl	w0, w0, #2
ffff0000400842e4:	2a0003e0 	mov	w0, w0
ffff0000400842e8:	8b000020 	add	x0, x1, x0
ffff0000400842ec:	91040000 	add	x0, x0, #0x100
        printf("0x%08x, ",
ffff0000400842f0:	b9400000 	ldr	w0, [x0]
ffff0000400842f4:	2a0003e1 	mov	w1, w0
ffff0000400842f8:	900007e0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff0000400842fc:	91302000 	add	x0, x0, #0xc08
ffff000040084300:	940002ef 	bl	ffff000040084ebc <tfp_printf>
    for (i = 0U; i < _gic_max_irq / 32U; i++)
ffff000040084304:	b9402fe0 	ldr	w0, [sp, #44]
ffff000040084308:	11000400 	add	w0, w0, #0x1
ffff00004008430c:	b9002fe0 	str	w0, [sp, #44]
ffff000040084310:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040084314:	9130a000 	add	x0, x0, #0xc28
ffff000040084318:	b9400000 	ldr	w0, [x0]
ffff00004008431c:	53057c00 	lsr	w0, w0, #5
ffff000040084320:	b9402fe1 	ldr	w1, [sp, #44]
ffff000040084324:	6b00003f 	cmp	w1, w0
ffff000040084328:	54fffc63 	b.cc	ffff0000400842b4 <arm_gic_dump+0x64>  // b.lo, b.ul, b.last
                                       i * 32U));
    }
    printf("\n--- hw pending ---\n");
ffff00004008432c:	900007e0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff000040084330:	91306000 	add	x0, x0, #0xc18
ffff000040084334:	940002e2 	bl	ffff000040084ebc <tfp_printf>
    for (i = 0U; i < _gic_max_irq / 32U; i++)
ffff000040084338:	b9002fff 	str	wzr, [sp, #44]
ffff00004008433c:	14000018 	b	ffff00004008439c <arm_gic_dump+0x14c>
    {
        printf("0x%08x, ",
                   GIC_DIST_PENDING_SET(_gic_table[index].dist_hw_base,
ffff000040084340:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040084344:	912da002 	add	x2, x0, #0xb68
ffff000040084348:	f9400fe1 	ldr	x1, [sp, #24]
ffff00004008434c:	aa0103e0 	mov	x0, x1
ffff000040084350:	d37ff800 	lsl	x0, x0, #1
ffff000040084354:	8b010000 	add	x0, x0, x1
ffff000040084358:	d37df000 	lsl	x0, x0, #3
ffff00004008435c:	8b000040 	add	x0, x2, x0
ffff000040084360:	f9400401 	ldr	x1, [x0, #8]
ffff000040084364:	b9402fe0 	ldr	w0, [sp, #44]
ffff000040084368:	12006800 	and	w0, w0, #0x7ffffff
ffff00004008436c:	531e7400 	lsl	w0, w0, #2
ffff000040084370:	2a0003e0 	mov	w0, w0
ffff000040084374:	8b000020 	add	x0, x1, x0
ffff000040084378:	91080000 	add	x0, x0, #0x200
        printf("0x%08x, ",
ffff00004008437c:	b9400000 	ldr	w0, [x0]
ffff000040084380:	2a0003e1 	mov	w1, w0
ffff000040084384:	900007e0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff000040084388:	91302000 	add	x0, x0, #0xc08
ffff00004008438c:	940002cc 	bl	ffff000040084ebc <tfp_printf>
    for (i = 0U; i < _gic_max_irq / 32U; i++)
ffff000040084390:	b9402fe0 	ldr	w0, [sp, #44]
ffff000040084394:	11000400 	add	w0, w0, #0x1
ffff000040084398:	b9002fe0 	str	w0, [sp, #44]
ffff00004008439c:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400843a0:	9130a000 	add	x0, x0, #0xc28
ffff0000400843a4:	b9400000 	ldr	w0, [x0]
ffff0000400843a8:	53057c00 	lsr	w0, w0, #5
ffff0000400843ac:	b9402fe1 	ldr	w1, [sp, #44]
ffff0000400843b0:	6b00003f 	cmp	w1, w0
ffff0000400843b4:	54fffc63 	b.cc	ffff000040084340 <arm_gic_dump+0xf0>  // b.lo, b.ul, b.last
                                        i * 32U));
    }
    printf("\n--- hw active ---\n");
ffff0000400843b8:	900007e0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff0000400843bc:	9130c000 	add	x0, x0, #0xc30
ffff0000400843c0:	940002bf 	bl	ffff000040084ebc <tfp_printf>
    for (i = 0U; i < _gic_max_irq / 32U; i++)
ffff0000400843c4:	b9002fff 	str	wzr, [sp, #44]
ffff0000400843c8:	14000018 	b	ffff000040084428 <arm_gic_dump+0x1d8>
    {
        printf("0x%08x, ",
                   GIC_DIST_ACTIVE_SET(_gic_table[index].dist_hw_base,
ffff0000400843cc:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff0000400843d0:	912da002 	add	x2, x0, #0xb68
ffff0000400843d4:	f9400fe1 	ldr	x1, [sp, #24]
ffff0000400843d8:	aa0103e0 	mov	x0, x1
ffff0000400843dc:	d37ff800 	lsl	x0, x0, #1
ffff0000400843e0:	8b010000 	add	x0, x0, x1
ffff0000400843e4:	d37df000 	lsl	x0, x0, #3
ffff0000400843e8:	8b000040 	add	x0, x2, x0
ffff0000400843ec:	f9400401 	ldr	x1, [x0, #8]
ffff0000400843f0:	b9402fe0 	ldr	w0, [sp, #44]
ffff0000400843f4:	12006800 	and	w0, w0, #0x7ffffff
ffff0000400843f8:	531e7400 	lsl	w0, w0, #2
ffff0000400843fc:	2a0003e0 	mov	w0, w0
ffff000040084400:	8b000020 	add	x0, x1, x0
ffff000040084404:	910c0000 	add	x0, x0, #0x300
        printf("0x%08x, ",
ffff000040084408:	b9400000 	ldr	w0, [x0]
ffff00004008440c:	2a0003e1 	mov	w1, w0
ffff000040084410:	900007e0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff000040084414:	91302000 	add	x0, x0, #0xc08
ffff000040084418:	940002a9 	bl	ffff000040084ebc <tfp_printf>
    for (i = 0U; i < _gic_max_irq / 32U; i++)
ffff00004008441c:	b9402fe0 	ldr	w0, [sp, #44]
ffff000040084420:	11000400 	add	w0, w0, #0x1
ffff000040084424:	b9002fe0 	str	w0, [sp, #44]
ffff000040084428:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff00004008442c:	9130a000 	add	x0, x0, #0xc28
ffff000040084430:	b9400000 	ldr	w0, [x0]
ffff000040084434:	53057c00 	lsr	w0, w0, #5
ffff000040084438:	b9402fe1 	ldr	w1, [sp, #44]
ffff00004008443c:	6b00003f 	cmp	w1, w0
ffff000040084440:	54fffc63 	b.cc	ffff0000400843cc <arm_gic_dump+0x17c>  // b.lo, b.ul, b.last
                                       i * 32U));
    }
    printf("\n");
ffff000040084444:	900007e0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff000040084448:	91312000 	add	x0, x0, #0xc48
ffff00004008444c:	9400029c 	bl	ffff000040084ebc <tfp_printf>
}
ffff000040084450:	d503201f 	nop
ffff000040084454:	a8c37bfd 	ldp	x29, x30, [sp], #48
ffff000040084458:	d65f03c0 	ret

ffff00004008445c <gic_dump>:

long gic_dump(void)
{
ffff00004008445c:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
ffff000040084460:	910003fd 	mov	x29, sp
    arm_gic_dump_type(0);
ffff000040084464:	d2800000 	mov	x0, #0x0                   	// #0
ffff000040084468:	97ffff3d 	bl	ffff00004008415c <arm_gic_dump_type>
    arm_gic_dump(0);
ffff00004008446c:	d2800000 	mov	x0, #0x0                   	// #0
ffff000040084470:	97ffff78 	bl	ffff000040084250 <arm_gic_dump>

    return 0;
ffff000040084474:	d2800000 	mov	x0, #0x0                   	// #0
ffff000040084478:	a8c17bfd 	ldp	x29, x30, [sp], #16
ffff00004008447c:	d65f03c0 	ret

ffff000040084480 <generic_timer_init>:
/* 	These are for Arm generic timers. 
	They are fully functional on both QEMU and Rpi3.
	Recommended.
*/
void generic_timer_init ( void )
{
ffff000040084480:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
ffff000040084484:	910003fd 	mov	x29, sp
	gen_timer_init();
ffff000040084488:	9400038c 	bl	ffff0000400852b8 <gen_timer_init>
}
ffff00004008448c:	d503201f 	nop
ffff000040084490:	a8c17bfd 	ldp	x29, x30, [sp], #16
ffff000040084494:	d65f03c0 	ret

ffff000040084498 <handle_generic_timer_irq>:

void handle_generic_timer_irq( void ) 
{
ffff000040084498:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
ffff00004008449c:	910003fd 	mov	x29, sp
	// TODO: In order to implement sleep(t), you should calculate @interval based on t, 
	// instead of having a fixed @interval which triggers periodic interrupts
	gen_timer_reset(interval);	
ffff0000400844a0:	b00007e0 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff0000400844a4:	91201000 	add	x0, x0, #0x804
ffff0000400844a8:	b9400000 	ldr	w0, [x0]
ffff0000400844ac:	94000386 	bl	ffff0000400852c4 <gen_timer_reset>
	timer_tick();
ffff0000400844b0:	97fff9e7 	bl	ffff000040082c4c <timer_tick>
}
ffff0000400844b4:	d503201f 	nop
ffff0000400844b8:	a8c17bfd 	ldp	x29, x30, [sp], #16
ffff0000400844bc:	d65f03c0 	ret

ffff0000400844c0 <copy_process>:
#include "sched.h"
#include "utils.h"
#include "entry.h"

int copy_process(unsigned long clone_flags, unsigned long fn, unsigned long arg)
{
ffff0000400844c0:	a9ba7bfd 	stp	x29, x30, [sp, #-96]!
ffff0000400844c4:	910003fd 	mov	x29, sp
ffff0000400844c8:	f90017e0 	str	x0, [sp, #40]
ffff0000400844cc:	f90013e1 	str	x1, [sp, #32]
ffff0000400844d0:	f9000fe2 	str	x2, [sp, #24]
	preempt_disable();
ffff0000400844d4:	97fff959 	bl	ffff000040082a38 <preempt_disable>
	struct task_struct *p;

	unsigned long page = allocate_kernel_page();
ffff0000400844d8:	97fff7d6 	bl	ffff000040082430 <allocate_kernel_page>
ffff0000400844dc:	f9002fe0 	str	x0, [sp, #88]
	p = (struct task_struct *) page;
ffff0000400844e0:	f9402fe0 	ldr	x0, [sp, #88]
ffff0000400844e4:	f9002be0 	str	x0, [sp, #80]
	struct pt_regs *childregs = task_pt_regs(p);
ffff0000400844e8:	f9402be0 	ldr	x0, [sp, #80]
ffff0000400844ec:	94000076 	bl	ffff0000400846c4 <task_pt_regs>
ffff0000400844f0:	f90027e0 	str	x0, [sp, #72]

	if (!p)
ffff0000400844f4:	f9402be0 	ldr	x0, [sp, #80]
ffff0000400844f8:	f100001f 	cmp	x0, #0x0
ffff0000400844fc:	54000061 	b.ne	ffff000040084508 <copy_process+0x48>  // b.any
		return -1;
ffff000040084500:	12800000 	mov	w0, #0xffffffff            	// #-1
ffff000040084504:	14000045 	b	ffff000040084618 <copy_process+0x158>

	if (clone_flags & PF_KTHREAD) { /* create a kernel task */
ffff000040084508:	f94017e0 	ldr	x0, [sp, #40]
ffff00004008450c:	927f0000 	and	x0, x0, #0x2
ffff000040084510:	f100001f 	cmp	x0, #0x0
ffff000040084514:	54000100 	b.eq	ffff000040084534 <copy_process+0x74>  // b.none
		p->cpu_context.x19 = fn;
ffff000040084518:	f9402be0 	ldr	x0, [sp, #80]
ffff00004008451c:	f94013e1 	ldr	x1, [sp, #32]
ffff000040084520:	f9000001 	str	x1, [x0]
		p->cpu_context.x20 = arg;
ffff000040084524:	f9402be0 	ldr	x0, [sp, #80]
ffff000040084528:	f9400fe1 	ldr	x1, [sp, #24]
ffff00004008452c:	f9000401 	str	x1, [x0, #8]
ffff000040084530:	14000012 	b	ffff000040084578 <copy_process+0xb8>
	} else { /* fork user tasks */
		struct pt_regs * cur_regs = task_pt_regs(current);
ffff000040084534:	d00007e0 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040084538:	f9402000 	ldr	x0, [x0, #64]
ffff00004008453c:	f9400000 	ldr	x0, [x0]
ffff000040084540:	94000061 	bl	ffff0000400846c4 <task_pt_regs>
ffff000040084544:	f90023e0 	str	x0, [sp, #64]
		*cur_regs = *childregs; 	// copy over the entire pt_regs
ffff000040084548:	f94023e1 	ldr	x1, [sp, #64]
ffff00004008454c:	f94027e0 	ldr	x0, [sp, #72]
ffff000040084550:	aa0103e3 	mov	x3, x1
ffff000040084554:	aa0003e1 	mov	x1, x0
ffff000040084558:	d2802200 	mov	x0, #0x110                 	// #272
ffff00004008455c:	aa0003e2 	mov	x2, x0
ffff000040084560:	aa0303e0 	mov	x0, x3
ffff000040084564:	94000365 	bl	ffff0000400852f8 <memcpy>
		childregs->regs[0] = 0;		// return value (x0) for child
ffff000040084568:	f94027e0 	ldr	x0, [sp, #72]
ffff00004008456c:	f900001f 	str	xzr, [x0]
		copy_virt_memory(p);		// duplicate virt memory
ffff000040084570:	f9402be0 	ldr	x0, [sp, #80]
ffff000040084574:	97fff8d7 	bl	ffff0000400828d0 <copy_virt_memory>
		// that's it, no modifying pc/sp/etc
	}
	p->flags = clone_flags;
ffff000040084578:	f9402be0 	ldr	x0, [sp, #80]
ffff00004008457c:	f94017e1 	ldr	x1, [sp, #40]
ffff000040084580:	f9004401 	str	x1, [x0, #136]
	p->priority = current->priority;
ffff000040084584:	d00007e0 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040084588:	f9402000 	ldr	x0, [x0, #64]
ffff00004008458c:	f9400000 	ldr	x0, [x0]
ffff000040084590:	f9403c01 	ldr	x1, [x0, #120]
ffff000040084594:	f9402be0 	ldr	x0, [sp, #80]
ffff000040084598:	f9003c01 	str	x1, [x0, #120]
	p->state = TASK_RUNNING;
ffff00004008459c:	f9402be0 	ldr	x0, [sp, #80]
ffff0000400845a0:	f900341f 	str	xzr, [x0, #104]
	p->counter = p->priority;
ffff0000400845a4:	f9402be0 	ldr	x0, [sp, #80]
ffff0000400845a8:	f9403c01 	ldr	x1, [x0, #120]
ffff0000400845ac:	f9402be0 	ldr	x0, [sp, #80]
ffff0000400845b0:	f9003801 	str	x1, [x0, #112]
	p->preempt_count = 1; //disable preemption until schedule_tail
ffff0000400845b4:	f9402be0 	ldr	x0, [sp, #80]
ffff0000400845b8:	d2800021 	mov	x1, #0x1                   	// #1
ffff0000400845bc:	f9004001 	str	x1, [x0, #128]

	p->cpu_context.pc = (unsigned long)ret_from_fork;
ffff0000400845c0:	d00007e0 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400845c4:	f9403401 	ldr	x1, [x0, #104]
ffff0000400845c8:	f9402be0 	ldr	x0, [sp, #80]
ffff0000400845cc:	f9003001 	str	x1, [x0, #96]
	p->cpu_context.sp = (unsigned long)childregs;
ffff0000400845d0:	f94027e1 	ldr	x1, [sp, #72]
ffff0000400845d4:	f9402be0 	ldr	x0, [sp, #80]
ffff0000400845d8:	f9002c01 	str	x1, [x0, #88]
	int pid = nr_tasks++;
ffff0000400845dc:	d00007e0 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400845e0:	f9402400 	ldr	x0, [x0, #72]
ffff0000400845e4:	b9400000 	ldr	w0, [x0]
ffff0000400845e8:	11000402 	add	w2, w0, #0x1
ffff0000400845ec:	d00007e1 	adrp	x1, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400845f0:	f9402421 	ldr	x1, [x1, #72]
ffff0000400845f4:	b9000022 	str	w2, [x1]
ffff0000400845f8:	b9003fe0 	str	w0, [sp, #60]
	task[pid] = p;	
ffff0000400845fc:	d00007e0 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040084600:	f9402800 	ldr	x0, [x0, #80]
ffff000040084604:	b9803fe1 	ldrsw	x1, [sp, #60]
ffff000040084608:	f9402be2 	ldr	x2, [sp, #80]
ffff00004008460c:	f8217802 	str	x2, [x0, x1, lsl #3]

	preempt_enable();
ffff000040084610:	97fff912 	bl	ffff000040082a58 <preempt_enable>
	return pid;
ffff000040084614:	b9403fe0 	ldr	w0, [sp, #60]
}
ffff000040084618:	a8c67bfd 	ldp	x29, x30, [sp], #96
ffff00004008461c:	d65f03c0 	ret

ffff000040084620 <move_to_user_mode>:
   @size: size of the area 
   @pc: offset of the startup function inside the area
*/   

int move_to_user_mode(unsigned long start, unsigned long size, unsigned long pc)
{
ffff000040084620:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
ffff000040084624:	910003fd 	mov	x29, sp
ffff000040084628:	f90017e0 	str	x0, [sp, #40]
ffff00004008462c:	f90013e1 	str	x1, [sp, #32]
ffff000040084630:	f9000fe2 	str	x2, [sp, #24]
	struct pt_regs *regs = task_pt_regs(current);
ffff000040084634:	d00007e0 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040084638:	f9402000 	ldr	x0, [x0, #64]
ffff00004008463c:	f9400000 	ldr	x0, [x0]
ffff000040084640:	94000021 	bl	ffff0000400846c4 <task_pt_regs>
ffff000040084644:	f9001fe0 	str	x0, [sp, #56]
	regs->pstate = PSR_MODE_EL0t;
ffff000040084648:	f9401fe0 	ldr	x0, [sp, #56]
ffff00004008464c:	f900841f 	str	xzr, [x0, #264]
	regs->pc = pc;
ffff000040084650:	f9401fe0 	ldr	x0, [sp, #56]
ffff000040084654:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040084658:	f9008001 	str	x1, [x0, #256]
	/* assumption: our toy user program will not exceed 1 page. the 2nd page will serve as the stack */
	regs->sp = 2 *  PAGE_SIZE;  
ffff00004008465c:	f9401fe0 	ldr	x0, [sp, #56]
ffff000040084660:	d2840001 	mov	x1, #0x2000                	// #8192
ffff000040084664:	f9007c01 	str	x1, [x0, #248]
	/* only allocate 1 code page here b/c the stack page is to be mapped on demand. */
	unsigned long code_page = allocate_user_page(current, 0 /*va*/);
ffff000040084668:	d00007e0 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff00004008466c:	f9402000 	ldr	x0, [x0, #64]
ffff000040084670:	f9400000 	ldr	x0, [x0]
ffff000040084674:	d2800001 	mov	x1, #0x0                   	// #0
ffff000040084678:	97fff77c 	bl	ffff000040082468 <allocate_user_page>
ffff00004008467c:	f9001be0 	str	x0, [sp, #48]
	if (code_page == 0)	{
ffff000040084680:	f9401be0 	ldr	x0, [sp, #48]
ffff000040084684:	f100001f 	cmp	x0, #0x0
ffff000040084688:	54000061 	b.ne	ffff000040084694 <move_to_user_mode+0x74>  // b.any
		return -1;
ffff00004008468c:	12800000 	mov	w0, #0xffffffff            	// #-1
ffff000040084690:	1400000b 	b	ffff0000400846bc <move_to_user_mode+0x9c>
	}
	memcpy(start, code_page, size); /* NB: arg1-src; arg2-dest */
ffff000040084694:	f94013e2 	ldr	x2, [sp, #32]
ffff000040084698:	f9401be1 	ldr	x1, [sp, #48]
ffff00004008469c:	f94017e0 	ldr	x0, [sp, #40]
ffff0000400846a0:	94000316 	bl	ffff0000400852f8 <memcpy>
	set_pgd(current->mm.pgd);
ffff0000400846a4:	d00007e0 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400846a8:	f9402000 	ldr	x0, [x0, #64]
ffff0000400846ac:	f9400000 	ldr	x0, [x0]
ffff0000400846b0:	f9404800 	ldr	x0, [x0, #144]
ffff0000400846b4:	94000306 	bl	ffff0000400852cc <set_pgd>
	return 0;
ffff0000400846b8:	52800000 	mov	w0, #0x0                   	// #0
}
ffff0000400846bc:	a8c47bfd 	ldp	x29, x30, [sp], #64
ffff0000400846c0:	d65f03c0 	ret

ffff0000400846c4 <task_pt_regs>:

/* get a task's saved registers, which are at the top of the task's kernel page. 
   these regs are saved/restored by kernel_entry()/kernel_exit(). 
*/
struct pt_regs * task_pt_regs(struct task_struct *tsk)
{
ffff0000400846c4:	d10083ff 	sub	sp, sp, #0x20
ffff0000400846c8:	f90007e0 	str	x0, [sp, #8]
	unsigned long p = (unsigned long)tsk + THREAD_SIZE - sizeof(struct pt_regs);
ffff0000400846cc:	f94007e0 	ldr	x0, [sp, #8]
ffff0000400846d0:	913bc000 	add	x0, x0, #0xef0
ffff0000400846d4:	f9000fe0 	str	x0, [sp, #24]
	return (struct pt_regs *)p;
ffff0000400846d8:	f9400fe0 	ldr	x0, [sp, #24]
}
ffff0000400846dc:	910083ff 	add	sp, sp, #0x20
ffff0000400846e0:	d65f03c0 	ret

ffff0000400846e4 <ui2a>:
    }

#endif

static void ui2a(unsigned int num, unsigned int base, int uc,char * bf)
    {
ffff0000400846e4:	d100c3ff 	sub	sp, sp, #0x30
ffff0000400846e8:	b9001fe0 	str	w0, [sp, #28]
ffff0000400846ec:	b9001be1 	str	w1, [sp, #24]
ffff0000400846f0:	b90017e2 	str	w2, [sp, #20]
ffff0000400846f4:	f90007e3 	str	x3, [sp, #8]
    int n=0;
ffff0000400846f8:	b9002fff 	str	wzr, [sp, #44]
    unsigned int d=1;
ffff0000400846fc:	52800020 	mov	w0, #0x1                   	// #1
ffff000040084700:	b9002be0 	str	w0, [sp, #40]
    while (num/d >= base)
ffff000040084704:	14000005 	b	ffff000040084718 <ui2a+0x34>
        d*=base;
ffff000040084708:	b9402be1 	ldr	w1, [sp, #40]
ffff00004008470c:	b9401be0 	ldr	w0, [sp, #24]
ffff000040084710:	1b007c20 	mul	w0, w1, w0
ffff000040084714:	b9002be0 	str	w0, [sp, #40]
    while (num/d >= base)
ffff000040084718:	b9401fe1 	ldr	w1, [sp, #28]
ffff00004008471c:	b9402be0 	ldr	w0, [sp, #40]
ffff000040084720:	1ac00820 	udiv	w0, w1, w0
ffff000040084724:	b9401be1 	ldr	w1, [sp, #24]
ffff000040084728:	6b00003f 	cmp	w1, w0
ffff00004008472c:	54fffee9 	b.ls	ffff000040084708 <ui2a+0x24>  // b.plast
    while (d!=0) {
ffff000040084730:	1400002f 	b	ffff0000400847ec <ui2a+0x108>
        int dgt = num / d;
ffff000040084734:	b9401fe1 	ldr	w1, [sp, #28]
ffff000040084738:	b9402be0 	ldr	w0, [sp, #40]
ffff00004008473c:	1ac00820 	udiv	w0, w1, w0
ffff000040084740:	b90027e0 	str	w0, [sp, #36]
        num%= d;
ffff000040084744:	b9401fe0 	ldr	w0, [sp, #28]
ffff000040084748:	b9402be1 	ldr	w1, [sp, #40]
ffff00004008474c:	1ac10802 	udiv	w2, w0, w1
ffff000040084750:	b9402be1 	ldr	w1, [sp, #40]
ffff000040084754:	1b017c41 	mul	w1, w2, w1
ffff000040084758:	4b010000 	sub	w0, w0, w1
ffff00004008475c:	b9001fe0 	str	w0, [sp, #28]
        d/=base;
ffff000040084760:	b9402be1 	ldr	w1, [sp, #40]
ffff000040084764:	b9401be0 	ldr	w0, [sp, #24]
ffff000040084768:	1ac00820 	udiv	w0, w1, w0
ffff00004008476c:	b9002be0 	str	w0, [sp, #40]
        if (n || dgt>0 || d==0) {
ffff000040084770:	b9402fe0 	ldr	w0, [sp, #44]
ffff000040084774:	7100001f 	cmp	w0, #0x0
ffff000040084778:	540000e1 	b.ne	ffff000040084794 <ui2a+0xb0>  // b.any
ffff00004008477c:	b94027e0 	ldr	w0, [sp, #36]
ffff000040084780:	7100001f 	cmp	w0, #0x0
ffff000040084784:	5400008c 	b.gt	ffff000040084794 <ui2a+0xb0>
ffff000040084788:	b9402be0 	ldr	w0, [sp, #40]
ffff00004008478c:	7100001f 	cmp	w0, #0x0
ffff000040084790:	540002e1 	b.ne	ffff0000400847ec <ui2a+0x108>  // b.any
            *bf++ = dgt+(dgt<10 ? '0' : (uc ? 'A' : 'a')-10);
ffff000040084794:	b94027e0 	ldr	w0, [sp, #36]
ffff000040084798:	7100241f 	cmp	w0, #0x9
ffff00004008479c:	5400010d 	b.le	ffff0000400847bc <ui2a+0xd8>
ffff0000400847a0:	b94017e0 	ldr	w0, [sp, #20]
ffff0000400847a4:	7100001f 	cmp	w0, #0x0
ffff0000400847a8:	54000060 	b.eq	ffff0000400847b4 <ui2a+0xd0>  // b.none
ffff0000400847ac:	528006e0 	mov	w0, #0x37                  	// #55
ffff0000400847b0:	14000004 	b	ffff0000400847c0 <ui2a+0xdc>
ffff0000400847b4:	52800ae0 	mov	w0, #0x57                  	// #87
ffff0000400847b8:	14000002 	b	ffff0000400847c0 <ui2a+0xdc>
ffff0000400847bc:	52800600 	mov	w0, #0x30                  	// #48
ffff0000400847c0:	b94027e1 	ldr	w1, [sp, #36]
ffff0000400847c4:	12001c22 	and	w2, w1, #0xff
ffff0000400847c8:	f94007e1 	ldr	x1, [sp, #8]
ffff0000400847cc:	91000423 	add	x3, x1, #0x1
ffff0000400847d0:	f90007e3 	str	x3, [sp, #8]
ffff0000400847d4:	0b020000 	add	w0, w0, w2
ffff0000400847d8:	12001c00 	and	w0, w0, #0xff
ffff0000400847dc:	39000020 	strb	w0, [x1]
            ++n;
ffff0000400847e0:	b9402fe0 	ldr	w0, [sp, #44]
ffff0000400847e4:	11000400 	add	w0, w0, #0x1
ffff0000400847e8:	b9002fe0 	str	w0, [sp, #44]
    while (d!=0) {
ffff0000400847ec:	b9402be0 	ldr	w0, [sp, #40]
ffff0000400847f0:	7100001f 	cmp	w0, #0x0
ffff0000400847f4:	54fffa01 	b.ne	ffff000040084734 <ui2a+0x50>  // b.any
            }
        }
    *bf=0;
ffff0000400847f8:	f94007e0 	ldr	x0, [sp, #8]
ffff0000400847fc:	3900001f 	strb	wzr, [x0]
    }
ffff000040084800:	d503201f 	nop
ffff000040084804:	9100c3ff 	add	sp, sp, #0x30
ffff000040084808:	d65f03c0 	ret

ffff00004008480c <i2a>:

static void i2a (int num, char * bf)
    {
ffff00004008480c:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
ffff000040084810:	910003fd 	mov	x29, sp
ffff000040084814:	b9001fe0 	str	w0, [sp, #28]
ffff000040084818:	f9000be1 	str	x1, [sp, #16]
    if (num<0) {
ffff00004008481c:	b9401fe0 	ldr	w0, [sp, #28]
ffff000040084820:	7100001f 	cmp	w0, #0x0
ffff000040084824:	5400012a 	b.ge	ffff000040084848 <i2a+0x3c>  // b.tcont
        num=-num;
ffff000040084828:	b9401fe0 	ldr	w0, [sp, #28]
ffff00004008482c:	4b0003e0 	neg	w0, w0
ffff000040084830:	b9001fe0 	str	w0, [sp, #28]
        *bf++ = '-';
ffff000040084834:	f9400be0 	ldr	x0, [sp, #16]
ffff000040084838:	91000401 	add	x1, x0, #0x1
ffff00004008483c:	f9000be1 	str	x1, [sp, #16]
ffff000040084840:	528005a1 	mov	w1, #0x2d                  	// #45
ffff000040084844:	39000001 	strb	w1, [x0]
        }
    ui2a(num,10,0,bf);
ffff000040084848:	b9401fe0 	ldr	w0, [sp, #28]
ffff00004008484c:	f9400be3 	ldr	x3, [sp, #16]
ffff000040084850:	52800002 	mov	w2, #0x0                   	// #0
ffff000040084854:	52800141 	mov	w1, #0xa                   	// #10
ffff000040084858:	97ffffa3 	bl	ffff0000400846e4 <ui2a>
    }
ffff00004008485c:	d503201f 	nop
ffff000040084860:	a8c27bfd 	ldp	x29, x30, [sp], #32
ffff000040084864:	d65f03c0 	ret

ffff000040084868 <a2d>:

static int a2d(char ch)
    {
ffff000040084868:	d10043ff 	sub	sp, sp, #0x10
ffff00004008486c:	39003fe0 	strb	w0, [sp, #15]
    if (ch>='0' && ch<='9')
ffff000040084870:	39403fe0 	ldrb	w0, [sp, #15]
ffff000040084874:	7100bc1f 	cmp	w0, #0x2f
ffff000040084878:	540000e9 	b.ls	ffff000040084894 <a2d+0x2c>  // b.plast
ffff00004008487c:	39403fe0 	ldrb	w0, [sp, #15]
ffff000040084880:	7100e41f 	cmp	w0, #0x39
ffff000040084884:	54000088 	b.hi	ffff000040084894 <a2d+0x2c>  // b.pmore
        return ch-'0';
ffff000040084888:	39403fe0 	ldrb	w0, [sp, #15]
ffff00004008488c:	5100c000 	sub	w0, w0, #0x30
ffff000040084890:	14000014 	b	ffff0000400848e0 <a2d+0x78>
    else if (ch>='a' && ch<='f')
ffff000040084894:	39403fe0 	ldrb	w0, [sp, #15]
ffff000040084898:	7101801f 	cmp	w0, #0x60
ffff00004008489c:	540000e9 	b.ls	ffff0000400848b8 <a2d+0x50>  // b.plast
ffff0000400848a0:	39403fe0 	ldrb	w0, [sp, #15]
ffff0000400848a4:	7101981f 	cmp	w0, #0x66
ffff0000400848a8:	54000088 	b.hi	ffff0000400848b8 <a2d+0x50>  // b.pmore
        return ch-'a'+10;
ffff0000400848ac:	39403fe0 	ldrb	w0, [sp, #15]
ffff0000400848b0:	51015c00 	sub	w0, w0, #0x57
ffff0000400848b4:	1400000b 	b	ffff0000400848e0 <a2d+0x78>
    else if (ch>='A' && ch<='F')
ffff0000400848b8:	39403fe0 	ldrb	w0, [sp, #15]
ffff0000400848bc:	7101001f 	cmp	w0, #0x40
ffff0000400848c0:	540000e9 	b.ls	ffff0000400848dc <a2d+0x74>  // b.plast
ffff0000400848c4:	39403fe0 	ldrb	w0, [sp, #15]
ffff0000400848c8:	7101181f 	cmp	w0, #0x46
ffff0000400848cc:	54000088 	b.hi	ffff0000400848dc <a2d+0x74>  // b.pmore
        return ch-'A'+10;
ffff0000400848d0:	39403fe0 	ldrb	w0, [sp, #15]
ffff0000400848d4:	5100dc00 	sub	w0, w0, #0x37
ffff0000400848d8:	14000002 	b	ffff0000400848e0 <a2d+0x78>
    else return -1;
ffff0000400848dc:	12800000 	mov	w0, #0xffffffff            	// #-1
    }
ffff0000400848e0:	910043ff 	add	sp, sp, #0x10
ffff0000400848e4:	d65f03c0 	ret

ffff0000400848e8 <a2i>:

static char a2i(char ch, char** src,int base,int* nump)
    {
ffff0000400848e8:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
ffff0000400848ec:	910003fd 	mov	x29, sp
ffff0000400848f0:	3900bfe0 	strb	w0, [sp, #47]
ffff0000400848f4:	f90013e1 	str	x1, [sp, #32]
ffff0000400848f8:	b9002be2 	str	w2, [sp, #40]
ffff0000400848fc:	f9000fe3 	str	x3, [sp, #24]
    char* p= *src;
ffff000040084900:	f94013e0 	ldr	x0, [sp, #32]
ffff000040084904:	f9400000 	ldr	x0, [x0]
ffff000040084908:	f9001fe0 	str	x0, [sp, #56]
    int num=0;
ffff00004008490c:	b90037ff 	str	wzr, [sp, #52]
    int digit;
    while ((digit=a2d(ch))>=0) {
ffff000040084910:	14000010 	b	ffff000040084950 <a2i+0x68>
        if (digit>base) break;
ffff000040084914:	b94033e1 	ldr	w1, [sp, #48]
ffff000040084918:	b9402be0 	ldr	w0, [sp, #40]
ffff00004008491c:	6b00003f 	cmp	w1, w0
ffff000040084920:	5400026c 	b.gt	ffff00004008496c <a2i+0x84>
        num=num*base+digit;
ffff000040084924:	b94037e1 	ldr	w1, [sp, #52]
ffff000040084928:	b9402be0 	ldr	w0, [sp, #40]
ffff00004008492c:	1b007c20 	mul	w0, w1, w0
ffff000040084930:	b94033e1 	ldr	w1, [sp, #48]
ffff000040084934:	0b000020 	add	w0, w1, w0
ffff000040084938:	b90037e0 	str	w0, [sp, #52]
        ch=*p++;
ffff00004008493c:	f9401fe0 	ldr	x0, [sp, #56]
ffff000040084940:	91000401 	add	x1, x0, #0x1
ffff000040084944:	f9001fe1 	str	x1, [sp, #56]
ffff000040084948:	39400000 	ldrb	w0, [x0]
ffff00004008494c:	3900bfe0 	strb	w0, [sp, #47]
    while ((digit=a2d(ch))>=0) {
ffff000040084950:	3940bfe0 	ldrb	w0, [sp, #47]
ffff000040084954:	97ffffc5 	bl	ffff000040084868 <a2d>
ffff000040084958:	b90033e0 	str	w0, [sp, #48]
ffff00004008495c:	b94033e0 	ldr	w0, [sp, #48]
ffff000040084960:	7100001f 	cmp	w0, #0x0
ffff000040084964:	54fffd8a 	b.ge	ffff000040084914 <a2i+0x2c>  // b.tcont
ffff000040084968:	14000002 	b	ffff000040084970 <a2i+0x88>
        if (digit>base) break;
ffff00004008496c:	d503201f 	nop
        }
    *src=p;
ffff000040084970:	f94013e0 	ldr	x0, [sp, #32]
ffff000040084974:	f9401fe1 	ldr	x1, [sp, #56]
ffff000040084978:	f9000001 	str	x1, [x0]
    *nump=num;
ffff00004008497c:	f9400fe0 	ldr	x0, [sp, #24]
ffff000040084980:	b94037e1 	ldr	w1, [sp, #52]
ffff000040084984:	b9000001 	str	w1, [x0]
    return ch;
ffff000040084988:	3940bfe0 	ldrb	w0, [sp, #47]
    }
ffff00004008498c:	a8c47bfd 	ldp	x29, x30, [sp], #64
ffff000040084990:	d65f03c0 	ret

ffff000040084994 <putchw>:

static void putchw(void* putp,putcf putf,int n, char z, char* bf)
    {
ffff000040084994:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
ffff000040084998:	910003fd 	mov	x29, sp
ffff00004008499c:	f90017e0 	str	x0, [sp, #40]
ffff0000400849a0:	f90013e1 	str	x1, [sp, #32]
ffff0000400849a4:	b9001fe2 	str	w2, [sp, #28]
ffff0000400849a8:	39006fe3 	strb	w3, [sp, #27]
ffff0000400849ac:	f9000be4 	str	x4, [sp, #16]
    char fc=z? '0' : ' ';
ffff0000400849b0:	39406fe0 	ldrb	w0, [sp, #27]
ffff0000400849b4:	7100001f 	cmp	w0, #0x0
ffff0000400849b8:	54000060 	b.eq	ffff0000400849c4 <putchw+0x30>  // b.none
ffff0000400849bc:	52800600 	mov	w0, #0x30                  	// #48
ffff0000400849c0:	14000002 	b	ffff0000400849c8 <putchw+0x34>
ffff0000400849c4:	52800400 	mov	w0, #0x20                  	// #32
ffff0000400849c8:	3900dfe0 	strb	w0, [sp, #55]
    char ch;
    char* p=bf;
ffff0000400849cc:	f9400be0 	ldr	x0, [sp, #16]
ffff0000400849d0:	f9001fe0 	str	x0, [sp, #56]
    while (*p++ && n > 0)
ffff0000400849d4:	14000004 	b	ffff0000400849e4 <putchw+0x50>
        n--;
ffff0000400849d8:	b9401fe0 	ldr	w0, [sp, #28]
ffff0000400849dc:	51000400 	sub	w0, w0, #0x1
ffff0000400849e0:	b9001fe0 	str	w0, [sp, #28]
    while (*p++ && n > 0)
ffff0000400849e4:	f9401fe0 	ldr	x0, [sp, #56]
ffff0000400849e8:	91000401 	add	x1, x0, #0x1
ffff0000400849ec:	f9001fe1 	str	x1, [sp, #56]
ffff0000400849f0:	39400000 	ldrb	w0, [x0]
ffff0000400849f4:	7100001f 	cmp	w0, #0x0
ffff0000400849f8:	54000120 	b.eq	ffff000040084a1c <putchw+0x88>  // b.none
ffff0000400849fc:	b9401fe0 	ldr	w0, [sp, #28]
ffff000040084a00:	7100001f 	cmp	w0, #0x0
ffff000040084a04:	54fffeac 	b.gt	ffff0000400849d8 <putchw+0x44>
    while (n-- > 0)
ffff000040084a08:	14000005 	b	ffff000040084a1c <putchw+0x88>
        putf(putp,fc);
ffff000040084a0c:	f94013e2 	ldr	x2, [sp, #32]
ffff000040084a10:	3940dfe1 	ldrb	w1, [sp, #55]
ffff000040084a14:	f94017e0 	ldr	x0, [sp, #40]
ffff000040084a18:	d63f0040 	blr	x2
    while (n-- > 0)
ffff000040084a1c:	b9401fe0 	ldr	w0, [sp, #28]
ffff000040084a20:	51000401 	sub	w1, w0, #0x1
ffff000040084a24:	b9001fe1 	str	w1, [sp, #28]
ffff000040084a28:	7100001f 	cmp	w0, #0x0
ffff000040084a2c:	54ffff0c 	b.gt	ffff000040084a0c <putchw+0x78>
    while ((ch= *bf++))
ffff000040084a30:	14000005 	b	ffff000040084a44 <putchw+0xb0>
        putf(putp,ch);
ffff000040084a34:	f94013e2 	ldr	x2, [sp, #32]
ffff000040084a38:	3940dbe1 	ldrb	w1, [sp, #54]
ffff000040084a3c:	f94017e0 	ldr	x0, [sp, #40]
ffff000040084a40:	d63f0040 	blr	x2
    while ((ch= *bf++))
ffff000040084a44:	f9400be0 	ldr	x0, [sp, #16]
ffff000040084a48:	91000401 	add	x1, x0, #0x1
ffff000040084a4c:	f9000be1 	str	x1, [sp, #16]
ffff000040084a50:	39400000 	ldrb	w0, [x0]
ffff000040084a54:	3900dbe0 	strb	w0, [sp, #54]
ffff000040084a58:	3940dbe0 	ldrb	w0, [sp, #54]
ffff000040084a5c:	7100001f 	cmp	w0, #0x0
ffff000040084a60:	54fffea1 	b.ne	ffff000040084a34 <putchw+0xa0>  // b.any
    }
ffff000040084a64:	d503201f 	nop
ffff000040084a68:	d503201f 	nop
ffff000040084a6c:	a8c47bfd 	ldp	x29, x30, [sp], #64
ffff000040084a70:	d65f03c0 	ret

ffff000040084a74 <tfp_format>:

void tfp_format(void* putp,putcf putf,char *fmt, va_list va)
    {
ffff000040084a74:	a9ba7bfd 	stp	x29, x30, [sp, #-96]!
ffff000040084a78:	910003fd 	mov	x29, sp
ffff000040084a7c:	f9000bf3 	str	x19, [sp, #16]
ffff000040084a80:	f9001fe0 	str	x0, [sp, #56]
ffff000040084a84:	f9001be1 	str	x1, [sp, #48]
ffff000040084a88:	f90017e2 	str	x2, [sp, #40]
ffff000040084a8c:	aa0303f3 	mov	x19, x3
    char bf[12];

    char ch;


    while ((ch=*(fmt++))) {
ffff000040084a90:	140000ef 	b	ffff000040084e4c <tfp_format+0x3d8>
        if (ch!='%')
ffff000040084a94:	39417fe0 	ldrb	w0, [sp, #95]
ffff000040084a98:	7100941f 	cmp	w0, #0x25
ffff000040084a9c:	540000c0 	b.eq	ffff000040084ab4 <tfp_format+0x40>  // b.none
            putf(putp,ch);
ffff000040084aa0:	f9401be2 	ldr	x2, [sp, #48]
ffff000040084aa4:	39417fe1 	ldrb	w1, [sp, #95]
ffff000040084aa8:	f9401fe0 	ldr	x0, [sp, #56]
ffff000040084aac:	d63f0040 	blr	x2
ffff000040084ab0:	140000e7 	b	ffff000040084e4c <tfp_format+0x3d8>
        else {
            char lz=0;
ffff000040084ab4:	39017bff 	strb	wzr, [sp, #94]
#ifdef  PRINTF_LONG_SUPPORT
            char lng=0;
#endif
            int w=0;
ffff000040084ab8:	b9004fff 	str	wzr, [sp, #76]
            ch=*(fmt++);
ffff000040084abc:	f94017e0 	ldr	x0, [sp, #40]
ffff000040084ac0:	91000401 	add	x1, x0, #0x1
ffff000040084ac4:	f90017e1 	str	x1, [sp, #40]
ffff000040084ac8:	39400000 	ldrb	w0, [x0]
ffff000040084acc:	39017fe0 	strb	w0, [sp, #95]
            if (ch=='0') {
ffff000040084ad0:	39417fe0 	ldrb	w0, [sp, #95]
ffff000040084ad4:	7100c01f 	cmp	w0, #0x30
ffff000040084ad8:	54000101 	b.ne	ffff000040084af8 <tfp_format+0x84>  // b.any
                ch=*(fmt++);
ffff000040084adc:	f94017e0 	ldr	x0, [sp, #40]
ffff000040084ae0:	91000401 	add	x1, x0, #0x1
ffff000040084ae4:	f90017e1 	str	x1, [sp, #40]
ffff000040084ae8:	39400000 	ldrb	w0, [x0]
ffff000040084aec:	39017fe0 	strb	w0, [sp, #95]
                lz=1;
ffff000040084af0:	52800020 	mov	w0, #0x1                   	// #1
ffff000040084af4:	39017be0 	strb	w0, [sp, #94]
                }
            if (ch>='0' && ch<='9') {
ffff000040084af8:	39417fe0 	ldrb	w0, [sp, #95]
ffff000040084afc:	7100bc1f 	cmp	w0, #0x2f
ffff000040084b00:	54000189 	b.ls	ffff000040084b30 <tfp_format+0xbc>  // b.plast
ffff000040084b04:	39417fe0 	ldrb	w0, [sp, #95]
ffff000040084b08:	7100e41f 	cmp	w0, #0x39
ffff000040084b0c:	54000128 	b.hi	ffff000040084b30 <tfp_format+0xbc>  // b.pmore
                ch=a2i(ch,&fmt,10,&w);
ffff000040084b10:	910133e1 	add	x1, sp, #0x4c
ffff000040084b14:	9100a3e0 	add	x0, sp, #0x28
ffff000040084b18:	aa0103e3 	mov	x3, x1
ffff000040084b1c:	52800142 	mov	w2, #0xa                   	// #10
ffff000040084b20:	aa0003e1 	mov	x1, x0
ffff000040084b24:	39417fe0 	ldrb	w0, [sp, #95]
ffff000040084b28:	97ffff70 	bl	ffff0000400848e8 <a2i>
ffff000040084b2c:	39017fe0 	strb	w0, [sp, #95]
            if (ch=='l') {
                ch=*(fmt++);
                lng=1;
            }
#endif
            switch (ch) {
ffff000040084b30:	39417fe0 	ldrb	w0, [sp, #95]
ffff000040084b34:	7101e01f 	cmp	w0, #0x78
ffff000040084b38:	54000be0 	b.eq	ffff000040084cb4 <tfp_format+0x240>  // b.none
ffff000040084b3c:	7101e01f 	cmp	w0, #0x78
ffff000040084b40:	5400184c 	b.gt	ffff000040084e48 <tfp_format+0x3d4>
ffff000040084b44:	7101d41f 	cmp	w0, #0x75
ffff000040084b48:	54000300 	b.eq	ffff000040084ba8 <tfp_format+0x134>  // b.none
ffff000040084b4c:	7101d41f 	cmp	w0, #0x75
ffff000040084b50:	540017cc 	b.gt	ffff000040084e48 <tfp_format+0x3d4>
ffff000040084b54:	7101cc1f 	cmp	w0, #0x73
ffff000040084b58:	54001360 	b.eq	ffff000040084dc4 <tfp_format+0x350>  // b.none
ffff000040084b5c:	7101cc1f 	cmp	w0, #0x73
ffff000040084b60:	5400174c 	b.gt	ffff000040084e48 <tfp_format+0x3d4>
ffff000040084b64:	7101901f 	cmp	w0, #0x64
ffff000040084b68:	54000660 	b.eq	ffff000040084c34 <tfp_format+0x1c0>  // b.none
ffff000040084b6c:	7101901f 	cmp	w0, #0x64
ffff000040084b70:	540016cc 	b.gt	ffff000040084e48 <tfp_format+0x3d4>
ffff000040084b74:	71018c1f 	cmp	w0, #0x63
ffff000040084b78:	54000f00 	b.eq	ffff000040084d58 <tfp_format+0x2e4>  // b.none
ffff000040084b7c:	71018c1f 	cmp	w0, #0x63
ffff000040084b80:	5400164c 	b.gt	ffff000040084e48 <tfp_format+0x3d4>
ffff000040084b84:	7101601f 	cmp	w0, #0x58
ffff000040084b88:	54000960 	b.eq	ffff000040084cb4 <tfp_format+0x240>  // b.none
ffff000040084b8c:	7101601f 	cmp	w0, #0x58
ffff000040084b90:	540015cc 	b.gt	ffff000040084e48 <tfp_format+0x3d4>
ffff000040084b94:	7100001f 	cmp	w0, #0x0
ffff000040084b98:	540016c0 	b.eq	ffff000040084e70 <tfp_format+0x3fc>  // b.none
ffff000040084b9c:	7100941f 	cmp	w0, #0x25
ffff000040084ba0:	540014c0 	b.eq	ffff000040084e38 <tfp_format+0x3c4>  // b.none
                    putchw(putp,putf,w,0,va_arg(va, char*));
                    break;
                case '%' :
                    putf(putp,ch);
                default:
                    break;
ffff000040084ba4:	140000a9 	b	ffff000040084e48 <tfp_format+0x3d4>
                    ui2a(va_arg(va, unsigned int),10,0,bf);
ffff000040084ba8:	b9401a61 	ldr	w1, [x19, #24]
ffff000040084bac:	f9400260 	ldr	x0, [x19]
ffff000040084bb0:	7100003f 	cmp	w1, #0x0
ffff000040084bb4:	540000ab 	b.lt	ffff000040084bc8 <tfp_format+0x154>  // b.tstop
ffff000040084bb8:	91002c01 	add	x1, x0, #0xb
ffff000040084bbc:	927df021 	and	x1, x1, #0xfffffffffffffff8
ffff000040084bc0:	f9000261 	str	x1, [x19]
ffff000040084bc4:	1400000d 	b	ffff000040084bf8 <tfp_format+0x184>
ffff000040084bc8:	11002022 	add	w2, w1, #0x8
ffff000040084bcc:	b9001a62 	str	w2, [x19, #24]
ffff000040084bd0:	b9401a62 	ldr	w2, [x19, #24]
ffff000040084bd4:	7100005f 	cmp	w2, #0x0
ffff000040084bd8:	540000ad 	b.le	ffff000040084bec <tfp_format+0x178>
ffff000040084bdc:	91002c01 	add	x1, x0, #0xb
ffff000040084be0:	927df021 	and	x1, x1, #0xfffffffffffffff8
ffff000040084be4:	f9000261 	str	x1, [x19]
ffff000040084be8:	14000004 	b	ffff000040084bf8 <tfp_format+0x184>
ffff000040084bec:	f9400662 	ldr	x2, [x19, #8]
ffff000040084bf0:	93407c20 	sxtw	x0, w1
ffff000040084bf4:	8b000040 	add	x0, x2, x0
ffff000040084bf8:	b9400000 	ldr	w0, [x0]
ffff000040084bfc:	910143e1 	add	x1, sp, #0x50
ffff000040084c00:	aa0103e3 	mov	x3, x1
ffff000040084c04:	52800002 	mov	w2, #0x0                   	// #0
ffff000040084c08:	52800141 	mov	w1, #0xa                   	// #10
ffff000040084c0c:	97fffeb6 	bl	ffff0000400846e4 <ui2a>
                    putchw(putp,putf,w,lz,bf);
ffff000040084c10:	b9404fe0 	ldr	w0, [sp, #76]
ffff000040084c14:	910143e1 	add	x1, sp, #0x50
ffff000040084c18:	aa0103e4 	mov	x4, x1
ffff000040084c1c:	39417be3 	ldrb	w3, [sp, #94]
ffff000040084c20:	2a0003e2 	mov	w2, w0
ffff000040084c24:	f9401be1 	ldr	x1, [sp, #48]
ffff000040084c28:	f9401fe0 	ldr	x0, [sp, #56]
ffff000040084c2c:	97ffff5a 	bl	ffff000040084994 <putchw>
                    break;
ffff000040084c30:	14000087 	b	ffff000040084e4c <tfp_format+0x3d8>
                    i2a(va_arg(va, int),bf);
ffff000040084c34:	b9401a61 	ldr	w1, [x19, #24]
ffff000040084c38:	f9400260 	ldr	x0, [x19]
ffff000040084c3c:	7100003f 	cmp	w1, #0x0
ffff000040084c40:	540000ab 	b.lt	ffff000040084c54 <tfp_format+0x1e0>  // b.tstop
ffff000040084c44:	91002c01 	add	x1, x0, #0xb
ffff000040084c48:	927df021 	and	x1, x1, #0xfffffffffffffff8
ffff000040084c4c:	f9000261 	str	x1, [x19]
ffff000040084c50:	1400000d 	b	ffff000040084c84 <tfp_format+0x210>
ffff000040084c54:	11002022 	add	w2, w1, #0x8
ffff000040084c58:	b9001a62 	str	w2, [x19, #24]
ffff000040084c5c:	b9401a62 	ldr	w2, [x19, #24]
ffff000040084c60:	7100005f 	cmp	w2, #0x0
ffff000040084c64:	540000ad 	b.le	ffff000040084c78 <tfp_format+0x204>
ffff000040084c68:	91002c01 	add	x1, x0, #0xb
ffff000040084c6c:	927df021 	and	x1, x1, #0xfffffffffffffff8
ffff000040084c70:	f9000261 	str	x1, [x19]
ffff000040084c74:	14000004 	b	ffff000040084c84 <tfp_format+0x210>
ffff000040084c78:	f9400662 	ldr	x2, [x19, #8]
ffff000040084c7c:	93407c20 	sxtw	x0, w1
ffff000040084c80:	8b000040 	add	x0, x2, x0
ffff000040084c84:	b9400000 	ldr	w0, [x0]
ffff000040084c88:	910143e1 	add	x1, sp, #0x50
ffff000040084c8c:	97fffee0 	bl	ffff00004008480c <i2a>
                    putchw(putp,putf,w,lz,bf);
ffff000040084c90:	b9404fe0 	ldr	w0, [sp, #76]
ffff000040084c94:	910143e1 	add	x1, sp, #0x50
ffff000040084c98:	aa0103e4 	mov	x4, x1
ffff000040084c9c:	39417be3 	ldrb	w3, [sp, #94]
ffff000040084ca0:	2a0003e2 	mov	w2, w0
ffff000040084ca4:	f9401be1 	ldr	x1, [sp, #48]
ffff000040084ca8:	f9401fe0 	ldr	x0, [sp, #56]
ffff000040084cac:	97ffff3a 	bl	ffff000040084994 <putchw>
                    break;
ffff000040084cb0:	14000067 	b	ffff000040084e4c <tfp_format+0x3d8>
                    ui2a(va_arg(va, unsigned int),16,(ch=='X'),bf);
ffff000040084cb4:	b9401a61 	ldr	w1, [x19, #24]
ffff000040084cb8:	f9400260 	ldr	x0, [x19]
ffff000040084cbc:	7100003f 	cmp	w1, #0x0
ffff000040084cc0:	540000ab 	b.lt	ffff000040084cd4 <tfp_format+0x260>  // b.tstop
ffff000040084cc4:	91002c01 	add	x1, x0, #0xb
ffff000040084cc8:	927df021 	and	x1, x1, #0xfffffffffffffff8
ffff000040084ccc:	f9000261 	str	x1, [x19]
ffff000040084cd0:	1400000d 	b	ffff000040084d04 <tfp_format+0x290>
ffff000040084cd4:	11002022 	add	w2, w1, #0x8
ffff000040084cd8:	b9001a62 	str	w2, [x19, #24]
ffff000040084cdc:	b9401a62 	ldr	w2, [x19, #24]
ffff000040084ce0:	7100005f 	cmp	w2, #0x0
ffff000040084ce4:	540000ad 	b.le	ffff000040084cf8 <tfp_format+0x284>
ffff000040084ce8:	91002c01 	add	x1, x0, #0xb
ffff000040084cec:	927df021 	and	x1, x1, #0xfffffffffffffff8
ffff000040084cf0:	f9000261 	str	x1, [x19]
ffff000040084cf4:	14000004 	b	ffff000040084d04 <tfp_format+0x290>
ffff000040084cf8:	f9400662 	ldr	x2, [x19, #8]
ffff000040084cfc:	93407c20 	sxtw	x0, w1
ffff000040084d00:	8b000040 	add	x0, x2, x0
ffff000040084d04:	b9400004 	ldr	w4, [x0]
ffff000040084d08:	39417fe0 	ldrb	w0, [sp, #95]
ffff000040084d0c:	7101601f 	cmp	w0, #0x58
ffff000040084d10:	1a9f17e0 	cset	w0, eq  // eq = none
ffff000040084d14:	12001c00 	and	w0, w0, #0xff
ffff000040084d18:	2a0003e1 	mov	w1, w0
ffff000040084d1c:	910143e0 	add	x0, sp, #0x50
ffff000040084d20:	aa0003e3 	mov	x3, x0
ffff000040084d24:	2a0103e2 	mov	w2, w1
ffff000040084d28:	52800201 	mov	w1, #0x10                  	// #16
ffff000040084d2c:	2a0403e0 	mov	w0, w4
ffff000040084d30:	97fffe6d 	bl	ffff0000400846e4 <ui2a>
                    putchw(putp,putf,w,lz,bf);
ffff000040084d34:	b9404fe0 	ldr	w0, [sp, #76]
ffff000040084d38:	910143e1 	add	x1, sp, #0x50
ffff000040084d3c:	aa0103e4 	mov	x4, x1
ffff000040084d40:	39417be3 	ldrb	w3, [sp, #94]
ffff000040084d44:	2a0003e2 	mov	w2, w0
ffff000040084d48:	f9401be1 	ldr	x1, [sp, #48]
ffff000040084d4c:	f9401fe0 	ldr	x0, [sp, #56]
ffff000040084d50:	97ffff11 	bl	ffff000040084994 <putchw>
                    break;
ffff000040084d54:	1400003e 	b	ffff000040084e4c <tfp_format+0x3d8>
                    putf(putp,(char)(va_arg(va, int)));
ffff000040084d58:	b9401a61 	ldr	w1, [x19, #24]
ffff000040084d5c:	f9400260 	ldr	x0, [x19]
ffff000040084d60:	7100003f 	cmp	w1, #0x0
ffff000040084d64:	540000ab 	b.lt	ffff000040084d78 <tfp_format+0x304>  // b.tstop
ffff000040084d68:	91002c01 	add	x1, x0, #0xb
ffff000040084d6c:	927df021 	and	x1, x1, #0xfffffffffffffff8
ffff000040084d70:	f9000261 	str	x1, [x19]
ffff000040084d74:	1400000d 	b	ffff000040084da8 <tfp_format+0x334>
ffff000040084d78:	11002022 	add	w2, w1, #0x8
ffff000040084d7c:	b9001a62 	str	w2, [x19, #24]
ffff000040084d80:	b9401a62 	ldr	w2, [x19, #24]
ffff000040084d84:	7100005f 	cmp	w2, #0x0
ffff000040084d88:	540000ad 	b.le	ffff000040084d9c <tfp_format+0x328>
ffff000040084d8c:	91002c01 	add	x1, x0, #0xb
ffff000040084d90:	927df021 	and	x1, x1, #0xfffffffffffffff8
ffff000040084d94:	f9000261 	str	x1, [x19]
ffff000040084d98:	14000004 	b	ffff000040084da8 <tfp_format+0x334>
ffff000040084d9c:	f9400662 	ldr	x2, [x19, #8]
ffff000040084da0:	93407c20 	sxtw	x0, w1
ffff000040084da4:	8b000040 	add	x0, x2, x0
ffff000040084da8:	b9400000 	ldr	w0, [x0]
ffff000040084dac:	12001c00 	and	w0, w0, #0xff
ffff000040084db0:	f9401be2 	ldr	x2, [sp, #48]
ffff000040084db4:	2a0003e1 	mov	w1, w0
ffff000040084db8:	f9401fe0 	ldr	x0, [sp, #56]
ffff000040084dbc:	d63f0040 	blr	x2
                    break;
ffff000040084dc0:	14000023 	b	ffff000040084e4c <tfp_format+0x3d8>
                    putchw(putp,putf,w,0,va_arg(va, char*));
ffff000040084dc4:	b9404fe5 	ldr	w5, [sp, #76]
ffff000040084dc8:	b9401a61 	ldr	w1, [x19, #24]
ffff000040084dcc:	f9400260 	ldr	x0, [x19]
ffff000040084dd0:	7100003f 	cmp	w1, #0x0
ffff000040084dd4:	540000ab 	b.lt	ffff000040084de8 <tfp_format+0x374>  // b.tstop
ffff000040084dd8:	91003c01 	add	x1, x0, #0xf
ffff000040084ddc:	927df021 	and	x1, x1, #0xfffffffffffffff8
ffff000040084de0:	f9000261 	str	x1, [x19]
ffff000040084de4:	1400000d 	b	ffff000040084e18 <tfp_format+0x3a4>
ffff000040084de8:	11002022 	add	w2, w1, #0x8
ffff000040084dec:	b9001a62 	str	w2, [x19, #24]
ffff000040084df0:	b9401a62 	ldr	w2, [x19, #24]
ffff000040084df4:	7100005f 	cmp	w2, #0x0
ffff000040084df8:	540000ad 	b.le	ffff000040084e0c <tfp_format+0x398>
ffff000040084dfc:	91003c01 	add	x1, x0, #0xf
ffff000040084e00:	927df021 	and	x1, x1, #0xfffffffffffffff8
ffff000040084e04:	f9000261 	str	x1, [x19]
ffff000040084e08:	14000004 	b	ffff000040084e18 <tfp_format+0x3a4>
ffff000040084e0c:	f9400662 	ldr	x2, [x19, #8]
ffff000040084e10:	93407c20 	sxtw	x0, w1
ffff000040084e14:	8b000040 	add	x0, x2, x0
ffff000040084e18:	f9400000 	ldr	x0, [x0]
ffff000040084e1c:	aa0003e4 	mov	x4, x0
ffff000040084e20:	52800003 	mov	w3, #0x0                   	// #0
ffff000040084e24:	2a0503e2 	mov	w2, w5
ffff000040084e28:	f9401be1 	ldr	x1, [sp, #48]
ffff000040084e2c:	f9401fe0 	ldr	x0, [sp, #56]
ffff000040084e30:	97fffed9 	bl	ffff000040084994 <putchw>
                    break;
ffff000040084e34:	14000006 	b	ffff000040084e4c <tfp_format+0x3d8>
                    putf(putp,ch);
ffff000040084e38:	f9401be2 	ldr	x2, [sp, #48]
ffff000040084e3c:	39417fe1 	ldrb	w1, [sp, #95]
ffff000040084e40:	f9401fe0 	ldr	x0, [sp, #56]
ffff000040084e44:	d63f0040 	blr	x2
                    break;
ffff000040084e48:	d503201f 	nop
    while ((ch=*(fmt++))) {
ffff000040084e4c:	f94017e0 	ldr	x0, [sp, #40]
ffff000040084e50:	91000401 	add	x1, x0, #0x1
ffff000040084e54:	f90017e1 	str	x1, [sp, #40]
ffff000040084e58:	39400000 	ldrb	w0, [x0]
ffff000040084e5c:	39017fe0 	strb	w0, [sp, #95]
ffff000040084e60:	39417fe0 	ldrb	w0, [sp, #95]
ffff000040084e64:	7100001f 	cmp	w0, #0x0
ffff000040084e68:	54ffe161 	b.ne	ffff000040084a94 <tfp_format+0x20>  // b.any
                }
            }
        }
    abort:;
ffff000040084e6c:	14000002 	b	ffff000040084e74 <tfp_format+0x400>
                    goto abort;
ffff000040084e70:	d503201f 	nop
    }
ffff000040084e74:	d503201f 	nop
ffff000040084e78:	f9400bf3 	ldr	x19, [sp, #16]
ffff000040084e7c:	a8c67bfd 	ldp	x29, x30, [sp], #96
ffff000040084e80:	d65f03c0 	ret

ffff000040084e84 <init_printf>:


void init_printf(void* putp,void (*putf) (void*,char))
    {
ffff000040084e84:	d10043ff 	sub	sp, sp, #0x10
ffff000040084e88:	f90007e0 	str	x0, [sp, #8]
ffff000040084e8c:	f90003e1 	str	x1, [sp]
    stdout_putf=putf;
ffff000040084e90:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040084e94:	9130c000 	add	x0, x0, #0xc30
ffff000040084e98:	f94003e1 	ldr	x1, [sp]
ffff000040084e9c:	f9000001 	str	x1, [x0]
    stdout_putp=putp;
ffff000040084ea0:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040084ea4:	9130e000 	add	x0, x0, #0xc38
ffff000040084ea8:	f94007e1 	ldr	x1, [sp, #8]
ffff000040084eac:	f9000001 	str	x1, [x0]
    }
ffff000040084eb0:	d503201f 	nop
ffff000040084eb4:	910043ff 	add	sp, sp, #0x10
ffff000040084eb8:	d65f03c0 	ret

ffff000040084ebc <tfp_printf>:

void tfp_printf(char *fmt, ...)
    {
ffff000040084ebc:	a9b67bfd 	stp	x29, x30, [sp, #-160]!
ffff000040084ec0:	910003fd 	mov	x29, sp
ffff000040084ec4:	f9001fe0 	str	x0, [sp, #56]
ffff000040084ec8:	f90037e1 	str	x1, [sp, #104]
ffff000040084ecc:	f9003be2 	str	x2, [sp, #112]
ffff000040084ed0:	f9003fe3 	str	x3, [sp, #120]
ffff000040084ed4:	f90043e4 	str	x4, [sp, #128]
ffff000040084ed8:	f90047e5 	str	x5, [sp, #136]
ffff000040084edc:	f9004be6 	str	x6, [sp, #144]
ffff000040084ee0:	f9004fe7 	str	x7, [sp, #152]
    va_list va;
    va_start(va,fmt);
ffff000040084ee4:	910283e0 	add	x0, sp, #0xa0
ffff000040084ee8:	f90023e0 	str	x0, [sp, #64]
ffff000040084eec:	910283e0 	add	x0, sp, #0xa0
ffff000040084ef0:	f90027e0 	str	x0, [sp, #72]
ffff000040084ef4:	910183e0 	add	x0, sp, #0x60
ffff000040084ef8:	f9002be0 	str	x0, [sp, #80]
ffff000040084efc:	128006e0 	mov	w0, #0xffffffc8            	// #-56
ffff000040084f00:	b9005be0 	str	w0, [sp, #88]
ffff000040084f04:	b9005fff 	str	wzr, [sp, #92]
    tfp_format(stdout_putp,stdout_putf,fmt,va);
ffff000040084f08:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040084f0c:	9130e000 	add	x0, x0, #0xc38
ffff000040084f10:	f9400004 	ldr	x4, [x0]
ffff000040084f14:	b0000be0 	adrp	x0, ffff000040201000 <mem_map+0x7ec98>
ffff000040084f18:	9130c000 	add	x0, x0, #0xc30
ffff000040084f1c:	f9400005 	ldr	x5, [x0]
ffff000040084f20:	910043e2 	add	x2, sp, #0x10
ffff000040084f24:	910103e3 	add	x3, sp, #0x40
ffff000040084f28:	a9400460 	ldp	x0, x1, [x3]
ffff000040084f2c:	a9000440 	stp	x0, x1, [x2]
ffff000040084f30:	a9410460 	ldp	x0, x1, [x3, #16]
ffff000040084f34:	a9010440 	stp	x0, x1, [x2, #16]
ffff000040084f38:	910043e0 	add	x0, sp, #0x10
ffff000040084f3c:	aa0003e3 	mov	x3, x0
ffff000040084f40:	f9401fe2 	ldr	x2, [sp, #56]
ffff000040084f44:	aa0503e1 	mov	x1, x5
ffff000040084f48:	aa0403e0 	mov	x0, x4
ffff000040084f4c:	97fffeca 	bl	ffff000040084a74 <tfp_format>
    va_end(va);
    }
ffff000040084f50:	d503201f 	nop
ffff000040084f54:	a8ca7bfd 	ldp	x29, x30, [sp], #160
ffff000040084f58:	d65f03c0 	ret

ffff000040084f5c <putcp>:

static void putcp(void* p,char c)
    {
ffff000040084f5c:	d10043ff 	sub	sp, sp, #0x10
ffff000040084f60:	f90007e0 	str	x0, [sp, #8]
ffff000040084f64:	39001fe1 	strb	w1, [sp, #7]
    *(*((char**)p))++ = c;
ffff000040084f68:	f94007e0 	ldr	x0, [sp, #8]
ffff000040084f6c:	f9400000 	ldr	x0, [x0]
ffff000040084f70:	91000402 	add	x2, x0, #0x1
ffff000040084f74:	f94007e1 	ldr	x1, [sp, #8]
ffff000040084f78:	f9000022 	str	x2, [x1]
ffff000040084f7c:	39401fe1 	ldrb	w1, [sp, #7]
ffff000040084f80:	39000001 	strb	w1, [x0]
    }
ffff000040084f84:	d503201f 	nop
ffff000040084f88:	910043ff 	add	sp, sp, #0x10
ffff000040084f8c:	d65f03c0 	ret

ffff000040084f90 <tfp_sprintf>:



void tfp_sprintf(char* s,char *fmt, ...)
    {
ffff000040084f90:	a9b77bfd 	stp	x29, x30, [sp, #-144]!
ffff000040084f94:	910003fd 	mov	x29, sp
ffff000040084f98:	f9001fe0 	str	x0, [sp, #56]
ffff000040084f9c:	f9001be1 	str	x1, [sp, #48]
ffff000040084fa0:	f90033e2 	str	x2, [sp, #96]
ffff000040084fa4:	f90037e3 	str	x3, [sp, #104]
ffff000040084fa8:	f9003be4 	str	x4, [sp, #112]
ffff000040084fac:	f9003fe5 	str	x5, [sp, #120]
ffff000040084fb0:	f90043e6 	str	x6, [sp, #128]
ffff000040084fb4:	f90047e7 	str	x7, [sp, #136]
    va_list va;
    va_start(va,fmt);
ffff000040084fb8:	910243e0 	add	x0, sp, #0x90
ffff000040084fbc:	f90023e0 	str	x0, [sp, #64]
ffff000040084fc0:	910243e0 	add	x0, sp, #0x90
ffff000040084fc4:	f90027e0 	str	x0, [sp, #72]
ffff000040084fc8:	910183e0 	add	x0, sp, #0x60
ffff000040084fcc:	f9002be0 	str	x0, [sp, #80]
ffff000040084fd0:	128005e0 	mov	w0, #0xffffffd0            	// #-48
ffff000040084fd4:	b9005be0 	str	w0, [sp, #88]
ffff000040084fd8:	b9005fff 	str	wzr, [sp, #92]
    tfp_format(&s,putcp,fmt,va);
ffff000040084fdc:	910043e2 	add	x2, sp, #0x10
ffff000040084fe0:	910103e3 	add	x3, sp, #0x40
ffff000040084fe4:	a9400460 	ldp	x0, x1, [x3]
ffff000040084fe8:	a9000440 	stp	x0, x1, [x2]
ffff000040084fec:	a9410460 	ldp	x0, x1, [x3, #16]
ffff000040084ff0:	a9010440 	stp	x0, x1, [x2, #16]
ffff000040084ff4:	910043e0 	add	x0, sp, #0x10
ffff000040084ff8:	9100e3e4 	add	x4, sp, #0x38
ffff000040084ffc:	aa0003e3 	mov	x3, x0
ffff000040085000:	f9401be2 	ldr	x2, [sp, #48]
ffff000040085004:	f0ffffe0 	adrp	x0, ffff000040084000 <arm_gic_dist_init+0x230>
ffff000040085008:	913d7001 	add	x1, x0, #0xf5c
ffff00004008500c:	aa0403e0 	mov	x0, x4
ffff000040085010:	97fffe99 	bl	ffff000040084a74 <tfp_format>
    putcp(&s,0);
ffff000040085014:	9100e3e0 	add	x0, sp, #0x38
ffff000040085018:	52800001 	mov	w1, #0x0                   	// #0
ffff00004008501c:	97ffffd0 	bl	ffff000040084f5c <putcp>
    va_end(va);
    }
ffff000040085020:	d503201f 	nop
ffff000040085024:	a8c97bfd 	ldp	x29, x30, [sp], #144
ffff000040085028:	d65f03c0 	ret

ffff00004008502c <kernel_process>:
#include "sched.h"
#include "sys.h"
#include "user.h"

// main body of kernel thread
void kernel_process() {
ffff00004008502c:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
ffff000040085030:	910003fd 	mov	x29, sp
	printf("Kernel process started. EL %d\r\n", get_el());
ffff000040085034:	940000ba 	bl	ffff00004008531c <get_el>
ffff000040085038:	2a0003e1 	mov	w1, w0
ffff00004008503c:	f00007c0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff000040085040:	91314000 	add	x0, x0, #0xc50
ffff000040085044:	97ffff9e 	bl	ffff000040084ebc <tfp_printf>
	unsigned long begin = (unsigned long)&user_begin;  	// defined in linker-qemu.ld
ffff000040085048:	b00007e0 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff00004008504c:	f9403000 	ldr	x0, [x0, #96]
ffff000040085050:	f90017e0 	str	x0, [sp, #40]
	unsigned long end = (unsigned long)&user_end;
ffff000040085054:	b00007e0 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040085058:	f9403c00 	ldr	x0, [x0, #120]
ffff00004008505c:	f90013e0 	str	x0, [sp, #32]
	unsigned long process = (unsigned long)&user_process;
ffff000040085060:	b00007e0 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff000040085064:	f9404000 	ldr	x0, [x0, #128]
ffff000040085068:	f9000fe0 	str	x0, [sp, #24]
	int err = move_to_user_mode(begin, end - begin, process - begin);
ffff00004008506c:	f94013e1 	ldr	x1, [sp, #32]
ffff000040085070:	f94017e0 	ldr	x0, [sp, #40]
ffff000040085074:	cb000023 	sub	x3, x1, x0
ffff000040085078:	f9400fe1 	ldr	x1, [sp, #24]
ffff00004008507c:	f94017e0 	ldr	x0, [sp, #40]
ffff000040085080:	cb000020 	sub	x0, x1, x0
ffff000040085084:	aa0003e2 	mov	x2, x0
ffff000040085088:	aa0303e1 	mov	x1, x3
ffff00004008508c:	f94017e0 	ldr	x0, [sp, #40]
ffff000040085090:	97fffd64 	bl	ffff000040084620 <move_to_user_mode>
ffff000040085094:	b90017e0 	str	w0, [sp, #20]
	if (err < 0){
ffff000040085098:	b94017e0 	ldr	w0, [sp, #20]
ffff00004008509c:	7100001f 	cmp	w0, #0x0
ffff0000400850a0:	5400008a 	b.ge	ffff0000400850b0 <kernel_process+0x84>  // b.tcont
		printf("Error while moving process to user mode\n\r");
ffff0000400850a4:	f00007c0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff0000400850a8:	9131c000 	add	x0, x0, #0xc70
ffff0000400850ac:	97ffff84 	bl	ffff000040084ebc <tfp_printf>
	} 
	// this func is called from ret_from_fork (entry.S). after returning, it goes back to 
	// ret_from_fork and does kernel_exit there. hence, pt_regs populated by move_to_user_mode()
	// will take effect. 
}
ffff0000400850b0:	d503201f 	nop
ffff0000400850b4:	a8c37bfd 	ldp	x29, x30, [sp], #48
ffff0000400850b8:	d65f03c0 	ret

ffff0000400850bc <kernel_main>:

void kernel_main()
{
ffff0000400850bc:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
ffff0000400850c0:	910003fd 	mov	x29, sp
	uart_init();
ffff0000400850c4:	94000059 	bl	ffff000040085228 <uart_init>
	init_printf(NULL, putc);
ffff0000400850c8:	b00007e0 	adrp	x0, ffff000040182000 <_binary_font_psf_start+0x7f0>
ffff0000400850cc:	f9402c01 	ldr	x1, [x0, #88]
ffff0000400850d0:	d2800000 	mov	x0, #0x0                   	// #0
ffff0000400850d4:	97ffff6c 	bl	ffff000040084e84 <init_printf>

	printf("kernel boots ...\n\r");
ffff0000400850d8:	f00007c0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff0000400850dc:	91328000 	add	x0, x0, #0xca0
ffff0000400850e0:	97ffff77 	bl	ffff000040084ebc <tfp_printf>

	irq_vector_init();
ffff0000400850e4:	9400006e 	bl	ffff00004008529c <irq_vector_init>
	generic_timer_init();
ffff0000400850e8:	97fffce6 	bl	ffff000040084480 <generic_timer_init>
	enable_interrupt_controller();
ffff0000400850ec:	97fff49a 	bl	ffff000040082354 <enable_interrupt_controller>
	enable_irq();
ffff0000400850f0:	9400006e 	bl	ffff0000400852a8 <enable_irq>

	int res = copy_process(PF_KTHREAD, (unsigned long)&kernel_process, 0);
ffff0000400850f4:	90000000 	adrp	x0, ffff000040085000 <tfp_sprintf+0x70>
ffff0000400850f8:	9100b000 	add	x0, x0, #0x2c
ffff0000400850fc:	d2800002 	mov	x2, #0x0                   	// #0
ffff000040085100:	aa0003e1 	mov	x1, x0
ffff000040085104:	d2800040 	mov	x0, #0x2                   	// #2
ffff000040085108:	97fffcee 	bl	ffff0000400844c0 <copy_process>
ffff00004008510c:	b9001fe0 	str	w0, [sp, #28]
	if (res < 0) {
ffff000040085110:	b9401fe0 	ldr	w0, [sp, #28]
ffff000040085114:	7100001f 	cmp	w0, #0x0
ffff000040085118:	540000aa 	b.ge	ffff00004008512c <kernel_main+0x70>  // b.tcont
		printf("error while starting kernel process");
ffff00004008511c:	f00007c0 	adrp	x0, ffff000040180000 <cpu_switch_to+0xf96cc>
ffff000040085120:	9132e000 	add	x0, x0, #0xcb8
ffff000040085124:	97ffff66 	bl	ffff000040084ebc <tfp_printf>
		return;
ffff000040085128:	14000003 	b	ffff000040085134 <kernel_main+0x78>
	}

	while (1){
		schedule();
ffff00004008512c:	97fff69d 	bl	ffff000040082ba0 <schedule>
ffff000040085130:	17ffffff 	b	ffff00004008512c <kernel_main+0x70>
	}	
}
ffff000040085134:	a8c27bfd 	ldp	x29, x30, [sp], #32
ffff000040085138:	d65f03c0 	ret

ffff00004008513c <uart_send>:
#define UARTICR_RXIC    0x10
#define UARTICR_TXIC    0x20

static unsigned long hw_base = 0x09000000; 

void uart_send (char c) {
ffff00004008513c:	d10043ff 	sub	sp, sp, #0x10
ffff000040085140:	39003fe0 	strb	w0, [sp, #15]
    while (UART_FR(hw_base) & UARTFR_TXFF)
ffff000040085144:	d503201f 	nop
ffff000040085148:	900007e0 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff00004008514c:	91202000 	add	x0, x0, #0x808
ffff000040085150:	f9400000 	ldr	x0, [x0]
ffff000040085154:	91006000 	add	x0, x0, #0x18
ffff000040085158:	b9400000 	ldr	w0, [x0]
ffff00004008515c:	121b0000 	and	w0, w0, #0x20
ffff000040085160:	7100001f 	cmp	w0, #0x0
ffff000040085164:	54ffff21 	b.ne	ffff000040085148 <uart_send+0xc>  // b.any
        ;
    UART_DR(hw_base) = (uint32_t)c;
ffff000040085168:	900007e0 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff00004008516c:	91202000 	add	x0, x0, #0x808
ffff000040085170:	f9400000 	ldr	x0, [x0]
ffff000040085174:	aa0003e1 	mov	x1, x0
ffff000040085178:	39403fe0 	ldrb	w0, [sp, #15]
ffff00004008517c:	b9000020 	str	w0, [x1]
}
ffff000040085180:	d503201f 	nop
ffff000040085184:	910043ff 	add	sp, sp, #0x10
ffff000040085188:	d65f03c0 	ret

ffff00004008518c <uart_recv>:

char uart_recv(void) {    
    while (1) {
        if (!(UART_FR(hw_base) & UARTFR_RXFE)) 
ffff00004008518c:	900007e0 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff000040085190:	91202000 	add	x0, x0, #0x808
ffff000040085194:	f9400000 	ldr	x0, [x0]
ffff000040085198:	91006000 	add	x0, x0, #0x18
ffff00004008519c:	b9400000 	ldr	w0, [x0]
ffff0000400851a0:	121c0000 	and	w0, w0, #0x10
ffff0000400851a4:	7100001f 	cmp	w0, #0x0
ffff0000400851a8:	54000040 	b.eq	ffff0000400851b0 <uart_recv+0x24>  // b.none
ffff0000400851ac:	17fffff8 	b	ffff00004008518c <uart_recv>
            break;      
ffff0000400851b0:	d503201f 	nop
    }
    return (char)(UART_DR(hw_base) & 0xff);
ffff0000400851b4:	900007e0 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff0000400851b8:	91202000 	add	x0, x0, #0x808
ffff0000400851bc:	f9400000 	ldr	x0, [x0]
ffff0000400851c0:	b9400000 	ldr	w0, [x0]
ffff0000400851c4:	12001c00 	and	w0, w0, #0xff
}
ffff0000400851c8:	d65f03c0 	ret

ffff0000400851cc <uart_send_string>:

void uart_send_string(char* str) {
ffff0000400851cc:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
ffff0000400851d0:	910003fd 	mov	x29, sp
ffff0000400851d4:	f9000fe0 	str	x0, [sp, #24]
	for (int i = 0; str[i] != '\0'; i ++) {
ffff0000400851d8:	b9002fff 	str	wzr, [sp, #44]
ffff0000400851dc:	14000009 	b	ffff000040085200 <uart_send_string+0x34>
		uart_send((char)str[i]);
ffff0000400851e0:	b9802fe0 	ldrsw	x0, [sp, #44]
ffff0000400851e4:	f9400fe1 	ldr	x1, [sp, #24]
ffff0000400851e8:	8b000020 	add	x0, x1, x0
ffff0000400851ec:	39400000 	ldrb	w0, [x0]
ffff0000400851f0:	97ffffd3 	bl	ffff00004008513c <uart_send>
	for (int i = 0; str[i] != '\0'; i ++) {
ffff0000400851f4:	b9402fe0 	ldr	w0, [sp, #44]
ffff0000400851f8:	11000400 	add	w0, w0, #0x1
ffff0000400851fc:	b9002fe0 	str	w0, [sp, #44]
ffff000040085200:	b9802fe0 	ldrsw	x0, [sp, #44]
ffff000040085204:	f9400fe1 	ldr	x1, [sp, #24]
ffff000040085208:	8b000020 	add	x0, x1, x0
ffff00004008520c:	39400000 	ldrb	w0, [x0]
ffff000040085210:	7100001f 	cmp	w0, #0x0
ffff000040085214:	54fffe61 	b.ne	ffff0000400851e0 <uart_send_string+0x14>  // b.any
	}
}
ffff000040085218:	d503201f 	nop
ffff00004008521c:	d503201f 	nop
ffff000040085220:	a8c37bfd 	ldp	x29, x30, [sp], #48
ffff000040085224:	d65f03c0 	ret

ffff000040085228 <uart_init>:

void uart_init (void) {

    /* disable rx irq */
    UART_IMSC(hw_base) &= ~UARTIMSC_RXIM;
ffff000040085228:	900007e0 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff00004008522c:	91202000 	add	x0, x0, #0x808
ffff000040085230:	f9400000 	ldr	x0, [x0]
ffff000040085234:	9100e000 	add	x0, x0, #0x38
ffff000040085238:	b9400000 	ldr	w0, [x0]
ffff00004008523c:	900007e1 	adrp	x1, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff000040085240:	91202021 	add	x1, x1, #0x808
ffff000040085244:	f9400021 	ldr	x1, [x1]
ffff000040085248:	9100e021 	add	x1, x1, #0x38
ffff00004008524c:	121b7800 	and	w0, w0, #0xffffffef
ffff000040085250:	b9000020 	str	w0, [x1]

    /* enable Rx and Tx of UART */
    UART_CR(hw_base) = (1 << 0) | (1 << 8) | (1 << 9);
ffff000040085254:	900007e0 	adrp	x0, ffff000040181000 <cpu_switch_to+0xfa6cc>
ffff000040085258:	91202000 	add	x0, x0, #0x808
ffff00004008525c:	f9400000 	ldr	x0, [x0]
ffff000040085260:	9100c000 	add	x0, x0, #0x30
ffff000040085264:	aa0003e1 	mov	x1, x0
ffff000040085268:	52806020 	mov	w0, #0x301                 	// #769
ffff00004008526c:	b9000020 	str	w0, [x1]
    UART_DEVICE->ICR  = BE_INTERRUPT;

    /* Enable the UART */
    UART_DEVICE->CR |= CR_UARTEN;
#endif    
}
ffff000040085270:	d503201f 	nop
ffff000040085274:	d65f03c0 	ret

ffff000040085278 <putc>:

// This function is required by printf function
void putc(void* p, char c) {
ffff000040085278:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
ffff00004008527c:	910003fd 	mov	x29, sp
ffff000040085280:	f9000fe0 	str	x0, [sp, #24]
ffff000040085284:	39005fe1 	strb	w1, [sp, #23]
	uart_send(c);
ffff000040085288:	39405fe0 	ldrb	w0, [sp, #23]
ffff00004008528c:	97ffffac 	bl	ffff00004008513c <uart_send>
ffff000040085290:	d503201f 	nop
ffff000040085294:	a8c27bfd 	ldp	x29, x30, [sp], #32
ffff000040085298:	d65f03c0 	ret

ffff00004008529c <irq_vector_init>:
// ----------------- irq --------------------------- //

.globl irq_vector_init
irq_vector_init:
	adr	x0, vectors		// load VBAR_EL1 with virtual
ffff00004008529c:	10002b20 	adr	x0, ffff000040085800 <vectors>
	msr	vbar_el1, x0		// vector table address
ffff0000400852a0:	d518c000 	msr	vbar_el1, x0
	ret
ffff0000400852a4:	d65f03c0 	ret

ffff0000400852a8 <enable_irq>:

.globl enable_irq
enable_irq:
	msr    daifclr, #2 
ffff0000400852a8:	d50342ff 	msr	daifclr, #0x2
	ret
ffff0000400852ac:	d65f03c0 	ret

ffff0000400852b0 <disable_irq>:

.globl disable_irq
disable_irq:
	msr	daifset, #2
ffff0000400852b0:	d50342df 	msr	daifset, #0x2
	ret
ffff0000400852b4:	d65f03c0 	ret

ffff0000400852b8 <gen_timer_init>:
	# Below, writes 1 to the control register (CNTP_CTL_EL0) of the EL1 physical timer
	# Explanation: 
	# 		CTL indicates this is a control register
	#		CNTP_XXX_EL0 indicates that this is for the EL1 physical timer
	#		(Why named _EL0? I guess it means that the timer is accessible to both EL1 and EL0)
	mov x0, #1
ffff0000400852b8:	d2800020 	mov	x0, #0x1                   	// #1
	msr CNTP_CTL_EL0, x0
ffff0000400852bc:	d51be220 	msr	cntp_ctl_el0, x0
	ret
ffff0000400852c0:	d65f03c0 	ret

ffff0000400852c4 <gen_timer_reset>:

.globl gen_timer_reset
gen_timer_reset:
	# When called from C code, the function writes the 1st argument (x0) to TVAL, 
	# which (roughly speaking) sets a "delta" for System Counter.
	msr CNTP_TVAL_EL0, x0
ffff0000400852c4:	d51be200 	msr	cntp_tval_el0, x0
    ret
ffff0000400852c8:	d65f03c0 	ret

ffff0000400852cc <set_pgd>:

// ----------------------- pgd --------------------------------------------//
.globl set_pgd
set_pgd:
	msr	ttbr0_el1, x0
ffff0000400852cc:	d5182000 	msr	ttbr0_el1, x0
	tlbi vmalle1is
ffff0000400852d0:	d508831f 	tlbi	vmalle1is
  	DSB ISH              // ensure completion of TLB invalidation
ffff0000400852d4:	d5033b9f 	dsb	ish
	isb
ffff0000400852d8:	d5033fdf 	isb
	ret
ffff0000400852dc:	d65f03c0 	ret

ffff0000400852e0 <get_pgd>:

.globl get_pgd
get_pgd:
	mov x1, 0
ffff0000400852e0:	d2800001 	mov	x1, #0x0                   	// #0
	ldr x0, [x1]
ffff0000400852e4:	f9400020 	ldr	x0, [x1]
	mov x0, 0x1000
ffff0000400852e8:	d2820000 	mov	x0, #0x1000                	// #4096
	msr	ttbr0_el1, x0
ffff0000400852ec:	d5182000 	msr	ttbr0_el1, x0
	ldr x0, [x1]
ffff0000400852f0:	f9400020 	ldr	x0, [x1]
	ret
ffff0000400852f4:	d65f03c0 	ret

ffff0000400852f8 <memcpy>:

// ---------------------- misc -------------------------------------------- //
.globl memcpy
memcpy:
	ldr x3, [x0], #8
ffff0000400852f8:	f8408403 	ldr	x3, [x0], #8
	str x3, [x1], #8
ffff0000400852fc:	f8008423 	str	x3, [x1], #8
	subs x2, x2, #8
ffff000040085300:	f1002042 	subs	x2, x2, #0x8
	b.gt memcpy
ffff000040085304:	54ffffac 	b.gt	ffff0000400852f8 <memcpy>
	ret
ffff000040085308:	d65f03c0 	ret

ffff00004008530c <memzero>:

.globl memzero
memzero:
	str xzr, [x0], #8
ffff00004008530c:	f800841f 	str	xzr, [x0], #8
	subs x1, x1, #8
ffff000040085310:	f1002021 	subs	x1, x1, #0x8
	b.gt memzero
ffff000040085314:	54ffffcc 	b.gt	ffff00004008530c <memzero>
	ret
ffff000040085318:	d65f03c0 	ret

ffff00004008531c <get_el>:

.globl get_el
get_el:
	mrs x0, CurrentEL
ffff00004008531c:	d5384240 	mrs	x0, currentel
	lsr x0, x0, #2
ffff000040085320:	d342fc00 	lsr	x0, x0, #2
	ret
ffff000040085324:	d65f03c0 	ret

ffff000040085328 <put32>:

.globl put32
put32:
	str w1,[x0]
ffff000040085328:	b9000001 	str	w1, [x0]
	ret
ffff00004008532c:	d65f03c0 	ret

ffff000040085330 <get32>:

.globl get32
get32:
	ldr w0,[x0]
ffff000040085330:	b9400000 	ldr	w0, [x0]
	ret
ffff000040085334:	d65f03c0 	ret

ffff000040085338 <delay>:

.globl delay
delay:
	subs x0, x0, #1
ffff000040085338:	f1000400 	subs	x0, x0, #0x1
	bne delay
ffff00004008533c:	54ffffe1 	b.ne	ffff000040085338 <delay>  // b.any
ffff000040085340:	d65f03c0 	ret
	...

ffff000040085800 <vectors>:
 * Exception vectors.
 */
.align	11
.globl vectors 
vectors:
	ventry	sync_invalid_el1t			// Synchronous EL1t
ffff000040085800:	140001e1 	b	ffff000040085f84 <sync_invalid_el1t>
ffff000040085804:	d503201f 	nop
ffff000040085808:	d503201f 	nop
ffff00004008580c:	d503201f 	nop
ffff000040085810:	d503201f 	nop
ffff000040085814:	d503201f 	nop
ffff000040085818:	d503201f 	nop
ffff00004008581c:	d503201f 	nop
ffff000040085820:	d503201f 	nop
ffff000040085824:	d503201f 	nop
ffff000040085828:	d503201f 	nop
ffff00004008582c:	d503201f 	nop
ffff000040085830:	d503201f 	nop
ffff000040085834:	d503201f 	nop
ffff000040085838:	d503201f 	nop
ffff00004008583c:	d503201f 	nop
ffff000040085840:	d503201f 	nop
ffff000040085844:	d503201f 	nop
ffff000040085848:	d503201f 	nop
ffff00004008584c:	d503201f 	nop
ffff000040085850:	d503201f 	nop
ffff000040085854:	d503201f 	nop
ffff000040085858:	d503201f 	nop
ffff00004008585c:	d503201f 	nop
ffff000040085860:	d503201f 	nop
ffff000040085864:	d503201f 	nop
ffff000040085868:	d503201f 	nop
ffff00004008586c:	d503201f 	nop
ffff000040085870:	d503201f 	nop
ffff000040085874:	d503201f 	nop
ffff000040085878:	d503201f 	nop
ffff00004008587c:	d503201f 	nop
	ventry	irq_invalid_el1t			// IRQ EL1t
ffff000040085880:	140001db 	b	ffff000040085fec <irq_invalid_el1t>
ffff000040085884:	d503201f 	nop
ffff000040085888:	d503201f 	nop
ffff00004008588c:	d503201f 	nop
ffff000040085890:	d503201f 	nop
ffff000040085894:	d503201f 	nop
ffff000040085898:	d503201f 	nop
ffff00004008589c:	d503201f 	nop
ffff0000400858a0:	d503201f 	nop
ffff0000400858a4:	d503201f 	nop
ffff0000400858a8:	d503201f 	nop
ffff0000400858ac:	d503201f 	nop
ffff0000400858b0:	d503201f 	nop
ffff0000400858b4:	d503201f 	nop
ffff0000400858b8:	d503201f 	nop
ffff0000400858bc:	d503201f 	nop
ffff0000400858c0:	d503201f 	nop
ffff0000400858c4:	d503201f 	nop
ffff0000400858c8:	d503201f 	nop
ffff0000400858cc:	d503201f 	nop
ffff0000400858d0:	d503201f 	nop
ffff0000400858d4:	d503201f 	nop
ffff0000400858d8:	d503201f 	nop
ffff0000400858dc:	d503201f 	nop
ffff0000400858e0:	d503201f 	nop
ffff0000400858e4:	d503201f 	nop
ffff0000400858e8:	d503201f 	nop
ffff0000400858ec:	d503201f 	nop
ffff0000400858f0:	d503201f 	nop
ffff0000400858f4:	d503201f 	nop
ffff0000400858f8:	d503201f 	nop
ffff0000400858fc:	d503201f 	nop
	ventry	fiq_invalid_el1t			// FIQ EL1t
ffff000040085900:	140001d5 	b	ffff000040086054 <fiq_invalid_el1t>
ffff000040085904:	d503201f 	nop
ffff000040085908:	d503201f 	nop
ffff00004008590c:	d503201f 	nop
ffff000040085910:	d503201f 	nop
ffff000040085914:	d503201f 	nop
ffff000040085918:	d503201f 	nop
ffff00004008591c:	d503201f 	nop
ffff000040085920:	d503201f 	nop
ffff000040085924:	d503201f 	nop
ffff000040085928:	d503201f 	nop
ffff00004008592c:	d503201f 	nop
ffff000040085930:	d503201f 	nop
ffff000040085934:	d503201f 	nop
ffff000040085938:	d503201f 	nop
ffff00004008593c:	d503201f 	nop
ffff000040085940:	d503201f 	nop
ffff000040085944:	d503201f 	nop
ffff000040085948:	d503201f 	nop
ffff00004008594c:	d503201f 	nop
ffff000040085950:	d503201f 	nop
ffff000040085954:	d503201f 	nop
ffff000040085958:	d503201f 	nop
ffff00004008595c:	d503201f 	nop
ffff000040085960:	d503201f 	nop
ffff000040085964:	d503201f 	nop
ffff000040085968:	d503201f 	nop
ffff00004008596c:	d503201f 	nop
ffff000040085970:	d503201f 	nop
ffff000040085974:	d503201f 	nop
ffff000040085978:	d503201f 	nop
ffff00004008597c:	d503201f 	nop
	ventry	error_invalid_el1t			// Error EL1t
ffff000040085980:	140001cf 	b	ffff0000400860bc <error_invalid_el1t>
ffff000040085984:	d503201f 	nop
ffff000040085988:	d503201f 	nop
ffff00004008598c:	d503201f 	nop
ffff000040085990:	d503201f 	nop
ffff000040085994:	d503201f 	nop
ffff000040085998:	d503201f 	nop
ffff00004008599c:	d503201f 	nop
ffff0000400859a0:	d503201f 	nop
ffff0000400859a4:	d503201f 	nop
ffff0000400859a8:	d503201f 	nop
ffff0000400859ac:	d503201f 	nop
ffff0000400859b0:	d503201f 	nop
ffff0000400859b4:	d503201f 	nop
ffff0000400859b8:	d503201f 	nop
ffff0000400859bc:	d503201f 	nop
ffff0000400859c0:	d503201f 	nop
ffff0000400859c4:	d503201f 	nop
ffff0000400859c8:	d503201f 	nop
ffff0000400859cc:	d503201f 	nop
ffff0000400859d0:	d503201f 	nop
ffff0000400859d4:	d503201f 	nop
ffff0000400859d8:	d503201f 	nop
ffff0000400859dc:	d503201f 	nop
ffff0000400859e0:	d503201f 	nop
ffff0000400859e4:	d503201f 	nop
ffff0000400859e8:	d503201f 	nop
ffff0000400859ec:	d503201f 	nop
ffff0000400859f0:	d503201f 	nop
ffff0000400859f4:	d503201f 	nop
ffff0000400859f8:	d503201f 	nop
ffff0000400859fc:	d503201f 	nop

	ventry	sync_invalid_el1h			// Synchronous EL1h
ffff000040085a00:	140001c9 	b	ffff000040086124 <sync_invalid_el1h>
ffff000040085a04:	d503201f 	nop
ffff000040085a08:	d503201f 	nop
ffff000040085a0c:	d503201f 	nop
ffff000040085a10:	d503201f 	nop
ffff000040085a14:	d503201f 	nop
ffff000040085a18:	d503201f 	nop
ffff000040085a1c:	d503201f 	nop
ffff000040085a20:	d503201f 	nop
ffff000040085a24:	d503201f 	nop
ffff000040085a28:	d503201f 	nop
ffff000040085a2c:	d503201f 	nop
ffff000040085a30:	d503201f 	nop
ffff000040085a34:	d503201f 	nop
ffff000040085a38:	d503201f 	nop
ffff000040085a3c:	d503201f 	nop
ffff000040085a40:	d503201f 	nop
ffff000040085a44:	d503201f 	nop
ffff000040085a48:	d503201f 	nop
ffff000040085a4c:	d503201f 	nop
ffff000040085a50:	d503201f 	nop
ffff000040085a54:	d503201f 	nop
ffff000040085a58:	d503201f 	nop
ffff000040085a5c:	d503201f 	nop
ffff000040085a60:	d503201f 	nop
ffff000040085a64:	d503201f 	nop
ffff000040085a68:	d503201f 	nop
ffff000040085a6c:	d503201f 	nop
ffff000040085a70:	d503201f 	nop
ffff000040085a74:	d503201f 	nop
ffff000040085a78:	d503201f 	nop
ffff000040085a7c:	d503201f 	nop
	ventry	el1_irq					// IRQ EL1h
ffff000040085a80:	14000293 	b	ffff0000400864cc <el1_irq>
ffff000040085a84:	d503201f 	nop
ffff000040085a88:	d503201f 	nop
ffff000040085a8c:	d503201f 	nop
ffff000040085a90:	d503201f 	nop
ffff000040085a94:	d503201f 	nop
ffff000040085a98:	d503201f 	nop
ffff000040085a9c:	d503201f 	nop
ffff000040085aa0:	d503201f 	nop
ffff000040085aa4:	d503201f 	nop
ffff000040085aa8:	d503201f 	nop
ffff000040085aac:	d503201f 	nop
ffff000040085ab0:	d503201f 	nop
ffff000040085ab4:	d503201f 	nop
ffff000040085ab8:	d503201f 	nop
ffff000040085abc:	d503201f 	nop
ffff000040085ac0:	d503201f 	nop
ffff000040085ac4:	d503201f 	nop
ffff000040085ac8:	d503201f 	nop
ffff000040085acc:	d503201f 	nop
ffff000040085ad0:	d503201f 	nop
ffff000040085ad4:	d503201f 	nop
ffff000040085ad8:	d503201f 	nop
ffff000040085adc:	d503201f 	nop
ffff000040085ae0:	d503201f 	nop
ffff000040085ae4:	d503201f 	nop
ffff000040085ae8:	d503201f 	nop
ffff000040085aec:	d503201f 	nop
ffff000040085af0:	d503201f 	nop
ffff000040085af4:	d503201f 	nop
ffff000040085af8:	d503201f 	nop
ffff000040085afc:	d503201f 	nop
	ventry	fiq_invalid_el1h			// FIQ EL1h
ffff000040085b00:	140001a3 	b	ffff00004008618c <fiq_invalid_el1h>
ffff000040085b04:	d503201f 	nop
ffff000040085b08:	d503201f 	nop
ffff000040085b0c:	d503201f 	nop
ffff000040085b10:	d503201f 	nop
ffff000040085b14:	d503201f 	nop
ffff000040085b18:	d503201f 	nop
ffff000040085b1c:	d503201f 	nop
ffff000040085b20:	d503201f 	nop
ffff000040085b24:	d503201f 	nop
ffff000040085b28:	d503201f 	nop
ffff000040085b2c:	d503201f 	nop
ffff000040085b30:	d503201f 	nop
ffff000040085b34:	d503201f 	nop
ffff000040085b38:	d503201f 	nop
ffff000040085b3c:	d503201f 	nop
ffff000040085b40:	d503201f 	nop
ffff000040085b44:	d503201f 	nop
ffff000040085b48:	d503201f 	nop
ffff000040085b4c:	d503201f 	nop
ffff000040085b50:	d503201f 	nop
ffff000040085b54:	d503201f 	nop
ffff000040085b58:	d503201f 	nop
ffff000040085b5c:	d503201f 	nop
ffff000040085b60:	d503201f 	nop
ffff000040085b64:	d503201f 	nop
ffff000040085b68:	d503201f 	nop
ffff000040085b6c:	d503201f 	nop
ffff000040085b70:	d503201f 	nop
ffff000040085b74:	d503201f 	nop
ffff000040085b78:	d503201f 	nop
ffff000040085b7c:	d503201f 	nop
	ventry	error_invalid_el1h			// Error EL1h
ffff000040085b80:	1400019d 	b	ffff0000400861f4 <error_invalid_el1h>
ffff000040085b84:	d503201f 	nop
ffff000040085b88:	d503201f 	nop
ffff000040085b8c:	d503201f 	nop
ffff000040085b90:	d503201f 	nop
ffff000040085b94:	d503201f 	nop
ffff000040085b98:	d503201f 	nop
ffff000040085b9c:	d503201f 	nop
ffff000040085ba0:	d503201f 	nop
ffff000040085ba4:	d503201f 	nop
ffff000040085ba8:	d503201f 	nop
ffff000040085bac:	d503201f 	nop
ffff000040085bb0:	d503201f 	nop
ffff000040085bb4:	d503201f 	nop
ffff000040085bb8:	d503201f 	nop
ffff000040085bbc:	d503201f 	nop
ffff000040085bc0:	d503201f 	nop
ffff000040085bc4:	d503201f 	nop
ffff000040085bc8:	d503201f 	nop
ffff000040085bcc:	d503201f 	nop
ffff000040085bd0:	d503201f 	nop
ffff000040085bd4:	d503201f 	nop
ffff000040085bd8:	d503201f 	nop
ffff000040085bdc:	d503201f 	nop
ffff000040085be0:	d503201f 	nop
ffff000040085be4:	d503201f 	nop
ffff000040085be8:	d503201f 	nop
ffff000040085bec:	d503201f 	nop
ffff000040085bf0:	d503201f 	nop
ffff000040085bf4:	d503201f 	nop
ffff000040085bf8:	d503201f 	nop
ffff000040085bfc:	d503201f 	nop

	ventry	el0_sync				// Synchronous 64-bit EL0 (used for syscalls)
ffff000040085c00:	1400028a 	b	ffff000040086628 <el0_sync>
ffff000040085c04:	d503201f 	nop
ffff000040085c08:	d503201f 	nop
ffff000040085c0c:	d503201f 	nop
ffff000040085c10:	d503201f 	nop
ffff000040085c14:	d503201f 	nop
ffff000040085c18:	d503201f 	nop
ffff000040085c1c:	d503201f 	nop
ffff000040085c20:	d503201f 	nop
ffff000040085c24:	d503201f 	nop
ffff000040085c28:	d503201f 	nop
ffff000040085c2c:	d503201f 	nop
ffff000040085c30:	d503201f 	nop
ffff000040085c34:	d503201f 	nop
ffff000040085c38:	d503201f 	nop
ffff000040085c3c:	d503201f 	nop
ffff000040085c40:	d503201f 	nop
ffff000040085c44:	d503201f 	nop
ffff000040085c48:	d503201f 	nop
ffff000040085c4c:	d503201f 	nop
ffff000040085c50:	d503201f 	nop
ffff000040085c54:	d503201f 	nop
ffff000040085c58:	d503201f 	nop
ffff000040085c5c:	d503201f 	nop
ffff000040085c60:	d503201f 	nop
ffff000040085c64:	d503201f 	nop
ffff000040085c68:	d503201f 	nop
ffff000040085c6c:	d503201f 	nop
ffff000040085c70:	d503201f 	nop
ffff000040085c74:	d503201f 	nop
ffff000040085c78:	d503201f 	nop
ffff000040085c7c:	d503201f 	nop
	ventry	el0_irq					// IRQ 64-bit EL0
ffff000040085c80:	1400023e 	b	ffff000040086578 <el0_irq>
ffff000040085c84:	d503201f 	nop
ffff000040085c88:	d503201f 	nop
ffff000040085c8c:	d503201f 	nop
ffff000040085c90:	d503201f 	nop
ffff000040085c94:	d503201f 	nop
ffff000040085c98:	d503201f 	nop
ffff000040085c9c:	d503201f 	nop
ffff000040085ca0:	d503201f 	nop
ffff000040085ca4:	d503201f 	nop
ffff000040085ca8:	d503201f 	nop
ffff000040085cac:	d503201f 	nop
ffff000040085cb0:	d503201f 	nop
ffff000040085cb4:	d503201f 	nop
ffff000040085cb8:	d503201f 	nop
ffff000040085cbc:	d503201f 	nop
ffff000040085cc0:	d503201f 	nop
ffff000040085cc4:	d503201f 	nop
ffff000040085cc8:	d503201f 	nop
ffff000040085ccc:	d503201f 	nop
ffff000040085cd0:	d503201f 	nop
ffff000040085cd4:	d503201f 	nop
ffff000040085cd8:	d503201f 	nop
ffff000040085cdc:	d503201f 	nop
ffff000040085ce0:	d503201f 	nop
ffff000040085ce4:	d503201f 	nop
ffff000040085ce8:	d503201f 	nop
ffff000040085cec:	d503201f 	nop
ffff000040085cf0:	d503201f 	nop
ffff000040085cf4:	d503201f 	nop
ffff000040085cf8:	d503201f 	nop
ffff000040085cfc:	d503201f 	nop
	ventry	fiq_invalid_el0_64			// FIQ 64-bit EL0
ffff000040085d00:	14000157 	b	ffff00004008625c <fiq_invalid_el0_64>
ffff000040085d04:	d503201f 	nop
ffff000040085d08:	d503201f 	nop
ffff000040085d0c:	d503201f 	nop
ffff000040085d10:	d503201f 	nop
ffff000040085d14:	d503201f 	nop
ffff000040085d18:	d503201f 	nop
ffff000040085d1c:	d503201f 	nop
ffff000040085d20:	d503201f 	nop
ffff000040085d24:	d503201f 	nop
ffff000040085d28:	d503201f 	nop
ffff000040085d2c:	d503201f 	nop
ffff000040085d30:	d503201f 	nop
ffff000040085d34:	d503201f 	nop
ffff000040085d38:	d503201f 	nop
ffff000040085d3c:	d503201f 	nop
ffff000040085d40:	d503201f 	nop
ffff000040085d44:	d503201f 	nop
ffff000040085d48:	d503201f 	nop
ffff000040085d4c:	d503201f 	nop
ffff000040085d50:	d503201f 	nop
ffff000040085d54:	d503201f 	nop
ffff000040085d58:	d503201f 	nop
ffff000040085d5c:	d503201f 	nop
ffff000040085d60:	d503201f 	nop
ffff000040085d64:	d503201f 	nop
ffff000040085d68:	d503201f 	nop
ffff000040085d6c:	d503201f 	nop
ffff000040085d70:	d503201f 	nop
ffff000040085d74:	d503201f 	nop
ffff000040085d78:	d503201f 	nop
ffff000040085d7c:	d503201f 	nop
	ventry	error_invalid_el0_64			// Error 64-bit EL0
ffff000040085d80:	14000151 	b	ffff0000400862c4 <error_invalid_el0_64>
ffff000040085d84:	d503201f 	nop
ffff000040085d88:	d503201f 	nop
ffff000040085d8c:	d503201f 	nop
ffff000040085d90:	d503201f 	nop
ffff000040085d94:	d503201f 	nop
ffff000040085d98:	d503201f 	nop
ffff000040085d9c:	d503201f 	nop
ffff000040085da0:	d503201f 	nop
ffff000040085da4:	d503201f 	nop
ffff000040085da8:	d503201f 	nop
ffff000040085dac:	d503201f 	nop
ffff000040085db0:	d503201f 	nop
ffff000040085db4:	d503201f 	nop
ffff000040085db8:	d503201f 	nop
ffff000040085dbc:	d503201f 	nop
ffff000040085dc0:	d503201f 	nop
ffff000040085dc4:	d503201f 	nop
ffff000040085dc8:	d503201f 	nop
ffff000040085dcc:	d503201f 	nop
ffff000040085dd0:	d503201f 	nop
ffff000040085dd4:	d503201f 	nop
ffff000040085dd8:	d503201f 	nop
ffff000040085ddc:	d503201f 	nop
ffff000040085de0:	d503201f 	nop
ffff000040085de4:	d503201f 	nop
ffff000040085de8:	d503201f 	nop
ffff000040085dec:	d503201f 	nop
ffff000040085df0:	d503201f 	nop
ffff000040085df4:	d503201f 	nop
ffff000040085df8:	d503201f 	nop
ffff000040085dfc:	d503201f 	nop

	ventry	sync_invalid_el0_32			// Synchronous 32-bit EL0
ffff000040085e00:	1400014b 	b	ffff00004008632c <sync_invalid_el0_32>
ffff000040085e04:	d503201f 	nop
ffff000040085e08:	d503201f 	nop
ffff000040085e0c:	d503201f 	nop
ffff000040085e10:	d503201f 	nop
ffff000040085e14:	d503201f 	nop
ffff000040085e18:	d503201f 	nop
ffff000040085e1c:	d503201f 	nop
ffff000040085e20:	d503201f 	nop
ffff000040085e24:	d503201f 	nop
ffff000040085e28:	d503201f 	nop
ffff000040085e2c:	d503201f 	nop
ffff000040085e30:	d503201f 	nop
ffff000040085e34:	d503201f 	nop
ffff000040085e38:	d503201f 	nop
ffff000040085e3c:	d503201f 	nop
ffff000040085e40:	d503201f 	nop
ffff000040085e44:	d503201f 	nop
ffff000040085e48:	d503201f 	nop
ffff000040085e4c:	d503201f 	nop
ffff000040085e50:	d503201f 	nop
ffff000040085e54:	d503201f 	nop
ffff000040085e58:	d503201f 	nop
ffff000040085e5c:	d503201f 	nop
ffff000040085e60:	d503201f 	nop
ffff000040085e64:	d503201f 	nop
ffff000040085e68:	d503201f 	nop
ffff000040085e6c:	d503201f 	nop
ffff000040085e70:	d503201f 	nop
ffff000040085e74:	d503201f 	nop
ffff000040085e78:	d503201f 	nop
ffff000040085e7c:	d503201f 	nop
	ventry	irq_invalid_el0_32			// IRQ 32-bit EL0
ffff000040085e80:	14000145 	b	ffff000040086394 <irq_invalid_el0_32>
ffff000040085e84:	d503201f 	nop
ffff000040085e88:	d503201f 	nop
ffff000040085e8c:	d503201f 	nop
ffff000040085e90:	d503201f 	nop
ffff000040085e94:	d503201f 	nop
ffff000040085e98:	d503201f 	nop
ffff000040085e9c:	d503201f 	nop
ffff000040085ea0:	d503201f 	nop
ffff000040085ea4:	d503201f 	nop
ffff000040085ea8:	d503201f 	nop
ffff000040085eac:	d503201f 	nop
ffff000040085eb0:	d503201f 	nop
ffff000040085eb4:	d503201f 	nop
ffff000040085eb8:	d503201f 	nop
ffff000040085ebc:	d503201f 	nop
ffff000040085ec0:	d503201f 	nop
ffff000040085ec4:	d503201f 	nop
ffff000040085ec8:	d503201f 	nop
ffff000040085ecc:	d503201f 	nop
ffff000040085ed0:	d503201f 	nop
ffff000040085ed4:	d503201f 	nop
ffff000040085ed8:	d503201f 	nop
ffff000040085edc:	d503201f 	nop
ffff000040085ee0:	d503201f 	nop
ffff000040085ee4:	d503201f 	nop
ffff000040085ee8:	d503201f 	nop
ffff000040085eec:	d503201f 	nop
ffff000040085ef0:	d503201f 	nop
ffff000040085ef4:	d503201f 	nop
ffff000040085ef8:	d503201f 	nop
ffff000040085efc:	d503201f 	nop
	ventry	fiq_invalid_el0_32			// FIQ 32-bit EL0
ffff000040085f00:	1400013f 	b	ffff0000400863fc <fiq_invalid_el0_32>
ffff000040085f04:	d503201f 	nop
ffff000040085f08:	d503201f 	nop
ffff000040085f0c:	d503201f 	nop
ffff000040085f10:	d503201f 	nop
ffff000040085f14:	d503201f 	nop
ffff000040085f18:	d503201f 	nop
ffff000040085f1c:	d503201f 	nop
ffff000040085f20:	d503201f 	nop
ffff000040085f24:	d503201f 	nop
ffff000040085f28:	d503201f 	nop
ffff000040085f2c:	d503201f 	nop
ffff000040085f30:	d503201f 	nop
ffff000040085f34:	d503201f 	nop
ffff000040085f38:	d503201f 	nop
ffff000040085f3c:	d503201f 	nop
ffff000040085f40:	d503201f 	nop
ffff000040085f44:	d503201f 	nop
ffff000040085f48:	d503201f 	nop
ffff000040085f4c:	d503201f 	nop
ffff000040085f50:	d503201f 	nop
ffff000040085f54:	d503201f 	nop
ffff000040085f58:	d503201f 	nop
ffff000040085f5c:	d503201f 	nop
ffff000040085f60:	d503201f 	nop
ffff000040085f64:	d503201f 	nop
ffff000040085f68:	d503201f 	nop
ffff000040085f6c:	d503201f 	nop
ffff000040085f70:	d503201f 	nop
ffff000040085f74:	d503201f 	nop
ffff000040085f78:	d503201f 	nop
ffff000040085f7c:	d503201f 	nop
	ventry	error_invalid_el0_32			// Error 32-bit EL0
ffff000040085f80:	14000139 	b	ffff000040086464 <error_invalid_el0_32>

ffff000040085f84 <sync_invalid_el1t>:

sync_invalid_el1t:
	handle_invalid_entry 1,  SYNC_INVALID_EL1t
ffff000040085f84:	d10443ff 	sub	sp, sp, #0x110
ffff000040085f88:	a90007e0 	stp	x0, x1, [sp]
ffff000040085f8c:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff000040085f90:	a90217e4 	stp	x4, x5, [sp, #32]
ffff000040085f94:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff000040085f98:	a90427e8 	stp	x8, x9, [sp, #64]
ffff000040085f9c:	a9052fea 	stp	x10, x11, [sp, #80]
ffff000040085fa0:	a90637ec 	stp	x12, x13, [sp, #96]
ffff000040085fa4:	a9073fee 	stp	x14, x15, [sp, #112]
ffff000040085fa8:	a90847f0 	stp	x16, x17, [sp, #128]
ffff000040085fac:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff000040085fb0:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff000040085fb4:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff000040085fb8:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff000040085fbc:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff000040085fc0:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff000040085fc4:	910443f5 	add	x21, sp, #0x110
ffff000040085fc8:	d5384036 	mrs	x22, elr_el1
ffff000040085fcc:	d5384017 	mrs	x23, spsr_el1
ffff000040085fd0:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff000040085fd4:	a9105ff6 	stp	x22, x23, [sp, #256]
ffff000040085fd8:	d2800000 	mov	x0, #0x0                   	// #0
ffff000040085fdc:	d5385201 	mrs	x1, esr_el1
ffff000040085fe0:	d5384022 	mrs	x2, elr_el1
ffff000040085fe4:	97fff0eb 	bl	ffff000040082390 <show_invalid_entry_message>
ffff000040085fe8:	14000252 	b	ffff000040086930 <err_hang>

ffff000040085fec <irq_invalid_el1t>:

irq_invalid_el1t:
	handle_invalid_entry  1, IRQ_INVALID_EL1t
ffff000040085fec:	d10443ff 	sub	sp, sp, #0x110
ffff000040085ff0:	a90007e0 	stp	x0, x1, [sp]
ffff000040085ff4:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff000040085ff8:	a90217e4 	stp	x4, x5, [sp, #32]
ffff000040085ffc:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff000040086000:	a90427e8 	stp	x8, x9, [sp, #64]
ffff000040086004:	a9052fea 	stp	x10, x11, [sp, #80]
ffff000040086008:	a90637ec 	stp	x12, x13, [sp, #96]
ffff00004008600c:	a9073fee 	stp	x14, x15, [sp, #112]
ffff000040086010:	a90847f0 	stp	x16, x17, [sp, #128]
ffff000040086014:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff000040086018:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff00004008601c:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff000040086020:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff000040086024:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff000040086028:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff00004008602c:	910443f5 	add	x21, sp, #0x110
ffff000040086030:	d5384036 	mrs	x22, elr_el1
ffff000040086034:	d5384017 	mrs	x23, spsr_el1
ffff000040086038:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff00004008603c:	a9105ff6 	stp	x22, x23, [sp, #256]
ffff000040086040:	d2800020 	mov	x0, #0x1                   	// #1
ffff000040086044:	d5385201 	mrs	x1, esr_el1
ffff000040086048:	d5384022 	mrs	x2, elr_el1
ffff00004008604c:	97fff0d1 	bl	ffff000040082390 <show_invalid_entry_message>
ffff000040086050:	14000238 	b	ffff000040086930 <err_hang>

ffff000040086054 <fiq_invalid_el1t>:

fiq_invalid_el1t:
	handle_invalid_entry  1, FIQ_INVALID_EL1t
ffff000040086054:	d10443ff 	sub	sp, sp, #0x110
ffff000040086058:	a90007e0 	stp	x0, x1, [sp]
ffff00004008605c:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff000040086060:	a90217e4 	stp	x4, x5, [sp, #32]
ffff000040086064:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff000040086068:	a90427e8 	stp	x8, x9, [sp, #64]
ffff00004008606c:	a9052fea 	stp	x10, x11, [sp, #80]
ffff000040086070:	a90637ec 	stp	x12, x13, [sp, #96]
ffff000040086074:	a9073fee 	stp	x14, x15, [sp, #112]
ffff000040086078:	a90847f0 	stp	x16, x17, [sp, #128]
ffff00004008607c:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff000040086080:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff000040086084:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff000040086088:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff00004008608c:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff000040086090:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff000040086094:	910443f5 	add	x21, sp, #0x110
ffff000040086098:	d5384036 	mrs	x22, elr_el1
ffff00004008609c:	d5384017 	mrs	x23, spsr_el1
ffff0000400860a0:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff0000400860a4:	a9105ff6 	stp	x22, x23, [sp, #256]
ffff0000400860a8:	d2800040 	mov	x0, #0x2                   	// #2
ffff0000400860ac:	d5385201 	mrs	x1, esr_el1
ffff0000400860b0:	d5384022 	mrs	x2, elr_el1
ffff0000400860b4:	97fff0b7 	bl	ffff000040082390 <show_invalid_entry_message>
ffff0000400860b8:	1400021e 	b	ffff000040086930 <err_hang>

ffff0000400860bc <error_invalid_el1t>:

error_invalid_el1t:
	handle_invalid_entry  1, ERROR_INVALID_EL1t
ffff0000400860bc:	d10443ff 	sub	sp, sp, #0x110
ffff0000400860c0:	a90007e0 	stp	x0, x1, [sp]
ffff0000400860c4:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff0000400860c8:	a90217e4 	stp	x4, x5, [sp, #32]
ffff0000400860cc:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff0000400860d0:	a90427e8 	stp	x8, x9, [sp, #64]
ffff0000400860d4:	a9052fea 	stp	x10, x11, [sp, #80]
ffff0000400860d8:	a90637ec 	stp	x12, x13, [sp, #96]
ffff0000400860dc:	a9073fee 	stp	x14, x15, [sp, #112]
ffff0000400860e0:	a90847f0 	stp	x16, x17, [sp, #128]
ffff0000400860e4:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff0000400860e8:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff0000400860ec:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff0000400860f0:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff0000400860f4:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff0000400860f8:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff0000400860fc:	910443f5 	add	x21, sp, #0x110
ffff000040086100:	d5384036 	mrs	x22, elr_el1
ffff000040086104:	d5384017 	mrs	x23, spsr_el1
ffff000040086108:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff00004008610c:	a9105ff6 	stp	x22, x23, [sp, #256]
ffff000040086110:	d2800060 	mov	x0, #0x3                   	// #3
ffff000040086114:	d5385201 	mrs	x1, esr_el1
ffff000040086118:	d5384022 	mrs	x2, elr_el1
ffff00004008611c:	97fff09d 	bl	ffff000040082390 <show_invalid_entry_message>
ffff000040086120:	14000204 	b	ffff000040086930 <err_hang>

ffff000040086124 <sync_invalid_el1h>:

sync_invalid_el1h:
	handle_invalid_entry 1, SYNC_INVALID_EL1h
ffff000040086124:	d10443ff 	sub	sp, sp, #0x110
ffff000040086128:	a90007e0 	stp	x0, x1, [sp]
ffff00004008612c:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff000040086130:	a90217e4 	stp	x4, x5, [sp, #32]
ffff000040086134:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff000040086138:	a90427e8 	stp	x8, x9, [sp, #64]
ffff00004008613c:	a9052fea 	stp	x10, x11, [sp, #80]
ffff000040086140:	a90637ec 	stp	x12, x13, [sp, #96]
ffff000040086144:	a9073fee 	stp	x14, x15, [sp, #112]
ffff000040086148:	a90847f0 	stp	x16, x17, [sp, #128]
ffff00004008614c:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff000040086150:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff000040086154:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff000040086158:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff00004008615c:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff000040086160:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff000040086164:	910443f5 	add	x21, sp, #0x110
ffff000040086168:	d5384036 	mrs	x22, elr_el1
ffff00004008616c:	d5384017 	mrs	x23, spsr_el1
ffff000040086170:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff000040086174:	a9105ff6 	stp	x22, x23, [sp, #256]
ffff000040086178:	d2800080 	mov	x0, #0x4                   	// #4
ffff00004008617c:	d5385201 	mrs	x1, esr_el1
ffff000040086180:	d5384022 	mrs	x2, elr_el1
ffff000040086184:	97fff083 	bl	ffff000040082390 <show_invalid_entry_message>
ffff000040086188:	140001ea 	b	ffff000040086930 <err_hang>

ffff00004008618c <fiq_invalid_el1h>:

fiq_invalid_el1h:
	handle_invalid_entry  1, FIQ_INVALID_EL1h
ffff00004008618c:	d10443ff 	sub	sp, sp, #0x110
ffff000040086190:	a90007e0 	stp	x0, x1, [sp]
ffff000040086194:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff000040086198:	a90217e4 	stp	x4, x5, [sp, #32]
ffff00004008619c:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff0000400861a0:	a90427e8 	stp	x8, x9, [sp, #64]
ffff0000400861a4:	a9052fea 	stp	x10, x11, [sp, #80]
ffff0000400861a8:	a90637ec 	stp	x12, x13, [sp, #96]
ffff0000400861ac:	a9073fee 	stp	x14, x15, [sp, #112]
ffff0000400861b0:	a90847f0 	stp	x16, x17, [sp, #128]
ffff0000400861b4:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff0000400861b8:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff0000400861bc:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff0000400861c0:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff0000400861c4:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff0000400861c8:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff0000400861cc:	910443f5 	add	x21, sp, #0x110
ffff0000400861d0:	d5384036 	mrs	x22, elr_el1
ffff0000400861d4:	d5384017 	mrs	x23, spsr_el1
ffff0000400861d8:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff0000400861dc:	a9105ff6 	stp	x22, x23, [sp, #256]
ffff0000400861e0:	d28000a0 	mov	x0, #0x5                   	// #5
ffff0000400861e4:	d5385201 	mrs	x1, esr_el1
ffff0000400861e8:	d5384022 	mrs	x2, elr_el1
ffff0000400861ec:	97fff069 	bl	ffff000040082390 <show_invalid_entry_message>
ffff0000400861f0:	140001d0 	b	ffff000040086930 <err_hang>

ffff0000400861f4 <error_invalid_el1h>:

error_invalid_el1h:
	handle_invalid_entry  1, ERROR_INVALID_EL1h
ffff0000400861f4:	d10443ff 	sub	sp, sp, #0x110
ffff0000400861f8:	a90007e0 	stp	x0, x1, [sp]
ffff0000400861fc:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff000040086200:	a90217e4 	stp	x4, x5, [sp, #32]
ffff000040086204:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff000040086208:	a90427e8 	stp	x8, x9, [sp, #64]
ffff00004008620c:	a9052fea 	stp	x10, x11, [sp, #80]
ffff000040086210:	a90637ec 	stp	x12, x13, [sp, #96]
ffff000040086214:	a9073fee 	stp	x14, x15, [sp, #112]
ffff000040086218:	a90847f0 	stp	x16, x17, [sp, #128]
ffff00004008621c:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff000040086220:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff000040086224:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff000040086228:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff00004008622c:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff000040086230:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff000040086234:	910443f5 	add	x21, sp, #0x110
ffff000040086238:	d5384036 	mrs	x22, elr_el1
ffff00004008623c:	d5384017 	mrs	x23, spsr_el1
ffff000040086240:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff000040086244:	a9105ff6 	stp	x22, x23, [sp, #256]
ffff000040086248:	d28000c0 	mov	x0, #0x6                   	// #6
ffff00004008624c:	d5385201 	mrs	x1, esr_el1
ffff000040086250:	d5384022 	mrs	x2, elr_el1
ffff000040086254:	97fff04f 	bl	ffff000040082390 <show_invalid_entry_message>
ffff000040086258:	140001b6 	b	ffff000040086930 <err_hang>

ffff00004008625c <fiq_invalid_el0_64>:

fiq_invalid_el0_64:
	handle_invalid_entry  0, FIQ_INVALID_EL0_64
ffff00004008625c:	d10443ff 	sub	sp, sp, #0x110
ffff000040086260:	a90007e0 	stp	x0, x1, [sp]
ffff000040086264:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff000040086268:	a90217e4 	stp	x4, x5, [sp, #32]
ffff00004008626c:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff000040086270:	a90427e8 	stp	x8, x9, [sp, #64]
ffff000040086274:	a9052fea 	stp	x10, x11, [sp, #80]
ffff000040086278:	a90637ec 	stp	x12, x13, [sp, #96]
ffff00004008627c:	a9073fee 	stp	x14, x15, [sp, #112]
ffff000040086280:	a90847f0 	stp	x16, x17, [sp, #128]
ffff000040086284:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff000040086288:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff00004008628c:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff000040086290:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff000040086294:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff000040086298:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff00004008629c:	d5384115 	mrs	x21, sp_el0
ffff0000400862a0:	d5384036 	mrs	x22, elr_el1
ffff0000400862a4:	d5384017 	mrs	x23, spsr_el1
ffff0000400862a8:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff0000400862ac:	a9105ff6 	stp	x22, x23, [sp, #256]
ffff0000400862b0:	d28000e0 	mov	x0, #0x7                   	// #7
ffff0000400862b4:	d5385201 	mrs	x1, esr_el1
ffff0000400862b8:	d5384022 	mrs	x2, elr_el1
ffff0000400862bc:	97fff035 	bl	ffff000040082390 <show_invalid_entry_message>
ffff0000400862c0:	1400019c 	b	ffff000040086930 <err_hang>

ffff0000400862c4 <error_invalid_el0_64>:

error_invalid_el0_64:
	handle_invalid_entry  0, ERROR_INVALID_EL0_64
ffff0000400862c4:	d10443ff 	sub	sp, sp, #0x110
ffff0000400862c8:	a90007e0 	stp	x0, x1, [sp]
ffff0000400862cc:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff0000400862d0:	a90217e4 	stp	x4, x5, [sp, #32]
ffff0000400862d4:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff0000400862d8:	a90427e8 	stp	x8, x9, [sp, #64]
ffff0000400862dc:	a9052fea 	stp	x10, x11, [sp, #80]
ffff0000400862e0:	a90637ec 	stp	x12, x13, [sp, #96]
ffff0000400862e4:	a9073fee 	stp	x14, x15, [sp, #112]
ffff0000400862e8:	a90847f0 	stp	x16, x17, [sp, #128]
ffff0000400862ec:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff0000400862f0:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff0000400862f4:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff0000400862f8:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff0000400862fc:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff000040086300:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff000040086304:	d5384115 	mrs	x21, sp_el0
ffff000040086308:	d5384036 	mrs	x22, elr_el1
ffff00004008630c:	d5384017 	mrs	x23, spsr_el1
ffff000040086310:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff000040086314:	a9105ff6 	stp	x22, x23, [sp, #256]
ffff000040086318:	d2800100 	mov	x0, #0x8                   	// #8
ffff00004008631c:	d5385201 	mrs	x1, esr_el1
ffff000040086320:	d5384022 	mrs	x2, elr_el1
ffff000040086324:	97fff01b 	bl	ffff000040082390 <show_invalid_entry_message>
ffff000040086328:	14000182 	b	ffff000040086930 <err_hang>

ffff00004008632c <sync_invalid_el0_32>:

sync_invalid_el0_32:
	handle_invalid_entry  0, SYNC_INVALID_EL0_32
ffff00004008632c:	d10443ff 	sub	sp, sp, #0x110
ffff000040086330:	a90007e0 	stp	x0, x1, [sp]
ffff000040086334:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff000040086338:	a90217e4 	stp	x4, x5, [sp, #32]
ffff00004008633c:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff000040086340:	a90427e8 	stp	x8, x9, [sp, #64]
ffff000040086344:	a9052fea 	stp	x10, x11, [sp, #80]
ffff000040086348:	a90637ec 	stp	x12, x13, [sp, #96]
ffff00004008634c:	a9073fee 	stp	x14, x15, [sp, #112]
ffff000040086350:	a90847f0 	stp	x16, x17, [sp, #128]
ffff000040086354:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff000040086358:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff00004008635c:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff000040086360:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff000040086364:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff000040086368:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff00004008636c:	d5384115 	mrs	x21, sp_el0
ffff000040086370:	d5384036 	mrs	x22, elr_el1
ffff000040086374:	d5384017 	mrs	x23, spsr_el1
ffff000040086378:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff00004008637c:	a9105ff6 	stp	x22, x23, [sp, #256]
ffff000040086380:	d2800120 	mov	x0, #0x9                   	// #9
ffff000040086384:	d5385201 	mrs	x1, esr_el1
ffff000040086388:	d5384022 	mrs	x2, elr_el1
ffff00004008638c:	97fff001 	bl	ffff000040082390 <show_invalid_entry_message>
ffff000040086390:	14000168 	b	ffff000040086930 <err_hang>

ffff000040086394 <irq_invalid_el0_32>:

irq_invalid_el0_32:
	handle_invalid_entry  0, IRQ_INVALID_EL0_32
ffff000040086394:	d10443ff 	sub	sp, sp, #0x110
ffff000040086398:	a90007e0 	stp	x0, x1, [sp]
ffff00004008639c:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff0000400863a0:	a90217e4 	stp	x4, x5, [sp, #32]
ffff0000400863a4:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff0000400863a8:	a90427e8 	stp	x8, x9, [sp, #64]
ffff0000400863ac:	a9052fea 	stp	x10, x11, [sp, #80]
ffff0000400863b0:	a90637ec 	stp	x12, x13, [sp, #96]
ffff0000400863b4:	a9073fee 	stp	x14, x15, [sp, #112]
ffff0000400863b8:	a90847f0 	stp	x16, x17, [sp, #128]
ffff0000400863bc:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff0000400863c0:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff0000400863c4:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff0000400863c8:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff0000400863cc:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff0000400863d0:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff0000400863d4:	d5384115 	mrs	x21, sp_el0
ffff0000400863d8:	d5384036 	mrs	x22, elr_el1
ffff0000400863dc:	d5384017 	mrs	x23, spsr_el1
ffff0000400863e0:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff0000400863e4:	a9105ff6 	stp	x22, x23, [sp, #256]
ffff0000400863e8:	d2800140 	mov	x0, #0xa                   	// #10
ffff0000400863ec:	d5385201 	mrs	x1, esr_el1
ffff0000400863f0:	d5384022 	mrs	x2, elr_el1
ffff0000400863f4:	97ffefe7 	bl	ffff000040082390 <show_invalid_entry_message>
ffff0000400863f8:	1400014e 	b	ffff000040086930 <err_hang>

ffff0000400863fc <fiq_invalid_el0_32>:

fiq_invalid_el0_32:
	handle_invalid_entry  0, FIQ_INVALID_EL0_32
ffff0000400863fc:	d10443ff 	sub	sp, sp, #0x110
ffff000040086400:	a90007e0 	stp	x0, x1, [sp]
ffff000040086404:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff000040086408:	a90217e4 	stp	x4, x5, [sp, #32]
ffff00004008640c:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff000040086410:	a90427e8 	stp	x8, x9, [sp, #64]
ffff000040086414:	a9052fea 	stp	x10, x11, [sp, #80]
ffff000040086418:	a90637ec 	stp	x12, x13, [sp, #96]
ffff00004008641c:	a9073fee 	stp	x14, x15, [sp, #112]
ffff000040086420:	a90847f0 	stp	x16, x17, [sp, #128]
ffff000040086424:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff000040086428:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff00004008642c:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff000040086430:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff000040086434:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff000040086438:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff00004008643c:	d5384115 	mrs	x21, sp_el0
ffff000040086440:	d5384036 	mrs	x22, elr_el1
ffff000040086444:	d5384017 	mrs	x23, spsr_el1
ffff000040086448:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff00004008644c:	a9105ff6 	stp	x22, x23, [sp, #256]
ffff000040086450:	d2800160 	mov	x0, #0xb                   	// #11
ffff000040086454:	d5385201 	mrs	x1, esr_el1
ffff000040086458:	d5384022 	mrs	x2, elr_el1
ffff00004008645c:	97ffefcd 	bl	ffff000040082390 <show_invalid_entry_message>
ffff000040086460:	14000134 	b	ffff000040086930 <err_hang>

ffff000040086464 <error_invalid_el0_32>:

error_invalid_el0_32:
	handle_invalid_entry  0, ERROR_INVALID_EL0_32
ffff000040086464:	d10443ff 	sub	sp, sp, #0x110
ffff000040086468:	a90007e0 	stp	x0, x1, [sp]
ffff00004008646c:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff000040086470:	a90217e4 	stp	x4, x5, [sp, #32]
ffff000040086474:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff000040086478:	a90427e8 	stp	x8, x9, [sp, #64]
ffff00004008647c:	a9052fea 	stp	x10, x11, [sp, #80]
ffff000040086480:	a90637ec 	stp	x12, x13, [sp, #96]
ffff000040086484:	a9073fee 	stp	x14, x15, [sp, #112]
ffff000040086488:	a90847f0 	stp	x16, x17, [sp, #128]
ffff00004008648c:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff000040086490:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff000040086494:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff000040086498:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff00004008649c:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff0000400864a0:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff0000400864a4:	d5384115 	mrs	x21, sp_el0
ffff0000400864a8:	d5384036 	mrs	x22, elr_el1
ffff0000400864ac:	d5384017 	mrs	x23, spsr_el1
ffff0000400864b0:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff0000400864b4:	a9105ff6 	stp	x22, x23, [sp, #256]
ffff0000400864b8:	d2800180 	mov	x0, #0xc                   	// #12
ffff0000400864bc:	d5385201 	mrs	x1, esr_el1
ffff0000400864c0:	d5384022 	mrs	x2, elr_el1
ffff0000400864c4:	97ffefb3 	bl	ffff000040082390 <show_invalid_entry_message>
ffff0000400864c8:	1400011a 	b	ffff000040086930 <err_hang>

ffff0000400864cc <el1_irq>:

el1_irq:
	kernel_entry 1 
ffff0000400864cc:	d10443ff 	sub	sp, sp, #0x110
ffff0000400864d0:	a90007e0 	stp	x0, x1, [sp]
ffff0000400864d4:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff0000400864d8:	a90217e4 	stp	x4, x5, [sp, #32]
ffff0000400864dc:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff0000400864e0:	a90427e8 	stp	x8, x9, [sp, #64]
ffff0000400864e4:	a9052fea 	stp	x10, x11, [sp, #80]
ffff0000400864e8:	a90637ec 	stp	x12, x13, [sp, #96]
ffff0000400864ec:	a9073fee 	stp	x14, x15, [sp, #112]
ffff0000400864f0:	a90847f0 	stp	x16, x17, [sp, #128]
ffff0000400864f4:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff0000400864f8:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff0000400864fc:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff000040086500:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff000040086504:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff000040086508:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff00004008650c:	910443f5 	add	x21, sp, #0x110
ffff000040086510:	d5384036 	mrs	x22, elr_el1
ffff000040086514:	d5384017 	mrs	x23, spsr_el1
ffff000040086518:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff00004008651c:	a9105ff6 	stp	x22, x23, [sp, #256]
	bl	handle_irq
ffff000040086520:	97ffefae 	bl	ffff0000400823d8 <handle_irq>
	kernel_exit 1 
ffff000040086524:	a9505ff6 	ldp	x22, x23, [sp, #256]
ffff000040086528:	a94f57fe 	ldp	x30, x21, [sp, #240]
ffff00004008652c:	d5184036 	msr	elr_el1, x22
ffff000040086530:	d5184017 	msr	spsr_el1, x23
ffff000040086534:	a94007e0 	ldp	x0, x1, [sp]
ffff000040086538:	a9410fe2 	ldp	x2, x3, [sp, #16]
ffff00004008653c:	a94217e4 	ldp	x4, x5, [sp, #32]
ffff000040086540:	a9431fe6 	ldp	x6, x7, [sp, #48]
ffff000040086544:	a94427e8 	ldp	x8, x9, [sp, #64]
ffff000040086548:	a9452fea 	ldp	x10, x11, [sp, #80]
ffff00004008654c:	a94637ec 	ldp	x12, x13, [sp, #96]
ffff000040086550:	a9473fee 	ldp	x14, x15, [sp, #112]
ffff000040086554:	a94847f0 	ldp	x16, x17, [sp, #128]
ffff000040086558:	a9494ff2 	ldp	x18, x19, [sp, #144]
ffff00004008655c:	a94a57f4 	ldp	x20, x21, [sp, #160]
ffff000040086560:	a94b5ff6 	ldp	x22, x23, [sp, #176]
ffff000040086564:	a94c67f8 	ldp	x24, x25, [sp, #192]
ffff000040086568:	a94d6ffa 	ldp	x26, x27, [sp, #208]
ffff00004008656c:	a94e77fc 	ldp	x28, x29, [sp, #224]
ffff000040086570:	910443ff 	add	sp, sp, #0x110
ffff000040086574:	d69f03e0 	eret

ffff000040086578 <el0_irq>:

el0_irq:
	kernel_entry 0 
ffff000040086578:	d10443ff 	sub	sp, sp, #0x110
ffff00004008657c:	a90007e0 	stp	x0, x1, [sp]
ffff000040086580:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff000040086584:	a90217e4 	stp	x4, x5, [sp, #32]
ffff000040086588:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff00004008658c:	a90427e8 	stp	x8, x9, [sp, #64]
ffff000040086590:	a9052fea 	stp	x10, x11, [sp, #80]
ffff000040086594:	a90637ec 	stp	x12, x13, [sp, #96]
ffff000040086598:	a9073fee 	stp	x14, x15, [sp, #112]
ffff00004008659c:	a90847f0 	stp	x16, x17, [sp, #128]
ffff0000400865a0:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff0000400865a4:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff0000400865a8:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff0000400865ac:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff0000400865b0:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff0000400865b4:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff0000400865b8:	d5384115 	mrs	x21, sp_el0
ffff0000400865bc:	d5384036 	mrs	x22, elr_el1
ffff0000400865c0:	d5384017 	mrs	x23, spsr_el1
ffff0000400865c4:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff0000400865c8:	a9105ff6 	stp	x22, x23, [sp, #256]
	bl	handle_irq
ffff0000400865cc:	97ffef83 	bl	ffff0000400823d8 <handle_irq>
	kernel_exit 0 
ffff0000400865d0:	a9505ff6 	ldp	x22, x23, [sp, #256]
ffff0000400865d4:	a94f57fe 	ldp	x30, x21, [sp, #240]
ffff0000400865d8:	d5184115 	msr	sp_el0, x21
ffff0000400865dc:	d5184036 	msr	elr_el1, x22
ffff0000400865e0:	d5184017 	msr	spsr_el1, x23
ffff0000400865e4:	a94007e0 	ldp	x0, x1, [sp]
ffff0000400865e8:	a9410fe2 	ldp	x2, x3, [sp, #16]
ffff0000400865ec:	a94217e4 	ldp	x4, x5, [sp, #32]
ffff0000400865f0:	a9431fe6 	ldp	x6, x7, [sp, #48]
ffff0000400865f4:	a94427e8 	ldp	x8, x9, [sp, #64]
ffff0000400865f8:	a9452fea 	ldp	x10, x11, [sp, #80]
ffff0000400865fc:	a94637ec 	ldp	x12, x13, [sp, #96]
ffff000040086600:	a9473fee 	ldp	x14, x15, [sp, #112]
ffff000040086604:	a94847f0 	ldp	x16, x17, [sp, #128]
ffff000040086608:	a9494ff2 	ldp	x18, x19, [sp, #144]
ffff00004008660c:	a94a57f4 	ldp	x20, x21, [sp, #160]
ffff000040086610:	a94b5ff6 	ldp	x22, x23, [sp, #176]
ffff000040086614:	a94c67f8 	ldp	x24, x25, [sp, #192]
ffff000040086618:	a94d6ffa 	ldp	x26, x27, [sp, #208]
ffff00004008661c:	a94e77fc 	ldp	x28, x29, [sp, #224]
ffff000040086620:	910443ff 	add	sp, sp, #0x110
ffff000040086624:	d69f03e0 	eret

ffff000040086628 <el0_sync>:

// the syscall path (from irq vector)
el0_sync:
	kernel_entry 0
ffff000040086628:	d10443ff 	sub	sp, sp, #0x110
ffff00004008662c:	a90007e0 	stp	x0, x1, [sp]
ffff000040086630:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff000040086634:	a90217e4 	stp	x4, x5, [sp, #32]
ffff000040086638:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff00004008663c:	a90427e8 	stp	x8, x9, [sp, #64]
ffff000040086640:	a9052fea 	stp	x10, x11, [sp, #80]
ffff000040086644:	a90637ec 	stp	x12, x13, [sp, #96]
ffff000040086648:	a9073fee 	stp	x14, x15, [sp, #112]
ffff00004008664c:	a90847f0 	stp	x16, x17, [sp, #128]
ffff000040086650:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff000040086654:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff000040086658:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff00004008665c:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff000040086660:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff000040086664:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff000040086668:	d5384115 	mrs	x21, sp_el0
ffff00004008666c:	d5384036 	mrs	x22, elr_el1
ffff000040086670:	d5384017 	mrs	x23, spsr_el1
ffff000040086674:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff000040086678:	a9105ff6 	stp	x22, x23, [sp, #256]
	mrs	x25, esr_el1					// read the syndrome register
ffff00004008667c:	d5385219 	mrs	x25, esr_el1
	lsr	x24, x25, #ESR_ELx_EC_SHIFT		// exception class
ffff000040086680:	d35aff38 	lsr	x24, x25, #26
	cmp	x24, #ESR_ELx_EC_SVC64			// is the currrent exception caused by SVC in 64-bit state? 
ffff000040086684:	f100571f 	cmp	x24, #0x15
	b.eq	el0_svc						// if yes, jump to below for handling syscalls 
ffff000040086688:	540003a0 	b.eq	ffff0000400866fc <el0_svc>  // b.none
	cmp	x24, #ESR_ELx_EC_DABT_LOW		// is data abort in EL0?
ffff00004008668c:	f100931f 	cmp	x24, #0x24
	b.eq	el0_da						// if yes, handle it
ffff000040086690:	54000ac0 	b.eq	ffff0000400867e8 <el0_da>  // b.none
	handle_invalid_entry 0, SYNC_ERROR
ffff000040086694:	d10443ff 	sub	sp, sp, #0x110
ffff000040086698:	a90007e0 	stp	x0, x1, [sp]
ffff00004008669c:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff0000400866a0:	a90217e4 	stp	x4, x5, [sp, #32]
ffff0000400866a4:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff0000400866a8:	a90427e8 	stp	x8, x9, [sp, #64]
ffff0000400866ac:	a9052fea 	stp	x10, x11, [sp, #80]
ffff0000400866b0:	a90637ec 	stp	x12, x13, [sp, #96]
ffff0000400866b4:	a9073fee 	stp	x14, x15, [sp, #112]
ffff0000400866b8:	a90847f0 	stp	x16, x17, [sp, #128]
ffff0000400866bc:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff0000400866c0:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff0000400866c4:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff0000400866c8:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff0000400866cc:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff0000400866d0:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff0000400866d4:	d5384115 	mrs	x21, sp_el0
ffff0000400866d8:	d5384036 	mrs	x22, elr_el1
ffff0000400866dc:	d5384017 	mrs	x23, spsr_el1
ffff0000400866e0:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff0000400866e4:	a9105ff6 	stp	x22, x23, [sp, #256]
ffff0000400866e8:	d28001a0 	mov	x0, #0xd                   	// #13
ffff0000400866ec:	d5385201 	mrs	x1, esr_el1
ffff0000400866f0:	d5384022 	mrs	x2, elr_el1
ffff0000400866f4:	97ffef27 	bl	ffff000040082390 <show_invalid_entry_message>
ffff0000400866f8:	1400008e 	b	ffff000040086930 <err_hang>

ffff0000400866fc <el0_svc>:
scno	.req	x26					// syscall number
stbl	.req	x27					// syscall table pointer

// the syscall path (cont'd)
el0_svc:
	adr	stbl, sys_call_table			// load syscall table pointer
ffff0000400866fc:	107de1bb 	adr	x27, ffff000040182330 <sys_call_table>
	uxtw	scno, w8					// syscall number in w8
ffff000040086700:	2a0803fa 	mov	w26, w8
	mov	sc_nr, #__NR_syscalls
ffff000040086704:	d2800079 	mov	x25, #0x3                   	// #3
	bl	enable_irq
ffff000040086708:	97fffae8 	bl	ffff0000400852a8 <enable_irq>
	cmp     scno, sc_nr                 // syscall number >= upper syscall limit?			
ffff00004008670c:	eb19035f 	cmp	x26, x25
	b.hs	ni_sys						// if yes, jump to handle errors
ffff000040086710:	54000082 	b.cs	ffff000040086720 <ni_sys>  // b.hs, b.nlast

	ldr	x16, [stbl, scno, lsl #3]		// address in the syscall table
ffff000040086714:	f87a7b70 	ldr	x16, [x27, x26, lsl #3]
	blr	x16								// call sys_* routine
ffff000040086718:	d63f0200 	blr	x16
	b	ret_from_syscall
ffff00004008671c:	1400001b 	b	ffff000040086788 <ret_from_syscall>

ffff000040086720 <ni_sys>:
ni_sys:
	handle_invalid_entry 0, SYSCALL_ERROR
ffff000040086720:	d10443ff 	sub	sp, sp, #0x110
ffff000040086724:	a90007e0 	stp	x0, x1, [sp]
ffff000040086728:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff00004008672c:	a90217e4 	stp	x4, x5, [sp, #32]
ffff000040086730:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff000040086734:	a90427e8 	stp	x8, x9, [sp, #64]
ffff000040086738:	a9052fea 	stp	x10, x11, [sp, #80]
ffff00004008673c:	a90637ec 	stp	x12, x13, [sp, #96]
ffff000040086740:	a9073fee 	stp	x14, x15, [sp, #112]
ffff000040086744:	a90847f0 	stp	x16, x17, [sp, #128]
ffff000040086748:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff00004008674c:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff000040086750:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff000040086754:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff000040086758:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff00004008675c:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff000040086760:	d5384115 	mrs	x21, sp_el0
ffff000040086764:	d5384036 	mrs	x22, elr_el1
ffff000040086768:	d5384017 	mrs	x23, spsr_el1
ffff00004008676c:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff000040086770:	a9105ff6 	stp	x22, x23, [sp, #256]
ffff000040086774:	d28001c0 	mov	x0, #0xe                   	// #14
ffff000040086778:	d5385201 	mrs	x1, esr_el1
ffff00004008677c:	d5384022 	mrs	x2, elr_el1
ffff000040086780:	97ffef04 	bl	ffff000040082390 <show_invalid_entry_message>
ffff000040086784:	1400006b 	b	ffff000040086930 <err_hang>

ffff000040086788 <ret_from_syscall>:
ret_from_syscall:
	bl	disable_irq				
ffff000040086788:	97fffaca 	bl	ffff0000400852b0 <disable_irq>
	str	x0, [sp, #S_X0]				// returned x0 to the user task (saving x0 to on the stack)
ffff00004008678c:	f90003e0 	str	x0, [sp]
	kernel_exit 0
ffff000040086790:	a9505ff6 	ldp	x22, x23, [sp, #256]
ffff000040086794:	a94f57fe 	ldp	x30, x21, [sp, #240]
ffff000040086798:	d5184115 	msr	sp_el0, x21
ffff00004008679c:	d5184036 	msr	elr_el1, x22
ffff0000400867a0:	d5184017 	msr	spsr_el1, x23
ffff0000400867a4:	a94007e0 	ldp	x0, x1, [sp]
ffff0000400867a8:	a9410fe2 	ldp	x2, x3, [sp, #16]
ffff0000400867ac:	a94217e4 	ldp	x4, x5, [sp, #32]
ffff0000400867b0:	a9431fe6 	ldp	x6, x7, [sp, #48]
ffff0000400867b4:	a94427e8 	ldp	x8, x9, [sp, #64]
ffff0000400867b8:	a9452fea 	ldp	x10, x11, [sp, #80]
ffff0000400867bc:	a94637ec 	ldp	x12, x13, [sp, #96]
ffff0000400867c0:	a9473fee 	ldp	x14, x15, [sp, #112]
ffff0000400867c4:	a94847f0 	ldp	x16, x17, [sp, #128]
ffff0000400867c8:	a9494ff2 	ldp	x18, x19, [sp, #144]
ffff0000400867cc:	a94a57f4 	ldp	x20, x21, [sp, #160]
ffff0000400867d0:	a94b5ff6 	ldp	x22, x23, [sp, #176]
ffff0000400867d4:	a94c67f8 	ldp	x24, x25, [sp, #192]
ffff0000400867d8:	a94d6ffa 	ldp	x26, x27, [sp, #208]
ffff0000400867dc:	a94e77fc 	ldp	x28, x29, [sp, #224]
ffff0000400867e0:	910443ff 	add	sp, sp, #0x110
ffff0000400867e4:	d69f03e0 	eret

ffff0000400867e8 <el0_da>:

el0_da:
	bl	enable_irq
ffff0000400867e8:	97fffab0 	bl	ffff0000400852a8 <enable_irq>
	mrs	x0, far_el1
ffff0000400867ec:	d5386000 	mrs	x0, far_el1
	mrs	x1, esr_el1			
ffff0000400867f0:	d5385201 	mrs	x1, esr_el1
	bl	do_mem_abort
ffff0000400867f4:	97fff063 	bl	ffff000040082980 <do_mem_abort>
	cmp x0, 0
ffff0000400867f8:	f100001f 	cmp	x0, #0x0
	b.eq 1f
ffff0000400867fc:	54000360 	b.eq	ffff000040086868 <el0_da+0x80>  // b.none
	handle_invalid_entry 0, DATA_ABORT_ERROR
ffff000040086800:	d10443ff 	sub	sp, sp, #0x110
ffff000040086804:	a90007e0 	stp	x0, x1, [sp]
ffff000040086808:	a9010fe2 	stp	x2, x3, [sp, #16]
ffff00004008680c:	a90217e4 	stp	x4, x5, [sp, #32]
ffff000040086810:	a9031fe6 	stp	x6, x7, [sp, #48]
ffff000040086814:	a90427e8 	stp	x8, x9, [sp, #64]
ffff000040086818:	a9052fea 	stp	x10, x11, [sp, #80]
ffff00004008681c:	a90637ec 	stp	x12, x13, [sp, #96]
ffff000040086820:	a9073fee 	stp	x14, x15, [sp, #112]
ffff000040086824:	a90847f0 	stp	x16, x17, [sp, #128]
ffff000040086828:	a9094ff2 	stp	x18, x19, [sp, #144]
ffff00004008682c:	a90a57f4 	stp	x20, x21, [sp, #160]
ffff000040086830:	a90b5ff6 	stp	x22, x23, [sp, #176]
ffff000040086834:	a90c67f8 	stp	x24, x25, [sp, #192]
ffff000040086838:	a90d6ffa 	stp	x26, x27, [sp, #208]
ffff00004008683c:	a90e77fc 	stp	x28, x29, [sp, #224]
ffff000040086840:	d5384115 	mrs	x21, sp_el0
ffff000040086844:	d5384036 	mrs	x22, elr_el1
ffff000040086848:	d5384017 	mrs	x23, spsr_el1
ffff00004008684c:	a90f57fe 	stp	x30, x21, [sp, #240]
ffff000040086850:	a9105ff6 	stp	x22, x23, [sp, #256]
ffff000040086854:	d28001e0 	mov	x0, #0xf                   	// #15
ffff000040086858:	d5385201 	mrs	x1, esr_el1
ffff00004008685c:	d5384022 	mrs	x2, elr_el1
ffff000040086860:	97ffeecc 	bl	ffff000040082390 <show_invalid_entry_message>
ffff000040086864:	14000033 	b	ffff000040086930 <err_hang>
1:
	bl disable_irq				
ffff000040086868:	97fffa92 	bl	ffff0000400852b0 <disable_irq>
	kernel_exit 0
ffff00004008686c:	a9505ff6 	ldp	x22, x23, [sp, #256]
ffff000040086870:	a94f57fe 	ldp	x30, x21, [sp, #240]
ffff000040086874:	d5184115 	msr	sp_el0, x21
ffff000040086878:	d5184036 	msr	elr_el1, x22
ffff00004008687c:	d5184017 	msr	spsr_el1, x23
ffff000040086880:	a94007e0 	ldp	x0, x1, [sp]
ffff000040086884:	a9410fe2 	ldp	x2, x3, [sp, #16]
ffff000040086888:	a94217e4 	ldp	x4, x5, [sp, #32]
ffff00004008688c:	a9431fe6 	ldp	x6, x7, [sp, #48]
ffff000040086890:	a94427e8 	ldp	x8, x9, [sp, #64]
ffff000040086894:	a9452fea 	ldp	x10, x11, [sp, #80]
ffff000040086898:	a94637ec 	ldp	x12, x13, [sp, #96]
ffff00004008689c:	a9473fee 	ldp	x14, x15, [sp, #112]
ffff0000400868a0:	a94847f0 	ldp	x16, x17, [sp, #128]
ffff0000400868a4:	a9494ff2 	ldp	x18, x19, [sp, #144]
ffff0000400868a8:	a94a57f4 	ldp	x20, x21, [sp, #160]
ffff0000400868ac:	a94b5ff6 	ldp	x22, x23, [sp, #176]
ffff0000400868b0:	a94c67f8 	ldp	x24, x25, [sp, #192]
ffff0000400868b4:	a94d6ffa 	ldp	x26, x27, [sp, #208]
ffff0000400868b8:	a94e77fc 	ldp	x28, x29, [sp, #224]
ffff0000400868bc:	910443ff 	add	sp, sp, #0x110
ffff0000400868c0:	d69f03e0 	eret

ffff0000400868c4 <ret_from_fork>:
	
// the first instructions to be executed by a new task 
// x19 = fn; x20 = arg, populated by copy_process() 
.globl ret_from_fork
ret_from_fork:
	bl	schedule_tail
ffff0000400868c4:	97fff0dc 	bl	ffff000040082c34 <schedule_tail>
	cbz	x19, ret_to_user			// branch to below if not a kernel thread
ffff0000400868c8:	b4000073 	cbz	x19, ffff0000400868d4 <ret_to_user>
	mov	x0, x20						// kernel thread, load fn/arg as populated by copy_process()
ffff0000400868cc:	aa1403e0 	mov	x0, x20
	blr	x19
ffff0000400868d0:	d63f0260 	blr	x19

ffff0000400868d4 <ret_to_user>:
	// kernel thread returns, and continues below to return to user
ret_to_user:
	bl disable_irq				
ffff0000400868d4:	97fffa77 	bl	ffff0000400852b0 <disable_irq>
	kernel_exit 0 					// will restore previously prepared processor state (pt_regs), hit eret, then EL0
ffff0000400868d8:	a9505ff6 	ldp	x22, x23, [sp, #256]
ffff0000400868dc:	a94f57fe 	ldp	x30, x21, [sp, #240]
ffff0000400868e0:	d5184115 	msr	sp_el0, x21
ffff0000400868e4:	d5184036 	msr	elr_el1, x22
ffff0000400868e8:	d5184017 	msr	spsr_el1, x23
ffff0000400868ec:	a94007e0 	ldp	x0, x1, [sp]
ffff0000400868f0:	a9410fe2 	ldp	x2, x3, [sp, #16]
ffff0000400868f4:	a94217e4 	ldp	x4, x5, [sp, #32]
ffff0000400868f8:	a9431fe6 	ldp	x6, x7, [sp, #48]
ffff0000400868fc:	a94427e8 	ldp	x8, x9, [sp, #64]
ffff000040086900:	a9452fea 	ldp	x10, x11, [sp, #80]
ffff000040086904:	a94637ec 	ldp	x12, x13, [sp, #96]
ffff000040086908:	a9473fee 	ldp	x14, x15, [sp, #112]
ffff00004008690c:	a94847f0 	ldp	x16, x17, [sp, #128]
ffff000040086910:	a9494ff2 	ldp	x18, x19, [sp, #144]
ffff000040086914:	a94a57f4 	ldp	x20, x21, [sp, #160]
ffff000040086918:	a94b5ff6 	ldp	x22, x23, [sp, #176]
ffff00004008691c:	a94c67f8 	ldp	x24, x25, [sp, #192]
ffff000040086920:	a94d6ffa 	ldp	x26, x27, [sp, #208]
ffff000040086924:	a94e77fc 	ldp	x28, x29, [sp, #224]
ffff000040086928:	910443ff 	add	sp, sp, #0x110
ffff00004008692c:	d69f03e0 	eret

ffff000040086930 <err_hang>:

.globl err_hang
err_hang: b err_hang
ffff000040086930:	14000000 	b	ffff000040086930 <err_hang>

ffff000040086934 <cpu_switch_to>:
#include "sched.h"

.globl cpu_switch_to
/* the context switch magic */
cpu_switch_to:
	mov	x10, #THREAD_CPU_CONTEXT
ffff000040086934:	d280000a 	mov	x10, #0x0                   	// #0
	add	x8, x0, x10
ffff000040086938:	8b0a0008 	add	x8, x0, x10
	// now `x8` will contain a pointer to the current `cpu_context`
	mov	x9, sp
ffff00004008693c:	910003e9 	mov	x9, sp
	
	// below: all callee-saved registers are stored in the order, in which they are defined in `cpu_context` structure
	stp	x19, x20, [x8], #16		
ffff000040086940:	a8815113 	stp	x19, x20, [x8], #16
	stp	x21, x22, [x8], #16
ffff000040086944:	a8815915 	stp	x21, x22, [x8], #16
	stp	x23, x24, [x8], #16
ffff000040086948:	a8816117 	stp	x23, x24, [x8], #16
	stp	x25, x26, [x8], #16
ffff00004008694c:	a8816919 	stp	x25, x26, [x8], #16
	stp	x27, x28, [x8], #16
ffff000040086950:	a881711b 	stp	x27, x28, [x8], #16
	stp	x29, x9, [x8], #16
ffff000040086954:	a881251d 	stp	x29, x9, [x8], #16
	str	x30, [x8]			// save LR (x30) to cpu_context.pc, pointing to where this function is called from
ffff000040086958:	f900011e 	str	x30, [x8]
	
	add	x8, x1, x10			// calculate the address of the next task's `cpu_contex`
ffff00004008695c:	8b0a0028 	add	x8, x1, x10
	
	// below: restore the CPU context of "switch_to" task to CPU regs
	ldp	x19, x20, [x8], #16		
ffff000040086960:	a8c15113 	ldp	x19, x20, [x8], #16
	ldp	x21, x22, [x8], #16
ffff000040086964:	a8c15915 	ldp	x21, x22, [x8], #16
	ldp	x23, x24, [x8], #16
ffff000040086968:	a8c16117 	ldp	x23, x24, [x8], #16
	ldp	x25, x26, [x8], #16
ffff00004008696c:	a8c16919 	ldp	x25, x26, [x8], #16
	ldp	x27, x28, [x8], #16
ffff000040086970:	a8c1711b 	ldp	x27, x28, [x8], #16
	ldp	x29, x9, [x8], #16
ffff000040086974:	a8c1251d 	ldp	x29, x9, [x8], #16
	ldr	x30, [x8]				// x30 == LR
ffff000040086978:	f940011e 	ldr	x30, [x8]
	mov	sp, x9
ffff00004008697c:	9100013f 	mov	sp, x9

	// The `ret` instruction will jump to the location pointed to by the link register (LR or `x30`). 
	// If we are switching to a task for the first time, this will be the beginning of the `ret_from_fork` function.
	// In all other cases this will be the location previously saved in the `cpu_context.pc` by the `cpu_switch_to` function
	ret							
ffff000040086980:	d65f03c0 	ret
