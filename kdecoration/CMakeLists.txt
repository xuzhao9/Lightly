add_definitions(-DTRANSLATION_DOMAIN="lightly_kwin_deco")

find_package(KF6 REQUIRED COMPONENTS CoreAddons GuiAddons ConfigWidgets WindowSystem I18n IconThemes)
find_package(Qt6 CONFIG REQUIRED COMPONENTS DBus)

set(LIGHTLY_HAVE_X11 FALSE)

################# configuration #################
configure_file(config-lightly.h.cmake ${CMAKE_CURRENT_BINARY_DIR}/config-lightly.h )

################# includes #################
include_directories(${CMAKE_SOURCE_DIR}/liblightlycommon)
include_directories(${CMAKE_BINARY_DIR}/liblightlycommon)

################# newt target #################
### plugin classes
set(lightlydecoration_SRCS
    lightlybutton.cpp
    lightlydecoration.cpp
    lightlyexceptionlist.cpp
    lightlysettingsprovider.cpp
    lightlysizegrip.cpp)

# Bring back QString(char *)
remove_definitions(-DQT_NO_CAST_FROM_ASCII)
remove_definitions(-DQT_NO_KEYWORDS)

### build library
kconfig_add_kcfg_files(lightlydecoration_SRCS lightlysettings.kcfgc)
add_library(lightlydecoration MODULE
    ${lightlydecoration_SRCS}
    ${lightlydecoration_config_SRCS}
    ${lightlydecoration_config_PART_FORMS_HEADERS})

set_target_properties(lightlydecoration PROPERTIES
  OUTPUT_NAME org.kde.lightly)

target_compile_options(lightlydecoration
    PRIVATE -std=c++20)

target_link_libraries(lightlydecoration
    PRIVATE
        lightlycommon6
        Qt6::DBus
        Qt6::Widgets
        KF6::CoreAddons
        KF6::ConfigGui
        KF6::GuiAddons
        KF6::I18n
        KF6::IconThemes
        KDecoration3::KDecoration
)

if(LIGHTLY_HAVE_X11)
  target_link_libraries(lightlydecoration
    PUBLIC
      XCB::XCB)
endif()


install(TARGETS lightlydecoration DESTINATION ${KDE_INSTALL_PLUGINDIR}/${KDECORATION_PLUGIN_DIR})

add_subdirectory(config)
