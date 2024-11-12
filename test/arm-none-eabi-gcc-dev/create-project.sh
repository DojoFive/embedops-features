#!/usr/bin/env bash

# Create project structure
mkdir -p arm_project/src && cd arm_project

# Create minimal main.c
cat > src/main.c << 'EOF'
void main(void) {
    while(1);
}
EOF

# Create minimal CMakeLists.txt
cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.12)
project(arm_project C)

add_executable(${PROJECT_NAME} src/main.c)

target_compile_options(${PROJECT_NAME} PRIVATE
    -mcpu=cortex-m4
    -mthumb
    -nostartfiles
)

target_link_options(${PROJECT_NAME} PRIVATE
    -nostartfiles
    -nodefaultlibs
    -nostdlib
)
EOF

# Create toolchain file
cat > toolchain.cmake << 'EOF'
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR ARM)
set(CMAKE_C_COMPILER arm-none-eabi-gcc)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
EOF

# Build
mkdir build && cd build