cmake_minimum_required(VERSION 3.24)

# --- Toolchain bootstrap (must run before project()) -------------------------
# This gate lives OUTSIDE the evkb tree, so it cannot use evkb's per-gate
# toolchain/ file (that file resolves the core path relative to its own location
# inside evkb).  Inline the same, tested settings here with an absolute COREPATH
# so a plain `cmake -B build -S .` cross-compiles for the RT1176 M7 with no extra
# flags.  Mirrors evkb/*/toolchain/rt1170-evkb.toolchain.cmake.
set(TEENSY_VERSION 117 CACHE STRING "RT1176 / MIMXRT1170-EVKB" FORCE)
set(CPU_CORE_SPEED 996000000 CACHE STRING "RT1176 M7 core clock" FORCE)
set(EVKB $ENV{HOME}/Development/rt1170/evkb)
# COREPATH must end with a trailing slash and be cache type STRING (not PATH,
# which CMake would normalise and strip the slash): the macros build LINKER_FILE
# by raw concat "${COREPATH}imxrt1176.ld".
set(COREPATH "${EVKB}/cores/imxrt1176/" CACHE STRING "imxrt1176 core path" FORCE)
set(CMAKE_EXE_LINKER_FLAGS "--specs=nano.specs" CACHE INTERNAL "")
set(COMPILERPATH "/Applications/ARM_10/bin/")
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_TRY_COMPILE_TARGET_TYPE "STATIC_LIBRARY")
set(CMAKE_C_COMPILER ${COMPILERPATH}arm-none-eabi-gcc)
set(CMAKE_CXX_COMPILER ${COMPILERPATH}arm-none-eabi-g++)
set(CMAKE_CXX_LINK_EXECUTABLE "${CMAKE_C_COMPILER} <FLAGS> <CMAKE_CXX_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")
# -----------------------------------------------------------------------------

project(sd_fs_test)

include(FetchContent)
FetchContent_Declare(teensy_cmake_macros SOURCE_DIR ${EVKB}/teensy-cmake-macros)
FetchContent_MakeAvailable(teensy_cmake_macros)
include(${teensy_cmake_macros_SOURCE_DIR}/CMakeLists.include.txt)

import_arduino_library(cores ${EVKB}/cores/imxrt1176)
# SdFat is a 1.5-format Arduino library: all sources live under src/ (with
# per-feature subdirs) and SdFat.h uses includes relative to src/.  The teensy
# macro globs each listed dir non-recursively and adds it to the include path,
# so enumerate every src subdir that carries sources.  `src` first supplies the
# include root that resolves <SdFat.h> and its relative include chain.
#
# Unlike the raw-block gate (sd_block_test), this gate links the SD wrapper,
# whose SDClass::begin() references sdfs.begin(SdSpiConfig(...)) -- the SPI-over-
# SD backend.  That reference is reachable in the call graph (a runtime `if`, not
# a compile-time exclusion), so --gc-sections cannot strip it and SdSpiCard.cpp's
# sdCsWrite()/sdCsInit() and the SdSpiArduinoDriver methods must resolve at link.
# src/SpiDriver is therefore compiled: SdSpiChipSelect.cpp supplies sdCsWrite/
# sdCsInit, and SdSpiLibDriver.h (SdFat's generic Arduino SPI driver, selected
# because SdFatConfig.h now excludes __IMXRT1176__ from SD_HAS_CUSTOM_SPI)
# supplies the driver methods inline -- using only the per-byte SPI transfer the
# RT1176 port implements.  All other SpiDriver .cpp (Teensy3/Due/ESP/STM32/...)
# are platform-guarded to empty on this target.  The gate itself still uses only
# SDIO (BUILTIN_SDCARD); the SPI-SD path is linked but never executed.
import_arduino_library(SdFat ${CMAKE_CURRENT_LIST_DIR}/../..
    src src/common src/SdCard src/FatLib src/ExFatLib src/FsLib
    src/iostream src/SpiDriver)
import_arduino_library(SPI   $ENV{HOME}/Development/SPI)
# SD wrapper (newdigate/SD, aka PaulS_SD): SDClass:public FS over SdFat.  It is a
# 1.5-format library too (SD.cpp / SD.h under src/), so pass the `src` subdir so
# the macro both compiles src/SD.cpp and puts src/ on the include path to resolve
# <SD.h>.  Passing only the repo root would glob nothing and never add src/.
import_arduino_library(SD    $ENV{HOME}/Development/PaulS_SD src)

teensy_add_executable(sd_fs_test sd_fs_test.cpp)
teensy_target_link_libraries(sd_fs_test cores SdFat SD SPI)

target_link_libraries(sd_fs_test.elf stdc++)
