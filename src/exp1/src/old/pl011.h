/* derived from: 
    https://github.com/m8/armvisor/blob/master/src/arch/aarch64/inc/uart.h

    xzl, feb 2024
*/

#ifndef AV_UART_H
#define AV_UART_H

#define DR_DATA_MASK                (0xFF)
#define RX_INTERRUPT	            (1U << 4U)
#define BE_INTERRUPT	            (1U << 9U)
#define LCRH_FEN                    (1U << 4U)
#define CR_UARTEN                   (1U	<< 0U)      // xzl: enable 
#define IMSC_RXIM		            (1U << 4U)
#define FR_RXFE                     (1U	<< 4U)
#define RSRECR_ERR_MASK             (0xF)

#define REG32  unsigned int    // 32 bit register

struct __attribute__((packed)) PL011_REGS
{
	REG32 DR;                            
	REG32 RSRECR;                        
	REG32 __empty0__[4];                 
	REG32 FR;                            
	REG32 __empty1__;                    
	REG32 ILPR;                          
	REG32 IBRD;                          
	REG32 FBRD;                          
	REG32 LCRH;                          
	REG32 CR;                            
	REG32 IFLS;				            
	REG32 IMSC;				            
	REG32 RIS;				            
	REG32 MIS;				            // xzl: irq status..??
	REG32 ICR;				            
} ;

static struct PL011_REGS* UART_DEVICE = (struct PL011_REGS*)0x09000000;
#endif

