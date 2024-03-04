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
SET(ASM_OPTIONS "-x assembler-with-cpp")
SET(CMAKE_ASM_FLAGS "-Isrc  -g -DUSE_QEMU -DPLAT_VIRT")

# for linker
set(LINKER_SCRIPT "/tmp/linker-qemu.ld")
SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -T ${LINKER_SCRIPT}")

include_directories(./src)

file(GLOB HEADERS
"src/*.h"
)

file(GLOB COMMON_SOURCES
  ${HEADERS}
  "src/*.c")


# ------------------------------------- #
# all executables  
# ------------------------------------- #
add_executable(kernel8.elf
    ${COMMON_SOURCES}
)
#target_link_options(kernel8.elf PRIVATE "-T ${CMAKE_SOURCE_DIR}/src/${LINKER_SCRIPT}")