cmake_minimum_required(VERSION 3.18.1)

project(vanta_audio_engine LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(
    vanta_audio_engine
    SHARED
    native/vanta_engine.cpp
    native/vanta_decoder.cpp
    native/vanta_output.cpp
)

find_library(log-lib log)
find_library(android-lib android)
find_library(opensles-lib OpenSLES)

target_include_directories(vanta_audio_engine PRIVATE native)
target_link_libraries(vanta_audio_engine ${log-lib} ${android-lib} ${opensles-lib})
