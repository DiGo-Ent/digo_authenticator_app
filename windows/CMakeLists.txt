# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(digo_authenticator_app LANGUAGES CXX)

# Fix MSVC C++ deprecation compile blocks in plugins like local_auth_windows
add_compile_definitions(_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "digo_authenticator_app")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Enable source control versioning if requested.
if(DEFINED FLUTTER_BUILD_NUMBER)
  add_definitions(-DFLUTTER_BUILD_NUMBER=${FLUTTER_BUILD_NUMBER})
endif()
if(DEFINED FLUTTER_BUILD_NAME)
  add_definitions(-DFLUTTER_BUILD_NAME="${FLUTTER_BUILD_NAME}")
endif()

# Setup project.
include(flutter/generated_plugins.cmake)

# Apply standard flags.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Configure the executable.
add_executable(${BINARY_NAME}
  "runner/main.cpp"
  "runner/utils.cpp"
  "runner/win32_window.cpp"
  "runner/flutter_window.cpp"
  "runner/Runner.rc"
)
apply_standard_settings(${BINARY_NAME})
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")
if(FLUTTER_TARGET_PLATFORM_VERSION)
  target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_TARGET_PLATFORM_VERSION=${FLUTTER_TARGET_PLATFORM_VERSION}")
endif()

# Link libraries.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE ${flutter_generated_plugins_libraries})

# Add the dlls to the build directory.
add_custom_command(
  TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "$<TARGET_FILE:flutter>"
  "$<TARGET_FILE_DIR:${BINARY_NAME}>"
)

# Copy the generated plugins to the build directory.
foreach(plugin ${flutter_generated_plugins_libraries})
  add_custom_command(
    TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "$<TARGET_FILE:${plugin}>"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>"
  )
endforeach()
