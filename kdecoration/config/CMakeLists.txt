### config classes
### they are kept separately because they might move in a separate library in the future

set(lightlydecoration_config_SRCS
    lightlyconfigwidget.cpp
    lightlydetectwidget.cpp
    lightlyexceptiondialog.cpp
    lightlyexceptionlistwidget.cpp
    lightlyexceptionmodel.cpp
    lightlyitemmodel.cpp
)

set(lightlydecoration_config_PART_FORMS
   ui/lightlyconfigurationui.ui
   ui/lightlydetectwidget.ui
   ui/lightlyexceptiondialog.ui
   ui/lightlyexceptionlistwidget.ui
)
find_package(KF6KCMUtils)
ki18n_wrap_ui(lightlydecoration_config_SRCS ${lightlydecoration_config_PART_FORMS})

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
        KF6::KCMUtils
)
kcmutils_generate_desktop_file(kcm_lightlydecoration)