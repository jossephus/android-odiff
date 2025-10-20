cmake_minimum_required(VERSION 3.10)
project(odiff_lib)

add_library(odiff STATIC IMPORTED)
set_target_properties(odiff PROPERTIES IMPORTED_LOCATION
        ${CMAKE_SOURCE_DIR}/src/main/jniLibs/${ANDROID_ABI}/libodiff.a)

add_library(spng STATIC IMPORTED)
set_target_properties(spng PROPERTIES IMPORTED_LOCATION
        ${CMAKE_SOURCE_DIR}/src/main/jniLibs/${ANDROID_ABI}/libspng.a)

add_library(jpeg STATIC IMPORTED)
set_target_properties(jpeg PROPERTIES IMPORTED_LOCATION
        ${CMAKE_SOURCE_DIR}/src/main/jniLibs/${ANDROID_ABI}/libjpeg-turbo.a)

add_library(z STATIC IMPORTED)
set_target_properties(z PROPERTIES IMPORTED_LOCATION
        ${CMAKE_SOURCE_DIR}/src/main/jniLibs/${ANDROID_ABI}/libz.a)

add_library(zstd STATIC IMPORTED)
set_target_properties(zstd PROPERTIES IMPORTED_LOCATION
        ${CMAKE_SOURCE_DIR}/src/main/jniLibs/${ANDROID_ABI}/libzstd.a)

add_library(webp STATIC IMPORTED)
set_target_properties(webp PROPERTIES IMPORTED_LOCATION
        ${CMAKE_SOURCE_DIR}/src/main/jniLibs/${ANDROID_ABI}/libwebp.a)

add_library(tiff STATIC IMPORTED)
set_target_properties(tiff PROPERTIES IMPORTED_LOCATION
        ${CMAKE_SOURCE_DIR}/src/main/jniLibs/${ANDROID_ABI}/libtiff.a)

add_library(odiff_lib SHARED ./odiff_bindings.cpp)
target_link_options(odiff_lib PRIVATE -flto "-Wl,-z,max-page-size=16384" "-Wl,-z,common-page-size=16384")
target_link_libraries(odiff_lib odiff spng jpeg z zstd tiff webp atomic m -pthread -Wl,--allow-shlib-undefined)
