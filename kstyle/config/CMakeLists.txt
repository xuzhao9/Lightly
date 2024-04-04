### configuration plugin
add_definitions(-DTRANSLATION_DOMAIN=\"lightly_style_config\")
set(kstyle_lightly_config_PART_SRCS lightlystyleconfig.cpp)

set(kstyle_lightly_config_PART_SRCS ${kstyle_lightly_config_PART_SRCS} lightlystyleconfigmodule.cpp)

kconfig_add_kcfg_files(kstyle_lightly_config_PART_SRCS ../lightlystyleconfigdata.kcfgc)
set(kstyle_lightly_config_PART_FORMS ui/lightlystyleconfig.ui)
ki18n_wrap_ui(kstyle_lightly_config_PART_FORMS_HEADERS ${kstyle_lightly_config_PART_FORMS})

add_library(kstyle_lightly_config MODULE
    ${kstyle_lightly_config_PART_SRCS}
    ${kstyle_lightly_config_PART_FORMS_HEADERS}
)

target_link_libraries(kstyle_lightly_config Qt6::Core Qt6::Gui Qt6::Widgets Qt6::DBus)
target_link_libraries(kstyle_lightly_config KF6::ConfigCore KF6::ConfigWidgets KF6::I18n)
install(TARGETS kstyle_lightly_config DESTINATION ${QT_PLUGIN_INSTALL_DIR})
install(FILES lightlystyleconfig.desktop DESTINATION  ${SERVICES_INSTALL_DIR})

########### next target ###############
find_package(KF6KCMUtils CONFIG)
set_package_properties(KF6KCMUtils PROPERTIES
    DESCRIPTION "KF6 KCM utils Framework"
    URL "https://projects.kde.org/projects/frameworks/kcmutils"
    TYPE OPTIONAL
    PURPOSE "Required for lightly-settings6 application to build")

if( KF5KCMUtils_FOUND )
    set(lightly_settings_SOURCES main.cpp)
    add_executable(lightly-settings6 ${lightly_settings_SOURCES} )
    target_link_libraries(lightly-settings6 Qt6::Core Qt6::Gui Qt6::Widgets )
    target_link_libraries(lightly-settings6 KF6::I18n KF6::KCMUtils)

    install(TARGETS lightly-settings6 ${INSTALL_TARGETS_DEFAULT_ARGS})

    # icon
    ecm_install_icons(ICONS sc-apps-lightly-settings.svgz
        DESTINATION ${ICON_INSTALL_DIR}
        THEME hicolor )
endif()
