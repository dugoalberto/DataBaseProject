cmake_minimum_required(VERSION 3.21)
project(provaLab5_1)

set(CMAKE_CXX_STANDARD 14)

add_executable(provaLab5_1 main.cpp main.cpp)
include_directories(dependencies/lib)
include_directories(dependencies/include)
target_link_libraries(provaLab5_1 pq)


