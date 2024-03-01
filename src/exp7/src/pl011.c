/* 
    A driver for Arm PL011 (UART), v2    
    by xzl, 2024

    supports output buffer, rx/tx irqs, sleep/wake, thread safe
    
    cf: 
    xv6 uart. c
    https://github.com/RT-Thread/rt-thread/blob/master/bsp/qemu-virt64-aarch64/drivers/drv_uart.c

*/

#include <stdint.h>
#include "utils.h"
#include "spinlock.h"

// https://developer.arm.com/documentation/ddi0183/f/programmer-s-model/register-descriptions
// enable fifo via the line control reg
// https://developer.arm.com/documentation/ddi0183/f/programmer-s-model/register-descriptions/line-control-register--uartlcr-h
// fifo level: 
// https://developer.arm.com/documentation/ddi0183/f/programmer-s-model/register-descriptions/interrupt-fifo-level-select-register--uartifls
// tx irq desc:
// https://developer.arm.com/documentation/ddi0183/f/programmer-s-model/interrupts/uarttxintr

#define UART_DR(base)   __REG32(base + 0x00)
#define UART_FR(base)   __REG32(base + 0x18)        // Flag 
#define UART_LCR(base)   __REG32(base + 0x2c)        // Line control
#define UART_CR(base)   __REG32(base + 0x30)        // Control
#define UART_IMSC(base) __REG32(base + 0x38)        // Interrupt mask set/clear register
#define UART_ICR(base)  __REG32(base + 0x44)        // Interrupt clear register 

#define UARTFR_RXFE     0x10        // rx fifo empty
#define UARTFR_TXFF     0x20        // tx fifo full
#define UARTIMSC_RXIM   0x10        // rx irq mask
#define UARTIMSC_TXIM   0x20        // tx irq mask
#define UARTICR_RXIC    0x10        // irq clear: rx
#define UARTICR_TXIC    0x20        // irq clear: tx
#define UARTLCR_FEN     (1<<4)      // FIFO enable. 

// the transmit output buffer.
struct spinlock uart_tx_lock;
#define UART_TX_BUF_SIZE 32
char uart_tx_buf[UART_TX_BUF_SIZE];
uint64 uart_tx_w; // write next to uart_tx_buf[uart_tx_w % UART_TX_BUF_SIZE]
uint64 uart_tx_r; // read next from uart_tx_buf[uart_tx_r % UART_TX_BUF_SIZE]

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

/* ------------------------ new apis ---------------------- */

void uartstart();

void uart_init (unsigned long base) {
    hw_base = base; 

    /* disable rx irq */
    // UART_IMSC(hw_base) &= ~UARTIMSC_RXIM;

    /* enable fifo (so we have fewer tx irqs?)*/
    UART_LCR(hw_base) |= UARTLCR_FEN; 

    /* enable Rx and Tx of UART */
    UART_CR(hw_base) = (1 << 0) | (1 << 8) | (1 << 9);  // uart_enable | tx_enable | rx_enable 

    /* enable rx irq */
    UART_IMSC(hw_base) |= UARTIMSC_RXIM;

    /* enable tx irq */
    UART_IMSC(hw_base) |= UARTIMSC_TXIM;

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
    initlock(&uart_tx_lock, "uart");
}

// add a character to the output buffer and tell the
// UART to start sending if it isn't already.
// blocks if the output buffer is full.
// because it may block, it can't be called
// from interrupts; it's only suitable for use
// by write().
void uartputc(int c) {
    acquire(&uart_tx_lock);

    // if (panicked) { // freeze uart out from other cpus. we dont need it (xzl)
    //     for (;;)
    //         ;
    // }
    while (uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE) {
        // buffer is full.
        // wait for uartstart() to open up space in the buffer.
        sleep(&uart_tx_r, &uart_tx_lock);
    }
    uart_tx_buf[uart_tx_w % UART_TX_BUF_SIZE] = c;
    uart_tx_w += 1;
    uartstart();
    release(&uart_tx_lock);
}

// alternate version of uartputc() that doesn't 
// use interrupts, for use by kernel printf() and
// to echo characters. it spins waiting for the uart's
// output register to be empty.
void
uartputc_sync(int c)
{
  push_off();

//   if(panicked){          // cf above
//     for(;;)
//       ;
//   }

  // wait for Transmit Holding Empty to be set in LSR.
  while (UART_FR(hw_base) & UARTFR_TXFF)
        ;
  UART_DR(hw_base) = (uint32_t)c;

  pop_off();
}

// if the UART is idle, and a character is waiting
// in the transmit buffer, send it.
// caller must hold uart_tx_lock.
// called from both the top- and bottom-half.
void
uartstart()
{
  while(1){
    if(uart_tx_w == uart_tx_r){
      // transmit buffer is empty.
      return;
    }
    
    if(UART_FR(hw_base) & UARTFR_TXFF){
      // the UART transmit holding register is full,
      // so we cannot give it another byte.
      // it will interrupt when it's ready for a new byte.
      return;
    }
    
    int c = uart_tx_buf[uart_tx_r % UART_TX_BUF_SIZE];
    uart_tx_r += 1;
    
    // maybe uartputc() is waiting for space in the buffer.
    wakeup(&uart_tx_r);
    
    UART_DR(hw_base) = (uint32_t)c;
  }
}

// read one input character from the UART.
// return -1 if none is waiting.
int
uartgetc(void)
{
  if(!(UART_FR(hw_base) & UARTFR_RXFE)) {
    // input data is ready.
    return (int)(UART_DR(hw_base) & 0xff);
  } else {
    return -1;
  }
}

// handle a uart interrupt, raised because input has
// arrived, or the uart is ready for more output, or
// both. called from handle_irq()
// xzl: shall we differentiate between rx/tx irq?
void
uartintr(void)
{
  // printf("%s:%d called\n", __func__, __LINE__);

  // clear rx irq, must be done before we read 
  UART_ICR(hw_base) |= UARTICR_RXIC;

  // read and process incoming characters.
  while(1){
    int c = uartgetc();
    if(c == -1)
      break;
    consoleintr(c);
  }

  UART_ICR(hw_base) |= UARTICR_TXIC; // clear tx irq

  // send buffered characters.
  acquire(&uart_tx_lock);
  uartstart();
  release(&uart_tx_lock);
}

// This function is required by printf()
void putc(void* p, char c) {
	consputc(c);
}