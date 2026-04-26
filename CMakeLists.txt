cmake_minimum_required (VERSION 3.10.0)
project (ffmpeg)

include(FindPkgConfig)

# Threads are required
find_package(Threads REQUIRED)

# GNU windres isn't required, but used to compile Windows .rc files with MinGW. MSVC can also compile them
find_package(GNU_WINDRES QUIET)
find_package(ZLIB)
find_package(X11 QUIET)
find_package(PkgConfig)
if(PkgConfig_FOUND)
	pkg_check_modules(VAAPI_X11 IMPORTED_TARGET libva-x11)
	pkg_check_modules(VDPAU_X11 IMPORTED_TARGET vdpau)
endif()

# Assign appropriate Assembler settings based on architecture and target
option(ENABLE_OPTIMIZATIONS "Build ffmpeg with architecture-specific optimizations and Machine Assembly code" OFF)
if (CMAKE_SYSTEM_PROCESSOR MATCHES "amd64.*|AMD64.*|x86_64.*|X86_64.*|x86.*|i686.*|i386.*")
	find_program(YASM_EXECUTABLE yasm)
	if(YASM_EXECUTABLE)
		message(STATUS "Assembler found at: ${YASM_EXECUTABLE}. Enabling ${CMAKE_SYSTEM_PROCESSOR} optimizations")
		enable_language(C ASM_NASM)
		set(ENABLE_OPTIMIZATIONS ON CACHE BOOL "Build ffmpeg with architecture-specific optimizations" FORCE)
	else()
		message(WARNING "YASM not found. Building ffmpeg without ${CMAKE_SYSTEM_PROCESSOR} optimizations")
	endif()
elseif (CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64.*|arm64.*|aarch64.*|arm.*|mips.*")
	if(CMAKE_ASM_COMPILER)
		message(STATUS "Assembler found at: ${CMAKE_ASM_COMPILER}. Enabling ${CMAKE_SYSTEM_PROCESSOR} optimizations")
		enable_language(C ASM)
		set(ENABLE_OPTIMIZATIONS ON CACHE BOOL "Build ffmpeg with architecture-specific optimizations" FORCE)
	else()
		message(WARNING "Assembler not found. Building ffmpeg without ${CMAKE_SYSTEM_PROCESSOR} optimizations")
	endif()
endif()

if (CMAKE_SYSTEM_PROCESSOR MATCHES "amd64.*|AMD64.*|x86_64.*|X86_64.*")
		set(ASM_ARCH="-m amd64")
	if (CMAKE_HOST_SYSTEM_NAME STREQUAL "CYGWIN.*|Windows.*|MSYS.*")
		set(CMAKE_ASM_NASM_OBJECT_FORMAT win64)
	elseif (UNIX AND NOT APPLE)
		set(CMAKE_ASM_NASM_OBJECT_FORMAT elf64)
	elseif (APPLE)
		set(CMAKE_ASM_NASM_OBJECT_FORMAT macho64)
	endif()
elseif (CMAKE_SYSTEM_PROCESSOR MATCHES "x86.*|i686.*|i386.*")
	set(ASM_ARCH="-m x86")
	if (CMAKE_HOST_SYSTEM_NAME STREQUAL "CYGWIN.*|Windows.*|MSYS.*")
		set(CMAKE_ASM_NASM_OBJECT_FORMAT win32)
	elseif (UNIX AND NOT APPLE)
		set(CMAKE_ASM_NASM_OBJECT_FORMAT elf32)
	endif()
elseif (CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64.*|arm64.*|aarch64.*") # if there are no machine/processor-specific
	enable_language(C ASM)											# GNU as flags needed, I could make this an 	
																	# "else"
	# To do - set any GNU as flags that are needed, presumably as CMAKE_ASM_FLAGS
endif()

set(SRC_DIR ../ffmpeg)
set(LIBAVCODEC_SRC_DIR ${SRC_DIR}/libavcodec)
set(LIBAVFORMAT_SRC_DIR ${SRC_DIR}/libavformat)
set(LIBAVUTIL_SRC_DIR ${SRC_DIR}/libavutil)
set(LIBSWRESAMPLE_SRC_DIR ${SRC_DIR}/libswresample)
set(LIBSWSCALE_SRC_DIR ${SRC_DIR}/libswscale)

include(generated_headers.cmake)

# To Do: add some conditionals to not break builds where PIC is not supported, if any
# Seems to be enabled by default at least on amd64 FreeBSD 15.0, but shouldn't hurt to explicitly request it
#add_compile_options(-fPIC)
set(CMAKE_C_FLAGS "-fPIC")
set(CMAKE_ASM_NASM_FLAGS "-DPIC ${ASM_ARCH} -P ${CMAKE_CURRENT_BINARY_DIR}/config.asm")

# To Do - conditionally apply COMPILER_Flags based on the build target

# Mimic the naming convention of current ppsspp-ffmpeg precompiled libraries and distributed headers
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_HOST_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR}/lib)
set(HEADER_INSTALL_DIRECTORY ${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}/../include)
file(MAKE_DIRECTORY ${HEADER_INSTALL_DIRECTORY})

# libavcodec
include(libs/libavcodec.cmake)
add_library(avcodec STATIC ${LIBAVCODEC_SOURCE_FILES})
target_precompile_headers(avcodec PRIVATE ${LIBAVUTIL_SRC_DIR}/internal.h ${LIBAVUTIL_SRC_DIR}/intmath.h)
target_link_libraries(avcodec)
target_include_directories(avcodec PRIVATE ${SRC_DIR} ${VDPAU_X11_INCLUDE_DIRS} ${CMAKE_CURRENT_BINARY_DIR})
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
