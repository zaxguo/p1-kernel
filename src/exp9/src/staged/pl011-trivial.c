/* 
    A trivial driver for Arm PL011 (UART) 
    no lock, no irq, only support printf() for early kernel debugging
    by xzl, 2024

    cf: 
    https://github.com/RT-Thread/rt-thread/blob/master/bsp/qemu-virt64-aarch64/drivers/drv_uart.c

*/

#include <stdint.h>
#include "utils.h"

// https://developer.arm.com/documentation/ddi0183/f/programmer-s-model/register-descriptions
// enable fifo via the line control reg
// https://developer.arm.com/documentation/ddi0183/f/programmer-s-model/register-descriptions/line-control-register--uartlcr-h
// fifo level: 
// https://developer.arm.com/documentation/ddi0183/f/programmer-s-model/register-descriptions/interrupt-fifo-level-select-register--uartifls
// tx irq desc:
// https://developer.arm.com/documentation/ddi0183/f/programmer-s-model/interrupts/uarttxintr

#define UART_DR(base)   __REG32(base + 0x00)
#define UART_FR(base)   __REG32(base + 0x18)        // Flag 
#define UART_CR(base)   __REG32(base + 0x30)        // Control
#define UART_IMSC(base) __REG32(base + 0x38)        // Interrupt mask set/clear register
#define UART_ICR(base)  __REG32(base + 0x44)        // Interrupt clear register 

#define UARTFR_RXFE     0x10        // rx fifo empty
#define UARTFR_TXFF     0x20        // tx fifo full
#define UARTIMSC_RXIM   0x10        // rx irq mask
#define UARTIMSC_TXIM   0x20        // tx irq mask
#define UARTICR_RXIC    0x10        // irq clear: rx
#define UARTICR_TXIC    0x20        // irq clear: tx

static unsigned long hw_base = 0;  // we are on virt addr space

void uart_send (char c) {
    while (UART_FR(hw_base) & UARTFR_TXFF)
        ;
    UART_DR(hw_base) = (uint32_t)c;
}

char uart_recv(void) {    
    while (1) {
        if (!(UART_FR(hw_base) & UARTFR_RXFE)) 
            break;      
    }
    return (char)(UART_DR(hw_base) & 0xff);
}

void uart_send_string(char* str) {
	for (int i = 0; str[i] != '\0'; i ++) {
		uart_send((char)str[i]);
	}
}

void uart_init (unsigned long base) {
    hw_base = base; 

    /* disable rx irq */
    UART_IMSC(hw_base) &= ~UARTIMSC_RXIM;

    /* enable Rx and Tx of UART */
    UART_CR(hw_base) = (1 << 0) | (1 << 8) | (1 << 9);  // uart_enable | tx_enable | rx_enable 

    // /* enable rx irq */
    // UART_IMSC(hw_base) |= UARTIMSC_RXIM;

    // /* enable tx irq */
    // UART_IMSC(hw_base) |= UARTIMSC_TXIM;

#if 0 
    /* Disable the UART */
    UART_DEVICE->CR &= ~CR_UARTEN;

    /* Enable FIFOs */
    UART_DEVICE->LCRH |= LCRH_FEN;

    // Interrupt mask register
    UART_DEVICE->IMSC |= IMSC_RXIM;

    // Interrupt clear register
    UART_DEVICE->ICR  = BE_INTERRUPT;

    /* Enable the UART */
    UART_DEVICE->CR |= CR_UARTEN;
#endif    
}

// This function is required by printf function
void putc(void* p, char c) {
	uart_send(c);
}