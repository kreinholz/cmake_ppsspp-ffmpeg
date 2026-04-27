# Before we compile ffmpeg libs, we need to generate config.h/config.asm, libavutil/avconfig.h, and libavutil/ffversion.h.

# Generate config.h file
include(CheckCSourceCompiles)
include(CheckTypeSize)
include(CheckStructHasMember)
include(CheckSymbolExists)
include(CheckFunctionExists)
include(CheckIncludeFile)

set(extern_prefix \"\")
set(extern_asm "")
set(build_suffix \"\")
set(SLIBSUF \"${CMAKE_SHARED_LIBRARY_SUFFIX}\")
set(sws_max_filter_size 256)	# I was originally against hardcoding, but line 3055 of configure hardcodes '256'

# Test for restrict command
# To Do - if ffmpeg needs this, add a compiler flag such as -std=c99 to the build environment
if (c_restrict IN_LIST CMAKE_C_COMPILE_FEATURES)
	set(_RESTRICT restrict)
else()
	set(_RESTRICT "")
endif()

# Test for FAST_UNALIGNED
if(CMAKE_SYSTEM_PROCESSOR MATCHES "amd64.*|AMD64.*|x86_64.*|X86_64.*|x86.*|i686.*|i386.*|ARM64.*|arm64.*|aarch64.*")
	set(FAST_UNALIGNED 1)
	set(ALIGNED_STACK 1)
else()
	set(FAST_UNALIGNED 0)
	set(ALIGNED_STACK 0)
endif()

# Set the appropriate CPU variables
if(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64.*|arm64.*|aarch64.*")
	set(ARCH_AARCH64 1)
	set(HAVE_FAST_64BIT 1)
else()
	set(ARCH_AARCH64 0)
endif()
# Note - skipping Alpha
if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm.*")
	set(ARCH_ARM 1)
else()
	set(ARCH_ARM 0)
endif()
# Note - skipping Ardueno and other exotic CPU types, plus really old ones like m68k "classic" Macintosh chips
if(CMAKE_SYSTEM_PROCESSOR MATCHES "mips.*")
	set(ARCH_MIPS 1)
else()
	set(ARCH_MIPS 0)
endif()
if(CMAKE_SYSTEM_PROCESSOR MATCHES "mips64.*")
	set(ARCH_MIPS64 1)
else()
	set(ARCH_MIPS64 0)
endif()
if(CMAKE_SYSTEM_PROCESSOR MATCHES "amd64.*|AMD64.*|x86_64.*|X86_64.*")
	set(ARCH_X86_64 1)
	set(HAVE_FAST_64BIT 1)
	set(HAVE_FAST_CMOV 1)
else()
	set(ARCH_X86_64 0)
endif()
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86.*|i686.*|i386.*")
	set(ARCH_X86 1)
	set(HAVE_FAST_CMOV 1)
else()
	set(ARCH_X86 0)
endif()

# Start of some relevant 'HAVE_' tests

# The following 15-line function was written by Copilot (AI)
function(test_arm_support FLAG INSTRUCTION RESULT_VAR)
	# Save original CMAKE_REQUIRED_FLAGS
	set(_OLD_FLAGS "${CMAKE_REQUIRED_FLAGS}")
	# Add test flag
	set(CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS} ${FLAG}")
	# Try compiling a small snippet that uses the instruction
	check_c_source_compiles("
		int main(void) {
			__asm__ volatile(\"${INSTRUCTION}\");
			return 0;
		}
	" ${RESULT_VAR})
	# Restore original flags
	set(CMAKE_REQUIRED_FLAGS "${__OLD_FLAGS}")
endfunction()

# Modified test for x86 and other features, inspired by the above Copilot (AI) function
function(test_compiler_support FLAG TEST_CODE RESULT_VAR)
	# Save original CMAKE_REQUIRED_FLAGS
	set(_OLD_FLAGS "${CMAKE_REQUIRED_FLAGS}")
	# Add test flag
	set(CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS} ${FLAG}")
	# Try compiling a small snippet that uses the instruction
	check_c_source_compiles("${TEST_CODE}" "${RESULT_VAR}")
	# Restore original flags
	set(CMAKE_REQUIRED_FLAGS "${__OLD_FLAGS}")
endfunction()

# Very short convenience function (written by me) to set specified variable to "1" if defined, "0" if undefined
function(assign_value INPUT_VAR)
	if(${INPUT_VAR})
		set(${INPUT_VAR} 1 PARENT_SCOPE)
	else()
		set(${INPUT_VAR} 0 PARENT_SCOPE)
	endif()
endfunction()

assign_value(HAVE_FAST_64BIT)
assign_value(HAVE_FAST_CMOV)

# The following tests, which use Copilot's function, are taken straight from ffmpeg-3.0.2's configure script
if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm.*")
	test_arm_support("-mfpu=neon" "vadd.i16 q0, q0, q0" HAVE_NEON)
	test_arm_support("-mfpu=armv6" "sadd16 r0, r0, r0" HAVE_ARMV6)
	test_arm_support("-mfpu=armv6t2" "movt r0, #0" HAVE_ARMV6T2)
	test_arm_support("-mfpu=vfp" "fadds s0, s0, s0" HAVE_VFP)
	test_arm_support("-mfpu=vfp" "vmov.f32 s0, #1.0" HAVE_VFPV3)
	test_arm_support("-mfpu=setend" "setend be" HAVE_SETEND)
endif()
# Note - we only want to run the above tests on Arm; but we still want to assign a "1" or "0" value in config.h
assign_value(HAVE_NEON)
assign_value(HAVE_ARMV6)
assign_value(HAVE_ARMV6T2)
assign_value(HAVE_VFP)
assign_value(HAVE_VFPV3)
assign_value(HAVE_SETEND)

# The following are all PPC features--since we're not building PPSSPP on Big Endian, so we can hardcode these to "0"
#define HAVE_ALTIVEC 0
#define HAVE_DCBZL 0
#define HAVE_LDBRX 0
#define HAVE_POWER8 0
#define HAVE_PPC4XX 0
#define HAVE_VSX 0

# x86(_64) specific features - compiler test code suggested by Copilot AI
if(CMAKE_SYSTEM_PROCESSOR MATCHES "amd64.*|AMD64.*|x86_64.*|X86_64.*|x86.*|i686.*|i386.*" AND ENABLE_OPTIMIZATIONS)
	# Instead of actually testing for the following CPU features, turn them on since that's what ffmpeg's configure
	# script apparently does, even non-Intel compatible, discontinued features like FMA4 and XOP, because they get
	# set to 'true' on my Intel Xeon build system even though it lacks support for either of them or AMD3DNOWEXT
	set(HAVE_AESNI 1)
	set(HAVE_AMD3DNOW 1)
	set(HAVE_AMD3DNOWEXT 1)
	set(HAVE_AVX 1)
	set(HAVE_AVX2 1)
	set(HAVE_FMA3 1)
	set(HAVE_FMA4 1)
	set(HAVE_MMX 1)
	set(HAVE_MMXEXT 1)
	set(HAVE_SSE 1)
	set(HAVE_SSE2 1)
	set(HAVE_SSE3 1)
	set(HAVE_SSE4 1)
	set(HAVE_SSE42 1)
	set(HAVE_SSSE3 1)
	set(HAVE_XOP 1)
	set(HAVE_CPUNOP 1)
#[[
	test_compiler_support("-maes" "#include <immintrin.h>\nint main(void){_mm_aesenc_si128(_mm_setzero_si128(), _mm_setzero_si128());return 0;}" HAVE_AESNI)
	test_compiler_support("" "int main(void){__asm__ __volatile__(\"pfadd %%mm0, %%mm1\" ::: \"mm0\", \"mm1\");return 0;}" HAVE_AMD3DNOW)
	test_compiler_support("" "int main(void){__asm__ __volatile__(\"pavgusb %%mm0, %%mm1\\n\" ::: \"mm0\", \"mm1\");return 0;}" HAVE_AMD3DNOWEXT)
	test_compiler_support("-mavx" "#include <immintrin.h>\nint main(void){__m256 a=_mm256_setzero_ps();return 0;}" HAVE_AVX)
	test_compiler_support("-mavx2" "#include <immintrin.h>\nint main(void){__m256i a=_mm256_setzero_si256();return 0;}" HAVE_AVX2)
	test_compiler_support("-mfma" "#include <immintrin.h>\nint main(void){_mm256_fmadd_ps(_mm256_set1_ps(1.0f), _mm256_set1_ps(2.0f), _mm256_set1_ps(3.0f));return 0;}" HAVE_FMA3)
	test_compiler_support("-mfma" "#include <immintrin.h>\nint main(void){_mm256_macc_ps(_mm256_set1_ps(1.0f), _mm256_set1_ps(2.0f), _mm256_set1_ps(3.0f));return 0;}" HAVE_FMA4)
	test_compiler_support("-mmmx" "#include <mmintrin.h>\nint main(void){_mm_empty();return 0;}" HAVE_MMX)
	test_compiler_support("-mmmx" "#include <mmintrin.h>\n#include <xmmintrin.h>\nint main(void){__m64 a = _mm_setzero_si64();return 0;}" HAVE_MMXEXT)
	test_compiler_support("-msse" "#include <xmmintrin.h>\nint main(void){__m128 a=_mm_setzero_ps();return 0;}" HAVE_SSE)
	test_compiler_support("-msse2" "#include <emmintrin.h>\nint main(void){ __m128d a=_mm_setzero_pd();return 0;}" HAVE_SSE2)
	test_compiler_support("-msse3" "#include <pmmintrin.h>\nint main(void){__m128 a=_mm_hadd_ps(_mm_setzero_ps(),_mm_setzero_ps());return 0;}" HAVE_SSE3)
	test_compiler_support("-msse4.1" "#include <smmintrin.h>\nint main(void){__m128i a=_mm_blend_epi16(_mm_setzero_si128(),_mm_setzero_si128(),0xF0);return 0;}" HAVE_SSE4)
	test_compiler_support("-msse4.2" "#include <nmmintrin.h>\nint main(void){int r=_mm_crc32_u32(0,0);return 0;}" HAVE_SSE42)
	test_compiler_support("-mssse3" "#include <immintrin.h>\nint main(void){_mm_abs_epi8(_mm_set1_epi8(-1));return 0;}" HAVE_SSSE3)
	test_compiler_support("-mxop" "#include <immintrin.h>\nint main(void){_mm256_roti_epi32(_mm256_set1_epi32(1), 1);return 0;}" HAVE_XOP)
	test_compiler_support("" "int main(void){__asm__ __volatile__(\"nop\");return 0;}" HAVE_CPUNOP)
]]
endif()

# Note - we only want to run the above tests on x86(_64); but we still want to assign a "1" or "0" value in config.h
assign_value(HAVE_AESNI)
assign_value(HAVE_AMD3DNOW)
assign_value(HAVE_AMD3DNOWEXT)
assign_value(HAVE_AVX)
assign_value(HAVE_AVX2)
assign_value(HAVE_FMA3)
assign_value(HAVE_FMA4)
assign_value(HAVE_MMX)
assign_value(HAVE_MMXEXT)
assign_value(HAVE_SSE)
assign_value(HAVE_SSE2)
assign_value(HAVE_SSE3)
assign_value(HAVE_SSE4)
assign_value(HAVE_SSE42)
assign_value(HAVE_SSSE3)
assign_value(HAVE_XOP)
assign_value(HAVE_CPUNOP)

# MIPS specific features - compiler tests suggested by Copilot AI (only the last 4 actually do anything meaningful)
if(CMAKE_SYSTEM_PROCESSOR MATCHES "mips.*|mips64.*")
	test_compiler_support("-mfpu=fp64" "int main(void){return 0;}" HAVE_MIPSFPU)
	test_compiler_support("-march=mips32r2" "int main(void){return 0;}" HAVE_MIPS32R2)
	test_compiler_support("-march=mips32r5" "int main(void){return 0;}" HAVE_MIPS32R5)
	test_compiler_support("-march=mips64r2" "int main(void){return 0;}" HAVE_MIPS64R2)
	test_compiler_support("-march=mips32r6" "int main(void){return 0;}" HAVE_MIPS32R6)
	test_compiler_support("-march=mips64r6" "int main(void){return 0;}" HAVE_MIPS64R6)
	test_compiler_support("-mdsp" "int main(void){return 0;}" HAVE_MIPSDSP)
	test_compiler_support("-mdspr2" "int main(void){return 0;}" HAVE_MIPSDSPR2)
	test_compiler_support("" "#include <msa.h>\nint main(void){v16i8 a = __builtin_msa_fill_b(1);return 0;}" HAVE_MSA)
	test_compiler_support("" "#include <loongson2.h>\nint main(void){__m64 x = __builtin_loongson_paddb(0, 0);return 0;}" HAVE_LOONGSON2)
	test_compiler_support("" "#include <loongson3a.h>\nint main(void){__m128i x = __builtin_loongson_vaddb(0, 0);return 0;}" HAVE_LOONGSON3)
	test_compiler_support("" "#include <mmi.h>\nint main(void){__mmi_d v = {0};return 0;}" HAVE_MMI)
endif()
# Note - we only want to run the above tests on mips; but we still want to assign a "1" or "0" value in config.h
assign_value(HAVE_MIPSFPU)
assign_value(HAVE_MIPS32R2)
assign_value(HAVE_MIPS32R5)
assign_value(HAVE_MIPS64R2)
assign_value(HAVE_MIPS32R6)
assign_value(HAVE_MIPS64R6)
assign_value(HAVE_MIPSDSP)
assign_value(HAVE_MIPSDSPR2)
assign_value(HAVE_MSA)
assign_value(HAVE_LOONGSON2)
assign_value(HAVE_LOONGSON3)
assign_value(HAVE_MMI)

# alignment checks--function written by Copilot AI
# Function to check alignment support for GCC/Clang and MSVC
function(check_alignment ALIGNMENT VAR_NAME)
    set(SOURCE_CODE "
        #include <stdio.h>
        #include <stdint.h>

        #if defined(_MSC_VER)
            __declspec(align(${ALIGNMENT})) struct AlignedStruct {
                char c;
            };
        #else
            struct __attribute__((aligned(${ALIGNMENT}))) AlignedStruct {
                char c;
            };
        #endif

        int main(void) {
            struct AlignedStruct s;
            // Ensure alignment is applied (compile-time check)
            if (((uintptr_t)&s) % ${ALIGNMENT} != 0) return 1;
            return 0;
        }
    ")
    check_c_source_compiles("${SOURCE_CODE}" ${VAR_NAME})
endfunction()

# Check for 8, 16, and 32-byte alignment
check_alignment(8  HAVE_LOCAL_ALIGNED_8)
check_alignment(16 HAVE_LOCAL_ALIGNED_16)
check_alignment(32 HAVE_LOCAL_ALIGNED_32)

# check for simd_align_16 the same was as ffmpeg's configure does
if(HAVE_NEON OR HAVE_SSE)
	set(HAVE_SIMD_ALIGN_16 1)
else()
	set(HAVE_SIMD_ALIGN_16 0)
endif()

# tests for symver_asm_label and gnu_asm suggested by Gemini AI
test_compiler_support("-fPIC" "void foo(void){}\n__asm__(\".symver foo, foo@VERS_1.1\");\nint main(void){return 0;}" HAVE_SYMVER_ASM_LABEL)
test_compiler_support("" "void foo(void){}\n__asm__(\".symver foo, foo@@VERS_1.0\");\nint main(void){return 0;}" HAVE_GNU_ASM)
if(HAVE_SYMVER_ASM_LABEL OR HAVE_GNU_ASM)
	set(HAVE_SYMVER 1)
else()
	set(HAVE_SYMVER 0)
endif()

# More tests--these came from ffmpeg's configure script EXCEPT missing header info for atomic_compare_exchange & sync_val_compare_and_swap which came from Google
check_symbol_exists(atomic_cas_ptr "atomic.h" HAVE_ATOMIC_CAS_PTR)
check_symbol_exists(atomic_compare_exchange_strong "stdatomic.h" HAVE_ATOMIC_COMPARE_EXCHANGE)
check_symbol_exists(__machine_rw_barrier "mbarrier.h" HAVE_MACHINE_RW_BARRIER)
check_symbol_exists(MemoryBarrier "windows.h" HAVE_MEMORYBARRIER)
check_symbol_exists(SA_RESTART "signal.h" HAVE_SARESTART)
check_symbol_exists(gmtime_r "time.h" HAVE_GMTIME_R)
check_symbol_exists(localtime_r "time.h" HAVE_LOCALTIME_R)
check_symbol_exists(__rdtsc "intrin.h" HAVE_RDTSC)
check_symbol_exists(_mm_empty "mmintrin.h" HAVE_MM_EMPTY)
# The following is unreliable with check_symbol_exists, so we have to attempt to compile a code snippet
test_compiler_support("" "#include <stdint.h>\nint main(){volatile int val = 0;\n__sync_val_compare_and_swap(&val, 0, 1);\n;return 0;}" HAVE_SYNC_VAL_COMPARE_AND_SWAP)

assign_value(HAVE_ATOMIC_CAS_PTR)
assign_value(HAVE_ATOMIC_COMPARE_EXCHANGE)
assign_value(HAVE_MACHINE_RW_BARRIER)
assign_value(HAVE_MEMORYBARRIER)
assign_value(HAVE_MM_EMPTY)
assign_value(HAVE_RDTSC)
assign_value(HAVE_SARESTART)
assign_value(HAVE_SYNC_VAL_COMPARE_AND_SWAP)
# Conditionals to apply the above tests' results per ffmpeg's configure conditionals under # threading support
if(HAVE_SYNC_VAL_COMPARE_AND_SWAP OR HAVE_ATOMIC_COMPARE_EXCHANGE)
	set(HAVE_ATOMICS_GCC 1)
else()
	set(HAVE_ATOMIC_GCC 0)
endif()
if(HAVE_ATOMIC_CAS_PTR OR HAVE_MACHINE_RW_BARRIER)
	set(HAVE_ATOMICS_SUNCC 1)
else()
	set(HAVE_ATOMICS_SUNCC 0)
endif()
if(HAVE_MEMORYBARRIER)
	set(HAVE_ATOMICS_WIN32 1)
else()
	set(HAVE_ATOMICS_WIN32 0)
endif()
if(HAVE_ATOMICS_GCC OR HAVE_ATOMICS_SUNCC OR HAVE_ATOMICS_WIN32)
	set(HAVE_ATOMICS_NATIVE 1)
else()
	set(HAVE_ATOMICS_NATIVE 0)
endif()

# Function checks - cabs and cexp
check_function_exists(cabs HAVE_CABS)
check_function_exists(cexp HAVE_CEXP)
assign_value(HAVE_CABS)
assign_value(HAVE_CEXP)

test_compiler_support("" "int main(void){int x = 0;\nasm(\"nop\");\nreturn x;}" HAVE_INLINE_ASM)
assign_value(HAVE_INLINE_ASM)

# find_program(YASM_EXECUTABLE yasm) was already set in CMakeLists.txt so we can use those results here
if(YASM_EXECUTABLE)	
	set(HAVE_YASM 1)
else()
	set(HAVE_YASM 0)
endif()

# Check for presence of various headers on system--list taken from ffmpeg's configure
foreach(header alsa_asoundlib_h altivec_h arpa_inet_h asm_types_h cdio_paranoia_h cdio_paranoia_paranoia_h dev_bktr_ioctl_bt848_h dev_bktr_ioctl_meteor_h dev_ic_bt8xx_h dev_video_bktr_ioctl_bt848_h dev_video_meteor_ioctl_meteor_h direct_h dirent_h dlfcn_h d3d11_h dxva_h ES2_gl_h gsm_h io_h mach_mach_time_h machine_ioctl_bt848_h machine_ioctl_meteor_h malloc_h opencv2_core_core_c_h openjpeg_2_1_openjpeg_h openjpeg_2_0_openjpeg_h openjpeg_1_5_openjpeg_h OpenGL_gl3_h poll_h sndio_h soundcard_h sys_mman_h sys_param_h sys_resource_h sys_select_h sys_soundcard_h sys_time_h sys_un_h sys_videoio_h termios_h udplite_h unistd_h valgrind_valgrind_h windows_h winsock2_h)
	# convert header item to proper header format
	string(REGEX REPLACE "_h" ".h" header_formatted ${header})
    # Create a RESULT_VAR, properly formatted
    string(TOUPPER "${header}" uppercase_header)
    set(RESULT_VAR "HAVE_${uppercase_header}")
    # Look for the header
    check_include_file(${header_formatted} ${RESULT_VAR})
    assign_value(${RESULT_VAR} PARENT_SCOPE) # Fix this: works fine if 'true', does nothing if 'false'
endforeach()

# Combined ffmpeg's configure math_func and system_funcs lists here since the check is the same
# Note: I removed gmtime_r & localtime_r from this list as they were already tested for above
foreach(math_func atanf atan2f cbrt cbrtf copysign cosf erf exp2 exp2f expf hypot isfinite isinf isnan ldexpf llrint llrintf log2 log2f log10f lrint lrintf powf rint round roundf sinf trunc truncf)
    # Create a RESULT_VAR, properly formatted
    string(TOUPPER "${math_func}" uppercase_math_func)
    set(RESULT_VAR "HAVE_${uppercase_math_func}")
    # Check whether the math type is defined
#    check_function_exists(${math_func} ${RESULT_VAR})
	check_type_size(${math_func} ${RESULT_VAR})
    assign_value(${RESULT_VAR} PARENT_SCOPE)
endforeach()

# To Do - don't copy and paste this function--it's sloppy coding.
foreach(system_func access aligned_malloc arc4random clock_gettime closesocket CommandLineToArgvW CoTaskMemFree CryptGenRandom dlopen fcntl flt_lim fork getaddrinfo gethrtime getopt GetProcessAffinityMask GetProcessMemoryInfo GetProcessTimes getrusage GetSystemTimeAsFileTime gettimeofday glob glXGetProcAddress inet_aton isatty jack_port_get_latency_range kbhit lstat lzo1x_999_compress mach_absolute_time MapViewOfFile memalign mkstemp mmap mprotect nanosleep PeekNamedPipe posix_memalign pthread_cancel sched_getaffinity SetConsoleTextAttribute SetConsoleCtrlHandler setmode setrlimit Sleep strerror_r sysconf sysctl usleep UTGetOSTypeFromString VirtualAlloc wglGetProcAddress)
    # Create a RESULT_VAR, properly formatted
    string(TOUPPER "${system_func}" uppercase_system_func)
    set(RESULT_VAR "HAVE_${uppercase_system_func}")
    # Check whether the math type is defined
    check_function_exists(${system_func} ${RESULT_VAR})
    assign_value(${RESULT_VAR} PARENT_SCOPE)
endforeach()

# Determine the type of Threads
if(CMAKE_USE_WIN32_THREADS_INIT)
	set(HAVE_W32THREADS 1)
else()
	set(HAVE_W32THREADS 0)
endif()
if(CMAKE_USE_PTHREADS_INIT)
	set(HAVE_PTHREADS 1)
else()
	set(HAVE_PTHREADS 0)
endif()
if(CMAKE_USE_OS2_THREADS_INIT)
	set(HAVE_OS2THREADS 1)
else()
	set(HAVE_OS2THREADS 0)
endif()

if(HAVE_PTHREADS OR HAVE_OS2THREADS OR HAVE_W32THREADS)
	set(HAVE_THREADS 1)
else()
	set(HAVE_THREADS 0)
endif()

# Toolchain features - Copilot suggested these test programs
test_compiler_support("" "int main(void){__asm__(\".dn 0, 0\");\n;return 0;}" HAVE_AS_DN_DIRECTIVE)
test_compiler_support("" "int main(void){__asm__(\".func myfunc\");\n;return 0;}" HAVE_AS_FUNC)
test_compiler_support("" "int main(void){__asm__(\".object_arch armv8-a\");\nreturn 0;}" HAVE_AS_OBJECT_ARCH)
test_compiler_support("" "int main(void){__asm__(\".mod.q\");\n;return 0;}" HAVE_ASM_MOD_Q)
test_compiler_support("" "struct __attribute__((may_alias)) A { int x; };\nint main() { struct A a; a.x = 1;\nreturn 0;}" HAVE_ATTRIBUTE_MAY_ALIAS)
test_compiler_support("" "struct __attribute__((packed)) B { char c; int i; };\nint main() { struct B b; b.c = 0; b.i = 1; return 0; }" HAVE_ATTRIBUTE_PACKED)
test_compiler_support("" "int main() {\nregister int r __asm__(\"ebp\");\nr = 0;\nreturn r; }" HAVE_EBP_AVAILABLE)
test_compiler_support("" "int main() {\nregister int r __asm__(\"ebx\");\nr = 0;\nreturn r; }" HAVE_EBX_AVAILABLE)
test_compiler_support("" "__asm__(\".section .text\");\nint main() { return 0; }" HAVE_GNU_AS)
test_compiler_support("" "__asm__(\".using mydata,12\");\nint main() { return 0; }" HAVE_IBM_ASM)
test_compiler_support("" "#include <stdio.h>\nint main(void){__asm__(\".globl mylabel\\nmylabel:\");\nreturn 0;}" HAVE_INLINE_ASM_DIRECT_SYMBOL_REFS)
test_compiler_support("" "#include <stdio.h>\nint main(void){__asm__(\"jmp 1f\\n1:\\n\");\nreturn 0;}" HAVE_INLINE_ASM_LABELS)
test_compiler_support("" "#include <stdio.h>\nint main(void){__asm__(\"jmp global_label\\n.global global_label\\nglobal_label:\");\nreturn 0;}" HAVE_INLINE_ASM_NONLOCAL_LABELS)
test_compiler_support("" "#include <stdio.h>\nint main(void){#pragma deprecated\nint x = 0;\nreturn 0;}" HAVE_PRAGMA_DEPRECATED)
test_compiler_support("" "#include <stdio.h>\nint main(void){#ifndef RSYNC_CONTIMEOUT\n#define RSYNC_CONTIMEOUT 30\n#endif\nreturn 0;}" HAVE_RSYNC_CONTIMEOUT)
test_compiler_support("" "#include <stdio.h>\nint main(void){__asm__(\".symver myfunc,myfunc@VER_1.0\"); void myfunc(void) {}\nreturn 0;}" HAVE_SYMVER_ASM_LABEL)
test_compiler_support("" "#include <stdio.h>\nint main(void){__asm__(\".symver myfunc,myfunc@@VER_1.0\"); void myfunc(void) {}\nreturn 0;}" HAVE_SYMVER_GNU_ASM)
test_compiler_support("" "#include <stdio.h>\nint main(void){__attribute__((pcs(\"aapcs-vfp\"))) void foo(void) {}\nreturn 0;}" HAVE_VFP_ARGS)
test_compiler_support("" "#include <stdio.h>\nint main(void){__asm__(\"add %0, %1, %2\" : \"=r\"( (int){0} ) : \"r\"(1), \"r\"(2));\nreturn 0;}" HAVE_XFORM_ASM)
test_compiler_support("" "#include <stdio.h>\nint main(void){__asm__(\"pxor %xmm0, %xmm0\" ::: \"xmm0\");\nreturn 0;}" HAVE_XMM_CLOBBERS)
assign_value(HAVE_AS_DN_DIRECTIVE)
assign_value(HAVE_AS_FUNC)
assign_value(HAVE_AS_OBJECT_ARCH)
assign_value(HAVE_ASM_MOD_Q)
assign_value(HAVE_ATTRIBUTE_MAY_ALIAS)
assign_value(HAVE_ATTRIBUTE_PACKED)
assign_value(HAVE_EBP_AVAILABLE)
assign_value(HAVE_EBX_AVAILABLE)
assign_value(HAVE_GNU_AS)
assign_value(HAVE_IBM_ASM)
assign_value(HAVE_INLINE_ASM_DIRECT_SYMBOL_REFS)
assign_value(HAVE_INLINE_ASM_LABELS)
assign_value(HAVE_INLINE_ASM_NONLOCAL_LABELS)
assign_value(HAVE_PRAGMA_DEPRECATED)
assign_value(HAVE_RSYNC_CONTIMEOUT)
assign_value(HAVE_SYMVER_ASM_LABEL)
assign_value(HAVE_SYMVER_GNU_ASM)
assign_value(HAVE_VFP_ARGS)
assign_value(HAVE_XFORM_ASM)
assign_value(HAVE_XMM_CLOBBERS)

# Types
check_type_size("CONDITION_VARIABLE_Ptr" HAVE_CONDITION_VARIABLE_PTR)
check_type_size("socklen_t" HAVE_SOCKLEN_T)
check_type_size("struct addrinfo" HAVE_STRUCT_ADDRINFO)
check_type_size("struct group_source_req" HAVE_STRUCT_GROUP_SOURCE_REQ)
check_type_size("struct ip_mreq_source" HAVE_STRUCT_IP_MREQ_SOURCE)
check_type_size("struct ipv6_mreq" HAVE_STRUCT_IPV6_MREQ)
check_type_size("struct pollfd" HAVE_STRUCT_POLLFD)
check_type_size("struct sctp_event_subscribe" HAVE_STRUCT_SCTP_EVENT_SUBSCRIBE)
check_type_size("struct sockaddr_in6" HAVE_STRUCT_SOCKADDR_IN6)
check_type_size("struct sockaddr_storage" HAVE_STRUCT_SOCKADDR_STORAGE)
check_type_size("struct v4l2_frmivalenum" HAVE_STRUCT_V4L2_FRMIVALENUM)
check_struct_has_member("struct rusage" ru_maxrss "sys/resource.h" HAVE_STRUCT_RUSAGE_RU_MAXRSS)
check_struct_has_member("struct sockaddr" sa_len "sys/socket.h" HAVE_STRUCT_SOCKADDR_SA_LEN)
check_struct_has_member("struct stat" st_mtim.tv_nsec "sys/stat.h" HAVE_STRUCT_STAT_ST_MTIM_TV_NSEC)
check_struct_has_member("struct v4l2_frmivalenum" discrete "linux/videodev2.h" HAVE_STRUCT_V4L2_FRMIVALENUM_DISCRETE)
assign_value(HAVE_CONDITION_VARIABLE_PTR)
assign_value(HAVE_SOCKLEN_T)
assign_value(HAVE_STRUCT_ADDRINFO)
assign_value(HAVE_STRUCT_GROUP_SOURCE_REQ)
assign_value(HAVE_STRUCT_IP_MREQ_SOURCE)
assign_value(HAVE_STRUCT_IPV6_MREQ)
assign_value(HAVE_STRUCT_POLLFD)
assign_value(HAVE_STRUCT_SCTP_EVENT_SUBSCRIBE)
assign_value(HAVE_STRUCT_SOCKADDR_IN6)
assign_value(HAVE_STRUCT_SOCKADDR_STORAGE)
assign_value(HAVE_STRUCT_V4L2_FRMIVALENUM)
assign_value(HAVE_STRUCT_RUSAGE_RU_MAXRSS)
assign_value(HAVE_STRUCT_SOCKADDR_SA_LEN)
assign_value(HAVE_STRUCT_STAT_ST_MTIM_TV_NSEC)
assign_value(HAVE_STRUCT_V4L2_FRMIVALENUM_DISCRETE)

# Deal with if(GNU_WINDRES) setting HAVE_GNU_WINDRES to "1")
if(GNU_WINDRES_FOUND)
	set(HAVE_GNU_WINDRES 1)
else()
	set(HAVE_GNU_WINDRES 0)
endif()

if(WIN32)
	set(HAVE_DOS_PATHS 1)
	check_library_exists(dxva2 DXVA2CreateVideoService "" HAVE_DXVA2_LIB)
	check_include_file(dxva2api.h HAVE_DXVA2API_COBJ)
else()
	set(HAVE_DOS_PATHS 0)
endif()

if(MSVC)
	set(HAVE_LIBC_MSVCRT 1)
else()
	set(HAVE_LIBC_MSVCRT 0)
endif()

# We don't need a FireWire camera library, GNU Texinfo tools, perl/pod2man, or SDL, so we'll hardcode all to "0"

test_compiler_support("" "__attribute__((section(\".data.rel.ro\"))) const int x = 42;\nint main() { return x; }" HAVE_SECTION_DATA_REL_RO)

if(WIN32 AND CMAKE_SYSTEM_NAME STREQUAL "WindowsStore")
    set(HAVE_WINRT 1)
else()
    set(HAVE_WINRT 0)
endif()

if(VAAPI_X11_FOUND) # Fix these 2: PkgConfig doesn't give me the variable I want so this returns false even when true
	set(HAVE_VAAPI_X11 1)
else()
	set(HAVE_VAAPI_X11 0)
endif()
if(VDPAU_X11_FOUND)
	set(HAVE_VDPAU_X11 1)
else()
	set(HAVE_VDPAU_X11 0)
endif()
if(X11_FOUND)
	set(HAVE_XLIB 1)
else()
	set(HAVE_XLIB 0)
endif()

assign_value(HAVE_DXVA2_LIB)
assign_value(HAVE_DXVA2API_COBJ)
assign_value(HAVE_SECTION_DATA_REL_RO)

if(HAVE_DXVA2_LIB OR HAVE_VAAPI_X11 OR HAVE_VDPAU_X11)
	set(CONFIG_HWACCELS 1)
else()
	set(CONFIG_HWACCELS 0)
endif()

if(ZLIB_FOUND)
	set(HAVE_ZLIB 1)
else()
	set(HAVE_ZLIB 0)
endif()

file(CONFIGURE
	OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/config.h"
	CONTENT
"/* Generated by cmake courtesy of kreinholz's hacks */
#ifndef FFMPEG_CONFIG_H
#define FFMPEG_CONFIG_H
#define FFMPEG_CONFIGURATION \"this is where configuration options are normally listed, although technically we don't need them and ffmpeg builds just fine in a pure cmake environment without them\"
#define FFMPEG_LICENSE \"GPL version 2 or later\"
#define CONFIG_THIS_YEAR 2016
#define FFMPEG_DATADIR ${CMAKE_CURRENT_BINARY_DIR}
#define AVCONV_DATADIR ${CMAKE_CURRENT_BINARY_DIR}
#define CC_IDENT \"${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION}\"
#define av_restrict ${_RESTRICT}
#define EXTERN_PREFIX ${extern_prefix}
#define EXTERN_ASM ${extern_asm}
#define BUILDSUF ${build_suffix}
#define SLIBSUF ${SLIBSUF}
#define HAVE_MMX2 HAVE_MMXEXT
#define SWS_MAX_FILTER_SIZE ${sws_max_filter_size}
#define ARCH_AARCH64 ${ARCH_AARCH64}
#define ARCH_ALPHA 0
#define ARCH_ARM ${ARCH_ARM}
#define ARCH_AVR32 0
#define ARCH_AVR32_AP 0
#define ARCH_AVR32_UC 0
#define ARCH_BFIN 0
#define ARCH_IA64 0
#define ARCH_M68K 0
#define ARCH_MIPS ${ARCH_MIPS}
#define ARCH_MIPS64 ${ARCH_MIPS64}
#define ARCH_PARISC 0
#define ARCH_PPC 0
#define ARCH_PPC64 0
#define ARCH_S390 0
#define ARCH_SH4 0
#define ARCH_SPARC 0
#define ARCH_SPARC64 0
#define ARCH_TILEGX 0
#define ARCH_TILEPRO 0
#define ARCH_TOMI 0
#define ARCH_X86 ${ARCH_X86}
#define ARCH_X86_32 ${ARCH_X86}
#define ARCH_X86_64 ${ARCH_X86_64}
#define HAVE_ARMV5TE 0
#define HAVE_ARMV6 ${HAVE_ARMV6}
#define HAVE_ARMV6T2 ${HAVE_ARMV6T2}
#define HAVE_ARMV8 ${ARCH_AARCH64}
#define HAVE_NEON ${HAVE_NEON}
#define HAVE_VFP ${HAVE_VFP}
#define HAVE_VFPV3 ${HAVE_VFPV3}
#define HAVE_SETEND ${HAVE_SETEND}
#define HAVE_ALTIVEC 0
#define HAVE_DCBZL 0
#define HAVE_LDBRX 0
#define HAVE_POWER8 0
#define HAVE_PPC4XX 0
#define HAVE_VSX 0
#define HAVE_AESNI ${HAVE_AESNI}
#define HAVE_AMD3DNOW ${HAVE_AMD3DNOW}
#define HAVE_AMD3DNOWEXT ${HAVE_AMD3DNOWEXT}
#define HAVE_AVX ${HAVE_AVX}
#define HAVE_AVX2 ${HAVE_AVX2}
#define HAVE_FMA3 ${HAVE_FMA3}
#define HAVE_FMA4 ${HAVE_FMA4}
#define HAVE_MMX ${HAVE_MMX}
#define HAVE_MMXEXT ${HAVE_MMXEXT}
#define HAVE_SSE ${HAVE_SSE}
#define HAVE_SSE2 ${HAVE_SSE2}
#define HAVE_SSE3 ${HAVE_SSE3}
#define HAVE_SSE4 ${HAVE_SSE4}
#define HAVE_SSE42 ${HAVE_SSE42}
#define HAVE_SSSE3 ${HAVE_SSSE3}
#define HAVE_XOP ${HAVE_XOP}
#define HAVE_CPUNOP ${HAVE_CPUNOP}
#define HAVE_I686 ${ARCH_X86_64}
#define HAVE_MIPSFPU ${HAVE_MIPSFPU}
#define HAVE_MIPS32R2 ${HAVE_MIPS32R2}
#define HAVE_MIPS32R5 ${HAVE_MIPS32R5}
#define HAVE_MIPS64R2 ${HAVE_MIPS64R2}
#define HAVE_MIPS32R6 ${HAVE_MIPS32R6}
#define HAVE_MIPS64R6 ${HAVE_MIPS64R6}
#define HAVE_MIPSDSP ${HAVE_MIPSDSP}
#define HAVE_MIPSDSPR2 ${HAVE_MIPSDSPR2}
#define HAVE_MSA ${HAVE_MSA}
#define HAVE_LOONGSON2 ${HAVE_LOONGSON2}
#define HAVE_LOONGSON3 ${HAVE_LOONGSON3}
#define HAVE_MMI ${HAVE_MMI}
#define HAVE_ARMV5TE_EXTERNAL 0
#define HAVE_ARMV6_EXTERNAL ${HAVE_ARMV6}
#define HAVE_ARMV6T2_EXTERNAL ${HAVE_ARMV6T2}
#define HAVE_ARMV8_EXTERNAL ${ARCH_AARCH64}
#define HAVE_NEON_EXTERNAL ${HAVE_NEON}
#define HAVE_VFP_EXTERNAL ${HAVE_VFP}
#define HAVE_VFPV3_EXTERNAL ${HAVE_VFPV3}
#define HAVE_SETEND_EXTERNAL ${HAVE_SETEND}
#define HAVE_ALTIVEC_EXTERNAL 0
#define HAVE_DCBZL_EXTERNAL 0
#define HAVE_LDBRX_EXTERNAL 0
#define HAVE_POWER8_EXTERNAL 0
#define HAVE_PPC4XX_EXTERNAL 0
#define HAVE_VSX_EXTERNAL 0
#define HAVE_AESNI_EXTERNAL ${HAVE_AESNI}
#define HAVE_AMD3DNOW_EXTERNAL ${HAVE_AMD3DNOW}
#define HAVE_AMD3DNOWEXT_EXTERNAL ${HAVE_AMD3DNOWEXT}
#define HAVE_AVX_EXTERNAL ${HAVE_AVX}
#define HAVE_AVX2_EXTERNAL ${HAVE_AVX2}
#define HAVE_FMA3_EXTERNAL ${HAVE_FMA3}
#define HAVE_FMA4_EXTERNAL ${HAVE_FMA4}
#define HAVE_MMX_EXTERNAL ${HAVE_MMX}
#define HAVE_MMXEXT_EXTERNAL ${HAVE_MMXEXT}
#define HAVE_SSE_EXTERNAL ${HAVE_SSE}
#define HAVE_SSE2_EXTERNAL ${HAVE_SSE2}
#define HAVE_SSE3_EXTERNAL ${HAVE_SSE3}
#define HAVE_SSE4_EXTERNAL ${HAVE_SSE4}
#define HAVE_SSE42_EXTERNAL ${HAVE_SSE42}
#define HAVE_SSSE3_EXTERNAL ${HAVE_SSSE3}
#define HAVE_XOP_EXTERNAL ${HAVE_XOP}
#define HAVE_CPUNOP_EXTERNAL ${HAVE_CPUNOP}
#define HAVE_I686_EXTERNAL ${ARCH_X86_64}
#define HAVE_MIPSFPU_EXTERNAL ${HAVE_MIPSFPU}
#define HAVE_MIPS32R2_EXTERNAL ${HAVE_MIPS32R2}
#define HAVE_MIPS32R5_EXTERNAL ${HAVE_MIPS32R5}
#define HAVE_MIPS64R2_EXTERNAL ${HAVE_MIPS64R2}
#define HAVE_MIPS32R6_EXTERNAL ${HAVE_MIPS32R6}
#define HAVE_MIPS64R6_EXTERNAL ${HAVE_MIPS64R6}
#define HAVE_MIPSDSP_EXTERNAL ${HAVE_MIPSDSP}
#define HAVE_MIPSDSPR2_EXTERNAL ${HAVE_MIPSDSPR2}
#define HAVE_MSA_EXTERNAL ${HAVE_MSA}
#define HAVE_LOONGSON2_EXTERNAL ${HAVE_LOONGSON2}
#define HAVE_LOONGSON3_EXTERNAL ${HAVE_LOONGSON3}
#define HAVE_MMI_EXTERNAL ${HAVE_MMI}
#define HAVE_ARMV5TE_INLINE 0
#define HAVE_ARMV6_INLINE ${HAVE_ARMV6}
#define HAVE_ARMV6T2_INLINE ${HAVE_ARMV6T2}
#define HAVE_ARMV8_INLINE ${ARCH_AARCH64}
#define HAVE_NEON_INLINE ${HAVE_NEON}
#define HAVE_VFP_INLINE ${HAVE_VFP}
#define HAVE_VFPV3_INLINE ${HAVE_VFPV3}
#define HAVE_SETEND_INLINE ${HAVE_SETEND}
#define HAVE_ALTIVEC_INLINE 0
#define HAVE_DCBZL_INLINE 0
#define HAVE_LDBRX_INLINE 0
#define HAVE_POWER8_INLINE 0
#define HAVE_PPC4XX_INLINE 0
#define HAVE_VSX_INLINE 0
#define HAVE_AESNI_INLINE ${HAVE_AESNI}
#define HAVE_AMD3DNOW_INLINE ${HAVE_AMD3DNOW}
#define HAVE_AMD3DNOWEXT_INLINE ${HAVE_AMD3DNOWEXT}
#define HAVE_AVX_INLINE ${HAVE_AVX}
#define HAVE_AVX2_INLINE ${HAVE_AVX2}
#define HAVE_FMA3_INLINE ${HAVE_FMA3}
#define HAVE_FMA4_INLINE ${HAVE_FMA4}
#define HAVE_MMX_INLINE ${HAVE_MMX}
#define HAVE_MMXEXT_INLINE ${HAVE_MMXEXT}
#define HAVE_SSE_INLINE ${HAVE_SSE}
#define HAVE_SSE2_INLINE ${HAVE_SSE2}
#define HAVE_SSE3_INLINE ${HAVE_SSE3}
#define HAVE_SSE4_INLINE ${HAVE_SSE4}
#define HAVE_SSE42_INLINE ${HAVE_SSE42}
#define HAVE_SSSE3_INLINE ${HAVE_SSSE3}
#define HAVE_XOP_INLINE ${HAVE_XOP}
#define HAVE_CPUNOP_INLINE ${HAVE_CPUNOP}
#define HAVE_I686_INLINE ${ARCH_X86_64}
#define HAVE_MIPSFPU_INLINE ${HAVE_MIPSFPU}
#define HAVE_MIPS32R2_INLINE ${HAVE_MIPS32R2}
#define HAVE_MIPS32R5_INLINE ${HAVE_MIPS32R5}
#define HAVE_MIPS64R2_INLINE ${HAVE_MIPS64R2}
#define HAVE_MIPS32R6_INLINE ${HAVE_MIPS32R6}
#define HAVE_MIPS64R6_INLINE ${HAVE_MIPS64R6}
#define HAVE_MIPSDSP_INLINE ${HAVE_MIPSDSP}
#define HAVE_MIPSDSPR2_INLINE ${HAVE_MIPSDSPR2}
#define HAVE_MSA_INLINE ${HAVE_MSA}
#define HAVE_LOONGSON2_INLINE ${HAVE_LOONGSON2}
#define HAVE_LOONGSON3_INLINE ${HAVE_LOONGSON3}
#define HAVE_MMI_INLINE ${HAVE_MMI}
#define HAVE_ALIGNED_STACK ${ALIGNED_STACK}
#define HAVE_FAST_64BIT ${HAVE_FAST_64BIT}
#define HAVE_FAST_CLZ 1
#define HAVE_FAST_CMOV ${HAVE_FAST_CMOV}
#define HAVE_LOCAL_ALIGNED_8 ${HAVE_LOCAL_ALIGNED_8}
#define HAVE_LOCAL_ALIGNED_16 ${HAVE_LOCAL_ALIGNED_16}
#define HAVE_LOCAL_ALIGNED_32 ${HAVE_LOCAL_ALIGNED_32}
#define HAVE_SIMD_ALIGN_16 ${HAVE_SIMD_ALIGN_16}
#define HAVE_ATOMICS_GCC ${HAVE_ATOMICS_GCC}
#define HAVE_ATOMICS_SUNCC ${HAVE_ATOMICS_SUNCC}
#define HAVE_ATOMICS_WIN32 ${HAVE_ATOMICS_WIN32}
#define HAVE_ATOMIC_CAS_PTR ${HAVE_ATOMIC_CAS_PTR}
#define HAVE_ATOMIC_COMPARE_EXCHANGE ${HAVE_ATOMIC_COMPARE_EXCHANGE}
#define HAVE_MACHINE_RW_BARRIER ${HAVE_MACHINE_RW_BARRIER}
#define HAVE_MEMORYBARRIER ${HAVE_MEMORYBARRIER}
#define HAVE_MM_EMPTY ${HAVE_MM_EMPTY}
#define HAVE_RDTSC ${HAVE_RDTSC}
#define HAVE_SARESTART ${HAVE_SARESTART}
#define HAVE_SYNC_VAL_COMPARE_AND_SWAP ${HAVE_SYNC_VAL_COMPARE_AND_SWAP}
#define HAVE_CABS ${HAVE_CABS}
#define HAVE_CEXP ${HAVE_CEXP}
#define HAVE_INLINE_ASM ${HAVE_INLINE_ASM}
#define HAVE_SYMVER ${HAVE_SYMVER}
#define HAVE_YASM ${HAVE_YASM}
#define HAVE_BIGENDIAN 0
#define HAVE_FAST_UNALIGNED ${FAST_UNALIGNED}
#define HAVE_INCOMPATIBLE_LIBAV_ABI 0
#define HAVE_ALSA_ASOUNDLIB_H ${HAVE_ALSA_ASOUNDLIB_H}
#define HAVE_ALTIVEC_H ${HAVE_ALTIVEC_H}
#define HAVE_ARPA_INET_H ${HAVE_ARPA_INET_H}
#define HAVE_ASM_TYPES_H ${HAVE_ASM_TYPES_H}
#define HAVE_CDIO_PARANOIA_H ${HAVE_CDIO_PARANOIA_H}
#define HAVE_CDIO_PARANOIA_PARANOIA_H ${HAVE_CDIO_PARANOIA_PARANOIA_H}
#define HAVE_DEV_BKTR_IOCTL_BT848_H ${HAVE_DEV_BKTR_IOCTL_BT848_H}
#define HAVE_DEV_BKTR_IOCTL_METEOR_H ${HAVE_DEV_BKTR_IOCTL_METEOR_H}
#define HAVE_DEV_IC_BT8XX_H ${HAVE_DEV_IC_BT8XX_H}
#define HAVE_DEV_VIDEO_BKTR_IOCTL_BT848_H ${HAVE_DEV_VIDEO_BKTR_IOCTL_BT848_H}
#define HAVE_DEV_VIDEO_METEOR_IOCTL_METEOR_H ${HAVE_DEV_VIDEO_METEOR_IOCTL_METEOR_H}
#define HAVE_DIRECT_H ${HAVE_DIRECT_H}
#define HAVE_DIRENT_H ${HAVE_DIRENT_H}
#define HAVE_DLFCN_H ${HAVE_DLFCN_H}
#define HAVE_D3D11_H ${HAVE_D3D11_H}
#define HAVE_DXVA_H ${HAVE_DXVA_H}
#define HAVE_ES2_GL_H ${HAVE_ES2_GL_H}
#define HAVE_GSM_H ${HAVE_GSM_H}
#define HAVE_IO_H ${HAVE_IO_H}
#define HAVE_MACH_MACH_TIME_H ${HAVE_MACH_MACH_TIME_H}
#define HAVE_MACHINE_IOCTL_BT848_H ${HAVE_MACHINE_IOCTL_BT848_H}
#define HAVE_MACHINE_IOCTL_METEOR_H ${HAVE_MACHINE_IOCTL_METEOR_H}
#define HAVE_MALLOC_H ${HAVE_MALLOC_H}
#define HAVE_OPENCV2_CORE_CORE_C_H ${HAVE_OPENCV2_CORE_CORE_C_H}
#define HAVE_OPENJPEG_2_1_OPENJPEG_H ${HAVE_OPENJPEG_2_1_OPENJPEG_H}
#define HAVE_OPENJPEG_2_0_OPENJPEG_H ${HAVE_OPENJPEG_2_0_OPENJPEG_H}
#define HAVE_OPENJPEG_1_5_OPENJPEG_H ${HAVE_OPENJPEG_1_5_OPENJPEG_H}
#define HAVE_OPENGL_GL3_H ${HAVE_OPENGL_GL3_H}
#define HAVE_POLL_H ${HAVE_POLL_H}
#define HAVE_SNDIO_H ${HAVE_SNDIO_H}
#define HAVE_SOUNDCARD_H ${HAVE_SOUNDCARD_H}
#define HAVE_SYS_MMAN_H ${HAVE_SYS_MMAN_H}
#define HAVE_SYS_PARAM_H ${HAVE_SYS_PARAM_H}
#define HAVE_SYS_RESOURCE_H ${HAVE_SYS_RESOURCE_H}
#define HAVE_SYS_SELECT_H ${HAVE_SYS_SELECT_H}
#define HAVE_SYS_SOUNDCARD_H ${HAVE_SYS_SOUNDCARD_H}
#define HAVE_SYS_TIME_H ${HAVE_SYS_TIME_H}
#define HAVE_SYS_UN_H ${HAVE_SYS_UN_H}
#define HAVE_SYS_VIDEOIO_H ${HAVE_SYS_VIDEOIO_H}
#define HAVE_TERMIOS_H ${HAVE_TERMIOS_H}
#define HAVE_UDPLITE_H ${HAVE_UDPLITE_H}
#define HAVE_UNISTD_H ${HAVE_UNISTD_H}
#define HAVE_VALGRIND_VALGRIND_H ${HAVE_VALGRIND_VALGRIND_H}
#define HAVE_WINDOWS_H ${HAVE_WINDOWS_H}
#define HAVE_WINSOCK2_H ${HAVE_WINSOCK2_H}
#define HAVE_INTRINSICS_NEON ${HAVE_NEON}
#define HAVE_ATANF ${HAVE_ATANF}
#define HAVE_ATAN2F ${HAVE_ATAN2F}
#define HAVE_CBRT ${HAVE_CBRT}
#define HAVE_CBRTF ${HAVE_CBRTF}
#define HAVE_COPYSIGN ${HAVE_COPYSIGN}
#define HAVE_COSF ${HAVE_COSF}
#define HAVE_ERF ${HAVE_ERF}
#define HAVE_EXP2 ${HAVE_EXP2}
#define HAVE_EXP2F ${HAVE_EXP2F}
#define HAVE_EXPF ${HAVE_EXPF}
#define HAVE_HYPOT ${HAVE_HYPOT}
#define HAVE_ISFINITE ${HAVE_ISFINITE}
#define HAVE_ISINF ${HAVE_ISINF}
#define HAVE_ISNAN ${HAVE_ISNAN}
#define HAVE_LDEXPF ${HAVE_LDEXPF}
#define HAVE_LLRINT ${HAVE_LLRINT}
#define HAVE_LLRINTF ${HAVE_LLRINTF}
#define HAVE_LOG2 ${HAVE_LOG2}
#define HAVE_LOG2F ${HAVE_LOG2F}
#define HAVE_LOG10F ${HAVE_LOG10F}
#define HAVE_LRINT ${HAVE_LRINT}
#define HAVE_LRINTF ${HAVE_LRINTF}
#define HAVE_POWF ${HAVE_POWF}
#define HAVE_RINT ${HAVE_RINT}
#define HAVE_ROUND ${HAVE_ROUND}
#define HAVE_ROUNDF ${HAVE_ROUNDF}
#define HAVE_SINF ${HAVE_SINF}
#define HAVE_TRUNC ${HAVE_TRUNC}
#define HAVE_TRUNCF ${HAVE_TRUNCF}
#define HAVE_ACCESS ${HAVE_ACCESS}
#define HAVE_ALIGNED_MALLOC ${HAVE_ALIGNED_MALLOC}
#define HAVE_ARC4RANDOM ${HAVE_ARC4RANDOM}
#define HAVE_CLOCK_GETTIME ${HAVE_CLOCK_GETTIME}
#define HAVE_CLOSESOCKET ${HAVE_CLOSESOCKET}
#define HAVE_COMMANDLINETOARGVW ${HAVE_COMMANDLINETOARGVW}
#define HAVE_COTASKMEMFREE ${HAVE_COTASKMEMFREE}
#define HAVE_CRYPTGENRANDOM ${HAVE_CRYPTGENRANDOM}
#define HAVE_DLOPEN ${HAVE_DLOPEN}
#define HAVE_FCNTL ${HAVE_FCNTL}
#define HAVE_FLT_LIM ${HAVE_FLT_LIM}
#define HAVE_FORK ${HAVE_FORK}
#define HAVE_GETADDRINFO ${HAVE_GETADDRINFO}
#define HAVE_GETHRTIME ${HAVE_GETHRTIME}
#define HAVE_GETOPT ${HAVE_GETOPT}
#define HAVE_GETPROCESSAFFINITYMASK ${HAVE_GETPROCESSAFFINITYMASK}
#define HAVE_GETPROCESSMEMORYINFO ${HAVE_GETPROCESSMEMORYINFO}
#define HAVE_GETPROCESSTIMES ${HAVE_GETPROCESSTIMES}
#define HAVE_GETRUSAGE ${HAVE_GETRUSAGE}
#define HAVE_GETSYSTEMTIMEASFILETIME ${HAVE_GETSYSTEMTIMEASFILETIME}
#define HAVE_GETTIMEOFDAY ${HAVE_GETTIMEOFDAY}
#define HAVE_GLOB ${HAVE_GLOB}
#define HAVE_GLXGETPROCADDRESS ${HAVE_GLXGETPROCADDRESS}
#define HAVE_GMTIME_R ${HAVE_GMTIME_R}
#define HAVE_INET_ATON ${HAVE_INET_ATON}
#define HAVE_ISATTY ${HAVE_ISATTY}
#define HAVE_JACK_PORT_GET_LATENCY_RANGE ${HAVE_JACK_PORT_GET_LATENCY_RANGE}
#define HAVE_KBHIT ${HAVE_KBHIT}
#define HAVE_LOCALTIME_R ${HAVE_LOCALTIME_R}
#define HAVE_LSTAT ${HAVE_LSTAT}
#define HAVE_LZO1X_999_COMPRESS ${HAVE_LZO1X_999_COMPRESS}
#define HAVE_MACH_ABSOLUTE_TIME ${HAVE_MACH_ABSOLUTE_TIME}
#define HAVE_MAPVIEWOFFILE ${HAVE_MAPVIEWOFFILE}
#define HAVE_MEMALIGN ${HAVE_MEMALIGN}
#define HAVE_MKSTEMP ${HAVE_MKSTEMP}
#define HAVE_MMAP ${HAVE_MMAP}
#define HAVE_MPROTECT ${HAVE_MPROTECT}
#define HAVE_NANOSLEEP ${HAVE_NANOSLEEP}
#define HAVE_PEEKNAMEDPIPE ${HAVE_PEEKNAMEDPIPE}
#define HAVE_POSIX_MEMALIGN ${HAVE_POSIX_MEMALIGN}
#define HAVE_PTHREAD_CANCEL ${HAVE_PTHREAD_CANCEL}
#define HAVE_SCHED_GETAFFINITY ${HAVE_SCHED_GETAFFINITY}
#define HAVE_SETCONSOLETEXTATTRIBUTE ${HAVE_SETCONSOLETEXTATTRIBUTE}
#define HAVE_SETCONSOLECTRLHANDLER ${HAVE_SETCONSOLECTRLHANDLER}
#define HAVE_SETMODE ${HAVE_SETMODE}
#define HAVE_SETRLIMIT ${HAVE_SETRLIMIT}
#define HAVE_SLEEP ${HAVE_SLEEP}
#define HAVE_STRERROR_R ${HAVE_STRERROR_R}
#define HAVE_SYSCONF ${HAVE_SYSCONF}
#define HAVE_SYSCTL ${HAVE_SYSCTL}
#define HAVE_USLEEP ${HAVE_USLEEP}
#define HAVE_UTGETOSTYPEFROMSTRING ${HAVE_UTGETOSTYPEFROMSTRING}
#define HAVE_VIRTUALALLOC ${HAVE_VIRTUALALLOC}
#define HAVE_WGLGETPROCADDRESS ${HAVE_WGLGETPROCADDRESS}
#define HAVE_PTHREADS ${HAVE_PTHREADS}
#define HAVE_OS2THREADS ${HAVE_OS2THREADS}
#define HAVE_W32THREADS ${HAVE_W32THREADS}
#define HAVE_AS_DN_DIRECTIVE ${HAVE_AS_DN_DIRECTIVE}
#define HAVE_AS_FUNC ${HAVE_AS_FUNC}
#define HAVE_AS_OBJECT_ARCH ${HAVE_AS_OBJECT_ARCH}
#define HAVE_ASM_MOD_Q ${HAVE_ASM_MOD_Q}
#define HAVE_ATTRIBUTE_MAY_ALIAS ${HAVE_ATTRIBUTE_MAY_ALIAS}
#define HAVE_ATTRIBUTE_PACKED ${HAVE_ATTRIBUTE_PACKED}
#define HAVE_EBP_AVAILABLE ${HAVE_EBP_AVAILABLE}
#define HAVE_EBX_AVAILABLE ${HAVE_EBX_AVAILABLE}
#define HAVE_GNU_AS ${HAVE_GNU_AS}
#define HAVE_GNU_WINDRES ${HAVE_GNU_WINDRES}
#define HAVE_IBM_ASM ${HAVE_IBM_ASM}
#define HAVE_INLINE_ASM_DIRECT_SYMBOL_REFS ${HAVE_INLINE_ASM_DIRECT_SYMBOL_REFS}
#define HAVE_INLINE_ASM_LABELS ${HAVE_INLINE_ASM_LABELS}
#define HAVE_INLINE_ASM_NONLOCAL_LABELS ${HAVE_INLINE_ASM_NONLOCAL_LABELS}
#define HAVE_PRAGMA_DEPRECATED ${HAVE_PRAGMA_DEPRECATED}
#define HAVE_RSYNC_CONTIMEOUT ${HAVE_RSYNC_CONTIMEOUT}
#define HAVE_SYMVER_ASM_LABEL ${HAVE_SYMVER_ASM_LABEL}
#define HAVE_SYMVER_GNU_ASM ${HAVE_SYMVER_GNU_ASM}
#define HAVE_VFP_ARGS ${HAVE_VFP_ARGS}
#define HAVE_XFORM_ASM ${HAVE_XFORM_ASM}
#define HAVE_XMM_CLOBBERS ${HAVE_XMM_CLOBBERS}
#define HAVE_CONDITION_VARIABLE_PTR ${HAVE_CONDITION_VARIABLE_PTR}
#define HAVE_SOCKLEN_T ${HAVE_SOCKLEN_T}
#define HAVE_STRUCT_ADDRINFO ${HAVE_STRUCT_ADDRINFO}
#define HAVE_STRUCT_GROUP_SOURCE_REQ ${HAVE_STRUCT_GROUP_SOURCE_REQ}
#define HAVE_STRUCT_IP_MREQ_SOURCE ${HAVE_STRUCT_IP_MREQ_SOURCE}
#define HAVE_STRUCT_IPV6_MREQ ${HAVE_STRUCT_IPV6_MREQ}
#define HAVE_STRUCT_POLLFD ${HAVE_STRUCT_POLLFD}
#define HAVE_STRUCT_RUSAGE_RU_MAXRSS ${HAVE_STRUCT_RUSAGE_RU_MAXRSS}
#define HAVE_STRUCT_SCTP_EVENT_SUBSCRIBE ${HAVE_STRUCT_SCTP_EVENT_SUBSCRIBE}
#define HAVE_STRUCT_SOCKADDR_IN6 ${HAVE_STRUCT_SOCKADDR_IN6}
#define HAVE_STRUCT_SOCKADDR_SA_LEN ${HAVE_STRUCT_SOCKADDR_SA_LEN}
#define HAVE_STRUCT_SOCKADDR_STORAGE ${HAVE_STRUCT_SOCKADDR_STORAGE}
#define HAVE_STRUCT_STAT_ST_MTIM_TV_NSEC ${HAVE_STRUCT_STAT_ST_MTIM_TV_NSEC}
#define HAVE_STRUCT_V4L2_FRMIVALENUM_DISCRETE ${HAVE_STRUCT_V4L2_FRMIVALENUM_DISCRETE}
#define HAVE_ATOMICS_NATIVE ${HAVE_ATOMICS_NATIVE}
#define HAVE_DOS_PATHS ${HAVE_DOS_PATHS}
#define HAVE_DXVA2_LIB ${HAVE_DXVA2_LIB}
#define HAVE_DXVA2API_COBJ ${HAVE_DXVA2API_COBJ}
#define HAVE_LIBC_MSVCRT ${HAVE_LIBC_MSVCRT}
#define HAVE_LIBDC1394_1 0
#define HAVE_LIBDC1394_2 0
#define HAVE_MAKEINFO 0
#define HAVE_MAKEINFO_HTML 0
#define HAVE_PERL 0
#define HAVE_POD2MAN 0
#define HAVE_SDL 0
#define HAVE_SECTION_DATA_REL_RO ${HAVE_SECTION_DATA_REL_RO}
#define HAVE_TEXI2HTML 0
#define HAVE_THREADS ${HAVE_THREADS}
#define HAVE_VAAPI_X11 ${HAVE_VAAPI_X11}
#define HAVE_VDPAU_X11 ${HAVE_VDPAU_X11}
#define HAVE_WINRT ${HAVE_WINRT}
#define HAVE_XLIB ${HAVE_XLIB}
#define CONFIG_BSFS 0
#define CONFIG_DECODERS 1
#define CONFIG_ENCODERS 1
#define CONFIG_HWACCELS ${CONFIG_HWACCELS}
#define CONFIG_PARSERS 1
#define CONFIG_INDEVS 0
#define CONFIG_OUTDEVS 0
#define CONFIG_FILTERS 0
#define CONFIG_DEMUXERS 1
#define CONFIG_MUXERS 1
#define CONFIG_PROTOCOLS 1
#define CONFIG_DOC 0
#define CONFIG_HTMLPAGES 0
#define CONFIG_MANPAGES 0
#define CONFIG_PODPAGES 0
#define CONFIG_TXTPAGES 0
#define CONFIG_AVIO_READING_EXAMPLE 0
#define CONFIG_AVIO_DIR_CMD_EXAMPLE 0
#define CONFIG_DECODING_ENCODING_EXAMPLE 0
#define CONFIG_DEMUXING_DECODING_EXAMPLE 0
#define CONFIG_EXTRACT_MVS_EXAMPLE 0
#define CONFIG_FILTER_AUDIO_EXAMPLE 0
#define CONFIG_FILTERING_AUDIO_EXAMPLE 0
#define CONFIG_FILTERING_VIDEO_EXAMPLE 0
#define CONFIG_METADATA_EXAMPLE 0
#define CONFIG_MUXING_EXAMPLE 0
#define CONFIG_QSVDEC_EXAMPLE 0
#define CONFIG_REMUXING_EXAMPLE 0
#define CONFIG_RESAMPLING_AUDIO_EXAMPLE 0
#define CONFIG_SCALING_VIDEO_EXAMPLE 0
#define CONFIG_TRANSCODE_AAC_EXAMPLE 0
#define CONFIG_TRANSCODING_EXAMPLE 0
#define CONFIG_AVISYNTH 0
#define CONFIG_BZLIB 0
#define CONFIG_CHROMAPRINT 0
#define CONFIG_CRYSTALHD 0
#define CONFIG_DECKLINK 0
#define CONFIG_FREI0R 0
#define CONFIG_GCRYPT 0
#define CONFIG_GMP 0
#define CONFIG_GNUTLS 0
#define CONFIG_ICONV 0
#define CONFIG_LADSPA 0
#define CONFIG_LIBASS 0
#define CONFIG_LIBBLURAY 0
#define CONFIG_LIBBS2B 0
#define CONFIG_LIBCACA 0
#define CONFIG_LIBCDIO 0
#define CONFIG_LIBCELT 0
#define CONFIG_LIBDC1394 0
#define CONFIG_LIBDCADEC 0
#define CONFIG_LIBFAAC 0
#define CONFIG_LIBFDK_AAC 0
#define CONFIG_LIBFLITE 0
#define CONFIG_LIBFONTCONFIG 0
#define CONFIG_LIBFREETYPE 0
#define CONFIG_LIBFRIBIDI 0
#define CONFIG_LIBGME 0
#define CONFIG_LIBGSM 0
#define CONFIG_LIBIEC61883 0
#define CONFIG_LIBILBC 0
#define CONFIG_LIBKVAZAAR 0
#define CONFIG_LIBMFX 0
#define CONFIG_LIBMODPLUG 0
#define CONFIG_LIBMP3LAME 0
#define CONFIG_LIBNUT 0
#define CONFIG_LIBOPENCORE_AMRNB 0
#define CONFIG_LIBOPENCORE_AMRWB 0
#define CONFIG_LIBOPENCV 0
#define CONFIG_LIBOPENH264 0
#define CONFIG_LIBOPENJPEG 0
#define CONFIG_LIBOPUS 0
#define CONFIG_LIBPULSE 0
#define CONFIG_LIBRTMP 0
#define CONFIG_LIBRUBBERBAND 0
#define CONFIG_LIBSCHROEDINGER 0
#define CONFIG_LIBSHINE 0
#define CONFIG_LIBSMBCLIENT 0
#define CONFIG_LIBSNAPPY 0
#define CONFIG_LIBSOXR 0
#define CONFIG_LIBSPEEX 0
#define CONFIG_LIBSSH 0
#define CONFIG_LIBTESSERACT 0
#define CONFIG_LIBTHEORA 0
#define CONFIG_LIBTWOLAME 0
#define CONFIG_LIBUTVIDEO 0
#define CONFIG_LIBV4L2 0
#define CONFIG_LIBVIDSTAB 0
#define CONFIG_LIBVO_AMRWBENC 0
#define CONFIG_LIBVORBIS 0
#define CONFIG_LIBVPX 0
#define CONFIG_LIBWAVPACK 0
#define CONFIG_LIBWEBP 0
#define CONFIG_LIBX264 0
#define CONFIG_LIBX265 0
#define CONFIG_LIBXAVS 0
#define CONFIG_LIBXCB ${HAVE_XLIB}
#define CONFIG_LIBXCB_SHM ${HAVE_XLIB}
#define CONFIG_LIBXCB_SHAPE ${HAVE_XLIB}
#define CONFIG_LIBXCB_XFIXES ${HAVE_XLIB}
#define CONFIG_LIBXVID 0
#define CONFIG_LIBZIMG 0
#define CONFIG_LIBZMQ 0
#define CONFIG_LIBZVBI 0
#define CONFIG_LZMA 0
#define CONFIG_MMAL 0
#define CONFIG_NETCDF 0
#define CONFIG_NVENC 0
#define CONFIG_OPENAL 0
#define CONFIG_OPENCL 0
#define CONFIG_OPENGL 0
#define CONFIG_OPENSSL 0
#define CONFIG_SCHANNEL 0
#define CONFIG_SDL 0
#define CONFIG_SECURETRANSPORT 0
#define CONFIG_X11GRAB 0
#define CONFIG_XLIB ${HAVE_XLIB}
#define CONFIG_ZLIB ${HAVE_ZLIB}
#define CONFIG_FTRAPV 0
#define CONFIG_GRAY 0
#define CONFIG_HARDCODED_TABLES 0
#define CONFIG_RUNTIME_CPUDETECT 1
#define CONFIG_SAFE_BITSTREAM_READER 1
#define CONFIG_SHARED 0
#define CONFIG_SMALL 0
#define CONFIG_STATIC 1
#define CONFIG_SWSCALE_ALPHA 1
#define CONFIG_D3D11VA 0
#define CONFIG_DXVA2 ${HAVE_DXVA2_LIB}
#define CONFIG_VAAPI ${HAVE_VAAPI_X11}
#define CONFIG_VDA 0
#define CONFIG_VDPAU ${HAVE_VDPAU_X11}
#define CONFIG_VIDEOTOOLBOX 0
#define CONFIG_XVMC 1
#define CONFIG_GPL 1
#define CONFIG_NONFREE 0
#define CONFIG_VERSION3 0
#define CONFIG_AVCODEC 1
#define CONFIG_AVDEVICE 0
#define CONFIG_AVFILTER 0
#define CONFIG_AVFORMAT 1
#define CONFIG_AVRESAMPLE 0
#define CONFIG_AVUTIL 1
#define CONFIG_POSTPROC 0
#define CONFIG_SWRESAMPLE 1
#define CONFIG_SWSCALE 1
#define CONFIG_FFPLAY 0
#define CONFIG_FFPROBE 0
#define CONFIG_FFSERVER 0
#define CONFIG_FFMPEG 0
#define CONFIG_DCT 1
#define CONFIG_DWT 0
#define CONFIG_ERROR_RESILIENCE 1
#define CONFIG_FAAN 1
#define CONFIG_FAST_UNALIGNED 1
#define CONFIG_FFT 1
#define CONFIG_LSP 0
#define CONFIG_LZO 0
#define CONFIG_MDCT 1
#define CONFIG_PIXELUTILS 0
#define CONFIG_NETWORK 0
#define CONFIG_RDFT 1
#define CONFIG_FONTCONFIG 0
#define CONFIG_INCOMPATIBLE_LIBAV_ABI 0
#define CONFIG_MEMALIGN_HACK 0
#define CONFIG_MEMORY_POISONING 0
#define CONFIG_NEON_CLOBBER_TEST 0
#define CONFIG_PIC 1
#define CONFIG_POD2MAN 0
#define CONFIG_RAISE_MAJOR 0
#define CONFIG_THUMB 0
#define CONFIG_VALGRIND_BACKTRACE 0
#define CONFIG_XMM_CLOBBER_TEST 0
#define CONFIG_AANDCTTABLES 1
#define CONFIG_AC3DSP 0
#define CONFIG_AUDIO_FRAME_QUEUE 0
#define CONFIG_AUDIODSP 0
#define CONFIG_BLOCKDSP 1
#define CONFIG_BSWAPDSP 1
#define CONFIG_CABAC 1
#define CONFIG_DIRAC_PARSE 0
#define CONFIG_DVPROFILE 0
#define CONFIG_EXIF 1
#define CONFIG_FAANDCT 1
#define CONFIG_FAANIDCT 1
#define CONFIG_FDCTDSP 1
#define CONFIG_FLACDSP 0
#define CONFIG_FMTCONVERT 0
#define CONFIG_FRAME_THREAD_ENCODER 1
#define CONFIG_G722DSP 0
#define CONFIG_GOLOMB 1
#define CONFIG_GPLV3 0
#define CONFIG_H263DSP 1
#define CONFIG_H264CHROMA 1
#define CONFIG_H264DSP 1
#define CONFIG_H264PRED 1
#define CONFIG_H264QPEL 1
#define CONFIG_HPELDSP 1
#define CONFIG_HUFFMAN 1
#define CONFIG_HUFFYUVDSP 0
#define CONFIG_HUFFYUVENCDSP 1
#define CONFIG_IDCTDSP 1
#define CONFIG_IIRFILTER 0
#define CONFIG_IMDCT15 1
#define CONFIG_INTRAX8 0
#define CONFIG_IVIDSP 0
#define CONFIG_JPEGTABLES 1
#define CONFIG_LGPLV3 0
#define CONFIG_LIBX262 0
#define CONFIG_LLAUDDSP 0
#define CONFIG_LLVIDDSP 1
#define CONFIG_LPC 0
#define CONFIG_LZF 0
#define CONFIG_ME_CMP 1
#define CONFIG_MPEG_ER 1
#define CONFIG_MPEGAUDIO 1
#define CONFIG_MPEGAUDIODSP 1
#define CONFIG_MPEGVIDEO 1
#define CONFIG_MPEGVIDEOENC 1
#define CONFIG_MSS34DSP 0
#define CONFIG_PIXBLOCKDSP 1
#define CONFIG_QPELDSP 1
#define CONFIG_QSV 0
#define CONFIG_QSVDEC 0
#define CONFIG_QSVENC 0
#define CONFIG_RANGECODER 1
#define CONFIG_RIFFDEC 1
#define CONFIG_RIFFENC 1
#define CONFIG_RTPDEC 0
#define CONFIG_RTPENC_CHAIN 0
#define CONFIG_RV34DSP 0
#define CONFIG_SINEWIN 1
#define CONFIG_SNAPPY 0
#define CONFIG_STARTCODE 1
#define CONFIG_TEXTUREDSP 0
#define CONFIG_TEXTUREDSPENC 0
#define CONFIG_TPELDSP 0
#define CONFIG_VIDEODSP 1
#define CONFIG_VP3DSP 0
#define CONFIG_VP56DSP 0
#define CONFIG_VP8DSP 0
#define CONFIG_WMA_FREQS 0
#define CONFIG_WMV2DSP 0
#define CONFIG_AAC_ADTSTOASC_BSF 0
#define CONFIG_CHOMP_BSF 0
#define CONFIG_DUMP_EXTRADATA_BSF 0
#define CONFIG_H264_MP4TOANNEXB_BSF 0
#define CONFIG_HEVC_MP4TOANNEXB_BSF 0
#define CONFIG_IMX_DUMP_HEADER_BSF 0
#define CONFIG_MJPEG2JPEG_BSF 0
#define CONFIG_MJPEGA_DUMP_HEADER_BSF 0
#define CONFIG_MP3_HEADER_DECOMPRESS_BSF 0
#define CONFIG_MPEG4_UNPACK_BFRAMES_BSF 0
#define CONFIG_MOV2TEXTSUB_BSF 0
#define CONFIG_NOISE_BSF 0
#define CONFIG_REMOVE_EXTRADATA_BSF 0
#define CONFIG_TEXT2MOVSUB_BSF 0
#define CONFIG_AASC_DECODER 0
#define CONFIG_AIC_DECODER 0
#define CONFIG_ALIAS_PIX_DECODER 0
#define CONFIG_AMV_DECODER 0
#define CONFIG_ANM_DECODER 0
#define CONFIG_ANSI_DECODER 0
#define CONFIG_APNG_DECODER 0
#define CONFIG_ASV1_DECODER 0
#define CONFIG_ASV2_DECODER 0
#define CONFIG_AURA_DECODER 0
#define CONFIG_AURA2_DECODER 0
#define CONFIG_AVRP_DECODER 0
#define CONFIG_AVRN_DECODER 0
#define CONFIG_AVS_DECODER 0
#define CONFIG_AVUI_DECODER 0
#define CONFIG_AYUV_DECODER 0
#define CONFIG_BETHSOFTVID_DECODER 0
#define CONFIG_BFI_DECODER 0
#define CONFIG_BINK_DECODER 0
#define CONFIG_BMP_DECODER 0
#define CONFIG_BMV_VIDEO_DECODER 0
#define CONFIG_BRENDER_PIX_DECODER 0
#define CONFIG_C93_DECODER 0
#define CONFIG_CAVS_DECODER 0
#define CONFIG_CDGRAPHICS_DECODER 0
#define CONFIG_CDXL_DECODER 0
#define CONFIG_CFHD_DECODER 0
#define CONFIG_CINEPAK_DECODER 0
#define CONFIG_CLJR_DECODER 0
#define CONFIG_CLLC_DECODER 0
#define CONFIG_COMFORTNOISE_DECODER 0
#define CONFIG_CPIA_DECODER 0
#define CONFIG_CSCD_DECODER 0
#define CONFIG_CYUV_DECODER 0
#define CONFIG_DDS_DECODER 0
#define CONFIG_DFA_DECODER 0
#define CONFIG_DIRAC_DECODER 0
#define CONFIG_DNXHD_DECODER 0
#define CONFIG_DPX_DECODER 0
#define CONFIG_DSICINVIDEO_DECODER 0
#define CONFIG_DVAUDIO_DECODER 0
#define CONFIG_DVVIDEO_DECODER 0
#define CONFIG_DXA_DECODER 0
#define CONFIG_DXTORY_DECODER 0
#define CONFIG_DXV_DECODER 0
#define CONFIG_EACMV_DECODER 0
#define CONFIG_EAMAD_DECODER 0
#define CONFIG_EATGQ_DECODER 0
#define CONFIG_EATGV_DECODER 0
#define CONFIG_EATQI_DECODER 0
#define CONFIG_EIGHTBPS_DECODER 0
#define CONFIG_EIGHTSVX_EXP_DECODER 0
#define CONFIG_EIGHTSVX_FIB_DECODER 0
#define CONFIG_ESCAPE124_DECODER 0
#define CONFIG_ESCAPE130_DECODER 0
#define CONFIG_EXR_DECODER 0
#define CONFIG_FFV1_DECODER 0
#define CONFIG_FFVHUFF_DECODER 0
#define CONFIG_FIC_DECODER 0
#define CONFIG_FLASHSV_DECODER 0
#define CONFIG_FLASHSV2_DECODER 0
#define CONFIG_FLIC_DECODER 0
#define CONFIG_FLV_DECODER 0
#define CONFIG_FOURXM_DECODER 0
#define CONFIG_FRAPS_DECODER 0
#define CONFIG_FRWU_DECODER 0
#define CONFIG_G2M_DECODER 0
#define CONFIG_GIF_DECODER 0
#define CONFIG_H261_DECODER 0
#define CONFIG_H263_DECODER 1
#define CONFIG_H263I_DECODER 0
#define CONFIG_H263P_DECODER 1
#define CONFIG_H264_DECODER 1
#define CONFIG_H264_CRYSTALHD_DECODER 0
#define CONFIG_H264_MMAL_DECODER 0
#define CONFIG_H264_QSV_DECODER 0
#define CONFIG_H264_VDA_DECODER 0
#define CONFIG_H264_VDPAU_DECODER 0
#define CONFIG_HAP_DECODER 0
#define CONFIG_HEVC_DECODER 0
#define CONFIG_HEVC_QSV_DECODER 0
#define CONFIG_HNM4_VIDEO_DECODER 0
#define CONFIG_HQ_HQA_DECODER 0
#define CONFIG_HQX_DECODER 0
#define CONFIG_HUFFYUV_DECODER 0
#define CONFIG_IDCIN_DECODER 0
#define CONFIG_IFF_ILBM_DECODER 0
#define CONFIG_INDEO2_DECODER 0
#define CONFIG_INDEO3_DECODER 0
#define CONFIG_INDEO4_DECODER 0
#define CONFIG_INDEO5_DECODER 0
#define CONFIG_INTERPLAY_VIDEO_DECODER 0
#define CONFIG_JPEG2000_DECODER 0
#define CONFIG_JPEGLS_DECODER 0
#define CONFIG_JV_DECODER 0
#define CONFIG_KGV1_DECODER 0
#define CONFIG_KMVC_DECODER 0
#define CONFIG_LAGARITH_DECODER 0
#define CONFIG_LOCO_DECODER 0
#define CONFIG_MDEC_DECODER 0
#define CONFIG_MIMIC_DECODER 0
#define CONFIG_MJPEG_DECODER 1
#define CONFIG_MJPEGB_DECODER 1
#define CONFIG_MMVIDEO_DECODER 0
#define CONFIG_MOTIONPIXELS_DECODER 0
#define CONFIG_MPEG_XVMC_DECODER 0
#define CONFIG_MPEG1VIDEO_DECODER 0
#define CONFIG_MPEG2VIDEO_DECODER 1
#define CONFIG_MPEG4_DECODER 1
#define CONFIG_MPEG4_CRYSTALHD_DECODER 0
#define CONFIG_MPEG4_MMAL_DECODER 0
#define CONFIG_MPEG4_VDPAU_DECODER 0
#define CONFIG_MPEGVIDEO_DECODER 0
#define CONFIG_MPEG_VDPAU_DECODER 0
#define CONFIG_MPEG1_VDPAU_DECODER 0
#define CONFIG_MPEG2_MMAL_DECODER 0
#define CONFIG_MPEG2_CRYSTALHD_DECODER 0
#define CONFIG_MPEG2_QSV_DECODER 0
#define CONFIG_MSA1_DECODER 0
#define CONFIG_MSMPEG4_CRYSTALHD_DECODER 0
#define CONFIG_MSMPEG4V1_DECODER 0
#define CONFIG_MSMPEG4V2_DECODER 0
#define CONFIG_MSMPEG4V3_DECODER 0
#define CONFIG_MSRLE_DECODER 0
#define CONFIG_MSS1_DECODER 0
#define CONFIG_MSS2_DECODER 0
#define CONFIG_MSVIDEO1_DECODER 0
#define CONFIG_MSZH_DECODER 0
#define CONFIG_MTS2_DECODER 0
#define CONFIG_MVC1_DECODER 0
#define CONFIG_MVC2_DECODER 0
#define CONFIG_MXPEG_DECODER 0
#define CONFIG_NUV_DECODER 0
#define CONFIG_PAF_VIDEO_DECODER 0
#define CONFIG_PAM_DECODER 0
#define CONFIG_PBM_DECODER 0
#define CONFIG_PCX_DECODER 0
#define CONFIG_PGM_DECODER 0
#define CONFIG_PGMYUV_DECODER 0
#define CONFIG_PICTOR_DECODER 0
#define CONFIG_PNG_DECODER 0
#define CONFIG_PPM_DECODER 0
#define CONFIG_PRORES_DECODER 0
#define CONFIG_PRORES_LGPL_DECODER 0
#define CONFIG_PTX_DECODER 0
#define CONFIG_QDRAW_DECODER 0
#define CONFIG_QPEG_DECODER 0
#define CONFIG_QTRLE_DECODER 0
#define CONFIG_R10K_DECODER 0
#define CONFIG_R210_DECODER 0
#define CONFIG_RAWVIDEO_DECODER 0
#define CONFIG_RL2_DECODER 0
#define CONFIG_ROQ_DECODER 0
#define CONFIG_RPZA_DECODER 0
#define CONFIG_RSCC_DECODER 0
#define CONFIG_RV10_DECODER 0
#define CONFIG_RV20_DECODER 0
#define CONFIG_RV30_DECODER 0
#define CONFIG_RV40_DECODER 0
#define CONFIG_S302M_DECODER 0
#define CONFIG_SANM_DECODER 0
#define CONFIG_SCREENPRESSO_DECODER 0
#define CONFIG_SDX2_DPCM_DECODER 0
#define CONFIG_SGI_DECODER 0
#define CONFIG_SGIRLE_DECODER 0
#define CONFIG_SMACKER_DECODER 0
#define CONFIG_SMC_DECODER 0
#define CONFIG_SMVJPEG_DECODER 0
#define CONFIG_SNOW_DECODER 0
#define CONFIG_SP5X_DECODER 0
#define CONFIG_SUNRAST_DECODER 0
#define CONFIG_SVQ1_DECODER 0
#define CONFIG_SVQ3_DECODER 0
#define CONFIG_TARGA_DECODER 0
#define CONFIG_TARGA_Y216_DECODER 0
#define CONFIG_TDSC_DECODER 0
#define CONFIG_THEORA_DECODER 0
#define CONFIG_THP_DECODER 0
#define CONFIG_TIERTEXSEQVIDEO_DECODER 0
#define CONFIG_TIFF_DECODER 0
#define CONFIG_TMV_DECODER 0
#define CONFIG_TRUEMOTION1_DECODER 0
#define CONFIG_TRUEMOTION2_DECODER 0
#define CONFIG_TSCC_DECODER 0
#define CONFIG_TSCC2_DECODER 0
#define CONFIG_TXD_DECODER 0
#define CONFIG_ULTI_DECODER 0
#define CONFIG_UTVIDEO_DECODER 0
#define CONFIG_V210_DECODER 0
#define CONFIG_V210X_DECODER 0
#define CONFIG_V308_DECODER 0
#define CONFIG_V408_DECODER 0
#define CONFIG_V410_DECODER 0
#define CONFIG_VB_DECODER 0
#define CONFIG_VBLE_DECODER 0
#define CONFIG_VC1_DECODER 0
#define CONFIG_VC1_CRYSTALHD_DECODER 0
#define CONFIG_VC1_VDPAU_DECODER 0
#define CONFIG_VC1IMAGE_DECODER 0
#define CONFIG_VC1_MMAL_DECODER 0
#define CONFIG_VC1_QSV_DECODER 0
#define CONFIG_VCR1_DECODER 0
#define CONFIG_VMDVIDEO_DECODER 0
#define CONFIG_VMNC_DECODER 0
#define CONFIG_VP3_DECODER 0
#define CONFIG_VP5_DECODER 0
#define CONFIG_VP6_DECODER 0
#define CONFIG_VP6A_DECODER 0
#define CONFIG_VP6F_DECODER 0
#define CONFIG_VP7_DECODER 0
#define CONFIG_VP8_DECODER 0
#define CONFIG_VP9_DECODER 0
#define CONFIG_VQA_DECODER 0
#define CONFIG_WEBP_DECODER 0
#define CONFIG_WMV1_DECODER 0
#define CONFIG_WMV2_DECODER 0
#define CONFIG_WMV3_DECODER 0
#define CONFIG_WMV3_CRYSTALHD_DECODER 0
#define CONFIG_WMV3_VDPAU_DECODER 0
#define CONFIG_WMV3IMAGE_DECODER 0
#define CONFIG_WNV1_DECODER 0
#define CONFIG_XAN_WC3_DECODER 0
#define CONFIG_XAN_WC4_DECODER 0
#define CONFIG_XBM_DECODER 0
#define CONFIG_XFACE_DECODER 0
#define CONFIG_XL_DECODER 0
#define CONFIG_XWD_DECODER 0
#define CONFIG_Y41P_DECODER 0
#define CONFIG_YOP_DECODER 0
#define CONFIG_YUV4_DECODER 0
#define CONFIG_ZERO12V_DECODER 0
#define CONFIG_ZEROCODEC_DECODER 0
#define CONFIG_ZLIB_DECODER 0
#define CONFIG_ZMBV_DECODER 0
#define CONFIG_AAC_DECODER 1
#define CONFIG_AAC_FIXED_DECODER 0
#define CONFIG_AAC_LATM_DECODER 1
#define CONFIG_AC3_DECODER 0
#define CONFIG_AC3_FIXED_DECODER 0
#define CONFIG_ALAC_DECODER 0
#define CONFIG_ALS_DECODER 0
#define CONFIG_AMRNB_DECODER 0
#define CONFIG_AMRWB_DECODER 0
#define CONFIG_APE_DECODER 0
#define CONFIG_ATRAC1_DECODER 0
#define CONFIG_ATRAC3_DECODER 1
#define CONFIG_ATRAC3P_DECODER 1
#define CONFIG_BINKAUDIO_DCT_DECODER 0
#define CONFIG_BINKAUDIO_RDFT_DECODER 0
#define CONFIG_BMV_AUDIO_DECODER 0
#define CONFIG_COOK_DECODER 0
#define CONFIG_DCA_DECODER 0
#define CONFIG_DSD_LSBF_DECODER 0
#define CONFIG_DSD_MSBF_DECODER 0
#define CONFIG_DSD_LSBF_PLANAR_DECODER 0
#define CONFIG_DSD_MSBF_PLANAR_DECODER 0
#define CONFIG_DSICINAUDIO_DECODER 0
#define CONFIG_DSS_SP_DECODER 0
#define CONFIG_EAC3_DECODER 0
#define CONFIG_EVRC_DECODER 0
#define CONFIG_FFWAVESYNTH_DECODER 0
#define CONFIG_FLAC_DECODER 0
#define CONFIG_G723_1_DECODER 0
#define CONFIG_G729_DECODER 0
#define CONFIG_GSM_DECODER 0
#define CONFIG_GSM_MS_DECODER 0
#define CONFIG_IAC_DECODER 0
#define CONFIG_IMC_DECODER 0
#define CONFIG_INTERPLAY_ACM_DECODER 0
#define CONFIG_MACE3_DECODER 0
#define CONFIG_MACE6_DECODER 0
#define CONFIG_METASOUND_DECODER 0
#define CONFIG_MLP_DECODER 0
#define CONFIG_MP1_DECODER 0
#define CONFIG_MP1FLOAT_DECODER 0
#define CONFIG_MP2_DECODER 0
#define CONFIG_MP2FLOAT_DECODER 0
#define CONFIG_MP3_DECODER 1
#define CONFIG_MP3FLOAT_DECODER 0
#define CONFIG_MP3ADU_DECODER 0
#define CONFIG_MP3ADUFLOAT_DECODER 0
#define CONFIG_MP3ON4_DECODER 0
#define CONFIG_MP3ON4FLOAT_DECODER 0
#define CONFIG_MPC7_DECODER 0
#define CONFIG_MPC8_DECODER 0
#define CONFIG_NELLYMOSER_DECODER 0
#define CONFIG_ON2AVC_DECODER 0
#define CONFIG_OPUS_DECODER 0
#define CONFIG_PAF_AUDIO_DECODER 0
#define CONFIG_QCELP_DECODER 0
#define CONFIG_QDM2_DECODER 0
#define CONFIG_RA_144_DECODER 0
#define CONFIG_RA_288_DECODER 0
#define CONFIG_RALF_DECODER 0
#define CONFIG_SHORTEN_DECODER 0
#define CONFIG_SIPR_DECODER 0
#define CONFIG_SMACKAUD_DECODER 0
#define CONFIG_SONIC_DECODER 0
#define CONFIG_TAK_DECODER 0
#define CONFIG_TRUEHD_DECODER 0
#define CONFIG_TRUESPEECH_DECODER 0
#define CONFIG_TTA_DECODER 0
#define CONFIG_TWINVQ_DECODER 0
#define CONFIG_VMDAUDIO_DECODER 0
#define CONFIG_VORBIS_DECODER 0
#define CONFIG_WAVPACK_DECODER 0
#define CONFIG_WMALOSSLESS_DECODER 0
#define CONFIG_WMAPRO_DECODER 0
#define CONFIG_WMAV1_DECODER 0
#define CONFIG_WMAV2_DECODER 0
#define CONFIG_WMAVOICE_DECODER 0
#define CONFIG_WS_SND1_DECODER 0
#define CONFIG_XMA1_DECODER 0
#define CONFIG_XMA2_DECODER 0
#define CONFIG_PCM_ALAW_DECODER 0
#define CONFIG_PCM_BLURAY_DECODER 0
#define CONFIG_PCM_DVD_DECODER 0
#define CONFIG_PCM_F32BE_DECODER 0
#define CONFIG_PCM_F32LE_DECODER 0
#define CONFIG_PCM_F64BE_DECODER 0
#define CONFIG_PCM_F64LE_DECODER 0
#define CONFIG_PCM_LXF_DECODER 0
#define CONFIG_PCM_MULAW_DECODER 0
#define CONFIG_PCM_S8_DECODER 1
#define CONFIG_PCM_S8_PLANAR_DECODER 0
#define CONFIG_PCM_S16BE_DECODER 0
#define CONFIG_PCM_S16BE_PLANAR_DECODER 0
#define CONFIG_PCM_S16LE_DECODER 1
#define CONFIG_PCM_S16LE_PLANAR_DECODER 0
#define CONFIG_PCM_S24BE_DECODER 0
#define CONFIG_PCM_S24DAUD_DECODER 0
#define CONFIG_PCM_S24LE_DECODER 0
#define CONFIG_PCM_S24LE_PLANAR_DECODER 0
#define CONFIG_PCM_S32BE_DECODER 0
#define CONFIG_PCM_S32LE_DECODER 0
#define CONFIG_PCM_S32LE_PLANAR_DECODER 0
#define CONFIG_PCM_U8_DECODER 0
#define CONFIG_PCM_U16BE_DECODER 0
#define CONFIG_PCM_U16LE_DECODER 0
#define CONFIG_PCM_U24BE_DECODER 0
#define CONFIG_PCM_U24LE_DECODER 0
#define CONFIG_PCM_U32BE_DECODER 0
#define CONFIG_PCM_U32LE_DECODER 0
#define CONFIG_PCM_ZORK_DECODER 0
#define CONFIG_INTERPLAY_DPCM_DECODER 0
#define CONFIG_ROQ_DPCM_DECODER 0
#define CONFIG_SOL_DPCM_DECODER 0
#define CONFIG_XAN_DPCM_DECODER 0
#define CONFIG_ADPCM_4XM_DECODER 0
#define CONFIG_ADPCM_ADX_DECODER 0
#define CONFIG_ADPCM_AFC_DECODER 0
#define CONFIG_ADPCM_AICA_DECODER 0
#define CONFIG_ADPCM_CT_DECODER 0
#define CONFIG_ADPCM_DTK_DECODER 0
#define CONFIG_ADPCM_EA_DECODER 0
#define CONFIG_ADPCM_EA_MAXIS_XA_DECODER 0
#define CONFIG_ADPCM_EA_R1_DECODER 0
#define CONFIG_ADPCM_EA_R2_DECODER 0
#define CONFIG_ADPCM_EA_R3_DECODER 0
#define CONFIG_ADPCM_EA_XAS_DECODER 0
#define CONFIG_ADPCM_G722_DECODER 0
#define CONFIG_ADPCM_G726_DECODER 0
#define CONFIG_ADPCM_G726LE_DECODER 0
#define CONFIG_ADPCM_IMA_AMV_DECODER 0
#define CONFIG_ADPCM_IMA_APC_DECODER 0
#define CONFIG_ADPCM_IMA_DK3_DECODER 0
#define CONFIG_ADPCM_IMA_DK4_DECODER 0
#define CONFIG_ADPCM_IMA_EA_EACS_DECODER 0
#define CONFIG_ADPCM_IMA_EA_SEAD_DECODER 0
#define CONFIG_ADPCM_IMA_ISS_DECODER 0
#define CONFIG_ADPCM_IMA_OKI_DECODER 0
#define CONFIG_ADPCM_IMA_QT_DECODER 0
#define CONFIG_ADPCM_IMA_RAD_DECODER 0
#define CONFIG_ADPCM_IMA_SMJPEG_DECODER 0
#define CONFIG_ADPCM_IMA_WAV_DECODER 0
#define CONFIG_ADPCM_IMA_WS_DECODER 0
#define CONFIG_ADPCM_MS_DECODER 0
#define CONFIG_ADPCM_PSX_DECODER 0
#define CONFIG_ADPCM_SBPRO_2_DECODER 0
#define CONFIG_ADPCM_SBPRO_3_DECODER 0
#define CONFIG_ADPCM_SBPRO_4_DECODER 0
#define CONFIG_ADPCM_SWF_DECODER 0
#define CONFIG_ADPCM_THP_DECODER 0
#define CONFIG_ADPCM_THP_LE_DECODER 0
#define CONFIG_ADPCM_VIMA_DECODER 0
#define CONFIG_ADPCM_XA_DECODER 0
#define CONFIG_ADPCM_YAMAHA_DECODER 0
#define CONFIG_SSA_DECODER 0
#define CONFIG_ASS_DECODER 0
#define CONFIG_CCAPTION_DECODER 0
#define CONFIG_DVBSUB_DECODER 0
#define CONFIG_DVDSUB_DECODER 0
#define CONFIG_JACOSUB_DECODER 0
#define CONFIG_MICRODVD_DECODER 0
#define CONFIG_MOVTEXT_DECODER 0
#define CONFIG_MPL2_DECODER 0
#define CONFIG_PGSSUB_DECODER 0
#define CONFIG_PJS_DECODER 0
#define CONFIG_REALTEXT_DECODER 0
#define CONFIG_SAMI_DECODER 0
#define CONFIG_SRT_DECODER 0
#define CONFIG_STL_DECODER 0
#define CONFIG_SUBRIP_DECODER 0
#define CONFIG_SUBVIEWER_DECODER 0
#define CONFIG_SUBVIEWER1_DECODER 0
#define CONFIG_TEXT_DECODER 0
#define CONFIG_VPLAYER_DECODER 0
#define CONFIG_WEBVTT_DECODER 0
#define CONFIG_XSUB_DECODER 0
#define CONFIG_LIBCELT_DECODER 0
#define CONFIG_LIBDCADEC_DECODER 0
#define CONFIG_LIBFDK_AAC_DECODER 0
#define CONFIG_LIBGSM_DECODER 0
#define CONFIG_LIBGSM_MS_DECODER 0
#define CONFIG_LIBILBC_DECODER 0
#define CONFIG_LIBOPENCORE_AMRNB_DECODER 0
#define CONFIG_LIBOPENCORE_AMRWB_DECODER 0
#define CONFIG_LIBOPENJPEG_DECODER 0
#define CONFIG_LIBOPUS_DECODER 0
#define CONFIG_LIBSCHROEDINGER_DECODER 0
#define CONFIG_LIBSPEEX_DECODER 0
#define CONFIG_LIBUTVIDEO_DECODER 0
#define CONFIG_LIBVORBIS_DECODER 0
#define CONFIG_LIBVPX_VP8_DECODER 0
#define CONFIG_LIBVPX_VP9_DECODER 0
#define CONFIG_LIBZVBI_TELETEXT_DECODER 0
#define CONFIG_BINTEXT_DECODER 0
#define CONFIG_XBIN_DECODER 0
#define CONFIG_IDF_DECODER 0
#define CONFIG_AA_DEMUXER 0
#define CONFIG_AAC_DEMUXER 1
#define CONFIG_AC3_DEMUXER 0
#define CONFIG_ACM_DEMUXER 0
#define CONFIG_ACT_DEMUXER 0
#define CONFIG_ADF_DEMUXER 0
#define CONFIG_ADP_DEMUXER 0
#define CONFIG_ADS_DEMUXER 0
#define CONFIG_ADX_DEMUXER 0
#define CONFIG_AEA_DEMUXER 0
#define CONFIG_AFC_DEMUXER 0
#define CONFIG_AIFF_DEMUXER 0
#define CONFIG_AMR_DEMUXER 0
#define CONFIG_ANM_DEMUXER 0
#define CONFIG_APC_DEMUXER 0
#define CONFIG_APE_DEMUXER 0
#define CONFIG_APNG_DEMUXER 0
#define CONFIG_AQTITLE_DEMUXER 0
#define CONFIG_ASF_DEMUXER 0
#define CONFIG_ASF_O_DEMUXER 0
#define CONFIG_ASS_DEMUXER 0
#define CONFIG_AST_DEMUXER 0
#define CONFIG_AU_DEMUXER 0
#define CONFIG_AVI_DEMUXER 1
#define CONFIG_AVISYNTH_DEMUXER 0
#define CONFIG_AVR_DEMUXER 0
#define CONFIG_AVS_DEMUXER 0
#define CONFIG_BETHSOFTVID_DEMUXER 0
#define CONFIG_BFI_DEMUXER 0
#define CONFIG_BINTEXT_DEMUXER 0
#define CONFIG_BINK_DEMUXER 0
#define CONFIG_BIT_DEMUXER 0
#define CONFIG_BMV_DEMUXER 0
#define CONFIG_BFSTM_DEMUXER 0
#define CONFIG_BRSTM_DEMUXER 0
#define CONFIG_BOA_DEMUXER 0
#define CONFIG_C93_DEMUXER 0
#define CONFIG_CAF_DEMUXER 0
#define CONFIG_CAVSVIDEO_DEMUXER 0
#define CONFIG_CDG_DEMUXER 0
#define CONFIG_CDXL_DEMUXER 0
#define CONFIG_CINE_DEMUXER 0
#define CONFIG_CONCAT_DEMUXER 0
#define CONFIG_DATA_DEMUXER 0
#define CONFIG_DAUD_DEMUXER 0
#define CONFIG_DCSTR_DEMUXER 0
#define CONFIG_DFA_DEMUXER 0
#define CONFIG_DIRAC_DEMUXER 0
#define CONFIG_DNXHD_DEMUXER 0
#define CONFIG_DSF_DEMUXER 0
#define CONFIG_DSICIN_DEMUXER 0
#define CONFIG_DSS_DEMUXER 0
#define CONFIG_DTS_DEMUXER 0
#define CONFIG_DTSHD_DEMUXER 0
#define CONFIG_DV_DEMUXER 0
#define CONFIG_DVBSUB_DEMUXER 0
#define CONFIG_DXA_DEMUXER 0
#define CONFIG_EA_DEMUXER 0
#define CONFIG_EA_CDATA_DEMUXER 0
#define CONFIG_EAC3_DEMUXER 0
#define CONFIG_EPAF_DEMUXER 0
#define CONFIG_FFM_DEMUXER 0
#define CONFIG_FFMETADATA_DEMUXER 0
#define CONFIG_FILMSTRIP_DEMUXER 0
#define CONFIG_FLAC_DEMUXER 0
#define CONFIG_FLIC_DEMUXER 0
#define CONFIG_FLV_DEMUXER 0
#define CONFIG_LIVE_FLV_DEMUXER 0
#define CONFIG_FOURXM_DEMUXER 0
#define CONFIG_FRM_DEMUXER 0
#define CONFIG_FSB_DEMUXER 0
#define CONFIG_G722_DEMUXER 0
#define CONFIG_G723_1_DEMUXER 0
#define CONFIG_G729_DEMUXER 0
#define CONFIG_GENH_DEMUXER 0
#define CONFIG_GIF_DEMUXER 0
#define CONFIG_GSM_DEMUXER 0
#define CONFIG_GXF_DEMUXER 0
#define CONFIG_H261_DEMUXER 0
#define CONFIG_H263_DEMUXER 1
#define CONFIG_H264_DEMUXER 1
#define CONFIG_HEVC_DEMUXER 0
#define CONFIG_HLS_DEMUXER 0
#define CONFIG_HNM_DEMUXER 0
#define CONFIG_ICO_DEMUXER 0
#define CONFIG_IDCIN_DEMUXER 0
#define CONFIG_IDF_DEMUXER 0
#define CONFIG_IFF_DEMUXER 0
#define CONFIG_ILBC_DEMUXER 0
#define CONFIG_IMAGE2_DEMUXER 0
#define CONFIG_IMAGE2PIPE_DEMUXER 0
#define CONFIG_IMAGE2_ALIAS_PIX_DEMUXER 0
#define CONFIG_IMAGE2_BRENDER_PIX_DEMUXER 0
#define CONFIG_INGENIENT_DEMUXER 0
#define CONFIG_IPMOVIE_DEMUXER 0
#define CONFIG_IRCAM_DEMUXER 0
#define CONFIG_ISS_DEMUXER 0
#define CONFIG_IV8_DEMUXER 0
#define CONFIG_IVF_DEMUXER 0
#define CONFIG_IVR_DEMUXER 0
#define CONFIG_JACOSUB_DEMUXER 0
#define CONFIG_JV_DEMUXER 0
#define CONFIG_LMLM4_DEMUXER 0
#define CONFIG_LOAS_DEMUXER 0
#define CONFIG_LRC_DEMUXER 0
#define CONFIG_LVF_DEMUXER 0
#define CONFIG_LXF_DEMUXER 0
#define CONFIG_M4V_DEMUXER 1
#define CONFIG_MATROSKA_DEMUXER 0
#define CONFIG_MGSTS_DEMUXER 0
#define CONFIG_MICRODVD_DEMUXER 0
#define CONFIG_MJPEG_DEMUXER 0
#define CONFIG_MLP_DEMUXER 0
#define CONFIG_MLV_DEMUXER 0
#define CONFIG_MM_DEMUXER 0
#define CONFIG_MMF_DEMUXER 0
#define CONFIG_MOV_DEMUXER 0
#define CONFIG_MP3_DEMUXER 1
#define CONFIG_MPC_DEMUXER 0
#define CONFIG_MPC8_DEMUXER 0
#define CONFIG_MPEGPS_DEMUXER 1
#define CONFIG_MPEGTS_DEMUXER 0
#define CONFIG_MPEGTSRAW_DEMUXER 0
#define CONFIG_MPEGVIDEO_DEMUXER 1
#define CONFIG_MPJPEG_DEMUXER 0
#define CONFIG_MPL2_DEMUXER 0
#define CONFIG_MPSUB_DEMUXER 0
#define CONFIG_MSF_DEMUXER 0
#define CONFIG_MSNWC_TCP_DEMUXER 0
#define CONFIG_MTV_DEMUXER 0
#define CONFIG_MV_DEMUXER 0
#define CONFIG_MVI_DEMUXER 0
#define CONFIG_MXF_DEMUXER 0
#define CONFIG_MXG_DEMUXER 0
#define CONFIG_NC_DEMUXER 0
#define CONFIG_NISTSPHERE_DEMUXER 0
#define CONFIG_NSV_DEMUXER 0
#define CONFIG_NUT_DEMUXER 0
#define CONFIG_NUV_DEMUXER 0
#define CONFIG_OGG_DEMUXER 0
#define CONFIG_OMA_DEMUXER 1
#define CONFIG_PAF_DEMUXER 0
#define CONFIG_PCM_ALAW_DEMUXER 0
#define CONFIG_PCM_MULAW_DEMUXER 0
#define CONFIG_PCM_F64BE_DEMUXER 0
#define CONFIG_PCM_F64LE_DEMUXER 0
#define CONFIG_PCM_F32BE_DEMUXER 0
#define CONFIG_PCM_F32LE_DEMUXER 0
#define CONFIG_PCM_S32BE_DEMUXER 0
#define CONFIG_PCM_S32LE_DEMUXER 0
#define CONFIG_PCM_S24BE_DEMUXER 0
#define CONFIG_PCM_S24LE_DEMUXER 0
#define CONFIG_PCM_S16BE_DEMUXER 0
#define CONFIG_PCM_S16LE_DEMUXER 1
#define CONFIG_PCM_S8_DEMUXER 1
#define CONFIG_PCM_U32BE_DEMUXER 0
#define CONFIG_PCM_U32LE_DEMUXER 0
#define CONFIG_PCM_U24BE_DEMUXER 0
#define CONFIG_PCM_U24LE_DEMUXER 0
#define CONFIG_PCM_U16BE_DEMUXER 0
#define CONFIG_PCM_U16LE_DEMUXER 0
#define CONFIG_PCM_U8_DEMUXER 0
#define CONFIG_PJS_DEMUXER 0
#define CONFIG_PMP_DEMUXER 1
#define CONFIG_PVA_DEMUXER 0
#define CONFIG_PVF_DEMUXER 0
#define CONFIG_QCP_DEMUXER 0
#define CONFIG_R3D_DEMUXER 0
#define CONFIG_RAWVIDEO_DEMUXER 0
#define CONFIG_REALTEXT_DEMUXER 0
#define CONFIG_REDSPARK_DEMUXER 0
#define CONFIG_RL2_DEMUXER 0
#define CONFIG_RM_DEMUXER 0
#define CONFIG_ROQ_DEMUXER 0
#define CONFIG_RPL_DEMUXER 0
#define CONFIG_RSD_DEMUXER 0
#define CONFIG_RSO_DEMUXER 0
#define CONFIG_RTP_DEMUXER 0
#define CONFIG_RTSP_DEMUXER 0
#define CONFIG_SAMI_DEMUXER 0
#define CONFIG_SAP_DEMUXER 0
#define CONFIG_SBG_DEMUXER 0
#define CONFIG_SDP_DEMUXER 0
#define CONFIG_SDR2_DEMUXER 0
#define CONFIG_SEGAFILM_DEMUXER 0
#define CONFIG_SHORTEN_DEMUXER 0
#define CONFIG_SIFF_DEMUXER 0
#define CONFIG_SLN_DEMUXER 0
#define CONFIG_SMACKER_DEMUXER 0
#define CONFIG_SMJPEG_DEMUXER 0
#define CONFIG_SMUSH_DEMUXER 0
#define CONFIG_SOL_DEMUXER 0
#define CONFIG_SOX_DEMUXER 0
#define CONFIG_SPDIF_DEMUXER 0
#define CONFIG_SRT_DEMUXER 0
#define CONFIG_STR_DEMUXER 0
#define CONFIG_STL_DEMUXER 0
#define CONFIG_SUBVIEWER1_DEMUXER 0
#define CONFIG_SUBVIEWER_DEMUXER 0
#define CONFIG_SUP_DEMUXER 0
#define CONFIG_SVAG_DEMUXER 0
#define CONFIG_SWF_DEMUXER 0
#define CONFIG_TAK_DEMUXER 0
#define CONFIG_TEDCAPTIONS_DEMUXER 0
#define CONFIG_THP_DEMUXER 0
#define CONFIG_THREEDOSTR_DEMUXER 0
#define CONFIG_TIERTEXSEQ_DEMUXER 0
#define CONFIG_TMV_DEMUXER 0
#define CONFIG_TRUEHD_DEMUXER 0
#define CONFIG_TTA_DEMUXER 0
#define CONFIG_TXD_DEMUXER 0
#define CONFIG_TTY_DEMUXER 0
#define CONFIG_V210_DEMUXER 0
#define CONFIG_V210X_DEMUXER 0
#define CONFIG_VAG_DEMUXER 0
#define CONFIG_VC1_DEMUXER 0
#define CONFIG_VC1T_DEMUXER 0
#define CONFIG_VIVO_DEMUXER 0
#define CONFIG_VMD_DEMUXER 0
#define CONFIG_VOBSUB_DEMUXER 0
#define CONFIG_VOC_DEMUXER 0
#define CONFIG_VPK_DEMUXER 0
#define CONFIG_VPLAYER_DEMUXER 0
#define CONFIG_VQF_DEMUXER 0
#define CONFIG_W64_DEMUXER 0
#define CONFIG_WAV_DEMUXER 1
#define CONFIG_WC3_DEMUXER 0
#define CONFIG_WEBM_DASH_MANIFEST_DEMUXER 0
#define CONFIG_WEBVTT_DEMUXER 0
#define CONFIG_WSAUD_DEMUXER 0
#define CONFIG_WSVQA_DEMUXER 0
#define CONFIG_WTV_DEMUXER 0
#define CONFIG_WVE_DEMUXER 0
#define CONFIG_WV_DEMUXER 0
#define CONFIG_XA_DEMUXER 0
#define CONFIG_XBIN_DEMUXER 0
#define CONFIG_XMV_DEMUXER 0
#define CONFIG_XVAG_DEMUXER 0
#define CONFIG_XWMA_DEMUXER 0
#define CONFIG_YOP_DEMUXER 0
#define CONFIG_YUV4MPEGPIPE_DEMUXER 0
#define CONFIG_IMAGE_BMP_PIPE_DEMUXER 0
#define CONFIG_IMAGE_DDS_PIPE_DEMUXER 0
#define CONFIG_IMAGE_DPX_PIPE_DEMUXER 0
#define CONFIG_IMAGE_EXR_PIPE_DEMUXER 0
#define CONFIG_IMAGE_J2K_PIPE_DEMUXER 0
#define CONFIG_IMAGE_JPEG_PIPE_DEMUXER 0
#define CONFIG_IMAGE_JPEGLS_PIPE_DEMUXER 0
#define CONFIG_IMAGE_PICTOR_PIPE_DEMUXER 0
#define CONFIG_IMAGE_PNG_PIPE_DEMUXER 0
#define CONFIG_IMAGE_QDRAW_PIPE_DEMUXER 0
#define CONFIG_IMAGE_SGI_PIPE_DEMUXER 0
#define CONFIG_IMAGE_SUNRAST_PIPE_DEMUXER 0
#define CONFIG_IMAGE_TIFF_PIPE_DEMUXER 0
#define CONFIG_IMAGE_WEBP_PIPE_DEMUXER 0
#define CONFIG_LIBGME_DEMUXER 0
#define CONFIG_LIBMODPLUG_DEMUXER 0
#define CONFIG_LIBNUT_DEMUXER 0
#define CONFIG_A64MULTI_ENCODER 0
#define CONFIG_A64MULTI5_ENCODER 0
#define CONFIG_ALIAS_PIX_ENCODER 0
#define CONFIG_AMV_ENCODER 0
#define CONFIG_APNG_ENCODER 0
#define CONFIG_ASV1_ENCODER 0
#define CONFIG_ASV2_ENCODER 0
#define CONFIG_AVRP_ENCODER 0
#define CONFIG_AVUI_ENCODER 0
#define CONFIG_AYUV_ENCODER 0
#define CONFIG_BMP_ENCODER 0
#define CONFIG_CINEPAK_ENCODER 0
#define CONFIG_CLJR_ENCODER 0
#define CONFIG_COMFORTNOISE_ENCODER 0
#define CONFIG_DNXHD_ENCODER 0
#define CONFIG_DPX_ENCODER 0
#define CONFIG_DVVIDEO_ENCODER 0
#define CONFIG_FFV1_ENCODER 1
#define CONFIG_FFVHUFF_ENCODER 0
#define CONFIG_FLASHSV_ENCODER 0
#define CONFIG_FLASHSV2_ENCODER 0
#define CONFIG_FLV_ENCODER 0
#define CONFIG_GIF_ENCODER 0
#define CONFIG_H261_ENCODER 0
#define CONFIG_H263_ENCODER 1
#define CONFIG_H263P_ENCODER 0
#define CONFIG_HAP_ENCODER 0
#define CONFIG_HUFFYUV_ENCODER 1
#define CONFIG_JPEG2000_ENCODER 0
#define CONFIG_JPEGLS_ENCODER 0
#define CONFIG_LJPEG_ENCODER 0
#define CONFIG_MJPEG_ENCODER 0
#define CONFIG_MPEG1VIDEO_ENCODER 0
#define CONFIG_MPEG2VIDEO_ENCODER 0
#define CONFIG_MPEG4_ENCODER 1
#define CONFIG_MSMPEG4V2_ENCODER 0
#define CONFIG_MSMPEG4V3_ENCODER 0
#define CONFIG_MSVIDEO1_ENCODER 0
#define CONFIG_PAM_ENCODER 0
#define CONFIG_PBM_ENCODER 0
#define CONFIG_PCX_ENCODER 0
#define CONFIG_PGM_ENCODER 0
#define CONFIG_PGMYUV_ENCODER 0
#define CONFIG_PNG_ENCODER 0
#define CONFIG_PPM_ENCODER 0
#define CONFIG_PRORES_ENCODER 0
#define CONFIG_PRORES_AW_ENCODER 0
#define CONFIG_PRORES_KS_ENCODER 0
#define CONFIG_QTRLE_ENCODER 0
#define CONFIG_R10K_ENCODER 0
#define CONFIG_R210_ENCODER 0
#define CONFIG_RAWVIDEO_ENCODER 0
#define CONFIG_ROQ_ENCODER 0
#define CONFIG_RV10_ENCODER 0
#define CONFIG_RV20_ENCODER 0
#define CONFIG_S302M_ENCODER 0
#define CONFIG_SGI_ENCODER 0
#define CONFIG_SNOW_ENCODER 0
#define CONFIG_SUNRAST_ENCODER 0
#define CONFIG_SVQ1_ENCODER 0
#define CONFIG_TARGA_ENCODER 0
#define CONFIG_TIFF_ENCODER 0
#define CONFIG_UTVIDEO_ENCODER 0
#define CONFIG_V210_ENCODER 0
#define CONFIG_V308_ENCODER 0
#define CONFIG_V408_ENCODER 0
#define CONFIG_V410_ENCODER 0
#define CONFIG_VC2_ENCODER 0
#define CONFIG_WRAPPED_AVFRAME_ENCODER 0
#define CONFIG_WMV1_ENCODER 0
#define CONFIG_WMV2_ENCODER 0
#define CONFIG_XBM_ENCODER 0
#define CONFIG_XFACE_ENCODER 0
#define CONFIG_XWD_ENCODER 0
#define CONFIG_Y41P_ENCODER 0
#define CONFIG_YUV4_ENCODER 0
#define CONFIG_ZLIB_ENCODER 0
#define CONFIG_ZMBV_ENCODER 0
#define CONFIG_AAC_ENCODER 0
#define CONFIG_AC3_ENCODER 0
#define CONFIG_AC3_FIXED_ENCODER 0
#define CONFIG_ALAC_ENCODER 0
#define CONFIG_DCA_ENCODER 0
#define CONFIG_EAC3_ENCODER 0
#define CONFIG_FLAC_ENCODER 0
#define CONFIG_G723_1_ENCODER 0
#define CONFIG_MP2_ENCODER 0
#define CONFIG_MP2FIXED_ENCODER 0
#define CONFIG_NELLYMOSER_ENCODER 0
#define CONFIG_RA_144_ENCODER 0
#define CONFIG_SONIC_ENCODER 0
#define CONFIG_SONIC_LS_ENCODER 0
#define CONFIG_TTA_ENCODER 0
#define CONFIG_VORBIS_ENCODER 0
#define CONFIG_WAVPACK_ENCODER 0
#define CONFIG_WMAV1_ENCODER 0
#define CONFIG_WMAV2_ENCODER 0
#define CONFIG_PCM_ALAW_ENCODER 0
#define CONFIG_PCM_F32BE_ENCODER 0
#define CONFIG_PCM_F32LE_ENCODER 0
#define CONFIG_PCM_F64BE_ENCODER 0
#define CONFIG_PCM_F64LE_ENCODER 0
#define CONFIG_PCM_MULAW_ENCODER 0
#define CONFIG_PCM_S8_ENCODER 0
#define CONFIG_PCM_S8_PLANAR_ENCODER 0
#define CONFIG_PCM_S16BE_ENCODER 0
#define CONFIG_PCM_S16BE_PLANAR_ENCODER 0
#define CONFIG_PCM_S16LE_ENCODER 1
#define CONFIG_PCM_S16LE_PLANAR_ENCODER 0
#define CONFIG_PCM_S24BE_ENCODER 0
#define CONFIG_PCM_S24DAUD_ENCODER 0
#define CONFIG_PCM_S24LE_ENCODER 0
#define CONFIG_PCM_S24LE_PLANAR_ENCODER 0
#define CONFIG_PCM_S32BE_ENCODER 0
#define CONFIG_PCM_S32LE_ENCODER 0
#define CONFIG_PCM_S32LE_PLANAR_ENCODER 0
#define CONFIG_PCM_U8_ENCODER 0
#define CONFIG_PCM_U16BE_ENCODER 0
#define CONFIG_PCM_U16LE_ENCODER 0
#define CONFIG_PCM_U24BE_ENCODER 0
#define CONFIG_PCM_U24LE_ENCODER 0
#define CONFIG_PCM_U32BE_ENCODER 0
#define CONFIG_PCM_U32LE_ENCODER 0
#define CONFIG_ROQ_DPCM_ENCODER 0
#define CONFIG_ADPCM_ADX_ENCODER 0
#define CONFIG_ADPCM_G722_ENCODER 0
#define CONFIG_ADPCM_G726_ENCODER 0
#define CONFIG_ADPCM_IMA_QT_ENCODER 0
#define CONFIG_ADPCM_IMA_WAV_ENCODER 0
#define CONFIG_ADPCM_MS_ENCODER 0
#define CONFIG_ADPCM_SWF_ENCODER 0
#define CONFIG_ADPCM_YAMAHA_ENCODER 0
#define CONFIG_SSA_ENCODER 0
#define CONFIG_ASS_ENCODER 0
#define CONFIG_DVBSUB_ENCODER 0
#define CONFIG_DVDSUB_ENCODER 0
#define CONFIG_MOVTEXT_ENCODER 0
#define CONFIG_SRT_ENCODER 0
#define CONFIG_SUBRIP_ENCODER 0
#define CONFIG_TEXT_ENCODER 0
#define CONFIG_WEBVTT_ENCODER 0
#define CONFIG_XSUB_ENCODER 0
#define CONFIG_LIBFAAC_ENCODER 0
#define CONFIG_LIBFDK_AAC_ENCODER 0
#define CONFIG_LIBGSM_ENCODER 0
#define CONFIG_LIBGSM_MS_ENCODER 0
#define CONFIG_LIBILBC_ENCODER 0
#define CONFIG_LIBMP3LAME_ENCODER 0
#define CONFIG_LIBOPENCORE_AMRNB_ENCODER 0
#define CONFIG_LIBOPENJPEG_ENCODER 0
#define CONFIG_LIBOPUS_ENCODER 0
#define CONFIG_LIBSCHROEDINGER_ENCODER 0
#define CONFIG_LIBSHINE_ENCODER 0
#define CONFIG_LIBSPEEX_ENCODER 0
#define CONFIG_LIBTHEORA_ENCODER 0
#define CONFIG_LIBTWOLAME_ENCODER 0
#define CONFIG_LIBUTVIDEO_ENCODER 0
#define CONFIG_LIBVO_AMRWBENC_ENCODER 0
#define CONFIG_LIBVORBIS_ENCODER 0
#define CONFIG_LIBVPX_VP8_ENCODER 0
#define CONFIG_LIBVPX_VP9_ENCODER 0
#define CONFIG_LIBWAVPACK_ENCODER 0
#define CONFIG_LIBWEBP_ANIM_ENCODER 0
#define CONFIG_LIBWEBP_ENCODER 0
#define CONFIG_LIBX262_ENCODER 0
#define CONFIG_LIBX264_ENCODER 0
#define CONFIG_LIBX264RGB_ENCODER 0
#define CONFIG_LIBX265_ENCODER 0
#define CONFIG_LIBXAVS_ENCODER 0
#define CONFIG_LIBXVID_ENCODER 0
#define CONFIG_LIBOPENH264_ENCODER 0
#define CONFIG_H264_QSV_ENCODER 0
#define CONFIG_NVENC_ENCODER 0
#define CONFIG_NVENC_H264_ENCODER 0
#define CONFIG_NVENC_HEVC_ENCODER 0
#define CONFIG_HEVC_QSV_ENCODER 0
#define CONFIG_LIBKVAZAAR_ENCODER 0
#define CONFIG_MPEG2_QSV_ENCODER 0
#define CONFIG_ACOMPRESSOR_FILTER 0
#define CONFIG_ACROSSFADE_FILTER 0
#define CONFIG_ADELAY_FILTER 0
#define CONFIG_AECHO_FILTER 0
#define CONFIG_AEMPHASIS_FILTER 0
#define CONFIG_AEVAL_FILTER 0
#define CONFIG_AFADE_FILTER 0
#define CONFIG_AFFTFILT_FILTER 0
#define CONFIG_AFORMAT_FILTER 0
#define CONFIG_AGATE_FILTER 0
#define CONFIG_AINTERLEAVE_FILTER 0
#define CONFIG_ALIMITER_FILTER 0
#define CONFIG_ALLPASS_FILTER 0
#define CONFIG_AMERGE_FILTER 0
#define CONFIG_AMETADATA_FILTER 0
#define CONFIG_AMIX_FILTER 0
#define CONFIG_ANEQUALIZER_FILTER 0
#define CONFIG_ANULL_FILTER 0
#define CONFIG_APAD_FILTER 0
#define CONFIG_APERMS_FILTER 0
#define CONFIG_APHASER_FILTER 0
#define CONFIG_APULSATOR_FILTER 0
#define CONFIG_AREALTIME_FILTER 0
#define CONFIG_ARESAMPLE_FILTER 0
#define CONFIG_AREVERSE_FILTER 0
#define CONFIG_ASELECT_FILTER 0
#define CONFIG_ASENDCMD_FILTER 0
#define CONFIG_ASETNSAMPLES_FILTER 0
#define CONFIG_ASETPTS_FILTER 0
#define CONFIG_ASETRATE_FILTER 0
#define CONFIG_ASETTB_FILTER 0
#define CONFIG_ASHOWINFO_FILTER 0
#define CONFIG_ASPLIT_FILTER 0
#define CONFIG_ASTATS_FILTER 0
#define CONFIG_ASTREAMSELECT_FILTER 0
#define CONFIG_ASYNCTS_FILTER 0
#define CONFIG_ATEMPO_FILTER 0
#define CONFIG_ATRIM_FILTER 0
#define CONFIG_AZMQ_FILTER 0
#define CONFIG_BANDPASS_FILTER 0
#define CONFIG_BANDREJECT_FILTER 0
#define CONFIG_BASS_FILTER 0
#define CONFIG_BIQUAD_FILTER 0
#define CONFIG_BS2B_FILTER 0
#define CONFIG_CHANNELMAP_FILTER 0
#define CONFIG_CHANNELSPLIT_FILTER 0
#define CONFIG_CHORUS_FILTER 0
#define CONFIG_COMPAND_FILTER 0
#define CONFIG_COMPENSATIONDELAY_FILTER 0
#define CONFIG_DCSHIFT_FILTER 0
#define CONFIG_DYNAUDNORM_FILTER 0
#define CONFIG_EARWAX_FILTER 0
#define CONFIG_EBUR128_FILTER 0
#define CONFIG_EQUALIZER_FILTER 0
#define CONFIG_EXTRASTEREO_FILTER 0
#define CONFIG_FLANGER_FILTER 0
#define CONFIG_HIGHPASS_FILTER 0
#define CONFIG_JOIN_FILTER 0
#define CONFIG_LADSPA_FILTER 0
#define CONFIG_LOWPASS_FILTER 0
#define CONFIG_PAN_FILTER 0
#define CONFIG_REPLAYGAIN_FILTER 0
#define CONFIG_RESAMPLE_FILTER 0
#define CONFIG_RUBBERBAND_FILTER 0
#define CONFIG_SIDECHAINCOMPRESS_FILTER 0
#define CONFIG_SIDECHAINGATE_FILTER 0
#define CONFIG_SILENCEDETECT_FILTER 0
#define CONFIG_SILENCEREMOVE_FILTER 0
#define CONFIG_SOFALIZER_FILTER 0
#define CONFIG_STEREOTOOLS_FILTER 0
#define CONFIG_STEREOWIDEN_FILTER 0
#define CONFIG_TREBLE_FILTER 0
#define CONFIG_TREMOLO_FILTER 0
#define CONFIG_VIBRATO_FILTER 0
#define CONFIG_VOLUME_FILTER 0
#define CONFIG_VOLUMEDETECT_FILTER 0
#define CONFIG_AEVALSRC_FILTER 0
#define CONFIG_ANOISESRC_FILTER 0
#define CONFIG_ANULLSRC_FILTER 0
#define CONFIG_FLITE_FILTER 0
#define CONFIG_SINE_FILTER 0
#define CONFIG_ANULLSINK_FILTER 0
#define CONFIG_ALPHAEXTRACT_FILTER 0
#define CONFIG_ALPHAMERGE_FILTER 0
#define CONFIG_ATADENOISE_FILTER 0
#define CONFIG_ASS_FILTER 0
#define CONFIG_BBOX_FILTER 0
#define CONFIG_BLACKDETECT_FILTER 0
#define CONFIG_BLACKFRAME_FILTER 0
#define CONFIG_BLEND_FILTER 0
#define CONFIG_BOXBLUR_FILTER 0
#define CONFIG_CHROMAKEY_FILTER 0
#define CONFIG_CODECVIEW_FILTER 0
#define CONFIG_COLORBALANCE_FILTER 0
#define CONFIG_COLORCHANNELMIXER_FILTER 0
#define CONFIG_COLORKEY_FILTER 0
#define CONFIG_COLORLEVELS_FILTER 0
#define CONFIG_COLORMATRIX_FILTER 0
#define CONFIG_CONVOLUTION_FILTER 0
#define CONFIG_COPY_FILTER 0
#define CONFIG_COVER_RECT_FILTER 0
#define CONFIG_CROP_FILTER 0
#define CONFIG_CROPDETECT_FILTER 0
#define CONFIG_CURVES_FILTER 0
#define CONFIG_DCTDNOIZ_FILTER 0
#define CONFIG_DEBAND_FILTER 0
#define CONFIG_DECIMATE_FILTER 0
#define CONFIG_DEFLATE_FILTER 0
#define CONFIG_DEJUDDER_FILTER 0
#define CONFIG_DELOGO_FILTER 0
#define CONFIG_DESHAKE_FILTER 0
#define CONFIG_DETELECINE_FILTER 0
#define CONFIG_DILATION_FILTER 0
#define CONFIG_DISPLACE_FILTER 0
#define CONFIG_DRAWBOX_FILTER 0
#define CONFIG_DRAWGRAPH_FILTER 0
#define CONFIG_DRAWGRID_FILTER 0
#define CONFIG_DRAWTEXT_FILTER 0
#define CONFIG_EDGEDETECT_FILTER 0
#define CONFIG_ELBG_FILTER 0
#define CONFIG_EQ_FILTER 0
#define CONFIG_EROSION_FILTER 0
#define CONFIG_EXTRACTPLANES_FILTER 0
#define CONFIG_FADE_FILTER 0
#define CONFIG_FFTFILT_FILTER 0
#define CONFIG_FIELD_FILTER 0
#define CONFIG_FIELDMATCH_FILTER 0
#define CONFIG_FIELDORDER_FILTER 0
#define CONFIG_FIND_RECT_FILTER 0
#define CONFIG_FORMAT_FILTER 0
#define CONFIG_FPS_FILTER 0
#define CONFIG_FRAMEPACK_FILTER 0
#define CONFIG_FRAMERATE_FILTER 0
#define CONFIG_FRAMESTEP_FILTER 0
#define CONFIG_FREI0R_FILTER 0
#define CONFIG_FSPP_FILTER 0
#define CONFIG_GEQ_FILTER 0
#define CONFIG_GRADFUN_FILTER 0
#define CONFIG_HALDCLUT_FILTER 0
#define CONFIG_HFLIP_FILTER 0
#define CONFIG_HISTEQ_FILTER 0
#define CONFIG_HISTOGRAM_FILTER 0
#define CONFIG_HQDN3D_FILTER 0
#define CONFIG_HQX_FILTER 0
#define CONFIG_HSTACK_FILTER 0
#define CONFIG_HUE_FILTER 0
#define CONFIG_IDET_FILTER 0
#define CONFIG_IL_FILTER 0
#define CONFIG_INFLATE_FILTER 0
#define CONFIG_INTERLACE_FILTER 0
#define CONFIG_INTERLEAVE_FILTER 0
#define CONFIG_KERNDEINT_FILTER 0
#define CONFIG_LENSCORRECTION_FILTER 0
#define CONFIG_LUT3D_FILTER 0
#define CONFIG_LUT_FILTER 0
#define CONFIG_LUTRGB_FILTER 0
#define CONFIG_LUTYUV_FILTER 0
#define CONFIG_MASKEDMERGE_FILTER 0
#define CONFIG_MCDEINT_FILTER 0
#define CONFIG_MERGEPLANES_FILTER 0
#define CONFIG_METADATA_FILTER 0
#define CONFIG_MPDECIMATE_FILTER 0
#define CONFIG_NEGATE_FILTER 0
#define CONFIG_NNEDI_FILTER 0
#define CONFIG_NOFORMAT_FILTER 0
#define CONFIG_NOISE_FILTER 0
#define CONFIG_NULL_FILTER 0
#define CONFIG_OCR_FILTER 0
#define CONFIG_OCV_FILTER 0
#define CONFIG_OVERLAY_FILTER 0
#define CONFIG_OWDENOISE_FILTER 0
#define CONFIG_PAD_FILTER 0
#define CONFIG_PALETTEGEN_FILTER 0
#define CONFIG_PALETTEUSE_FILTER 0
#define CONFIG_PERMS_FILTER 0
#define CONFIG_PERSPECTIVE_FILTER 0
#define CONFIG_PHASE_FILTER 0
#define CONFIG_PIXDESCTEST_FILTER 0
#define CONFIG_PP_FILTER 0
#define CONFIG_PP7_FILTER 0
#define CONFIG_PSNR_FILTER 0
#define CONFIG_PULLUP_FILTER 0
#define CONFIG_QP_FILTER 0
#define CONFIG_RANDOM_FILTER 0
#define CONFIG_REALTIME_FILTER 0
#define CONFIG_REMOVEGRAIN_FILTER 0
#define CONFIG_REMOVELOGO_FILTER 0
#define CONFIG_REPEATFIELDS_FILTER 0
#define CONFIG_REVERSE_FILTER 0
#define CONFIG_ROTATE_FILTER 0
#define CONFIG_SAB_FILTER 0
#define CONFIG_SCALE_FILTER 0
#define CONFIG_SCALE2REF_FILTER 0
#define CONFIG_SELECT_FILTER 0
#define CONFIG_SELECTIVECOLOR_FILTER 0
#define CONFIG_SENDCMD_FILTER 0
#define CONFIG_SEPARATEFIELDS_FILTER 0
#define CONFIG_SETDAR_FILTER 0
#define CONFIG_SETFIELD_FILTER 0
#define CONFIG_SETPTS_FILTER 0
#define CONFIG_SETSAR_FILTER 0
#define CONFIG_SETTB_FILTER 0
#define CONFIG_SHOWINFO_FILTER 0
#define CONFIG_SHOWPALETTE_FILTER 0
#define CONFIG_SHUFFLEFRAMES_FILTER 0
#define CONFIG_SHUFFLEPLANES_FILTER 0
#define CONFIG_SIGNALSTATS_FILTER 0
#define CONFIG_SMARTBLUR_FILTER 0
#define CONFIG_SPLIT_FILTER 0
#define CONFIG_SPP_FILTER 0
#define CONFIG_SSIM_FILTER 0
#define CONFIG_STEREO3D_FILTER 0
#define CONFIG_STREAMSELECT_FILTER 0
#define CONFIG_SUBTITLES_FILTER 0
#define CONFIG_SUPER2XSAI_FILTER 0
#define CONFIG_SWAPRECT_FILTER 0
#define CONFIG_SWAPUV_FILTER 0
#define CONFIG_TBLEND_FILTER 0
#define CONFIG_TELECINE_FILTER 0
#define CONFIG_THUMBNAIL_FILTER 0
#define CONFIG_TILE_FILTER 0
#define CONFIG_TINTERLACE_FILTER 0
#define CONFIG_TRANSPOSE_FILTER 0
#define CONFIG_TRIM_FILTER 0
#define CONFIG_UNSHARP_FILTER 0
#define CONFIG_USPP_FILTER 0
#define CONFIG_VECTORSCOPE_FILTER 0
#define CONFIG_VFLIP_FILTER 0
#define CONFIG_VIDSTABDETECT_FILTER 0
#define CONFIG_VIDSTABTRANSFORM_FILTER 0
#define CONFIG_VIGNETTE_FILTER 0
#define CONFIG_VSTACK_FILTER 0
#define CONFIG_W3FDIF_FILTER 0
#define CONFIG_WAVEFORM_FILTER 0
#define CONFIG_XBR_FILTER 0
#define CONFIG_YADIF_FILTER 0
#define CONFIG_ZMQ_FILTER 0
#define CONFIG_ZOOMPAN_FILTER 0
#define CONFIG_ZSCALE_FILTER 0
#define CONFIG_ALLRGB_FILTER 0
#define CONFIG_ALLYUV_FILTER 0
#define CONFIG_CELLAUTO_FILTER 0
#define CONFIG_COLOR_FILTER 0
#define CONFIG_FREI0R_SRC_FILTER 0
#define CONFIG_HALDCLUTSRC_FILTER 0
#define CONFIG_LIFE_FILTER 0
#define CONFIG_MANDELBROT_FILTER 0
#define CONFIG_MPTESTSRC_FILTER 0
#define CONFIG_NULLSRC_FILTER 0
#define CONFIG_RGBTESTSRC_FILTER 0
#define CONFIG_SMPTEBARS_FILTER 0
#define CONFIG_SMPTEHDBARS_FILTER 0
#define CONFIG_TESTSRC_FILTER 0
#define CONFIG_TESTSRC2_FILTER 0
#define CONFIG_NULLSINK_FILTER 0
#define CONFIG_ADRAWGRAPH_FILTER 0
#define CONFIG_AHISTOGRAM_FILTER 0
#define CONFIG_APHASEMETER_FILTER 0
#define CONFIG_AVECTORSCOPE_FILTER 0
#define CONFIG_CONCAT_FILTER 0
#define CONFIG_SHOWCQT_FILTER 0
#define CONFIG_SHOWFREQS_FILTER 0
#define CONFIG_SHOWSPECTRUM_FILTER 0
#define CONFIG_SHOWSPECTRUMPIC_FILTER 0
#define CONFIG_SHOWVOLUME_FILTER 0
#define CONFIG_SHOWWAVES_FILTER 0
#define CONFIG_SHOWWAVESPIC_FILTER 0
#define CONFIG_SPECTRUMSYNTH_FILTER 0
#define CONFIG_AMOVIE_FILTER 0
#define CONFIG_MOVIE_FILTER 0
#define CONFIG_H263_VAAPI_HWACCEL 0
#define CONFIG_H263_VIDEOTOOLBOX_HWACCEL 0
#define CONFIG_H264_D3D11VA_HWACCEL 0
#define CONFIG_H264_DXVA2_HWACCEL 0
#define CONFIG_H264_MMAL_HWACCEL 0
#define CONFIG_H264_QSV_HWACCEL 0
#define CONFIG_H264_VAAPI_HWACCEL 0
#define CONFIG_H264_VDA_HWACCEL 0
#define CONFIG_H264_VDA_OLD_HWACCEL 0
#define CONFIG_H264_VDPAU_HWACCEL 0
#define CONFIG_H264_VIDEOTOOLBOX_HWACCEL 0
#define CONFIG_HEVC_D3D11VA_HWACCEL 0
#define CONFIG_HEVC_DXVA2_HWACCEL 0
#define CONFIG_HEVC_QSV_HWACCEL 0
#define CONFIG_HEVC_VAAPI_HWACCEL 0
#define CONFIG_HEVC_VDPAU_HWACCEL 0
#define CONFIG_MPEG1_XVMC_HWACCEL 0
#define CONFIG_MPEG1_VDPAU_HWACCEL 0
#define CONFIG_MPEG1_VIDEOTOOLBOX_HWACCEL 0
#define CONFIG_MPEG2_XVMC_HWACCEL 0
#define CONFIG_MPEG2_D3D11VA_HWACCEL 0
#define CONFIG_MPEG2_DXVA2_HWACCEL 0
#define CONFIG_MPEG2_MMAL_HWACCEL 0
#define CONFIG_MPEG2_QSV_HWACCEL 0
#define CONFIG_MPEG2_VAAPI_HWACCEL 0
#define CONFIG_MPEG2_VDPAU_HWACCEL 0
#define CONFIG_MPEG2_VIDEOTOOLBOX_HWACCEL 0
#define CONFIG_MPEG4_MMAL_HWACCEL 0
#define CONFIG_MPEG4_VAAPI_HWACCEL 0
#define CONFIG_MPEG4_VDPAU_HWACCEL 0
#define CONFIG_MPEG4_VIDEOTOOLBOX_HWACCEL 0
#define CONFIG_VC1_D3D11VA_HWACCEL 0
#define CONFIG_VC1_DXVA2_HWACCEL 0
#define CONFIG_VC1_VAAPI_HWACCEL 0
#define CONFIG_VC1_VDPAU_HWACCEL 0
#define CONFIG_VC1_MMAL_HWACCEL 0
#define CONFIG_VC1_QSV_HWACCEL 0
#define CONFIG_VP9_D3D11VA_HWACCEL 0
#define CONFIG_VP9_DXVA2_HWACCEL 0
#define CONFIG_VP9_VAAPI_HWACCEL 0
#define CONFIG_WMV3_D3D11VA_HWACCEL 0
#define CONFIG_WMV3_DXVA2_HWACCEL 0
#define CONFIG_WMV3_VAAPI_HWACCEL 0
#define CONFIG_WMV3_VDPAU_HWACCEL 0
#define CONFIG_ALSA_INDEV 0
#define CONFIG_AVFOUNDATION_INDEV 0
#define CONFIG_BKTR_INDEV 0
#define CONFIG_DECKLINK_INDEV 0
#define CONFIG_DSHOW_INDEV 0
#define CONFIG_DV1394_INDEV 0
#define CONFIG_FBDEV_INDEV 0
#define CONFIG_GDIGRAB_INDEV 0
#define CONFIG_IEC61883_INDEV 0
#define CONFIG_JACK_INDEV 0
#define CONFIG_LAVFI_INDEV 0
#define CONFIG_OPENAL_INDEV 0
#define CONFIG_OSS_INDEV 0
#define CONFIG_PULSE_INDEV 0
#define CONFIG_QTKIT_INDEV 0
#define CONFIG_SNDIO_INDEV 0
#define CONFIG_V4L2_INDEV 0
#define CONFIG_VFWCAP_INDEV 0
#define CONFIG_X11GRAB_INDEV 0
#define CONFIG_X11GRAB_XCB_INDEV 0
#define CONFIG_LIBCDIO_INDEV 0
#define CONFIG_LIBDC1394_INDEV 0
#define CONFIG_A64_MUXER 0
#define CONFIG_AC3_MUXER 0
#define CONFIG_ADTS_MUXER 0
#define CONFIG_ADX_MUXER 0
#define CONFIG_AIFF_MUXER 0
#define CONFIG_AMR_MUXER 0
#define CONFIG_APNG_MUXER 0
#define CONFIG_ASF_MUXER 0
#define CONFIG_ASS_MUXER 0
#define CONFIG_AST_MUXER 0
#define CONFIG_ASF_STREAM_MUXER 0
#define CONFIG_AU_MUXER 0
#define CONFIG_AVI_MUXER 1
#define CONFIG_AVM2_MUXER 0
#define CONFIG_BIT_MUXER 0
#define CONFIG_CAF_MUXER 0
#define CONFIG_CAVSVIDEO_MUXER 0
#define CONFIG_CRC_MUXER 0
#define CONFIG_DASH_MUXER 0
#define CONFIG_DATA_MUXER 0
#define CONFIG_DAUD_MUXER 0
#define CONFIG_DIRAC_MUXER 0
#define CONFIG_DNXHD_MUXER 0
#define CONFIG_DTS_MUXER 0
#define CONFIG_DV_MUXER 0
#define CONFIG_EAC3_MUXER 0
#define CONFIG_F4V_MUXER 0
#define CONFIG_FFM_MUXER 0
#define CONFIG_FFMETADATA_MUXER 0
#define CONFIG_FILMSTRIP_MUXER 0
#define CONFIG_FLAC_MUXER 0
#define CONFIG_FLV_MUXER 0
#define CONFIG_FRAMECRC_MUXER 0
#define CONFIG_FRAMEMD5_MUXER 0
#define CONFIG_G722_MUXER 0
#define CONFIG_G723_1_MUXER 0
#define CONFIG_GIF_MUXER 0
#define CONFIG_GXF_MUXER 0
#define CONFIG_H261_MUXER 0
#define CONFIG_H263_MUXER 0
#define CONFIG_H264_MUXER 0
#define CONFIG_HDS_MUXER 0
#define CONFIG_HEVC_MUXER 0
#define CONFIG_HLS_MUXER 0
#define CONFIG_ICO_MUXER 0
#define CONFIG_ILBC_MUXER 0
#define CONFIG_IMAGE2_MUXER 0
#define CONFIG_IMAGE2PIPE_MUXER 0
#define CONFIG_IPOD_MUXER 0
#define CONFIG_IRCAM_MUXER 0
#define CONFIG_ISMV_MUXER 0
#define CONFIG_IVF_MUXER 0
#define CONFIG_JACOSUB_MUXER 0
#define CONFIG_LATM_MUXER 0
#define CONFIG_LRC_MUXER 0
#define CONFIG_M4V_MUXER 0
#define CONFIG_MD5_MUXER 0
#define CONFIG_MATROSKA_MUXER 0
#define CONFIG_MATROSKA_AUDIO_MUXER 0
#define CONFIG_MICRODVD_MUXER 0
#define CONFIG_MJPEG_MUXER 0
#define CONFIG_MLP_MUXER 0
#define CONFIG_MMF_MUXER 0
#define CONFIG_MOV_MUXER 0
#define CONFIG_MP2_MUXER 0
#define CONFIG_MP3_MUXER 0
#define CONFIG_MP4_MUXER 0
#define CONFIG_MPEG1SYSTEM_MUXER 0
#define CONFIG_MPEG1VCD_MUXER 0
#define CONFIG_MPEG1VIDEO_MUXER 0
#define CONFIG_MPEG2DVD_MUXER 0
#define CONFIG_MPEG2SVCD_MUXER 0
#define CONFIG_MPEG2VIDEO_MUXER 0
#define CONFIG_MPEG2VOB_MUXER 0
#define CONFIG_MPEGTS_MUXER 0
#define CONFIG_MPJPEG_MUXER 0
#define CONFIG_MXF_MUXER 0
#define CONFIG_MXF_D10_MUXER 0
#define CONFIG_MXF_OPATOM_MUXER 0
#define CONFIG_NULL_MUXER 0
#define CONFIG_NUT_MUXER 0
#define CONFIG_OGA_MUXER 0
#define CONFIG_OGG_MUXER 0
#define CONFIG_OMA_MUXER 0
#define CONFIG_OPUS_MUXER 0
#define CONFIG_PCM_ALAW_MUXER 0
#define CONFIG_PCM_MULAW_MUXER 0
#define CONFIG_PCM_F64BE_MUXER 0
#define CONFIG_PCM_F64LE_MUXER 0
#define CONFIG_PCM_F32BE_MUXER 0
#define CONFIG_PCM_F32LE_MUXER 0
#define CONFIG_PCM_S32BE_MUXER 0
#define CONFIG_PCM_S32LE_MUXER 0
#define CONFIG_PCM_S24BE_MUXER 0
#define CONFIG_PCM_S24LE_MUXER 0
#define CONFIG_PCM_S16BE_MUXER 0
#define CONFIG_PCM_S16LE_MUXER 0
#define CONFIG_PCM_S8_MUXER 0
#define CONFIG_PCM_U32BE_MUXER 0
#define CONFIG_PCM_U32LE_MUXER 0
#define CONFIG_PCM_U24BE_MUXER 0
#define CONFIG_PCM_U24LE_MUXER 0
#define CONFIG_PCM_U16BE_MUXER 0
#define CONFIG_PCM_U16LE_MUXER 0
#define CONFIG_PCM_U8_MUXER 0
#define CONFIG_PSP_MUXER 0
#define CONFIG_RAWVIDEO_MUXER 0
#define CONFIG_RM_MUXER 0
#define CONFIG_ROQ_MUXER 0
#define CONFIG_RSO_MUXER 0
#define CONFIG_RTP_MUXER 0
#define CONFIG_RTP_MPEGTS_MUXER 0
#define CONFIG_RTSP_MUXER 0
#define CONFIG_SAP_MUXER 0
#define CONFIG_SEGMENT_MUXER 0
#define CONFIG_STREAM_SEGMENT_MUXER 0
#define CONFIG_SINGLEJPEG_MUXER 0
#define CONFIG_SMJPEG_MUXER 0
#define CONFIG_SMOOTHSTREAMING_MUXER 0
#define CONFIG_SOX_MUXER 0
#define CONFIG_SPX_MUXER 0
#define CONFIG_SPDIF_MUXER 0
#define CONFIG_SRT_MUXER 0
#define CONFIG_SWF_MUXER 0
#define CONFIG_TEE_MUXER 0
#define CONFIG_TG2_MUXER 0
#define CONFIG_TGP_MUXER 0
#define CONFIG_MKVTIMESTAMP_V2_MUXER 0
#define CONFIG_TRUEHD_MUXER 0
#define CONFIG_UNCODEDFRAMECRC_MUXER 0
#define CONFIG_VC1_MUXER 0
#define CONFIG_VC1T_MUXER 0
#define CONFIG_VOC_MUXER 0
#define CONFIG_W64_MUXER 0
#define CONFIG_WAV_MUXER 0
#define CONFIG_WEBM_MUXER 0
#define CONFIG_WEBM_DASH_MANIFEST_MUXER 0
#define CONFIG_WEBM_CHUNK_MUXER 0
#define CONFIG_WEBP_MUXER 0
#define CONFIG_WEBVTT_MUXER 0
#define CONFIG_WTV_MUXER 0
#define CONFIG_WV_MUXER 0
#define CONFIG_YUV4MPEGPIPE_MUXER 0
#define CONFIG_CHROMAPRINT_MUXER 0
#define CONFIG_LIBNUT_MUXER 0
#define CONFIG_ALSA_OUTDEV 0
#define CONFIG_CACA_OUTDEV 0
#define CONFIG_DECKLINK_OUTDEV 0
#define CONFIG_FBDEV_OUTDEV 0
#define CONFIG_OPENGL_OUTDEV 0
#define CONFIG_OSS_OUTDEV 0
#define CONFIG_PULSE_OUTDEV 0
#define CONFIG_SDL_OUTDEV 0
#define CONFIG_SNDIO_OUTDEV 0
#define CONFIG_V4L2_OUTDEV 0
#define CONFIG_XV_OUTDEV 0
#define CONFIG_AAC_PARSER 1
#define CONFIG_AAC_LATM_PARSER 1
#define CONFIG_AC3_PARSER 0
#define CONFIG_ADX_PARSER 0
#define CONFIG_BMP_PARSER 0
#define CONFIG_CAVSVIDEO_PARSER 0
#define CONFIG_COOK_PARSER 0
#define CONFIG_DCA_PARSER 0
#define CONFIG_DIRAC_PARSER 0
#define CONFIG_DNXHD_PARSER 0
#define CONFIG_DPX_PARSER 0
#define CONFIG_DVAUDIO_PARSER 0
#define CONFIG_DVBSUB_PARSER 0
#define CONFIG_DVDSUB_PARSER 0
#define CONFIG_DVD_NAV_PARSER 0
#define CONFIG_FLAC_PARSER 0
#define CONFIG_G729_PARSER 0
#define CONFIG_GSM_PARSER 0
#define CONFIG_H261_PARSER 0
#define CONFIG_H263_PARSER 1
#define CONFIG_H264_PARSER 1
#define CONFIG_HEVC_PARSER 0
#define CONFIG_MJPEG_PARSER 0
#define CONFIG_MLP_PARSER 0
#define CONFIG_MPEG4VIDEO_PARSER 1
#define CONFIG_MPEGAUDIO_PARSER 1
#define CONFIG_MPEGVIDEO_PARSER 1
#define CONFIG_OPUS_PARSER 0
#define CONFIG_PNG_PARSER 0
#define CONFIG_PNM_PARSER 0
#define CONFIG_RV30_PARSER 0
#define CONFIG_RV40_PARSER 0
#define CONFIG_TAK_PARSER 0
#define CONFIG_VC1_PARSER 0
#define CONFIG_VORBIS_PARSER 0
#define CONFIG_VP3_PARSER 0
#define CONFIG_VP8_PARSER 0
#define CONFIG_VP9_PARSER 0
#define CONFIG_ASYNC_PROTOCOL 0
#define CONFIG_BLURAY_PROTOCOL 0
#define CONFIG_CACHE_PROTOCOL 0
#define CONFIG_CONCAT_PROTOCOL 0
#define CONFIG_CRYPTO_PROTOCOL 0
#define CONFIG_DATA_PROTOCOL 0
#define CONFIG_FFRTMPCRYPT_PROTOCOL 0
#define CONFIG_FFRTMPHTTP_PROTOCOL 0
#define CONFIG_FILE_PROTOCOL 1
#define CONFIG_FTP_PROTOCOL 0
#define CONFIG_GOPHER_PROTOCOL 0
#define CONFIG_HLS_PROTOCOL 0
#define CONFIG_HTTP_PROTOCOL 0
#define CONFIG_HTTPPROXY_PROTOCOL 0
#define CONFIG_HTTPS_PROTOCOL 0
#define CONFIG_ICECAST_PROTOCOL 0
#define CONFIG_MMSH_PROTOCOL 0
#define CONFIG_MMST_PROTOCOL 0
#define CONFIG_MD5_PROTOCOL 0
#define CONFIG_PIPE_PROTOCOL 0
#define CONFIG_RTMP_PROTOCOL 0
#define CONFIG_RTMPE_PROTOCOL 0
#define CONFIG_RTMPS_PROTOCOL 0
#define CONFIG_RTMPT_PROTOCOL 0
#define CONFIG_RTMPTE_PROTOCOL 0
#define CONFIG_RTMPTS_PROTOCOL 0
#define CONFIG_RTP_PROTOCOL 0
#define CONFIG_SCTP_PROTOCOL 0
#define CONFIG_SRTP_PROTOCOL 0
#define CONFIG_SUBFILE_PROTOCOL 0
#define CONFIG_TCP_PROTOCOL 0
#define CONFIG_TLS_SCHANNEL_PROTOCOL 0
#define CONFIG_TLS_SECURETRANSPORT_PROTOCOL 0
#define CONFIG_TLS_GNUTLS_PROTOCOL 0
#define CONFIG_TLS_OPENSSL_PROTOCOL 0
#define CONFIG_UDP_PROTOCOL 0
#define CONFIG_UDPLITE_PROTOCOL 0
#define CONFIG_UNIX_PROTOCOL 0
#define CONFIG_LIBRTMP_PROTOCOL 0
#define CONFIG_LIBRTMPE_PROTOCOL 0
#define CONFIG_LIBRTMPS_PROTOCOL 0
#define CONFIG_LIBRTMPT_PROTOCOL 0
#define CONFIG_LIBRTMPTE_PROTOCOL 0
#define CONFIG_LIBSSH_PROTOCOL 0
#define CONFIG_LIBSMBCLIENT_PROTOCOL 0
#endif /* FFMPEG_CONFIG_H */"
	NEWLINE_STYLE LF
)

# Generate config.asm file, if ASM is enabled
# To Do - actually wrap this in a conditional for an as-yet to be created ENABLE_ASM build option
file(READ "${CMAKE_CURRENT_BINARY_DIR}/config.h" CONFIG_H_CONTENTS)
string(REGEX REPLACE "#define" "%define" CONFIG_ASM_CONTENTS ${CONFIG_H_CONTENTS})
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/config.asm" ${CONFIG_ASM_CONTENTS})
# Clean up some lines not used from config.h
file(STRINGS "${CMAKE_CURRENT_BINARY_DIR}/config.asm" LINES)
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/config.asm" "")
foreach(LINE IN LISTS LINES)
	if(NOT LINE MATCHES "Generated" AND NOT LINE MATCHES "CONFIG_H" AND NOT LINE MATCHES "FFMPEG_CONFIGURATION" AND NOT LINE MATCHES "FFMPEG_LICENSE" AND NOT LINE MATCHES "CONFIG_THIS_YEAR" AND NOT LINE MATCHES "FFMPEG_DATADIR" AND NOT LINE MATCHES "AVCONV_DATADIR" AND NOT LINE MATCHES "CC_IDENT" AND NOT LINE MATCHES "av_restrict" AND NOT LINE MATCHES "EXTERN_PREFIX" AND NOT LINE MATCHES "EXTERN_ASM" AND NOT LINE MATCHES "BUILDSUF" AND NOT LINE MATCHES "SLIBSUF" AND NOT LINE MATCHES "HAVE_MMX2" AND NOT LINE MATCHES "SWS_MAX_FILTER_SIZE")
		file(APPEND "${CMAKE_CURRENT_BINARY_DIR}/config.asm" "${LINE}\n")
	endif()
endforeach()

# Generate avconfig.h file
# Test for BIGENDIAN
if(CMAKE_C_BYTE_ORDER STREQUAL "BIG_ENDIAN")
	set(IS_BIGENDIAN 1)
else()
	set(IS_BIGENDIAN 0)
endif()



file(CONFIGURE
	OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/libavutil/avconfig.h"
	CONTENT
"
/* Generated by cmake courtesy of kreinholz's hacks */
#ifndef AVUTIL_AVCONFIG_H
#define AVUTIL_AVCONFIG_H
#define AV_HAVE_BIGENDIAN ${IS_BIGENDIAN}
#define AV_HAVE_FAST_UNALIGNED ${FAST_UNALIGNED}
#define AV_HAVE_INCOMPATIBLE_LIBAV_ABI 0
#endif /* AVUTIL_AVCONFIG_H */
"
	NEWLINE_STYLE LF
)

# Generate ffversion.h header file
# In ffmpeg's version.sh script, 'git' is used, but that's an external dependency we don't otherwise need
# we can just output say the first 7 digits of .git/refs/heads/master, assuming it exists, with hardcoded fallback
set(FILE_PATH "${SRC_DIR}/.git/refs/heads/master")
if(EXISTS ${FILE_PATH})
	file(READ "${FILE_PATH}" GIT_HASH)
	string(SUBSTRING "${GIT_HASH}" 0 7 GIT_HASH)
	set(GIT_HASH \"${GIT_HASH}\")
else()
	set(GIT_HASH \"1e3b496\")
endif()

file(CONFIGURE
	OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/libavutil/ffversion.h"
	CONTENT
"
/* Automatically generated by cmake courtesy of kreinholz's hacks */
#ifndef AVUTIL_FFVERSION_H
#define AVUTIL_FFVERSION_H
#define FFMPEG_VERSION ${GIT_HASH}
#endif /* AVUTIL_FFVERSION_H */
"
	NEWLINE_STYLE LF
)
