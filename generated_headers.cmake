# Before we compile ffmpeg libs, we need to generate config.h/config.asm, libavutil/avconfig.h, and libavutil/ffversion.h.

# Generate config.h file
include(CheckCSourceCompiles)
include(CheckTypeSize)
include(CheckStructHasMember)
include(CheckSymbolExists)
include(CheckFunctionExists)
include(CheckIncludeFile)

include(configure_functions.cmake)

# Check for extern_prefix
check_cc(ff_extern "int ff_extern;" HAVE_ff_extern)
execute_process(
    COMMAND nm "${CONFIG_TESTS_DIR}/ff_extern.o"
    OUTPUT_VARIABLE NM_RESULT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
file(WRITE "${CONFIG_TESTS_DIR}/nm_ff_extern" "${NM_RESULT}")
execute_process(
    COMMAND awk "/ff_extern/{ print substr($0, match($0, /[^ \t]*ff_extern/)) }" "${CONFIG_TESTS_DIR}/nm_ff_extern"
    OUTPUT_VARIABLE AWK_RESULT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(extern_prefix_orig \"${AWK_RESULT}\")
string(REGEX REPLACE "ff_extern" "" extern_prefix "${extern_prefix_orig}")
# Note: when I run the nm and awk commands, piped, in a shell, I don't have to do a regex replace of "ff_extern"

set(build_suffix \"\")
# Note: I can't find anywhere this is defined

set(SLIBSUF \"${CMAKE_SHARED_LIBRARY_SUFFIX}\")

set(sws_max_filter_size 256)
# See line 3055 where 256 is hardcoded as the default

# Check the restrict keyword and assign accordingly
set(_RESTRICT)
check_cc(restrict "void foo(char * restrict p);" restrict)
check_cc(__restrict__ "void foo(char * __restrict__ p);" __restrict__)
check_cc(__restrict "void foo(char * __restrict p);" __restrict)
if (restrict)
	set(_RESTRICT "restrict")
elseif (__restrict__)
	set(_RESTRICT "__restrict__")
elseif (__restrict)
	set(_RESTRICT "__restrict")
else()
	message(STATUS "restrict keyword not found!")
endif()
if (NOT _RESTRICT STREQUAL "restrict")
	check_cc(restrict_cflags "__declspec(${_RESTRICT}) void* foo(int);" stdlib_cflag)
	if (stdlib_cflag)
		# This is where we would, using an as-yet unimplemented function: "add_cflags -FIstdlib.h"
	endif()
endif()

# Get the compiler ident string in the same format as ffmpeg's configure script--retaining only the first line
execute_process(
    COMMAND cc "--version"
    OUTPUT_VARIABLE CC_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
string(REGEX REPLACE "\n.*" "" CC_IDENT "${CC_VERSION}")
set(CC_IDENT \"${CC_IDENT}\")

# Deal with common ARCH aliases (from lines 4027-4072 of ffmpeg's configure script)
# We should probably just use the CMAKE_SYSTEM_PROCESSOR variable and apply any conditions in configure
if(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64.*|arm64.*|aarch64.*")
	set(ARCH "aarch64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "arm.*|iPad.*|iPhone.*")
	set(ARCH "arm")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "mips.*|IP.*")
	# To Do: configure script at lines 4038-4043 conditionally sets additional CPPFLAGS and LDFLAGS
	set(ARCH "mips")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "parisc.*|hppa.*")
	set(ARCH "parisc")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "\"Power Macintosh\".*|ppc.*|powerpc.*")
	set(ARCH "ppc")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "s390.*|s390x.*")
	set(ARCH "s390")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "sh4.*|sh.*")
	set(ARCH "sh4")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "sun4u.*|sparc.*")
	set(ARCH "sparc")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "tilegx.*|tile-gx.*")
	set(ARCH "tilegx")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "i386.*|i486.*|i586.*|i686.*|i86pc.*|BePC.*|x86pc.*|x86_64.*|X86_64.*|x86_32.*|amd64.*|AMD64.*|x86.*")
	set(ARCH "x86")
else()
	message(WARNING "unknown architecture ${CMAKE_SYSTEM_PROCESSOR}")
endif()
message("SYSTEM PROCESSOR FOUND: ${CMAKE_SYSTEM_PROCESSOR}. Assigning to arch alias ${ARCH}.")

# To Do: lines 3450-3454 set .exe as the exesuf on Windows. However, since I'm using a cmake variable for this, it may be fine...

# Get the CPU name--and fallback to "generic" per line 3034 of ffmpeg's configure script
check_native(CPU_NAME)
if (CPU_NAME STREQUAL "")
	set(CPU_NAME "generic")
endif()
message(STATUS "Setting CPU: ${CPU_NAME}")

# To Do: lines 4074-4084 conditionally add cpuflags for march and mcpu for armv.* CPUs
# Need to store cpuflags, cflags, asflags, and ldflags in variables and add as appropriate

# Get the SUBARCH if on arm and CPU_NAME is set to "generic"--see line 4092 of ffmpeg's configure script
if (${ARCH} STREQUAL "arm" AND ${CPU_NAME} STREQUAL "generic")
	probe_arm_arch(SUBARCH)
endif()

# Set the SUBARCH if on arm and CPU_NAME contains the substring "armv"--see line 4127 of ffmpeg's configure script
if (${ARCH} STREQUAL "arm" AND ${CPU_NAME} MATCHES "armv")
	string(TOLOWER "${CPU_NAME}" CPU_LOWERCASE)
	string(REGEX REPLACE "[^a-z0-9]" "" SUBARCH "${CPU_LOWERCASE}")
elseif (${ARCH} STREQUAL "arm")
	if (${CPU_NAME} MATCHES "cortex-a")
		set(SUBARCH "armv7a")
	elseif (${CPU_NAME} MATCHES "cortex-r")
		set(SUBARCH "armv7r")
	elseif (${CPU_NAME} MATCHES "cortex-m")
		set(SUBARCH "armv7m")
		# At line 4134, configure ALSO enables 'thumb'
	elseif (${CPU_NAME} MATCHES "arm11")
		set(SUBARCH "armv6")
	elseif (${CPU_NAME} MATCHES "arm[79]*e*|arm9[24]6*|arm96*|arm102[26]")
		set(SUBARCH "armv5te")
	elseif (${CPU_NAME} MATCHES "armv4*|arm7*|arm9[24]*")
		set(SUBARCH "armv4")
	else()
		probe_arm_arch(SUBARCH)
	endif()
	# Set some options based on the arm SUBARCH--see line 4143 in ffmpeg's configure script
	if (${SUBARCH} MATCHES "armv5t*")
		set(HAVE_FAST_CLZ 1)
	elseif (${SUBARCH} MATCHES "armv[6-8]*")
		set(HAVE_FAST_CLZ 1)
		set(HAVE_FAST_UNALIGNED 1)
	endif()
endif()

# Note: skipping avr32 and bfin cpu-specific checks at lines 4151-4174 of ffmpeg's configure script

# MIPS--see line 4176 of ffmpeg's configure script
if (${ARCH} STREQUAL "mips")
	if (NOT ${CPU_NAME} STREQUAL "generic")
		set(HAVE_MIPS32R2 0)
		set(HAVE_MIPS32R5 0)
        set(HAVE_MIPS64R2 0)
        set(HAVE_MIPS32R6 0)
        set(HAVE_MIPS64R6 0)
        set(HAVE_LOONGSON2 0)
        set(HAVE_LOONGSON3 0)
	endif()
	if (${CPU_NAME} MATCHES "24kc|24kf*|24kec|34kc|1004kc|24kef*|34kf*|1004kf*|74kc|74kf")
		set(HAVE_MIPS32R2 1)
		set(HAVE_MSA 0)
		# Jump down to line 4232 in ffmpeg's configure script
		if (${CPU_NAME} MATCHES "24kc")
			set(HAVE_MIPSFPU 0)
			set(HAVE_MIPSDSP 0)
			set(HAVE_MIPSDSPR2 0)
		elseif (${CPU_NAME} MATCHES "24kf*")
			set(HAVE_MIPSDSP 0)
			set(HAVE_MIPSDSPR2 0)
		elseif (${CPU_NAME} MATCHES "24kec|34kc|1004kc")
			set(HAVE_MIPSFPU 0)
			set(HAVE_MIPSDSPR2 0)
		elseif (${CPU_NAME} MATCHES "74kc")
			set(HAVE_MIPSFPU 0)
		endif()
	elseif (${CPU_NAME} MATCHES "p5600|i6400")
		set(HAVE_MIPSDSP 0)
		set(HAVE_MIPSDSPR2 0)
		# Jump down to line 4251 in ffmpeg's configure script)
		if (${CPU_NAME} MATCHES "p5600")
			set(HAVE_MIPS32R5 1)
			# To Do: add appropriate cpuflags
		elseif (${CPU_NAME} MATCHES "i6400")
			set(HAVE_MIPS64R6 1)
			# To Do: add appropriate cpuflags
		endif()
	elseif (${CPU_NAME} MATCHES "loongson*")
		set(HAVE_LOONGSON2 1)
		set(HAVE_LOONGSON3 1)
		set(HAVE_LOCAL_ALIGNED_8 1)
		set(HAVE_LOCAL_ALIGNED_16 1)
		set(HAVE_LOCAL_ALIGNED_32 1)
		set(HAVE_SIMD_ALIGN_16 1)
		set(HAVE_FAST_64BIT 1)
		set(HAVE_FAST_CLZ 1)
		set(HAVE_FAST_CMOV 1)
		set(HAVE_FAST_UNALIGNED 1)
		set(HAVE_ALIGNED_STACK 0)
		# To Do - deal with cpuflags at lines 4208-4216 of configure script
	else()
		message(WARNING "Unknown CPU. Disabling all MIPS optimizations")
		set(HAVE_MIPSFPU 0)
		set(HAVE_MIPSDSP 0)
		set(HAVE_MIPSDSPR2 0)
		set(HAVE_MSA 0)
		set(HAVE_MMI 0)
	endif()
endif()

# Skipping PPC at lines 4265-4324, since PPSSPP is little endian only
# To Do: should probably revisit this section as little endian PPC exists

# To Do: revisit lines 4326-4335, re SPARC; skipped for now since we're not adding cpuflags yet

# x86 - starting at line 4337 of ffmpeg's configure script
if (${ARCH} STREQUAL "x86")
	if (${CPU_NAME} MATCHES "i[345]86|pentium")
		set(HAVE_I686 0)
		set(HAVE_MMX 0)
		# To Do - set appropriate cpuflags
	elseif (${CPU_NAME} MATCHES "pentium-mmx|k6|k6-[23]|winchip-c6|winchip2|c3")
		set(HAVE_I686 0)
	elseif (${CPU_NAME} MATCHES "i686|pentiumpro|pentium[23]|pentium-m|athlon|athlon-tbird|athlon-4|athlon-[mx]p|athlon64*|k8*|opteron*|athlon-fx|core*|atom|bonnell|nehalem|westmere|silvermont|sandybridge|ivybridge|haswell|broadwell|amdfam10|barcelona|b[dt]ver*")
		set(HAVE_I686 1)
		set(HAVE_FAST_CMOV 1)
	elseif (${CPU_NAME} MATCHES "pentium4|pentium4m|prescott|nocona")
		set(HAVE_I686 1)
		set(HAVE_FAST_CMOV 0)
	endif()
endif()

# To do: lines 4367-4371, adding cflags, asflags, and ldflags based on added cpuflags

# To do: go back and look for more 'enable' and 'disable' lines and assign as appropriate to HAVE_ variables

# Skipping the 2 checks at lines 4389 and 4392 as CPPFLAGS are N/A with cmake. If we need CPPFLAGS, however, we can probably just add these to CFLAGS...

# 64 vs 32-bit subarch checks at lines 4409-4447 of ffmpeg's configure script
if (${ARCH} MATCHES "aarch64|alpha|ia64")
	# To do: add spic flag
elseif (${ARCH} MATCHES "mips")
	check_64bit(mips mips64 "_MIPS_SIM > 1" MIPS_SUBARCH)
	if (${MIPS_SUBARCH} STREQUAL "mips64")
		set(ARCH_MIPS64 1)
	endif()
	# To do: add ppc, s390, and sparc conditionals (lines 4421-4432)
elseif (${ARCH} MATCHES "x86")
	check_64bit(x86_32 x86_64 "sizeof(void *) > 4" X86_SUBARCH)
	if (${X86_SUBARCH} STREQUAL "x86_64")
		set(ARCH_X86_64 1)
	else()
		set(ARCH_X86_32 1)
	endif()
endif()

# To Do: review lines 4452-4704 for OS-specific flags

# To Do: review lines 4728-4841 for probe_libc function

# Check for PIC - see line 4845 of ffmpeg's configure script
set(CONFIG_PIC 1)
check_cpp_condition(pic "stdlib.h" "defined(__PIC__) || defined(__pic__) || defined(PIC)" CONFIG_PIC)
# FIXME: ffmpeg's configure script gets passing test results on my system--yet this check fails; but it's clearly not defined in stdlib.h so I don't know how it passed with configure!
# For now, default to "1" since the vast majority of build environments support/require PIC
# To Do: per lines 4900-4912, add appropriate cflags and asflags (cppflags?) if PIC is enabled

set(HAVE_INLINE_ASM 0)
check_cc(inline_asm "void foo(void) { __asm__ volatile (\"\" ::); }" HAVE_INLINE_ASM)

# Line 4933
set(HAVE_PRAGMA_DEPRECATED 0)
check_cc(pragma_deprecated "void foo(void) { _Pragma(\"GCC diagnostic ignored \"-Wdeprecated-declarations\"\") }" HAVE_PRAGMA_DEPRECATED)
# FIXME: ffmpeg's configure script gets passing test results on my system--yet this check fails

set(HAVE_ATTRIBUTE_PACKED 0)
check_cc(attribute_packed "struct { int x; } __attribute__((packed)) x;" HAVE_ATTRIBUTE_PACKED)

set(HAVE_ATTRIBUTE_MAY_ALIAS 0)
check_cc(attribute_may_alias "union { int x; } __attribute__((may_alias)) x;" HAVE_ATTRIBUTE_MAY_ALIAS)

# Skipping endian test at lines 4945-4952 since PPSSPP is little endian only

# Note: this check should only work on aarch64, arm, and ppc altivec
check_gas(gas HAVE_GNU_AS)
# To Do: might need to add more related to check_gas() function starting at line 4954 of ffmpeg's configure script

# Inline ASM labels
set(HAVE_INLINE_ASM_LABELS 0)
check_inline_asm(inline_asm_labels "\"1:\\n\"" HAVE_INLINE_ASM_LABELS)
set(HAVE_INLINE_ASM_NONLOCAL_LABELS 0)
check_inline_asm(inline_asm_nonlocal_labels "\"Label:\\n\"" HAVE_INLINE_ASM_NONLOCAL_LABELS)

if (${ARCH} STREQUAL "aarch64")
	# To Do: fix check_insn() function, implement the checks at lines 5005-5011
	check_insn(armv8 "prfm   pldl1strm, [x0]" HAVE_ARMV8 HAVE_ARMV8_INLINE HAVE_ARMV8_EXTERNAL)
	check_insn(neon "ext   v0.8B, v0.8B, v1.8B, #1" HAVE_NEON HAVE_NEON_INLINE HAVE_NEON_EXTERNAL)
	check_insn(vfp "fmadd d0,    d0,    d1,    d2" HAVE_VFP HAVE_VFP_INLINE HAVE_VFP_EXTERNAL)
elseif (${ARCH} STREQUAL "arm")
	if (MSVC)
		check_cpp_condition(thumb1 "stddef.h" "defined _M_ARMT" CONFIG_THUMB)
	endif()
	check_cpp_condition(thumb_defined "stddef.h" "defined __thumb__" THUMB_DEFINED)
	if (THUMB_DEFINED)
		check_cc(thumb "float func(float a, float b){ return a+b; }" CONFIG_THUMB)
	endif()
	# To Do: line 5025 - check cflags and set appropriately if CONFIG_THUMB is true
	check_cpp_condition(vfp_args1 "stddef.h" "defined __ARM_PCS_VFP" HAVE_VFP_ARGS)
	if (NOT HAVE_VFP_ARGS)
		check_cpp_condition(vfp_args2 "stddef.h" "defined _M_ARM_FP && _M_ARM_FP >= 30" HAVE_VFP_ARGS)
	endif()
	# To do: a second if (NOT HAVE_VFP_ARGS), lines 5031-5037, with multiple chained checks
	check_insn(armv5te "qadd r0, r0, r0" HAVE_ARMV5TE HAVE_ARMV5TE_INLINE HAVE_ARMV5TE_EXTERNAL)
	check_insn(armv6 "sadd16 r0, r0, r0" HAVE_ARMV6 HAVE_ARMV6_INLINE HAVE_ARMV6_EXTERNAL)
	check_insn(armv6t2 "movt r0, #0" HAVE_ARMV6T2 HAVE_ARMV6T2_INLINE HAVE_ARMV6T2_EXTERNAL)
	check_insn(neon "vadd.i16 q0, q0, q0" HAVE_NEON HAVE_NEON_INLINE HAVE_NEON_EXTERNAL)
	check_insn(vfp "fadds s0, s0, s0" HAVE_VFP HAVE_VFP_INLINE HAVE_VFP_EXTERNAL)
	check_insn(vfpv3 "vmov.f32 s0, #1.0" HAVE_VFPV3 HAVE_VFPV3_INLINE HAVE_VFPV3_EXTERNAL)
	check_insn(setend "setend be" HAVE_SETEND HAVE_SETEND_INLINE HAVE_SETEND_EXTERNAL)
	# Note: The above 7 only get enabled on Linux and Android, per lines 5050-5052
	check_inline_asm(asm_mod_q "\"add r0, %Q0, %R0\" :: \"r\"((long long)0)\"" HAVE_ASM_MOD_Q)
    check_as(as_dn_directive "ra .dn d0.i16\n.unreq ra" HAVE_AS_DN_DIRECTIVE)
	# I don't think I need to worry about lines 5061-5066
elseif (${ARCH} STREQUAL "mips")	# Technically these checks should only run if HAVE_ LOONGSON2, LOONGSON3, MMI
	check_inline_asm(loongson2 "\"dmult.g $8, $9, $10\"" HAVE_LOONGSON2_INLINE)
	check_inline_asm(loongson3 "\"gsldxc1 $f0, 0($2, $3)\"" HAVE_LOONGSON3_INLINE)
	check_inline_asm(mmi "\"punpcklhw $f0, $f0, $f0\"" HAVE_MMI_INLINE)
	if (ARCH_MIPS64)	# Again, these checks should conditionally run if HAVE_ MIPS64R6, MIPS64R2, etc.
		check_inline_asm_flags(mips64r6 "\"dlsa $0, $0, $0, 1\"" HAVE_MIPS64R6_INLINE) # To Do: deal with '-mips64r6' flag if check passes
		check_inline_asm_flags(mips64r2 "\"dext $0, $0, 0, 1\"" HAVE_MIPS64R2_INLINE)
		if (NOT HAVE_MIPS64R6 AND NOT HAVE_MIPS64R2)
			check_inline_asm_flags(mips64r1 "\"daddi $0, $0, 0\"" HAVE_MIPS64R1_INLINE)
		endif()
	else()
		check_inline_asm_flags(mips32r6 "\"aui $0, $0, 0\"" HAVE_MIPS32R6_INLINE)
		check_inline_asm_flags(mips32r5 "\"eretnc\"" HAVE_MIPS32R5_INLINE)
		check_inline_asm_flags(mips32r2 "\"ext $0, $0, 0, 1\"" HAVE_MIPS32R2_INLINE)
		if (NOT HAVE_MIPS32R6 AND NOT HAVE_MIPS32R5 AND NOT HAVE_MIPS32R2)
			check_inline_asm_flags(mips32r1 "\"addi $0, $0, 0\"" HAVE_MIPS32R1_INLINE)
		endif()
	endif()
	check_inline_asm_flags(mipsfpu "\"cvt.d.l $f0, $f2\"" HAVE_MIPSFPU_INLINE)
	if (HAVE_MIPSFPU)
		if (HAVE_MIPS32R6 OR HAVE_MIPS32R6 OR HAVE_MIPS64R6)
			check_inline_asm_flags(mipsfpu "\"cvt.d.l $f0, $f1\"" HAVE_MIPSFPU_INLINE)
		elseif (HAVE_MSA)
			check_inline_asm_flags(msa "\"addvi.b $w0, $w1, 1\"" HAVE_MSA_INLINE1)
			if (HAVE_MSA_INLINE1)
				check_header(msa "msa.h" HAVE_MSA_INLINE)
			endif()
		endif()
	endif()
	if (HAVE_MIPSDSP)
		check_inline_asm_flags(mipsdsp "\"addu.qb $t0, $t1, $t2\"" HAVE_MIPSDSP_INLINE)
	endif()
	if (HAVE_MIPSDSP2)
		check_inline_asm_flags(mipsdspr2 "\"absq_s.qb $t0, $t1\"" HAVE_MIPSDSP2_INLINE)
	endif()
# Note: skipping parisc and ppc, lines 5092-5136
elseif (${ARCH} STREQUAL "x86")
	check_builtin(rdtsc "<intrin.h>" "__rdtsc()" HAVE_RDTSC)
	check_builtin (mm_empty "<mmintrin.h>" "_mm_empty()" HAVE_MM_EMPTY)
	set(HAVE_LOCAL_ALIGNED_8 1)
	set(HAVE_LOCAL_ALIGNED_16 1)
	set(HAVE_LOCAL_ALIGNED_32 1)
	check_exec_crash(ebp "volatile int i=0\;\n__asm__ volatile (\"xorl %%ebp, %%ebp\" ::: \"%ebp\")\;\nreturn i\;" HAVE_EBP_AVAILABLE)
	check_inline_asm(ebx_available "\"\"::\"b\"(0)" HAVE_EBX_AVAILABLE1)
	if (HAVE_EBX_AVAILABLE1)
		check_inline_asm(ebx_available "\"\":::\"%ebx\"" HAVE_EBX_AVAILABLE)
	endif()
	check_inline_asm(xmm_clobbers "\"\":::\"%xmm0\"" HAVE_XMM_CLOBBERS)
	check_inline_asm(inline_asm_direct_symbol_refs "\"movl '$extern_prefix'test, %eax\"" HAVE_INLINE_ASM_DIRECT_SYMBOL_REFS)
	if (NOT HAVE_INLINE_ASM_DIRECT_SYMBOL_REFS)
		check_inline_asm(inline_asm_direct_symbol_refs "\"movl '$extern_prefix'test(%rip), %eax\"" HAVE_INLINE_ASM_DIRECT_SYMBOL_REFS)
	endif()
	check_inline_asm(ssse3_inline "\"pabsw %xmm0, %xmm0\"" HAVE_SSSE3_INLINE)
	check_inline_asm(mmxext_inline "\"pmaxub %mm0, %mm1\"" HAVE_MMXEXT_INLINE)
	# To Do: set yasm object format if needed--see lines 5173-5180
	# To Do: set appropriate YASM flags--see lines 5185-5188
	check_yasm(yasm "movbe ecx, [5]" HAVE_YASM)
	if (HAVE_YASM)
		check_yasm(avx2_external "vextracti128 xmm0, ymm0, 0" HAVE_AVX2_EXTERNAL)
		check_yasm(xop_external "vpmacsdd xmm0, xmm1, xmm2, xmm3" HAVE_XOP_EXTERNAL)
		check_yasm(fma4_external "vfmaddps ymm0, ymm1, ymm2, ymm3" HAVE_FMA4_EXTERNAL)
		check_yasm(cpunop "CPU amdnop" HAVE_CPUNOP_EXTERNAL)
	endif()
	if (${CPU_NAME} MATCHES "athlon*|opteron*|k8*|pentium|pentium-mmx|prescott|nocona|atom|geode")
		set(HAVE_FAST_CLZ 0)
	else()
		set(HAVE_FAST_CLZ 1)
	endif()
endif()

# Line 5207
check_code(intrinsics_neon cc "<arm_neon.h>" "int16x8_t test = vdupq_n_s16(0)" HAVE_INTRINSICS_NEON)

# To Do: implement check_ld_flags, only if needed. See lines 5209-5210

# Note: modifying check_func dlopen test as we don't need decklink, frei0r, ladspa, or nvenc
check_func(dlopen "dlopen" HAVE_DLOPEN)	# Note: we could modify check_func to allow a shared lib arg vice passing ""

# Skipping lines 5225-5262 as we disabled 'network'

check_builtin(atomic_cas_ptr "<atomic.h>" "void **ptr\; void *oldval, *newval\; atomic_cas_ptr(ptr, oldval, newval)" HAVE_ATOMIC_CAS_PTR)
check_builtin(atomic_compare_exchange "" "int *ptr, *oldval\; int newval\; __atomic_compare_exchange_n(ptr, oldval, newval, 0, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)" HAVE_ATOMIC_COMPARE_EXCHANGE)
check_builtin(machine_rw_barrier "<mbarrier.h>" "__machine_rw_barrier()" HAVE_MACHINE_RW_BARRIER)
check_builtin(MemoryBarrier "<windows.h>" "MemoryBarrier()" HAVE_MEMORYBARRIER)
check_builtin(sarestart "<signal.h>" "SA_RESTART" HAVE_SARESTART)
check_builtin(sync_val_compare_and_swap "" "int *ptr\; int oldval, newval\; __sync_val_compare_and_swap(ptr, oldval, newval)" HAVE_SYNC_VAL_COMPARE_AND_SWAP)
check_builtin(gmtime_r "<time.h>" "time_t *time\; struct tm *tm\; gmtime_r(time, tm)" HAVE_GMTIME_R)
check_builtin(localtime_r "<time.h>" "time_t *time\; struct tm *tm\; localtime_r(time, tm)" HAVE_LOCALTIME_R)

check_func_headers(aligned_malloc "<malloc.h>" "_aligned_malloc" "" HAVE_ALIGNED_MALLOC)
# Note: we don't have a 'custom_allocator' option set, so we don't need a malloc_prefix
check_func(memalign "memalign" HAVE_MEMALIGN)
check_func(posix_memalign "posix_memalign" HAVE_POSIX_MEMALIGN)
check_func(access "access" HAVE_ACCESS)
check_func_headers(arc4random "<stdlib.h>" "arc4random" "" HAVE_ARC4RANDOM)
check_func_headers(clock_gettime "<time.h>" "clock_gettime" "" HAVE_CLOCK_GETTIME)
if (NOT HAVE_CLOCK_GETTIME)
	check_func_headers(clock_gettime "<time.h>" "clock_gettime" "-lrt" HAVE_CLOCK_GETTIME)
	# To Do: if this fallback check passes, need to add "-lrt" as an extra lib
endif()
check_func(fcntl "fcntl" HAVE_FCNTL)
check_func(fork "fork" HAVE_FORK)
check_func(gethrtime "gethrtime" HAVE_GETHRTIME)
check_func(getopt "getopt" HAVE_GETOPT)
check_func(getrusage "getrusage" HAVE_GETRUSAGE)
check_func(gettimeofday "gettimeofday" HAVE_GETTIMEOFDAY)
check_func(isatty "isatty" HAVE_ISATTY)
check_func(mach_absolute_time "mach_absolute_time" HAVE_MACH_ABSOLUTE_TIME)
check_func(mkstemp "mkstemp" HAVE_MKSTEMP)
check_func(mmap "mmap" HAVE_MMAP)
check_func(mprotect "mprotect" HAVE_MPROTECT)
check_func_headers(nanosleep "<time.h>" "nanosleep" "" HAVE_NANOSLEEP)
if (NOT HAVE_NANOSLEEP)
	check_func_headers(nanosleep "<time.h>" "nanosleep" "-lrt" HAVE_NANOSLEEP)
	# To Do: if this fallback check passes, need to add "-lrt" as an extra lib
endif()
check_func(sched_getaffinity "sched_getaffinity" HAVE_SCHED_GETAFFINITY)
check_func(setrlimit "setrlimit" HAVE_SETRLIMIT)
check_struct(st_mtim.tv_nsec "<sys/stat.h>" "struct stat" st_mtim.tv_nsec HAVE_STRUCT_STAT_ST_MTIM_TV_NSEC)
# To Do: check the above; in ffmpeg's configure script, there's a -D_BSD_SOURCE flag added to the end. Supposedly
# that's been deprecated since 2014 and the new flag is -D_DEFAULT_SOURCE to enable various extensions to POSIX
check_func(strerror_r "strerror_r" HAVE_STRERROR_R)
check_func(sysconf "sysconf" HAVE_SYSCONF)
check_func(sysctl "sysctl" HAVE_SYSCTL)
check_func(usleep "usleep" HAVE_USLEEP)

check_func_headers(kbhit "<conio.h>" "kbhit" "" HAVE_KBHIT)
check_func_headers(setmode "<io.h>" "setmode" "" HAVE_SETMODE)
check_func_headers(lzo1x_999_compress "<lzo/lzo1x.h>" "lzo1x_999_compress" "" HAVE_LZO1X_999_COMPRESS)
check_func_headers(getenv "<stdlib.h>" "getenv" "" HAVE_GETENV)
check_func_headers(lstat "<sys/stat.h>" "lstat" "" HAVE_LSTAT)

# Note: lines 5318-5328 all rely on windows.h header--I'm not sure why they're not inside a Windows-only conditional
check_header(windows "windows.h" HAVE_WINDOWS_H)	# Note: check repeated at line 5358 so doing only here instead
if (HAVE_WINDOWS_H)
	check_func_headers(cotaskmemfree "<windows.h>" "CoTaskMemFree" "-lole32" HAVE_COTASKMEMFREE)
	check_func_headers(getprocessaffinitymask "<windows.h>" "GetProcessAffinityMask" "" HAVE_GETPROCESSAFFINITYMASK)
	check_func_headers(getprocesstimes "<windows.h>" "GetProcessTimes" "" HAVE_GETPROCESSTIMES)
	check_func_headers(getsystemtimeasfiletime "<windows.h>" "GetSystemTimeAsFileTime" "" HAVE_GETSYSTEMTIMEASFILETIME)
	check_func_headers(mapviewoffile "<windows.h>" "MapViewOfFile" "" HAVE_MAPVIEWOFFILE)
	check_func_headers(peeknamedpipe "<windows.h>" "PeekNamedPipe" "" HAVE_PEEKNAMEDPIPE)
	check_func_headers(setconsoletextattribute "<windows.h>" "SetConsoleTextAttribute" "" HAVE_SETCONSOLETEXTATTRIBUTE)
	check_func_headers(setconsolectrlhandler "<windows.h>" "SetConsoleCtrlHandler" "" HAVE_SETCONSOLECTRLHANDLER)
	check_func_headers(sleep "<windows.h>" "Sleep" "" HAVE_SLEEP)
	check_func_headers(virtualalloc "<windows.h>" "VirtualAlloc" "" HAVE_VIRTUALALLOC)
	check_struct(condition_variable_ptr "<windows.h>" "CONDITION_VARIABLE" "Ptr" HAVE_CONDITION_VARIABLE_PTR)
endif()
check_func_headers(glob "<glob.h>" "glob" "" HAVE_GLOB)

# Xlib check at lines 5330-5331
string(APPEND CMAKE_C_FLAGS "-I${X11_Xlib_INCLUDE_PATH}")
string(APPEND CMAKE_CXX_FLAGS "-I${X11_Xlib_INCLUDE_PATH}")	# Note: needed for check_header to find XvMClib
string(APPEND CMAKE_EXE_LINKER_FLAGS "-L/usr/local/lib")
check_func_headers(xlib "<X11/Xlib.h>;<X11/extensions/Xvlib.h>" "XvGetPortAttribute" "-lXv;-lX11;-lXext" CONFIG_XLIB)
# To Do: handle appending of CMAKE_C_FLAGS and CMAKE_EXE_LINKER_FLAGS in a more elegant manner (although this might also serve as a model for adding compiler and linker flags in a similar way to ffmpeg's configure script throughout)

check_header(direct "direct.h" HAVE_DIRECT_H)
check_header(dirent "dirent.h" HAVE_DIRENT_H)
check_header(dlfcn "dlfcn.h" HAVE_DLFCN_H)
check_header(d3d11 "d3d11.h" HAVE_D3D11_H)
check_header(dxva "dxva.h" HAVE_DXVA_H)
check_header(dxva2api "dxva2api.h" HAVE_DXVA2API_H)	# -D_WIN32_WINNT=0x0600
check_header(io "io.h" HAVE_IO_H)
check_header(libcrystalhd_if "libcrystalhd/libcrystalhd_if.h" CONFIG_LIBCRYSTALHD)	# disabled so unnecessary check
check_header(mach_time "mach/mach_time.h" HAVE_MACH_MACH_TIME_H)
check_header(malloc "malloc.h" HAVE_MALLOC_H)
check_header(udplite "net/udplite.h" HAVE_UDPLITE_H)
check_header(poll "poll.h" HAVE_POLL_H)
check_header(mman "sys/mman.h" HAVE_SYS_MMAN_H)
check_header(param "sys/param.h" HAVE_SYS_PARAM_H)
check_header(resource "sys/resource.h" HAVE_SYS_RESOURCE_H)
check_header(select "sys/select.h" HAVE_SYS_SELECT_H)
check_header(time "sys/time.h" HAVE_SYS_TIME_H)
check_header(un "sys/un.h" HAVE_SYS_UN_H)
check_header(termios "sys/termios.h" HAVE_SYS_TERMIOS_H)
check_header(unistd "sys/unistd.h" HAVE_SYS_UNISTD_H)
check_header(valgrind "valgrind/valgrind.h" HAVE_VALGRIND_VALGRIND_H)
check_header(vdpau "vdpau/vdpau.h" CONFIG_VDPAU)	# But should we? Line 5773 check seems more definitive
check_header(vdpau_x11 "vdpau/vdpau_x11.h" HAVE_VDPAU_X11)
check_header(VDADecoder "VideoDecodeAcceleration/VDADecoder.h" CONFIG_VDA)	# disabled so unnecessary check
check_header(VideoToolbox "VideoToolbox/VideoToolbox.h" CONFIG_VIDEOTOOLBOX) # disabled so unnecessary check
# Note: we already checked for windows.h header above so skipping here
check_header(XvMClib "X11/extensions/XvMClib.h" CONFIG_XVMC)	# Note: check fails to do compiler error!
check_header(types "asm/types.h" HAVE_ASM_TYPES_H)

# Line 5362
check_lib2(commandlinetoargvw "<windows.h>;<shellapi.h>" "CommandLineToArgvW" "-shell32" HAVE_COMMANDLINETOARGVW)
check_lib2(cryptgenrandom "<windows.h>;<wincrypt.h>" "CryptGenRandom" "-ladvapi32" HAVE_CRYPTGENRANDOM)
check_lib2(getprocessmemoryinfo "<windows.h>;<psapi.h>" "GetProcessMemoryInfo" "-lpsapi" HAVE_GETPROCESSMEMORYINFO)
check_lib(utgetostypefromstring "CoreServices/CoreServices.h" "UTGetOSTypeFromString" HAVE_UTGETOSTYPEFROMSTRING)
# To Do: the above has a follow-up: "-framework CoreServices"
check_struct(ru_maxrss "<sys/time.h>;<sys/resource.h>" "struct rusage" ru_maxrss HAVE_STRUCT_RUSAGE_RU_MAXRSS)

check_type(dxva_picparams_hevc "<windows.h>;<dxva.h>" "DXVA_PicParams_HEVC" DXVA_PICPARAMS_HEVC) # To do: ffmpeg configure doesn't set a variable, it sets the following flags: -DWINAPI_FAMILY=WINAPI_FAMILY_DESKTOP_APP -D_CRT_BUILD_DESKTOP_APP=0


check_type(dxva_picparams_vp9 "<windows.h>;<dxva.h>" "DXVA_PicParams_VP9" DXVA_PICPARAMS_VP9) # To do: set the following flags: -DWINAPI_FAMILY=WINAPI_FAMILY_DESKTOP_APP -D_CRT_BUILD_DESKTOP_APP=0
check_type(id3d11videodecoder "<windows.h>;<d3d11.h>" "ID3D11VideoDecoder" ID3D11VIDEODECODER) # To do: something
check_type(id3d11videocontext "<windows.h>;<d3d11.h>" "ID3D11VideoContext" ID3D11VIDEOCONTEXT) # To do: something
check_type(dxva2_configpicturedecode "<d3d9.h>;<dxva2api.h>" "DXVA2_ConfigPictureDecode" DXVA2_CONFIGPICTUREDECODE)
# To do: set flag -D_WIN32_WINNT=0x0602

check_type(vapictureparameterbufferhevc "<va/va.h>" "VAPictureParameterBufferHEVC" VAPICTUREPARAMETERBUFFERHEVC)
# To do: something with the above
check_type(vadecpictureparameterbuffervp9 "<va/va.h>" "VADecPictureParameterBufferVP9" VADECPICTUREPARAMETERBUFFERVP9)
# To do: something with the above

check_type(vdppictureinfohevc "<vdpau/vdpau.h>" "VdpPictureInfoHEVC" VDPPICTUREINFOHEVC) # To do: something

check_cpp_condition(winrt "windows.h" "!WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)" HAVE_WINRT) 
# To Do: enable WINRT if true--simply adding the variable to the end of the check might do it

# pthreads vs w32threads - see lines 5382-5389. Note: since we're hardcoding configure 'options', slight change here
if (HAVE_WINDOWS_H)	# Enable w32threads if either of configure script's conditions are met; deal with pthreads later
	check_func_headers(beginthreadex "<windows.h>;<process.h>" "_beginthreadex" "" HAVE_W32THREADS)
	if (NOT HAVE_W32THREADS)
		if (HAVE_WINRT)
			check_func_headers(createthread "<windows.h>" "CreateThread" "" HAVE_W32THREADS)
		endif()
	endif()
endif()

# pthreads - see lines 5391-5414
if (NOT HAVE_W32THREADS AND NOT HAVE_OS2THREADS)
	check_func(pthread_join "pthread_join" HAVE_PTHREAD_JOIN)	# may need to modify check_func to add a lib arg
	check_func(pthread_create "pthread_create" HAVE_PTHREAD_CREATE) # we haven't set any cflags or extralibs
	check_func(pthread_cancel "pthread_cancel" HAVE_PTHREAD_CANCEL)
	if (HAVE_PTHREAD_JOIN AND HAVE_PTHREAD_CREATE AND HAVE_PTHREAD_CANCEL)
		set(HAVE_PTHREADS 1)
	endif()
endif()
# To Do: address setting of cflags, extralibs, checks involving linked libs that check_func doesn't currently allow
# FIXME: the second check, for pthread_create, currently fails with linker error 'ld: error: undefined symbol: pthread_create'

# Note: the following checks at lines 5421-5423 require a lib argument; ffmpeg's configure uses check_lib for the
# first check, which fails due to lack of a lib argument. Using check_lib2 instead, like the following 2 checks
check_lib2(zlibversion "<zlib.h>" "zlibVersion" "-lz" CONFIG_ZLIB)
check_lib2(bz2_bzlibversion "<bzlib.h>" "BZ2_bzlibVersion" "-lbz2" CONFIG_BZLIB)
check_lib2(lzma_version_number "<lzma.h>" "lzma_version_number" "-llzma" CONFIG_LZMA)
# To Do: add appropriate external libs if the above checks pass; or do we want to disable some/all of the above?

check_lib2(sin "<math.h>" "sin" "-lm" WHY)
# To Do: this check doesn't set any variables, but seems to add an alias "-lm" for LIBM
check_lib2(dtscrystalhdversion "<libcrystalhd/libcrystalhd_if.h>" "DtsCrystalHDVersion" "-lcrystalhd" CONFIG_CRYSTALHD)

# check all listed math_funcs - see lines 5434-5436
set(mathfuncs "atanf;atan2f;cbrt;cbrtf;copysign;cosf;erf;exp2;exp2f;expf;hypot;isfinite;isinf;isnan;ldexpf;llrint;llrintf;log2;log2f;log10f;lrint;lrintf;powf;rint;round;roundf;sinf;trunc;truncf")

foreach(func IN LISTS mathfuncs )
	string(TOUPPER ${func} uppercase_func)
	check_mathfunc(${func} ${func} "-lm" HAVE_${uppercase_func})
endforeach()

# check all listed complex_funcs - see lines 5438-5440. Note: there are only 2, so no need to iterate through a list
check_complexfunc(cabs cabs HAVE_CABS)
check_complexfunc(cexp cexp HAVE_CEXP)

# Skip a bunch of unwanted options. Resume checks at line 5674, videoio
check_header(sys_videoio "sys/videoio.h" HAVE_SYS_VIDEOIO_H)
# Note: skipping line 5675 check as we don't need v4l2 for ppsspp-ffmpeg

check_type(ibasefilter "<dshow.h>" "IBaseFilter" CONFIG_DSHOW_INDEV)	# Note: not sure this is the right variable

# Note: skipping lines 5684-5691 as I don't believe we need/want any of these

check_header(sndio "sndio.h" HAVE_SNDIO_H)
check_struct(audio_buf_info "<sys/soundcard.h>" "audio_buf_info bytes;" "audio_buf_info bytes" HAVE_SYS_SOUNDCARD_H)
if (NOT HAVE_SYS_SOUNDCARD_H)
	check_cc(sys_soundcard "#include <sys/soundcard.h>\naudio_buf_info abc;" HAVE_SYS_SOUNDCARD_H)
	# To Do: should deal with "add_cppflags -D__BSD_VISIBLE -D__XSI_VISIBLE" although this fallback check passes
	# on my system even without them
endif()
check_header(soundcard "soundcard.h" HAVE_SOUNDCARD_H)

# Note: skipping more checks since we disabled those features for ppsspp-ffmpeg

# Xlib: see lines 5718-5719
check_lib2(xopendisplay "<X11/Xlib.h>" "XOpenDisplay" "-lX11" HAVE_XLIB)

# Note: skipping lines 5721-5745 for now; find_package(X11) should've already located xcb; we could write an alternate
# check to make sure its header is found here or the like

# dxva2api_h - see line 5755
check_cc(dxva2api_cobj "#define _WIN32_WINNT 0x0600\n#define COBJMACROS\n#include <windows.h>\n#include <d3d9.h>\n#include <dxva2api.h>\nint main(void) { IDirectXVideoDecoder *o = NULL; IDirectXVideoDecoder_Release(o); return 0; }" HAVE_DXVA2API_COBJ)

# VAAPI - see line 5765
check_lib2(vaInitialize "<va/va.h >" "vaInitialize" "-lva" CONFIG_VAAPI) # To Do: fix include paths--/usr/local
if (CONFIG_VAAPI AND HAVE_XLIB)
	check_lib2(vaGetDisplay "<va/va.h>;<va/va_x11.h>" "vaGetDisplay" "-lva;-lva-x11" HAVE_VAAPI_X11)
endif()
# FIXME: above check fails due to failure to search /usr/local/include
check_cpp_condition(vdp_decoder_profile "vdpau/vdpau.h" "defined VDP_DECODER_PROFILE_MPEG4_PART2_ASP" CONFIG_VDPAU)
if (CONFIG_VDPAU AND HAVE_XLIB)
	check_func_headers(vdp_device_create_x11 "<vdpau/vdpau.h>;<vdpau/vdpau_x11.h>" "vdp_device_create_x11" "-lvdpau" HAVE_VDPAU_X11)
endif()

# To Do: lots of flags-related checks on lines 5787-5855

# symver_asm_label - see line 5857
check_cc(symver_asm_label [[void ff_foo(void) __asm__ ("av_foo@VERSION");
void ff_foo(void) { ${inline_asm+__asm__($quotes);} }]] HAVE_SYMVER_ASM_LABEL)
check_cc(symver_gnu_asm [[__asm__(".symver ff_foo,av_foo@VERSION");
void ff_foo(void) {}]] HAVE_SYMVER_GNU_ASM)

# To do: more skipped flags checks

# Threads - see line 6045
# To Do: test for atomics_native?
# Quick-and-dirty for now: FIXME: enable pthreads and disable all others
set(HAVE_PTHREADS 1)
set(HAVE_THREADS 1)

# Run convenience function to set "0" for any variables not set to "1"
set(settings-list "ARCH_AARCH64;ARCH_ALPHA;ARCH_AMD64;ARCH_ARM;ARCH_AVR32;ARCH_AVR32_AP;ARCH_AVR32_UC;ARCH_BFIN;ARCH_IA64;ARCH_M68K;ARCH_MIPS;ARCH_MIPS64;ARCH_PARISC;ARCH_PPC;ARCH_PPC64;ARCH_S390;ARCH_SH4;ARCH_SPARC;ARCH_SPARC64;ARCH_TILEGX;ARCH_TILEPRO;ARCH_TOMI;ARCH_X86;ARCH_X86_32;ARCH_X86_64;HAVE_ARMV5TE;HAVE_ARMV6;HAVE_ARMV6T2;HAVE_ARMV8;HAVE_NEON;HAVE_VFP;HAVE_VFPV3;HAVE_SETEND;HAVE_ALTIVEC;HAVE_DCBZL;HAVE_LDBRX;HAVE_POWER8;HAVE_PPC4XX;HAVE_VSX;HAVE_AESNI;HAVE_AMD3DNOW;HAVE_AMD3DNOWEXT;HAVE_AVX;HAVE_AVX2;HAVE_FMA3;HAVE_FMA4;HAVE_MMX;HAVE_MMXEXT;HAVE_SSE;HAVE_SSE2;HAVE_SSE3;HAVE_SSE4;HAVE_SSE42;HAVE_SSSE3;HAVE_XOP;HAVE_CPUNOP;HAVE_I686;HAVE_MIPSFPU;HAVE_MIPS32R2;HAVE_MIPS32R5;HAVE_MIPS64R2;HAVE_MIPS32R6;HAVE_MIPS64R6;HAVE_MIPSDSP;HAVE_MIPSDSPR2;HAVE_MSA;HAVE_LOONGSON2;HAVE_LOONGSON3;HAVE_MMI;HAVE_ARMV5TE_EXTERNAL;HAVE_ARMV6_EXTERNAL;HAVE_ARMV6T2_EXTERNAL;HAVE_ARMV8_EXTERNAL;HAVE_NEON_EXTERNAL;HAVE_VFP_EXTERNAL;HAVE_VFPV3_EXTERNAL;HAVE_SETEND_EXTERNAL;HAVE_ALTIVEC_EXTERNAL;HAVE_DCBZL_EXTERNAL;HAVE_LDBRX_EXTERNAL;HAVE_POWER8_EXTERNAL;HAVE_PPC4XX_EXTERNAL;HAVE_VSX_EXTERNAL;HAVE_AESNI_EXTERNAL;HAVE_AMD3DNOW_EXTERNAL;HAVE_AMD3DNOWEXT_EXTERNAL;HAVE_AVX_EXTERNAL;HAVE_AVX2_EXTERNAL;HAVE_FMA3_EXTERNAL;HAVE_FMA4_EXTERNAL;HAVE_MMX_EXTERNAL;HAVE_MMXEXT_EXTERNAL;HAVE_SSE_EXTERNAL;HAVE_SSE2_EXTERNAL;HAVE_SSE3_EXTERNAL;HAVE_SSE4_EXTERNAL;HAVE_SSE42_EXTERNAL;HAVE_SSSE3_EXTERNAL;HAVE_XOP_EXTERNAL;HAVE_CPUNOP_EXTERNAL;HAVE_I686_EXTERNAL;HAVE_MIPSFPU_EXTERNAL;HAVE_MIPS32R2_EXTERNAL;HAVE_MIPS32R5_EXTERNAL;HAVE_MIPS64R2_EXTERNAL;HAVE_MIPS32R6_EXTERNAL;HAVE_MIPS64R6_EXTERNAL;HAVE_MIPSDSP_EXTERNAL;HAVE_MIPSDSPR2_EXTERNAL;HAVE_MSA_EXTERNAL;HAVE_LOONGSON2_EXTERNAL;HAVE_LOONGSON3_EXTERNAL;HAVE_MMI_EXTERNAL;HAVE_ARMV5TE_INLINE;HAVE_ARMV6_INLINE;HAVE_ARMV6T2_INLINE;HAVE_ARMV8_INLINE;HAVE_NEON_INLINE;HAVE_VFP_INLINE;HAVE_VFPV3_INLINE;HAVE_SETEND_INLINE;HAVE_ALTIVEC_INLINE;HAVE_DCBZL_INLINE;HAVE_LDBRX_INLINE;HAVE_POWER8_INLINE;HAVE_PPC4XX_INLINE;HAVE_VSX_INLINE;HAVE_AESNI_INLINE;HAVE_AMD3DNOW_INLINE;HAVE_AMD3DNOWEXT_INLINE;HAVE_AVX_INLINE;HAVE_AVX2_INLINE;HAVE_FMA3_INLINE;HAVE_FMA4_INLINE;HAVE_MMX_INLINE;HAVE_MMXEXT_INLINE;HAVE_SSE_INLINE;HAVE_SSE2_INLINE;HAVE_SSE3_INLINE;HAVE_SSE4_INLINE;HAVE_SSE42_INLINE;HAVE_SSSE3_INLINE;HAVE_XOP_INLINE;HAVE_CPUNOP_INLINE;HAVE_I686_INLINE;HAVE_MIPSFPU_INLINE;HAVE_MIPS32R2_INLINE;HAVE_MIPS32R5_INLINE;HAVE_MIPS64R2_INLINE;HAVE_MIPS32R6_INLINE;HAVE_MIPS64R6_INLINE;HAVE_MIPSDSP_INLINE;HAVE_MIPSDSPR2_INLINE;HAVE_MSA_INLINE;HAVE_LOONGSON2_INLINE;HAVE_LOONGSON3_INLINE;HAVE_MMI_INLINE;HAVE_ALIGNED_STACK;HAVE_FAST_64BIT;HAVE_FAST_CLZ;HAVE_FAST_CMOV;HAVE_LOCAL_ALIGNED_8;HAVE_LOCAL_ALIGNED_16;HAVE_LOCAL_ALIGNED_32;HAVE_SIMD_ALIGN_16;HAVE_ATOMICS_GCC;HAVE_ATOMICS_SUNCC;HAVE_ATOMICS_WIN32;HAVE_ATOMIC_CAS_PTR;HAVE_ATOMIC_COMPARE_EXCHANGE;HAVE_MACHINE_RW_BARRIER;HAVE_MEMORYBARRIER;HAVE_MM_EMPTY;HAVE_RDTSC;HAVE_SARESTART;HAVE_SYNC_VAL_COMPARE_AND_SWAP;HAVE_CABS;HAVE_CEXP;HAVE_INLINE_ASM;HAVE_SYMVER;HAVE_YASM;HAVE_BIGENDIAN;HAVE_FAST_UNALIGNED;HAVE_INCOMPATIBLE_LIBAV_ABI;HAVE_ALSA_ASOUNDLIB_H;HAVE_ALTIVEC_H;HAVE_ARPA_INET_H;HAVE_ASM_TYPES_H;HAVE_CDIO_PARANOIA_H;HAVE_CDIO_PARANOIA_PARANOIA_H;HAVE_DEV_BKTR_IOCTL_BT848_H;HAVE_DEV_BKTR_IOCTL_METEOR_H;HAVE_DEV_IC_BT8XX_H;HAVE_DEV_VIDEO_BKTR_IOCTL_BT848_H;HAVE_DEV_VIDEO_METEOR_IOCTL_METEOR_H;HAVE_DIRECT_H;HAVE_DIRENT_H;HAVE_DLFCN_H;HAVE_D3D11_H;HAVE_DXVA_H;HAVE_ES2_GL_H;HAVE_GSM_H;HAVE_IO_H;HAVE_MACH_MACH_TIME_H;HAVE_MACHINE_IOCTL_BT848_H;HAVE_MACHINE_IOCTL_METEOR_H;HAVE_MALLOC_H;HAVE_OPENCV2_CORE_CORE_C_H;HAVE_OPENJPEG_2_1_OPENJPEG_H;HAVE_OPENJPEG_2_0_OPENJPEG_H;HAVE_OPENJPEG_1_5_OPENJPEG_H;HAVE_OPENGL_GL3_H;HAVE_POLL_H;HAVE_SNDIO_H;HAVE_SOUNDCARD_H;HAVE_SYS_MMAN_H;HAVE_SYS_PARAM_H;HAVE_SYS_RESOURCE_H;HAVE_SYS_SELECT_H;HAVE_SYS_SOUNDCARD_H;HAVE_SYS_TIME_H;HAVE_SYS_UN_H;HAVE_SYS_VIDEOIO_H;HAVE_TERMIOS_H;HAVE_UDPLITE_H;HAVE_UNISTD_H;HAVE_VALGRIND_VALGRIND_H;HAVE_WINDOWS_H;HAVE_WINSOCK2_H;HAVE_INTRINSICS_NEON;HAVE_ATANF;HAVE_ATAN2F;HAVE_CBRT;HAVE_CBRTF;HAVE_COPYSIGN;HAVE_COSF;HAVE_ERF;HAVE_EXP2;HAVE_EXP2F;HAVE_EXPF;HAVE_HYPOT;HAVE_ISFINITE;HAVE_ISINF;HAVE_ISNAN;HAVE_LDEXPF;HAVE_LLRINT;HAVE_LLRINTF;HAVE_LOG2;HAVE_LOG2F;HAVE_LOG10F;HAVE_LRINT;HAVE_LRINTF;HAVE_POWF;HAVE_RINT;HAVE_ROUND;HAVE_ROUNDF;HAVE_SINF;HAVE_TRUNC;HAVE_TRUNCF;HAVE_ACCESS;HAVE_ALIGNED_MALLOC;HAVE_ARC4RANDOM;HAVE_CLOCK_GETTIME;HAVE_CLOSESOCKET;HAVE_COMMANDLINETOARGVW;HAVE_COTASKMEMFREE;HAVE_CRYPTGENRANDOM;HAVE_DLOPEN;HAVE_FCNTL;HAVE_FLT_LIM;HAVE_FORK;HAVE_GETADDRINFO;HAVE_GETHRTIME;HAVE_GETOPT;HAVE_GETPROCESSAFFINITYMASK;HAVE_GETPROCESSMEMORYINFO;HAVE_GETPROCESSTIMES;HAVE_GETRUSAGE;HAVE_GETSYSTEMTIMEASFILETIME;HAVE_GETTIMEOFDAY;HAVE_GLOB;HAVE_GLXGETPROCADDRESS;HAVE_GMTIME_R;HAVE_INET_ATON;HAVE_ISATTY;HAVE_JACK_PORT_GET_LATENCY_RANGE;HAVE_KBHIT;HAVE_LOCALTIME_R;HAVE_LSTAT;HAVE_LZO1X_999_COMPRESS;HAVE_MACH_ABSOLUTE_TIME;HAVE_MAPVIEWOFFILE;HAVE_MEMALIGN;HAVE_MKSTEMP;HAVE_MMAP;HAVE_MPROTECT;HAVE_NANOSLEEP;HAVE_PEEKNAMEDPIPE;HAVE_POSIX_MEMALIGN;HAVE_PTHREAD_CANCEL;HAVE_SCHED_GETAFFINITY;HAVE_SETCONSOLETEXTATTRIBUTE;HAVE_SETCONSOLECTRLHANDLER;HAVE_SETMODE;HAVE_SETRLIMIT;HAVE_SLEEP;HAVE_STRERROR_R;HAVE_SYSCONF;HAVE_SYSCTL;HAVE_USLEEP;HAVE_UTGETOSTYPEFROMSTRING;HAVE_VIRTUALALLOC;HAVE_WGLGETPROCADDRESS;HAVE_PTHREADS;HAVE_OS2THREADS;HAVE_W32THREADS;HAVE_AS_DN_DIRECTIVE;HAVE_AS_FUNC;HAVE_AS_OBJECT_ARCH;HAVE_ASM_MOD_Q;HAVE_ATTRIBUTE_MAY_ALIAS;HAVE_ATTRIBUTE_PACKED;HAVE_EBP_AVAILABLE;HAVE_EBX_AVAILABLE;HAVE_GNU_AS;HAVE_GNU_WINDRES;HAVE_IBM_ASM;HAVE_INLINE_ASM_DIRECT_SYMBOL_REFS;HAVE_INLINE_ASM_LABELS;HAVE_INLINE_ASM_NONLOCAL_LABELS;HAVE_PRAGMA_DEPRECATED;HAVE_RSYNC_CONTIMEOUT;HAVE_SYMVER_ASM_LABEL;HAVE_SYMVER_GNU_ASM;HAVE_VFP_ARGS;HAVE_XFORM_ASM;HAVE_XMM_CLOBBERS;HAVE_CONDITION_VARIABLE_PTR;HAVE_SOCKLEN_T;HAVE_STRUCT_ADDRINFO;HAVE_STRUCT_GROUP_SOURCE_REQ;HAVE_STRUCT_IP_MREQ_SOURCE;HAVE_STRUCT_IPV6_MREQ;HAVE_STRUCT_POLLFD;HAVE_STRUCT_RUSAGE_RU_MAXRSS;HAVE_STRUCT_SCTP_EVENT_SUBSCRIBE;HAVE_STRUCT_SOCKADDR_IN6;HAVE_STRUCT_SOCKADDR_SA_LEN;HAVE_STRUCT_SOCKADDR_STORAGE;HAVE_STRUCT_STAT_ST_MTIM_TV_NSEC;HAVE_STRUCT_V4L2_FRMIVALENUM_DISCRETE;HAVE_ATOMICS_NATIVE;HAVE_DOS_PATHS;HAVE_DXVA2_LIB;HAVE_DXVA2API_COBJ;HAVE_LIBC_MSVCRT;HAVE_LIBDC1394_1;HAVE_LIBDC1394_2;HAVE_MAKEINFO;HAVE_MAKEINFO_HTML;HAVE_PERL;HAVE_POD2MAN;HAVE_SDL;HAVE_SECTION_DATA_REL_RO;HAVE_TEXI2HTML;HAVE_THREADS;HAVE_VAAPI_X11;HAVE_VDPAU_X11;HAVE_WINRT;HAVE_XLIB;CONFIG_BSFS;CONFIG_DECODERS;CONFIG_ENCODERS;CONFIG_HWACCELS;CONFIG_PARSERS;CONFIG_INDEVS;CONFIG_OUTDEVS;CONFIG_FILTERS;CONFIG_DEMUXERS;CONFIG_MUXERS;CONFIG_PROTOCOLS;CONFIG_DOC;CONFIG_HTMLPAGES;CONFIG_MANPAGES;CONFIG_PODPAGES;CONFIG_TXTPAGES;CONFIG_AVIO_READING_EXAMPLE;CONFIG_AVIO_DIR_CMD_EXAMPLE;CONFIG_DECODING_ENCODING_EXAMPLE;CONFIG_DEMUXING_DECODING_EXAMPLE;CONFIG_EXTRACT_MVS_EXAMPLE;CONFIG_FILTER_AUDIO_EXAMPLE;CONFIG_FILTERING_AUDIO_EXAMPLE;CONFIG_FILTERING_VIDEO_EXAMPLE;CONFIG_METADATA_EXAMPLE;CONFIG_MUXING_EXAMPLE;CONFIG_QSVDEC_EXAMPLE;CONFIG_REMUXING_EXAMPLE;CONFIG_RESAMPLING_AUDIO_EXAMPLE;CONFIG_SCALING_VIDEO_EXAMPLE;CONFIG_TRANSCODE_AAC_EXAMPLE;CONFIG_TRANSCODING_EXAMPLE;CONFIG_AVISYNTH;CONFIG_BZLIB;CONFIG_CHROMAPRINT;CONFIG_CRYSTALHD;CONFIG_DECKLINK;CONFIG_FREI0R;CONFIG_GCRYPT;CONFIG_GMP;CONFIG_GNUTLS;CONFIG_ICONV;CONFIG_LADSPA;CONFIG_LIBASS;CONFIG_LIBBLURAY;CONFIG_LIBBS2B;CONFIG_LIBCACA;CONFIG_LIBCDIO;CONFIG_LIBCELT;CONFIG_LIBDC1394;CONFIG_LIBDCADEC;CONFIG_LIBFAAC;CONFIG_LIBFDK_AAC;CONFIG_LIBFLITE;CONFIG_LIBFONTCONFIG;CONFIG_LIBFREETYPE;CONFIG_LIBFRIBIDI;CONFIG_LIBGME;CONFIG_LIBGSM;CONFIG_LIBIEC61883;CONFIG_LIBILBC;CONFIG_LIBKVAZAAR;CONFIG_LIBMFX;CONFIG_LIBMODPLUG;CONFIG_LIBMP3LAME;CONFIG_LIBNUT;CONFIG_LIBOPENCORE_AMRNB;CONFIG_LIBOPENCORE_AMRWB;CONFIG_LIBOPENCV;CONFIG_LIBOPENH264;CONFIG_LIBOPENJPEG;CONFIG_LIBOPUS;CONFIG_LIBPULSE;CONFIG_LIBRTMP;CONFIG_LIBRUBBERBAND;CONFIG_LIBSCHROEDINGER;CONFIG_LIBSHINE;CONFIG_LIBSMBCLIENT;CONFIG_LIBSNAPPY;CONFIG_LIBSOXR;CONFIG_LIBSPEEX;CONFIG_LIBSSH;CONFIG_LIBTESSERACT;CONFIG_LIBTHEORA;CONFIG_LIBTWOLAME;CONFIG_LIBUTVIDEO;CONFIG_LIBV4L2;CONFIG_LIBVIDSTAB;CONFIG_LIBVO_AMRWBENC;CONFIG_LIBVORBIS;CONFIG_LIBVPX;CONFIG_LIBWAVPACK;CONFIG_LIBWEBP;CONFIG_LIBX264;CONFIG_LIBX265;CONFIG_LIBXAVS;CONFIG_LIBXCB;CONFIG_LIBXCB_SHM;CONFIG_LIBXCB_SHAPE;CONFIG_LIBXCB_XFIXES;CONFIG_LIBXVID;CONFIG_LIBZIMG;CONFIG_LIBZMQ;CONFIG_LIBZVBI;CONFIG_LZMA;CONFIG_MMAL;CONFIG_NETCDF;CONFIG_NVENC;CONFIG_OPENAL;CONFIG_OPENCL;CONFIG_OPENGL;CONFIG_OPENSSL;CONFIG_SCHANNEL;CONFIG_SDL;CONFIG_SECURETRANSPORT;CONFIG_X11GRAB;CONFIG_XLIB;CONFIG_ZLIB;CONFIG_FTRAPV;CONFIG_GRAY;CONFIG_HARDCODED_TABLES;CONFIG_RUNTIME_CPUDETECT;CONFIG_SAFE_BITSTREAM_READER;CONFIG_SHARED;CONFIG_SMALL;CONFIG_STATIC;CONFIG_SWSCALE_ALPHA;CONFIG_D3D11VA;CONFIG_DXVA2;CONFIG_VAAPI;CONFIG_VDA;CONFIG_VDPAU")

foreach(option IN LISTS settings-list)
	set_disabled_to_zero(${option})
endforeach()


file(CONFIGURE
	OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/config.h"
	CONTENT
"/* Generated by cmake courtesy of kreinholz's hacks */
#ifndef FFMPEG_CONFIG_H
#define FFMPEG_CONFIG_H
#define FFMPEG_CONFIGURATION \"this is where configure options are normally listed, although technically we don't need them and ffmpeg builds just fine in a pure cmake environment without them\"
#define FFMPEG_LICENSE \"GPL version 2 or later\"
#define CONFIG_THIS_YEAR 2016
#define FFMPEG_DATADIR ${CMAKE_CURRENT_BINARY_DIR}
#define AVCONV_DATADIR ${CMAKE_CURRENT_BINARY_DIR}
#define CC_IDENT ${CC_IDENT}
#define av_restrict ${_RESTRICT}
#define EXTERN_PREFIX ${extern_prefix}
#define EXTERN_ASM ${extern_prefix}
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
#define ARCH_X86_32 ${ARCH_X86_32}
#define ARCH_X86_64 ${ARCH_X86_64}
#define HAVE_ARMV5TE ${HAVE_ARMV5TE}
#define HAVE_ARMV6 ${HAVE_ARMV6}
#define HAVE_ARMV6T2 ${HAVE_ARMV6T2}
#define HAVE_ARMV8 ${HAVE_ARMV8}
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
#define HAVE_I686 ${HAVE_I686}
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
#define HAVE_ARMV5TE_EXTERNAL ${HAVE_ARMV5TE_EXTERNAL}
#define HAVE_ARMV6_EXTERNAL ${HAVE_ARMV6_EXTERNAL}
#define HAVE_ARMV6T2_EXTERNAL ${HAVE_ARMV6T2_EXTERNAL}
#define HAVE_ARMV8_EXTERNAL ${HAVE_ARMV8_EXTERNAL}
#define HAVE_NEON_EXTERNAL ${HAVE_NEON_EXTERNAL}
#define HAVE_VFP_EXTERNAL ${HAVE_VFP_EXTERNAL}
#define HAVE_VFPV3_EXTERNAL ${HAVE_VFPV3_EXTERNAL}
#define HAVE_SETEND_EXTERNAL ${HAVE_SETEND_EXTERNAL}
#define HAVE_ALTIVEC_EXTERNAL 0
#define HAVE_DCBZL_EXTERNAL 0
#define HAVE_LDBRX_EXTERNAL 0
#define HAVE_POWER8_EXTERNAL 0
#define HAVE_PPC4XX_EXTERNAL 0
#define HAVE_VSX_EXTERNAL 0
#define HAVE_AESNI_EXTERNAL ${HAVE_AESNI_EXTERNAL}
#define HAVE_AMD3DNOW_EXTERNAL ${HAVE_AMD3DNOW_EXTERNAL}
#define HAVE_AMD3DNOWEXT_EXTERNAL ${HAVE_AMD3DNOWEXT_EXTERNAL}
#define HAVE_AVX_EXTERNAL ${HAVE_AVX_EXTERNAL}
#define HAVE_AVX2_EXTERNAL ${HAVE_AVX2_EXTERNAL}
#define HAVE_FMA3_EXTERNAL ${HAVE_FMA3_EXTERNAL}
#define HAVE_FMA4_EXTERNAL ${HAVE_FMA4_EXTERNAL}
#define HAVE_MMX_EXTERNAL ${HAVE_MMX_EXTERNAL}
#define HAVE_MMXEXT_EXTERNAL ${HAVE_MMXEXT_EXTERNAL}
#define HAVE_SSE_EXTERNAL ${HAVE_SSE_EXTERNAL}
#define HAVE_SSE2_EXTERNAL ${HAVE_SSE2_EXTERNAL}
#define HAVE_SSE3_EXTERNAL ${HAVE_SSE3_EXTERNAL}
#define HAVE_SSE4_EXTERNAL ${HAVE_SSE4_EXTERNAL}
#define HAVE_SSE42_EXTERNAL ${HAVE_SSE42_EXTERNAL}
#define HAVE_SSSE3_EXTERNAL ${HAVE_SSSE3_EXTERNAL}
#define HAVE_XOP_EXTERNAL ${HAVE_XOP_EXTERNAL}
#define HAVE_CPUNOP_EXTERNAL ${HAVE_CPUNOP_EXTERNAL}
#define HAVE_I686_EXTERNAL ${HAVE_I686_EXTERNAL}
#define HAVE_MIPSFPU_EXTERNAL ${HAVE_MIPSFPU_EXTERNAL}
#define HAVE_MIPS32R2_EXTERNAL ${HAVE_MIPS32R2_EXTERNAL}
#define HAVE_MIPS32R5_EXTERNAL ${HAVE_MIPS32R5_EXTERNAL}
#define HAVE_MIPS64R2_EXTERNAL ${HAVE_MIPS64R2_EXTERNAL}
#define HAVE_MIPS32R6_EXTERNAL ${HAVE_MIPS32R6_EXTERNAL}
#define HAVE_MIPS64R6_EXTERNAL ${HAVE_MIPS64R6_EXTERNAL}
#define HAVE_MIPSDSP_EXTERNAL ${HAVE_MIPSDSP_EXTERNAL}
#define HAVE_MIPSDSPR2_EXTERNAL ${HAVE_MIPSDSPR2_EXTERNAL}
#define HAVE_MSA_EXTERNAL ${HAVE_MSA_EXTERNAL}
#define HAVE_LOONGSON2_EXTERNAL ${HAVE_LOONGSON2_EXTERNAL}
#define HAVE_LOONGSON3_EXTERNAL ${HAVE_LOONGSON3_EXTERNAL}
#define HAVE_MMI_EXTERNAL ${HAVE_MMI_EXTERNAL}
#define HAVE_ARMV5TE_INLINE 0
#define HAVE_ARMV6_INLINE ${HAVE_ARMV6_INLINE}
#define HAVE_ARMV6T2_INLINE ${HAVE_ARMV6T2_INLINE}
#define HAVE_ARMV8_INLINE ${ARCH_AARCH64_INLINE}
#define HAVE_NEON_INLINE ${HAVE_NEON_INLINE}
#define HAVE_VFP_INLINE ${HAVE_VFP_INLINE}
#define HAVE_VFPV3_INLINE ${HAVE_VFPV3_INLINE}
#define HAVE_SETEND_INLINE ${HAVE_SETEND_INLINE}
#define HAVE_ALTIVEC_INLINE 0
#define HAVE_DCBZL_INLINE 0
#define HAVE_LDBRX_INLINE 0
#define HAVE_POWER8_INLINE 0
#define HAVE_PPC4XX_INLINE 0
#define HAVE_VSX_INLINE 0
#define HAVE_AESNI_INLINE ${HAVE_AESNI_INLINE}
#define HAVE_AMD3DNOW_INLINE ${HAVE_AMD3DNOW_INLINE}
#define HAVE_AMD3DNOWEXT_INLINE ${HAVE_AMD3DNOWEXT_INLINE}
#define HAVE_AVX_INLINE ${HAVE_AVX_INLINE}
#define HAVE_AVX2_INLINE ${HAVE_AVX2_INLINE}
#define HAVE_FMA3_INLINE ${HAVE_FMA3_INLINE}
#define HAVE_FMA4_INLINE ${HAVE_FMA4_INLINE}
#define HAVE_MMX_INLINE ${HAVE_MMX_INLINE}
#define HAVE_MMXEXT_INLINE ${HAVE_MMXEXT_INLINE}
#define HAVE_SSE_INLINE ${HAVE_SSE_INLINE}
#define HAVE_SSE2_INLINE ${HAVE_SSE2_INLINE}
#define HAVE_SSE3_INLINE ${HAVE_SSE3_INLINE}
#define HAVE_SSE4_INLINE ${HAVE_SSE4_INLINE}
#define HAVE_SSE42_INLINE ${HAVE_SSE42_INLINE}
#define HAVE_SSSE3_INLINE ${HAVE_SSSE3_INLINE}
#define HAVE_XOP_INLINE ${HAVE_XOP_INLINE}
#define HAVE_CPUNOP_INLINE ${HAVE_CPUNOP_INLINE}
#define HAVE_I686_INLINE ${HAVE_I686_INLINE}
#define HAVE_MIPSFPU_INLINE ${HAVE_MIPSFPU_INLINE}
#define HAVE_MIPS32R2_INLINE ${HAVE_MIPS32R2_INLINE}
#define HAVE_MIPS32R5_INLINE ${HAVE_MIPS32R5_INLINE}
#define HAVE_MIPS64R2_INLINE ${HAVE_MIPS64R2_INLINE}
#define HAVE_MIPS32R6_INLINE ${HAVE_MIPS32R6_INLINE}
#define HAVE_MIPS64R6_INLINE ${HAVE_MIPS64R6_INLINE}
#define HAVE_MIPSDSP_INLINE ${HAVE_MIPSDSP_INLINE}
#define HAVE_MIPSDSPR2_INLINE ${HAVE_MIPSDSPR2_INLINE}
#define HAVE_MSA_INLINE ${HAVE_MSA_INLINE}
#define HAVE_LOONGSON2_INLINE ${HAVE_LOONGSON2_INLINE}
#define HAVE_LOONGSON3_INLINE ${HAVE_LOONGSON3_INLINE}
#define HAVE_MMI_INLINE ${HAVE_MMI_INLINE}
#define HAVE_ALIGNED_STACK ${HAVE_ALIGNED_STACK}
#define HAVE_FAST_64BIT ${HAVE_FAST_64BIT}
#define HAVE_FAST_CLZ ${HAVE_FAST_CLZ}
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
#define HAVE_FAST_UNALIGNED ${HAVE_FAST_UNALIGNED}
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
#define CONFIG_XLIB ${CONFIG_XLIB}
#define CONFIG_ZLIB ${CONFIG_ZLIB}
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
#define CONFIG_VAAPI ${CONFIG_VAAPI}
#define CONFIG_VDA 0
#define CONFIG_VDPAU ${CONFIG_VDPAU}
#define CONFIG_VIDEOTOOLBOX 0
#define CONFIG_XVMC ${CONFIG_XVMC}
#define CONFIG_GPL 0
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
#define CONFIG_PIC ${CONFIG_PIC}
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
