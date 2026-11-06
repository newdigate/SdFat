cmake_minimum_required(VERSION 3.24)

# --- Toolchain bootstrap (must run before project()) -------------------------
# This gate lives OUTSIDE the evkb tree, so it cannot use evkb's per-gate
# toolchain/ file (that file resolves the core path relative to its own location
# inside evkb).  Inline the same, tested settings here with an absolute COREPATH
# so a plain `cmake -B build -S .` cross-compiles for the RT1176 M7 with no extra
# flags.  Mirrors evkb/toolchain/rt1170-evkb.toolchain.cmake.
set(TEENSY_VERSION 117 CACHE STRING "RT1176 / MIMXRT1170-EVKB" FORCE)
set(CPU_CORE_SPEED 996000000 CACHE STRING "RT1176 M7 core clock" FORCE)
# Sibling library checkouts.  The imxrt1176 core lives in the teensy-cores repo
# and the build macros in teensy-cmake-macros -- neither sits inside evkb any
# more.  TEENSY_LIB_ROOT mirrors evkb.cmake: -D wins, then the environment,
# else $HOME/Development.
if(NOT DEFINED TEENSY_LIB_ROOT)
    if(DEFINED ENV{TEENSY_LIB_ROOT})
        set(TEENSY_LIB_ROOT "$ENV{TEENSY_LIB_ROOT}")
    else()
        set(TEENSY_LIB_ROOT "$ENV{HOME}/Development")
    endif()
endif()
# COREPATH must end with a trailing slash and be cache type STRING (not PATH,
# which CMake would normalise and strip the slash): the macros build LINKER_FILE
# by raw concat "${COREPATH}imxrt1176.ld".
set(COREPATH "${TEENSY_LIB_ROOT}/teensy-cores/imxrt1176/" CACHE STRING "imxrt1176 core path" FORCE)
set(CMAKE_EXE_LINKER_FLAGS "--specs=nano.specs" CACHE INTERNAL "")
set(COMPILERPATH "/Applications/ARM_10/bin/")
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_TRY_COMPILE_TARGET_TYPE "STATIC_LIBRARY")
set(CMAKE_C_COMPILER ${COMPILERPATH}arm-none-eabi-gcc)
set(CMAKE_CXX_COMPILER ${COMPILERPATH}arm-none-eabi-g++)
set(CMAKE_CXX_LINK_EXECUTABLE "${CMAKE_C_COMPILER} <FLAGS> <CMAKE_CXX_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")
# -----------------------------------------------------------------------------

project(sd_block_test)

include(FetchContent)
FetchContent_Declare(teensy_cmake_macros SOURCE_DIR ${TEENSY_LIB_ROOT}/teensy-cmake-macros)
FetchContent_MakeAvailable(teensy_cmake_macros)
include(${teensy_cmake_macros_SOURCE_DIR}/CMakeLists.include.txt)

import_arduino_library(cores ${TEENSY_LIB_ROOT}/teensy-cores/imxrt1176)
# SdFat is a 1.5-format Arduino library: all sources live under src/ (with
# per-feature subdirs) and SdFat.h uses includes relative to src/.  The teensy
# macro globs each listed dir non-recursively and adds it to the include path,
# so enumerate every src subdir that carries sources.  `src` first supplies the
# include root that resolves <SdFat.h> and its relative include chain.
#
# src/SpiDriver is deliberately NOT compiled.  This is a raw-SDIO gate, so the
# SPI-over-SD backend is unused; and because the core defines CORE_TEENSY, SdFat
# selects its native Teensy SPI driver (SdSpiTeensy3.cpp), which uses Teensy SPI
# extensions (setTransferWriteFill / transfer(tx,rx,count)) that the RT1176 SPI
# port does not implement.  The driver's headers still resolve via the src/
# include root, SdSpiCard.cpp still compiles, and nothing references those
# symbols at link (the test uses SdioCard only), so omitting the .cpp is safe.
import_arduino_library(SdFat ${CMAKE_CURRENT_LIST_DIR}/../..
    src src/common src/SdCard src/FatLib src/ExFatLib src/FsLib
    src/iostream)
import_arduino_library(SPI   ${TEENSY_LIB_ROOT}/SPI)

teensy_add_executable(sd_block_test sd_block_test.cpp)
teensy_target_link_libraries(sd_block_test cores SdFat SPI)

target_link_libraries(sd_block_test.elf stdc++)
