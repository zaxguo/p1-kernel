# 1: Baremetal HelloWorld

**READING TIME:  40 MIN**

## Objectives

![](figures/helloworld.png)

![](figures/overview.png)

We will build: a minimal, baremetal program that can print "Hello world" via Rpi3's UART. 

Students will experience: 

1. The C project structure

2. The use of cross-compilation toolchain

3. arm64 assembly (lightly)

4. Basic knowledge on Rpi3 and its UART hardware


## Get the code 

Code location: p1-kernel/src/exp1

Please: do a `git pull` even if you have cloned the p1-kenel repo previously, in case of upstream updates. 

Load pre-defined commands: "cd p1-kernel && source env-qemu.sh". Make sure you read env-qemu.sh.

## Roadmap

Create a Makefile project. Add minimum code to boot the platform. Initialize the UART hardware. Send characters to the UART registers. 

## Terms 

1. Strictly speaking, this baremetal program is not a "kernel". We nevertheless call it so for ease of explanation. 

2. "QEMU" means the Rpi3 platform as emulated by QEMU (route 1). "Raspberry Pi" means the actual Rpi3 hardware (route 2). We will explain details where the real hardware behaves differently from QEMU. 

## Code walkthrough

1. `Makefile.qemu`: We will use the GNU Makefile to build the kernel. This file contains detailed comments. A refresher of Makefile: [this](http://opensourceforu.com/2012/06/gnu-make-in-detail-for-beginners/) article. 
1. `src`: This folder contains all of the source code.
1. `include`: All of the header files are placed here. 

### The linker script (src/linker-qemu.ld)

A linker script describes how the sections in the input object files (`_c.o` and `_s.o`) should be mapped into the output file (`.elf`); it also controls the addresses of all program symbols (e.g. functions and variables). More information can be found [here](https://sourceware.org/binutils/docs/ld/Scripts.html#Scripts). Now let's take a look at the linker script:

```
SECTIONS
{
    .text.boot : { *(.text.boot) }
    .text :  { *(.text) }
    .rodata : { *(.rodata) }
    .data : { *(.data) }
    . = ALIGN(0x8);
    bss_begin = .;
    .bss : { *(.bss*) } 
    bss_end = .;
}
```

After startup, the Rpi3 GPU loads `kernel8.img` into memory 0x0 and starts execution from the beginning of the file. That's why the `.text.boot` section must come first; we are going to put the kernel startup code inside this section. QEMU behaves differently: it loads the kernel image at 0x80000. 

>  Q: How to tweak the linker script to update the start address?

The `.text`, `.rodata`, and `.data` sections contain kernel instructions, read-only data, and global data with init values. The `.bss` section contains data that should be initialized to 0. By putting such data in a separate section, the compiler can save some space in the ELF binary––only the section size is stored in the ELF header, but the section content is omitted. 

After booting up, our kernel initializes the `.bss` section to 0; that's why we need to record the start and end of the section (hence the `bss_begin` and `bss_end` symbols) and align the section so that it starts at an address that is a multiple of 8. This eases kernel programming because the `str` instruction can be used only with 8-byte-aligned addresses.

## Kernel startup

### Booting the kernel

boot.S (src/boot.S) contains the kernel startup code. It has detailed comments. 

> Q: It may make more sense to put core 1-3 in deep sleep using ``wfi``. How? 

### Kernel memory layout

If the current processor ID is 0, then execution branches to the `master` function:

After cleaning the `.bss` section, the kernel initializes the stack pointer and passes execution to the `kernel_main` function. The Rpi3 loads the kernel at address 0 (QEMU loads at 0x80000); that's why the initial stack pointer can be set to any location high enough so that stack will not override the kernel image when it grows sufficiently large. `LOW_MEMORY` is defined in [mm.h](https://github.com/fxlin/p1-kernel/blob/master/src/exp1/include/mm.h) and is equal to 4MB. As our kernel's stack won't grow very large and the image itself is tiny, 4MB is more than enough for us. 

![](figures/mem-0.png)

**Aside: Some ARM64 instructions used** 

For those of you who are not familiar with ARM assembler syntax, let me quickly summarize the instructions that we have used:

* [**mrs**](http://www.keil.com/support/man/docs/armasm/armasm_dom1361289881374.htm) Load value from a system register to one of the general purpose registers (x0–x30)
* [**and**](http://www.keil.com/support/man/docs/armasm/armasm_dom1361289863017.htm) Perform the logical AND operation. We use this command to strip the last byte from the value we obtain from the `mpidr_el1` register.
* [**cbz**](http://www.keil.com/support/man/docs/armasm/armasm_dom1361289867296.htm) Compare the result of the previously executed operation to 0 and jump (or `branch` in ARM terminology) to the provided label if the comparison yields true.
* [**b**](http://www.keil.com/support/man/docs/armasm/armasm_dom1361289863797.htm) Perform an unconditional branch to some label.
* [**adr**](http://www.keil.com/support/man/docs/armasm/armasm_dom1361289862147.htm) Load a label's relative address into the target register. In this case, we want pointers to the start and end of the `.bss` region.
* [**sub**](http://www.keil.com/support/man/docs/armasm/armasm_dom1361289908389.htm) Subtract values from two registers.
* [**bl**](http://www.keil.com/support/man/docs/armasm/armasm_dom1361289865686.htm) "Branch with a link": perform an unconditional branch and store the return address in x30 (the link register). When the subroutine is finished, use the `ret` instruction to jump back to the return address.
* [**mov**](http://www.keil.com/support/man/docs/armasm/armasm_dom1361289878994.htm) Move a value between registers or from a constant to a register.

Our [cheat sheet](../cheatsheet.md) summarizes common ARM64 instructions. 

For official documentation, [here](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.den0024a/index.html) is the ARMv8-A developer's guide. It's a good resource if the ARM ISA is unfamiliar to you. [This page](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.den0024a/ch09s01s01.html) specifically outlines the register usage convention in the ABI.

### The `kernel_main` function

We have seen that the boot code eventually passes control to the `kernel_main` function. (VSCode: Ctrl-t then type "kernel_main")
```
#include "mini_uart.h"

void kernel_main(void)
{
    uart_init();
    uart_send_string("Hello, world!\r\n");

    while (1) {
        uart_send(uart_recv());
    }
}
```

This function is one of the simplest in the kernel. It works with the `Mini UART` device to print to screen and read user input. The kernel just prints `Hello, world!` and then enters an infinite loop that reads characters from the user and sends them back to the screen.

## A bit about the Rpi3 hardware
The Rpi3 board is based on the BCM2837 SoC by Broadcom. The SoC manual is [here](https://github.com/raspberrypi/documentation/files/1888662/BCM2837-ARM-Peripherals.-.Revised.-.V2-1.pdf). The SoC is not friendly for OS hackers: Broadcom poorly documents it and the hardware has many quirks. 

Despite so, the community figured out most of the SoC details over years because Rpi3's popularity. It's not our goal to dive in the SoC. Rather, our philosophy is to deal BCM2837-specific details as few as possible -- just enough to get our kernel working. We will spend more efforts on explaining generic hardware such as ARM64 cores, generic timers, irq controllers, etc. 

> Rpi4 seems more friendly to kernel hackers. 

### Memory-mapped IO
On ARM-based SoCs, access to all devices is performed via memory-mapped registers. The Rpi3 SoC reserves physical memory address `0x3F000000` for IO devices. To configure a particular device, software reads/writes device registers. A device register is just a 32-bit region of memory. The meaning of each bit in each IO register is described in the SoC manual. 

<!---- Take a look at section 1.2.3 ARM physical addresses in the SoC manual and the surrounding documentation for more context on why we use `0x3F000000` as a base address (even though `0x7E000000` is used throughout the manual). ---->

> The term "device" is heavily overloaded in many tech docs. Sometimes it means a board, e.g. "an Rpi3 device"; sometimes it means an IO peripheral, e.g. "UART device". We will be explicit. 

### UART
UART is a simple character device allowing software to send out text characters to a different machine. If you do not care about performance, UART requires very minimum software code. Therefore, it is often the first few IO devices to bring up when we build system software for a new machine. Only with UART meaning debugging is possible. (JTAG is another option which however requires more complex setup).

In the simplest form, software writes ascii values to UART registers. The UART device converts written values to a sequence of high and low voltages on wire. This sequence is transmitted to your via the `TTL-to-serial cable` and is interpreted by your terminal emulator (e.g. PuTTY on Windows). 

Rpi3 has the two UART devices. Oddly enough, they are different. 

| Name  | Type      | Comments                                   |
| :---- | :-------- | ------------------------------------------ |
| UART0 | PL011     | Secondary, intended as Bluetooth connector |
| UART1 | mini UART | Primary, intended as debug console         |

UART1/Mini UART: easier to program; limited performance/functionalities. That's fine for our goal. For specification of the Mini UART registers: see page 8 of the SoC manual. 

UART0/PL011: richer functions; higher speed. Yet one needs to configure the board clock by talking to the GPU firmware. We won't do that. see [Example code](https://github.com/bztsrc/raspi3-tutorial/tree/master/05_uart0) if you are interested. 

**Both UARTs can be mapped to the same physical pins** by setting the GPFSEL1 register. See the GPIO function diagram below. 

That's enough to know about Rpi UARTs. More:  [official web page](https://www.raspberrypi.org/documentation/configuration/uart.md). 

### GPIO

Another IO device is GPIO [General-purpose input/output](https://en.wikipedia.org/wiki/General-purpose_input/output). GPIO provides a bunch of registers. Each bit in such a register corresponds to a pin on the Rpi3 board. By writing 1 or 0 to register bits, software can control the output voltage on the pins, e.g. for turning on/off LEDs connected to such pins. Reading is done in a similar fashion. The picture below shows GPIO pin headers populated on Rpi3. (Note: the picture shows Rpi2, which has the same pinout as Rpi3)

![](../images/gpio-pins.jpg)

An SoC often has limited number of pins. Software can control the use of these pins, e.g. for GPIO or for UART. Software does so by writing to specific memory-mapped registers. 

The GPIO can be used to configure the behavior of different GPIO pins. For example, to be able to use the Mini UART, we need to activate pins 14 and 15 and set them up to use this device. The image below illustrates how numbers are assigned to the GPIO pins:

![](../images/gpio-numbers.png)

## Walkthrough: the UART code

The following init code configures pin 14 & 15 as UART in/out, sets up UART clock and its modes, etc. 

> Much of the UART init code is irrelevant to QEMU. Since QEMU "emulates" the UARTs, it can dump whatever our kernel writes to the emulated UART registers to stdio. Example: ``qemu-system-aarch64 -M raspi3 -kernel ./kernel8.img -serial null -serial stdio``
>
> The first -serial means UART0 which we do not touch; the second -serial means we direct UART1 to stdio. 

```
void uart_init ( void )
{
    unsigned int selector;

    selector = get32(GPFSEL1);
    selector &= ~(7<<12);                   // clean gpio14
    selector |= 2<<12;                      // set alt5 for gpio14
    selector &= ~(7<<15);                   // clean gpio15
    selector |= 2<<15;                      // set alt5 for gpio 15
    put32(GPFSEL1,selector);

    put32(GPPUD,0);
    delay(150);
    put32(GPPUDCLK0,(1<<14)|(1<<15));
    delay(150);
    put32(GPPUDCLK0,0);

    put32(AUX_ENABLES,1);                   //Enable mini uart (this also enables access to it registers)
    put32(AUX_MU_CNTL_REG,0);               //Disable auto flow control and disable receiver and transmitter (for now)
    put32(AUX_MU_IER_REG,0);                //Disable receive and transmit interrupts
    put32(AUX_MU_LCR_REG,3);                //Enable 8 bit mode
    put32(AUX_MU_MCR_REG,0);                //Set RTS line to be always high
    put32(AUX_MU_BAUD_REG,270);             //Set baud rate to 115200

    put32(AUX_MU_CNTL_REG,3);               //Finally, enable transmitter and receiver
}
```

Here, we use the two functions `put32` and `get32`. Those functions are very simple -- read and write some data to and from a 32-bit register. You can take a look at how they are implemented in [utils.S](https://github.com/fxlin/p1-kernel/blob/master/src/exp1/src/utils.S). `uart_init` is one of the most complex and important functions in this lesson, and we will continue to examine it in the next three sections.

### Init: GPIO alternative function selection 

First, we need to activate the GPIO pins. Most of the pins can be used with different IO devices. So before using a particular pin, we need to select the pin's alternative function,  a number from 0 to 5 that can be set for each pin and configures which IO device is virtually "connected" to the pin. 

See the list of all available GPIO alternative functions in the image below (taken from page 102 of the SoC manual)

![Raspberry Pi GPIO alternative functions](../images/alt.png)

Here you can see that pins 14 and 15 have the TXD1 and RXD1 alternative functions available. This means that if we select alternative function number 5 for pins 14 and 15, they will be used as a Mini UART Transmit Data pin and Mini UART Receive Data pin, respectively. The `GPFSEL1` register is used to control alternative functions for pins 10-19. The meaning of all the bits in those registers is shown in the following table (page 92 of the SoC manual):

![Raspberry Pi GPIO function selector](../images/gpfsel1.png)

So now you know everything you need to understand the following lines of code that are used to configure GPIO pins 14 and 15 to work with the Mini UART device:

```
    unsigned int selector;

    selector = get32(GPFSEL1);
    selector &= ~(7<<12);                   // clean gpio14
    selector |= 2<<12;                      // set alt5 for gpio14
    selector &= ~(7<<15);                   // clean gpio15
    selector |= 2<<15;                      // set alt5 for gpio 15
    put32(GPFSEL1,selector);
```

Init: GPIO pull-up/down & how we disable it

When working with GPIO pins, you will often encounter terms such as pull-up/pull-down. These concepts are explained in great detail in [this](https://grantwinney.com/using-pullup-and-pulldown-resistors-on-the-raspberry-pi/) article. For those who are too lazy to read the whole article, I will briefly explain the pull-up/pull-down concept.

If you use a particular pin as input and don't connect anything to this pin, you will not be able to identify whether the value of the pin is 1 or 0. In fact, the device will report random values. The pull-up/pull-down mechanism allows you to overcome this issue. If you set the pin to the pull-up state and nothing is connected to it, it will report `1` all the time (for the pull-down state, the value will always be 0). In our case, we need neither the pull-up nor the pull-down state, because both the 14 and 15 pins are going to be connected all the time. 

**The pin state is preserved even after a reboot, so before using any pin, we always have to initialize its state.** There are three available states: pull-up, pull-down, and neither (to remove the current pull-up or pull-down state), and we need the third one.

Switching between pin states is not a very simple procedure because it requires physically toggling a switch on the electric circuit. This process involves the `GPPUD` and `GPPUDCLK` registers and is described on page 101 of the SoC manual:

```
The GPIO Pull-up/down Clock Registers control the actuation of internal pull-downs on
the respective GPIO pins. These registers must be used in conjunction with the GPPUD
register to effect GPIO Pull-up/down changes. The following sequence of events is
required:
1. Write to GPPUD to set the required control signal (i.e. Pull-up or Pull-Down or neither
to remove the current Pull-up/down)
2. Wait 150 cycles – this provides the required set-up time for the control signal
3. Write to GPPUDCLK0/1 to clock the control signal into the GPIO pads you wish to
modify – NOTE only the pads which receive a clock will be modified, all others will
retain their previous state.
4. Wait 150 cycles – this provides the required hold time for the control signal
5. Write to GPPUD to remove the control signal
6. Write to GPPUDCLK0/1 to remove the clock
```

**This procedure describes how we can remove both the pull-up and pull-down states from a pin**, which is what we are doing for pins 14 and 15 in the following code:

```
    put32(GPPUD,0);
    delay(150);
    put32(GPPUDCLK0,(1<<14)|(1<<15));
    delay(150);
    put32(GPPUDCLK0,0);
```

### Init: Mini UART

Now our Mini UART is connected to the GPIO pins, and the pins are configured. The rest of the `uart_init` function is dedicated to Mini UART initialization. 

```
    put32(AUX_ENABLES,1);                   //Enable mini uart (this also enables access to its registers)
    put32(AUX_MU_CNTL_REG,0);               //Disable auto flow control and disable receiver and transmitter (for now)
    put32(AUX_MU_IER_REG,0);                //Disable receive and transmit interrupts
    put32(AUX_MU_LCR_REG,3);                //Enable 8 bit mode
    put32(AUX_MU_MCR_REG,0);                //Set RTS line to be always high
    put32(AUX_MU_BAUD_REG,270);             //Set baud rate to 115200

    put32(AUX_MU_CNTL_REG,3);               //Finally, enable transmitter and receiver
```
Let's examine this code snippet line by line. 

```
    put32(AUX_ENABLES,1);                   //Enable mini uart (this also enables access to its registers)
```
This line enables the Mini UART. We must do this in the beginning, because this also enables access to all the other Mini UART registers.

-------------------

```
    put32(AUX_MU_CNTL_REG,0);               //Disable auto flow control and disable receiver and transmitter (for now)
```
Here we disable the receiver and transmitter before the configuration is finished. We also permanently disable auto-flow control because it requires us to use additional GPIO pins, and the TTL-to-serial cable doesn't support it. For more information about auto-flow control, you can refer to [this](http://www.deater.net/weave/vmwprod/hardware/pi-rts/) article.

--------------------------------------

```
    put32(AUX_MU_IER_REG,0);                //Disable receive and transmit interrupts
```
It is possible to configure the Mini UART to generate a processor interrupt each time new data is available. We want to be as simple as possible. So for now, we will just disable this feature.

-------------------

```
    put32(AUX_MU_LCR_REG,3);                //Enable 8 bit mode
```
Mini UART can support either 7- or 8-bit operations. This is because an ASCII character is 7 bits for the standard set and 8 bits for the extended. We are going to use 8-bit mode. 

-------------------

```
    put32(AUX_MU_MCR_REG,0);                //Set RTS line to be always high
```
The RTS line is used in the flow control and we don't need it. Set it to be high all the time.

-------------------

```
    put32(AUX_MU_BAUD_REG,270);             //Set baud rate to 115200
```
The baud rate is the rate at which information is transferred in a communication channel. “115200 baud” means that the serial port is capable of transferring a maximum of 115200 bits per second. The baud rate of your Raspberry Pi mini UART device should be the same as the baud rate in your terminal emulator. 

The Mini UART calculates baud rate according to the following equation:

```
baudrate = system_clock_freq / (8 * ( baudrate_reg + 1 )) 
```
The `system_clock_freq` is 250 MHz, so we can easily calculate the value of `baudrate_reg` as 270.

``` 
    put32(AUX_MU_CNTL_REG,3);               //Finally, enable transmitter and receiver
```
After this line is executed, the Mini UART is ready for work!

### Sending data over UART

After the Mini UART is ready, we can try to use it to send and receive some data. To do this, we can use the following two functions:

```
void uart_send ( char c )
{
    while(1) {
        if(get32(AUX_MU_LSR_REG)&0x20) 
            break;
    }
    put32(AUX_MU_IO_REG,c);
}

char uart_recv ( void )
{
    while(1) {
        if(get32(AUX_MU_LSR_REG)&0x01) 
            break;
    }
    return(get32(AUX_MU_IO_REG)&0xFF);
}
```

Both of the functions start with an infinite loop, the purpose of which is to verify whether the device is ready to transmit or receive data. We are using  the `AUX_MU_LSR_REG` register to do this. Bit zero, if set to 1, indicates that the data is ready; this means that we can read from the UART. Bit five, if set to 1, tells us that the transmitter is empty, meaning that we can write to the UART.

Next, we use `AUX_MU_IO_REG` to either store the value of the transmitted character or read the value of the received character.

-------------------

We also have a very simple function that is capable of sending strings instead of characters:

```
void uart_send_string(char* str)
{
    for (int i = 0; str[i] != '\0'; i ++) {
        uart_send((char)str[i]);
    }
}
```
This function just iterates over all characters in a string and sends them one by one. 

**Low efficiency?** Apparently Tx/Rx with busy wait burn lots of CPU cycles for no good. It's fine for our baremetal program -- simple & less error-prone. Production software often do interrupt-driven Rx/Tx. 


## Take the kernel for a spin

### QEMU (route 1)

**Setup**

Follow the instructions in [Prerequisites](../exp0/rpi-os.md).

Type `make -f Makefile.qemu` . 

**Run**

```
$ qemu-system-aarch64 -M raspi3 -kernel ./kernel8.img -serial null -serial stdio
VNC server running on 127.0.0.1:5900
Hello, world!
<Ctrl-C>
```


### Rpi3 (route 2)

Run `make -f Makefile.rpi3` to build the kernel. 

The Raspberry Pi startup sequence is the following (simplified):

1. The device is powered on.
1. The GPU starts up and reads the `config.txt` file from the boot partition. This file contains some configuration parameters that the GPU uses to further adjust the startup sequence.
1. `kernel8.img` is loaded into memory and executed.

**Setup**

To be able to run our simple OS, the `config.txt` file should be the following:

```
enable_uart=1
arm_64bit=1
kernel_old=1
disable_commandline_tags=1
```

* `kernel_old=1` specifies that the kernel image should be loaded at address 0.
* `disable_commandline_tags` instructs the GPU to not pass any command line arguments to the booted image.

**Run**

1. Copy the generated `kernel8.img` file to the `boot` partition of your Raspberry Pi flash card and delete `kernel7.img` as well as any other `kernel*.img` files on your SD card. Make sure you left all other files in the boot partition untouched (see [43](https://github.com/fxlin/p1-kernel/issues/43) and [158](https://github.com/fxlin/p1-kernel/issues/158) issues for details). 

   **Update** (2/10/21): students reported that UART1 stops to work with the newest Rpi3 firmware (either extracted from Raspbian OS or from the upstream github repo). The symptom: no "helloworld" is printed, while UART1 seems echoing fine. UART0 seems unaffected. My guess: it has something to do with the firmware's new device tree feature? **Action:** use older firmware provided by us: https://github.com/fxlin/p1-kernel/releases/tag/exp1-rpi3. 

1. Modify the `config.txt` file as described above.

1. Connect the USB-to-TTL serial cable as described in the [Prerequisites](../exp0/rpi-os.md).

1. Power on your Raspberry Pi.

1. Open your terminal emulator. You should be able to see the `Hello, world!` message there.

**Aside (optional): prepare the SD card from scratch (w/o Raspbian)**

The steps above assume that you have Raspbian installed on your SD card. It is also possible to run the RPi OS using an empty SD card.

1. Prepare your SD card:
    * Use an MBR partition table
    * Format the boot partition as FAT32
    > The card should be formatted exactly in the same way as it is required to install Raspbian. Check `HOW TO FORMAT AN SD CARD AS FAT` section in the [official documenation](https://www.raspberrypi.org/documentation/installation/noobs.md) for more information.
    
1. Copy the following files to the card:
   
    * [bootcode.bin](https://github.com/raspberrypi/firmware/blob/master/boot/bootcode.bin) This is the GPU bootloader, it contains the GPU code to start the GPU and load the GPU firmware. 
    
    * [start.elf](https://github.com/raspberrypi/firmware/blob/master/boot/start.elf) This is the GPU firmware. It reads `config.txt` and enables the GPU to load and run ARM specific user code from `kernel8.img`
    
      **Update** (2/10/21): UART1 is broken by these upstream firmware for unknown reason. Use older firmware provided by us: https://github.com/fxlin/p1-kernel/releases/tag/exp1-rpi3. 
    
1. Copy `kernel8.img` and `config.txt` files. 

1. Connect the USB-to-TTL serial cable.

1. Power on your Raspberry Pi.

1. Use your terminal emulator to connect to the RPi OS. 

Unfortunately, all Raspberry Pi firmware files are closed-sourced and undocumented. For more information about the Raspberry Pi startup sequence, you can refer to some unofficial sources, like [this](https://raspberrypi.stackexchange.com/questions/10442/what-is-the-boot-sequence) StackExchange question or [this](https://github.com/DieterReuter/workshop-raspberrypi-64bit-os/blob/master/part1-bootloader.md) Github repository.

