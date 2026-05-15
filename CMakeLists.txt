cmake_minimum_required (VERSION 3.13.0)
project (ffmpeg)

include(FindPkgConfig)

# Threads are required
find_package(Threads REQUIRED)

# GNU windres isn't required, but used to compile Windows .rc files with MinGW. MSVC can also compile them
find_package(GNU_WINDRES QUIET)

set(SRC_DIR ../ffmpeg)
set(LIBAVCODEC_SRC_DIR ${SRC_DIR}/libavcodec)
set(LIBAVFORMAT_SRC_DIR ${SRC_DIR}/libavformat)
set(LIBAVUTIL_SRC_DIR ${SRC_DIR}/libavutil)
set(LIBSWRESAMPLE_SRC_DIR ${SRC_DIR}/libswresample)
set(LIBSWSCALE_SRC_DIR ${SRC_DIR}/libswscale)

# Clear any inherited COMPILE_OPTIONS from PPSSPP project root--some of them break ffmpeg
get_directory_property(opts COMPILE_OPTIONS)
set_directory_properties(PROPERTIES COMPILE_OPTIONS "")

# Restore some flags needed to build ffmpeg
add_compile_options(-I/usr/local/include)
set(ADDL_INCLUDES -I/usr/local/include)
add_compile_options(-L/usr/local/lib)
set(ADDL_LIBS -L/usr/local/lib)
# Add PIC - note: CMAKE_POSITION_INDEPENDENT_CODE is supposed to be more portable than adding an -fPIC compiler flag
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if (NOT "${X11_Xlib_INCLUDE_PATH}" MATCHES "/usr/local/include")
	add_compile_options(-I${X11_Xlib_INCLUDE_PATH})
endif()
if (NOT "${ZLIB_INCLUDE_DIR}" MATCHES "/usr/local/include")
	add_compile_options(-I${ZLIB_INCLUDE_DIR})
endif()

# To Do - conditionally apply COMPILER_Flags based on the build target

include(generated_headers.cmake)

# Create a separate directory of headers to expose to PPSSPP, mimicking the current setup of ppsspp-ffmpeg
set(HEADER_INSTALL_DIRECTORY ${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}/../include)
file(MAKE_DIRECTORY ${HEADER_INSTALL_DIRECTORY})

# libavcodec
include(libs/libavcodec.cmake)
add_library(avcodec STATIC ${LIBAVCODEC_SOURCE_FILES})
target_precompile_headers(avcodec PRIVATE ${LIBAVUTIL_SRC_DIR}/internal.h ${LIBAVUTIL_SRC_DIR}/intmath.h)
target_link_libraries(avcodec)
target_include_directories(avcodec PRIVATE ${SRC_DIR} ${CMAKE_CURRENT_BINARY_DIR})
target_include_directories(avcodec INTERFACE ${LIBAVCODEC_HEADERS})	# expose libavcodec headers to PPSSPP build
file(COPY ${LIBAVCODEC_HEADERS} DESTINATION ${HEADER_INSTALL_DIRECTORY}/libavcodec) # same, albeit the "old" way
set(LIBAVCODEC_LIBRARY avcodec)

# libavformat
include(libs/libavformat.cmake)
add_library(avformat STATIC ${LIBAVFORMAT_SOURCE_FILES})
target_precompile_headers(avformat PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/config.h ${LIBAVUTIL_SRC_DIR}/internal.h)
target_link_libraries(avformat)
target_include_directories(avformat PRIVATE ${SRC_DIR} ${CMAKE_CURRENT_BINARY_DIR})
target_include_directories(avformat INTERFACE ${LIBAVFORMAT_HEADERS})
file(COPY ${LIBAVFORMAT_HEADERS} DESTINATION ${HEADER_INSTALL_DIRECTORY}/libavformat)
set(LIBAVFORMAT_LIBRARY avformat)

# libavutil
include(libs/libavutil.cmake)
target_link_libraries(avutil)
target_include_directories(avutil PRIVATE ${SRC_DIR} ${CMAKE_CURRENT_BINARY_DIR})
target_include_directories(avutil INTERFACE ${LIBAVUTIL_HEADERS})
file(COPY ${LIBAVUTIL_HEADERS} DESTINATION ${HEADER_INSTALL_DIRECTORY}/libavutil)
set(LIBAVUTIL_LIBRARY avutil)

# libswresample
include(libs/libswresample.cmake)
add_library(swresample STATIC ${LIBSWRESAMPLE_SOURCE_FILES})
target_precompile_headers(swresample PRIVATE ${LIBAVUTIL_SRC_DIR}/cpu.h ${LIBAVUTIL_SRC_DIR}/internal.h)
target_link_libraries(swresample)
target_include_directories(swresample PUBLIC ${SRC_DIR} ${CMAKE_CURRENT_BINARY_DIR})
target_include_directories(swresample INTERFACE ${LIBSWRESAMPLE_HEADERS})
file(COPY ${LIBSWRESAMPLE_HEADERS} DESTINATION ${HEADER_INSTALL_DIRECTORY}/libswresample)
set(LIBSWRESAMPLE_LIBRARY swresample)

# libswscale
include(libs/libswscale.cmake)
add_library(swscale STATIC ${LIBSWSCALE_SOURCE_FILES})
target_precompile_headers(swscale PRIVATE ${LIBAVUTIL_SRC_DIR}/internal.h)
target_link_libraries(swscale)
target_include_directories(swscale PRIVATE ${SRC_DIR} ${CMAKE_CURRENT_BINARY_DIR})
target_include_directories(swscale INTERFACE ${LIBSWSCALE_HEADERS})
file(COPY ${LIBSWSCALE_HEADERS} DESTINATION ${HEADER_INSTALL_DIRECTORY}/libswscale)
set(LIBSWSCALE_LIBRARY swscale)
