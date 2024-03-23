#ifndef _PLAT_RPI3QEMU_H
#define _PLAT_RPI3QEMU_H

// QEMU's rpi3 emulation, for qemu's "-M raspi3"
// will be included by both .S and .c
// ---------------- memory layout --------------------------- //
// cf qemu monitor "info mtree"
#define DEVICE_BASE     0x3f000000
#define DEVICE_LOW      0x40000000 
#define DEVICE_HIGH     0x40000100

#define PHYS_BASE       0x00000000              // start of sys mem
#define KERNEL_START    0x00080000              // qemu will load ker to this addr and boot
#define PHYS_SIZE       0x3f000000    

// ---------------- irq ------------------------------------ //
// "BCM2837 ARM Peripherals Revised V2-1. pp.112 Sec 7.5 registers"
#define PBASE           0x3F000000      // start of peripheral addr
#define IRQ_BASIC_PENDING	(PBASE+0x0000B200)  // gpu's own irqs + common irqs
#define IRQ_PENDING_1		(PBASE+0x0000B204)  // irq 0..31 from gpu side
    #define SYSTEM_TIMER_IRQ_0	(1 << 0)
    #define SYSTEM_TIMER_IRQ_1	(1 << 1)
    #define SYSTEM_TIMER_IRQ_2	(1 << 2)
    #define SYSTEM_TIMER_IRQ_3	(1 << 3)
    #define IRQ_PENDING_1_USB (1<<9)
    #define IRQ_PENDING_1_AUX (1<<29)       // aux(mini uart)
#define IRQ_PENDING_2		(PBASE+0x0000B208)  // irq 32..63 from gpu side
#define FIQ_CONTROL		    (PBASE+0x0000B20C)
#define ENABLE_IRQS_1		(PBASE+0x0000B210)
    #define ENABLE_IRQS_1_USB (1<<9)
    #define ENABLE_IRQS_1_AUX (1<<29)
#define ENABLE_IRQS_2		(PBASE+0x0000B214)
#define ENABLE_BASIC_IRQS	(PBASE+0x0000B218)
#define DISABLE_IRQS_1		(PBASE+0x0000B21C)
#define DISABLE_IRQS_2		(PBASE+0x0000B220)
#define DISABLE_BASIC_IRQS	(PBASE+0x0000B224)



// See BCM2836 ARM-local peripherals at
// https://www.raspberrypi.org/documentation/hardware/raspberrypi/bcm2836/QA7_rev3.4.pdf
#define LPBASE          0x40000000      
#define TIMER_INT_CTRL_0    (0x40000040)
#define INT_SOURCE_0        (LPBASE+0x60)   // "CORE0_IRQ_SOURCE" in the manual above

#define TIMER_INT_CTRL_0_VALUE  (1 << 1) 
#define GENERIC_TIMER_INTERRUPT (1U<<1) // CNTPNSIRQ
#define GPU_SIDE_INTERRUPT (1U<<8)        // GPU side interrupt

// ---------------- mbox  ------------------------------------ //
// Copyright (C) 2018 bzt (bztsrc@github) (cf. CREDITS)

#ifndef __ASSEMBLER__
/* a properly aligned buffer */
extern volatile unsigned int mbox[36];
int mbox_call(unsigned char ch);
#endif

#define MBOX_REQUEST    0

/* channels */
#define MBOX_CH_POWER   0
#define MBOX_CH_FB      1
#define MBOX_CH_VUART   2
#define MBOX_CH_VCHIQ   3
#define MBOX_CH_LEDS    4
#define MBOX_CH_BTNS    5
#define MBOX_CH_TOUCH   6
#define MBOX_CH_COUNT   7
#define MBOX_CH_PROP    8

/* tags */
#define MBOX_TAG_SETPOWER       0x28001
#define MBOX_TAG_SETCLKRATE     0x38002
#define MBOX_TAG_LAST           0

// ---------------- timer ------------------------------------ //
#define TIMER_CS        (PBASE+0x00003000)
#define TIMER_CLO       (PBASE+0x00003004)      // counter low 32bit, ro
#define TIMER_CHI       (PBASE+0x00003008)      // counter high 32bit, ro 
#define TIMER_C0        (PBASE+0x0000300C)
#define TIMER_C1        (PBASE+0x00003010)
#define TIMER_C2        (PBASE+0x00003014)
#define TIMER_C3        (PBASE+0x00003018)

#define TIMER_CS_M0	(1 << 0)
#define TIMER_CS_M1	(1 << 1)
#define TIMER_CS_M2	(1 << 2)
#define TIMER_CS_M3	(1 << 3)

// --------------- mini uart ------------------------------- //
#define UART_PHYS 0x3F000000    // cf mini_uart.c
#endif