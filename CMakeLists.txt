cmake_minimum_required (VERSION 3.10.0)
project (ffmpeg)

include(FindPkgConfig)

# Threads are required
find_package(Threads REQUIRED)

# GNU windres isn't required, but used to compile Windows .rc files with MinGW. MSVC can also compile them
find_package(GNU_WINDRES QUIET)
find_package(ZLIB)

set(SRC_DIR ../ffmpeg)
set(LIBAVCODEC_SRC_DIR ${SRC_DIR}/libavcodec)
set(LIBAVFORMAT_SRC_DIR ${SRC_DIR}/libavformat)
set(LIBAVUTIL_SRC_DIR ${SRC_DIR}/libavutil)
set(LIBSWRESAMPLE_SRC_DIR ${SRC_DIR}/libswresample)
set(LIBSWSCALE_SRC_DIR ${SRC_DIR}/libswscale)

include(generated_headers.cmake)

#set(CMAKE_C_FLAGS "-fPIC")
#string(APPEND CMAKE_C_FLAGS "-fPIC")
# Temporary debugging statements to figure out what compile options might be causing broken ffmpeg when built as a module instead of standalone
get_directory_property(opts COMPILE_OPTIONS)
message("Directory-wide inherited COMPILE_OPTIONS: ${opts}")
message(STATUS "current inherited C Flags from PPSSPP: ${CMAKE_C_FLAGS}")
message(STATUS "current inherited CXX Flags from PPSSPP: ${CMAKE_CXX_FLAGS}")
message(STATUS "current inherited LD Flags from PPSSPP: ${CMAKE_SHARED_LINKER_FLAGS}")

# Backup and remove PPSSPP's compiler flags to enable some of these checks to complete
set(OLD_CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")
set(CMAKE_C_FLAGS "" CACHE STRING "C compiler flags" FORCE)
set(OLD_CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
set(CMAKE_CXX_FLAGS "" CACHE STRING "CXX compiler flags" FORCE)
set(OLD_CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS}")
set(CMAKE_SHARED_LINKER_FLAGS "")
set_directory_properties(PROPERTIES COMPILE_OPTIONS "")
# To Do - conditionally apply COMPILER_Flags based on the build target

# Mimic the naming convention of current ppsspp-ffmpeg precompiled libraries and distributed headers
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

# Run strip on the libraries to remove unneeded symbols
find_program(STRIP_TOOL strip)
if(STRIP_TOOL)
	add_custom_command(
		TARGET avcodec
		POST_BUILD
		COMMAND ${STRIP_TOOL} --strip-unneeded $<TARGET_FILE:avcodec>
		COMMENT "Stripping symbols from avcodec"
	)
		add_custom_command(
		TARGET avformat
		POST_BUILD
		COMMAND ${STRIP_TOOL} --strip-unneeded $<TARGET_FILE:avformat>
		COMMENT "Stripping symbols from avformat"
	)
		add_custom_command(
		TARGET avutil
		POST_BUILD
		COMMAND ${STRIP_TOOL} --strip-unneeded $<TARGET_FILE:avutil>
		COMMENT "Stripping symbols from avutil"
	)
		add_custom_command(
		TARGET swresample
		POST_BUILD
		COMMAND ${STRIP_TOOL} --strip-unneeded $<TARGET_FILE:swresample>
		COMMENT "Stripping symbols from swresample"
	)
		add_custom_command(
		TARGET swscale
		POST_BUILD
		COMMAND ${STRIP_TOOL} --strip-unneeded $<TARGET_FILE:swscale>
		COMMENT "Stripping symbols from swscale"
	)
endif()

# Restore PPSSPP's original compiler flags
set(CMAKE_C_FLAGS "${OLD_CMAKE_C_FLAGS}")
set(CMAKE_CXX_FLAGS "${OLD_CMAKE_CXX_FLAGS}")
set(CMAKE_SHARED_LINKER_FLAGS "${OLD_CMAKE_SHARED_LINKER_FLAGS}")
set_directory_properties(PROPERTIES COMPILE_OPTIONS "${opts}")

# Make sure to set appropriate options found in PPSSPP's root CMakeLists.txt file at lines 1055-1067
set(CMAKE_REQUIRED_FLAGS "-pedantic -Wall -Werror -Wno-unused-variable")
check_cxx_source_compiles("extern \"C\" {
	#include <libavcodec/avcodec.h>
	#include <libavformat/avformat.h>
	}
	static AVCodecContext *s_codec_context = NULL;
	int main() {
		const AVCodec *codec = avcodec_find_encoder(s_codec_context->codec_id);
		return 0;
	}
	" HAVE_LIBAVCODEC_CONST_AVCODEC FAIL_REGEX "invalid conversion")
