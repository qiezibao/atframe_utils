﻿if (CMAKE_VERSION VERSION_GREATER_EQUAL "3.10")
    include_guard(GLOBAL)
endif()

# 功能检测选项
include(WriteCompilerDetectionHeader)

# generate check header
write_compiler_detection_header(
    FILE "${PROJECT_ATFRAME_UTILS_INCLUDE_DIR}/config/compiler_features.h"
    PREFIX UTIL_CONFIG
    COMPILERS GNU Clang AppleClang MSVC
    FEATURES cxx_auto_type cxx_constexpr cxx_decltype cxx_decltype_auto cxx_defaulted_functions cxx_deleted_functions cxx_final cxx_override cxx_range_for cxx_noexcept cxx_nullptr cxx_rvalue_references cxx_static_assert cxx_thread_local cxx_variadic_templates cxx_lambdas
)
#file(MAKE_DIRECTORY "${PROJECT_ATFRAME_UTILS_INCLUDE_DIR}/config")
#file(RENAME "${CMAKE_BINARY_DIR}/compiler_features.h" "${PROJECT_ATFRAME_UTILS_INCLUDE_DIR}/config/compiler_features.h")

# 默认配置选项
#####################################################################
option(LIBUNWIND_ENABLED "Enable using libunwind." OFF)
option(LOG_WRAPPER_ENABLE_LUA_SUPPORT "Enable lua support." ON)
option(LOG_WRAPPER_CHECK_LUA "Check lua support." ON)
set(LOG_WRAPPER_MAX_SIZE_PER_LINE "2097152" CACHE STRING "Max size in one log line.")
set(LOG_WRAPPER_CATEGORIZE_SIZE "16" CACHE STRING "Default log categorize number.")

# Check pthread
find_package(Threads)
if (CMAKE_USE_PTHREADS_INIT)
    set(THREAD_TLS_USE_PTHREAD 1)
    if(NOT ANDROID)
        list(APPEND PROJECT_ATFRAME_UTILS_DEP_SYS_LINK_NAMES pthread)
    endif ()
    if (THREADS_PREFER_PTHREAD_FLAG)
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_DEFINITIONS ${THREADS_PREFER_PTHREAD_FLAG})
    endif ()
endif ()

# Check mkstemp/_mktemp/_mktemp_s for file system
if (WIN32)
    include(CheckCXXSourceCompiles)
    check_cxx_source_compiles("
    #include <io.h>
    #include <stdio.h>
    int main() {
        char buffer[32] = \"abcdefgXXXXXX\";
        const char* f = _mktemp(buffer);
        puts(f);
        return 0;
    }
    "
    LIBATFRAME_UTILS_TEST_WINDOWS_MKTEMP)
    if (LIBATFRAME_UTILS_TEST_WINDOWS_MKTEMP)
        set (LIBATFRAME_UTILS_ENABLE_WINDOWS_MKTEMP TRUE)
    endif()
else ()
    include(CheckCSourceCompiles)
    check_c_source_compiles("
    #include <stdlib.h>
    #include <stdio.h>
    #include <unistd.h>
    int main() {
        char buffer[32] = \"/tmp/abcdefgXXXXXX\";
        int f = mkstemp(buffer);
        close(f);
        return 0;
    }
    "
    LIBATFRAME_UTILS_TEST_POSIX_MKSTEMP)
    if (LIBATFRAME_UTILS_TEST_POSIX_MKSTEMP)
        set (LIBATFRAME_UTILS_ENABLE_POSIX_MKSTEMP TRUE)
    endif()
endif ()

if (ANDROID)
    # Android发现偶现_Unwind_Backtrace调用崩溃,默认金庸掉这个功能。
    # 可以用adb logcat | ./ndk-stack -sym $PROJECT_PATH/obj/local/armeabi 代替
    option(LOG_WRAPPER_ENABLE_STACKTRACE "Try to enable stacktrace for log." OFF)
else()
    option(LOG_WRAPPER_ENABLE_STACKTRACE "Try to enable stacktrace for log." ON)
endif()
option(LOCK_DISABLE_MT "Disable multi-thread support lua support." OFF)
set(LOG_STACKTRACE_MAX_STACKS "100" CACHE STRING "Max stacks when stacktracing.")

include("${PROJECT_ATFRAME_UTILS_SOURCE_DIR}/log/log_configure.cmake")

# 内存混淆int
set(ENABLE_MIXEDINT_MAGIC_MASK 0 CACHE STRING "Integer mixed magic mask")
if (NOT ENABLE_MIXEDINT_MAGIC_MASK)
    set(ENABLE_MIXEDINT_MAGIC_MASK 0)
endif()

if(WIN32)
    include(CheckCXXSourceCompiles)
    set(LIBATFRAME_UTILS_TEST_UUID_BACKUP_CMAKE_REQUIRED_LIBRARIES ${CMAKE_REQUIRED_LIBRARIES})
    set(CMAKE_REQUIRED_LIBRARIES Rpcrt4)
    check_cxx_source_compiles("
    #include <rpc.h>
    int main() {
        UUID Uuid;
        UuidCreate(&Uuid);
        return 0;
    }
    "
    LIBATFRAME_UTILS_TEST_UUID)

    set(CMAKE_REQUIRED_LIBRARIES ${LIBATFRAME_UTILS_TEST_UUID_BACKUP_CMAKE_REQUIRED_LIBRARIES})
    unset(LIBATFRAME_UTILS_TEST_UUID_BACKUP_CMAKE_REQUIRED_LIBRARIES)
    if (LIBATFRAME_UTILS_TEST_UUID)
        set (LIBATFRAME_UTILS_ENABLE_UUID TRUE)
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES Rpcrt4)
    else()
        set (LIBATFRAME_UTILS_ENABLE_UUID FALSE)
    endif()
else()
    find_package(Libuuid)
    if (TARGET libuuid)
        EchoWithColor(COLOR YELLOW "-- Dependency: libuuid found.(Target: libuuid)")
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES libuuid)
        set (LIBATFRAME_UTILS_ENABLE_UUID TRUE)
    elseif(Libuuid_FOUND)
        EchoWithColor(COLOR YELLOW "-- Dependency: libuuid found.(${Libuuid_INCLUDE_DIRS}:${Libuuid_LIBRARIES})")
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_INCLUDE_DIRS ${Libuuid_INCLUDE_DIRS})
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES ${Libuuid_LIBRARIES})
        set (LIBATFRAME_UTILS_ENABLE_UUID TRUE)
    else()
        set (LIBATFRAME_UTILS_ENABLE_UUID FALSE)
    endif()
endif()

# libuv
option(ENABLE_NETWORK "Enable network support." ON)
if (ENABLE_NETWORK)
    if (TARGET uv_a)
        set(NETWORK_EVPOLL_ENABLE_LIBUV 1)
        message(STATUS "libuv using target: uv_a")
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES uv_a)
    elseif (TARGET uv)
        set(NETWORK_EVPOLL_ENABLE_LIBUV 1)
        message(STATUS "libuv using target: uv")
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES uv)
    elseif (TARGET libuv)
        set(NETWORK_EVPOLL_ENABLE_LIBUV 1)
        message(STATUS "libuv using target: libuv")
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES libuv)
    else()
        find_package(Libuv)
        if(Libuv_FOUND)
            message(STATUS "Libuv support enabled")
            set(NETWORK_EVPOLL_ENABLE_LIBUV 1)
        else()
            message(STATUS "Libuv support disabled")
        endif()
    endif()

    # curl
    if (NOT TARGET CURL::libcurl AND NOT CURL_FOUND)
        find_package(CURL)
    endif ()
    if (TARGET CURL::libcurl)
        message(STATUS "Curl using target: CURL::libcurl")
        set(NETWORK_ENABLE_CURL 1)
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES CURL::libcurl)
    elseif(CURL_FOUND AND CURL_LIBRARIES)
        message(STATUS "Curl support enabled")
        set(NETWORK_ENABLE_CURL 1)
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_INCLUDE_DIRS ${CURL_INCLUDE_DIRS})
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES ${CURL_LIBRARIES})
    else()
        message(STATUS "Curl support disabled")
    endif()

    if(Libuv_FOUND)
        if (TARGET unofficial::libuv::libuv)
            list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES unofficial::libuv::libuv)
        elseif (Libuv_LIBRARIES)
            list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_INCLUDE_DIRS ${Libuv_INCLUDE_DIRS})
            list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES ${Libuv_LIBRARIES})
        endif()
    endif()
endif()

# openssl
option(CRYPTO_DISABLED "Disable crypto module if not specify crypto lib." OFF)
if (CRYPTO_USE_OPENSSL OR CRYPTO_USE_LIBRESSL OR CRYPTO_USE_BORINGSSL)
    if (NOT OPENSSL_FOUND AND NOT LIBRESSL_FOUND)
        if (CRYPTO_USE_LIBRESSL)
            find_package(LibreSSL)
        else()
            find_package(OpenSSL)
        endif()
    endif()

    if (OPENSSL_FOUND OR LIBRESSL_FOUND)
        message(STATUS "Crypto enabled.(openssl/libressl found)")
    else()
        message(FATAL_ERROR "CRYPTO_USE_OPENSSL,CRYPTO_USE_LIBRESSL,CRYPTO_USE_BORINGSSL is set but openssl/libressl not found")
    endif()
elseif (CRYPTO_USE_MBEDTLS)
    if (TARGET mbedtls_static OR TARGET mbedtls)
        set(MBEDTLS_FOUND TRUE)
        set(CRYPTO_USE_MBEDTLS 1)
    else ()
        find_package(MbedTLS)
        if (MBEDTLS_FOUND) 
            message(STATUS "Crypto enabled.(mbedtls found)")
            set(CRYPTO_USE_MBEDTLS 1)
        endif()
    endif()
    if (MBEDTLS_FOUND)
        message(STATUS "Crypto enabled.(mbedtls found)")
    else()
        message(FATAL_ERROR "CRYPTO_USE_MBEDTLS is set but mbedtls not found")
    endif()
elseif (NOT CRYPTO_DISABLED)
    # try to find openssl or mbedtls
    find_package(OpenSSL)
    if (NOT OPENSSL_FOUND)
        find_package(LibreSSL)
    endif ()
    if (LIBRESSL_FOUND)
        message(STATUS "Crypto enabled.(libressl found)")
        set(CRYPTO_USE_LIBRESSL 1)
    elseif (OPENSSL_FOUND)
        message(STATUS "Crypto enabled.(openssl found)")
        set(CRYPTO_USE_OPENSSL 1)
    else ()
        if (TARGET mbedtls_static OR TARGET mbedtls)
            set(MBEDTLS_FOUND TRUE)
        else ()
            find_package(MbedTLS)
            if (MBEDTLS_FOUND) 
                message(STATUS "Crypto enabled.(mbedtls found)")
                set(CRYPTO_USE_MBEDTLS 1)
            endif()
        endif()
    endif()
endif()

if(LIBRESSL_FOUND AND NOT OPENSSL_FOUND)
    set (OPENSSL_FOUND ${LIBRESSL_FOUND} CACHE BOOL "using libressl for erplacement of openssl" FORCE)
    set (OPENSSL_INCLUDE_DIR ${LIBRESSL_INCLUDE_DIR} CACHE PATH "libressl include dir" FORCE)
    set (OPENSSL_CRYPTO_LIBRARY ${LIBRESSL_CRYPTO_LIBRARY} CACHE STRING "libressl crypto libs" FORCE)
    set (OPENSSL_CRYPTO_LIBRARIES ${LIBRESSL_CRYPTO_LIBRARY} CACHE STRING "libressl crypto libs" FORCE)
    set (OPENSSL_SSL_LIBRARY ${LIBRESSL_SSL_LIBRARY} CACHE STRING "libressl ssl libs" FORCE)
    set (OPENSSL_SSL_LIBRARIES ${LIBRESSL_SSL_LIBRARY} CACHE STRING "libressl ssl libs" FORCE)
    set (OPENSSL_LIBRARIES ${LIBRESSL_LIBRARIES} CACHE STRING "libressl all libs" FORCE)
    set (OPENSSL_VERSION "1.1.0" CACHE STRING "openssl version of libressl" FORCE)

    set (OpenSSL::Crypto LibreSSL::Crypto)
    set (OpenSSL::SSL LibreSSL::SSL)
endif ()

if (OPENSSL_FOUND)
    if ((TARGET OpenSSL::SSL) OR (TARGET OpenSSL::Crypto))
        if (TARGET OpenSSL::SSL)
            message(STATUS "OpenSSL using target: OpenSSL::SSL")
            list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES OpenSSL::SSL)
        endif ()
        if (TARGET OpenSSL::Crypto)
            message(STATUS "OpenSSL using target: OpenSSL::Crypto")
            list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES OpenSSL::Crypto)
        endif ()
    else ()
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_INCLUDE_DIRS ${OPENSSL_INCLUDE_DIR})
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES ${OPENSSL_SSL_LIBRARY} ${OPENSSL_CRYPTO_LIBRARY})
    endif()
    if (NOT LIBRESSL_FOUND AND WIN32)
        find_library (ATFRAME_UTILS_OPENSSL_FIND_CRYPT32 Crypt32)
        if (ATFRAME_UTILS_OPENSSL_FIND_CRYPT32)
            list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES Crypt32)
        endif()
    endif()
elseif (MBEDTLS_FOUND)
    if (TARGET mbedtls_static)
        message(STATUS "MbedTLS using target: mbedtls_static")
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES mbedtls_static)
    elseif (TARGET mbedtls)
        message(STATUS "MbedTLS using target: mbedtls")
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES mbedtls)
    else ()
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_INCLUDE_DIRS ${MbedTLS_INCLUDE_DIRS})
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES ${MbedTLS_CRYPTO_LIBRARIES})
    endif()
endif()

if (NOT CRYPTO_DISABLED)
    find_package(Libsodium)
    if(LIBSODIUM_FOUND)
        set(CRYPTO_USE_LIBSODIUM 1)
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_INCLUDE_DIRS ${Libsodium_INCLUDE_DIRS})
        list(APPEND PROJECT_ATFRAME_UTILS_PUBLIC_LINK_NAMES ${Libsodium_LIBRARIES})
    endif()
endif()

# 测试配置选项
set(GTEST_ROOT "" CACHE STRING "GTest root directory")
set(BOOST_ROOT "" CACHE STRING "Boost root directory")
option(PROJECT_TEST_ENABLE_BOOST_UNIT_TEST "Enable boost unit test." OFF)

option(PROJECT_ENABLE_UNITTEST "Enable unit test" OFF)
option(PROJECT_ENABLE_SAMPLE "Enable sample" OFF)
