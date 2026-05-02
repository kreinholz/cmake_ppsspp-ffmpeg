# configure_functions.cmake - various functions from ffmpeg's configure script rewritten for cmake

# Create a directory to store all of our tests
set(CONFIG_TESTS_DIR "${CMAKE_CURRENT_BINARY_DIR}/configure_checks")
file(MAKE_DIRECTORY ${CONFIG_TESTS_DIR})

# Very short convenience function (written by me) to set specified variable to "1" if defined, "0" if undefined
function(assign_value INPUT_VAR)
	if(${INPUT_VAR})
		set(${INPUT_VAR} 1 PARENT_SCOPE)
	else()
		set(${INPUT_VAR} 0 PARENT_SCOPE)
	endif()
endfunction()

# Rewrite of ffmpeg's check_cc function at line 866 of configure script
function(check_cc target ARGUMENTS RESULT_VAR)
	file(WRITE "${CONFIG_TESTS_DIR}/${target}.c" "${ARGUMENTS}")
	set(OUTPUT_OBJ "${CONFIG_TESTS_DIR}/${target}.o")
	execute_process(
		COMMAND ${CMAKE_C_COMPILER} 
				${CMAKE_C_FLAGS} 
				-c "${CONFIG_TESTS_DIR}/${target}.c"
				-o "${OUTPUT_OBJ}"
		RESULT_VARIABLE result
		OUTPUT_VARIABLE out
		ERROR_VARIABLE err
	)
	if (result EQUAL 0)
		message(STATUS "${target} check passed")
		set(${RESULT_VAR} 1 PARENT_SCOPE)
	else()
		message(STATUS "${target} check failed. See ${target}_error.log for details")
		file(WRITE "${CONFIG_TESTS_DIR}/${target}_error.log" "${err}")
	endif()
endfunction()

# Rewrite of ffmpeg's check_cxx function at line 873 of configure script
function(check_cxx target ARGUMENTS RESULT_VAR)
	file(WRITE "${CONFIG_TESTS_DIR}/${target}.cpp" "${ARGUMENTS}")
	set(OUTPUT_OBJ "${CONFIG_TESTS_DIR}/${target}.o")
	execute_process(
		COMMAND ${CMAKE_CXX_COMPILER} 
				${CMAKE_CXX_FLAGS} 
				-c "${CONFIG_TESTS_DIR}/${target}.cpp"
				-o "${OUTPUT_OBJ}"
		RESULT_VARIABLE result
		OUTPUT_VARIABLE out
		ERROR_VARIABLE err
	)
	if (result EQUAL 0)
		message(STATUS "${target} check passed")
		set(${RESULT_VAR} 1 PARENT_SCOPE)
	else()
		message(STATUS "${target} check failed. See ${target}_error.log for details")
		file(WRITE "${CONFIG_TESTS_DIR}/${target}_error.log" "${err}")
	endif()
endfunction()

# Rewrite of ffmpeg's as_o function at line 894 of configure script
# NOTE: written by Copilot AI
# FIXME: I'm not sure this will work because ARGN is associated with command-line arguments to cmake...
macro(as_o result_var)
    set(output "")
    foreach(arg IN LISTS ARGN)  # ARGN = all arguments after result_var
        string(APPEND output "-o ${arg} ")
    endforeach()

    # Remove trailing space
    string(STRIP "${output}" output)

    # Directly set the variable in the caller's scope
    set(${result_var} "${output}")
endmacro()

# Rewrite of ffmpeg's check_as function at line 898 of configure script
# TODO - actually run a check with this to make sure it works as intended
function(check_as target ARGUMENTS RESULT_VAR)
	file(WRITE "${CONFIG_TESTS_DIR}/${target}.S" "${ARGUMENTS}")
	set(OUTPUT_OBJ "${CONFIG_TESTS_DIR}/${target}.o")
	execute_process(
		COMMAND ${GAS_EXECUTABLE} 
				${CMAKE_ASM_FLAGS} 
				-c "${CONFIG_TESTS_DIR}/${target}.S"
				-o "${OUTPUT_OBJ}"
		RESULT_VARIABLE result
		OUTPUT_VARIABLE out
		ERROR_VARIABLE err
	)
	if (result EQUAL 0)
		message(STATUS "${target} check passed")
		set(${RESULT_VAR} 1 PARENT_SCOPE)
	else()
		message(STATUS "${target} check failed. See ${target}_error.log for details")
		file(WRITE "${CONFIG_TESTS_DIR}/${target}_error.log" "${err}")
	endif()
endfunction()

# Rewrite of ffmpeg's check_inline_asm function at line 905 of configure script
function(check_inline_asm target ARGUMENTS RESULT_VAR)
	set(TEST_CODE "void foo(void){__asm__ volatile(${ARGUMENTS}\)\;}")
	check_cc(${target} ${TEST_CODE} ${RESULT_VAR})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

# Rewrite of ffmpeg's check_inline_asm_flags function at line 916 of configure script
# TODO - run a check with this and add in the flag-setting logic
function(check_inline_asm_flags target ARGUMENTS RESULT_VAR)
	set(TEST_CODE "void foo(void){__asm__ volatile(${ARGUMENTS}\)\;}")
	check_cc(${target} ${TEST_CODE} ${RESULT_VAR})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
	if (${RESULT_VAR} EQUAL 1)
		# To Do - add any relevant CFLAGS, ASFLAGS (ASM_FLAGS?), LDFLAGS, etc. based on the enabled feature
	endif()
endfunction()

# Rewrite of ffmpeg's check_insn function at line 935 of configure script
# FIXME: this and its nested functions probably need another argument to enable relevant features/add headers
# TODO - run a successful check with this to make sure it works as intended
function(check_insn target ARGUMENTS RESULT_VAR INLINE_RESULT_VAR EXTERNAL_RESULT_VAR)
	set(inline_target "${target}_inline")
	check_inline_asm(${inline_target} "${ARGUMENTS}" ${INLINE_RESULT_VAR})
	set(${INLINE_RESULT_VAR} "${${INLINE_RESULT_VAR}}" PARENT_SCOPE)
	set(external_target "${target}_external")
	check_as(${external_target} "${ARGUMENTS}" ${EXTERNAL_RESULT_VAR})
	set(${EXTERNAL_RESULT_VAR} "${${EXTERNAL_RESULT_VAR}}" PARENT_SCOPE)
	if (${INLINE_RESULT_VAR} EQUAL 1 OR ${EXTERNAL_RESULT_VAR} EQUAL 1)
		set(${RESULT_VAR} 1 PARENT_SCOPE)
	endif()
endfunction()

# Rewrite of ffmpeg's check_yasm function at line 941 of configure script
function(check_yasm target ARGUMENTS RESULT_VAR)
	file(WRITE "${CONFIG_TESTS_DIR}/${target}.S" "${ARGUMENTS}")
	set(OUTPUT_OBJ "${CONFIG_TESTS_DIR}/${target}.o")
	execute_process(
		COMMAND ${YASM_EXECUTABLE} 
				${CMAKE_ASM_NASM_FLAGS} 
				"${CONFIG_TESTS_DIR}/${target}.S"
				-o "${OUTPUT_OBJ}"
		RESULT_VARIABLE result
		OUTPUT_VARIABLE out
		ERROR_VARIABLE err
	)
	if (result EQUAL 0)
		message(STATUS "${target} check passed")
		set(${RESULT_VAR} 1 PARENT_SCOPE)
	else()
		message(STATUS "${target} check failed. See ${target}_error.log for details")
		file(WRITE "${CONFIG_TESTS_DIR}/${target}_error.log" "${err}")
	endif()
endfunction()

# Rewrite of fmpeg's check_ld function at line 953 of configure script
function(check_ld target ARGUMENTS EXTERNAL_LIB RESULT_VAR)
	set(CC_RESULT_VAR ${RESULT_VAR})
	check_cc("${target}_preliminary" ${ARGUMENTS} ${CC_RESULT_VAR})
	if (NOT "${EXTERNAL_LIB}" STREQUAL "")
		string(SUBSTRING "${EXTERNAL_LIB}" 2 -1 EXTERNAL_LIB_TRIMMED)
		find_library(${EXTERNAL_LIB} "${EXTERNAL_LIB_TRIMMED}")
	endif()
	if (${CC_RESULT_VAR} EQUAL 1)
		set(OUTPUT_OBJ "${CONFIG_TESTS_DIR}/${target}_preliminary.o")
		execute_process(
			COMMAND ${CMAKE_C_COMPILER}
					${CMAKE_EXE_LINKER_FLAGS}
					${CMAKE_C_FLAGS}
					"${OUTPUT_OBJ}"
					"${EXTERNAL_LIB}"
					-o "${CONFIG_TESTS_DIR}/${target}.exe"
			RESULT_VARIABLE result
			OUTPUT_VARIABLE out
			ERROR_VARIABLE err
			)
		if (result EQUAL 0)
			message(STATUS "${target} check passed")
			set(${RESULT_VAR} 1 PARENT_SCOPE)
		else()
			message(STATUS "${target} check failed. See ${target}_lib_error.log for details")
			file(WRITE "${CONFIG_TESTS_DIR}/${target}_lib_error.log" "${err}")
		endif()
	endif()
endfunction()

# Rewrite of ffmpeg's check_code function at line 972 of configure script
function(check_code target compiler headers ARGUMENTS RESULT_VAR)
	# Check whether more than 1 header file was passed as a function argument
	list(LENGTH headers len)
	if (len GREATER 1)
		foreach(header IN LISTS headers)
			string(APPEND HEADERS_STRING "#include ${header}\n")
		endforeach()
	else()
		set(HEADERS_STRING "#include ${headers}")
	endif()
	set(TEST_CODE "${HEADERS_STRING}\nint main(void) { ${ARGUMENTS};\nreturn 0; }")
	set(test_func "check_${compiler}")
	cmake_language(CALL ${test_func} ${target} "${TEST_CODE}" ${RESULT_VAR})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

# Rewrite of ffmpeg's check_header function at line 1053 of configure script
function(check_header target header RESULT_VAR)
	set(HEADER_STRING "#include <${header}>")
	set(TEST_CODE "${HEADER_STRING}\nint x\;")
	check_cxx(${target} ${TEST_CODE} ${RESULT_VAR})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

# Rewrite of ffmpeg's check_func function at line 1076 of configure script
function(check_func target func RESULT_VAR)
	set(TEST_CODE "extern int ${func}()\;\nint main(void){ ${func}()\; }")
	check_ld(${target} "${TEST_CODE}" "" ${RESULT_VAR})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

# Rewrite of ffmpeg's check_complexfunc function at line 1087 of configure script
function(check_complexfunc target func RESULT_VAR)
	set(args1 "f, g")
	set(args2 "f * I")
	set(TEST_CODE "#include <complex.h>\n#include <math.h>\nfloat foo(complex float f, complex float g) { return ${func}(${args1})\; }\nint main(void){ return (int) foo\; }")
	check_ld(${target} "${TEST_CODE}" "-lm" ${RESULT_VAR})
	if (${RESULT_VAR} EQUAL 1)
		set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
	else()
		set(TEST_CODE "#include <complex.h>\n#include <math.h>\nfloat foo(complex float f, complex float g) { return ${func}(${args2})\; }\nint main(void){ return (int) foo\; }")
		check_ld(${target} "${TEST_CODE}" "-lm" ${RESULT_VAR})
		set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
	endif()
endfunction()

# Rewrite of ffmpeg's check_mathfunc function at line 1102 of configure script
function(check_mathfunc target func lib RESULT_VAR)
	set(args1 "f, g")
	set(args2 "f")
	set(TEST_CODE "#include <math.h>\nfloat foo(float f, float g) { return ${func}(${args1})\; }\nint main(void){ return (int) foo\; }")
	check_ld(${target} "${TEST_CODE}" "-1m" ${RESULT_VAR})
	if (${RESULT_VAR} EQUAL 1)
		set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
	else()
		set(TEST_CODE "#include <math.h>\nfloat foo(float f, float g) { return ${func}(${args2})\; }\nint main(void){ return (int) foo\; }")
		check_ld(${target} "${TEST_CODE}" "-lm" ${RESULT_VAR})
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
			string(APPEND FUNCS_STRING "long check_${func}(void) { return (long) ${func}\; }\n")
		endforeach()
	else()
		set(FUNCS_STRING "long check_${funcs}(void) { return (long) ${funcs}\; }\n")
	endif()
	set(TEST_CODE "${HEADERS_STRING}\n${FUNCS_STRING}\nint main(void) { return 0\; }")
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
	set(TEST_CODE "${HEADER_STRING}\n${CONDITION_STRING}\nint x\;")
	check_cxx(${target} ${TEST_CODE} ${RESULT_VAR})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

# Rewrite of ffmpeg's check_lib function at line 1164 of configure script
function(check_lib target header func RESULT_VAR)
	set(HEADER_STRING "${header}")
	set(FUNC_STRING "${func}")
	set(HEADER_RESULT_VAR "HEADER_${RESULT_VAR}")
	check_header("${target}_header" "${HEADER_STRING}" ${HEADER_RESULT_VAR})
	if (${HEADER_RESULT_VAR} EQUAL 1)
		check_func(${target} "${func}" ${RESULT_VAR})
	endif()
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

# Rewrite of ffmpeg's check_lib2 function at line 1164 of configure script
function(check_lib2 target headers funcs lib RESULT_VAR)
	check_func_headers(${target} "${headers}" "${funcs}" "${lib}" ${RESULT_VAR})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

# Rewrite of ffmpeg's check_exec_crash function at line 1207 of configure script
