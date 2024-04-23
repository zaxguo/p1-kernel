#ifdef PLAT_VIRT
#include "plat-virt.h"
#elif defined PLAT_RPI3QEMU || defined PLAT_RPI3
#include "plat-rpi3qemu.h"
#else
#error "unimpl"
#endif



