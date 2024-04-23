ARMGNU ?= aarch64-linux-gnu
VOS_HOME ?= /home/xzl/workspace-p1-kernel

VOS_REPO_PATH ?= $(VOS_HOME)/p1-kernel-next/
KERNEL_PATH ?= $(VOS_HOME)/p1-kernel-next/kernel
USR_PATH ?= $(VOS_HOME)/p1-kernel-next/usr

NEWLIB_HOME ?= $(VOS_HOME)/newlib
NEWLIB_INC_PATH ?= $(NEWLIB_HOME)/newlib/libc/include 
NEWLIB_BUILD_PATH ?= $(NEWLIB_HOME)/build