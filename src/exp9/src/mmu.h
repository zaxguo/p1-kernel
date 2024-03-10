#ifndef _MMU_H
#define _MMU_H

/* reference: 
For quick overview, cf: "ARM 100940_0100_en" armv8-a address translation.

For detailed def, cf: 
"Overview of the VMSAv8-64 address translation stages"
https://armv8-ref.codingbelief.com/en/chapter_d4/d42_5_overview_of_the_vmsav8-64_address_translation.html

"VMSAv8-64 translation table level 0 level 1 and level 2 descriptor formats"
https://armv8-ref.codingbelief.com/en/chapter_d4/d43_1_vmsav8-64_translation_table_descriptor_formats.html
*/

/* in arm's lingo, we are using 4KB granule (lowest pgtable entry). that means: 
    1GB per PUD entry, 2MB per PMD entry */
#define MM_TYPE_PAGE_TABLE		0x3
#define MM_TYPE_PAGE 			0x3
#define MM_TYPE_BLOCK			0x1         // block -- pointed by either a PUD entry or a PMD entry

/* ref:
Access flag (AF). "D4.4.1 Memory access control"
https://armv8-ref.codingbelief.com/en/chapter_d4/d44_1_memory_access_control.html#
*/
#define MM_ACCESS			    (0x1 << 10)  // AF. "indicates when a page or section of memory is accessed for the first time". if 0, exception. to be set by kernel
/* Access permission, bit7:6 in descriptor */
#define MM_AP_MASK              (0x3UL << 6)
#define MM_AP_EL1_RW            (0x0 << 6)      // EL0:no access; EL1/2/3: rw
#define MM_AP_RW                (0x1 << 6)      // EL0/1/2/3: rw
#define MM_AP_EL0_RO            (0x2 << 6)      // EL0:ro; EL1/2/3: rw
#define MM_AP_RO                (0x3 << 6)      // EL0/1/2/3: ro

/* "D4.3.3 Memory attribute fields in the VMSAv8-64 translation table format descriptors" */
#define MM_XN (1UL<<54)    // execute-never (Unprivileged execute never for EL1/EL0)
#define MM_PXN (1UL<<53)   // Privileged execute-never bit (Determines whether the region is executable at EL1)
#define MM_XN_MASK              (0x3UL << 53)

// extract perm bits from pte
#define PTE_TO_PERM(x)      (x & (unsigned long)(MM_AP_MASK | MM_XN_MASK))
#ifndef __ASSEMBLER__
    // extract pa from pte. assuming pa within 32bits TODO: fix this for larger phys mem system...
    _Static_assert(PHYS_SIZE < 0xffffffff); 
#endif
#define PTE_TO_PA(x)        (x & (0xffffffff) & PAGE_MASK)
/*
 * Memory region attributes:
 *
 *   n = AttrIndx[2:0]
 *			        n	MAIR
 *   DEVICE_nGnRnE	000	00000000
 *   NORMAL_NC		001	01000100
 *  cf Google "den0024 MT_DEVICE_nGnRnE_FLAGS (or memory ordering)"
 */
#define MT_DEVICE_nGnRnE 		0x0
#define MT_NORMAL_NC			0x1
#define MT_DEVICE_nGnRnE_FLAGS		0x00  // "equivalent to Strongly Ordered memory in the ARMv7 architecture".
#define MT_NORMAL_NC_FLAGS  		0x44   
#define MAIR_VALUE			(MT_DEVICE_nGnRnE_FLAGS << (8 * MT_DEVICE_nGnRnE)) | (MT_NORMAL_NC_FLAGS << (8 * MT_NORMAL_NC))

#define MMU_FLAGS	 		(MM_TYPE_BLOCK | (MT_NORMAL_NC << 2) | MM_ACCESS)	    /* block (section) granuarlity, memory */
#define MMU_DEVICE_FLAGS	(MM_TYPE_BLOCK | (MT_DEVICE_nGnRnE << 2) | MM_ACCESS)	/* block (section) granuarlity, devices */
#define MMU_PTE_FLAGS		(MM_TYPE_PAGE | (MT_NORMAL_NC << 2) | MM_ACCESS)	    /* need to be used with MP_AP_xxx, MM_XN */

// https://developer.arm.com/documentation/ddi0595/2021-12/AArch64-Registers/TCR-EL1--Translation-Control-Register--EL1-?lang=en#fieldset_0-31_30
#define TCR_T0SZ			(64 - 48)       // The size offset of the memory region addressed by TTBR0_EL1.
#define TCR_T1SZ			((64 - 48) << 16) // ... for TTBR1_EL1
#define TCR_TG0_4K			(0 << 14)       // Granule size 4KB for the TTBR1_EL0 
#define TCR_TG1_4K			(2 << 30)       // Granule size 4KB for the TTBR1_EL1
// NB above: granule is for level3 pgtable entry. does NOT mean that we cannot map blocks 
// at lv1 and lv2. 
#define TCR_VALUE			(TCR_T0SZ | TCR_T1SZ | TCR_TG0_4K | TCR_TG1_4K)

#endif
