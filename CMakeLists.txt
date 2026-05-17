cmake_minimum_required (VERSION 3.13.0)
project (ffmpeg)

include(FindPkgConfig)

# Threads are required
find_package(Threads REQUIRED)

set(SRC_DIR ../ffmpeg)
set(LIBAVCODEC_SRC_DIR ${SRC_DIR}/libavcodec)
set(LIBAVFORMAT_SRC_DIR ${SRC_DIR}/libavformat)
set(LIBAVUTIL_SRC_DIR ${SRC_DIR}/libavutil)
set(LIBSWRESAMPLE_SRC_DIR ${SRC_DIR}/libswresample)
set(LIBSWSCALE_SRC_DIR ${SRC_DIR}/libswscale)

# Set some flags needed to for ffmpeg internal checks
if (IOS)
	set(ADDL_INCLUDES -I${CMAKE_OSX_SYSROOT}/usr/include)
	set(ADDL_LIBS -L${CMAKE_OSX_SYSROOT}/usr/lib)
elseif (CMAKE_CROSSCOMPILING)
	set(ADDL_INCLUDES -I${CMAKE_SYSROOT}/usr/include)
	set(ADDL_LIBS -L${CMAKE_SYSROOT}/usr/lib)
else()
	set(ADDL_INCLUDES -I/usr/local/include)
	set(ADDL_LIBS -L/usr/local/lib)
endif()

# To Do - conditionally apply COMPILER_Flags based on the build target

include(generated_headers.cmake)

# Create a separate directory of headers to expose to PPSSPP, mimicking the current setup of ppsspp-ffmpeg
set(HEADER_INSTALL_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include)
#set(HEADER_INSTALL_DIRECTORY ${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}/../include)
file(MAKE_DIRECTORY ${HEADER_INSTALL_DIRECTORY})

# libavcodec
include(libs/libavcodec.cmake)
add_library(avcodec STATIC ${LIBAVCODEC_SOURCE_FILES})
set_target_properties(avcodec PROPERTIES POSITION_INDEPENDENT_CODE TRUE) # Enable PIC
target_precompile_headers(avcodec PRIVATE ${LIBAVUTIL_SRC_DIR}/internal.h ${LIBAVUTIL_SRC_DIR}/intmath.h)
target_link_libraries(avcodec)
target_include_directories(avcodec PRIVATE ${SRC_DIR} ${CMAKE_CURRENT_BINARY_DIR})
target_include_directories(avcodec INTERFACE ${LIBAVCODEC_HEADERS})	# expose libavcodec headers to PPSSPP build
file(COPY ${LIBAVCODEC_HEADERS} DESTINATION ${HEADER_INSTALL_DIRECTORY}/libavcodec) # same, albeit the "old" way
set(LIBAVCODEC_LIBRARY avcodec)

# libavformat
include(libs/libavformat.cmake)
add_library(avformat STATIC ${LIBAVFORMAT_SOURCE_FILES})
set_target_properties(avformat PROPERTIES POSITION_INDEPENDENT_CODE TRUE) # Enable PIC
target_precompile_headers(avformat PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/config.h ${LIBAVUTIL_SRC_DIR}/internal.h)
target_link_libraries(avformat)
target_include_directories(avformat PRIVATE ${SRC_DIR} ${CMAKE_CURRENT_BINARY_DIR})
target_include_directories(avformat INTERFACE ${LIBAVFORMAT_HEADERS})
file(COPY ${LIBAVFORMAT_HEADERS} DESTINATION ${HEADER_INSTALL_DIRECTORY}/libavformat)
set(LIBAVFORMAT_LIBRARY avformat)

# libavutil
include(libs/libavutil.cmake)
add_library(avutil STATIC ${LIBAVUTIL_SOURCE_FILES})
target_precompile_headers(avutil PRIVATE 
	${CMAKE_CURRENT_BINARY_DIR}/libavutil/ffversion.h 
	${CMAKE_CURRENT_BINARY_DIR}/libavutil/avconfig.h 
	${LIBAVUTIL_SRC_DIR}/internal.h
)
set_target_properties(avutil PROPERTIES POSITION_INDEPENDENT_CODE TRUE) # Enable PIC
target_link_libraries(avutil)
target_include_directories(avutil PRIVATE ${SRC_DIR} ${CMAKE_CURRENT_BINARY_DIR})
target_include_directories(avutil INTERFACE ${LIBAVUTIL_HEADERS})
file(COPY ${LIBAVUTIL_HEADERS} DESTINATION ${HEADER_INSTALL_DIRECTORY}/libavutil)
set(LIBAVUTIL_LIBRARY avutil)

# libswresample
include(libs/libswresample.cmake)
add_library(swresample STATIC ${LIBSWRESAMPLE_SOURCE_FILES})
set_target_properties(swresample PROPERTIES POSITION_INDEPENDENT_CODE TRUE) # Enable PIC
target_precompile_headers(swresample PRIVATE ${LIBAVUTIL_SRC_DIR}/cpu.h ${LIBAVUTIL_SRC_DIR}/internal.h)
target_link_libraries(swresample)
target_include_directories(swresample PUBLIC ${SRC_DIR} ${CMAKE_CURRENT_BINARY_DIR})
target_include_directories(swresample INTERFACE ${LIBSWRESAMPLE_HEADERS})
file(COPY ${LIBSWRESAMPLE_HEADERS} DESTINATION ${HEADER_INSTALL_DIRECTORY}/libswresample)
set(LIBSWRESAMPLE_LIBRARY swresample)

# libswscale
include(libs/libswscale.cmake)
add_library(swscale STATIC ${LIBSWSCALE_SOURCE_FILES})
set_target_properties(swscale PROPERTIES POSITION_INDEPENDENT_CODE TRUE) # Enable PIC
target_precompile_headers(swscale PRIVATE ${LIBAVUTIL_SRC_DIR}/internal.h)
target_link_libraries(swscale)
target_include_directories(swscale PRIVATE ${SRC_DIR} ${CMAKE_CURRENT_BINARY_DIR})
target_include_directories(swscale INTERFACE ${LIBSWSCALE_HEADERS})
file(COPY ${LIBSWSCALE_HEADERS} DESTINATION ${HEADER_INSTALL_DIRECTORY}/libswscale)
set(LIBSWSCALE_LIBRARY swscale)

