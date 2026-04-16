cmake_minimum_required (VERSION 3.10.0)
project (ffmpeg)

include(generated_headers.cmake)

set(SRC_DIR ../ffmpeg)
set(LIBAVCODEC_SRC_DIR ${SRC_DIR}/libavcodec)
set(LIBAVFORMAT_SRC_DIR ${SRC_DIR}/libavformat)
set(LIBAVUTIL_SRC_DIR ${SRC_DIR}/libavutil)
set(LIBSWRESAMPLE_SRC_DIR ${SRC_DIR}/libswresample)
set(LIBSWSCALE_SRC_DIR ${SRC_DIR}/libswscale)

# Mimic the naming convention of current ppsspp-ffmpeg precompiled libraries and distributed headers
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_HOST_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR}/lib)
set(HEADER_INSTALL_DIRECTORY ${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}/../include)
file(MAKE_DIRECTORY ${HEADER_INSTALL_DIRECTORY})

#libavcodec
set(LIBAVCODEC_SOURCE_FILES
	${LIBAVCODEC_SRC_DIR}/aac_ac3_parser.c
	${LIBAVCODEC_SRC_DIR}/aac_parser.c
	${LIBAVCODEC_SRC_DIR}/aacadtsdec.c
	${LIBAVCODEC_SRC_DIR}/aacdec.c
	${LIBAVCODEC_SRC_DIR}/aacps_float.c
	${LIBAVCODEC_SRC_DIR}/aacpsdsp_float.c
	${LIBAVCODEC_SRC_DIR}/aacsbr.c
	${LIBAVCODEC_SRC_DIR}/aactab.c
	${LIBAVCODEC_SRC_DIR}/aandcttab.c
	${LIBAVCODEC_SRC_DIR}/allcodecs.c
	${LIBAVCODEC_SRC_DIR}/atrac.c
	${LIBAVCODEC_SRC_DIR}/atrac3.c
	${LIBAVCODEC_SRC_DIR}/atrac3plus.c
	${LIBAVCODEC_SRC_DIR}/atrac3plusdec.c
	${LIBAVCODEC_SRC_DIR}/atrac3plusdsp.c
	${LIBAVCODEC_SRC_DIR}/audioconvert.c
	${LIBAVCODEC_SRC_DIR}/avdct.c
	${LIBAVCODEC_SRC_DIR}/avfft.c
	${LIBAVCODEC_SRC_DIR}/avpacket.c
	${LIBAVCODEC_SRC_DIR}/avpicture.c
	${LIBAVCODEC_SRC_DIR}/bitstream_filter.c
	${LIBAVCODEC_SRC_DIR}/bitstream.c
	${LIBAVCODEC_SRC_DIR}/blockdsp.c
	${LIBAVCODEC_SRC_DIR}/bswapdsp.c
	${LIBAVCODEC_SRC_DIR}/cabac.c
	${LIBAVCODEC_SRC_DIR}/codec_desc.c
	${LIBAVCODEC_SRC_DIR}/d3d11va.c
	${LIBAVCODEC_SRC_DIR}/dct.c
	${LIBAVCODEC_SRC_DIR}/dct32_fixed.c
	${LIBAVCODEC_SRC_DIR}/dct32_float.c
	${LIBAVCODEC_SRC_DIR}/dirac.c
	${LIBAVCODEC_SRC_DIR}/dv_profile.c
	${LIBAVCODEC_SRC_DIR}/error_resilience.c
	${LIBAVCODEC_SRC_DIR}/exif.c
	${LIBAVCODEC_SRC_DIR}/faandct.c
	${LIBAVCODEC_SRC_DIR}/faanidct.c
	${LIBAVCODEC_SRC_DIR}/fdctdsp.c
	${LIBAVCODEC_SRC_DIR}/fft_fixed_32.c
	${LIBAVCODEC_SRC_DIR}/fft_fixed.c
	${LIBAVCODEC_SRC_DIR}/fft_float.c
	${LIBAVCODEC_SRC_DIR}/fft_init_table.c
	${LIBAVCODEC_SRC_DIR}/ffv1.c
	${LIBAVCODEC_SRC_DIR}/ffv1enc.c
	${LIBAVCODEC_SRC_DIR}/flvdec.c
	${LIBAVCODEC_SRC_DIR}/flvenc.c
	${LIBAVCODEC_SRC_DIR}/frame_thread_encoder.c
	${LIBAVCODEC_SRC_DIR}/golomb.c
	${LIBAVCODEC_SRC_DIR}/h263_parser.c
	${LIBAVCODEC_SRC_DIR}/h263.c
	${LIBAVCODEC_SRC_DIR}/h263data.c
	${LIBAVCODEC_SRC_DIR}/h263dec.c
	${LIBAVCODEC_SRC_DIR}/h263dsp.c
	${LIBAVCODEC_SRC_DIR}/h264_cabac.c
	${LIBAVCODEC_SRC_DIR}/h264_cavlc.c
	${LIBAVCODEC_SRC_DIR}/h264_direct.c
	${LIBAVCODEC_SRC_DIR}/h264_loopfilter.c
	${LIBAVCODEC_SRC_DIR}/h264_mb.c
	${LIBAVCODEC_SRC_DIR}/h264_parser.c
	${LIBAVCODEC_SRC_DIR}/h264_picture.c
	${LIBAVCODEC_SRC_DIR}/h264_ps.c
	${LIBAVCODEC_SRC_DIR}/h264_refs.c
	${LIBAVCODEC_SRC_DIR}/h264_sei.c
	${LIBAVCODEC_SRC_DIR}/h264_slice.c
	${LIBAVCODEC_SRC_DIR}/h264.c
	${LIBAVCODEC_SRC_DIR}/h264chroma.c
	${LIBAVCODEC_SRC_DIR}/h264dsp.c
	${LIBAVCODEC_SRC_DIR}/h264idct.c
	${LIBAVCODEC_SRC_DIR}/h264pred.c
	${LIBAVCODEC_SRC_DIR}/h264qpel.c
	${LIBAVCODEC_SRC_DIR}/hpeldsp.c
	${LIBAVCODEC_SRC_DIR}/huffman.c
	${LIBAVCODEC_SRC_DIR}/huffyuv.c
	${LIBAVCODEC_SRC_DIR}/huffyuvenc.c
	${LIBAVCODEC_SRC_DIR}/huffyuvencdsp.c
	${LIBAVCODEC_SRC_DIR}/idctdsp.c
	${LIBAVCODEC_SRC_DIR}/imdct15.c
	${LIBAVCODEC_SRC_DIR}/imgconvert.c
	${LIBAVCODEC_SRC_DIR}/intelh263dec.c
	${LIBAVCODEC_SRC_DIR}/ituh263dec.c
	${LIBAVCODEC_SRC_DIR}/ituh263enc.c
	${LIBAVCODEC_SRC_DIR}/jfdctfst.c
	${LIBAVCODEC_SRC_DIR}/jfdctint.c
	${LIBAVCODEC_SRC_DIR}/jpegtables.c
	${LIBAVCODEC_SRC_DIR}/jrevdct.c
	${LIBAVCODEC_SRC_DIR}/kbdwin.c
	${LIBAVCODEC_SRC_DIR}/latm_parser.c
	${LIBAVCODEC_SRC_DIR}/lossless_videodsp.c
	${LIBAVCODEC_SRC_DIR}/mathtables.c
	${LIBAVCODEC_SRC_DIR}/mdct_fixed_32.c
	${LIBAVCODEC_SRC_DIR}/mdct_fixed.c
	${LIBAVCODEC_SRC_DIR}/mdct_float.c
	${LIBAVCODEC_SRC_DIR}/me_cmp.c
	${LIBAVCODEC_SRC_DIR}/mjpegbdec.c
	${LIBAVCODEC_SRC_DIR}/mjpegdec.c
	${LIBAVCODEC_SRC_DIR}/motion_est.c
	${LIBAVCODEC_SRC_DIR}/mpeg_er.c
	${LIBAVCODEC_SRC_DIR}/mpeg12.c
	${LIBAVCODEC_SRC_DIR}/mpeg12data.c
	${LIBAVCODEC_SRC_DIR}/mpeg12dec.c
	${LIBAVCODEC_SRC_DIR}/mpeg4audio.c
	${LIBAVCODEC_SRC_DIR}/mpeg4video_parser.c
	${LIBAVCODEC_SRC_DIR}/mpeg4video.c
	${LIBAVCODEC_SRC_DIR}/mpeg4videodec.c
	${LIBAVCODEC_SRC_DIR}/mpeg4videoenc.c
	${LIBAVCODEC_SRC_DIR}/mpegaudio_parser.c
	${LIBAVCODEC_SRC_DIR}/mpegaudio.c
	${LIBAVCODEC_SRC_DIR}/mpegaudiodata.c
	${LIBAVCODEC_SRC_DIR}/mpegaudiodec_fixed.c
	${LIBAVCODEC_SRC_DIR}/mpegaudiodecheader.c
	${LIBAVCODEC_SRC_DIR}/mpegaudiodsp_data.c
	${LIBAVCODEC_SRC_DIR}/mpegaudiodsp_fixed.c
	${LIBAVCODEC_SRC_DIR}/mpegaudiodsp_float.c
	${LIBAVCODEC_SRC_DIR}/mpegaudiodsp.c
	${LIBAVCODEC_SRC_DIR}/mpegpicture.c
	${LIBAVCODEC_SRC_DIR}/mpegutils.c
	${LIBAVCODEC_SRC_DIR}/mpegvideo_enc.c
	${LIBAVCODEC_SRC_DIR}/mpegvideo_motion.c
	${LIBAVCODEC_SRC_DIR}/mpegvideo_parser.c
	${LIBAVCODEC_SRC_DIR}/mpegvideo.c
	${LIBAVCODEC_SRC_DIR}/mpegvideodata.c
	${LIBAVCODEC_SRC_DIR}/mpegvideodsp.c
	${LIBAVCODEC_SRC_DIR}/mpegvideoencdsp.c
	${LIBAVCODEC_SRC_DIR}/options.c
	${LIBAVCODEC_SRC_DIR}/parser.c
	${LIBAVCODEC_SRC_DIR}/pcm.c
	${LIBAVCODEC_SRC_DIR}/pixblockdsp.c
	${LIBAVCODEC_SRC_DIR}/profiles.c
	${LIBAVCODEC_SRC_DIR}/qpeldsp.c
	${LIBAVCODEC_SRC_DIR}/qsv_api.c
	${LIBAVCODEC_SRC_DIR}/rangecoder.c
	${LIBAVCODEC_SRC_DIR}/ratecontrol.c
	${LIBAVCODEC_SRC_DIR}/raw.c
	${LIBAVCODEC_SRC_DIR}/rdft.c
	${LIBAVCODEC_SRC_DIR}/resample.c
	${LIBAVCODEC_SRC_DIR}/resample2.c
	${LIBAVCODEC_SRC_DIR}/rl.c
	${LIBAVCODEC_SRC_DIR}/sbrdsp.c
	${LIBAVCODEC_SRC_DIR}/simple_idct.c
	${LIBAVCODEC_SRC_DIR}/sinewin_fixed.c
	${LIBAVCODEC_SRC_DIR}/sinewin.c
	${LIBAVCODEC_SRC_DIR}/startcode.c
	${LIBAVCODEC_SRC_DIR}/tiff_common.c
	${LIBAVCODEC_SRC_DIR}/utils.c
#	${LIBAVCODEC_SRC_DIR}/vdpau.c	# I had this in my gmake-generated object files, but disabled hwaccels
	${LIBAVCODEC_SRC_DIR}/videodsp.c
	${LIBAVCODEC_SRC_DIR}/vorbis_parser.c
	${LIBAVCODEC_SRC_DIR}/xiph.c
	${LIBAVCODEC_SRC_DIR}/xvididct.c
)

# includes to ship with libavcodec
set(LIBAVCODEC_HEADERS
	${LIBAVCODEC_SRC_DIR}/avcodec.h
	${LIBAVCODEC_SRC_DIR}/avdct.h
	${LIBAVCODEC_SRC_DIR}/avfft.h
	${LIBAVCODEC_SRC_DIR}/dv_profile.h
	${LIBAVCODEC_SRC_DIR}/d3d11va.h
	${LIBAVCODEC_SRC_DIR}/dirac.h
	${LIBAVCODEC_SRC_DIR}/dxva2.h
	${LIBAVCODEC_SRC_DIR}/qsv.h
	${LIBAVCODEC_SRC_DIR}/vaapi.h
	${LIBAVCODEC_SRC_DIR}/vda.h
	${LIBAVCODEC_SRC_DIR}/vdpau.h
	${LIBAVCODEC_SRC_DIR}/version.h
	${LIBAVCODEC_SRC_DIR}/videotoolbox.h
	${LIBAVCODEC_SRC_DIR}/vorbis_parser.h
	${LIBAVCODEC_SRC_DIR}/xvmc.h
)

# OS-specific sources
if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
	list(APPEND LIBAVCODEC_SOURCE_FILES ${LIBAVCODEC_SRC_DIR}/dxva2.c)
	list(APPEND LIBAVCODEC_SOURCE_FILES ${LIBAVCODEC_SRC_DIR}/dxva2_h264.c)
	list(APPEND LIBAVCODEC_SOURCE_FILES ${LIBAVCODEC_SRC_DIR}/avcodecres.c)
	list(APPEND LIBAVCODEC_SOURCE_FILES ${LIBAVCODEC_SRC_DIR}/file_open.c) # if LIBC_MSVC
else()
	list(APPEND LIBAVCODEC_SOURCE_FILES ${LIBAVCODEC_SRC_DIR}/pthread.c)
	list(APPEND LIBAVCODEC_SOURCE_FILES ${LIBAVCODEC_SRC_DIR}/pthread_slice.c)
	list(APPEND LIBAVCODEC_SOURCE_FILES ${LIBAVCODEC_SRC_DIR}/pthread_frame.c)
endif()
# To Do - add a conditional for HAVE_LIBC_MSVCRT to pull in file_open.c
# Along those lines--deal with threads, on both UNIX and Windows, as conditionals, see libavcodec/Makefile
# Because without it we get linker errors building PPSSPP with these bundled ffmpeg libs
# I did an ugly, quick-and-dirty for threads, based on an else() after Windows, but this SHOULD be a bona fide test

add_library(avcodec STATIC ${LIBAVCODEC_SOURCE_FILES})
target_precompile_headers(avcodec PRIVATE ${LIBAVUTIL_SRC_DIR}/internal.h ${LIBAVUTIL_SRC_DIR}/intmath.h)
target_link_libraries(avcodec)
target_include_directories(avcodec PRIVATE ${SRC_DIR} ${CMAKE_CURRENT_BINARY_DIR})
file(COPY ${LIBAVCODEC_HEADERS} DESTINATION ${HEADER_INSTALL_DIRECTORY}/libavcodec)
set(LIBAVCODEC_LIBRARY avcodec)

# libavformat
# May need to further check for LIBC_MSVCRT vs GNU_WINDRES on Windows hosts
set(LIBAVFORMAT_SOURCE_FILES
	${LIBAVFORMAT_SRC_DIR}/aacdec.c
	${LIBAVFORMAT_SRC_DIR}/allformats.c
	${LIBAVFORMAT_SRC_DIR}/apetag.c
	${LIBAVFORMAT_SRC_DIR}/avidec.c
	${LIBAVFORMAT_SRC_DIR}/avienc.c
	${LIBAVFORMAT_SRC_DIR}/avio.c
	${LIBAVFORMAT_SRC_DIR}/aviobuf.c
	${LIBAVFORMAT_SRC_DIR}/avlanguage.c
	${LIBAVFORMAT_SRC_DIR}/cutils.c
	${LIBAVFORMAT_SRC_DIR}/dump.c
	${LIBAVFORMAT_SRC_DIR}/file.c
	${LIBAVFORMAT_SRC_DIR}/format.c
	${LIBAVFORMAT_SRC_DIR}/h263dec.c
	${LIBAVFORMAT_SRC_DIR}/h264dec.c
	${LIBAVFORMAT_SRC_DIR}/id3v1.c
	${LIBAVFORMAT_SRC_DIR}/id3v2.c
	${LIBAVFORMAT_SRC_DIR}/img2.c
	${LIBAVFORMAT_SRC_DIR}/isom.c
	${LIBAVFORMAT_SRC_DIR}/m4vdec.c
	${LIBAVFORMAT_SRC_DIR}/metadata.c
	${LIBAVFORMAT_SRC_DIR}/mp3dec.c
	${LIBAVFORMAT_SRC_DIR}/mpeg.c
	${LIBAVFORMAT_SRC_DIR}/mpegtsenc.c
	${LIBAVFORMAT_SRC_DIR}/mpegvideodec.c
	${LIBAVFORMAT_SRC_DIR}/mux.c
	${LIBAVFORMAT_SRC_DIR}/oma.c
	${LIBAVFORMAT_SRC_DIR}/omadec.c
	${LIBAVFORMAT_SRC_DIR}/options.c
	${LIBAVFORMAT_SRC_DIR}/os_support.c
	${LIBAVFORMAT_SRC_DIR}/pcm.c
	${LIBAVFORMAT_SRC_DIR}/pcmdec.c
	${LIBAVFORMAT_SRC_DIR}/pmpdec.c
	${LIBAVFORMAT_SRC_DIR}/qtpalette.c
	${LIBAVFORMAT_SRC_DIR}/rawdec.c
	${LIBAVFORMAT_SRC_DIR}/replaygain.c
	${LIBAVFORMAT_SRC_DIR}/riff.c
	${LIBAVFORMAT_SRC_DIR}/riffdec.c
	${LIBAVFORMAT_SRC_DIR}/riffenc.c
	${LIBAVFORMAT_SRC_DIR}/sdp.c
	${LIBAVFORMAT_SRC_DIR}/url.c
	${LIBAVFORMAT_SRC_DIR}/utils.c
	${LIBAVFORMAT_SRC_DIR}/wavdec.c
)

set(LIBAVFORMAT_HEADERS
	${LIBAVFORMAT_SRC_DIR}/avformat.h
	${LIBAVFORMAT_SRC_DIR}/avio.h
	${LIBAVFORMAT_SRC_DIR}/version.h
)

# OS-specific sources
if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
	list(APPEND LIBAVFORMAT_SOURCE_FILES ${LIBAVFORMAT_SRC_DIR}/avformatres.rc)
endif()

add_library(avformat STATIC ${LIBAVFORMAT_SOURCE_FILES})
target_precompile_headers(avformat PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/config.h ${LIBAVUTIL_SRC_DIR}/internal.h)
target_link_libraries(avformat)
target_include_directories(avformat PRIVATE ${SRC_DIR} ${CMAKE_CURRENT_BINARY_DIR})
file(COPY ${LIBAVFORMAT_HEADERS} DESTINATION ${HEADER_INSTALL_DIRECTORY}/libavformat)
set(LIBAVFORMAT_LIBRARY avformat)

# libavutil
set(LIBAVUTIL_SOURCE_FILES
	${LIBAVUTIL_SRC_DIR}/adler32.c
	${LIBAVUTIL_SRC_DIR}/aes_ctr.c
	${LIBAVUTIL_SRC_DIR}/aes.c
	${LIBAVUTIL_SRC_DIR}/audio_fifo.c
	${LIBAVUTIL_SRC_DIR}/avstring.c
	${LIBAVUTIL_SRC_DIR}/base64.c
	${LIBAVUTIL_SRC_DIR}/blowfish.c
	${LIBAVUTIL_SRC_DIR}/bprint.c
	${LIBAVUTIL_SRC_DIR}/buffer.c
	${LIBAVUTIL_SRC_DIR}/camellia.c
	${LIBAVUTIL_SRC_DIR}/cast5.c
	${LIBAVUTIL_SRC_DIR}/channel_layout.c
	${LIBAVUTIL_SRC_DIR}/color_utils.c
	${LIBAVUTIL_SRC_DIR}/cpu.c
	${LIBAVUTIL_SRC_DIR}/crc.c
	${LIBAVUTIL_SRC_DIR}/des.c
	${LIBAVUTIL_SRC_DIR}/dict.c
	${LIBAVUTIL_SRC_DIR}/display.c
	${LIBAVUTIL_SRC_DIR}/downmix_info.c
	${LIBAVUTIL_SRC_DIR}/error.c
	${LIBAVUTIL_SRC_DIR}/eval.c
	${LIBAVUTIL_SRC_DIR}/fifo.c
	${LIBAVUTIL_SRC_DIR}/file_open.c
	${LIBAVUTIL_SRC_DIR}/file.c
	${LIBAVUTIL_SRC_DIR}/fixed_dsp.c
	${LIBAVUTIL_SRC_DIR}/float_dsp.c
	${LIBAVUTIL_SRC_DIR}/frame.c
	${LIBAVUTIL_SRC_DIR}/hash.c
	${LIBAVUTIL_SRC_DIR}/hmac.c
	${LIBAVUTIL_SRC_DIR}/imgutils.c
	${LIBAVUTIL_SRC_DIR}/integer.c
	${LIBAVUTIL_SRC_DIR}/intmath.c
	${LIBAVUTIL_SRC_DIR}/lfg.c
	${LIBAVUTIL_SRC_DIR}/lls.c
	${LIBAVUTIL_SRC_DIR}/log.c
	${LIBAVUTIL_SRC_DIR}/log2_tab.c
	${LIBAVUTIL_SRC_DIR}/mastering_display_metadata.c
	${LIBAVUTIL_SRC_DIR}/mathematics.c
	${LIBAVUTIL_SRC_DIR}/md5.c
	${LIBAVUTIL_SRC_DIR}/mem.c
	${LIBAVUTIL_SRC_DIR}/murmur3.c
	${LIBAVUTIL_SRC_DIR}/opt.c
	${LIBAVUTIL_SRC_DIR}/parseutils.c
	${LIBAVUTIL_SRC_DIR}/pixdesc.c
	${LIBAVUTIL_SRC_DIR}/pixelutils.c
	${LIBAVUTIL_SRC_DIR}/random_seed.c
	${LIBAVUTIL_SRC_DIR}/rational.c
	${LIBAVUTIL_SRC_DIR}/rc4.c
	${LIBAVUTIL_SRC_DIR}/reverse.c
	${LIBAVUTIL_SRC_DIR}/ripemd.c
	${LIBAVUTIL_SRC_DIR}/samplefmt.c
	${LIBAVUTIL_SRC_DIR}/sha.c
	${LIBAVUTIL_SRC_DIR}/sha512.c
	${LIBAVUTIL_SRC_DIR}/stereo3d.c
	${LIBAVUTIL_SRC_DIR}/tea.c
	${LIBAVUTIL_SRC_DIR}/threadmessage.c
	${LIBAVUTIL_SRC_DIR}/time.c
	${LIBAVUTIL_SRC_DIR}/timecode.c
	${LIBAVUTIL_SRC_DIR}/tree.c
	${LIBAVUTIL_SRC_DIR}/twofish.c
	${LIBAVUTIL_SRC_DIR}/utils.c
	${LIBAVUTIL_SRC_DIR}/xga_font_data.c
	${LIBAVUTIL_SRC_DIR}/xtea.c
)

set(LIBAVUTIL_HEADERS
	${LIBAVUTIL_SRC_DIR}/adler32.h
	${LIBAVUTIL_SRC_DIR}/aes.h
	${LIBAVUTIL_SRC_DIR}/aes_ctr.h
	${LIBAVUTIL_SRC_DIR}/attributes.h
	${LIBAVUTIL_SRC_DIR}/audio_fifo.h
	${LIBAVUTIL_SRC_DIR}/avassert.h
	${LIBAVUTIL_SRC_DIR}/avstring.h
	${LIBAVUTIL_SRC_DIR}/avutil.h
	${LIBAVUTIL_SRC_DIR}/base64.h
	${LIBAVUTIL_SRC_DIR}/blowfish.h
	${LIBAVUTIL_SRC_DIR}/bprint.h
	${LIBAVUTIL_SRC_DIR}/bswap.h
	${LIBAVUTIL_SRC_DIR}/buffer.h
	${LIBAVUTIL_SRC_DIR}/cast5.h
	${LIBAVUTIL_SRC_DIR}/camellia.h
	${LIBAVUTIL_SRC_DIR}/channel_layout.h
	${LIBAVUTIL_SRC_DIR}/common.h
	${LIBAVUTIL_SRC_DIR}/cpu.h
	${LIBAVUTIL_SRC_DIR}/crc.h
	${LIBAVUTIL_SRC_DIR}/des.h
	${LIBAVUTIL_SRC_DIR}/display.h
	${LIBAVUTIL_SRC_DIR}/downmix_info.h
	${LIBAVUTIL_SRC_DIR}/error.h
	${LIBAVUTIL_SRC_DIR}/eval.h
	${LIBAVUTIL_SRC_DIR}/fifo.h
	${LIBAVUTIL_SRC_DIR}/file.h
	${LIBAVUTIL_SRC_DIR}/frame.h
	${LIBAVUTIL_SRC_DIR}/hash.h
	${LIBAVUTIL_SRC_DIR}/hmac.h
	${LIBAVUTIL_SRC_DIR}/imgutils.h
	${LIBAVUTIL_SRC_DIR}/intfloat.h
	${LIBAVUTIL_SRC_DIR}/intreadwrite.h
	${LIBAVUTIL_SRC_DIR}/lfg.h
	${LIBAVUTIL_SRC_DIR}/log.h
	${LIBAVUTIL_SRC_DIR}/macros.h
	${LIBAVUTIL_SRC_DIR}/mathematics.h
	${LIBAVUTIL_SRC_DIR}/mastering_display_metadata.h
	${LIBAVUTIL_SRC_DIR}/md5.h
	${LIBAVUTIL_SRC_DIR}/mem.h
	${LIBAVUTIL_SRC_DIR}/motion_vector.h
	${LIBAVUTIL_SRC_DIR}/murmur3.h
	${LIBAVUTIL_SRC_DIR}/dict.h
	${LIBAVUTIL_SRC_DIR}/opt.h
	${LIBAVUTIL_SRC_DIR}/parseutils.h
	${LIBAVUTIL_SRC_DIR}/pixdesc.h
	${LIBAVUTIL_SRC_DIR}/pixelutils.h
	${LIBAVUTIL_SRC_DIR}/pixfmt.h
	${LIBAVUTIL_SRC_DIR}/random_seed.h
	${LIBAVUTIL_SRC_DIR}/rc4.h
	${LIBAVUTIL_SRC_DIR}/replaygain.h
	${LIBAVUTIL_SRC_DIR}/rational.h
	${LIBAVUTIL_SRC_DIR}/ripemd.h
	${LIBAVUTIL_SRC_DIR}/samplefmt.h
	${LIBAVUTIL_SRC_DIR}/sha.h
	${LIBAVUTIL_SRC_DIR}/sha512.h
	${LIBAVUTIL_SRC_DIR}/stereo3d.h
	${LIBAVUTIL_SRC_DIR}/threadmessage.h
	${LIBAVUTIL_SRC_DIR}/time.h
	${LIBAVUTIL_SRC_DIR}/timecode.h
	${LIBAVUTIL_SRC_DIR}/timestamp.h
	${LIBAVUTIL_SRC_DIR}/tree.h
	${LIBAVUTIL_SRC_DIR}/twofish.h
	${LIBAVUTIL_SRC_DIR}/version.h
	${LIBAVUTIL_SRC_DIR}/xtea.h
	${LIBAVUTIL_SRC_DIR}/tea.h
	${CMAKE_CURRENT_BINARY_DIR}/libavutil/ffversion.h 
	${CMAKE_CURRENT_BINARY_DIR}/libavutil/avconfig.h 
)

# Architecture-specific sources
if(CMAKE_SYSTEM_PROCESSOR MATCHES "amd64.*|AMD64.*|x86_64.*|X86_64.*|x86.*|i686.*|i386.*")
	list(APPEND LIBAVUTIL_SOURCE_FILES ${LIBAVUTIL_SRC_DIR}/x86/cpu.c)
	list(APPEND LIBAVUTIL_SOURCE_FILES ${LIBAVUTIL_SRC_DIR}/x86/fixed_dsp_init.c)
	list(APPEND LIBAVUTIL_SOURCE_FILES ${LIBAVUTIL_SRC_DIR}/x86/float_dsp_init.c)
	list(APPEND LIBAVUTIL_SOURCE_FILES ${LIBAVUTIL_SRC_DIR}/x86/lls_init.c)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64.*|arm64.*|aarch64.*")
	list(APPEND LIBAVUTIL_SOURCE_FILES ${LIBAVUTIL_SRC_DIR}/aarch64/cpu.c)
	list(APPEND LIBAVUTIL_SOURCE_FILES ${LIBAVUTIL_SRC_DIR}/aarch64/float_dsp_init.c)
	list(APPEND LIBAVUTIL_SOURCE_FILES ${LIBAVUTIL_SRC_DIR}/aarch64/float_dsp_neon.c)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "arm.*")
	list(APPEND LIBAVUTIL_SOURCE_FILES ${LIBAVUTIL_SRC_DIR}/arm/cpu.c)
	list(APPEND LIBAVUTIL_SOURCE_FILES ${LIBAVUTIL_SRC_DIR}/arm/float_dsp_init_arm.c)
	list(APPEND LIBAVUTIL_SOURCE_FILES ${LIBAVUTIL_SRC_DIR}/arm/float_dsp_init_neon.c)
	list(APPEND LIBAVUTIL_SOURCE_FILES ${LIBAVUTIL_SRC_DIR}/arm/float_dsp_neon.c)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "mips.*")
	list(APPEND LIBAVUTIL_SOURCE_FILES ${LIBAVUTIL_SRC_DIR}/mips/float_dsp_mips.c)
endif()

# OS-specific sources
if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
	list(APPEND LIBAVUTIL_SOURCE_FILES ${LIBAVUTIL_SRC_DIR}/avutilres.rc)
endif()

add_library(avutil STATIC ${LIBAVUTIL_SOURCE_FILES})
target_precompile_headers(avutil PRIVATE 
	${CMAKE_CURRENT_BINARY_DIR}/libavutil/ffversion.h 
	${CMAKE_CURRENT_BINARY_DIR}/libavutil/avconfig.h 
	${LIBAVUTIL_SRC_DIR}/internal.h
)
target_link_libraries(avutil)
target_include_directories(avutil PRIVATE ${SRC_DIR} ${CMAKE_CURRENT_BINARY_DIR})
file(COPY ${LIBAVUTIL_HEADERS} DESTINATION ${HEADER_INSTALL_DIRECTORY}/libavutil)
set(LIBAVUTIL_LIBRARY avutil)

# libswresample
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

# Architecture-specific sources
# NOTE: I'm not sure if neontest.c is required for aarch64 and arm, or if neon-objs should replace objs
if(CMAKE_SYSTEM_PROCESSOR MATCHES "amd64.*|AMD64.*|x86_64.*|X86_64.*|x86.*|i686.*|i386.*")
	list(APPEND LIBSWRESAMPLE_SOURCE_FILES ${LIBSWRESAMPLE_SRC_DIR}/x86/audio_convert_init.c)
	list(APPEND LIBSWRESAMPLE_SOURCE_FILES ${LIBSWRESAMPLE_SRC_DIR}/x86/rematrix_init.c)
	list(APPEND LIBSWRESAMPLE_SOURCE_FILES ${LIBSWRESAMPLE_SRC_DIR}/x86/resample_init.c)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64.*|arm64.*|aarch64.*")
	list(APPEND LIBSWRESAMPLE_SOURCE_FILES ${LIBSWRESAMPLE_SRC_DIR}/aarch64/audio_convert_init.c)
	list(APPEND LIBSWRESAMPLE_SOURCE_FILES ${LIBSWRESAMPLE_SRC_DIR}/aarch64/audio_convert_neon.c)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "arm.*")
	list(APPEND LIBSWRESAMPLE_SOURCE_FILES ${LIBSWRESAMPLE_SRC_DIR}/arm/audio_convert_init.c)
	list(APPEND LIBSWRESAMPLE_SOURCE_FILES ${LIBSWRESAMPLE_SRC_DIR}/arm/audio_convert_neon.c)
endif()

# OS-specific sources
if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
	list(APPEND LIBSWRESAMPLE_SOURCE_FILES ${LIBSWRESAMPLE_SRC_DIR}/swresampleres.rc)
endif()

add_library(swresample STATIC ${LIBSWRESAMPLE_SOURCE_FILES})
target_precompile_headers(swresample PRIVATE ${LIBAVUTIL_SRC_DIR}/cpu.h ${LIBAVUTIL_SRC_DIR}/internal.h)
target_link_libraries(swresample)
target_include_directories(swresample PUBLIC ${SRC_DIR} ${CMAKE_CURRENT_BINARY_DIR})
file(COPY ${LIBSWRESAMPLE_HEADERS} DESTINATION ${HEADER_INSTALL_DIRECTORY}/libswresample)
set(LIBSWRESAMPLE_LIBRARY swresample)

# libswscale
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
	list(APPEND LIBSWSCALE_SOURCE_FILES ${LIBSWSCALE_SRC_DIR}/x86/rgb2rgb.c)
	list(APPEND LIBSWSCALE_SOURCE_FILES ${LIBSWSCALE_SRC_DIR}/x86/swscale.c)
	list(APPEND LIBSWSCALE_SOURCE_FILES ${LIBSWSCALE_SRC_DIR}/x86/yuv2rgb.c)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64.*|arm64.*|aarch64.*|arm.*")
	list(APPEND LIBSWSCALE_SOURCE_FILES ${LIBSWSCALE_SRC_DIR}/arm/swscale_unscaled.c)
	list(APPEND LIBSWSCALE_SOURCE_FILES ${LIBSWSCALE_SRC_DIR}/arm/yuv2rgb.c)
endif()

# OS-specific sources
if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
	list(APPEND LIBSWSCALE_SOURCE_FILES ${LIBSWSCALE_SRC_DIR}/swscaleres.rc)
endif()

add_library(swscale STATIC ${LIBSWSCALE_SOURCE_FILES})
target_precompile_headers(swscale PRIVATE ${LIBAVUTIL_SRC_DIR}/internal.h)
target_link_libraries(swscale)
target_include_directories(swscale PRIVATE ${SRC_DIR} ${CMAKE_CURRENT_BINARY_DIR})
file(COPY ${LIBSWSCALE_HEADERS} DESTINATION ${HEADER_INSTALL_DIRECTORY}/libswscale)
set(LIBSWSCALE_LIBRARY swscale)

