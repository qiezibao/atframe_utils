﻿if (CMAKE_VERSION VERSION_GREATER_EQUAL "3.10")
    include_guard(GLOBAL)
endif()

# platform check 
# default to x86 platform.  We'll check for X64 in a bit

if(NOT DEFINED __FIND_PLATFORM_LOADED)
    set(__FIND_PLATFORM_LOADED 1)
    SET(PLATFORM x86)
    SET(PLATFORM_SUFFIX "")

    # This definition is necessary to work around a bug with Intellisense described
    # here: http://tinyurl.com/2cb428.  Syntax highlighting is important for proper
    # debugger functionality.

    IF(CMAKE_SIZEOF_VOID_P MATCHES 8)
        #MESSAGE(STATUS "Detected 64-bit platform.")
        IF(WIN32)
            ADD_DEFINITIONS("-D_WIN64")
        ENDIF()
        SET(PLATFORM x86_64)
        SET(PLATFORM_SUFFIX "64")
    ELSE()
        #MESSAGE(STATUS "Detected 32-bit platform.")
    ENDIF()
endif ()
