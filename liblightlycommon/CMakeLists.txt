################# dependencies #################
### Qt/KDE
find_package(Qt6 REQUIRED CONFIG COMPONENTS Widgets)

################# lightlystyle target #################
set(lightlycommon_LIB_SRCS
    lightlyboxshadowrenderer.cpp
)

add_library(lightlycommon6 ${lightlycommon_LIB_SRCS})

generate_export_header(lightlycommon6
    BASE_NAME lightlycommon
    EXPORT_FILE_NAME lightlycommon_export.h)

target_link_libraries(lightlycommon6
    PUBLIC
        Qt6::Core
        Qt6::Gui)

set_target_properties(lightlycommon6 PROPERTIES
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
    POSITION_INDEPENDENT_CODE TRUE)

install(TARGETS lightlycommon6 ${INSTALL_TARGETS_DEFAULT_ARGS} LIBRARY NAMELINK_SKIP)
