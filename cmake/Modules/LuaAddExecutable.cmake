# Added LUAJIT_ADD_EXECUTABLE Ryan Phillips <ryan at trolocsis.com>
# This CMakeLists.txt has been first taken from LuaDist
# Copyright (C) 2007-2011 LuaDist.
# Created by Peter Drahoš
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# Debugged and (now seriously) modified by Ronan Collobert, for Torch7
# Stripped-down and modified by Jörg Krause <joerg.krause@embedded.rocks>, for
# The Luvit Authors

macro(LUA_ADD_EXECUTABLE target)
  set(LUA_COMMAND luajit)
  set(LUA_COMMAND_ARGS "${CMAKE_CURRENT_SOURCE_DIR}/cmake/Modules/luac.lua")
  if (WITH_LUA_ENGINE STREQUAL Lua)
    set(LUA_COMMAND lua)
  endif ()

  if ($ENV{LUA_PATH})
    set(LUA_COMMAND ${CMAKE_COMMAND} -E env LUA_PATH=$ENV{LUA_PATH} -- ${LUA_COMMAND})
  endif ()

  set(target_sources)

  foreach(source_file ${ARGN})
    get_filename_component(source_extension ${source_file} EXT)
    get_filename_component(source_name ${source_file} NAME_WE)

    if (${source_extension} STREQUAL ".lua")
      set(generated_file "${CMAKE_BINARY_DIR}/compiled_lua/${source_name}_${target}_generated.c")
      if (NOT IS_ABSOLUTE ${source_file})
        set(source_file "${CMAKE_CURRENT_SOURCE_DIR}/${source_file}")
      endif ()

      add_custom_command(
        OUTPUT ${generated_file}
        MAIN_DEPENDENCY ${source_file}
        COMMAND ${LUA_COMMAND}
        ARGS ${LUA_COMMAND_ARGS} ${source_file} ${generated_file}
        COMMENT "Building Lua ${source_file}: ${generated_file}"
      )

      get_filename_component(basedir ${generated_file} PATH)
      file(MAKE_DIRECTORY ${basedir})

      list(APPEND target_sources ${generated_file})
    else ()
      list(APPEND target_sources ${source_file})
    endif ()
  endforeach()

  add_executable(${target} ${target_sources})
endmacro(LUA_ADD_EXECUTABLE target)
