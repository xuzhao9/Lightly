### config classes
### they are kept separately because they might move in a separate library in the future
find_package(KF6KCMUtils)

set(lightlydecoration_config_SRCS
    ../lightlyexceptionlist.cpp
    lightlyconfigwidget.cpp
    lightlydetectwidget.cpp
    lightlyexceptiondialog.cpp
    lightlyexceptionlistwidget.cpp
    lightlyexceptionmodel.cpp
    lightlyitemmodel.cpp
)
ki18n_wrap_ui(lightlydecoration_config_SRCS
    ui/lightlyconfigurationui.ui
    ui/lightlydetectwidget.ui
    ui/lightlyexceptiondialog.ui
    ui/lightlyexceptionlistwidget.ui
)

# Bring back QString(char *)
remove_definitions(-DQT_NO_CAST_FROM_ASCII)
remove_definitions(-DQT_NO_KEYWORDS)

kcoreaddons_add_plugin(kcm_lightlydecoration SOURCES kcm_lightlydecoration.cpp ${lightlydecoration_config_SRCS} INSTALL_NAMESPACE "${KDECORATION_KCM_PLUGIN_DIR}")
kconfig_add_kcfg_files(kcm_lightlydecoration ../lightlysettings.kcfgc)
target_include_directories(kcm_lightlydecoration PRIVATE ${CMAKE_SOURCE_DIR}/kdecoration ${CMAKE_BINARY_DIR}/kdecoration/)
target_link_libraries(kcm_lightlydecoration
    PUBLIC
        Qt6::Core
        Qt6::Gui
        Qt6::DBus
    PRIVATE
        KF6::ConfigCore
        KF6::CoreAddons
        KF6::GuiAddons
        KF6::I18n
        KF6::IconThemes
        KF6::WindowSystem
        KF6::KCMUtils
)
kcmutils_generate_desktop_file(kcm_lightlydecoration)
