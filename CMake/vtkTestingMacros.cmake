macro(vtk_test_data_transform data_dir base_dir name)
  set(module_base_dir ${${vtk-module}_SOURCE_DIR}/Testing/Data/Baseline)
  set(in "${data_dir}/Baseline/${base_dir}/${name}.png")
  file(GLOB in_ "${data_dir}/Baseline/${base_dir}/${name}_*.png")
  file(REMOVE ${in} ${in_})
endmacro()

# -----------------------------------------------------------------------------
# Usage: vtk_add_test_mpi(name [VTK_DATA_ROOT|VTK_LARGE_DATA_ROOT])
macro (vtk_add_test_mpi name)
  get_filename_component(TName ${name} NAME_WE)
  set(argn "${ARGN}")
  set(data_dir "")
  set(test_extra "")
  foreach(a IN LISTS argn)
    if("[${a}]" STREQUAL "[VTK_DATA_ROOT]")
      set(data_dir ${VTK_DATA_ROOT})
    elseif("[${a}]" STREQUAL "[VTK_LARGE_DATA_ROOT]")
      set(data_dir ${VTK_LARGE_DATA_ROOT})
    elseif("x${a}" MATCHES "\\.cxx$")
      list(APPEND test_extra ${a})
    else()
      message(FATAL_ERROR "Unknown argument \"${a}\"")
    endif()
  endforeach()

  if(data_dir)
    vtk_test_data_transform("${data_dir}" Parallel "${TName}")
    set(_D -D ${data_dir})
    set(_T -T ${VTK_BINARY_DIR}/Testing/Temporary)
    set(_V -V ${module_base_dir}/${TName}.png)
  else()
    set(_D "")
    set(_T "")
    set(_V "")
  endif()

  add_test(
    NAME ${vtk-module}Cxx-MPI-${TName}
    COMMAND ${VTK_MPIRUN_EXE}
    ${VTK_MPI_PRENUMPROC_FLAGS} ${VTK_MPI_NUMPROC_FLAG} ${VTK_MPI_MAX_NUMPROCS}
    ${VTK_MPI_PREFLAGS}
    $<TARGET_FILE:${TName}>
    ${_D} ${_T} ${_V}
    ${VTK_MPI_POSTFLAGS})

  vtk_module_test_executable(${TName} ${TName}.cxx ${test_extra})
endmacro()

# -----------------------------------------------------------------------------
# Usage: vtk_add_test_cxx([name.cxx[,-E<n>][,NO_VALID]]...
#          [NO_DATA] [NO_VALID|<base_dir>] [VALID_ERROR <n>])
function(vtk_add_test_cxx)
  # Parse Command line args
  set(names "")
  set(no_data 0)
  set(no_valid 0)
  set(no_output 0)
  set(large_data 0)
  unset(base_dir)
  foreach(a IN LISTS ARGN)
    if("[${a}]" STREQUAL "[NO_DATA]")
      set(no_data 1)
    elseif("[${a}]" STREQUAL "[NO_VALID]")
      set(no_valid 1)
    elseif("[${a}]" STREQUAL "[NO_OUTPUT]")
      set(no_output 1)
    elseif("[${a}]" STREQUAL "[LARGE_DATA]")
      set(large_data 1)
    elseif("x${a}" MATCHES "^x([^.]*)\\.cxx,?(.*)$")
      set(name "${CMAKE_MATCH_1}")
      string(REPLACE "," ";" _${name}_OPTIONS "${CMAKE_MATCH_2}")
      list(APPEND names ${name})
    elseif(NOT DEFINED base_dir)
      set(base_dir "${a}")
    else()
      message(FATAL_ERROR "Unknown argument \"${a}\"")
    endif()
  endforeach()

  if(no_valid)
    set(base_dir "")
  elseif(NOT DEFINED base_dir)
    message(FATAL_ERROR "Call must specify either NO_VALID or <base_dir> ")
  endif()

  if(large_data)
    set(data_dir "${VTK_LARGE_DATA_ROOT}")
  else()
    set(data_dir "${VTK_DATA_ROOT}")
  endif()

  if(data_dir AND NOT no_data)
    set(_D -D ${data_dir})
  else()
    set(_D "")
  endif()

  set(_T "")
  if(NOT no_output)
    set(_T -T ${VTK_TEST_OUTPUT_DIR})
  endif()

  foreach(name ${names})
    set(_V "")
    set(_E "")
    set(tmp_base "${base_dir}")
    foreach(opt IN LISTS _${name}_OPTIONS)
      if("x${opt}" MATCHES "^x-E([0-9]+)$")
        set(_E -E ${CMAKE_MATCH_1})
      elseif("[${opt}]" STREQUAL "[NO_VALID]")
        set(tmp_base "")
      else()
        message(FATAL_ERROR "Test ${name} has unknown option \"${opt}\"")
      endif()
    endforeach()
    if(data_dir AND tmp_base)
      vtk_test_data_transform("${data_dir}" "${tmp_base}" "${name}")
      set(_V -V ${module_base_dir}/${name}.png)
    endif()
    add_test(NAME ${vtk-module}Cxx-${name}
      COMMAND ${vtk-module}CxxTests ${name} ${${name}_ARGS}
      ${_D} ${_T} ${_V} ${_E})
    set_property(DIRECTORY APPEND PROPERTY VTK_TEST_CXX_SOURCES ${name}.cxx)
  endforeach()
endfunction()

macro(vtk_test_cxx_executable exe_name)
  set(argn "${ARGN}")
  set(test_driver vtkTestDriver.h)
  set(test_extra "")
  foreach(a IN LISTS argn)
    if("[${a}]" STREQUAL "[RENDERING_FACTORY]")
      include(vtkTestingRenderingDriver)
      set(test_driver ${vtkTestingRendering_SOURCE_DIR}/vtkTestingObjectFactory.h)
    elseif("x${a}" MATCHES "\\.cxx$")
      list(APPEND test_extra ${a})
    else()
      message(FATAL_ERROR "Unknown argument \"${a}\"")
    endif()
  endforeach()
  get_property(vtk_test_cxx_sources DIRECTORY PROPERTY VTK_TEST_CXX_SOURCES)
  create_test_sourcelist(Tests ${exe_name}.cxx ${vtk_test_cxx_sources}
    EXTRA_INCLUDE ${test_driver})
  vtk_module_test_executable(${exe_name} ${Tests} ${test_extra})
endmacro()

# -----------------------------------------------------------------------------
# Usage: vtk_add_test_python(name [NO_RT] [NO_DATA] [NO_VALID|<base_dir>])
# NO_RT is for tests using vtk.test.testing
function(vtk_add_test_python name)
  if(NOT VTK_PYTHON_EXE)
    message(FATAL_ERROR "VTK_PYTHON_EXE not set")
  endif()
  # Parse Command line args
  get_filename_component(TName ${name} NAME_WE)
  set(no_data 0)
  set(no_valid 0)
  set(no_output 0)
  set(no_rt 0)
  unset(base_dir)
  foreach(a IN LISTS ARGN)
    if("[${a}]" STREQUAL "[NO_DATA]")
      set(no_data 1)
    elseif("[${a}]" STREQUAL "[NO_VALID]")
      set(no_valid 1)
    elseif("[${a}]" STREQUAL "[NO_OUTPUT]")
      set(no_output 1)
    elseif("[${a}]" STREQUAL "[NO_RT]")
      set(no_rt 1)
    elseif(NOT DEFINED base_dir)
      set(base_dir "${a}")
    else()
      message(FATAL_ERROR "Unknown argument \"${a}\"")
    endif()
  endforeach()

  if(no_valid)
    set(base_dir "")
  elseif(NOT DEFINED base_dir)
    message(FATAL_ERROR "Call must specify either NO_VALID or <base_dir> ")
  endif()

  if(VTK_DATA_ROOT AND NOT no_data)
    set(_D -D ${VTK_DATA_ROOT})
  else()
    set(_D "")
  endif()

  set(rtImageTest "")
  set(_B "")
  set(_V "")
  set(_T "")
  set(_A "")
  if(VTK_DATA_ROOT AND base_dir)
    vtk_test_data_transform("${VTK_DATA_ROOT}" "${base_dir}" "${TName}")
    if(no_rt)
      set(_B -B ${module_base_dir})
    else()
      set(rtImageTest ${VTK_BINARY_DIR}/Utilities/vtkTclTest2Py/rtImageTest.py)
      set(_V -V ${module_base_dir}/${TName}.png)
      set(_A -A ${VTK_BINARY_DIR}/Utilities/vtkTclTest2Py)
    endif()
    if(NOT no_output)
      set(_T -T ${VTK_TEST_OUTPUT_DIR})
    endif()
  endif()

  add_test(NAME ${vtk-module}Python-${TName}
    COMMAND ${VTK_PYTHON_EXE} ${rtImageTest}
    ${CMAKE_CURRENT_SOURCE_DIR}/${TName}.py ${${TName}_ARGS}
    ${_D} ${_B} ${_T} ${_V} ${_A})
endfunction()

# -----------------------------------------------------------------------------
# Usage: vtk_add_test_tcl(name [NO_DATA] [NO_VALID|<base_dir>])
function(vtk_add_test_tcl name)
  if(NOT VTK_TCL_EXE)
    message(FATAL_ERROR "VTK_TCL_EXE not set")
  endif()
  # Parse Command line args
  get_filename_component(TName ${name} NAME_WE)
  set(no_data 0)
  set(no_valid 0)
  set(no_output 0)
  set(no_rt 0)
  unset(base_dir)
  foreach(a IN LISTS ARGN)
    if("[${a}]" STREQUAL "[NO_DATA]")
      set(no_data 1)
    elseif("[${a}]" STREQUAL "[NO_VALID]")
      set(no_valid 1)
    elseif("[${a}]" STREQUAL "[NO_OUTPUT]")
      set(no_output 1)
    elseif("[${a}]" STREQUAL "[NO_RT]")
      set(no_rt 1)
    elseif(NOT DEFINED base_dir)
      set(base_dir "${a}")
    else()
      message(FATAL_ERROR "Unknown argument \"${a}\"")
    endif()
  endforeach()

  if(no_valid OR no_rt)
    set(base_dir "")
  elseif(NOT DEFINED base_dir)
    message(FATAL_ERROR "Call must specify either NO_VALID or <base_dir> ")
  endif()

  if(VTK_DATA_ROOT AND NOT no_data)
    set(_D -D ${VTK_DATA_ROOT})
  elseif(no_rt)
    set(_D "")
  else()
    set(_D -D VTK_DATA_ROOT-NOTFOUND)
  endif()

  set(rtImageTest "")
  set(_V "")
  set(_T "")
  if(NOT no_rt)
    set(rtImageTest ${vtkTestingRendering_SOURCE_DIR}/rtImageTest.tcl)
    if(VTK_DATA_ROOT AND base_dir)
      vtk_test_data_transform("${VTK_DATA_ROOT}" "${base_dir}" "${TName}")
      set(_V -V ${module_base_dir}/${TName}.png)
    endif()
    if(NOT no_output)
      set(_T -T ${VTK_TEST_OUTPUT_DIR})
    endif()
  endif()
  set(_A -A ${VTK_SOURCE_DIR}/Wrapping/Tcl)

  add_test(NAME ${vtk-module}Tcl-${TName}
    COMMAND ${VTK_TCL_EXE} ${rtImageTest}
    ${CMAKE_CURRENT_SOURCE_DIR}/${TName}.tcl ${${TName}_ARGS}
    ${_D} ${_T} ${_V} ${_A})
endfunction()
