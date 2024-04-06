#include "utils.h"
#include "plat.h"
#include "circle-glue.h"
#include "gpio.h"

// re: pull-up/down https://grantwinney.com/using-pullup-and-pulldown-resistors-on-the-raspberry-pi/
enum {
    GPIO_MAX_PIN       = 53,
    GPIO_FUNCTION_OUT  = 1,
    GPIO_FUNCTION_ALT5 = 2,
    GPIO_FUNCTION_ALT3 = 7,
    GPIO_FUNCTION_ALT0 = 4
};

// Change reg bits given GPIO pin number. return 1 on OK
static unsigned int gpio_call(unsigned int pin_number, unsigned int value, 
    unsigned int base, unsigned int field_size, unsigned int field_max) {
    unsigned int field_mask = (1 << field_size) - 1;
  
    if (pin_number > field_max) return 0;
    if (value > field_mask) return 0; 

    unsigned int num_fields = 32 / field_size;
    unsigned int reg = base + ((pin_number / num_fields) * 4);
    unsigned int shift = (pin_number % num_fields) * field_size;

    unsigned int curval = get32va(reg);
    curval &= ~(field_mask << shift);
    curval |= value << shift;
    put32va(reg, curval);

    return 1;
}

unsigned int gpio_set     (unsigned int pin_number, unsigned int value) 
    { return gpio_call(pin_number, value, ARM_GPIO_GPSET0, 1, GPIO_MAX_PIN); }
unsigned int gpio_clear   (unsigned int pin_number, unsigned int value) 
    { return gpio_call(pin_number, value, ARM_GPIO_GPCLR0, 1, GPIO_MAX_PIN); }

// Below: set up GPIO pull modes. protocol recommended by the bcm2837 manual 
//    (pg 101, "GPIO Pull-up/down Clock Registers")
// cf: https://github.com/bztsrc/raspi3-tutorial/blob/master/03_uart1/uart.c
// cf Circle void CGPIOPin::SetPullMode
enum {
    Pull_None = 0,
    Pull_Down = 1, // Are down and up the right way around?
    Pull_Up = 2
};
unsigned int gpio_pull (unsigned int pin_number, unsigned int mode) { 
    unsigned long clkreg = ARM_GPIO_GPPUDCLK0 + (pin_number / 32) * 4;
    unsigned int regmask = 1 << (pin_number % 32);

    put32va(ARM_GPIO_GPPUD, mode); 
    delay(150);   // per manual
    put32va(clkreg, regmask); 
    delay(150);  
    put32va(ARM_GPIO_GPPUD, 0); 
    put32va(clkreg, 0); 

    return 0;
}

unsigned int gpio_function(unsigned int pin_number, unsigned int value) 
    { return gpio_call(pin_number, value, ARM_GPIO_GPFSEL0, 3, GPIO_MAX_PIN); }

// Rpi3 GPIO functions
// https://fxlin.github.io/p1-kernel/exp1/rpi-os/#init-gpio-alternative-function-selection

void gpio_useAsAlt0(unsigned int pin_number) {
    gpio_pull(pin_number, Pull_None);
    gpio_function(pin_number, GPIO_FUNCTION_ALT0);
}

void gpio_useAsAlt3(unsigned int pin_number) {
    gpio_pull(pin_number, Pull_None);
    gpio_function(pin_number, GPIO_FUNCTION_ALT3);
}

void gpio_useAsAlt5(unsigned int pin_number) {
    gpio_pull(pin_number, Pull_None);
    gpio_function(pin_number, GPIO_FUNCTION_ALT5);
}

//// gpio clock 
// cf: BCM2835 manual, pg 105, "General Purpose GPIO Clocks"
// "The General Purpose clocks can be output to GPIO pins. They run from the peripherals clock
// sources and use clock generators with noise-shaping MASH dividers. These allow the GPIO
// clocks to be used to drive audio devices."

#define CLK_CTL_MASH(x)		((x) << 9)
#define CLK_CTL_BUSY		(1 << 7)
#define CLK_CTL_KILL		(1 << 5)
#define CLK_CTL_ENAB		(1 << 4)
#define CLK_CTL_SRC(x)		((x) << 0)

#define CLK_DIV_DIVI(x)		((x) << 12)
#define CLK_DIV_DIVF(x)		((x) << 0)

void gpioclock_init(struct gpioclock_dev *desc, TGPIOClock clock) {
    desc->clock = clock; desc->source = GPIOClockSourceUnknown; 
}

void gpioclock_stop(struct gpioclock_dev *desc) {
	unsigned nCtlReg = ARM_CM_GP0CTL + (desc->clock * 8);

	// PeripheralEntry ();

	put32va (nCtlReg, ARM_CM_PASSWD | CLK_CTL_KILL);
	while (get32va (nCtlReg) & CLK_CTL_BUSY)
	{
		// wait for clock to stop
	}

	// PeripheralExit ();
}

// nDivI: 1..4095, allowed minimum depends on MASH
// nDivF: 0..4095
// nMASH: 0..3 MASH control
// cf: SoC manual, table 6-33 "Example of Frequency Spread when using MASH Filtering"
static void gpioclock_start(struct gpioclock_dev *desc, 
            unsigned nDivI, unsigned nDivF, unsigned nMASH) {
	static unsigned MinDivI[] = {1, 2, 3, 5};
	assert (nMASH <= 3);
	assert (MinDivI[nMASH] <= nDivI && nDivI <= 4095);
	assert (nDivF <= 4095);

	unsigned nCtlReg = ARM_CM_GP0CTL + (desc->clock * 8);
	unsigned nDivReg  = ARM_CM_GP0DIV + (desc->clock * 8);

	gpioclock_stop (desc);

	// PeripheralEntry ();

	put32va (nDivReg, ARM_CM_PASSWD | CLK_DIV_DIVI (nDivI) | CLK_DIV_DIVF (nDivF));
	us_delay(10); 
	assert (desc->source < GPIOClockSourceUnknown);
	put32va (nCtlReg, ARM_CM_PASSWD | CLK_CTL_MASH (nMASH) | CLK_CTL_SRC (desc->source));
	us_delay(10); 
	put32va (nCtlReg, read32 (nCtlReg) | ARM_CM_PASSWD | CLK_CTL_ENAB);
}

// assigns clock source automatically
// return 1 on ok 
int gpioclock_start_rate(struct gpioclock_dev *desc, unsigned nRateHZ) {
	assert (nRateHZ > 0);
	// xzl: iterate through all available clock sources, find one aivalable ....
	//			will write the source id to reg in Start()
	for (unsigned nSourceId = 0; nSourceId <= GPIO_CLOCK_SOURCE_ID_MAX; nSourceId++)
	{
		unsigned nSourceRate = CMachineInfo_GetGPIOClockSourceRate (nSourceId);
        if (nSourceRate == GPIO_CLOCK_SOURCE_UNUSED) {
            continue;
        }

        unsigned nDivI = nSourceRate / nRateHZ;
        if (1 <= nDivI && nDivI <= 4095 && nRateHZ * nDivI == nSourceRate) {
            desc->source = (TGPIOClockSource)nSourceId;
            gpioclock_start(desc, nDivI, 0, 0 /*mash*/); // use simplest strategy?
            return 1;
        }
    }
	return 0;
}