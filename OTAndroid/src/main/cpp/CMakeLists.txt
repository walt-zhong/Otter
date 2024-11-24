cmake_minimum_required(VERSION 3.4.1)
project(OTAnalyze)

if (${CMAKE_BUILD_TYPE} EQUAL "Release")
    #编译包大小优化选项 如表达式需要debug，请把以下三个编译选项注释掉
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Oz -flto -fdata-sections -ffunction-sections")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Oz -flto -fdata-sections -ffunction-sections")
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -O3 -flto  -Wl,--gc-sections -Wl")
else ()
    # nothing
endif ()

add_library(
        ${PROJECT_NAME}
        SHARED
        OTJniAnalyze.cpp
        OTAnalyze.cpp
        OTATSNode.cpp
        OTWordAnalyze.cpp
)

target_include_directories(
        ${PROJECT_NAME} PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(
        ${PROJECT_NAME}
        -landroid
        -llog
)
