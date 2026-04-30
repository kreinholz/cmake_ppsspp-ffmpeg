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
		message(STATUS "${target} check failed: ${err}")
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
		message(STATUS "${target} check failed: ${err}")
	endif()
endfunction()

# Rewrite of ffmpeg's as_o function at line 894 of configure script
# NOTE: written by Copilot AI
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
function(check_as target ARGUMENTS RESULT_VAR)
	file(WRITE "${CONFIG_TESTS_DIR}/${target}.S" "${ARGUMENTS}")
	set(OUTPUT_OBJ "${CONFIG_TESTS_DIR}/${target}.o")
	execute_process(
		COMMAND ${CMAKE_ASM_COMPILER} 
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
		message(STATUS "${target} check failed: ${err}")
	endif()
endfunction()

# Rewrite of ffmpeg's check_inline_asm function at line 905 of configure script
function(check_inline_asm target ARGUMENTS RESULT_VAR)
	set(TEST_CODE "
		void foo(void){__asm__ volatile(${ARGUMENTS}\)\;}
	")
	check_cc(${target} ${TEST_CODE} ${RESULT_VAR})
	set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

