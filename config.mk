ARMGNU ?= aarch64-linux-gnu
CC = $(ARMGNU)-gcc-9

VOS_HOME ?= /home/xzl/workspace-p1-kernel

VOS_REPO_PATH ?= $(VOS_HOME)/p1-kernel-next/
KERNEL_PATH ?= $(VOS_HOME)/p1-kernel-next/kernel
USR_PATH ?= $(VOS_HOME)/p1-kernel-next/usr

NEWLIB_HOME ?= $(VOS_HOME)/newlib
NEWLIB_INC_PATH ?= $(NEWLIB_HOME)/newlib/libc/include 
NEWLIB_BUILD_PATH ?= $(NEWLIB_HOME)/build

# newlib glue
LIBNEW_PATH=${USR_PATH}/libnew

LIBVORBIS_PATH=${USR_PATH}/libvorbis

LIBMINISDL_PATH=${USR_PATH}/libminisdl