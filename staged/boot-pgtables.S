// spin off from boot.S, pgtables utilities written in asm
// replaced by C counterparts (mm.c) for readability 

////////////////////////////////////////////////////////////////////////////////
// ------------------------ pgtable utilities below --------------------------//
// We use ASM instead of C, b/c we want to set up pgtables (&VA) before jumping
// to C code with a virtual SP. 

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

	// cf comment for "_create_block_map"
.macro	create_block_map_supersection, tbl, phys, start, end, flags, tmp1
	_create_block_map \tbl, \phys, \start, \end, \flags, SUPERSECTION_SHIFT, \tmp1
	.endm

	// cf comment for "_create_block_map"
.macro	create_block_map_section, tbl, phys, start, end, flags, tmp1
	_create_block_map \tbl, \phys, \start, \end, \flags, SECTION_SHIFT, \tmp1
	.endm

__create_idmap:
	mov	x29, x30
	
	adrp	x0, idmap_dir		// idmap_dir allocated in linker-qemu.ld
	mov	x1, #PG_DIR_SIZE		// 2pgs enough, PGD|PUD
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

	/* Mapping kernel mem. Phys addr range: 0x4000:0000, +PHYS_SIZE */
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

	// Mapping kernel mem. Phys addr range: 0--DEVICE_BASE
	mov 	x1, xzr				// x1 = starting phys addr. set x1 to 0. 
	mov 	x2, #VA_START		// x2 = the virtual base of the first section
	ldr		x3, =(VA_START + DEVICE_BASE - SECTION_SIZE)  // x3 = the virtual base of the last section
	create_block_map_section x0, x1, x2, x3, MMU_FLAGS, x4

	// Mapping device memory. Phys addr range: DEVICE_BASE--PHYS_MEMORY_SIZE(0x40000000)
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
