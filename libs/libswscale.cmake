# libswscale source files (all platforms)
set(LIBSWSCALE_SOURCE_FILES
	${LIBSWSCALE_SRC_DIR}/alphablend.c
	${LIBSWSCALE_SRC_DIR}/gamma.c
	${LIBSWSCALE_SRC_DIR}/hscale_fast_bilinear.c
	${LIBSWSCALE_SRC_DIR}/hscale.c
	${LIBSWSCALE_SRC_DIR}/input.c
	${LIBSWSCALE_SRC_DIR}/options.c
	${LIBSWSCALE_SRC_DIR}/output.c
	${LIBSWSCALE_SRC_DIR}/rgb2rgb.c
	${LIBSWSCALE_SRC_DIR}/slice.c
	${LIBSWSCALE_SRC_DIR}/swscale_unscaled.c
	${LIBSWSCALE_SRC_DIR}/swscale.c
	${LIBSWSCALE_SRC_DIR}/utils.c
	${LIBSWSCALE_SRC_DIR}/vscale.c
	${LIBSWSCALE_SRC_DIR}/yuv2rgb.c
)

set(LIBSWSCALE_HEADERS
	${LIBSWSCALE_SRC_DIR}/swscale.h
	${LIBSWSCALE_SRC_DIR}/version.h
)

# Architecture-specific sources
if(CMAKE_SYSTEM_PROCESSOR MATCHES "amd64.*|AMD64.*|x86_64.*|X86_64.*|x86.*|i686.*|i386.*")
	list(APPEND LIBSWSCALE_SOURCE_FILES ${LIBSWSCALE_SRC_DIR}/x86/hscale_fast_bilinear_simd.c)
	list(APPEND LIBSWSCALE_SOURCE_FILES ${LIBSWSCALE_SRC_DIR}/x86/input.asm)
	list(APPEND LIBSWSCALE_SOURCE_FILES ${LIBSWSCALE_SRC_DIR}/x86/rgb2rgb.c)
	list(APPEND LIBSWSCALE_SOURCE_FILES ${LIBSWSCALE_SRC_DIR}/x86/swscale.c)
	list(APPEND LIBSWSCALE_SOURCE_FILES ${LIBSWSCALE_SRC_DIR}/x86/yuv2rgb.c)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64.*|arm64.*|aarch64.*|arm.*")
	# To do - add appropriate additional sources
	list(APPEND LIBSWSCALE_SOURCE_FILES ${LIBSWSCALE_SRC_DIR}/arm/swscale_unscaled.c)
	list(APPEND LIBSWSCALE_SOURCE_FILES ${LIBSWSCALE_SRC_DIR}/arm/yuv2rgb.c)
endif()

# OS-specific sources
if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
	list(APPEND LIBSWSCALE_SOURCE_FILES ${LIBSWSCALE_SRC_DIR}/swscaleres.rc)
endif()
