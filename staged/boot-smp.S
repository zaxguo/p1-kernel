//
// xzl: an attempt to impl cpu spin flags ... at 0xd8... 
// turned out current firmware and qemu wont need them... keep them here


#include "param.h"
#include "sysregs.h"
#include "plat.h"
#include "mmu.h"

/* 
	unified code for virt and rpi3 
	for register details, cf sysregs.h
*/
.section ".text.boot"

// reg for cpuid_reg throughout boot.S. shall not be used for other purposes
cpuid_reg 	.req 	x28 

.globl _start
.globl start0
_start:
	b start0  // secondary cores need to see non-zero addr to boot
start0: 
	/* ---------- Below: handle multicore -------------- */
	mrs	cpuid_reg, mpidr_el1	// cf: https://developer.arm.com/documentation/100095/0002/system-control/aarch64-register-descriptions/multiprocessor-affinity-register--el1
	and	cpuid_reg, cpuid_reg, #0xFF	// x28: core id
	b check_flag
// the mechanism used by firmware that wants to "park" the cores
// qemu-8 implements this mechanism
.ltorg // emit literal pool; reuse the padding space
.org 0xd8  // relative to this section
.globl spin_cpu0
spin_cpu0:
        .quad 1  // emit 8 bytes of 0s. as the placeholder of core0's flag 
.org 0xe0
spin_cpu1:
        .quad 0 // ditto
.org 0xe8
spin_cpu2:
        .quad 0 // ditto
.org 0xf0
spin_cpu3:
        .quad 0 // ditto

#if 1
	// mechanism to park core(s) to avoid race condition, which will results in being unable to boot
	// if cores are already "parked" by firmware, we won't need this. but we dont know
check_flag:	
    adr     x5, core_flags	 // spin on core_flags until them become 1	
	ldr     x4, [x5, cpuid_reg, lsl #3]	// x4: the core's flag. 
    cbnz    x4, core_boot			// Flag non zero. This core may proceed. 
	wfe		// wait to be signaled. (low power)
	b 		check_flag
#endif

core_boot:
	//cbz cpuid_reg, 1f
	///  SIGN OF LIFE .........
	//add x0, cpuid_reg, 'A'
	//bl uart_send_pa
	//mov x0, '\n'
	//bl uart_send_pa
1:
	ldr	x0, =SCTLR_VALUE_MMU_DISABLED  // cf: sysregs.h
	msr	sctlr_el1, x0
	
	# don't trap EL0/EL1 access to advanced simd, fp registers.
	# cf: https://developer.arm.com/documentation/ddi0595/2021-03/AArch64-Registers/CPACR-EL1--Architectural-Feature-Access-Control-Register
	# 	some code may contain them (e.g. usblib StringFormat uses q0/q1...)
	MRS     x1, CPACR_EL1
	ORR     x1, x1, #(0x3 << 20)    // Write CPACR_EL1.FPEN bits
	MSR     CPACR_EL1, x1
	ISB

	/* -------- Below: exception level switch ---------------
	  check the current exception level: EL3 (rpi3 hardware) or EL2 (qemu)?
	  both eret to EL1  */

	mrs x0, CurrentEL
  	lsr x0, x0, #2
	cmp x0, #3
	beq el3		

	# current: EL2 
	# set EL1 to be running in AArch64
	mrs	x0, hcr_el2
	orr	x0, x0, #HCR_RW  
	msr	hcr_el2, x0

	# prepare to switch to EL1
	mov x0, #SPSR_VALUE
	msr	spsr_el2, x0

	adr	x0, el1_entry
	msr	elr_el2, x0
	eret	// switch to EL1

el3: 		// current: EL3
  	ldr x0, =HCR_VALUE
  	msr hcr_el2, x0

	ldr	x0, =SCR_VALUE
	msr	scr_el3, x0

	# prepare to switch to EL1
	ldr	x0, =SPSR_VALUE
	msr	spsr_el3, x0

	adr	x0, el1_entry		
	msr	elr_el3, x0	
	eret	// switch to EL1				

	/* ------- Below: EL1 execution ------- */
el1_entry:	
	cbnz cpuid_reg, setup_sp // all cores but cpu0 skip code below
	
	//adr x0, start0 
	//adr x1, spin_cpu1
	//str x0, [x1]

	// bss_begin/end are linking addr (kernel virt). convert them to phys.
	// they are (at least) 8 bytes aligned in link script
	ldr	x0, =bss_begin
	ldr	x1, =bss_end
	ldr x2, =VA_START
	sub x0, x0, x2
	sub x1, x1, x2
	sub	x1, x1, x0
	bl 	memzero_aligned

#if defined(PLAT_VIRT) || defined(PLAT_RPI3QEMU)
// A workaround for QEMU's quirks on MMU emulation, which also showcases how __create_page_tables
// can be used. 
// 
// As soon as the MMU is on and CPU switches from physical addresses to virtual addresses, 
// the emulated CPU seems to be still fetching next (few) instructions using the physical 
// addresses of those instructions. These addresses will go through MMU for translation 
// as if they are virtual addresses. Of course our kernel pgtables do not have translation
// for these addresses (TTBR1 is for translating virtual addresses at 0xffff...). That causes 
// MMU to throw a Prefetch abort. (prefetch == instruction loading)
//
// Real Rpi3 hardware has no such a problem: after MMU is on, it will not fetch instructions 
// at addresses calculated before MMU is on. 
//
// The workaround is to set an "identity" mapping. That is, we create an additional 
// pgtable tree at TTBR0 that maps all physical DRAM (0 -- PHYS_MEMORY_SIZE) to virtual 
// addresses with the same values. That keeps translation going on at the switch of MMU. 
// (cannot be TTBR1 which cannot map low virt addr)
//
// Cf: https://github.com/s-matyukevich/raspberry-pi-os/issues/8
// https://www.raspberrypi.org/forums/viewtopic.php?t=222408
	bl	__create_idmap
	//adrp	x0, idmap_dir
	//msr	ttbr0_el1, x0
#endif

	// create kernel's pgtable (for memory and IO)
#if defined(PLAT_RPI3QEMU) || defined(PLAT_RPI3)	
	bl 	__create_page_tables_rpi3
#elif defined(PLAT_VIRT)	
	bl 	__create_page_tables_virt
#else
	#error "not implemented"
#endif	

	// set virt sp = (cpuid_reg+1)*kernel_stack_size + kernel_stack_start
	// (assuming linear mapping, phys 0 --> virt VA_START)
	// NB: we won't use sp until mmu is on
setup_sp: 	
	add x0, cpuid_reg, #1
	mov x1, #(PAGE_SIZE * NPAGES_PER_KERNEL_STACK)
	mul x0, x0, x1
	ldr x1, =kernel_stack_start	// kernel.c
	add x0, x0, x1
	mov sp, x0 

	// load kernel's pgtable
	adrp	x0, pg_dir			// @pg_dir: the virtual base address of the pgtables. cf utils.h
	msr		ttbr1_el1, x0
	isb 		// memory barrier 

	// configuring mm translation (granule, user/kernel split, etc)
	// tcr_el1: Translation Control Register. cf mmu.h
	ldr	x0, =(TCR_VALUE)		
	msr	tcr_el1, x0 
	isb 		// memory barrier 

	// memory attributes.
	ldr	x0, =(MAIR_VALUE)
	msr	mair_el1, x0

#ifdef PLAT_RPI3QEMU
	adrp	x0, idmap_dir
	msr	ttbr0_el1, x0	
#endif

	// irq_vector_init, each core has to do this
	ldr x0, =vectors		// load VBAR_EL1 vector table addr (kern VA)
	msr	vbar_el1, x0	

	// still alive?
	//add x0, cpuid_reg, 'A'
	//bl uart_send_pa
		
	// Go in through jump_table per our core ID
#if 0	// buggy?
	adr	x4, jump_table
	lsl x2, cpuid_reg, #2
	ldr x4, [x4, x2]
	ldr x0, =SCTLR_VALUE // Turn on MMU. cf sysregs.h
	msr	sctlr_el1, x0	// BOOM! we are on virtual after this.
	mov x0, cpuid_reg 	// x28=core id as the 1st argument 
	br 	x4				// Jump to kernel_main() (kernel.c)
#endif
	cmp cpuid_reg, #0
	b.eq 1f
	ldr x2, =secondary_core_asm
	//ldr x2, =secondary_core
	ldr x0, =SCTLR_VALUE // Turn on MMU. cf sysregs.h
	msr	sctlr_el1, x0	// BOOM! we are on virtual after this.	
	br 	x2				// Jump to kernel_main() (kernel.c)

1:
	// ORIGINAL, core0
	// load the linking (virt) addr of kernel_main
	ldr	x2, =kernel_main
	ldr x0, =SCTLR_VALUE // Turn on MMU. cf sysregs.h
	msr	sctlr_el1, x0	// BOOM! we are on virtual after this.	
	br 	x2				// Jump to kernel_main() (kernel.c)

// ------------------------ pgtable utilities below --------------------------- //

	// Given a virt addr and the PGD, set the PGD entry, allocate one PUD and one PMD.
	//		link PGD -> PUD and PUD -> PMD
	// @tbl: a register pointing to PGD
	// @virt: the virtual address that we are currently mapping
	// @tmp1/2: temporary registers to use; contents will be clobbered 
	.macro	create_pgd_entry, tbl, virt, tmp1, tmp2
	create_table_entry \tbl, \virt, PGD_SHIFT, \tmp1, \tmp2  // set a PGD entry
	// @tbl now points to the newly created PUD table
	create_table_entry \tbl, \virt, PUD_SHIFT, \tmp1, \tmp2		// set a PUD entry
	// @tbl now points to the newly created PMD table
	.endm

	// Given a current lv pgtable (either PGD or PUD) and a virt addr to map, setting up 
	// the corresponding pgtable entry pointing to the next lv pgtable. 
	// Assumption: the next lv pgtable comes right afer the current lv pgtable 
	//		(i.e. all the page tables are located continuously)
	// After the operation, advance the pointer to the current lv pgtable to the next lv pgtable
	//
	// @tbl: a register pointing to the "current" pgtable in a memory region, after which new pgtables 
	//			to be allocated subsequentlly
	// @virt: the virtual address that we are currently mapping
	// @shift: for the "current" pgtable lv. 39 in case of PGD and 30 in case of PUD
	// 		   apply to the virtual address in order to extract current table index. 
	// @tmp1/2: temporary registers to use; contents will be clobbered 
	.macro	create_table_entry, tbl, virt, shift, tmp1, tmp2
	lsr	\tmp1, \virt, #\shift
	and	\tmp1, \tmp1, #PTRS_PER_TABLE - 1		// tmp1: extracted table index in the current lv. 
	add	\tmp2, \tbl, #PAGE_SIZE					// tmp2: addr of a next level pgtable (PUD or PMD). 
	orr	\tmp2, \tmp2, #MM_TYPE_PAGE_TABLE		// tmp2: make a table descriptor. set bits[0:1] to 1. 
	str	\tmp2, [\tbl, \tmp1, lsl #3]			// store descriptor (tmp2) to the current pgtable at index (tmp1)
	add	\tbl, \tbl, #PAGE_SIZE					// point @tbl to the newly create next level pgtable. for programming ease
	.endm

	// same as above, but points to next-lv pgtable 2 PAGES away
	.macro	create_table_entry2, tbl, virt, shift, tmp1, tmp2
	lsr	\tmp1, \virt, #\shift
	and	\tmp1, \tmp1, #PTRS_PER_TABLE - 1		// tmp1: extracted table index in the current lv. 
	add	\tmp2, \tbl, #(PAGE_SIZE<<1)					// tmp2: addr of a next level pgtable (PUD or PMD). 
	orr	\tmp2, \tmp2, #MM_TYPE_PAGE_TABLE		// tmp2: make a table descriptor. set bits[0:1] to 1. 
	str	\tmp2, [\tbl, \tmp1, lsl #3]			// store descriptor (tmp2) to the current pgtable at index (tmp1)
	add	\tbl, \tbl, #(PAGE_SIZE<<1)					// point @tbl to the newly create next level pgtable. for programming ease
	.endm

	// Populating entries in a PUD or PMD table for a given virt addr range 
	// "block map": mappings larger than 4KB, e.g. 1GB or 2MB
	// 
	// @tbl: a reg pointing to the base of PUD/PMD table
	// @phys: the start of the physical region to be mapped
	// @start/@end: virtual address of the first/last section to be mapped
	// @flags: to be copied into lower attributes of the block descriptor
	// @shift: SUPERSECTION_SHIFT for PUD, SECTION_SHIFT for PMD
	// @tmp1: temporary register to use; contents will be clobbered	
	.macro	_create_block_map, tbl, phys, start, end, flags, shift, tmp1
	lsr	\start, \start, #\shift
	and	\start, \start, #PTRS_PER_TABLE - 1			// start index in the PUD/PMD
	lsr	\end, \end, #\shift
	and	\end, \end, #PTRS_PER_TABLE - 1				// end index in the PUD/PMD
	// assemble a table entry in phys
	lsr	\phys, \phys, #\shift						// shift phy addr to lower bits
	mov	\tmp1, #\flags
	orr	\phys, \tmp1, \phys, lsl #\shift			// shift phy addr to higher bits
	// after this, phys: the table entry value
9999:	str	\phys, [\tbl, \start, lsl #3]				// store the entry in the pgtable
	add	\start, \start, #1								// @start: index of next PUD/PMD entry 
	//add	\phys, \phys, #(1 << \shift)				// update the table entry value
	mov \tmp1, #(1 << \shift)
	add \phys, \phys, \tmp1
	cmp	\start, \end
	b.ls	9999b
	.endm

.macro	create_block_map_supersection, tbl, phys, start, end, flags, tmp1
	_create_block_map \tbl, \phys, \start, \end, \flags, SUPERSECTION_SHIFT, \tmp1
	.endm

.macro	create_block_map_section, tbl, phys, start, end, flags, tmp1
	_create_block_map \tbl, \phys, \start, \end, \flags, SECTION_SHIFT, \tmp1
	.endm

#if defined(PLAT_VIRT) || defined(PLAT_RPI3QEMU)
__create_idmap:
	mov	x29, x30
	
	adrp	x0, idmap_dir		// idmap_dir allocated in linker-qemu.ld, 3 pages. 
	mov	x1, #PG_DIR_SIZE		// 3pgs, PGD|PUD|PMD
	bl	memzero_aligned

	adrp	x0, idmap_dir
	mov	x1, xzr					// starting mapping from 0x0 (phys device base)
	create_table_entry x0, x1, PGD_SHIFT, x2, x3 	// install the PGD entry
	// after this, x0 points to the new PUD table
	
	ldr	x1, =PHYS_BASE
	ldr	x2, =PHYS_BASE
	ldr	x3, =(PHYS_BASE + PHYS_SIZE - SUPERSECTION_SIZE)
	create_block_map_supersection x0, x1, x2, x3, MMU_FLAGS, x4

	mov	x30, x29
	ret
#endif

#ifdef PLAT_VIRT
__create_page_tables_virt: // for qemu's virt plat
	mov		x29, x30						// save return address

	// clear the mem region backing pgtables
	adrp 	x0, pg_dir
	mov		x1, #PG_DIR_SIZE
	bl 		memzero_aligned

	// allocate one PUD; link PGD (pg_dir)->PUD
	adrp	x0, pg_dir
	mov		x1, #VA_START 
	create_table_entry x0, x1, PGD_SHIFT, x2, x3
	// after this, x0 points to the new PUD table

	/* Mapping device memory. Phys addr range: DEVICE_BASE(0)--DEVICE_SIZE(0x40000000) */
	mov 	x1, #DEVICE_BASE						// x1 = start mapping from device base address 
	ldr 	x2, =(VA_START + DEVICE_BASE)			// x2 = first virtual address
	ldr		x3, =(VA_START + DEVICE_BASE + DEVICE_SIZE - SUPERSECTION_SIZE)	// x3 = the virtual base of the last section
	create_block_map_supersection x0, x1, x2, x3, MMU_DEVICE_FLAGS, x4
	//_create_block_map x0, x1, x2, x3, MMU_DEVICE_FLAGS, SUPERSECTION_SHIFT, x4

	/* Mapping kernel and init stack. Phys addr range: 0x4000:0000, +PHYS_SIZE */
	mov 	x1, #PHYS_BASE				// x1 = starting phys addr. set x1 to 0. 
	ldr 	x2, =(VA_START + DEVICE_BASE + DEVICE_SIZE)	 // x2 = the virtual base of the first section
	ldr		x3, =(VA_START + DEVICE_BASE + DEVICE_SIZE + PHYS_SIZE - SUPERSECTION_SIZE)  // x3 = the virtual base of the last section
	create_block_map_supersection x0, x1, x2, x3, MMU_FLAGS, x4

	mov	x30, x29						// restore return address
	ret
#endif

#if defined(PLAT_RPI3QEMU) || defined(PLAT_RPI3)	
__create_page_tables_rpi3: // for rpi3	
	mov		x29, x30						// save return address

	// our pgtable dir layout: PGD|PUD|PMD1|PMD2	each one page. total 4 pages

	// clear the mem region backing pgtables
	adrp 	x0, pg_dir
	mov		x1, #PG_DIR_SIZE
	bl 		memzero_aligned

	// allocate PUD & PMD1; link PGD (pg_dir)->PUD, and PUD->PMD1
	adrp	x0, pg_dir
	mov		x1, #VA_START 
	create_pgd_entry x0, x1, x2, x3
	// after this, x0 points to the new PMD table

	/* Mapping kernel and init stack. Phys addr range: 0--DEVICE_BASE */
	mov 	x1, xzr				// x1 = starting phys addr. set x1 to 0. 
	mov 	x2, #VA_START		// x2 = the virtual base of the first section
	ldr		x3, =(VA_START + DEVICE_BASE - SECTION_SIZE)  // x3 = the virtual base of the last section
	create_block_map_section x0, x1, x2, x3, MMU_FLAGS, x4

	/* Mapping device memory. Phys addr range: DEVICE_BASE--PHYS_MEMORY_SIZE(0x40000000) */
	mov 	x1, #DEVICE_BASE					// x1 = start mapping from device base address 
	ldr 	x2, =(VA_START + DEVICE_BASE)				// x2 = first virtual address
	ldr		x3, =(VA_START + DEVICE_LOW - SECTION_SIZE)	// x3 = the virtual base of the last section
	create_block_map_section x0, x1, x2, x3, MMU_DEVICE_FLAGS, x4
	
	// Now link PUD->PMD2
	adrp 	x0, pg_dir 
	add		x0, x0, #PAGE_SIZE 	// rewind x0 to PUD
	ldr		x1, =(VA_START + DEVICE_LOW)
	create_table_entry2 x0, x1, PUD_SHIFT, x2, x3 
	// now x0 points to PMD2
	mov		x1, #DEVICE_LOW	
	ldr		x2, =(VA_START + DEVICE_LOW)
	ldr		x3, =(VA_START + DEVICE_LOW)		// mapping one section is enough
	create_block_map_section x0, x1, x2, x3, MMU_DEVICE_FLAGS, x4

	mov	x30, x29						// restore return address
	ret
#endif

.globl core_flags
core_flags: 
	.quad 1	// 8 bytes
	.quad 0
	.quad 0
	.quad 0

jump_table:  // NB: each entry (insn) 4 bytes
	.quad 	kernel_main
	.quad	secondary_core	
	.quad	secondary_core
	.quad	secondary_core


.global core2_state
core2_state:
	.quad 0
	.quad 0
	.quad 0
	.quad 0xdeadbeef

secondary_core_asm:
	// now: VM is on, cache is on
	//add x0, cpuid_reg, 'X'	// are we alive?
	//bl uart_send_va	

	// invalidate all cache 
	ldr x0, =VA_START
	add x1, x0, #(4*SECTION_SIZE)
	bl __asm_invalidate_dcache_range

	// snapshot
	//adr x1, core2_state
	//mov x0, sp
	//str x0, [x1]
	//ldr x0, =0xeeeeeeee
	//str x0, [x1, #8]

	mov x0, cpuid_reg
	bl secondary_core
