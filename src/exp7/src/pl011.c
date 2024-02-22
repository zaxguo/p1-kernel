/* 
    A trivial driver for Arm PL011 (UART) 
    by xzl, 2024
*/

#include <stdint.h>
#include "utils.h"

#define UART_DR(base)   __REG32(base + 0x00)
#define UART_FR(base)   __REG32(base + 0x18)
#define UART_CR(base)   __REG32(base + 0x30)
#define UART_IMSC(base) __REG32(base + 0x38)
#define UART_ICR(base)  __REG32(base + 0x44)

#define UARTFR_RXFE     0x10
#define UARTFR_TXFF     0x20
#define UARTIMSC_RXIM   0x10
#define UARTIMSC_TXIM   0x20
#define UARTICR_RXIC    0x10
#define UARTICR_TXIC    0x20

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
    UART_CR(hw_base) = (1 << 0) | (1 << 8) | (1 << 9);
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