// Mar 2024: messy mini uart code with lots of experimental code.


#include <stdint.h>
#include "utils.h"
#include "spinlock.h"

// cf: https://github.com/futurehomeno/RPI_mini_UART/tree/master

#define PBASE   hw_base
// ---------------- gpio ------------------------------------ //
#define GPFSEL1         (PBASE+0x00200004)
#define GPSET0          (PBASE+0x0020001C)
#define GPCLR0          (PBASE+0x00200028)
#define GPPUD           (PBASE+0x00200094)
#define GPPUDCLK0       (PBASE+0x00200098)

// ---------------- mini uart ------------------------------------ //
// "The Device has three Auxiliary peripherals: One mini UART and two SPI masters. These
// three peripheral are grouped together as they share the same area in the peripheral register
// map and they share a common interrupt."
#define AUXIRQ          (PBASE+0x00215000)    // bit0: "If set the mini UART has an interrupt pending"
#define AUX_ENABLES     (PBASE+0x00215004)    // "AUXENB" in datasheet
#define AUX_MU_IO_REG   (PBASE+0x00215040)
#define AUX_MU_IER_REG  (PBASE+0x00215044)    // enable tx/rx irqs
  #define AUX_MU_IER_RXIRQ_ENABLE 1U      
  #define AUX_MU_IER_TXIRQ_ENABLE 2U      

#define AUX_MU_IIR_REG  (PBASE+0x00215048)    // check irq cause, fifo clear
  #define IS_TRANSMIT_INTERRUPT(x) (x & 0x2)  //0b010  tx empty
  #define IS_RECEIVE_INTERRUPT(x) (x & 0x4)   //0b100  rx ready
  #define FLUSH_UART 0xC6

#define AUX_MU_LCR_REG  (PBASE+0x0021504C)
#define AUX_MU_MCR_REG  (PBASE+0x00215050)

#define AUX_MU_LSR_REG  (PBASE+0x00215054)
  #define IS_TRANSMITTER_EMPTY(x) (x & 0x10)
  #define IS_TRANSMITTER_IDLE(x)  (x & 0x20)
  #define IS_DATA_READY(x) (x & 0x1)
  #define IS_RECEIVER_OVEERUN(x) (x & 0x2)
#define AUX_MU_MSR_REG  (PBASE+0x00215058)

#define AUX_MU_SCRATCH  (PBASE+0x0021505C)
#define AUX_MU_CNTL_REG (PBASE+0x00215060)

#define AUX_MU_STAT_REG (PBASE+0x00215064)

#define AUX_MU_BAUD_REG (PBASE+0x00215068)

// the transmit output buffer.
struct spinlock uart_tx_lock;
#define UART_TX_BUF_SIZE 32
char uart_tx_buf[UART_TX_BUF_SIZE];
uint64 uart_tx_w=0; // write next to uart_tx_buf[uart_tx_w % UART_TX_BUF_SIZE]
uint64 uart_tx_r=0; // read next from uart_tx_buf[uart_tx_r % UART_TX_BUF_SIZE]

static unsigned long hw_base = 0;  // we are on virt addr space

static long delay_cycles = 0; 
long uart_send_profile (char c)
{
  long cnt = 0; 
	while(1) {
    cnt ++; 
		if(get32(AUX_MU_LSR_REG) & 0x20) 
			break;
	}
	put32(AUX_MU_IO_REG, c);
  return cnt; 
}

void uart_send (char c)
{
	while(1) {
		if(get32(AUX_MU_LSR_REG) & 0x20) 
			break;
	}
	put32(AUX_MU_IO_REG, c);
}
 
char uart_recv (void)
{
	while(1) {
		if(get32(AUX_MU_LSR_REG) & 0x01) 
			break;
	}
	return(get32(AUX_MU_IO_REG) & 0xFF);
}

void uart_send_string(char* str)
{
	for (int i = 0; str[i] != '\0'; i ++) {
		uart_send((char)str[i]);
	}
}

/* ------------------------ new apis ---------------------- */
void uartstart();

__attribute__ ((unused)) static void uart_enable_rx_irq() {
  unsigned int ier = get32(AUX_MU_IER_REG); 
  put32(AUX_MU_IER_REG, ier | AUX_MU_IER_RXIRQ_ENABLE);
}

__attribute__ ((unused)) static void uart_enable_tx_irq() {
  unsigned int ier = get32(AUX_MU_IER_REG); 
  put32(AUX_MU_IER_REG, ier | AUX_MU_IER_TXIRQ_ENABLE);
  // E("enable tx irq");
}

__attribute__ ((unused)) static void uart_disable_tx_irq() {
  // unsigned int ier = get32(AUX_MU_IER_REG); 
  // put32(AUX_MU_IER_REG, ier & (~AUX_MU_IER_TXIRQ_ENABLE));
  put32(AUX_MU_IER_REG, 0);
  // E("disable tx irq");
}

__attribute__ ((unused)) static unsigned int uart_tx_empty() {
  unsigned int lsr = get32(AUX_MU_LSR_REG);
  return IS_TRANSMITTER_EMPTY(lsr);
}

__attribute__ ((unused)) static unsigned int uart_tx_idle() {
  unsigned int lsr = get32(AUX_MU_LSR_REG);
  return IS_TRANSMITTER_IDLE(lsr);
}


void uart_init (unsigned long base) {
  hw_base = base; 

	unsigned int selector;

	selector = get32(GPFSEL1);
	selector &= ~(7<<12);                   // clean gpio14
	selector |= 2<<12;                      // set alt5 for gpio14
	selector &= ~(7<<15);                   // clean gpio15
	selector |= 2<<15;                      // set alt5 for gpio15
	put32(GPFSEL1,selector);

	put32(GPPUD,0);
	delay(150);
	put32(GPPUDCLK0,(1<<14)|(1<<15));
	delay(150);
	put32(GPPUDCLK0,0);

  put32(AUX_MU_IIR_REG, FLUSH_UART);    // flush FIFO

	put32(AUX_ENABLES,1);                   //Enable mini uart (this also enables access to it registers)
	put32(AUX_MU_CNTL_REG,0);               //Disable auto flow control and disable receiver and transmitter (for now)
	
  // put32(AUX_MU_IER_REG, 0);                //Disable receive and transmit interrupts
  put32(AUX_MU_IER_REG,  (3<<2) | (0xf<<4));    // bit 7:4 3:2 must be 1
  uart_enable_rx_irq(); 
	
  put32(AUX_MU_LCR_REG,3);                //Enable 8 bit mode
	put32(AUX_MU_MCR_REG,0);                //Set RTS line to be always high
	put32(AUX_MU_BAUD_REG,270);             //Set baud rate to 115200

	put32(AUX_MU_CNTL_REG,3);               //Finally, enable transmitter and receiver

  initlock(&uart_tx_lock, "uart");


  // profile 
  uart_send_string("a very long string that exceeds the size of the fifo buffer");
  delay_cycles = uart_send_profile('T'); 
  // long cnt = 0; 
  // while(1) {
  //   cnt ++; 
  //   if(get32(AUX_MU_LSR_REG) & 0x20) 
  //     break;
  // }
  // printf("cnt = %ld", cnt); 
}

// add a character to the output buffer and tell the
// UART to start sending if it isn't already.
// blocks if the output buffer is full.
// because it may block, it can't be called
// from interrupts; it's only suitable for use
// by write().
void uartputc(int c) {
    acquire(&uart_tx_lock);
    V("called %c", c);

    // if (panicked) { // freeze uart out from other cpus. we dont need it (xzl)
    //     for (;;)
    //         ;
    // }
    while (uart_tx_w == uart_tx_r + UART_TX_BUF_SIZE) {
        // buffer is full.
        // wait for uartstart() to open up space in the buffer.
        W("going to sleep...");
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
void uartputc_sync(int c) {
  push_off();

//   if(panicked){while(1);}         // cf above

  while(1) {    
		if(get32(AUX_MU_LSR_REG) & 0x20) 
			break;
	}
	put32(AUX_MU_IO_REG, c);

  pop_off();
}

// if the UART is idle, and a character is waiting
// in the transmit buffer, send it.
// caller must hold uart_tx_lock.
// called from both the top- and bottom-half.
void uartstart() {
  // char need_tx_irq = 0; 

  while(1) {
    if(uart_tx_w == uart_tx_r){
      // transmit buffer is empty.
      // if (need_tx_irq)
      //   uart_enable_tx_irq(); 
      return;
    }

      // xzl: if called from irq, should spin here until all previous
      //    uart writes (printf()) are done? otherwise the line below
      //    may never get a chance to write to uart ....

    while (1) {
        // if (get32(AUX_MU_LSR_REG) & 0x20)
            // if(get32(AUX_MU_LSR_REG) & 0x10) // not working
            // if (uart_tx_empty())
        if (uart_tx_idle())   // works??
            break;
    }

#if 0 
    if(!uart_tx_empty()) {
      // E("tx busy...");      
      // xzl: almost always busy....??? no chance to write??
      // should alwasy enable tx irwq here???

      // the UART transmit holding register is full,
      // so we cannot give it another byte.
      // it will interrupt when it's ready for a new byte.
      // if (need_tx_irq)
        uart_enable_tx_irq(); 
      return;
    }
#endif

    int c = uart_tx_buf[uart_tx_r % UART_TX_BUF_SIZE];
    uart_tx_r += 1;
    
    // maybe uartputc() is waiting for space in the buffer.
    wakeup(&uart_tx_r);
    
    put32(AUX_MU_IO_REG, c); 
    // need_tx_irq = 1; 
    V("send a byte...");
  }
}

// FL: AUX_MU_LSR_REG seems not working. always return -1
// read one input character from the UART.
// return -1 if none is waiting.
// int
// uartgetc(void)
// {
//   if(!(get32(AUX_MU_LSR_REG) & 0x01)) {
//     // input data is ready.
//     return (int)(get32(AUX_MU_IO_REG) & 0xFF);
//   } else {
//     return -1;
//   }
// }

int uartgetc(void)
{
  if(!(get32(AUX_MU_STAT_REG) & 0xF0000)) {
    return -1;
  } else {
    // rx fifo has bytes
    return (int)(get32(AUX_MU_IO_REG) & 0xFF);
  }
}

// handle a uart interrupt, raised because input has
// arrived, or the uart is ready for more output, or
// both. called from handle_irq()
// xzl: shall we differentiate between rx/tx irq?
void uartintr(void) {
  // TODO: check AUX_MU_IIR_REG bit0 for pending irq
  //    and 2:1 for irq causes
  uint iir = get32(AUX_MU_IIR_REG); 
  if (iir & 1) 
    return; 

  V("pending irq: p %d w %d r %d", (iir & 1), (iir & 2), (iir & 4));
    
  // clear rx irq, must be done before we read 
  // no need for mini uart??

#if 1 
  // read and process incoming characters.
  if (IS_RECEIVE_INTERRUPT(iir)) {
    while(1){
      int c = uartgetc();
      if(c == -1) {
        // W("no char");
        break;
      }
      // W("read a char");
      consoleintr(c);
    }
  }
#endif

  // clear tx irq XXX no need for mini uart?
  // no need for mini uart??
#if 1
  if (IS_TRANSMIT_INTERRUPT(iir)) {
    // uart_disable_tx_irq(); 
    // send buffered characters.
    acquire(&uart_tx_lock);
    uartstart();
    release(&uart_tx_lock);
  }
#endif  
}


// This function is required by printf function
void putc ( void* p, char c)
{
	uart_send(c);
}
