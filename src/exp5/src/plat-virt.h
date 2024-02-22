#ifndef _PLAT_VIRT_H
#define _PLAT_VIRT_H

// QEMU virt, for qemu's "-M virt"
// will be included by both .S and .c

// ---------------- memory layout --------------------------- //
// cf qemu monitor "info mtree"
// [0x0, 0x4000:0000) 1GB of iomem, 
//              in which [0x0,0x1000:0000) for various on-chip devices
//                       [0x1000:0000, ) for pcie mmio
// [0x4000:0000, ) DRAM, size is specified by qemu cmd line. 
#define DEVICE_BASE     0x00000000
#define DEVICE_SIZE     0x40000000

#define PHYS_BASE       0x40000000              // start of sys mem
#define KERNEL_START    0x40080000              // qemu will load ker to this addr and boot
#define PHYS_SIZE       (1 *1024*1024*1024U)    // size of phys mem, "qemu ... -m 1024M ..."

#define LOW_MEMORY      (PHYS_BASE + 2 * SECTION_SIZE)
#define HIGH_MEMORY     (PHYS_BASE + PHYS_SIZE)

#define PAGE_SHIFT	 	12
#define TABLE_SHIFT 		9
#define SECTION_SHIFT		(PAGE_SHIFT + TABLE_SHIFT)

#define PAGE_SIZE   		(1 << PAGE_SHIFT)	
#define SECTION_SIZE		(1 << SECTION_SHIFT)	

#define PAGING_MEMORY           (HIGH_MEMORY - LOW_MEMORY)
#define PAGING_PAGES            (PAGING_MEMORY/PAGE_SIZE)

// ---------------- gic irq controller --------------------------- //
// from qemu mon "info mtree"
#define QEMU_GIC_DIST_BASE          0x08000000
#define QEMU_GIC_CPU_BASE           0x08010000

// cf: "Aarch64 programmer's guide: generic timer" 3.4 Interrupts
// "This means that each core sees its EL1 physical timer as INTID 30..."
#define IRQ_ARM_GENERIC_TIMER       30

#endif