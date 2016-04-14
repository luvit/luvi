# Added LUAJIT_ADD_EXECUTABLE Ryan Phillips <ryan at trolocsis.com>
# This CMakeLists.txt has been first taken from LuaDist
# Copyright (C) 2007-2011 LuaDist.
# Created by Peter Drahoš
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# Debugged and (now seriously) modified by Ronan Collobert, for Torch7
# Stripped-down and modified by Jörg Krause <joerg.krause@embedded.rocks>, for
# The Luvit Authors

MACRO(LUAJIT_add_custom_commands luajit_target)
  SET(TARGET_ARCH $ENV{TARGET_ARCH})
  IF(TARGET_ARCH)
    SET(LJ_BYTECODE_OPTS ${LJ_BYTECODE_OPTS} -a ${TARGET_ARCH})
  ENDIF(TARGET_ARCH)
  SET(LUA_PATH $ENV{LUA_PATH})
  SET(target_srcs "")
  FOREACH(file ${ARGN})
    IF(${file} MATCHES ".*\\.lua$")
      set(file "${CMAKE_CURRENT_SOURCE_DIR}/${file}")
      set(source_file ${file})
      string(LENGTH ${CMAKE_SOURCE_DIR} _luajit_source_dir_length)
      string(LENGTH ${file} _luajit_file_length)
      math(EXPR _begin "${_luajit_source_dir_length} + 1")
      math(EXPR _stripped_file_length "${_luajit_file_length} - ${_luajit_source_dir_length} - 1")
      string(SUBSTRING ${file} ${_begin} ${_stripped_file_length} stripped_file)

      set(generated_file "${CMAKE_BINARY_DIR}/jitted_tmp/${stripped_file}_${luajit_target}_generated${CMAKE_C_OUTPUT_EXTENSION}")

      add_custom_command(
        OUTPUT ${generated_file}
        MAIN_DEPENDENCY ${source_file}
        COMMAND "LUA_PATH=${LUA_PATH}" luajit
        ARGS -b ${LJ_BYTECODE_OPTS}
          ${source_file}
          ${generated_file}
        COMMENT "Building Luajitted ${source_file}: ${generated_file}"
      )

      get_filename_component(basedir ${generated_file} PATH)
      file(MAKE_DIRECTORY ${basedir})

      set(target_srcs ${target_srcs} ${generated_file})
      set_source_files_properties(
        ${generated_file}
        properties
        external_object true # this is an object file
        generated true        # to say that "it is OK that the obj-files do not exist before build time"
      )
    ELSE()
      set(target_srcs ${target_srcs} ${file})
    ENDIF(${file} MATCHES ".*\\.lua$")
  ENDFOREACH(file)
ENDMACRO()

MACRO(LUA_ADD_EXECUTABLE luajit_target)
  LUAJIT_add_custom_commands(${luajit_target} ${ARGN})
  add_executable(${luajit_target} ${target_srcs})
ENDMACRO(LUA_ADD_EXECUTABLE luajit_target)
