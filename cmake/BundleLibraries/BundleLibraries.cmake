string(TOUPPER ${CMAKE_BUILD_TYPE} bundle_build_type)

set(_static_lib_list "" CACHE INTERNAL "Static libs to add to bundle" FORCE)

function(bundle_static_library tgt_name bundled_tgt_name)
  list(APPEND _static_lib_list ${tgt_name})

  function(_recursively_collect_dependencies input_target)
    get_target_property(interface_deps ${input_target} INTERFACE_LINK_LIBRARIES)
    get_target_property(link_deps ${input_target} LINK_LIBRARIES)

    list(APPEND dep_list ${interface_deps} ${link_deps})

    foreach(dependency IN LISTS dep_list)
      if(TARGET ${dependency})
        get_target_property(alias ${dependency} ALIASED_TARGET)

        if(TARGET ${alias})
          set(dependency ${alias})
        endif()

        get_target_property(_type ${dependency} TYPE)

        if(${_type} STREQUAL "STATIC_LIBRARY")
          list(APPEND _static_lib_list ${dependency})
        endif()

        get_property(library_already_added
          GLOBAL PROPERTY _${tgt_name}_static_bundle_${dependency})

        if(NOT library_already_added)
          set_property(GLOBAL PROPERTY _${tgt_name}_static_bundle_${dependency} ON)
          _recursively_collect_dependencies(${dependency})
        endif()
      endif()
    endforeach()

    set(_static_lib_list ${_static_lib_list} PARENT_SCOPE)
  endfunction()

  _recursively_collect_dependencies(${tgt_name})

  list(REMOVE_DUPLICATES _static_lib_list)

  set(GEN_PATH ${CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${bundle_build_type}})

  set(bundled_tgt_full_name
    ${GEN_PATH}/${CMAKE_STATIC_LIBRARY_PREFIX}${bundled_tgt_name}${CMAKE_STATIC_LIBRARY_SUFFIX})

  if(EXISTS ${bundled_tgt_full_name})
    file(REMOVE ${bundled_tgt_full_name})
  endif()

  if(WIN32)
    find_program(lib_tool lib)

    foreach(tgt IN LISTS _static_lib_list)
      if(TARGET ${tgt})
        list(APPEND static_libs_full_names $<TARGET_FILE:${tgt}>)
      else()
        list(APPEND static_libs_full_names ${tgt})
      endif()
    endforeach()

    add_custom_command(
      COMMAND ${lib_tool} /NOLOGO /OUT:${bundled_tgt_full_name} ${static_libs_full_names}
      OUTPUT ${bundled_tgt_full_name}
      COMMENT "Bundling ${bundled_tgt_name}"
      VERBATIM)

  elseif(CMAKE_CXX_COMPILER_ID MATCHES "^(Clang|GNU)$")
    set(bundled_tgt_in ${GEN_PATH}/${bundled_tgt_name}.ar.in)
    file(WRITE ${bundled_tgt_in}
      "CREATE ${bundled_tgt_full_name}\n")

    foreach(tgt IN LISTS _static_lib_list)
      if(TARGET ${tgt})
        file(APPEND ${bundled_tgt_in}
          "ADDLIB $<TARGET_FILE:${tgt}>\n")
      else()
        file(APPEND ${bundled_tgt_in}
          "ADDLIB ${tgt}\n")
      endif()
    endforeach()

    file(APPEND ${bundled_tgt_in} "SAVE\n")
    file(APPEND ${bundled_tgt_in} "END\n")

    file(GENERATE
      OUTPUT ${GEN_PATH}/${bundled_tgt_name}.ar
      INPUT ${bundled_tgt_in})

    set(ar_tool ar) # ${CMAKE_AR}

    add_custom_command(
      COMMAND cd ${bundle_dir_path}
      COMMAND ${ar_tool} -M < ${GEN_PATH}/${bundled_tgt_name}.ar
      OUTPUT ${bundled_tgt_full_name}
      COMMENT "Bundling ${bundled_tgt_name}"
      VERBATIM)
  else()
    message(FATAL_ERROR "Unknown bundle scenario!")
  endif()

  add_custom_target(bundling_target ALL DEPENDS ${bundled_tgt_full_name})
  add_dependencies(bundling_target ${tgt_name})

  add_library(${bundled_tgt_name} STATIC IMPORTED)

  set_target_properties(${bundled_tgt_name}
    PROPERTIES
    IMPORTED_LOCATION ${bundled_tgt_full_name}
    INTERFACE_INCLUDE_DIRECTORIES $<TARGET_PROPERTY:${tgt_name},INTERFACE_INCLUDE_DIRECTORIES>)
  add_dependencies(${bundled_tgt_name} bundling_target)
endfunction()

function(bundle_add_lib tgt_name lib_name)
  set(_original_prefixes ${CMAKE_FIND_LIBRARY_PREFIXES})
  set(_original_suffixes ${CMAKE_FIND_LIBRARY_SUFFIXES})

  set(CMAKE_FIND_LIBRARY_PREFIXES ${CMAKE_STATIC_LIBRARY_PREFIX})
  set(CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_STATIC_LIBRARY_SUFFIX})

  get_target_property(link_dirs ${tgt_name} LINK_DIRECTORIES)
  find_library(lib_path ${lib_name} PATHS ${link_dirs} REQUIRED NO_CACHE)

  set(_static_lib_list ${_static_lib_list} ${lib_path} CACHE INTERNAL "Static libs to add to bundle" FORCE)

  set(CMAKE_FIND_LIBRARY_PREFIXES ${_original_prefixes})
  set(CMAKE_FIND_LIBRARY_SUFFIXES ${_original_suffixes})
endfunction()