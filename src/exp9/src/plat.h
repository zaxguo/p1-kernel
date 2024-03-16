#ifdef PLAT_VIRT
#include "plat-virt.h"
#elif defined PLAT_RPI3QEMU
#include "plat-rpi3qemu.h"
#elif defined PLAT_RPI3
#include "plat_rpi3.h"
#else
#error "unimpl"
#endif
