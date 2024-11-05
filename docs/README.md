# A tiny, modern kernel for Raspberry Pi 3 

Experiment descriptions are for you to read & reproduce. The assignments will be on LMS (e.g. Canvas). 

**Get the code**: 

```
git clone https://github.com/zaxguo/p1-kernel
# load build commands
cd p1-kernel && source env-qemu.sh
```

A tiny kernel *incrementally built* for OS education. 

Start with minimal, baremetal code. Then each assignment adds new features. Each experiment is a self-contained and can run on both Rpi3 hardware and QEMU. 

**On the website, there is a top-right search box -- use it!**

## Learning objectives

**Knowledge:** 

* protection modes
* interrupt handling
* preemptive scheduling
* virtual memory 

**Skills:** 

* Learning by doing: the core concepts of a modern OS kernel
* Experiencing OS engineering: hands-on programming & debugging at the hardware/software boundary
* Daring to plumb: working with baremetal hardware: CPU protection modes, registers, IO, MMU, etc.

**Secondary:**
* Armv8 programming. Arm is everywhere, including future Mac. 
* Working with C and assembly 
* Cross-platform development 

**Non-goals:**

* Non-core or advanced functions of OS kernel, e.g. filesystem or power management, which can be learnt via experimenting with commodity OS. 
* Rpi3-specific hardware details. The SoC of Rpi3 is notoriously unfriendly to kernel hackers. 
* Implementation details of commodity kernels, e.g. Linux or Windows.  

<!---- to complete --->

## Experiments
0. **[Sharpen your tools!](exp0/rpi-os.md)** (p1 exp0) 
1. **Helloworld from baremetal** (p1 exp1) 
      * [Power on + UART bring up](exp1/rpi-os.md)
      * [Simplifying dev workflow (rpi3 hardware only)](exp1/workflow.md)
2. **Exception elevated** (p1 exp2) 
      * [CPU initialization, exception levels](exp2/rpi-os.md)
3. **Heartbeats on** (p1 exp3) 
      * [Interrupt handling](exp3/rpi-os.md)
      * [Interrupt-driven animation](exp3/fb.md)
4. **Process scheduler** (p1 exp4) 
      * [A. Cooperative](exp4a/rpi-os.md) 
      * [B. Preemptive](exp4b/rpi-os.md) 
5. **A world of two lands** (p1 exp5) 
      * [User processes and system calls](exp5/rpi-os.md) 
6. **Into virtual** (p1 exp6) 
      * [Virtual memory management](exp6/rpi-os.md) 

## Acknowledgement
- Derived from the RPi OS project and its tutorials, which is modeled after the [Linux kernel](https://github.com/torvalds/linux). 
- Further derived from grad level OS course developed by Prof. Felix Lin at UVA CS(fxlin.github.io), which I TA'd.
