cmake_minimum_required(VERSION 3.20)

project(lightly)
set(PROJECT_VERSION "0.44")
set(PROJECT_VERSION_MAJOR 6)

set(KF6_MIN_VERSION "6.0.0")
set(QT_MIN_VERSION "6.4.0")

include(GenerateExportHeader)
include(WriteBasicConfigVersionFile)
include(FeatureSummary)

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${ECM_MODULE_PATH} ${ECM_KDE_MODULE_DIR} ${CMAKE_SOURCE_DIR}/cmake)

include(CMakePackageConfigHelpers)
include(ECMInstallIcons)
include(KDEInstallDirs6)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(KDEClangFormat)

include(GtkUpdateIconCache)


find_package(KF6FrameworkIntegration ${KF6_MIN_VERSION} CONFIG )
set_package_properties(KF${QT_MAJOR_VERSION}FrameworkIntegration PROPERTIES
    DESCRIPTION "KF6 Framework Integration"
    URL "https://projects.kde.org/projects/frameworks/frameworkintegration"
    TYPE OPTIONAL
    PURPOSE "Required to use KStyle convenience functionalities in style")

option(FOR_FLATPAK "Build Lightly for Flatpak" OFF)
option(WITH_DECORATIONS "Build Lightly window decorations for KWin" ON)
if(WITH_DECORATIONS)
    find_package(KDecoration2 REQUIRED)
    add_subdirectory(kdecoration)
endif()

add_subdirectory(liblightlycommon)
add_subdirectory(kstyle)
if (!FOR_FLATPAK)
    add_subdirectory(colors)
    add_subdirectory(misc)
endif()

include(ECMSetupVersion)
ecm_setup_version(${PROJECT_VERSION} VARIABLE_PREFIX LIGHTLY
                  PACKAGE_VERSION_FILE "${CMAKE_CURRENT_BINARY_DIR}/LightlyConfigVersion.cmake"
)

# create a Config.cmake and a ConfigVersion.cmake file and install them
set(CMAKECONFIG_INSTALL_DIR "${KDE_INSTALL_CMAKEPACKAGEDIR}/Lightly")

configure_package_config_file("${CMAKE_CURRENT_SOURCE_DIR}/LightlyConfig.cmake.in"
                              "${CMAKE_CURRENT_BINARY_DIR}/LightlyConfig.cmake"
	                      PATH_VARS KDE_INSTALL_FULL_DATADIR
                              INSTALL_DESTINATION  ${CMAKECONFIG_INSTALL_DIR})

# add clang-format target for all our real source files
file(GLOB_RECURSE ALL_CLANG_FORMAT_SOURCE_FILES *.cpp *.h)
kde_clang_format(${ALL_CLANG_FORMAT_SOURCE_FILES})

if (!FOR_FLATPAK)
install(FILES  "${CMAKE_CURRENT_BINARY_DIR}/LightlyConfig.cmake"
               "${CMAKE_CURRENT_BINARY_DIR}/LightlyConfigVersion.cmake"
        DESTINATION "${CMAKECONFIG_INSTALL_DIR}"
        COMPONENT Devel
)
endif()

feature_summary(WHAT ALL INCLUDE_QUIET_PACKAGES FATAL_ON_MISSING_REQUIRED_PACKAGES)
