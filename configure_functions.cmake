# configure_functions.cmake - various functions from ffmpeg's configure script rewritten for cmake

# Create a directory to store all of our tests
set(CONFIG_TESTS_DIR "${CMAKE_CURRENT_BINARY_DIR}/configure_checks")
file(MAKE_DIRECTORY ${CONFIG_TESTS_DIR})

# Rewrite of ffmpeg's check_cc function at line 866 of configure script
function(check_cc target ARGUMENTS RESULT_VAR)
	file(WRITE "${CONFIG_TESTS_DIR}/${target}.c" "${ARGUMENTS}")
	set(OUTPUT_OBJ "${CONFIG_TESTS_DIR}/${target}.o")
	execute_process(
		COMMAND ${CMAKE_C_COMPILER} 
				${ADDL_INCLUDES}
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
				${ADDL_INCLUDES} 
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

# Rewrite of fmpeg's check_ld function at line 953 of configure script
function(check_ld target ARGUMENTS EXTERNAL_LIB RESULT_VAR)
	set(CC_RESULT_VAR ${RESULT_VAR})
	check_cc("${target}_preliminary" ${ARGUMENTS} ${CC_RESULT_VAR})
	if (NOT "${EXTERNAL_LIB}" STREQUAL "")
		list(LENGTH EXTERNAL_LIB len)
		if (len GREATER 1)
			foreach(lib IN LISTS EXTERNAL_LIB)
				string(SUBSTRING "${lib}" 2 -1 lib_TRIMMED)
				find_library(MYLIB_${lib_TRIMMED} NAMES ${lib} "${lib_TRIMMED}")
				if (${MYLIB_${lib_TRIMMED}} MATCHES "-NOTFOUND")
					message(FATAL_ERROR "Required library ${lib} not found!")
				endif()
			endforeach()
		endif()
	endif()
	if (${CC_RESULT_VAR} EQUAL 1)
		set(OUTPUT_OBJ "${CONFIG_TESTS_DIR}/${target}_preliminary.o")
		execute_process(
			COMMAND ${CMAKE_C_COMPILER}
					${ADDL_INCLUDES}
					${ADDL_LIBS}
					${EXTERNAL_LIB}
					"${OUTPUT_OBJ}"
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
	elseif (headers STREQUAL "")
		set(HEADERS_STRING "")
	else()
		set(HEADERS_STRING "#include ${headers}")
	endif()
	set(test_func "check_${compiler}")
	if (NOT ${test_func} STREQUAL "check_ld")
		set(TEST_CODE "${HEADERS_STRING}\nint main(void) { ${ARGUMENTS};\nreturn 0; }")
		cmake_language(CALL ${test_func} ${target} "${TEST_CODE}" ${RESULT_VAR})
	else()
		set(TEST_CODE "${HEADERS_STRING}\nint main(void) { ${ARGUMENTS}\;\nreturn 0\; }")
		cmake_language(CALL ${test_func} ${target} "${TEST_CODE}" "" ${RESULT_VAR})
	endif()
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
	check_ld(${target} "${TEST_CODE}" "${lib}" ${RESULT_VAR})
	if (${RESULT_VAR} EQUAL 1)
		set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
	else()
		set(TEST_CODE "#include <math.h>\nfloat foo(float f, float g) { return ${func}(${args2})\; }\nint main(void){ return (int) foo\; }")
		check_ld(${target} "${TEST_CODE}" "${lib}" ${RESULT_VAR})
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

# Rewrite of ffmpeg's check_type function at line 1237 of configure script
function(check_type target headers type RESULT_VAR)
	check_code(${target} cc "${headers}" "${type} v" ${RESULT_VAR})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
	# Note: configure actually runs 'enable_safe' on "${type}" if the check passes
endfunction()

# Rewrite of ffmpeg's check_struct function at line 1246 of configure script
function(check_struct target headers struct member RESULT_VAR)
	check_code(${target} cc "${headers}" "const void *p = &((${struct} *)0)->${member}" ${RESULT_VAR})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
	# Note: configure actually runs 'enable_safe' on "${struct}_${member}" if the check passes
endfunction()

# Rewrite of ffmpeg's check_builtin function at line 1257 of configure script
function(check_builtin target headers builtin RESULT_VAR)
	check_code(${target} ld "${headers}" "${builtin}" ${RESULT_VAR})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
	# Note: configure actually invokes check_code with an incorrect/extra number of arguments!
endfunction()

# convenience function at the end that sets any truthy variables to "1" and any falsy variables to "0"
function(set_disabled_to_zero option)
	if(${option})
		set(${option} 1 PARENT_SCOPE)
	else()
		set(${option} 0 PARENT_SCOPE)
	endif()
endfunction()
