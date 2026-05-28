# configure_functions.cmake - various functions from ffmpeg's configure script rewritten for cmake

# Note: cmake has modules that could accomplish a lot of these checks. CheckCSourceCompiles, CheckIncludeFile, CheckTypeSize, CheckFunctionExists, etc. However, I found during testing that sometimes, cmake reachs a different result than ffmpeg. In order to not break ffmpeg, we need to arrive at the same result as ffmpeg's configure script's check, so instead of relying on cmake modules, I ported ffmpeg's configure script's functions needed below.

# Create a directory to store all of our tests
set(CONFIG_TESTS_DIR "${CMAKE_CURRENT_BINARY_DIR}/configure_checks")
file(MAKE_DIRECTORY ${CONFIG_TESTS_DIR})

include(CheckIncludeFile)
include(CheckIncludeFiles)

# Rewrite of ffmpeg's check_cc function at line 866 of configure script
function(check_cc target ARGUMENTS RESULT_VAR)
	set(EXTRA_LIBS "")
	set(EXTRA_FLAGS "")
	set(ADDL_LIB_DIRS_CLEAN "")

	foreach(arg IN ITEMS ${ARGN})
    	# 1. Check for Unix link flags (-l) OR absolute library file paths (.lib, .a, .so)
    	if(arg MATCHES "^-l")
        	list(APPEND EXTRA_LIBS "${arg}")
    	elseif(IS_ABSOLUTE "${arg}" AND arg MATCHES "\\.(lib|a|so|dylib)$")
        	list(APPEND EXTRA_LIBS "${arg}")
        	
    	# 2. Check for Library Directory flags (Unix: -L, MSVC: /LIBPATH: or -libpath:)
    	elseif(arg MATCHES "^-L")
        	string(SUBSTRING "${arg}" 2 -1 clean_dir)
        	list(APPEND ADDL_LIB_DIRS_CLEAN "${clean_dir}")
    	elseif(arg MATCHES "^[-/][Ll][Ii][Bb][Pp][Aa][Tt][Hh]:")
        	# Strips out both /LIBPATH: and -libpath: prefixes
        	string(REGEX REPLACE "^[-/][Ll][Ii][Bb][Pp][Aa][Tt][Hh]:" "" clean_dir "${arg}")
        	list(APPEND ADDL_LIB_DIRS_CLEAN "${clean_dir}")
        	
    	# 3. Everything else goes to flags
    	else()
        	list(APPEND EXTRA_FLAGS "${arg}")
    	endif()
	endforeach()
	
	# Clean up ADDL_LIB_DIRS (Handles both raw paths and legacy -L flags)
	if(ADDL_LIB_DIRS)
    	foreach(dir IN LISTS ADDL_LIB_DIRS)
        	if(dir MATCHES "^-L")
            	string(SUBSTRING "${dir}" 2 -1 clean_dir)
            	list(APPEND ADDL_LIB_DIRS_CLEAN "${clean_dir}")
        	elseif(dir MATCHES "^[-/][Ll][Ii][Bb][Pp][Aa][Tt][Hh]:")
            	string(REGEX REPLACE "^[-/][Ll][Ii][Bb][Pp][Aa][Tt][Hh]:" "" clean_dir "${dir}")
            	list(APPEND ADDL_LIB_DIRS_CLEAN "${clean_dir}")
        	else()
            	list(APPEND ADDL_LIB_DIRS_CLEAN "${dir}")
        	endif()
    	endforeach()
	endif()
	
	# Clean up ADDL_INCLUDES (Handles both raw paths and Unix -I flags)
	set(COMPILE_INCLUDES "")
	if(ADDL_INCLUDES)
    	foreach(dir IN LISTS ADDL_INCLUDES)
        	if(dir MATCHES "^-I")
            	string(SUBSTRING "${dir}" 2 -1 clean_dir)
            	list(APPEND COMPILE_INCLUDES "${clean_dir}")
        	else()
            	list(APPEND COMPILE_INCLUDES "${dir}")
        	endif()
    	endforeach()
	endif()
	
#[[
	foreach(arg IN ITEMS ${ARGN})
		if(arg MATCHES "^-l")	# Append to EXTRA_LIBS
			list(APPEND EXTRA_LIBS "${arg}")
		elseif(arg MATCHES "^-L")	# Append to ADDL_LIB_DIRS_CLEAN
			string(SUBSTRING "${arg}" 2 -1 clean_dir)
			list(APPEND ADDL_LIB_DIRS_CLEAN "${clean_dir}")
		else()
			list(APPEND EXTRA_FLAGS "${arg}")
		endif()
	endforeach()
	
	if(ADDL_LIB_DIRS)
		foreach(dir IN LISTS ADDL_LIB_DIRS)
			if(dir MATCHES "^-L")
				string(SUBSTRING "${dir}" 2 -1 clean_dir)
				list(APPEND ADDL_LIB_DIRS_CLEAN "${clean_dir}")
			else()
				list(APPEND ADDL_LIB_DIRS_CLEAN "${dir}")
			endif()
		endforeach()
	endif()

	set(COMPILE_INCLUDES "")
	if(ADDL_INCLUDES)
		foreach(dir IN LISTS ADDL_INCLUDES)
			if(dir MATCHES "^-I")
				string(SUBSTRING "${dir}" 2 -1 clean_dir)
				list(APPEND COMPILE_INCLUDES "${clean_dir}")
			else()
				list(APPEND COMPILE_INCLUDES "${dir}")
			endif()
		endforeach()
	endif()
]]	
	# Clean up duplicate paths/extra libs
	if(EXTRA_LIBS)
		list(REMOVE_DUPLICATES EXTRA_LIBS)
	endif()
	if(ADDL_LIB_DIRS_CLEAN)
		list(REMOVE_DUPLICATES ADDL_LIB_DIRS_CLEAN)
	endif()
	if(EXTRA_FLAGS)
		list(REMOVE_DUPLICATES EXTRA_FLAGS)
	endif()
	if(COMPILE_INCLUDES)
		list(REMOVE_DUPLICATES COMPILE_INCLUDES)
	endif()
	
	# Check if ARGUMENTS contains a variation of main function definition
	string(REGEX MATCH "int[ \t\r\n]+main[ \t\r\n]*\\(" HAS_MAIN "${ARGUMENTS}")
	if(NOT HAS_MAIN)
		# Append a standard int main() block to the end of the existing source code
		string(APPEND ARGUMENTS "\n\nint main(void) {\n    return 0;\n}\n")
	endif()

	set(TEST_SOURCE "${CONFIG_TESTS_DIR}/${target}.c")
	file(WRITE "${TEST_SOURCE}" "${ARGUMENTS}")
	set(OUTPUT_OBJ "${CONFIG_TESTS_DIR}/${target}.o")
    try_compile(COMPILE_RESULT
		"${CONFIG_TESTS_DIR}"
		"${TEST_SOURCE}"
		COMPILE_DEFINITIONS ${EXTRA_FLAGS}
		LINK_LIBRARIES ${EXTRA_LIBS}
		CMAKE_FLAGS
			"-DINCLUDE_DIRECTORIES:PATH=${COMPILE_INCLUDES}"
			"-DLINK_DIRECTORIES:PATH=${ADDL_LIB_DIRS_CLEAN}"
		COPY_FILE "${OUTPUT_OBJ}"
		OUTPUT_VARIABLE COMPILE_OUTPUT
	)

	if(COMPILE_RESULT)
		message(STATUS "${target} check passed")
		set(${RESULT_VAR} 1 PARENT_SCOPE)
	else()
#		message(STATUS "${target} check failed. Error:\n${COMPILE_OUTPUT}")
		message(STATUS "${target} check failed. See ${target}_error.log for details")
		file(WRITE "${CONFIG_TESTS_DIR}/${target}_error.log" "${COMPILE_OUTPUT}")
	endif()
endfunction()

# Rewrite of fmpeg's check_ld function at line 953 of configure script
function(check_ld target ARGUMENTS EXTERNAL_LIB RESULT_VAR)
	set(ADDL_LIB_DIRS "")
	set(EXTRA_LIBS "")
	set(EXTRA_FLAGS "")

set(EXTRA_LIBS "")
set(EXTRA_FLAGS "")
set(ADDL_LIB_DIRS_CLEAN "")
	
	foreach(arg IN ITEMS ${ARGN})
    	# 1. Catch Windows-specific -l flags injected by third-party scripts
    	if(MSVC AND arg MATCHES "^-l(msvcrt|shell32|advapi32|user32|gdi32|kernel32|psapi|ws2_32)")
        	# Strip the Unix "-l" flag prefix and append the bare ".lib" name for MSVC
        	string(REGEX REPLACE "^-l" "" clean_lib "${arg}")
        	list(APPEND EXTRA_LIBS "${clean_lib}.lib")
	
    	# 2. Standard Unix link flags (-l)
    	elseif(arg MATCHES "^-l")
        	list(APPEND EXTRA_LIBS "${arg}")
        	
    	# 3. Absolute library paths (.lib, .a, .so, etc.)
    	elseif(IS_ABSOLUTE "${arg}" AND arg MATCHES "\\.(lib|a|so|dylib)$")
        	list(APPEND EXTRA_LIBS "${arg}")
        	
    	# 4. Library Directory flags (Unix: -L, MSVC: /LIBPATH: or -libpath:)
    	elseif(arg MATCHES "^-L")
        	string(SUBSTRING "${arg}" 2 -1 clean_dir)
        	list(APPEND ADDL_LIB_DIRS_CLEAN "${clean_dir}")
    	elseif(arg MATCHES "^[-/][Ll][Ii][Bb][Pp][Aa][Tt][Hh]:")
        	string(REGEX REPLACE "^[-/][Ll][Ii][Bb][Pp][Aa][Tt][Hh]:" "" clean_dir "${arg}")
        	list(APPEND ADDL_LIB_DIRS_CLEAN "${clean_dir}")
        	
    	# 5. Everything else is a compiler option flag
    	else()
        	list(APPEND EXTRA_FLAGS "${arg}")
    	endif()
	endforeach()

#[[	MSVC-v1
	foreach(arg IN ITEMS ${ARGN})
    	# Append to EXTRA_FLAGS
    	if(EXTRA_FLAGS STREQUAL "")
    		set(EXTRA_FLAGS "${arg}")
    	else()
    		list(APPEND EXTRA_FLAGS "${arg}")
    	endif()
	endforeach()
    if(NOT "${EXTERNAL_LIB}" STREQUAL "")
    	foreach(lib IN LISTS EXTERNAL_LIB)
        	# 1. Clean the name across ALL platforms (removes -l prefix if passed)
        	string(REGEX MATCH "^-l(.+)" IS_FLAG "${lib}")
        	if(IS_FLAG)
            	string(SUBSTRING "${lib}" 2 -1 lib_CLEAN)
        	else()
            	set(lib_CLEAN "${lib}")
        	endif()
	
        	# 2. Standardize lookup names for MSVC compatibility
        	# If looking for 'msvcrt', MSVC needs 'msvcrt'. Unix needs 'm' or 'c'.
        	set(search_names "${lib_CLEAN}" "${lib}")
        	
        	find_library(EXTERNAL_LIB_${lib_CLEAN} NAMES ${search_names})            
        	if(NOT EXTERNAL_LIB_${lib_CLEAN})
            	message(STATUS "Library ${lib} not found! Failing ${target} check")
            	return()
        	endif()
	
        	# 3. Handle Linker Flags Generically
        	# MSVC prefers absolute paths directly. Unix accepts them perfectly too!
        	if(MSVC)
            	# On MSVC (including clang-cl), pass the absolute path to the .lib file
            	list(APPEND EXTRA_LIBS "${EXTERNAL_LIB_${lib_CLEAN}}")
        	else()
            	# Legacy/UNIX fallback matching your original variables
            	get_filename_component(lib_DIR "${EXTERNAL_LIB_${lib_CLEAN}}" DIRECTORY)
            	list(APPEND ADDL_LIB_DIRS "-L${lib_DIR}")
            	list(APPEND EXTRA_LIBS "-l${lib_CLEAN}")
        	endif()
    	endforeach()
	endif()
]]
    #[[
        foreach(lib IN LISTS EXTERNAL_LIB)
            # If the library starts with "-l", trim it down for find_library (e.g., "-lm" -> "m")
            string(REGEX MATCH "^-l(.+)" IS_FLAG "${lib}")
            if(IS_FLAG)
                string(SUBSTRING "${lib}" 2 -1 lib_CLEAN)
            else()
                set(lib_CLEAN "${lib}")
            endif()
            find_library(EXTERNAL_LIB_${lib_CLEAN} NAMES "${lib_CLEAN}" "${lib}")            
            if(NOT EXTERNAL_LIB_${lib_CLEAN})
                message(STATUS "Library ${lib} not found! Failing ${target} check")
                return()
            endif()
            get_filename_component(lib_DIR "${EXTERNAL_LIB_${lib_CLEAN}}" DIRECTORY)
			if (ADDL_LIB_DIRS STREQUAL "")
    			set(ADDL_LIB_DIRS "-L${lib_DIR}")
    		else()
    			list(APPEND ADDL_LIB_DIRS "-L${lib_DIR}")
    		endif()
    		if (EXTRA_LIBS STREQUAL "")
    		    set(EXTRA_LIBS "-l${lib_CLEAN}")
    		else()
    			list(APPEND EXTRA_LIBS "-l${lib_CLEAN}")
    		endif()
        endforeach()
    endif()
    ]]
    check_cc("${target}" "${ARGUMENTS}" CC_RESULT ${EXTRA_LIBS} ${ADDL_LIB_DIRS} ${EXTRA_FLAGS})
    if(CC_RESULT)
        set(${RESULT_VAR} 1 PARENT_SCOPE)
    endif()
endfunction()

# Rewrite of ffmpeg's check_code function at line 972 of configure script
function(check_code target compiler headers ARGUMENTS RESULT_VAR)
	set(EXTRA_FLAGS "")
	foreach(arg IN ITEMS ${ARGN})
    	# Append to EXTRA_FLAGS
    	if(EXTRA_FLAGS STREQUAL "")
    		set(EXTRA_FLAGS "${arg}")
    	else()
    		list(APPEND EXTRA_FLAGS "${arg}")
    	endif()
	endforeach()
	# Check whether more than 1 header file was passed as a function argument
	list(LENGTH headers len)
	if (len GREATER 1)
		foreach(header IN LISTS headers)
			string(APPEND HEADERS_STRING "#include ${header}\n")
		endforeach()
	elseif (headers STREQUAL "")
		set(HEADERS_STRING "")
	else()
		set(HEADERS_STRING "#include ${headers}")
	endif()
	set(test_func "check_${compiler}")
	if (NOT ${test_func} STREQUAL "check_ld")
		set(TEST_CODE "${HEADERS_STRING}\nint main(void) { ${ARGUMENTS};\nreturn 0; }")
		cmake_language(CALL ${test_func} ${target} "${TEST_CODE}" ${RESULT_VAR} ${EXTRA_FLAGS})
	else()
		set(TEST_CODE "${HEADERS_STRING}\nint main(void) { ${ARGUMENTS};\nreturn 0; }")
		cmake_language(CALL ${test_func} ${target} "${TEST_CODE}" "" ${RESULT_VAR} ${EXTRA_FLAGS})
	endif()
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

# Rewrite of ffmpeg's check_header function at line 1053 of configure script
function(check_header target header flag RESULT_VAR)
	set(Backup_Flags ${CMAKE_REQUIRED_FLAGS})
	if(flag)
		string(APPEND CMAKE_REQUIRED_FLAGS " ${flag}")
	endif()
	if (header MATCHES ";")
		check_include_files("${header}" ${RESULT_VAR})
	else()
		check_include_file(${header} ${RESULT_VAR} "${flag}")
	endif()
	set(CMAKE_REQUIRED_FLAGS ${Backup_Flags})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

# Rewrite of ffmpeg's check_func function at line 1076 of configure script
function(check_func target func RESULT_VAR)
	set(EXTRA_FLAGS "")
	foreach(arg IN ITEMS ${ARGN})
    	# Append to EXTRA_FLAGS
    	if(EXTRA_FLAGS STREQUAL "")
    		set(EXTRA_FLAGS "${arg}")
    	else()
    		list(APPEND EXTRA_FLAGS "${arg}")
    	endif()
	endforeach()
	set(TEST_CODE "extern int ${func}();\nint main(void){ ${func}(); }")
	check_ld(${target} "${TEST_CODE}" "" ${RESULT_VAR} ${EXTRA_FLAGS})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

# Rewrite of ffmpeg's check_complexfunc function at line 1087 of configure script
function(check_complexfunc target func RESULT_VAR)
	set(TEST_CODE "#include <complex.h>\n#include <math.h>\nfloat foo(complex float f, complex float g) { return ${func}(f * I); \}\nint main(void){ return (int) foo; \}")
	if(CMAKE_SYSTEM_NAME STREQUAL "Windows" AND NOT MINGW)
		check_ld(${target} "${TEST_CODE}" "-lmsvcrt" ${RESULT_VAR})
	else()
		check_ld(${target} "${TEST_CODE}" "-lm" ${RESULT_VAR})
	endif()
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

# Rewrite of ffmpeg's check_mathfunc function at line 1102 of configure script
function(check_mathfunc target func lib RESULT_VAR)
	set(args1 "f, g")
	set(args2 "f")
	if ("${target}" MATCHES "atan2f|copysign|hypot|ldexpf|powf")
		set(TEST_CODE "#include <math.h>\nfloat foo(float f, float g) { return ${func}(${args1}); }\nint main(void){ return (int) foo; }")
	else()
		set(TEST_CODE "#include <math.h>\nfloat foo(float f, float g) { return ${func}(${args2}); }\nint main(void){ return (int) foo; }")
	endif()
	check_ld(${target} "${TEST_CODE}" "${lib}" ${RESULT_VAR})
	if (${RESULT_VAR} EQUAL 1)
		set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
	endif()
endfunction()

# Rewrite of ffmpeg's check_func_headers function at line 1116 of configure script
function(check_func_headers target headers funcs lib RESULT_VAR)
	# Check whether more than 1 header file was passed as an argument
	list(LENGTH headers len)
	if (len GREATER 1)
		foreach(header IN LISTS headers)
			string(APPEND HEADERS_STRING "#include ${header}\n")
		endforeach()
	else()
		set(HEADERS_STRING "#include ${headers}")
	endif()
	# Check whether more than 1 function to test was passed as an argument
	list(LENGTH funcs len)
	if (len GREATER 1)
		foreach(func IN LISTS funcs)
			string(APPEND FUNCS_STRING "long check_${func}(void) { return (long) ${func}; }\n")
		endforeach()
	else()
		set(FUNCS_STRING "long check_${funcs}(void) { return (long) ${funcs}; }\n")
	endif()
	set(TEST_CODE "${HEADERS_STRING}\n${FUNCS_STRING}\nint main(void) { return 0; }")
	check_ld(${target} "${TEST_CODE}" "${lib}" ${RESULT_VAR})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
	# To Do: in ffmpeg's configure script, some results prompt adding additional system libs.
	# Maybe we tally up a list of such system libs and at the end of all these tests, try linking them to the
	# appropriate ffmpeg lib (if any) the cmake way? Will have to try find_package or find_library first, then
	# fallback on PkgConfig if needed. Although since these *should* all be system libs, find_library should suffice
	# Frankly, we could probably read from the HAVE_ variables directly, and conditionally add libraries at the end
endfunction()

# Rewrite of ffmpeg's check_cpp_condition function at line 1151 of configure script
function(check_cpp_condition target header condition RESULT_VAR)
	set(HEADER_STRING "#include <${header}>")
	set(CONDITION_STRING "#if !\(${condition})\n#error \"unsatisfied condition: ${condition}\"\n#endif")
	set(TEST_CODE "${HEADER_STRING}\n${CONDITION_STRING}\nint x;")
	check_cc(${target} "${TEST_CODE}" ${RESULT_VAR})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

# Rewrite of ffmpeg's check_lib function at line 1164 of configure script
function(check_lib target header func flag RESULT_VAR)
	set(HEADER_STRING "${header}")
	set(FUNC_STRING "${func}")
	set(HEADER_RESULT_VAR "HEADER_${RESULT_VAR}")
	check_header("${target}_header" "${HEADER_STRING}" "${flag}" ${HEADER_RESULT_VAR})
	if (${HEADER_RESULT_VAR} EQUAL 1)
		check_func(${target} "${func}" ${RESULT_VAR} ${flag})
	endif()
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

# Rewrite of ffmpeg's check_lib2 function at line 1164 of configure script
function(check_lib2 target headers funcs lib RESULT_VAR)
	check_func_headers(${target} "${headers}" "${funcs}" "${lib}" ${RESULT_VAR})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

# Rewrite of ffmpeg's check_type function at line 1237 of configure script
function(check_type target headers type RESULT_VAR)
	check_code(${target} cc "${headers}" "${type} v" ${RESULT_VAR})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

# Rewrite of ffmpeg's check_struct function at line 1246 of configure script
function(check_struct target headers struct member RESULT_VAR)
	set(EXTRA_FLAGS "")
	foreach(arg IN ITEMS ${ARGN})
    	# Append to EXTRA_FLAGS
    	if(EXTRA_FLAGS STREQUAL "")
    		set(EXTRA_FLAGS "${arg}")
    	else()
    		list(APPEND EXTRA_FLAGS "${arg}")
    	endif()
	endforeach()
	check_code(${target} cc "${headers}" "const void *p = &((${struct} *)0)->${member}" ${RESULT_VAR} ${EXTRA_FLAGS})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

# Rewrite of ffmpeg's check_builtin function at line 1257 of configure script
function(check_builtin target headers builtin RESULT_VAR)
	check_code(${target} ld "${headers}" "${builtin}" ${RESULT_VAR})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
	# Note: configure actually invokes check_code with an extra argument!
	# Of course, now that we've refactored check_cc to accept optional arguments, we could deal with this here
endfunction()

# convenience function at the end that sets any truthy variables to "1" and any falsy variables to "0"
function(set_disabled_to_zero option)
	if(${option})
		set(${option} 1 PARENT_SCOPE)
	else()
		set(${option} 0 PARENT_SCOPE)
	endif()
endfunction()
