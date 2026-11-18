/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami

Item {
    id: avatarFrame

    required property string userImage
    property string iconSource: "user-identity"
    property bool revealed: false
    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    implicitWidth: 92
    implicitHeight: 92
    scale: revealed ? 1 : 0

    Behavior on scale {
        NumberAnimation {
            duration: avatarFrame.revealed ? 500 : 400
            easing.type: avatarFrame.revealed ? Easing.OutBack : Easing.InBack
        }
    }

    Item {
        id: avatarContents
        anchors.fill: parent
        visible: avatarFrame.softwareRendering

        Rectangle {
            anchors.fill: parent
            color: "#66808080"
        }

        Kirigami.Icon {
            anchors.fill: parent
            anchors.margins: 18
            source: avatarFrame.iconSource
            isMask: true
            color: "white"
            visible: avatar.status !== Image.Ready
        }

        Image {
            id: avatar
            anchors.fill: parent
            source: avatarFrame.userImage === "" ? ""
                : avatarFrame.userImage.includes("://") ? avatarFrame.userImage
                : "file://" + avatarFrame.userImage.split("/").map(encodeURIComponent).join("/")
            fillMode: Image.PreserveAspectCrop
            smooth: true
        }
    }

    Rectangle {
        id: avatarMask
        anchors.fill: parent
        radius: width / 2
        color: "white"
        visible: false
    }

    OpacityMask {
        anchors.fill: parent
        source: avatarContents
        maskSource: avatarMask
        visible: !avatarFrame.softwareRendering
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.color: "#99ffffff"
        border.width: 1
    }
}
