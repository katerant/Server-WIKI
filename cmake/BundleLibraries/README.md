Модуль для упаковки статических зависимостей и статической либы в 1 общий архив объектов (.a/.lib)

Использование: 

```cmake

add_library(${LIB_NAME} STATIC ${LIB_SOURCES})

find_package(fmt CONFIG REQUIRED)
target_link_libraries(${LIB_NAME} PRIVATE fmt::fmt) # fmt тоже будет упакована

if(${WITH_DEPS})
    # Для библиотек, путь к которым не может быть извлечён из зависимостей ${LIB_NAME}, к примеру,
    # если линкуется не цель сборки (т.е. fmt::fmt), а просто имя, т.е. pthread, crypto и т.д. 
    # стоит использовать bundle_add_lib
    if(WIN32)
        bundle_add_lib(${LIB_NAME} zlib) 
    else()
        bundle_add_lib(${LIB_NAME} z)
    endif()

    # Несмотря на то, что OpenSSL::Сrypto и OpenSSL::SSL - цели сборки, из них не получится достать
    # пути к библиотекам, т.к. они записываются в отдельную переменную, не связанную с целями сборки
    #
    # https://cmake.org/cmake/help/latest/module/FindOpenSSL.html

    bundle_add_lib(${LIB_NAME} ssl)
    bundle_add_lib(${LIB_NAME} crypto)

    bundle_static_library(${LIB_NAME} ${LIB_NAME}-with-deps)
endif()
```