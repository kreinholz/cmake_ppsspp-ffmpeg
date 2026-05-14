# libswresample source files (all platforms)
set(LIBSWRESAMPLE_SOURCE_FILES
	${LIBSWRESAMPLE_SRC_DIR}/swresample.h
	${LIBSWRESAMPLE_SRC_DIR}/audioconvert.c
	${LIBSWRESAMPLE_SRC_DIR}/dither.c
	${LIBSWRESAMPLE_SRC_DIR}/options.c
	${LIBSWRESAMPLE_SRC_DIR}/rematrix.c
	${LIBSWRESAMPLE_SRC_DIR}/resample_dsp.c
	${LIBSWRESAMPLE_SRC_DIR}/resample.c
	${LIBSWRESAMPLE_SRC_DIR}/swresample_frame.c
	${LIBSWRESAMPLE_SRC_DIR}/swresample.c
)

set(LIBSWRESAMPLE_HEADERS
	${LIBSWRESAMPLE_SRC_DIR}/swresample.h
	${LIBSWRESAMPLE_SRC_DIR}/version.h
)

# OS-specific sources
if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows" OR GNU_WINDRES OR MSVC)
	list(APPEND LIBSWRESAMPLE_SOURCE_FILES ${LIBSWRESAMPLE_SRC_DIR}/swresampleres.rc)
endif()
