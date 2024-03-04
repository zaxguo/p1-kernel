# cf: https://kubasejdak.com/how-to-cross-compile-for-embedded-with-cmake-like-a-champ
# mar 2024 -- we have too many custom build rules. too many hassles. tried and gave up
#   eg a bug is that linker script uses relative paths to put user objs to certain sections. 
#   however with cmakelist we lost control of where those objs are, and the relative paths silently failed. 


cmake_minimum_required(VERSION 3.16.3)

project(p1)

enable_language(C ASM)

## toggle options...
#option(USE_QEMU ON)
#option(PLAT_VIRT ON)

# -- apply to all configurations --- #
SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Werror -nostdlib -nostartfiles -ffreestanding -Isrc -mgeneral-regs-only -g -O0")
SET(CMAKE_C_COMPILER "aarch64-linux-gnu-gcc")

add_definitions(-DUSE_QEMU)
add_definitions(-DPLAT_VIRT)

# for asm
# SET(ASM_OPTIONS "-x assembler-with-cpp")   # not working?
SET(CMAKE_ASM_FLAGS "-x assembler-with-cpp -Isrc -g -DUSE_QEMU -DPLAT_VIRT")
set(CMAKE_ASM_COMPILER ${CMAKE_C_COMPILER}) # otherwise fallback to native gcc

# for linker. cmake is said to use gcc for linking
set(LINKER_SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/src/linker-qemu-cmake.ld)
SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -T${LINKER_SCRIPT}")

include_directories(./src)

file(GLOB HEADERS
"src/*.h"
)

file(GLOB COMMON_SOURCES
  ${HEADERS}
  "src/*.c"
  "src/*.S")

list(REMOVE_ITEM COMMON_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/lfb.c)

# ------------------------------------- #
# all executables  
# ------------------------------------- #
add_executable(kernel8.elf
    ${COMMON_SOURCES}
)
# https://cmake.org/cmake/help/latest/command/add_custom_command.html
add_custom_command(
    TARGET kernel8.elf POST_BUILD
    COMMAND aarch64-linux-gnu-objcopy $<TARGET_FILE:kernel8.elf> -O binary kernel8.img    
    COMMAND aarch64-linux-gnu-objdump -dS $<TARGET_FILE:kernel8.elf> > kernel8.asm
    BYPRODUCTS kernel8.img kernel8.asm
VERBATIM)

#target_link_options(kernel8.elf PRIVATE "-T ${CMAKE_SOURCE_DIR}/src/${LINKER_SCRIPT}")