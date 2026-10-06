# Flutter Llama - CMake configuration for Android with llama.cpp
# Based on llama.cpp/examples/llama.android approach

cmake_minimum_required(VERSION 3.10.2)

project(flutter_llama)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)

# Find required packages
find_library(log-lib log)
find_library(android-lib android)

# llama.cpp configuration
set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../llama.cpp")

# Configure llama.cpp build
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)

# Disable features not needed for mobile
set(GGML_USE_LLAMAFILE OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_AMX OFF CACHE BOOL "" FORCE)

# GPU Acceleration for Android devices
# Vulkan for modern devices (Android 7.0+)
# OpenCL as fallback for older devices
# CPU backend with NEON as last resort

# Mobile NDK configuration: disable Vulkan SPIRV build dependency
set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
message(STATUS "⚡ Using optimized CPU backend with ARM NEON / x86 vector extensions")

message(STATUS "   Works on: All ARM64 Android devices")

# Add llama.cpp as subdirectory if source is present
if(EXISTS "${LLAMA_CPP_DIR}/CMakeLists.txt")
    add_subdirectory(${LLAMA_CPP_DIR} build-llama)

    # Create our JNI bridge library
    add_library(flutter_llama_bridge SHARED
        flutter_llama_bridge.cpp
    )

    # Include directories
    target_include_directories(flutter_llama_bridge PRIVATE
        ${LLAMA_CPP_DIR}/include
        ${LLAMA_CPP_DIR}/src
        ${LLAMA_CPP_DIR}/ggml/include
        ${LLAMA_CPP_DIR}/common
    )

    # Link with llama.cpp libraries
    target_link_libraries(flutter_llama_bridge
        llama
        ${log-lib}
        ${android-lib}
    )

    # Link GPU libraries if found
    if(vulkan-lib)
        target_link_libraries(flutter_llama_bridge ${vulkan-lib})
        message(STATUS "  Linked: Vulkan library")
    endif()

    if(opencl-lib)
        target_link_libraries(flutter_llama_bridge ${opencl-lib})
        message(STATUS "  Linked: OpenCL library")
    endif()
else()
    message(STATUS "llama.cpp submodule not present at ${LLAMA_CPP_DIR}; skipping flutter_llama_bridge compilation")
endif()

message(STATUS "Flutter Llama Bridge configuration:")
message(STATUS "  Android ABI: ${ANDROID_ABI}")
message(STATUS "  llama.cpp Dir: ${LLAMA_CPP_DIR}")
message(STATUS "  Build Type: ${CMAKE_BUILD_TYPE}")
