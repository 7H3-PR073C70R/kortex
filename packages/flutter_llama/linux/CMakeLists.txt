cmake_minimum_required(VERSION 3.10)
project(flutter_llama_plugin LANGUAGES CXX C)

set(PLUGIN_NAME "flutter_llama_plugin")

set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../llama.cpp")

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(EXISTS "${LLAMA_CPP_DIR}/CMakeLists.txt")
  set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
  set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
  set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
  set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
  set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
  add_subdirectory("${LLAMA_CPP_DIR}" build-llama EXCLUDE_FROM_ALL)
endif()

add_library(${PLUGIN_NAME} SHARED
  "flutter_llama_plugin.cc"
  "../src/llama_cpp_bridge.cpp"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET "default"
  VISIBILITY_INLINES_HIDDEN 0
)

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

target_include_directories(${PLUGIN_NAME} PRIVATE
  "${LLAMA_CPP_DIR}/include"
  "${LLAMA_CPP_DIR}/ggml/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../include"
)

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

if(TARGET llama)
  target_link_libraries(${PLUGIN_NAME} PRIVATE llama)
endif()

set(flutter_llama_bundled_libraries
  ""
  PARENT_SCOPE
)
